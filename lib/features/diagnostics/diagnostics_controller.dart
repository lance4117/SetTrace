import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostics_client.dart';

/// UI owns no files or business locks; confirmed state comes from native.
class DiagnosticsController extends ChangeNotifier {
  DiagnosticsController(this.client);
  final DiagnosticsClient client;
  DiagnosticsOverview? overview;
  DiagnosticExportStatus? export;
  bool loading = true, controlling = false, launching = false;
  bool overviewFailed = false, cancelling = false, inspecting = false;
  String? controlError, exportError;
  bool _disposed = false, _cancelRequested = false;
  int _loadRevision = 0, _exportRevision = 0;
  Timer? _poll;
  bool get exporting => launching || (export != null && !export!.terminal);
  bool get blocked => controlling || exporting || inspecting;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String _reason(Object error) =>
      error is DiagnosticsFailure ? error.code : 'storage_unavailable';

  Future<void> load({bool recoverExport = true}) async {
    final revision = ++_loadRevision;
    loading = true;
    _emit();
    try {
      final value = await client.overview();
      if (_disposed || revision != _loadRevision) return;
      overview = value;
      overviewFailed = false;
    } catch (_) {
      if (_disposed || revision != _loadRevision) return;
      overviewFailed = true;
    } finally {
      if (!_disposed && revision == _loadRevision) {
        loading = false;
        _emit();
      }
    }
    if (recoverExport && !_disposed && !exporting) {
      // Inspect only; never replay a task after restoration or Activity loss.
      try {
        final result = await client.inspectExport();
        if (!_disposed && revision == _loadRevision) {
          export = result;
          _watch();
          _emit();
        }
      } catch (error) {
        if (error is DiagnosticsFailure && error.code == 'missing') return;
        if (!_disposed && revision == _loadRevision) {
          exportError = 'publication_unknown';
          _emit();
        }
      }
    }
  }

  Future<void> _control(Future<DiagnosticsOverview> Function() command) async {
    if (_disposed || blocked) return;
    controlling = true;
    loading = false;
    controlError = null;
    ++_loadRevision;
    _emit();
    try {
      final value = await command();
      if (!_disposed) {
        overview = value;
        overviewFailed = false;
      }
    } catch (error) {
      if (!_disposed) {
        controlError = _reason(error);
        // A timeout may have committed; re-read before enabling the controls.
        try {
          overview = await client.overview();
          overviewFailed = false;
        } catch (_) {
          overviewFailed = true;
        }
      }
    } finally {
      controlling = false;
      _emit();
    }
  }

  Future<void> setEnabled(bool value) =>
      _control(() => client.setEnabled(value));
  Future<void> setDetailed(bool value) =>
      _control(() => client.setDetailed(value));
  Future<void> clear() => _control(client.clear);

  Future<void> startExport({Map<String, Object?> state = const {}}) async {
    if (_disposed ||
        blocked ||
        export?.stage == DiagnosticExportStage.unknown ||
        exportError == 'publication_unknown') {
      return;
    }
    final revision = ++_exportRevision;
    launching = true;
    _cancelRequested = false;
    cancelling = false;
    exportError = null;
    export = null;
    _emit();
    try {
      final result = await client.startExport(
        state: state,
        cancelled: () => _cancelRequested || _disposed,
      );
      if (_disposed || revision != _exportRevision) return;
      export = result;
      if (_cancelRequested && !result.terminal) {
        export = await client.cancelExport(result.id);
      }
      _watch();
    } catch (error) {
      if (!_disposed && revision == _exportRevision) {
        exportError = _reason(error);
        if (exportError == 'publication_unknown') await inspect();
      }
    } finally {
      if (revision == _exportRevision) {
        launching = false;
        if (export?.terminal != false) cancelling = false;
        _emit();
      }
    }
  }

  void _watch() {
    _poll?.cancel();
    if (!_disposed && export != null && !export!.terminal) {
      _poll = Timer(const Duration(milliseconds: 400), _refreshExport);
    }
  }

  Future<void> _refreshExport() async {
    final id = export?.id, revision = _exportRevision;
    if (id == null || _disposed) return;
    try {
      final value = await client.exportStatus(id);
      if (_disposed || revision != _exportRevision || export?.id != id) return;
      export = value;
      exportError = null;
      if (value.terminal) cancelling = false;
    } catch (_) {
      if (_disposed || revision != _exportRevision) return;
      exportError = 'publication_unknown';
      _poll?.cancel();
      _emit();
      return;
    }
    _emit();
    _watch();
  }

  Future<void> cancel() async {
    if (_disposed || cancelling || !exporting) return;
    _cancelRequested = true;
    if (export != null && !export!.cancellable) {
      _emit();
      return;
    }
    cancelling = true;
    _emit();
    if (export == null) return; // Permission dialog resolves via predicate.
    try {
      export = await client.cancelExport(export!.id);
      _watch();
    } catch (_) {
      exportError = 'publication_unknown';
      cancelling = false;
    }
    _emit();
  }

  Future<void> inspect() async {
    if (_disposed || inspecting) return;
    inspecting = true;
    _emit();
    try {
      final result = await client.inspectExport();
      if (!_disposed) {
        export = result;
        exportError = null;
        if (result.terminal) cancelling = false;
        _watch();
      }
    } catch (error) {
      if (!_disposed) {
        if (error is DiagnosticsFailure && error.code == 'missing') {
          export = null;
          exportError = 'missing';
        } else {
          exportError = 'publication_unknown';
        }
      }
    } finally {
      inspecting = false;
      _emit();
    }
  }

  Future<void> resume() async {
    if (export != null && !export!.terminal) {
      await _refreshExport();
    } else {
      await load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_loadRevision;
    ++_exportRevision;
    _poll?.cancel();
    super.dispose();
  }
}
