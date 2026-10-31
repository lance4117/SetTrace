# SetTrace 备份与恢复 · UI 设计

设计日期：2026-10-16。沿用 `focus-a-2026-10-14`（A · 专注工具）及现有四主题色增量。

这是用户要求的备份 UI 设计交付，包含页面、交互演示、双语文案、异常状态和原型核验；OpenSpec 变更 `add-full-data-backup-restore` 已完成代码实现，三个主规格已同步并[归档](../../../openspec/changes/archive/2026-10-17-add-full-data-backup-restore/README.md)，43/45项完成，设备人工及故障验收两项保持未完成。实施证据见[独立验收记录](../../qa/backup-restore-acceptance.md)，本目录原有核验仍仅代表 HTML 原型。

- [可点击设计稿](index.html)：左侧选择页面，右侧模拟文件选择与处理结果；顶部切换中英文、浅深色、四主题色、屏幕尺寸和字号。
- [交互与状态规范](backup-ui-spec.md)：页面编号、文案、保护和撤回规则、接入与验收边界。
- [关键画面总览](previews/overview-light-zh.png)、[设计工作台](previews/design-workspace.png)、[恢复全流程](previews/restore-flow-light-zh.png)。
- [原型核验结果](verification/qa-results.json)：仅 HTML，不代表 Flutter、Android 文件操作、数据库恢复或真实卸载／换机已通过。

## 已确认方向

1. 首版处理防丢失与换机，提供完整备份和恢复，自动同步留到后续。
2. 允许已有数据的设备整份恢复；替换前保存并校验恢复前副本。
3. 失败保留现有数据；恢复后可以撤回，撤回前也保护当下数据。

## 已纳入获批提案的默认规则

存在活动训练时先引导处理；备份包含可迁移设置；恢复设置默认勾选但可取消；外部备份默认保存公共 Downloads；恢复前副本存于应用内，不自动清理，支持逐份导出和确认删除。获批变更已按这些规则实施，尚未发布，详见规范与独立验收。

## 原型边界

所有数量、时间、文件、大小与版本均为示例。原型只改变浏览器内存中的演示状态，刷新可重置；不访问真实文件、不替换数据库、不申请权限、不联网。

系统文件选择器由右侧评审工具模拟返回结果，应用画面不仿画 Android 文件窗口。处理中由评审工具推进，不靠假定耗时自动宣告成功。已有训练、记录和计划导入仅展示接入说明。

本目录独立于已实施主设计稿，不将旧规格与验收记录改写成已具有备份功能。

## 依据与文件

依据：[设计入口](../README.md)、[主规范](../SetTrace_UI_Design_System_and_Flutter_Spec.md)、[页面清单](../screens-and-states.md)、[交互规则](../interaction-spec.md)、[验收标准](../acceptance-checklist.md)，以及相关主规格、数据库和设置代码。

用户指定的 `ui-ux-pro-max` 用于后果确认、错误恢复、触控、文本缩放、焦点及减少动画审查。通用健身查询返回橙色营销方向，与现有产品不匹配，未采用或持久化；缩小查询后仅采用简洁、留白和功能优先原则。颜色、字体、Material 线框语义和组件尺寸以项目规范为准。

`index.html`、`prototype.css`、`prototype.js` 为离线设计原型；`verification/verify-design.cjs` 为原型交互与适配核验脚本，使用本机已有 Playwright 和 Chrome，不新增依赖。
