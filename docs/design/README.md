# SetTrace 当前设计：A · 专注工具

| 项目 | 状态 |
| --- | --- |
| 设计版本 | `focus-a-2026-10-14` |
| 当前方向 | A · 专注工具；替代旧版视觉与布局方案 |
| 功能基线 | 应用 `0.1.3+5`，提交 `da18d62` |
| 本次交付 | A 方案 Flutter 实施、分阶段回归与 Android 验收证据 |
| 应用实施 | **已实施并归档**；见[实施报告](../qa/focus-a-redesign-acceptance.md) |
| 后续授权 | 规划、实施、主规格同步及归档已由用户授权完成；Git 提交和发布仍需对应授权 |

设计资料整理完成后，用户已明确要求规划并实施 `redesign-ui-focus`。当前 Flutter 实施及验证结果见[实施报告](../qa/focus-a-redesign-acceptance.md)；各项设备与证据边界以报告为准。五份主规格已同步，变更已于 2026-10-15 [归档](../../openspec/changes/archive/2026-10-15-redesign-ui-focus/README.md)；尚未执行 Git 提交或发布。

用户后续明确请求某项规划或开发工作，本身即授权其明确要求的范围，无需重复询问；授权不自动扩展到未要求的下一阶段。

## 阅读入口

代理处理 SetTrace UI 相关工作时，先实际读取下列 Markdown；仅知道路径、浏览图片或运行原型不等于已读取规范。

1. [主规范：视觉、组件与 Flutter 映射](SetTrace_UI_Design_System_and_Flutter_Spec.md)。
2. [页面与状态：29 个页面、14 类弹窗及功能覆盖](screens-and-states.md)。
3. [交互规范：可见条件、状态转换、返回与错误处理](interaction-spec.md)。
4. [验收标准：可检查的设计与实现要求](acceptance-checklist.md)。
5. 按所涉及能力读取 [现有 OpenSpec 规格](../../openspec/specs/)、当前源代码及对应验收记录。现有能力包括 `training-plans`、`workout-session`、`workout-history`、`app-experience`、`app-localization`。
6. 打开 [完整设计稿及模拟原型](prototype/SetTrace-Focus.html) 对照画面。原型不依赖网络或外部资源，可直接用浏览器打开。

## 依据与冲突处理

- **功能和数据含义**沿用现有 OpenSpec 规格及已确认的业务规则；发现代码与规格不一致，明确报告，不能借重设计静默修改业务。
- **目标视觉与交互呈现**以本目录当前 Markdown 为准，HTML、PNG 和 SVG用于对照；Flutter 实施状态由当前变更和验收报告记录；静态稿不能代替运行证据。
- Markdown 与示意图不一致时，使用 Markdown 中的明确规则，并记录画面差异；不根据示例推导新功能、默认值或数据校验。
- 旧设计仅在 [历史归档](archive/legacy-2026-10-14/README.md) 中供追溯。旧版 Figma 页面、旧稿的颜色、Picker 排他要求、备注和预计时长等示意，不再指导新的 UI 工作。
- 后续如确需修改既有行为要求，先说明冲突并等待用户确认，再在获批范围内通过 OpenSpec 规划；本次不改业务规格以迎合示意图。

### 已消除的两处歧义

1. `X01` 选中两个计划表示用户取消选择后的**示例状态**。正式导出流程仍默认全选；空选择禁止复制和保存。
2. A 方案增加显式加减操作以提高可发现性，同时保留现有规格要求的 Picker 滑动、有效档位吸附和跨档轻反馈。HTML 仅模拟按钮，不证明 Flutter 的 Picker 手势已实现或取消。

## 视觉资料

- [训练流程总览](previews/overview.png)。
- 计划：[浅色中文](previews/plans-light-zh.png) / [深色英文](previews/plans-dark-en.png)。
- 训练与休息：[浅色中文](previews/training-light-zh.png) / [深色英文](previews/training-dark-en.png)。
- 本次编辑与换序：[浅色中文](previews/session-tools-light-zh.png) / [深色英文](previews/session-tools-dark-en.png)。
- 导入导出：[浅色中文](previews/transfer-light-zh.png) / [深色英文](previews/transfer-dark-en.png)。
- 历史与设置：[浅色中文](previews/history-settings-light-zh.png) / [深色英文](previews/history-settings-dark-en.png)。
- 弹窗：[浅色中文](previews/dialogs-light-zh.png) / [深色英文](previews/dialogs-dark-en.png)。
- 适配：[浅色中文](previews/adaptation-light-zh.png) / [深色英文](previews/adaptation-dark-en.png)。
- [SVG 导入包](exports/SetTrace-Focus-SVG.zip)：222 个矢量文件，包含页面与弹窗的四种外观／语言组合、长内容展开稿和补充样本；不是 222 个独立功能页面。`*-full.svg` 是完整滚动内容，不是设备屏幕高度。
- 应用图标维持本目录原图标资源，不在本次视觉替换范围内。
- 当前选定的品牌方向为 **A · 组间节奏（三线 / 深墨绿）**，正式设计见[最终品牌设计](settrace-brand-final/README.md)与[使用规范](settrace-brand-final/design-guide.md)，包含轮廓 SVG、透明 PNG、横竖 Logo、分层图标源文件和小尺寸导出；已按用户要求替换 Android 启动器资源，构建结果及限制见[图标接入核验](android-icon-integration.md)。[五方向草图](logo-exploration-abcde/index.html)和后续配色讨论稿保留供追溯。此前的[错位训练记录](app-icon-record-stack.md)与[哑铃方案](app-icon-package.md)为未选用的早期候选。

## 原型与 Figma 的边界

截至本设计版本，原 Figma 文件因 Starter MCP 额度限制未更新为这套完整稿。旧文件中的 A/B 概念页不能替代本目录的新规范。SVG 可导入为图形与文本，但不携带 Figma 原生组件、变量、自动布局或原型连接。

HTML 是浏览器中的静态设计与模拟交互，不执行真实剪贴板、文件、授权、通知或数据库操作；成功提示和训练数据均为示例。原型对默认选择、计划排序持久化、系统设置、返回栈、主题偏好与数据写入的简化不能当作产品规则。系统字体回退和浏览器字号样本也不等同于 Flutter 字体或 Android 适配已验收。

原型中的“动作名称随界面语言保持原文”、固定主动作、长文换行等用于说明目标效果。实际 ARB 文案、单位和时间格式、系统控件、屏幕阅读器与业务状态仍按文字规范及既有能力实施。

## 验证证据

[设计资料核验说明](verification/README.md)区分浏览器原型检查、文档接入检查与 Flutter 实施验收。已有 Android 功能证据仍位于 `docs/qa/`，不因本次设计更新改写。

文档来源：初版 `5570b90`；本次换序 `dfe28f0`；计划传输 `7bf1f03`；记录删除 `00ef2a3`；本地化 `31a8d8f` / `e41967c`；提醒与跳过 `da18d62`。图像对应各能力的最新可用验收批次，不宣称每张截图都来自同一提交。

## 关于与首次说明增量

`add-app-about-and-first-run-notice` 在既有 A 方案上补充 C05（设置底部关于）、D15（首次说明）、D16（重看说明）和计划列表图标。主题、组件与品牌保持现行规范，新增交互见 INT-11、验收见 FLOW-17–19 / DATA-01。实施结果与已验证平台见 [独立验收记录](../qa/app-about-notice-acceptance.md)，不改写早期重设计证据。

本增量已于 2026-10-15 同步 `app-experience`／`app-localization` 主规格并[归档](../../openspec/changes/archive/2026-10-15-add-app-about-and-first-run-notice/README.md)，21/21 项任务完成；未执行 Git 提交或发布。

## 主题色增量

`add-theme-color-presets` 在 A 方案上增加设置内即时主题色选择：青色（默认）、蓝色、紫色、石墨，深浅配对且独立于明暗模式。卡片、配色和状态规则已补充至主规范第 10 节、C01/C02/C04 与 INT-10；检查见 COLOR-01–05，实际验证范围见 [主题色验收](../qa/theme-color-presets-acceptance.md)。已于 2026-10-15 同步 `app-experience`／`app-localization` 主规格并[归档](../../openspec/changes/archive/2026-10-15-add-theme-color-presets/README.md)，16/16 项任务完成；未执行 Git 提交或发布。
