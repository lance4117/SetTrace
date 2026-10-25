import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'diagnostic_contract.dart';

abstract interface class DiagnosticsTransport {
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]);
}

class AndroidDiagnosticsTransport implements DiagnosticsTransport {
  const AndroidDiagnosticsTransport();
  static const channel = MethodChannel('settrace/diagnostics');
  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (result == null) throw const DiagnosticsFailure('unavailable');
      if (result['error'] case final String error) {
        throw DiagnosticsFailure(error);
      }
      return result;
    } on PlatformException catch (error) {
      throw DiagnosticsFailure(error.code);
    } on MissingPluginException {
      throw const DiagnosticsFailure('unsupported');
    }
  }
}

/// Non-throwing observation; commands deliberately retain their failure result.
class DiagnosticsClient {
  DiagnosticsClient({this.transport, int? Function()? epoch})
    : _epoch = epoch ?? (() => null);
  static DiagnosticsClient instance = DiagnosticsClient();
  final DiagnosticsTransport? transport;
  final int? Function() _epoch;
  final String processId = diagnosticId();
  final Stopwatch _clock = Stopwatch()..start();
  final List<String> _pending = [];
  Timer? _timer;
  int _sequence = 0, _queuedBytes = 0, _dropped = 0;
  bool _sending = false, _disposed = false;
  Completer<void>? _inFlight;
  DiagnosticsOverview? _overview;
  int get queuedBytes => _queuedBytes;
  int get dropped => _dropped;
  DiagnosticsOverview? get current => _overview;
  int? get datasetEpoch => _readEpoch();

  Future<DiagnosticsOverview> overview() async {
    final value = DiagnosticsOverview.fromWire(await _command('overview'));
    return _accept(value);
  }

  Future<DiagnosticsOverview> setEnabled(bool enabled) async {
    return _accept(
      DiagnosticsOverview.fromWire(
        await _command('setEnabled', {'enabled': enabled}),
      ),
    );
  }

  Future<DiagnosticsOverview> setDetailed(bool enabled) async {
    return _accept(
      DiagnosticsOverview.fromWire(
        await _command('setDetailed', {'enabled': enabled}),
      ),
    );
  }

  Future<DiagnosticsOverview> clear() async {
    final value = DiagnosticsOverview.fromWire(await _command('clear'));
    _discard();
    return _accept(value);
  }

  Future<DiagnosticExportStatus> startExport({
    Map<String, Object?> state = const {},
    bool Function()? cancelled,
  }) async {
    final target = transport;
    if (target == null) throw const DiagnosticsFailure('unsupported');
    // System permission UI has no arbitrary eight-second deadline. A late
    // grant must not start a new task after the originating page cancelled.
    await target.call('requestExportPermission');
    if (cancelled?.call() == true) throw const DiagnosticsFailure('cancelled');
    await flush();
    if (cancelled?.call() == true) throw const DiagnosticsFailure('cancelled');
    return DiagnosticExportStatus.fromWire(
      await _command('startExport', {
        'state': state,
        'dart_dropped': _dropped,
        'process_instance': processId,
        'generation': _overview?.generation,
      }),
    );
  }

  Future<DiagnosticExportStatus> exportStatus(String id) async =>
      DiagnosticExportStatus.fromWire(
        await _command('exportStatus', {'export_id': id}),
      );
  Future<DiagnosticExportStatus> cancelExport(String id) async =>
      DiagnosticExportStatus.fromWire(
        await _command('cancelExport', {'export_id': id}),
      );
  Future<DiagnosticExportStatus> inspectExport() async =>
      DiagnosticExportStatus.fromWire(await _command('inspectExport'));

  Future<Map<String, Object?>> _command(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    final target = transport;
    if (target == null) throw const DiagnosticsFailure('unsupported');
    try {
      return await target
          .call(method, arguments)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // A lost acknowledgement is not evidence that a native mutation failed.
      throw DiagnosticsFailure(
        method == 'startExport' || method == 'cancelExport'
            ? 'publication_unknown'
            : 'timeout',
      );
    }
  }

  DiagnosticOperation operation(
    DiagnosticName name, {
    Map<DiagnosticObject, Object> objects = const {},
    Map<DiagnosticField, Object> fields = const {},
    String? parent,
    String? backupOperation,
    bool begin = true,
  }) {
    final operation = DiagnosticOperation._(
      this,
      name,
      diagnosticId(),
      objects,
      _readEpoch(),
      parent,
      backupOperation,
    );
    if (begin) {
      operation.emit(
        DiagnosticPhase.started,
        DiagnosticOutcome.observed,
        fields: fields,
      );
    }
    return operation;
  }

  void event(
    DiagnosticName name, {
    required DiagnosticPhase phase,
    DiagnosticOutcome outcome = DiagnosticOutcome.observed,
    DiagnosticSeverity level = DiagnosticSeverity.info,
    DiagnosticReason reason = DiagnosticReason.none,
    String? operationId,
    String? backupOperation,
    String? parent,
    Map<DiagnosticField, Object> fields = const {},
    Map<DiagnosticObject, Object> objects = const {},
    int? epoch,
    bool fixedEpoch = false,
    StackTrace? stack,
  }) {
    if (_disposed || transport == null || _overview?.enabled == false) return;
    try {
      final event = DiagnosticEvent(
        name: name,
        phase: phase,
        outcome: outcome,
        level: level,
        reason: reason,
        operationId: operationId ?? diagnosticId(),
        parentOperationId: parent,
        backupOperation: backupOperation,
        processId: processId,
        sequence: ++_sequence,
        monotonicUs: _clock.elapsedMicroseconds,
        time: DateTime.now(),
        epoch: fixedEpoch ? epoch : epoch ?? _readEpoch(),
        generation: _overview?.generation,
        fields: fields,
        objects: objects,
        frames: diagnosticFrames(stack),
      );
      final encoded = jsonEncode(event.toWire());
      final cost = encoded.length * 2 + 128;
      // Count string storage and conservative per-record overhead, not just UTF8.
      if (cost > 40 * 1024 ||
          _queuedBytes + cost > 128 * 1024 ||
          _pending.length >= 128) {
        _dropped++;
        return;
      }
      _pending.add(encoded);
      _queuedBytes += cost;
      _timer ??= Timer(const Duration(seconds: 1), () {
        _timer = null;
        unawaited(flush());
      });
      if (_queuedBytes >= 32 * 1024 && !_sending) unawaited(flush());
    } catch (_) {
      _dropped++;
    }
  }

  Future<void> flush() async {
    while (_inFlight != null) {
      await _inFlight!.future;
    }
    if (_pending.isEmpty || transport == null || _disposed) return;
    _sending = true;
    final active = Completer<void>();
    _inFlight = active;
    _timer?.cancel();
    _timer = null;
    final records = List<String>.of(_pending);
    final admittedGeneration = _overview?.generation;
    _pending.clear();
    _queuedBytes = 0;
    try {
      await transport!
          .call('recordBatch', {
            'records': records,
            'dart_dropped': _dropped,
            'process_instance': processId,
            'generation': admittedGeneration,
          })
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      if (_overview?.generation == admittedGeneration) _dropped += records.length;
    } finally {
      _sending = false;
      _inFlight = null;
      active.complete();
      if (_pending.isNotEmpty && !_disposed) {
        _timer ??= Timer(const Duration(seconds: 1), () {
          _timer = null;
          unawaited(flush());
        });
      }
    }
  }

  DiagnosticsOverview _accept(DiagnosticsOverview value) {
    if (_overview != null && _overview!.generation != value.generation) _dropped = 0;
    if (_overview != null && _overview!.generation != value.generation ||
        !value.enabled) {
      _discard();
    }
    _overview = value;
    return value;
  }

  int? _readEpoch() {
    try {
      return _epoch();
    } catch (_) {
      return null;
    }
  }

  void _discard() {
    _pending.clear();
    _queuedBytes = 0;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _discard();
  }
}

class DiagnosticOperation {
  DiagnosticOperation._(
    this.client,
    this.name,
    this.id,
    this.objects,
    this.epoch,
    this.parent,
    this.backupOperation,
  ) : _startedMonotonicUs = client._clock.elapsedMicroseconds;
  final DiagnosticsClient client;
  final DiagnosticName name;
  final String id;
  final String? parent;
  final String? backupOperation;
  final int? epoch;
  final int _startedMonotonicUs;
  final Map<DiagnosticObject, Object> objects;
  void emit(
    DiagnosticPhase phase,
    DiagnosticOutcome outcome, {
    DiagnosticReason reason = DiagnosticReason.none,
    DiagnosticSeverity level = DiagnosticSeverity.info,
    Map<DiagnosticField, Object> fields = const {},
    Map<DiagnosticObject, Object> resultObjects = const {},
    StackTrace? stack,
  }) => client.event(
    name,
    phase: phase,
    outcome: outcome,
    reason: reason,
    level: level,
    operationId: id,
    parent: parent,
    backupOperation: backupOperation,
    objects: {...objects, ...resultObjects},
    epoch: epoch,
    fixedEpoch: true,
    fields: {
      ...fields,
      if (phase != DiagnosticPhase.started)
        DiagnosticField.duration_ms:
            (client._clock.elapsedMicroseconds - _startedMonotonicUs) ~/ 1000,
    },
    stack: stack,
  );
}
