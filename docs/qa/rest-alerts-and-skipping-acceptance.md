# 休息提醒与剩余组跳过验收

## 环境与记录

执行日期：2026-10-14（记录日期使用 Asia/Hong_Kong；模拟器时区为 GMT，截图时刻使用该设备时区，数据库/延迟比较使用 UTC 毫秒）。
验证环境：Android 16 / API 36，独立 SetTraceRestQa AVD（sdk_gphone64_x86_64），`emulator-5554`。`wm size 1080x2340`、density 480，即 360 dp；充电 100%，系统默认电池策略、省电模式关闭。锁屏测试进入 Dozing；正常准时授权为 allow。
原有 Pixel_7_Pro 数据目录不可写，使用工作区 build/qa-avds 中独立 QA AVD，
不更改原 AVD。生成的调试包/原生报告/设备日志放在 build/qa/rest-alerts。

## 自动检查

- 数据库：新库互斥/归属约束，v1/v2→v3 保留旧值，失败回滚。
- 仓储：完成两组→跳过两组仍 2/4，失败回滚、旧确认拒绝、换序、
  重开、两类撤销与后续完成记录保留、最后动作可结束。
- 提醒：调度失败不回滚完成、加时旧修订失效、取消 API 失败仍拒旧投递、
  并发消费至多一次、自然归一化仍可提醒、关闭/开启与过期重开、权限拒绝记录。
- Widget：确认/取消/重复、撤销可找回、实际比例不足仍可保存、
  已跳过/未完成历史详情、通知目标校验和中英文长文案小屏。
- 原生：有效性查询、所有权/目标/修订拒绝、并发连接原子消费、
  不改训练数据、不在原生迁移旧版本、到期与迟到边界。

## 设备步骤与预期

1. 原计划 A 四组、B 四组。完成 A 两组后打开跳过确认再取消：
   A 仍两组实际完成，截止和待练第三组保持，通知仍对应第三组。
2. 在训练页和组间休息页分别确认跳过：A 第三、四组标已跳过，
   A 目标仍四组，显示 B 第一组，不新建休息，旧提醒不再响。
3. 重开应用：仍在 B，A 保留 2/4。选择独立撤销最近跳过：
   回到 A 第三组，A 前两组及 B 已完成组均保留。
4. 撤销上一组：只清最近真实完成，不恢复跳过；包含跳过的动作
   无法修改配置或参与待练换序；恢复跳过后可按原规则编辑。
5. 最后动作完成两组后跳过两组：可结束保存，实际进度不足 100%，
   历史为 2/4、详情后两组已跳过、统计只增加实际两组。
6. 前台自然到期：一次短音和反馈，不自动完成。普通后台与锁屏：
   一条本地通知，正文对应当前下一动作/组，点击返回最新同一会话。
7. +30 秒：旧截止不响，按新截止提醒；减到零/跳过休息/撤销/结束：
   不播放自然到期声，旧 Alarm/通知失效。到期前后切前后台不重复响。
8. 通知权限拒绝：前台仍提示，设置说明后台不可用，不每组重复申请；
   再授权后刷新。准时权限拒绝说明可能延迟；开启后重新对账当前休息。
9. 静音、勿扰、通知渠道关闭声音：不得强制绕过。渠道关闭或通知拒绝
   的后台通知不可用应明确；声音恢复后有效新事件正常。
10. 关闭提醒再开启：截止不重置，只安排未来休息；截止后重开不补播。
    普通进程回收后未来提醒仍有效，手机重启/强行停止不作为必达场景。
11. 动作间休息换序/换语言：截止保持，未发送正文更新。重复点击通知
    不叠加页面；已结束/删除目标通知不打开其他会话。
12. 旧 APK 数据有计划、历史和未完成休息，覆盖安装新版：
    原数据完整，仍沿原进度，跳过与撤销可用，历史比例和统计正确。

正常精确模式以截止后五秒内送达为目标；三十秒是失效上限。
每条设备结果记录截止时间、消费时间、通知出现时间及是否重复，
不得用“调度方法返回成功”代替实际送达。

## 执行结果

代码和自动验证已完成，设备功能矩阵使用独立模拟器执行。任务 5.4 的真实手机扬声器试听尚未执行，保留为未勾选；没有把模拟器解码记录写成真人试听结论。

### 自动检查与构建

| 检查 | 最终结果 |
| --- | --- |
| Flutter 静态分析 | 无问题 |
| Flutter 全量回归 | 140 项通过（含通知返回后保存刷新首页的新增回归） |
| 中英文资源 / ICU / UI 字符串检查 | 通过；`flutter gen-l10n` 通过 |
| Android 原生单元测试 | 4 项通过，包含铃声模式、零音量、勿扰、静默/禁用渠道边界 |
| Android 仪器测试 | 8 项通过；真实 AlarmManager 送达、替换/取消、消费去重、并发连接、版本拒绝 |
| APK | `build/app/outputs/flutter-apk/app-debug.apk`，debug，可覆盖安装 |
| Git 差异空白检查 | 通过 |

相关原始自动测试日志保存在 `build/qa/rest-alerts/`，可复现命令为 `flutter analyze --no-pub`、`flutter test --no-pub`、`dart run tool/check_localizations.dart`、`flutter build apk --debug --no-pub`。
原生使用 `gradlew :app:testDebugUnitTest :app:assembleDebugAndroidTest --offline`；仪器测试通过直接 `adb shell am instrument` 执行。
Gradle connected 任务所需 UTP 主机依赖未缓存，采用同一 AndroidJUnitRunner 直接运行，没有把构建 APK 当成仪器测试通过。

### 模拟器功能矩阵

| 场景 | 实际结果与证据 |
| --- | --- |
| 前台到期与前后台去重 | 一次事件消费；前台 300 ms raw 音频解码并显示反馈，不自动完成组。第一轮消费延迟 42 / 185 ms；后续前台事件为 4–7 ms |
| 普通后台 | 显示一条对应下一动作/组的通知；返回后游标保持最新，不重播旧事件 |
| 锁屏 | `mWakefulness=Dozing`，通知正文 QA Row 第 1/4 组；消费在截止后 12 ms，只有一条 SetTrace 通知 |
| 真正后台进程退出后未来提醒 | 截止前 PID 为空；接收器独立启动 PID 7955，事件 9 在截止后 320 ms 消费，出现一条通知。采用同 UID 结束进程来模拟回收，没有 force-stop 应用 |
| 通知点击冷/热返回 | 冷启动 PID 为空→新 PID；稳定页面回到同一会话的当前组。热点击返回 QA Row 第 2/4 组；重复点击复用与失效目标另由 Widget 测试覆盖 |
| 加 30 秒 | 同一事件修订增加，截止从起点 +8 秒更新为 +38 秒；旧截止没有输出，按新截止送达。原生仪器测试另验证旧 Alarm 替换与取消 |
| 减到零 | 原计划 30 秒休息在页面减 30 秒后立即进入待练；数据库截止与提醒引用为空，事件 cancelled 且 consumed_at 为空，没有自然到期输出 |
| 跳过 / 撤销 / 保存取消 | 跳过后无新动作间休息；两类撤销按自己的记录恢复；保存后该会话无 pending 提醒，系统无 SetTrace 活动通知。仓储和仪器测试另覆盖取消 API 失败时的旧回调拒绝 |
| Android 通知权限拒绝 | 实际系统弹窗选择拒绝；组先持久化，下一休息不重复申请。通知被拒绝时前台仍有 300 ms 音频解码与视觉反馈 |
| 通知权限恢复 / 准时能力撤销 | 恢复通知授权后可送达；撤销 SCHEDULE_EXACT_ALARM 后设置显示“后台提醒可能延迟”与准时设置入口；恢复后重新对账。降级使用非精确 Alarm，不把状态检查视作该模式的送达分布验证 |
| 勿扰 | 设置 none 后事件正常消费、训练继续，无新增应用音频记录；恢复 all 后正常新事件重新输出 |
| 静音与 Silent 渠道 | 系统设置滑块实际归零，`STREAM_NOTIFICATION Muted:true / streamVolume:0`，铃声为振动；渠道 importance=2。事件 7 到期显示反馈，前后应用音频记录均为 3 条，没有新增播放 |
| 渠道关闭 | 系统设置 Show notifications 关闭，渠道 importance=0；系统明确屏蔽此类通知，原生可用能力为 false。前台声策略对 importance=0/2 的独立回归通过 |
| 关闭再开启 / 超时重开 / 切换语言 | 仓储/服务与 Widget 测试覆盖：未来休息不改截止、过期不补播、文案更新但用户动作名保持；设备中文历史核对通过 |

[首轮时间证据](rest-alerts-and-skipping-evidence/live-reminder-timing.json)与[后续时间证据](rest-alerts-and-skipping-evidence/matrix-reminder-timing.json)保存绝对 UTC 毫秒截止与消费时间。
通知出现通过 UI 和 NotificationManager 实际观察，消费时间是输出前的原子记录，不能精确替代扬声器起声时间。正常精确模式所有已观察样本均在 5 秒内，不能据此承诺厂商设备或非精确模式必达。

### 升级与历史交叉流程

先安装原 v2 APK，注入仅用于 QA 的计划、历史和进行中休息，再 `install -r` 覆盖安装新版。
[升级逐值比较](rest-alerts-and-skipping-evidence/upgrade-comparison.txt)通过：计划、历史快照、主键、完成序号、历史时间、当前游标和休息截止保持；升级启动没有权限弹窗。

实际执行 A 2/4→跳过 2 组→下一动作→撤销跳过→A 第 3 组→继续训练，之后恢复 QA 升级夹具完成权限/声音矩阵。
矩阵只把活动会话休息改为 8 秒，原计划仍为 30 秒、目标仍四组。最终 A 与 B 都实际完成两组、跳过两组，末动作触发保存确认，真实进度 50%。
[最终数据库比较](rest-alerts-and-skipping-evidence/history-comparison.txt)确认：两动作均 2/4，新增四个实际完成组和四个跳过组，旧历史与原计划所有字段保持，旧提醒全部取消。
整场统计新增四组；单动作只有 2/4 的统计新增两组由仓储/Widget 测试覆盖。时长继续按原开始至保存计算；夹具起点较早导致截图显示 8 小时，不是跳过额外计算了时长。
从通知进入后保存的首页残留卡片已修复，并用单独的 Widget 回归验证。

### 界面证据

- [锁屏提醒](rest-alerts-and-skipping-evidence/locked-rest-notification.png)
- [普通后台进程退出后的提醒](rest-alerts-and-skipping-evidence/future-reclaim-notification.png)
- [系统通知授权弹窗](rest-alerts-and-skipping-evidence/android-permission-prompt.png)
- [静音到期反馈](rest-alerts-and-skipping-evidence/true-mute-ended.png)
- [系统静音状态](rest-alerts-and-skipping-evidence/true-silent-system.png)
- [非精确能力说明](rest-alerts-and-skipping-evidence/reminder-capabilities.png)
- [渠道关闭说明](rest-alerts-and-skipping-evidence/channel-disabled.png)
- [历史 2/4 与跳过详情](rest-alerts-and-skipping-evidence/final-history-detail.png)
- [中文历史](rest-alerts-and-skipping-evidence/final-chinese-history.png)

### 尚未验证的真实设备条件

任务 5.4 的真实手机扬声器试听待完成：安装 APK、正常铃声音量并启用渠道声音，完成一组后听一次短音；分别确认前台、锁屏的音色和响度可辨认。当前已验证资源是 300 ms、设备实际解码并输出，未做真人听感评价。
厂商后台限制、电池优化、真实手机锁屏起声时间和非精确模式的送达分布尚未量测；手机重启与强行停止原本就不属于首版必达范围。
