# SetTrace 当前 UI 参考

当前资料按源码 `306b9bc`、应用 **0.3.1+12** 整理。正式画面来源和验证方式逐项标注，旧稿见 [归档](../archive/README.md)。

1. [打开离线 UI 图册](overview.html)：按功能、语言、明暗和来源筛选。
2. [页面与状态完整目录](screen-inventory.md)：入口、条件、操作、返回与实施映射。
3. [视觉与组件规范](specs/visual-and-components.md)、[交互规范](specs/interaction-spec.md)、[验收标准](specs/acceptance-checklist.md)。
4. 专项：[备份](specs/features/backup.md)、[诊断](specs/features/diagnostics.md)、[记录统计](specs/features/history-summary.md)。
5. [构建及截图清单](manifest.json)、[覆盖与待验](verification/coverage.md)、[验证说明](verification/README.md)、[差异](verification/discrepancies.md)。
6. [REF-01–08 资料交付报告](verification/ref-report.md)、[逐组当前观察](verification/current-observations.md)、[文档完整性检查](verification/documentation-checks.json)。

APK SHA-256：`ebd9b53b25f51af01ea10de5318734ec031b09956e9e448a622edd4dcb6bbd98`。本次重新构建，与历史同版本包分别记录。

图册含 120 张 release Android 原帧、476 张测试渲染。测试图使用当前生产组件、隔离 SQLite 和受控平台，明确标记，不能替代真实 Android 写入／提醒验证。未采集分支与未验设备条件在目录中保留。

## 资料优先级

业务含义以现有 OpenSpec 主规格为准；当前实现以标识的源码／构建为准；本目录 Markdown 解释当前视觉与交互。发现冲突同时登记要求和实际，不静默改变业务。旧原型及历史 QA 只证明各自日期与范围。

## 刷新方式

1. 固定最新确认源码及应用改动范围，保存旧清单和当前参考到按日期命名的归档。
2. 用 `tool/ui_reference_dev.ps1` 核实 D 盘环境并重建 release；记录源码、源文件指纹、APK 哈希及实际安装版本。
3. 在只读 AVD 中采集实际原帧；运行明确标注的参考截图测试和对应既有回归。所有输出留在 D 盘。
4. 更新页面目录、manifest 与结果；通过截图哈希、引用、覆盖和变更范围检查后切换入口。
5. 未执行项保持 pending。不得把旧截图改名、新版本号或代码存在当作复验通过。

采集工具见项目 `tool/ui_reference_android.py`；生成图册使用 `python -B tool/ui_reference_publish.py`。Widget 采集须显式设置 `UI_REFERENCE_OUTPUT`，默认运行测试不会生成参考图片。

## OpenSpec 归档

`consolidate-design-and-current-ui` 已于 2026-10-31 按用户请求[归档](../../../openspec/changes/archive/2026-10-31-consolidate-design-and-current-ui/tasks.md)，30/30项完成，无规格增量。[归档记录](verification/openspec-archive.json)保存原件哈希；REF报告是归档前的实施验收快照，归档不改变其中的产品待验条件。未执行Git提交或发布。
