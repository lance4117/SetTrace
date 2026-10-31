# Design

## Context

动机与范围见 [proposal.md](proposal.md)。本变更涉及文件迁移、旧引用兼容、构建身份与证据组织，因此创建设计文档；产品行为没有变更，规格增量已明确跳过。

规划时的实现基线为 `306b9bc`、`0.3.1+12`，当前设计由 `focus-a-2026-10-14` 与后续增量构成。已确认的事实：

- 设计首页、页面清单、主规范及验收清单仍将诊断标为待实现；`diagnostics/implementation-handoff.md`、`lib/features/diagnostics/diagnostics_pages.dart` 和 2026-10-24 验收已记录实现。
- `history_page.dart` 已采用两张次数卡、通栏月度汇总、最近训练、月份、记录的顺序；旧总览中的历史页不能代表当前实现。
- `rest_reminder_controls.dart` 已呈现系统通知音、独立试听和系统设置；旧三音面板 D19 已被替代。
- `work/ui-sketches` 的确认 HTML、浅深预览及检查 JSON 与 `docs/design/history-summary` 对应四份文件哈希一致；另有未选布局和检查脚本，需要单独保留来源。
- `tool/generate_android_icons.py` 固定读取 `docs/design/settrace-brand-final`；历史 QA 和已归档变更也引用旧设计路径。
- 探索运行的现有最新 APK SHA-256 为 `d76067c8ef87bd35a0d1f02d96552d635383305186a74b9f6c88b52885186a31`，旧后台提醒验收包为 `762a13ecf51c05c5a73b022ca71981d42a075905f4be9fbe55fb254af4a32169`。相同版本号不证明二者等同；探索未保存截图，也未建立源码到 APK 的完整构建链。

现有主规格 `app-experience` 的导航、主题、状态、数据范围和返回要求已经覆盖应用行为。本次将这些要求与实际实现、截图和已有测试关联，不修改它们。

## Goals / Non-Goals

**Goals:**

- 当前资料有唯一主版本，历史稿可追溯，工作目录不再承担正式设计入口。
- 每个现有页面和分支都有目录条目，常规可达界面有当前构建的实际画面，无法安全采集的分支明确记录缺口。
- 分别表达设计依据、当前实现、观察结果与验证范围；更新规范时保留既有页面、INT 和验收编号。
- 图册可离线浏览，核心参考材料及验证摘要在仓库中自包含；机器路径只作环境记录。

**Non-Goals:**

- 不重新设计 UI、改变品牌、增加功能或调整业务／数据库／格式／权限／提醒策略。
- 不为取得截图修改生产界面、引入运行依赖、制造生产故障或清理用户数据。
- 不把所有历史设备验收重新做一遍；真机、TalkBack、厂商后台、听感和长时资源测试保持独立边界。
- 不在本次规划阶段执行迁移、构建、采集、主规格同步、归档 OpenSpec 变更、Git 提交或发布。

## Decisions

### 1. 采用 current-ui 与 archive 两个主要分区

`docs/design/README.md` 只提供当前入口、基线、历史入口及资料优先级。当前资料集中为：

```text
docs/design/
  README.md
  current-ui/
    README.md
    overview.html
    screen-inventory.md
    manifest.json
    specs/
      visual-and-components.md
      interaction-spec.md
      acceptance-checklist.md
      features/
        backup.md
        diagnostics.md
        history-summary.md
    screenshots/
      plans/ workout/ history/ settings/ transfer/ backup/ diagnostics/ about/
    assets/brand/
    verification/
      README.md
      results.json
      coverage.md
      discrepancies.md
      documentation-checks.json
  archive/
    README.md
    migration-manifest.json
    <date>-<topic>/
```

旧路径仅在历史引用确实需要时保留小型兼容入口，不再保存独立的当前规范。尚有效但未实现的目标在目录中标注 `planned`，与 `implemented` 分开，不仅因未实现就判定为过期。

选择原因：保留使用者熟悉的根入口，消除“基线加多个增量各自最新”的查阅负担。考虑过继续在原子目录补充索引，但它会保留多处当前主版本和过期标题，无法完成本次统一整理。

### 2. 先记录迁移映射，再归档和发布新入口

`archive/migration-manifest.json` 对每个来源文件记录原路径、原 SHA-256、分类、目标路径、归档原因、替代条目和重复关系。日期使用实施当天的 Asia/Hong_Kong 日期，不预设为规划日期。

| 来源 | 当前有效部分 | 历史处理 |
| --- | --- | --- |
| 四份根主文档与设计 README | 按当前实现整合视觉、交互、状态和验收说明 | 归档原版，保留版本来源和编号 |
| backup、diagnostics、history-summary | 有效文字并入专项规范，运行状态以实现和证据核对 | 旧草图、原型、导出和原型核验按批次归档 |
| prototype、previews、exports、verification | 当前图册及新验证报告另行生成 | 原 focus-a 模拟原型、拼图、SVG 包和旧核验归档 |
| settrace-brand-final | 正式 SVG／PNG 母版、分层源文件、使用规范及必要小尺寸导出进入 assets/brand | 候选、重复展示包、tmp、运行时复制和打包中间文件归档；独有源文件不遗漏 |
| logo-exploration-abcde、icon-concepts | 确认被正式使用的源文件按依赖核对 | 其余候选及配色讨论稿归档 |
| work/ui-sketches | 已确认内容与现行规范建立来源映射 | 独有布局、脚本和预览归档；四份重复文件映射到同哈希主副本 |
| 既有 archive | 原档内容与来源保留 | 仅在外层增加归档索引，不改写已有历史内容 |

原始归档按内容保全；新规范在新路径重写。去重只合并哈希相同内容，并记录全部来源。归档旧稿不代表其中所有规则都失效；仍适用的规则已经进入当前规范。

考虑过只按修改日期筛选最新文件，但文件时间不能证明确认状态、实施状态或内容独有性，因此采用来源、哈希、依赖和实际实现共同分类。

### 3. 保护历史引用和运行资源

- 扫描 Markdown／HTML 链接、JSON 清单、工具常量和 OpenSpec 当前指引，生成旧路径到新路径的映射。
- 项目 README、当前文档和 `openspec/config.yaml` 改为新主入口；保留其既有业务与授权约束，仅更新路径及过期项目事实。
- 历史 `docs/qa` 和 `openspec/changes/archive` 文件、测试日志、截图、样包及已归档任务状态保持原样。它们链接的原设计 Markdown 必要时保留明确标记的兼容页，指向对应历史原版，并另给当前资料链接。
- 被历史报告直接引用的非 Markdown 证据若迁移，保留逐字节相同的兼容副本并登记原因；不使用仅本机有效的目录联接。历史文件原有锚点应在兼容页提供落点；新增归档索引提供原路径、原版与当前替代的对应关系。
- 归档原文不批量替换内容以迎合新路径。其相对链接按原来源基准记录，在归档索引中补充可达目标；历史已有失效链接单列，不冒充本次迁移成功修复。
- `generate_android_icons.py` 仅更新母版读取路径及相应文档；`assets/brand` 和 Android 已生成的运行资源保持字节不变，不通过重新生成来验证路径。
- `work/ui-sketches/check-history-layout.cjs` 写死 C 盘运行时位置，只归档、不直接运行；需要的新资料工具采用已确认的 D 盘依赖路径。

选择少量有依据的兼容文件，是为了同时满足当前目录整洁和历史证据可追溯；不采用改写历史报告或复制整套旧设计回原位置的方案。

### 4. 用固定源码和构建建立当前画面身份

实施启动时再次读取版本、HEAD 和应用源文件状态。以最新确认的应用源码提交为基线，记录与规划参考 `306b9bc` 的变化；正常更新基线不固定停留在旧包。若出现无关的未提交应用代码或相互冲突的基线，不覆盖或重置，先明确来源范围。

由该基线重新构建现有 release 目标 `lib/main.dart`，记录源码提交、相关源文件／配置指纹、应用源码是否有补丁、仓库中仅文档的改动、SDK 版本、构建命令、APK SHA-256、安装后版本／构建号及设备 API／ABI。文档整理导致的 dirty 状态不冒充应用代码有修改，也不虚报整个仓库 clean。

在现有 `D:\ProgramData\Android_AVD` 设备的隔离只读运行中安装同一 APK，禁用快照保存。仅修改该临时实例中的样本数据与设置；不操作真实手机或原有持久应用数据。SDK 固定 `D:\ProgramData\Android_SDK`，缓存使用 `D:\ProgramData\DevCache`，TEMP/TMP 使用 `D:\ProgramData\DevTemp\settrace-ui-reference`；原始构建、日志及暂存资料在项目 `build/ui-reference/<run-id>/`。每次启动／构建前确认实际路径可用，工具缺失时说明阻碍，不下载、不回退到 C 盘。

保留必要的可移植构建与采集摘要至 `current-ui/verification`；大型 APK、映射和全量日志留在 D 盘构建目录，清单给出哈希和位置，不把这些忽略文件作为唯一通过依据。

考虑过直接沿用同版本现有 APK，但已观察到相同 `0.3.1+12` 下编译产物不同，必须重新建立来源链。探索内存画面只作为已知线索，不充当正式截图证据。

### 5. 页面、状态与实施映射覆盖完整目录

`screen-inventory.md` 是完整索引，每个条目至少包含稳定 ID、名称、实现状态、入口、前置条件、可用操作、返回／取消、失败反馈、实现位置、INT／验收编号、截图和验证状态。保留原 ID；许可等未编号分支增加明确后缀或新条目，不重用已有 ID，不把四种语言／外观计作四个功能。

| 范围 | 实施位置 | 对应交互／验收 |
| --- | --- | --- |
| P01–P06、D01–D04/D10 | plans_page.dart、exercise_editor_page.dart、step_picker.dart | INT-01/02/07；FLOW-01/02、VIS-04/06 |
| W01–W06、S01–S04、D05–D09/D14/D17/D18、C03 | workout_page.dart、session_order_sheet.dart、rest_reminder_dialog.dart、rest_alerts | INT-03–07/12；FLOW-03–09/14–16、REM-01–06 |
| X01–X04、D12 | plan_transfer_pages.dart | INT-08；FLOW-10/11 |
| H01–H05、D13 及删除确认 | history_page.dart、history_summary_card.dart、history_stats.dart | INT-09；FLOW-12/13、HIST-01–06 |
| C01–C05、系统声音及主题色分支 | settings_page.dart、theme_color_section.dart、rest_reminder_controls.dart、about_section.dart | INT-10–12；COLOR-01–05、REM-04/06、LOGUI-01 |
| D15/D16、许可摘要／列表／详情 | app_notice_dialog.dart、licenses_page.dart | INT-11；FLOW-17–19、DATA-01 |
| B00–B20、既有子状态和 E01–E14 | backup_pages.dart、backup_coordinator.dart | BK 系列、VIS-01–05、ADAPT-01–07 |
| L00–L08、LD01、LE01/LE02 及分支 | diagnostics_pages.dart、diagnostics_controller.dart、main.dart | INT-13；LOGUI-01–12 |
| A01–A05、共享组件与两语 | app_theme.dart、theme_color_preset.dart、app_task_layout.dart、lib/l10n | VIS-01–06、ADAPT-01–07 |

更新规范时说明计划默认配置与本次快照、结束休息与跳过剩余组、撤销完成与恢复跳过的区别。组数、休息、统计、默认全选、Picker 和权限规则仍以现有规格为依据。当前实现与要求不一致时两者并列记录到差异清单，不把实现缺陷改写为新设计要求。

### 6. 截图覆盖与图册展示

- 常规可达的每个独立页面、菜单和关键确认状态均采集当前构建画面；主要页面完成中文／英文与浅色／深色四组合，默认主题色青色，以 360dp、1.0 字号为主展示。
- 430dp、1.3／1.6 字号、长计划／动作名、长文件名、键盘、横屏短屏、约 768dp 平板、其他三种主题色及减少动态效果作为补充验证矩阵，逐项记录页面和实际覆盖，不宣称所有轴的笛卡尔积全部通过。
- 设置、许可、备份等长页面保存完整分段滚动截图，包含底部及固定操作区。长图如由分段拼接得到，明确标为派生参考并列出原帧；不得伪造为一张原始系统截图。
- 加载、提交、失败、受限、启动故障与未知结果均进入索引。优先使用安全可复现的现有测试入口；必要的测试夹具或截图 harness 仅在测试范围运行，不修改生产代码。测试渲染截图标记 `widget-test`／`integration-harness`，不能列为 release 正常运行截图。
- 无法安全触发的分支保留完整文字、代码／测试映射、未采集原因与后续条件；不从旧原型补图，也不人为填满磁盘、破坏生产库以制造状态。
- `overview.html` 直接引用本目录截图及清单的静态数据，可按功能、页面、语言、主题和状态浏览，并显示构建身份、缺口和验证标签。采用相对路径和本地内嵌清单，直接打开即可使用，无网络、服务端或在线字体依赖。

采用实际截图加文字索引，不重新制作一套看似当前应用的模拟交互原型；这与用户要参考最新实装 UI 的目标一致。

### 7. 清单、验证记录与维护契约

`manifest.json` 具有格式版本和唯一 `baseline_id`，记录源码与构建身份、生成时间和时区、设计来源、路径映射及截图条目。每条截图包含 `screen_id`、`state_id`、相对路径、文件 SHA-256、`baseline_id`、采集方式、语言、明暗、主题色、像素尺寸、density／逻辑宽高、字号、方向、前置样本和采集时间。测试夹具使用合成数据，用户内容只作示例，不写成业务默认值。

`verification/results.json` 每条记录包含页面／状态、验收 ID、预期、观察、实现／测试路径、证据路径、构建／设备环境、验证方式与结果。实现状态和验证状态分别建模：

| 验证结果 | 使用条件 |
| --- | --- |
| passed-current | 当前基线及该环境有实际执行结果和落盘证据 |
| passed-historical | 旧报告在原构建／原设备通过，本次尚未复验 |
| pending | 已实现但缺本次执行证据，或需要指定设备／人工条件 |
| failed | 实际结果不符要求，记录复现条件和影响 |
| not-implemented / not-applicable | 分别说明缺失实现，或当前前置条件下该项不适用的理由 |

另以 `implemented/planned/unknown` 标记实现状态。代码存在、Widget 通过、模拟器观察、真机人工观察分别记录，静态色值计算只能证明该颜色对的计算结果，不能替代完整状态检查。读取失败不得记作真空，导出预览不得证明写入成功，停止提醒不得证明完成训练，系统通知请求不得证明用户听见。

已有 `history_summary_ui_test.dart`、`rest_reminder_ui_test.dart`、备份及诊断测试按对应项复用，只有新基线重新执行才记为当前通过。使用 `ui-ux-pro-max` 已核实的 Flutter 约束布局、TextScaler、Android 48dp 触控、语义、对比度和减少动态效果指导审查，沿用项目主题及 Material 图标，不生成替代配色或安装依赖。

后续刷新流程写入 current-ui/README：选择基线、归档上一版、构建与采集、更新清单和结果、核对链接／哈希、替换当前入口。更新文档不能顺带把 pending 改成 passed。

### 8. 交付验收编号

以下是本次资料交付检查，不新增或改写产品主规格：

| ID | 完成条件 | 既有依据 |
| --- | --- | --- |
| REF-01 | 唯一入口可进入当前与历史；旧入口无相互竞争的当前正文 | DOC-02/04/05 |
| REF-02 | 来源逐文件映射，归档哈希一致，去重可追溯且无独有文件遗失 | DOC-01/06 |
| REF-03 | 页面／状态索引覆盖表内全部范围，未采集项有显式缺口，编号无丢失 | DOC-03、FLOW、BK、LOGUI |
| REF-04 | 当前画面可追溯到固定源码、构建与安装；历史包和测试画面有独立身份 | VIS、FLOW、REM |
| REF-05 | 正常可达页面与关键确认有截图；四组合主页面及补充适配矩阵有实际覆盖记录 | VIS-01–06、ADAPT-01–07 |
| REF-06 | 每个验证结论具有预期、实际、范围和证据；遗留真机／故障待验仍可见 | FLOW、HIST、BK、LOGUI |
| REF-07 | 图册离线可用；图片、清单、当前链接和必要历史兼容引用可达，工具读取母版路径有效 | DOC-02/04/05 |
| REF-08 | 应用代码、业务规格、运行品牌资源和历史证据无非预期改动；新问题只登记 | DOC-06、本次授权范围 |

目录整理可完成而产品待验项继续 pending；REF-05 自身未完成的必需截图任务不得因创建了占位条目而勾选。coverage.md 分别统计页面已登记、release 截图已采集、测试渲染已采集和检查已执行，缺口列出具体条目，不使用“完整通过”的总称掩盖边界。

## Risks / Trade-offs

- [旧标题和验收正文混杂] → 依据实现／实际运行／原报告逐条标记，原稿归档；冲突保留可见，不静默改变业务。
- [迁移破坏历史链接或母版工具] → 先生成依赖映射，使用最小兼容入口及路径更新，校验后再切换主入口。
- [版本相同但构建不同] → 源码与 APK 双身份、截图哈希和安装核对；旧证据按原构建展示。
- [页面多、矩阵庞大] → 完整状态索引与主页面四组合优先，补充矩阵明确覆盖，无法触发状态留缺口；任务完成与产品验证完成分别表达。
- [模拟器环境干扰结果] → 记录 API／ABI、逻辑尺寸和宿主限制；启动曾出现的 System UI 无响应只作环境事件，不推定为应用缺陷或忽略证据污染。
- [为拍图更改生产行为或伤及数据] → 隔离只读 AVD 与合成夹具，生产代码保持，测试截图显式标注来源。
- [归档原文字节保全与相对链接可读性冲突] → 保留原文件哈希，索引提供来源基准与可达替代；不为美化历史而改写证据。
- [图册及截图增加仓库体积] → 保留必要原帧和当前参考，派生图注明来源；大型构建与全量运行日志留在 D 盘 build，发布的参考不依赖远程资源。

## Migration Plan

1. 核实实施时基线、D 盘路径及允许修改范围，生成文件／依赖／哈希清单；保留用户已有改动。
2. 按分类规则保存历史原件，建立归档索引和最小兼容映射；整合当前文字规范与完整状态目录。
3. 重新构建并核对安装身份，在隔离模拟器按目录采集原帧和验证结果，生成清单及离线图册。
4. 核对原有测试及必要重跑，整理差异与未验项；产出资料完整性和适配覆盖报告。
5. 校验通过后切换根入口、项目 README、OpenSpec 阅读指引和依赖工具路径，移除工作目录的正式设计职责，关闭临时模拟器且不保存快照。
6. 交付 REF-01–08 结果与全部未完成项，由用户审阅；不自动提交、发布或执行 OpenSpec 归档。

回退按 migration-manifest 恢复本次移动的文件路径、入口和工具常量，只处理本次变更，不使用整仓库 reset 或覆盖用户改动。原件及哈希在切换前已经保全；运行应用及数据库不属于迁移对象。若资料完整性检查失败，保留暂存和清晰缺口，不发布一个伪装完整的 current-ui。
