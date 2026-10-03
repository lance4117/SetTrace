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
      throw const PlanTransferException('复制失败，请重试或选择导出到文件');
    }
  }

  @override
  Future<String?> readClipboard() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      throw const PlanTransferException('无法读取剪贴板，请手动粘贴计划文本');
    }
  }

  Future<Map<Object?, Object?>> _invoke(
    String method, [
    Object? arguments,
  ]) async {
    if (_fileBusy) throw const PlanTransferException('文件操作正在进行，请稍候');
    _fileBusy = true;
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      if (result == null) throw const PlanTransferException('文件操作未完成，请重试');
      if (result['status'] == 'error') {
        throw PlanTransferException(
          result['message'] is String
              ? result['message'] as String
              : '文件操作失败，请重试',
        );
      }
      return result;
    } on PlatformException {
      throw const PlanTransferException('文件操作失败，请重试');
    } on MissingPluginException {
      throw const PlanTransferException('当前平台暂不支持计划文件操作');
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
        result['location'] != '下载') {
      throw const PlanTransferException('文件未保存到下载目录，请重试');
    }
    return SavedPlanFile(result['fileName'] as String, '下载');
  }

  @override
  Future<String?> pickFile() async {
    final result = await _invoke('pickFile');
    if (result['status'] == 'cancelled') return null;
    if (result['status'] != 'success' || result['text'] is! String) {
      throw const PlanTransferException('无法读取文件，请重新选择');
    }
    final text = result['text'] as String;
    PlanTransferCodec.checkSize(text);
    if (text.trim().isEmpty) throw const PlanTransferException('文件为空，请重新选择');
    return text;
  }
}
