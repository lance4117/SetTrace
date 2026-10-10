import 'package:flutter/services.dart';

import 'plan_transfer.dart';

class SavedPlanFile {
  const SavedPlanFile(this.fileName, this.location);
  final String fileName, location;
}

abstract class PlanTransferPlatform {
  Future<void> copyText(String text);
  Future<String?> readClipboard();
  Future<SavedPlanFile> saveFile(String text);
  Future<String?> pickFile();
}

class AndroidPlanTransferPlatform implements PlanTransferPlatform {
  AndroidPlanTransferPlatform({
    this.channel = const MethodChannel('settrace/plan_transfer'),
  });
  final MethodChannel channel;
  bool _fileBusy = false;
  @override
  Future<void> copyText(String text) async {
    PlanTransferCodec.checkSize(text);
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      throw const PlanTransferException(
        PlanTransferFailure.clipboardCopyFailed,
      );
    }
  }

  @override
  Future<String?> readClipboard() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      throw const PlanTransferException(
        PlanTransferFailure.clipboardReadFailed,
      );
    }
  }

  Future<Map<Object?, Object?>> _invoke(
    String method, [
    Object? arguments,
  ]) async {
    if (_fileBusy) {
      throw const PlanTransferException(PlanTransferFailure.fileBusy);
    }
    _fileBusy = true;
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      if (result == null) {
        throw const PlanTransferException(PlanTransferFailure.fileIncomplete);
      }
      if (result['status'] == 'error') {
        final code = PlanTransferFailure.values
            .where((v) => v.name == result['code'])
            .firstOrNull;
        throw PlanTransferException(
          code ?? PlanTransferFailure.fileOperationFailed,
        );
      }
      return result;
    } on PlatformException {
      throw const PlanTransferException(
        PlanTransferFailure.fileOperationFailed,
      );
    } on MissingPluginException {
      throw const PlanTransferException(PlanTransferFailure.fileUnsupported);
    } finally {
      _fileBusy = false;
    }
  }

  @override
  Future<SavedPlanFile> saveFile(String text) async {
    PlanTransferCodec.checkSize(text);
    final result = await _invoke('saveFile', {'text': text});
    if (result['status'] != 'success' ||
        result['fileName'] is! String ||
        result['location'] != 'downloads') {
      throw const PlanTransferException(PlanTransferFailure.fileNotDownloads);
    }
    return SavedPlanFile(result['fileName'] as String, 'downloads');
  }

  @override
  Future<String?> pickFile() async {
    final result = await _invoke('pickFile');
    if (result['status'] == 'cancelled') return null;
    if (result['status'] != 'success' || result['text'] is! String) {
      throw const PlanTransferException(PlanTransferFailure.fileReadFailed);
    }
    final text = result['text'] as String;
    PlanTransferCodec.checkSize(text);
    if (text.trim().isEmpty) {
      throw const PlanTransferException(PlanTransferFailure.fileEmpty);
    }
    return text;
  }
}
