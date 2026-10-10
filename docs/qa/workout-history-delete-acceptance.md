# 删除训练记录验收

变更：`delete-workout-history`。日期：2026-10-07（Asia/Hong_Kong）。

## 行为与复现步骤

使用独立测试数据库与模拟器，准备同日两条记录（30 分钟/6 组、10 分钟/2 组）、历史月份一条记录（20 分钟/4 组）、原计划及一条活动会话。测试不得删除个人训练记录。

| 场景 | 操作 | 预期结果 |
| --- | --- | --- |
| 查看删除确认 | 进入详情，打开更多菜单并选择删除记录 | 显示名称快照、日期、不可恢复及统计更新说明，按钮可达 |
| 取消删除 | 分别点击取消、弹窗外侧或 Android 返回 | 仍在详情，数据库和统计不变 |
| 同一天精确删除 | 确认删除 30 分钟/6 组记录 | 仅目标及其动作/组数据消失，同日另一条保留；返回列表、周/月次数减 1、当月时长剩 10 分钟/2 组 |
| 删除部分完成训练 | 删除提前保存且含未完成组的记录 | 全部动作及完成/未完成组一并清理，不保留孤立行 |
| 删除最近训练 | 删除最新结束的一条 | 最近训练变为剩余记录中最新的一条 |
| 删除历史月份 | 切到历史月份后删除该月最后一条 | 月份选择不变，所选月时长/组数归零，显示月份空状态；当前自然月次数保持 |
| 删除全部记录最后一条 | 测试库只留一条再删除 | 周/月次数与所选月时长/组数均归零，最近训练为暂无 |
| 进行中/不存在的目标 | 仓储请求活动会话或缺失 ID | 不写数据；缺失目标不伪报本次删除成功，页面清理过期目标并刷新 |
| 数据库级联失败 | 测试触发器阻止子行删除 | 事务全部回滚；记录完整，移除触发器后可重试 |
| 重复点击与返回 | 延迟仓储提交，重复确认及返回 | 一次提交，写入期间保留详情，成功只返回一次 |
| 删除失败重试 | 可控仓储失败后再确认重试 | 保留详情/数据，显示可理解错误，重试可成功 |
| 删除成功但刷新失败 | 注入列表加载失败，再重试刷新 | 提示删除已成功、刷新失败；目标不重新出现；只重试加载，不再删除 |
| 过期查询 | 删除前查询延迟至删除后返回 | 不覆盖新列表，不恢复目标或旧统计 |
| 重启持久化 | 删除后强制停止并重开 App | 历史/数据库仍无目标、动作和组数据；原计划、其他历史与活动训练保持 |
| 主题和触控 | 360/430 dp、浅深主题、字体 1.3 | 确认内容可读、可滚动；菜单和主要按钮至少 48×48 dp |

## 自动测试

- 专项命令：`flutter test test/workout_repository_test.dart test/history_stats_test.dart test/history_delete_ui_test.dart`：32 项通过。
- 仓储：真实 SQLite，完整/部分保存记录删除，两层级联无残留，原计划/其他历史/活动会话全字段保留；`PRAGMA foreign_key_check` 为空；关闭重开后仍删除；注入级联失败后完整回滚并可重试。
- 统计：同日多条、跨周/月边界、最近训练替换、所选月为空与全部为空。
- UI：确认取消/关闭/返回，成功/失败/缺失目标，重复操作/返回保护，月份保留，加载重试和过期响应，360/430 dp × 浅深主题 × 字体 1.3。
- 全量分析、测试和 Android 实机模拟器证据在实施结束后追加。

## 全量检查结果

- `flutter analyze --no-pub`：No issues found（[日志](workout-history-delete/flutter-analyze.log)）。
- `flutter test --no-pub --concurrency=1`：97 项全部通过（[日志](workout-history-delete/flutter-test.log)）。首次默认并发运行中，既有排序测试 `partial current action stays pinned and locks its drag handle` 未及时等到“调整剩余顺序”；删除专项全部通过。串行全量复核通过，未修改排序实现或放宽断言（[首次日志](workout-history-delete/flutter-test-first.log)）。
- `flutter build apk --debug --no-pub`：成功（[日志](workout-history-delete/flutter-build.log)），输出 `build/app/outputs/flutter-apk/app-debug.apk`。


## Android 原生验收结果

使用工作区内独立的 `HistoryDelete` Android 16 / API 36 x86_64 模拟器，测试数据与个人模拟器数据隔离。通过 ADB 真实触摸、UIAutomator 节点、截图及实际 SQLite 数据读取完成验收。

- 1080×2400 竖屏，480 dpi（360 dp）和 402 dpi（约 430 dp），字体缩放 1.3；浅色/深色四种组合全部通过。菜单与菜单项的物理高度分别为 144 px / 121 px；确认按钮高度分别为 144 px / 120 px，对应 48 dp（402 dpi 下 UIAutomator 坐标有整数像素舍入）。
- 四次取消后，五张业务表全字段与 [before.json](workout-history-delete/before.json) 一致。确认内容与按钮清晰可达：[浅色 360](workout-history-delete/light-360-confirm.png)、[深色 360](workout-history-delete/dark-360-confirm.png)、[浅色 430](workout-history-delete/light-430-confirm.png)、[深色 430](workout-history-delete/dark-430-confirm.png)。
- 删除当日部分完成训练 `901` 后，父记录、动作快照及完成/未完成组全部清理；其余记录、原计划、计划动作和活动训练全字段不变：[删除后数据库](workout-history-delete/after-delete.json)。实际列表次数 2→1、40 分钟→10 分钟、8 组→2 组，最近训练换为保留记录：[列表截图](workout-history-delete/after-delete-list.png)、[UI 节点](workout-history-delete/after-delete-list.xml)。
- 强制停止并重开，目标没有恢复，原计划与活动训练可见：[重启后列表](workout-history-delete/after-restart-list.png)、[计划及活动训练](workout-history-delete/after-restart-plan.png)。
- 删除历史月份最后一条后保留 2026 年 9 月，时长/组数归零，当前自然月次数及最近训练保持：[历史月份空状态](workout-history-delete/old-month-empty.png)。
- 删除全部已保存历史中的最后一条后，次数、时长和组数全部归零，最近训练显示“暂无”；重启后仍保持。计划与活动会话仍全字段保留：[全部历史空状态](workout-history-delete/all-history-empty.png)、[最终数据库](workout-history-delete/after-last-delete.json)。
- 全部校验摘要及 APK SHA256：[assertions.json](workout-history-delete/assertions.json)。[复现脚本](workout-history-delete/verify_android.py) 仅接受名称为 `HistoryDelete` 的独立测试 AVD；需先安装 APK 并打开 App 初始化空库，然后依次执行 `seed`、四次 `visual 360/430 light/dark`、`flow` 和 `empty`。
- 删除失败、刷新失败、重复点击、过期查询及活动/缺失目标拒绝由自动化故障注入测试验证；原生正常删除、取消、布局与持久化由上述证据验证。
- `openspec validate delete-workout-history --strict --json`：通过，无问题。最终任务完成 14/14。
