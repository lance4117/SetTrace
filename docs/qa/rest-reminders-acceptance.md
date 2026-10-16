# 休息提醒增强验收

2026-10-16，变更 `enhance-rest-reminders`。代码已实现，任务完成 14／17；4.2 的 TalkBack、5.2 的完整设备矩阵和 5.3 的真人听感未全量验收；已按用户要求于 2026-10-16 带待验项归档。

## 实现与自动验证

- v4 迁移、逐轮事务领取、确认、设置与恢复；旧 consumed 不复活，确认不写训练组。
- D17／W01 单弹窗与停止入口；欢迎、编辑、权限及通知导航串行。返回只收起，重复不重开。
- C01/C02/C04、D18/D19：默认三音／振动／重复 10 秒，10/15/30/60 秒可选，试听与保存分离。
- 默认三音 1.800 秒，双段电子 1.740 秒，中／英语音约 1.458／1.417 秒；原生离线解码测试通过。真人听感另验。
- 中英文、浅深×四主题色、360／430 dp、600 dp 短屏、1.6 字号确认可达；Widget 语义与键盘确认、减少动画通过。实际 TalkBack 连续导航尚待验证。

| 命令 | 结果／证据 |
| --- | --- |
| `flutter analyze --no-pub` | 无诊断；`build/qa/rest-reminders/analyze-final.log` |
| `flutter test --no-pub --concurrency=4 --reporter expanded` | 951 项通过；`build/qa/rest-reminders/flutter-final-pass.log` |
| `dart run tool/check_localizations.dart` | 通过，含 gen-l10n、ICU、未翻译报告与资源测试；`build/qa/rest-reminders/localizations.log` |
| `gradlew :app:assembleDebug :app:testDebugUnitTest :app:assembleDebugAndroidTest --offline` | 通过；`build/qa/rest-reminders/android-final.log` |
| Android 仪器测试 | API 36／API 28 各 15 项提醒专项通过（运行器各显示 OK 20 tests）；`build/qa/rest-reminders/native-final.log`、`native-api28.log` |
| `openspec validate enhance-rest-reminders --strict` | 通过 |

原生仪器运行器还包含既有测试；`localizationQa` 可选集成场景未启用，不计入本次提醒验收。

Windows 环境中 Flutter 批处理会挂起，测试实际以 SDK 的 Dart＋flutter_tools.snapshot 执行；本地化检查使用 build 内的 Flutter 同等入口包装器，检查程序本身未修改。

覆盖来源：`database_migration_test`、`rest_alert_repository_test`、`rest_alert_repeating_test`、`rest_reminder_ui_test`、`about_notice_test`、`skipped_sets_ui_test` 及全量既有训练／撤销／排序／统计／传输／主题／本地化测试。`MainActivity` 既有 lifecycle／Intent 转发可直接复用，事件身份解析集中在 `RestAlertsBridge`。原生 `RestAlertsStoreTest` 验证 v4、并发领取、30 秒首次边界、迟到不补发、四间隔、确认清理、旧 Intent、音频、静默／禁用通道迁移和只更新现有通知的静默文案同步。

## 独立模拟器实测

仅使用本任务的 QA AVD，未连接或改动个人手机。API 36（`emulator-5556`）与 API 28（`emulator-5558`，原生烟测）；设备时钟独立，以下用设备 epoch 毫秒计算，不与主机时间混算。

| 场景 | 观察 |
| --- | --- |
| 组间休息、前台停留训练页 | 截止 1792085069000，首次领取 1792085069007（+7 ms）；保持一个弹窗，轮次 1→3，约 10 秒一轮；确认后 next_delivery_at 为空、完成数仍为 1 |
| 普通后台 | 截止 1792085238000，首次领取 1792085238009（+9 ms）；轮次增至 8，系统通知仅 ID=3 一条。点击返回训练，1792085317429 确认，完成数仍为 1 |
| 动作间休息、英文深色紫色、430 dp／1.6 字号 | 截止 1792086031000，首次领取 1792086031007（+7 ms）；单弹窗与间隔面板可读，确认后完成数保持 4 |
| 受控 Doze 短测 | 强制 deep idle 32 秒，截止 1792086220000，首次领取 +9 ms；观察到 2 轮，下一轮按实际时间＋10 秒。仅短窗口，不外推长期配额／厂商表现；见 [Doze 记录](rest-reminders/doze-result.json) |
| 待确认进程恢复 | 停止 QA 进程并错过下一时间后恢复，轮次保持 23、修订不变；下一轮安排在未来，没有启动补响，见 [恢复记录](rest-reminders/recovery-result.json) |
| v3→v4 设备升级 | 六张业务表逐值相同，未来截止 1792086253000 保留；旧 consumed 全部终止，见 [升级记录](rest-reminders/upgrade-result.json) |
| 熄屏／锁屏 | 截止 1792085361000，首次领取 1792085361008（+8 ms）；熄屏后继续逐轮更新同条通知。启用系统锁屏后截图确认通知可见 |

[前台弹窗](rest-reminders/foreground-dark-en-430.png) · [设置](rest-reminders/settings-dark-en-430.png) · [间隔面板](rest-reminders/interval-dark-en-430.png) · [后台通知](rest-reminders/background-notification.png) · [锁屏通知](rest-reminders/lockscreen-notification.png)。[状态记录](rest-reminders/device-states.jsonl)保留原始状态；通道和系统记录在 `build/qa/rest-reminders/device-states.jsonl`、`background-notifications.txt`、`lockscreen-policy.txt`。这些记录证实领取与通知存在，不代表真人听到声音或感觉到振动。

## 待验边界

- 4.2 的资源、语义、键盘及减少动画检查通过；实际 TalkBack 连续操作待验，任务保留未完成。
- 5.2 尚有完整设备矩阵、厂商限制、长期 Doze／通知冷却及 TalkBack 操作；Widget 的完整主题／尺寸矩阵不能代替逐台设备验收。
- 5.3 需要真实手机：三音、双段电子、中英语音在耳机／扬声器下的听感、系统音量／静音／勿扰、两次短振动、确认立即停止，以及各重复间隔。当前无真实手机连接，不标通过。
- 后台间隔受 AlarmManager、Doze 和通知冷却约束，不承诺严格每 10 秒；实际领取先于输出，崩溃窗口可能漏响。

汇总机读记录见 [verification.json](rest-reminders/verification.json)。

安装包：`build/app/outputs/apk/debug/app-debug.apk`（调试构建，未发布）。设计原图继续作为示意，OpenSpec 主规格已同步，见[归档记录](../../openspec/changes/archive/2026-10-16-enhance-rest-reminders/README.md)。

最终 APK SHA-256：`D9F5526FAEBE4486BE4DAFED8D03FF8222B3AA1F9A761B669A4B5971ECB67B4C`。

本次归档只同步规格与文档，保持 3 项待验复选框；未重新构建安装包，未执行 Git 提交或发布。
