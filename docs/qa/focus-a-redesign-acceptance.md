# A · 专注工具改版实施验收

设计版本：`focus-a-2026-10-14`。变更：`redesign-ui-focus`。实施与验证日期：2026-10-14—15。

A 方案已应用到 Flutter。用户于 2026-10-15 明确要求同步主规格并归档，现已完成；Git 提交和发布未执行。实施保留应用 `0.1.3+5` / `da18d62` 的业务行为。本报告记录本次新界面证据，既有 QA 报告保留不改写。

可先打开[实际截图索引](focus-a-redesign-evidence/index.html)，按页面、语言、主题和宽度筛选。最终 Debug 安装包位于 `build/app/outputs/flutter-apk/app-debug.apk`，入口为 `lib/main.dart`；哈希及大小见[构建记录](focus-a-redesign-evidence/build.json)。HTML 设计原型和旧版图片不作为 Flutter 通过证据。

## 环境与证据边界

- 全新独立 AVD：`SetTraceFocus` / `emulator-5580`，Android API 36；`SetTraceFocusLegacy` / `emulator-5582`，API 28。不接触原 AVD、个人训练库或真实设备数据。
- API 36 基线为 360 dp（1080×2400 / 3）和 430 dp（1290×2580 / 3），系统字号 1.0；应用适配补充 1.3 / 1.6、360×640、740×390 和 768×1024 逻辑尺寸，减少动态效果。
- 页面场景使用真正的 Flutter 页面及独立 SQLite 仓储；传输成功、提醒能力和故障样本有受控平台夹具。因此场景截图只证明呈现；真实文件、权限、通知、进程恢复另列实际 Android 证据。
- 430 dp 保留全部 42 个应用拥有的场景 × 中文／English × Light／Dark，共 168 张完整原图。360 dp 完整 168 场景有通过日志，最终保留 60 张重点截图。索引优先采用后续修正了根导航、主题选项与首页布局的批次。
- 系统 C03 不画成应用界面；其真实通知外观由 Android 决定。Flutter Surface 键盘截图不包含系统 IME 像素，但实际根视图键盘 inset 已断言为 299 dp。

## 阶段 1：共享主题与基础组件

主题对齐浅深语义色与 Material 组件；按钮增加次级、线框、危险与提交中状态，支持长文增高。导航保留根键与 IndexedStack，补充图标、文字及选中语义。Picker 保留滑动、吸附、有效变化触觉，增加同值规则的减／加及辅助功能增减语义。

`focus_components_test.dart`、`step_picker_test.dart` 验证可用配色对比、长按钮、忙碌不可重复提交、端点及外部同步不重复反馈；相关本地化回归验证草稿、tab、深层路由和绝对休息截止不丢失。覆盖 CMP-01–05、VIS-01–06、INT-01/10、ADAPT-01–07。

## 阶段 2：训练、休息与确认

W01–W06 将正文和主操作分离，依据真实状态显示完成本组／结束休息／保存。当前待练组与已完成数独立，参考重量有明确标签；超过 8 组采用摘要，跳过不增加实际进度。两类休息、±30 秒、跳过、恢复跳过、普通撤销及 D05–D09 沿用既有仓储规则。读取失败、操作失败和提醒失败分别恢复，结束／放弃有提交保护。

Widget 和仓储回归覆盖 100 组、大字号固定操作、连点、过期确认、两类撤销、零完成退出及保存失败不丢会话。真实到期与通知检查见后文。覆盖 INT-02–04/06/07、FLOW-02–06/09/16。

## 阶段 3：本次训练工具

S01–S04 显示完整状态与实际完成／目标；剩余换序增加上下按钮，复用候选槽位，不移动锁定行。本次配置仅编辑所选身份的组数与两类休息，保持原名称、重量、原计划及其他快照。过期草稿保留输入，禁用直接保存并提供重载。

`session_exercise_reordering_test.dart`、`session_reordering_repository_test.dart`、`focus_redesign_ui_test.dart` 覆盖非拖动换序、取消、身份、候选限制、非当前动作的过期→重载→保存。覆盖 D09/D14、FLOW-06–08/16、ADAPT-06。

## 阶段 4：计划、配置与准备

P01–P06 区分加载／失败／空状态，保留继续训练与导入导出。新建／改名弹窗等待真实异步提交，错误留输入、焦点与草稿；允许普通同名，创建成功但刷新失败只重试读取。动作配置与删除呈现对象及快照保留范围；准备不提前创建训练。

最终补测修复了 360×640 / 1.6 字号下首页标题挤压溢出：标题与工具在窄屏分行，整页内容可滚动。键盘辅助导航按新建→更多→继续训练→计划的可见顺序遍历。默认换序与删除快照保护、命名故障、真键盘字段错误均有检查。覆盖 D01–D04/D10/D12、FLOW-01/02/16。

## 阶段 5：导入导出

X01–X04 保持默认全选、主动粘贴、文件取消、完整配置预览、同名副本、新冲突再确认及原子写入。页面正文可滚动、确认独立可达；空输入禁用预览，错误就地保留。真实结果提示使用平台返回的文件名和公共 Downloads 位置。

API 36 双语完整旅程实际完成创建→动作配置（逗号小数）→准备→四组训练／结束休息→保存→历史详情→公共 Downloads 保存／读取→同名副本导入。API 28 实际拒绝／允许写入权限、公共下载、取消系统文件选择、选择旧中文备份均通过。JSON v1 编解码、原子保存与碰撞保留回归通过。覆盖 FLOW-10/11、INT-08。

## 阶段 6：历史、设置与系统反馈

H01–H05 保留自然周／月统计、所选月份、快照顺序及完成／跳过／未完成三类状态；删除失败与删除成功后刷新失败各自重试。C01–C04 保持实际主题／语言／提醒偏好，显示保存中及失败；能力受限、调度失败与偏好写入失败有独立说明。

真实系统检查：首次应用解释 D11→Android 原生通知权限→拒绝后继续训练；系统设置允许后恢复；准时权限关闭时提示可能延迟，系统设置开启后恢复；渠道关闭时提示后台不可用。未改动提醒调度、消费和导航协议。

前台自然到期消费一次，实际完成仍为 2 组；后台／锁屏自然到期产生真实系统通知。杀掉仅测试应用进程后，点击该通知冷启动返回会话 2 的最新第 3 组；两次原生重复入口继续复用该训练。已结束会话 1 与缺失目标拒绝跳转。主动结束时提醒取消、过期重启时提醒过期，均不补播。

通知音量为 0 和勿扰模式下分别运行自然到期，事件均只消费一次；系统音量／策略 dump 与既有声音策略单元测试佐证静音条件。模拟器不能证明实际扬声器听感或设备触觉，未将其记为真机通过。

证据：[前台到期](focus-a-redesign-evidence/runtime/foreground-result.json)、[系统通知及返回](focus-a-redesign-evidence/runtime/notification-result.json)、[不补播](focus-a-redesign-evidence/runtime/no-replay-results.json)、[静音／勿扰](focus-a-redesign-evidence/runtime/quiet-policy-results.json)，对应 PNG、XML、系统 dump 同目录。

## 阶段 7：覆盖、恢复与验收

### 页面及弹层逐项覆盖

下表每个应用场景均有两语／两主题的 Android 批次；列出浅色中文作为直接入口，其他组合见截图索引和运行日志。C03 单列系统实测。故障／取消／提交／极端适配分支由后续行为表和适配矩阵补充。

| ID | 页面或弹层 | 实现／实测范围 | 本次证据 |
| --- | --- | --- | --- |
| P01 | 计划首页，活动会话卡片、计划摘要 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-home-final/P01-zh-light-430.png)；另有两语／两主题批次 |
| P02 | 计划详情，动作顺序、组数、休息摘要 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/P02-zh-light-430.png)；另有两语／两主题批次 |
| P03 | 添加／编辑动作，名称、组数、两类休息、可选重量 | [实际实现](../../lib/features/plans/exercise_editor_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/P03-zh-light-430.png)；另有两语／两主题批次 |
| P04 | 开始前预览计划、动作顺序与总组数 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/P04-zh-light-430.png)；另有两语／两主题批次 |
| P05 | 没有计划的首页 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-home-final/P05-zh-light-430.png)；另有两语／两主题批次 |
| P06 | 已建计划没有动作 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/P06-zh-light-430.png)；另有两语／两主题批次 |
| W01 | 当前待练第 3 / 4 组，当前动作实际完成 2 组 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/W01-zh-light-430.png)；另有两语／两主题批次 |
| W02 | 全场尚未完成任何组 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/W02-zh-light-430.png)；另有两语／两主题批次 |
| W03 | 组间休息，接下来仍是当前动作 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/W03-zh-light-430.png)；另有两语／两主题批次 |
| W04 | 动作间休息，下一动作尚未开始 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/W04-zh-light-430.png)；另有两语／两主题批次 |
| W05 | 上个动作完成 2 / 4，剩余 2 组被跳过；下一动作待练 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/W05-zh-light-430.png)；另有两语／两主题批次 |
| W06 | 所有组均已处理，实际完成 11 / 15，4 组跳过 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/W06-zh-light-430.png)；另有两语／两主题批次 |
| S01 | 全部动作与编辑 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/S01-zh-light-430.png)；另有两语／两主题批次 |
| S02 | 调整剩余顺序 | [实际实现](../../lib/features/workout/session_order_sheet.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/S02-zh-light-430.png)；另有两语／两主题批次 |
| S03 | 选择下一动作 | [实际实现](../../lib/features/workout/session_order_sheet.dart) | [Android 截图](focus-a-redesign-evidence/android-430/S03-zh-light-430.png)；另有两语／两主题批次 |
| S04 | 编辑本次配置 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/S04-zh-light-430.png)；另有两语／两主题批次 |
| X01 | 导出计划选择 | [实际实现](../../lib/features/plans/plan_transfer_pages.dart) | [Android 截图](focus-a-redesign-evidence/android-430/X01-zh-light-430.png)；另有两语／两主题批次 |
| X02 | 文本输入／主动粘贴／文件选择 | [实际实现](../../lib/features/plans/plan_transfer_pages.dart) | [Android 截图](focus-a-redesign-evidence/android-430/X02-zh-light-430.png)；另有两语／两主题批次 |
| X03 | 导入前预览、拟用名称 | [实际实现](../../lib/features/plans/plan_transfer_pages.dart) | [Android 截图](focus-a-redesign-evidence/android-430/X03-zh-light-430.png)；另有两语／两主题批次 |
| X04 | 展开完整动作配置 | [实际实现](../../lib/features/plans/plan_transfer_pages.dart) | [Android 截图](focus-a-redesign-evidence/android-430/X04-zh-light-430.png)；另有两语／两主题批次 |
| H01 | 月份历史与统计 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/H01-zh-light-430.png)；另有两语／两主题批次 |
| H02 | 含跳过组的记录详情 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/H02-zh-light-430.png)；另有两语／两主题批次 |
| H03 | 所选历史月份为空 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/H03-zh-light-430.png)；另有两语／两主题批次 |
| H04 | 提前保存，完成／跳过／未完成并存 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/H04-zh-light-430.png)；另有两语／两主题批次 |
| H05 | 没有任何已保存记录 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/H05-zh-light-430.png)；另有两语／两主题批次 |
| C01 | 主题、语言、提醒正常 | [实际实现](../../lib/features/settings/settings_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/C01-zh-light-430.png)；另有两语／两主题批次 |
| C02 | 提醒能力受限 | [实际实现](../../lib/features/settings/settings_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/C02-zh-light-430.png)；另有两语／两主题批次 |
| C03 | Android 系统通知 | 真实系统通知、冷／热启动、失效目标 | [系统截图](focus-a-redesign-evidence/runtime/lockscreen-natural-notification.png)、[导航结果](focus-a-redesign-evidence/runtime/notification-result.json) |
| C04 | 调度或偏好保存失败 | [实际实现](../../lib/features/settings/settings_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/C04-zh-light-430.png)；另有两语／两主题批次 |
| D01 | 首页新建计划 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-home-final/D01-zh-light-430.png)；另有两语／两主题批次 |
| D02 | 计划重命名 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D02-zh-light-430.png)；另有两语／两主题批次 |
| D03 | 删除计划 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D03-zh-light-430.png)；另有两语／两主题批次 |
| D04 | 删除计划动作 | [实际实现](../../lib/features/plans/exercise_editor_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/D04-zh-light-430.png)；另有两语／两主题批次 |
| D05 | 有实际完成组的结束 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/D05-zh-light-430.png)；另有两语／两主题批次 |
| D06 | 放弃已有完成记录 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/D06-zh-light-430.png)；另有两语／两主题批次 |
| D07 | 零完成时结束 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/D07-zh-light-430.png)；另有两语／两主题批次 |
| D08 | 跳过当前动作剩余组 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D08-zh-light-430.png)；另有两语／两主题批次 |
| D09 | 恢复最近一批跳过 | [实际实现](../../lib/features/workout/workout_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D09-zh-light-430.png)；另有两语／两主题批次 |
| D10 | 开始新训练遇到活动会话 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D10-zh-light-430.png)；另有两语／两主题批次 |
| D11 | 休息提醒授权前解释 | [实际实现](../../lib/app/app.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D11-zh-light-430.png)；另有两语／两主题批次 |
| D12 | 首页计划更多菜单 | [实际实现](../../lib/features/plans/plans_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430-home-final/D12-zh-light-430.png)；另有两语／两主题批次 |
| D13 | 记录详情更多菜单 | [实际实现](../../lib/features/history/history_page.dart) | [Android 截图](focus-a-redesign-evidence/android-430/D13-zh-light-430.png)；另有两语／两主题批次 |
| D14 | 会话草稿过期 | [实际实现](../../lib/features/workout/session_order_sheet.dart) | [Android 截图](focus-a-redesign-evidence/android-430-final/D14-zh-light-430.png)；另有两语／两主题批次 |

### 行为与异常覆盖

| 要求 | 检查与结果 |
| --- | --- |
| FLOW-01/02 | 计划 UI、仓储及真实 Android 旅程；普通同名、默认换序、准备、活动冲突和来源删除仍能继续 |
| FLOW-03/04 | 完成连点、100 组、绝对截止、零休息、两类休息与提醒仓储；Android 前台／后台自然到期与不补播 |
| FLOW-05/06 | 跳过资格、取消、过期、普通撤销、恢复最新跳过保留后来完成；Android 实际跳过后完成下一动作 |
| FLOW-07/08 | 候选槽位、锁定行、非拖动替代、当前是否开始的两种选择语义；非当前编辑、过期重载和仅本次保存 |
| FLOW-09/16 | 零完成、有记录退出、放弃二次确认、一次提交、失败保留；命名／导入／删除错误不重复已提交写入 |
| FLOW-10/11 | 默认全选、复制／文件故障、JSON v1 往返与原子导入；API 36 Downloads 和 API 28 权限／旧备份文件 UI |
| FLOW-12/13 | `history_stats_test.dart`、`history_delete_ui_test.dart`；月份、快照、三类状态、删除成功但刷新失败等分支 |
| FLOW-14/15 | 偏好与提醒回归；Android 通知拒绝／允许、渠道关闭、准时权限、系统通知、冷／热返回和过期目标 |
| INT-10 / ADAPT-04/05 | 主题和语言写入成功／失败／重启保持；root switch 保留 tab、页面栈、草稿、选择、组数和原绝对截止 |

### 尺寸、字号与辅助功能

最终 Widget 套件包含 360／430 × Light／Dark × 中英文的 328 个应用场景，以及 28 场景 × 3 尺寸 × 1.3／1.6 字号的 168 个交叉样本；加上其他组件、UI、仓储与本地化行为测试，最终全部 648 项通过。覆盖长名称／加长译文、100 组、减少动态效果及短屏／平板。Android 360 和 430 dp 各 168 场景通过；真 IME 的 P03／X02／D01 × 两语 × 两主题共 12 场景在 1.6 字号下通过。

API 36 实际启用 TalkBack，确认底部导航按钮名称和 selected 状态、训练“当前第 3 组／已完成 2/4／逐组状态”的完整语义；通过 Android 键盘事件注入验证 Tab 轨迹与弹窗返回，见[辅助输入结果](focus-a-redesign-evidence/runtime/accessibility-results.json)、[最终焦点轨迹](focus-a-redesign-evidence/runtime/keyboard-order-final.json)及[弹窗返回截图](focus-a-redesign-evidence/runtime/keyboard-dialog-focus-return.png)。数值控件的增减语义、非拖动排序、减少动态效果及取消／失败保留由行为测试补足。倒计时明确为非 live region，避免逐秒抢播。完整语音听感、盲操作熟练度及不同读屏版本未作为真机通过项。

### 数据、升级与进程恢复

API 28 安装旧 `0.1.2+4`，使用仅属于该 QA AVD 的 v2 数据副本，保留计划、已保存历史、两组完成与未来休息、中文／深色偏好，再原位安装本次 APK。既有 v2→v3 升级后，五张原表的全部原列逐值一致，完整性为 ok，活动训练仍可继续、未来截止保持，见[升级结果](focus-a-redesign-evidence/runtime/upgrade-results.json)。本变更没有新增迁移。

API 36 在实际 UI 跳过剩余两组、随后完成下一动作一组，再删除来源计划并重启。会话动作顺序、组记录、跳过批次与当前动作／组身份保持；场景中原休息已自然到期，截止按既有规则归空，没有重置出新的休息，见[复杂状态恢复](focus-a-redesign-evidence/runtime/complex-restart-result.json)。未来休息保持由升级和本地化重建检查单独证明；已到期不补播另有原生结果。换序、恢复跳过、后来完成及本次编辑的持久化由相关仓储与 UI 回归交叉验证。

## 最终命令与结果

本机通过已有 Flutter SDK 的 `flutter_tools.snapshot` 运行同等 CLI 命令；OpenSpec 通过本机可用 Node 运行已安装入口，未改系统 PATH 或安装依赖。原始日志保存在[logs](focus-a-redesign-evidence/logs/)。

| 命令／入口 | 结果 | 日志 |
| --- | --- | --- |
| `flutter gen-l10n` | 通过 | [生成资源](focus-a-redesign-evidence/logs/flutter-gen-l10n.txt) |
| `dart run tool/check_localizations.dart` | 通过 | [文案检查](focus-a-redesign-evidence/logs/localizations-check.txt) |
| `dart run tool/test_language_extension.dart` | 通过；第三语言仅隔离夹具，正式仅 en/zh | [扩展检查](focus-a-redesign-evidence/logs/language-extension.txt) |
| `flutter analyze --no-pub` | 通过，无问题 | [静态分析](focus-a-redesign-evidence/logs/flutter-analyze.txt) |
| `flutter test --no-pub --reporter expanded` | 648 项通过，零失败 | [完整回归](focus-a-redesign-evidence/logs/flutter-test.txt) |
| `flutter build apk --debug --no-pub --target lib/main.dart` | 通过，正式应用入口 | [构建](focus-a-redesign-evidence/logs/flutter-build-main.txt) |
| `focus_a_redesign_test.dart` / API 36 | 360／430 dp 各 168 场景；最终修订重点场景再捕获 | [360](focus-a-redesign-evidence/logs/android-matrix-360.txt) / [430](focus-a-redesign-evidence/logs/android-matrix-430.txt) |
| `focus_a_keyboard_test.dart` / API 36 | 12 个真 IME 场景通过 | [键盘](focus-a-redesign-evidence/logs/android-keyboard.txt) |
| `localization_android_test.dart` / API 36 | 双语完整旅程通过 | [旅程](focus-a-redesign-evidence/logs/android-journey.txt) |
| `localization_legacy_test.dart` / API 28 | 原生权限／文件选择／旧备份通过 | [旧版平台](focus-a-redesign-evidence/logs/android-legacy.txt) |
| `:app:testDebugUnitTest` | 通过 | [原生单元](focus-a-redesign-evidence/logs/native-unit.txt) |
| `AndroidJUnitRunner` / API 28、36 | 各报告 13 项、零失败；各 2 项需显式参数的语言／剪贴板 relay 跳过，11 项实际执行，包括真实提醒及文件桥接 | [API 28](focus-a-redesign-evidence/logs/native-api28.txt) / [API 36](focus-a-redesign-evidence/logs/native-api36.txt) |
| `openspec validate redesign-ui-focus --strict --no-interactive` | 通过 | [规格检查](focus-a-redesign-evidence/logs/openspec-validate.txt) |

初轮失败已处理：布局缺少根导航的夹具已补齐；首页大字号溢出已修复；旧测试 BackButton 查找保持原语义控件；异步数据库等待改为真实时间轮询。原生旧版初次运行缺存储授权，补齐测试环境权限后重跑通过；未改平台实现来绕过权限。依赖库自己的跨盘 Gradle 测试不作本应用验收，使用 `:app:` 作用域测试。

## 改动范围与回退

[范围核验](focus-a-redesign-evidence/scope-integrity.json)核对 305 个受保护文件：304 个与规划前 SHA256 一致；`workout_repository.dart` 与当前 HEAD 字节完全一致，规划前历史哈希不同，当前无内容差异。实施期间数据库结构／迁移、计划与会话仓储／模型、JSON v1、统计、提醒服务、Android 平台协议、五份主规格、既有归档与旧 QA 资料保持；其后按用户授权仅同步本变更的五份主规格。

本次仅更改主题、共享 UI、主要页面、ARB、必要行为测试／验收工具及当前设计实施状态。此前设计归档和资料更新作为已有改动保留，不能整仓 reset。UI 回退应在审查后逐文件恢复本变更的 UI 与文案层、保留先前设计资料和用户修改；无需执行数据库降级或转换训练数据。测试与证据目录可随相应 UI 变更一同回退，旧 QA 原件不改写。

## 归档收尾（2026-10-15）

用户选择“同步主规格后归档”。五份主规格新增 15 项、更新 3 项要求，Purpose、未涉及要求及原有场景保留，严格校验通过。变更及 49 项已完成任务现位于[归档目录](../../openspec/changes/archive/2026-10-15-redesign-ui-focus/README.md)，相对链接已随迁移修复。

[同步明细](focus-a-redesign-evidence/spec-sync-results.json)、[归档记录](focus-a-redesign-evidence/archive-results.json)、[主规格校验](focus-a-redesign-evidence/logs/archive-spec-validation.txt)区分本次收尾与前面的实施证据。原始日志、apply-status 与范围哈希属于实施阶段快照，不重写为归档后的运行结果。归档不改变尚未实测的真机条件。

## 未验证条件与用户验收

- [ ] 真机扬声器音量、振动触感、完整 TalkBack 语音与盲操作体验；当前是模拟器系统策略、语义和辅助输入证据。
- [ ] 不同厂商 Android 的后台限制、锁屏私有样式及长期省电行为；当前实测 API 28／36 的独立 AVD。
- [ ] 用户对新外观、训练流程手感与最终视觉细节的接受；当前状态为等待验收。

以上条件未冒充真机通过。主规格同步与 OpenSpec 归档已按用户后续明确选择完成；Git 提交和版本发布未执行。
