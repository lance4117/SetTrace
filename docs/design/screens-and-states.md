# A 方案：页面、状态与功能覆盖

版本 `focus-a-2026-10-14`。本文件为设计清单，不是实施任务表。视觉值见[主规范](SetTrace_UI_Design_System_and_Flutter_Spec.md)，条件与状态转换见[交互规范](interaction-spec.md)，检查见[验收标准](acceptance-checklist.md)。

29 个主要画面使用稳定编号；Light / Dark 与中文 / English 是同一画面的适配，不增加独立功能数量。文中规则是设计目标；实际 Flutter 覆盖和限制见[实施报告](../qa/focus-a-redesign-acceptance.md)，不能仅凭示意图判定通过。完整稿在[原型](prototype/SetTrace-Focus.html)，可通过界面语言／外观控制及目录查看。

## 1. 计划与准备（P01–P06）

参考：[浅色](previews/plans-light-zh.png) / [深色](previews/plans-dark-en.png)。代码依据 `lib/features/plans/plans_page.dart`、`exercise_editor_page.dart`。

| ID / 原型定位 | 画面与信息 | 主操作与补充规则 |
| --- | --- | --- |
| [P01](prototype/SetTrace-Focus.html#screen-home) | 计划首页，活动会话卡片、计划摘要 | 活动会话存在时优先“继续训练”；“新建”与导入导出更多菜单共存；卡片进入详情 |
| [P02](prototype/SetTrace-Focus.html#screen-plan) | 计划详情，动作顺序、组数、休息摘要 | 开始进入准备；添加／编辑动作、改名、删除、默认换序可达；默认换序不受本次训练锁定规则限制 |
| [P03](prototype/SetTrace-Focus.html#screen-exercise) | 添加／编辑动作，名称、组数、两类休息、可选重量 | 保存及适用时删除；数字显示、滑动 Picker 与显式加减共用规则；键盘不遮挡字段和按钮 |
| [P04](prototype/SetTrace-Focus.html#screen-prep) | 开始前预览计划、动作顺序与总组数 | 确认后才创建快照；发生单会话冲突时 D10；不显示预计训练时长 |
| [P05](prototype/SetTrace-Focus.html#screen-home-empty) | 没有计划的首页 | 新建与导入均可达；导出禁用或说明无计划；仍有活动快照时保留继续入口，不因来源计划被删而丢失 |
| [P06](prototype/SetTrace-Focus.html#screen-plan-empty) | 已建计划没有动作 | 添加动作可用；开始训练禁用并说明原因；改名和删除仍可用 |

## 2. 训练与两类休息（W01–W06）

参考：[浅色](previews/training-light-zh.png) / [深色](previews/training-dark-en.png)。代码依据 `workout_page.dart`、`workout_models.dart`。

| ID / 原型定位 | 示例状态 | 必须表现的操作与含义 |
| --- | --- | --- |
| [W01](prototype/SetTrace-Focus.html#screen-active) | 当前待练第 3 / 4 组，当前动作实际完成 2 组 | 完成本组固定底部；查看动作、符合条件的更换下一动作、跳过剩余 2 组、撤销完成、结束可达；总进度只计真实完成 |
| [W02](prototype/SetTrace-Focus.html#screen-first) | 全场尚未完成任何组 | 不提供跳过剩余组、无效撤销或保存；可查看／调整符合条件的动作，结束使用 D07 |
| [W03](prototype/SetTrace-Focus.html#screen-rest) | 组间休息，接下来仍是当前动作 | 计时、−30 秒、＋30 秒、结束休息；符合条件时另有跳过剩余组；不是把“结束休息”叫作跳过动作 |
| [W04](prototype/SetTrace-Focus.html#screen-rest-between) | 动作间休息，下一动作尚未开始 | 明确“动作间休息”；当前目标和组数可读；更换下一动作保持绝对截止；无跳过剩余组入口 |
| [W05](prototype/SetTrace-Focus.html#screen-skipped) | 上个动作完成 2 / 4，剩余 2 组被跳过；下一动作待练 | 明确跳过对象和数量；独立恢复最近跳过；普通撤销仍只撤销真实完成；不会把实际 2 / 4 画成完成 4 / 4 |
| [W06](prototype/SetTrace-Focus.html#screen-finish-ready) | 所有组均已处理，实际完成 11 / 15，4 组跳过 | 可保存，但进度不是 100%；仍能恢复可撤销的跳过及完成记录，结束／放弃遵守确认规则 |

组数、休息时间、动作名、数量与训练日期均为示例，不是数据默认值。最多 100 组时使用摘要布局；主操作始终可达。

## 3. 本次训练工具（S01–S04）

参考：[浅色](previews/session-tools-light-zh.png) / [深色](previews/session-tools-dark-en.png)。代码依据 `session_order_sheet.dart`、`SessionExerciseEditorPage`。

| ID / 原型定位 | 画面 | 规则 |
| --- | --- | --- |
| [S01](prototype/SetTrace-Focus.html#screen-exercises) | 全部动作与编辑 | 全部动作按会话顺序，完成／进行中／待练／已跳过可区分；提供适用的本次编辑、剩余换序、独立恢复跳过；已跳过动作说明先恢复再编辑 |
| [S02](prototype/SetTrace-Focus.html#screen-order) | 调整剩余顺序 | 完成、部分完成、有跳过记录的位置锁定；可移动行有手柄及非拖动替代；草稿保存／取消明确，仅影响本次快照 |
| [S03](prototype/SetTrace-Focus.html#screen-choose-next) | 选择下一动作 | 当前尚未开始可被替换；已有完成组时只调整其后的待练顺序；候选数量不足时不给无效入口 |
| [S04](prototype/SetTrace-Focus.html#screen-session-edit) | 编辑本次配置 | 只编辑所选动作目标组数与两类休息；组数至少为 max(1, 已完成组数)；不新增名称、重量或次数编辑；成功返回原会话 |

P02 的计划默认排序与 S02 使用一致的排序表现，但数据范围和可移动限制不同。HTML 的排序草稿演示不能代替保存、取消、恢复与数据库事务规则。

## 4. 计划导入导出（X01–X04）

参考：[浅色](previews/transfer-light-zh.png) / [深色](previews/transfer-dark-en.png)。代码依据 `plan_transfer_pages.dart`；格式与范围见 [传输格式](../plan-transfer-format.md)。

| ID / 原型定位 | 画面 | 规则 |
| --- | --- | --- |
| [X01](prototype/SetTrace-Focus.html#screen-export) | 导出计划选择 | **进入时默认全选**；图中选中两个只是取消选择后的例子；全选／取消全选、所选数量、复制和文件保存都保留；空选择及执行中禁用两种输出 |
| [X02](prototype/SetTrace-Focus.html#screen-import) | 文本输入／主动粘贴／文件选择 | 不主动读取剪贴板；无内容不能预览；取消文件选择正常返回，不报成功或错误；读取、格式错误有可理解提示 |
| [X03](prototype/SetTrace-Focus.html#screen-preview) | 导入前预览、拟用名称 | 显示数量和新增副本含义、改名、完整配置展开入口、取消／重新选择／确认；同名不覆盖已有数据 |
| [X04](prototype/SetTrace-Focus.html#screen-expanded) | 展开完整动作配置 | 展示动作顺序、组数、两类休息及可选重量；长配置滚动，确认可达；字段校验或名称新冲突保留并更新预览，重新确认 |

导出仅含计划配置，复制／公共下载目录保存的结果来自实际操作；文件、文本使用同一既有格式。不能把 HTML 中省略的示例文本当有效导入内容，也不能将示例成功提示当平台操作已发生。

## 5. 记录与设置（H01–H05、C01–C04）

参考：[浅色](previews/history-settings-light-zh.png) / [深色](previews/history-settings-dark-en.png)。代码依据 `history_page.dart`、`history_stats.dart`、`settings_page.dart` 及提醒服务。

| ID / 原型定位 | 画面 | 规则 |
| --- | --- | --- |
| [H01](prototype/SetTrace-Focus.html#screen-history) | 月份历史与统计 | 本周／自然月次数、最近训练、所选月时长与实际完成组数；月份可切换；列表进入目标详情 |
| [H02](prototype/SetTrace-Focus.html#screen-detail) | 含跳过组的记录详情 | 名称、日期、时间、时长与真实完成比例；动作按最终快照顺序；逐组完成时间／跳过状态；删除从更多菜单进入 |
| [H03](prototype/SetTrace-Focus.html#screen-history-empty) | 所选历史月份为空 | 所选月时长／组数为零；自然周／月次数和最近训练仍按各自口径计算，不随所选月一并清零 |
| [H04](prototype/SetTrace-Focus.html#screen-detail-partial) | 提前保存，完成／跳过／未完成并存 | 三类组状态独立，不把待练组补成跳过或完成；已保存快照不受原计划改动影响 |
| [H05](prototype/SetTrace-Focus.html#screen-history-all-empty) | 没有任何已保存记录 | 相关次数、时长、完成组数均归零，最近训练暂无；不删除活动会话和计划 |
| [C01](prototype/SetTrace-Focus.html#screen-settings) | 主题、语言、提醒正常 | 系统／浅色／深色；English／中文；提醒开关和状态说明；持久化失败不伪报成功 |
| [C02](prototype/SetTrace-Focus.html#screen-settings-permissions) | 提醒能力受限 | 通知被拒绝或渠道禁用明确后台不可用；准时能力不足明确可能延迟；按实际能力显示对应系统设置入口，不能混为同一权限 |
| [C03](prototype/SetTrace-Focus.html#screen-notifications) | Android 提醒与返回示意 | 系统决定实际样式；自然到期提醒一次，不完成组；返回最新对应会话，结束／删除／失效目标不打开别的会话 |
| [C04](prototype/SetTrace-Focus.html#screen-settings-failed) | 调度或偏好保存失败 | 区分训练已保存与提醒失败；重试当前能力或偏好写入，休息截止不重置；提示实际状态 |

## 6. 弹窗与菜单样本（D01–D14）

参考：[浅色](previews/dialogs-light-zh.png) / [深色](previews/dialogs-dark-en.png)。共 14 类静态样本，并不限制运行时只能有 14 个弹层。原型中更多菜单、删除确认及条件分支还可点击查看；完整后果规则以文字为准。

| ID | 样本／触发 | 必须具备 |
| --- | --- | --- |
| D01 | 首页新建计划 | 标签、40 字符上限、非空校验、成功后关闭、失败保留；普通名称可重复 |
| D02 | 计划重命名 | 预填原名、同一校验规则、保存／取消 |
| D03 | 删除计划 | 目标名称、不可恢复；明确保留历史及活动快照 |
| D04 | 删除计划动作 | 目标动作及影响范围；不删除已有会话与历史快照 |
| D05 | 有实际完成组的结束 | 保存实际完成组／继续／放弃，放弃与主操作分隔 |
| D06 | 放弃已有完成记录 | 二次确认、不可恢复、保留计划和其他记录 |
| D07 | 零完成时结束 | 继续／放弃；不显示不可用保存，不额外重复放弃确认 |
| D08 | 跳过当前动作剩余组 | 动作、已完成／将跳过数量、不计实际完成、下一动作或结束后果 |
| D09 | 恢复最近一批跳过 | 具体动作和数量、回到该动作、保留全部真实完成组 |
| D10 | 开始新训练遇到活动会话 | 继续原训练或留在当前页；不提供静默覆盖 |
| D11 | 休息提醒授权前解释 | 说明后台／锁屏用途、系统权限、拒绝不影响训练；不伪造系统授权结果 |
| D12 | 首页计划更多菜单 | 导入／导出与新建共存；空首页可导入，导出禁用或说明原因 |
| D13 | 记录详情更多菜单 | 删除目标记录入口；随后确认必须显示记录名称、日期、不可恢复及统计更新 |
| D14 | 会话草稿过期 | 解释状态变化；重载／取消，保留真实完成记录，不将过期草稿直接覆盖 |

另需保留：计划详情改名／删除菜单、训练工具菜单、导入新冲突返回预览、字段错误、按钮提交中／禁用、删除成功后刷新失败、提醒关闭等状态。它们属于已有能力的呈现分支，不新增业务功能。

## 7. 适配样本（A01–A05）

| ID | 样本 | 目标 |
| --- | --- | --- |
| A01 | 360 dp 小屏 | 内容可滚动，无横向溢出，底部主操作独立 |
| A02 | 360 dp + 160% 字号 + 长英文动作名 | 完整换行，按钮增高、工具重排，不缩正文或裁断目标名 |
| A03 | 键盘弹出后的导入表单 | 焦点字段、错误与确认均可达；键盘外观由系统决定 |
| A04 | 740×390 横屏 | 主要任务与动作并排，短屏工具可滚动，尊重系统区域 |
| A05 | 约 768 dp 平板 | 上下文与当前任务双栏，正文宽度与触控目标受控 |

样本不是对所有 Android 设备或 Flutter 的通过报告；430 dp、字体缩放、读屏及真机仍按验收清单在后续获批实施后验证。

## 8. 功能来源与防遗漏映射

| 来源 | 覆盖画面 | 语义来源 |
| --- | --- | --- |
| 初版 `5570b90` | P01–P06、W01–W04、H01–H02、D01–D07、D10 | 计划、会话、历史主规格 |
| 本次换序 `dfe28f0` | S01–S04、W01/W04、D14 | `workout-session`；[换序验收](../qa/session-exercise-reordering-acceptance.md) |
| 计划传输 `7bf1f03` | X01–X04、D12 | `training-plans` / `app-experience`；[传输验收](../qa/plan-import-export-acceptance.md) |
| 删除历史 `00ef2a3` | H01–H05、D13 与删除确认 | `workout-history`；[删除验收](../qa/workout-history-delete-acceptance.md) |
| 本地化 `31a8d8f` / `e41967c` | 全画面、C01、A01–A05 | `app-localization`；[本地化验收](../qa/localization-acceptance.md) |
| 提醒与跳过 `da18d62` | W01–W06、H02/H04、C01–C04、D08/D09/D11 | `workout-session` / `workout-history` / `app-experience`；[提醒与跳过验收](../qa/rest-alerts-and-skipping-acceptance.md) |

后续获批规划如引用某个 ID，应同时引用相应交互与验收编号，不能只以“按新 UI 修改”代替功能覆盖说明。

## 9. 关于与首次说明增量（2026-10-15）

本节由 `add-app-about-and-first-run-notice` 引入，沿用 `focus-a-2026-10-14`，不替代既有 C01–C04。目标行为见对应 change；运行证据单列于 `docs/qa/app-about-notice-acceptance.md`，不以本节代替验收。

| ID | 画面／触发 | 状态及规则 |
| --- | --- | --- |
| C05 | C01/C02/C04 底部关于分区 | 三线正式标志、名称、简介、实际版本／构建号；版本加载／失败重试，主页／反馈主动外部打开及失败重试；离线第三方许可含加载、空、失败和返回；所有提醒状态下可达 |
| D15 | 当前说明版本无已阅记录时 | 中英文简介、隐私联网、本地数据、完整备份与应用内副本边界；默认／保存中／保存失败、重试和失败态本次继续；非提交返回或遮罩关闭不记已阅，本进程不立即重弹 |
| D16 | C05 隐私与数据说明 | 与 D15 同正文，只关闭不写首次状态，返回设置原位置与焦点；大字号正文滚动而操作保持可达 |

计划导航以 `list_alt_outlined` 替代斜哑铃，保留 22 dp、原文字、顺序和选中态。C05 使用 CMP-02，D15/D16 使用 CMP-01/04/05；交互见 INT-11，验收见 FLOW-17–19、VIS-01–05、ADAPT-01–07。

C05 许可子流程更新：主要项目摘要 → 项目许可详情；摘要底部“查看全部开源许可” → 完整项目列表 → 项目许可详情。正文不在列表内展开；所有页面均沿用 CMP-02 的普通行、24 dp 内距、当前语义主题和返回层级。

## 10. 主题色增量（C01/C02/C04、A01–A05）

设置增加外观与语言之间的主题色单选卡片；四项为青色／蓝色／紫色／石墨，青色默认。所有提醒状态下卡片存在，后续语言、提醒和 C05 关于可达。卡片状态包含正常、保存中、失败恢复和显式重试；默认无远程加载／空列表状态。

颜色选项只显示色块，不显示名称。常规四列，仅极窄容器按触控区域要求重排两列两行；A01/A02 检查 360／430 dp 和 1.6 字号长名称，A04/A05 检查短屏／平板、安全区及错误末尾可达。色块为整项操作目标，勾号／外圈表示唯一选中，本地化颜色名称仅作为辅助语义保留。其他 P/W/S/X/H/D 页面跟随共享强调色；正式品牌图形不重着色。行为见 INT-10 增量，证据见 `docs/qa/theme-color-presets-acceptance.md`。

## 11. 休息提醒增强（2026-10-16，已实现，待真机验收）

此增量以 INT-12 替代旧 C03／INT-06 的一次提醒呈现目标；旧原型保留作历史对照。[设计总览](previews/rest-reminders-2026-10-16.png)前两屏对应 D17，后两屏对应设置与 D18；D19 复用 D18 面板结构。

| ID | 画面／状态 | 规则 |
| --- | --- | --- |
| D17 / W03、W04 → W01 | 休息自然到期、待确认／确认中／失败重试 | 前台弹窗＋暗色遮罩；不显示系统横幅；返回只收起，W01 保留“停止本次提醒”；确认后恢复普通待练页 |
| C01/C02/C04 | 提醒开／关、重复开／关、保存中／失败、权限受限 | 总开关关闭收起选项并保留配置；重复关闭隐藏间隔；保留现有权限说明与重试入口 |
| D18 | 提醒间隔选择 | 10／15／30／60 秒，默认 10 秒；取消保留原值，保存失败留面板重试 |
| D19 | 提示音选择 | 单选与试听分离；试听只播放一段，不发送通知、不开始重复提醒；保存和取消同 D18 |
| C03 | 后台／锁屏通知及返回 | 重复更新同一条有效通知；点击成功返回所属训练后停止本次提醒，不再弹 D17 |

实施证据见[休息提醒增强验收](../qa/rest-reminders-acceptance.md)；D17/W01/C03 与设置组件已实现，真实手机音频、振动及剩余设备条件待验。


## 完整备份实施增量（2026-10-17，验收进行中）

C01/C02/C04/C05 均在适用提醒之后、关于之前增加“数据／备份与恢复”。
B00–B20/E01–E14 的设计依据为 [备份 UI 规范](backup/backup-ui-spec.md)。
Flutter 使用现有 AppCard、AppButton、AppTaskLayout 与四主题色；正文滚动和主操作区
分离，横屏采用已有左右布局。说明版本 2 区分公开完整备份、计划分享与应用内副本。
实际完成度与未测项见 [备份实施验收](../qa/backup-restore-acceptance.md)，不沿用 HTML 验收结论。
