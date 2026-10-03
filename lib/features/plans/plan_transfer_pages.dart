import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'plan_models.dart';
import 'plan_repository.dart';
import 'plan_transfer.dart';
import 'plan_transfer_platform.dart';

String transferError(Object error, String fallback) =>
    error is PlanTransferException ? error.message : fallback;

class PlanExportPage extends StatefulWidget {
  const PlanExportPage({
    super.key,
    required this.plans,
    required this.platform,
  });
  final PlanRepository plans;
  final PlanTransferPlatform platform;
  @override
  State<PlanExportPage> createState() => _PlanExportPageState();
}

class _PlanExportPageState extends State<PlanExportPage> {
  List<WorkoutPlan> items = [];
  Set<int> selected = {};
  bool loading = true, busy = false, successful = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final plans = await widget.plans.listPlans();
      if (mounted) {
        setState(() {
          items = plans;
          selected = plans.map((p) => p.id).toSet();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message = '无法加载计划，请返回后重试';
        });
      }
    }
  }

  Future<void> output(bool file) async {
    if (busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      message = null;
      successful = false;
    });
    try {
      final plans = await widget.plans.exportPlans(Set.of(selected));
      final text = const PlanTransferCodec().encode(
        PlanTransferDocument(plans, exportedAt: DateTime.now().toUtc()),
      );
      final String result;
      if (file) {
        final saved = await widget.platform.saveFile(text);
        result = '已保存到下载目录：${saved.fileName}';
      } else {
        await widget.platform.copyText(text);
        result = '已复制 ${plans.length} 个计划';
      }
      if (mounted) {
        setState(() {
          message = result;
          successful = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = transferError(error, '导出失败，请重试'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('导出计划'),
        automaticallyImplyLeading: !busy,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '训练计划备份包含计划及动作配置，不包含训练记录。',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('已选 ${selected.length} 个计划'),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: busy || loading
                        ? null
                        : () => setState(
                            () => selected = items.map((p) => p.id).toSet(),
                          ),
                    child: const Text('全选'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: busy || loading
                        ? null
                        : () => setState(() => selected = {}),
                    child: const Text('取消全选'),
                  ),
                ],
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const Center(child: Text('没有可导出的计划'))
                    : ListView(
                        children: [
                          for (final plan in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                child: CheckboxListTile(
                                  value: selected.contains(plan.id),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: busy
                                      ? null
                                      : (value) => setState(() {
                                          if (value == true) {
                                            selected.add(plan.id);
                                          } else {
                                            selected.remove(plan.id);
                                          }
                                        }),
                                  title: Text(plan.name),
                                  subtitle: Text(
                                    '${plan.exercises.length} 个动作 · ${plan.totalSets} 组',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    message!,
                    style: TextStyle(
                      color: successful
                          ? context.appColors.accent
                          : context.appColors.danger,
                    ),
                  ),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              AppButton(
                label: '复制到剪贴板',
                primary: false,
                onPressed: busy || selected.isEmpty
                    ? null
                    : () => output(false),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: '导出到文件',
                onPressed: busy || selected.isEmpty ? null : () => output(true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PlanImportPage extends StatefulWidget {
  const PlanImportPage({
    super.key,
    required this.plans,
    required this.platform,
  });
  final PlanRepository plans;
  final PlanTransferPlatform platform;
  @override
  State<PlanImportPage> createState() => _PlanImportPageState();
}

class _PlanImportPageState extends State<PlanImportPage> {
  final input = TextEditingController();
  List<TransferPlan>? preview;
  List<TextEditingController> names = [];
  bool busy = false;
  String? message;
  @override
  void dispose() {
    input.dispose();
    for (final c in names) {
      c.dispose();
    }
    super.dispose();
  }

  void showPreview(List<TransferPlan> plans) {
    for (final c in names) {
      c.dispose();
    }
    names = plans.map((p) => TextEditingController(text: p.name)).toList();
    setState(() => preview = plans);
  }

  Future<void> prepare(String text) async {
    final parsed = const PlanTransferCodec().decode(text);
    final resolved = await widget.plans.previewImport(parsed.plans);
    if (mounted) showPreview(resolved);
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => message = transferError(error, '导入失败，请重试'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> paste() => perform(() async {
    final text = await widget.platform.readClipboard();
    if (text == null || text.trim().isEmpty) {
      throw const PlanTransferException('剪贴板没有计划文本，请手动粘贴或选择文件');
    }
    PlanTransferCodec.checkSize(text);
    if (mounted) input.text = text;
  });
  Future<void> pick() => perform(() async {
    final text = await widget.platform.pickFile();
    if (text != null && mounted) await prepare(text);
  });
  Future<void> confirm() => perform(() async {
    final edited = [
      for (var i = 0; i < preview!.length; i++)
        preview![i].withName(names[i].text),
    ];
    const PlanTransferCodec().validatePlans(edited);
    final resolved = await widget.plans.previewImport(edited);
    if (!mounted) return;
    if (Iterable<int>.generate(edited.length)
        .any((i) => edited[i].name != resolved[i].name)) {
      showPreview(resolved);
      setState(() => message = '名称存在冲突，已调整为副本名称，请检查后再次确认');
      return;
    }
    try {
      final ids = await widget.plans.importPlans(edited);
      if (mounted) Navigator.pop(context, ids.length);
    } on ImportNameConflict catch (conflict) {
      if (mounted) {
        showPreview(conflict.plans);
        setState(() => message = '名称已被占用，已更新预览，请再次确认');
      }
    }
  });
  void reset() {
    for (final c in names) {
      c.dispose();
    }
    names = [];
    setState(() {
      preview = null;
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = preview;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(current == null ? '导入计划' : '导入预览'),
          automaticallyImplyLeading: !busy,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: current == null
                      ? ListView(
                          children: [
                            const Text('粘贴别人分享的计划文本，或选择本地计划文件。'),
                            const SizedBox(height: 16),
                            TextField(
                              key: const ValueKey('plan-import-text'),
                              controller: input,
                              minLines: 6,
                              maxLines: 10,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                hintText: '在这里粘贴计划文本',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: busy ? null : paste,
                                child: const Text('粘贴'),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            Text('将新增 ${current.length} 个计划，同名计划创建副本。'),
                            const SizedBox(height: 12),
                            for (var i = 0; i < current.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        key: ValueKey('import-name-$i'),
                                        controller: names[i],
                                        maxLength: 40,
                                        enabled: !busy,
                                        decoration: const InputDecoration(
                                          labelText: '计划名称',
                                        ),
                                      ),
                                      Text(
                                        '${current[i].exercises.length} 个动作 · ${current[i].totalSets} 组',
                                      ),
                                      if (current[i].exercises.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text('空计划，添加动作后可开始训练'),
                                        ),
                                      if (current[i].exercises.isNotEmpty)
                                        ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: const Text('查看动作配置'),
                                          children: [
                                            for (
                                              var j = 0;
                                              j < current[i].exercises.length;
                                              j++
                                            )
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  child: Text(
                                                    '${j + 1}. ${current[i].exercises[j].name}\n${current[i].exercises[j].targetSets} 组 · 组间休息 ${current[i].exercises[j].restBetweenSetsSeconds} 秒\n动作后休息 ${current[i].exercises[j].restAfterExerciseSeconds} 秒 · 重量 ${current[i].exercises[j].defaultWeightKg == null ? '未设置' : '${current[i].exercises[j].defaultWeightKg} kg'}',
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      message!,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (current == null) ...[
                  AppButton(
                    label: '从文件选择',
                    primary: false,
                    onPressed: busy ? null : pick,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: '预览计划',
                    onPressed: busy
                        ? null
                        : () => perform(() => prepare(input.text)),
                  ),
                ] else ...[
                  AppButton(
                    label: '重新选择',
                    primary: false,
                    onPressed: busy ? null : reset,
                  ),
                  const SizedBox(height: 12),
                  AppButton(label: '确认导入', onPressed: busy ? null : confirm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
