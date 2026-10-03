# 本次动作排序验收记录

日期：2026-10-03。变更：`reorder-session-exercises`。

## 自动验证

- 原版基线：13 项 Flutter 测试通过。本次最终全量 `flutter test`：48 项通过。
- 新增 9 项真实 SQLite v1 升级与失败回滚测试（`test/database_migration_test.dart` 和冻结的 `test/fixtures/database_v1.dart`）：零完成、组间休息、动作间休息、损坏游标、全组完成待保存、完整/部分历史、来源计划已删除、迁移失败整体回滚。损坏 fixture 的预期 SQLite 错误不代表产品失败。
- 新增 10 项排序仓库测试：候选集合校验与事务回滚、锁定槽位、休息 ±30 秒后换序及到期恢复、零休息换序、旧动作 ID 提交拒绝、同时间戳按提交先后撤销、跨动作撤销重做与跳过完成项、配置编辑、原计划删改、历史及统计独立性。
- 新增 16 项 Widget 测试：动作选择、完整拖动保存/取消、部分完成锁定、候选不足、原编辑入口、过期草稿拒绝及重载、失败重试、重复提交防护、迟到的生命周期读取、完整/部分详情、360/430 dp 浅深主题与 1.3 倍字体。保存成功后的关闭动画保持提交锁定。
- 原 `history_stats_test.dart` 及原训练测试均通过；排序不额外计训练次数或完成组数，整场经过时间口径不变。
- `flutter analyze`：无问题。[静态检查日志](reorder-session-exercises/flutter-analyze.log)
- `flutter test`：48 项通过。[完整测试日志](reorder-session-exercises/flutter-test.log)
- `flutter build apk --debug`：成功。[构建日志](reorder-session-exercises/flutter-build.log)
- `openspec validate reorder-session-exercises --strict --json`：1 项通过，0 个问题。[校验结果](reorder-session-exercises/openspec-validation.json)

## Android 安装与交互

设备为 Pixel_7_Pro Android 16 / API 36 x86_64 模拟器。应用版本 `0.1.0+1`；使用 1080×2400 竖屏，480 dpi（360 dp）及 402 dpi（约 430 dp），字体缩放 1.3。使用 ADB 的真实触摸事件、页面截图和数据库读取验收。[设备与最终 APK 哈希](reorder-session-exercises/device-build.json)、[Flutter Android 日志](reorder-session-exercises/flutter-android.log)。本次应用日志未发现 Flutter 异常或布局溢出。最终 APK 再次覆盖安装后，打开选择并取消的冒烟检查通过，原数据全字段比对仍一致。

覆盖安装前保留模拟器原数据库；安装时未卸载或清除应用数据。原库 v1 含一个部分保存历史及一个未完成会话，覆盖安装后为 v2。五张表的全部原字段逐项比对一致，只有新增字段被回填。[旧字段比对](reorder-session-exercises/migration-preservation.json)。旧会话继续页与旧历史详情均可打开：[旧会话](reorder-session-exercises/upgraded-active.png)、[旧历史详情](reorder-session-exercises/upgraded-history-detail.png)。

交互验收使用可恢复的独立测试数据副本：计划 A、B、C、D，每动作 2 组，组间休息 30 秒，动作后休息 150 秒；A 已完成，B 为当前动作。初始休息 fixture 的截止时间设为十分钟后，以便完成测试。验收结束后恢复原 v2 数据；原计划、历史及未完成会话全字段比对一致，测试会话未留在模拟器原数据中。[恢复比对](reorder-session-exercises/restoration-preservation.json)。备份数据库仅保留在忽略的 `build/qa/`，不作为提交文件。

| 验收动作 | 实际结果与证据 |
| --- | --- |
| 休息中选择 C | A、C、B、D；当前 C 第 1 组；原组时间戳与休息起止时间保持。见 [选择界面](reorder-session-exercises/light-360-chooser.png)、[选择后](reorder-session-exercises/after-choice.json)。 |
| 拖动 D 后取消 | 草稿显示 A、D、C、B；取消后数据库仍 A、C、B、D。见 [草稿](reorder-session-exercises/light-360-drag-draft.png)、[取消后](reorder-session-exercises/after-cancel.json)。 |
| 再次拖动 D 并保存 | 本次顺序 A、D、C、B，当前 D 第 1 组，休息字段完全一致。见 [保存后](reorder-session-exercises/after-drag-save.json)。 |
| 强制停止进程并重新打开 | 当前仍 D 第 1 组、A、D、C、B；截止时间不变，倒计时显示实际剩余值。见 [重启页](reorder-session-exercises/light-360-restarted.png)、[恢复数据](reorder-session-exercises/after-restart.json)。 |
| 完成 D 第 1 组并排列后续 B、C | D 显示“进行中”，无拖动手柄；当前 D 第 2 组保持，后续换成 B、C。期间原 30 秒组间休息自然到期，保存未重启休息。见 [锁定页](reorder-session-exercises/dark-430-partial-lock.png)、[排序后](reorder-session-exercises/partial-d-after-sort.json)。 |
| 撤销上一组 | 只清除 D 第 1 组的时间/完成序号，返回 D 第 1 组；本次 A、D、B、C 排序保留。见 [撤销数据](reorder-session-exercises/after-undo.json)。 |
| 提前保存并查看详情 | 一条历史、2 个完成组；A、D、B、C 按最终快照展示，未完成组准确保留。见 [详情](reorder-session-exercises/partial-history-detail-bottom.png)。完整保存详情另有 Widget/仓库回归覆盖。 |
| 原计划再次开始 | 准备页与新会话均 A、B、C、D，仍为原组数/休息配置，上一场顺序不回写计划。见 [准备页](reorder-session-exercises/next-session-preparation.png)、[新会话](reorder-session-exercises/next-session.json)。 |

以上数据库证据另以 10 条断言核对，均通过：[交互断言结果](reorder-session-exercises/android-assertions.json)。

浅色与深色、360/430 dp 和 1.3 倍字体下，排序文字、锁定状态、手柄、保存/取消按钮完整可见，底部手势区域未遮挡；列表可滚动：[浅色 360](reorder-session-exercises/light-360-scaled-order.png)、[浅色 430](reorder-session-exercises/light-430-scaled-order.png)、[深色 360](reorder-session-exercises/dark-360-partial-lock.png)、[深色 430](reorder-session-exercises/dark-430-partial-lock.png)。

## 数据和操作边界

可移动条件是没有完成组；部分完成与已完成动作锁定位置。选择下一动作及完整排序只影响本次训练，原计划和下次训练保留默认顺序。取消草稿不写数据库。

排序不跳过或重置休息；主动跳过、调整休息和撤销遵守原规则。详情展示最终会话排序，不是撤销/重做时间线。本次未引入动作执行计时、计划导入导出或已撤回的 timer 修复。

数据库升级不删除或重建用户数据，失败回滚；回退包需继续支持 v2，原始 v1 包不能直接打开 v2 数据库。

## 未验证项

没有连接 Android 真机，因此厂商系统、低性能设备及真实器械训练场景尚未验收。此次已完成 Android 模拟器验收，不将这些真机场景标为通过。