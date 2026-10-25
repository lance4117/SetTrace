# 本机诊断实施验收

变更：`add-local-diagnostics`；日期：2026-10-24；UI：`diagnostics-ui-2026-10-23`。状态：代码与本机自动化实施完成，跨版本／物理设备验收尚未全部完成。任务按各自完整验收条件勾选，不将已实现等同全部平台通过。

## 构建与环境

业务版本 `0.2.4+10`，SQLite仍v6，完整备份仍schemaVersion 1，首次说明由2升至3。SDK为 `D:\ProgramData\Android_SDK`，AVD为 `D:\ProgramData\Android_AVD`，设备为Pixel_7_Pro／emulator-5554、Android API36、x86_64；缓存和TEMP见[证据入口](local-diagnostics/README.md)。未下载其他API镜像、未创建C盘设备磁盘。

当前release由 `lib/main.dart` 构建，x86_64 APK 21,566,026字节，SHA-256为 `e06e1ae5facd766c95ec5c285920caa6bbe8c47cd69d3b3e5c97b85b0758e44d`。R8映射与APK匹配并留存在D盘构建目录，详情见[release核验](local-diagnostics/release-verification.json)。这是本机验证包，沿用项目既有debug签名，未公开分发。

## 自动化结果

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 全部Flutter测试 | 1237／1237通过，3分13秒；之后补充两条隔离测试并在专项复跑通过 | [完整日志](local-diagnostics/full-flutter-tests.log) |
| 最终诊断专项 | 36／36通过，包括新增Isolate.run异常、关闭记录后完整恢复不复活策略／身份 | [专项日志](local-diagnostics/final-diagnostics-tests.log) |
| 说明版本与提醒展示队列 | 独立60／60通过，亦包含于完整回归 | [说明队列](local-diagnostics/notice-queue-test.log) |
| 静态分析 | 无问题 | [analyze](local-diagnostics/analyze.log) |
| JVM原生单元 | 54／54通过，其中诊断核心38项；无失败／跳过 | [XML汇总](local-diagnostics/native-test-results.json)、[构建测试](local-diagnostics/android-ui-build.log) |
| Android原生平台 | 19／19通过，包含3项诊断平台与16项提醒平台回归 | [平台日志](local-diagnostics/android-platform-tests.log) |
| Android UI实际流程 | 1／1通过，28.721秒 | [UI日志](local-diagnostics/android-ui-tests.log)、[截图目录](local-diagnostics/android-ui/local-diagnostics-evidence/) |
| Release构建／配置 | 成功；无INTERNET、新广泛存储或新增上传／遥测运行SDK，业务系统备份未全局关闭 | [构建](local-diagnostics/release-build.log)、[实际权限](local-diagnostics/release-permissions.txt)、[manifest](local-diagnostics/release-manifest.txt)、[依赖](local-diagnostics/release-dependencies.log) |

测试数量按各自运行计，不相加为独立用例总数。早期失败的等待方式与旧notice fixture已修复；历史分批日志不替代最终结果。Gradle配置日志可出现开发插件配置，但releaseRuntimeClasspath与最终注册不含integration_test运行插件。

## 验收矩阵

| 范围 | 编号／内容 | 状态／证据 |
| --- | --- | --- |
| 核心 | 契约、关联、隐私、队列／存储、保留、错误捕获 | Dart／JVM故障注入通过；API36验证写入前拒绝、noBackup路径、无Activity／引擎、已确认关闭、重启及清空代际 |
| 业务 | 提交与后续失败、提醒因果链、恢复epoch | 全部业务回归通过；真实SQLite提交／失败后状态与诊断身份检查通过；平台提醒领取／去重不变 |
| 导出 | 包内容、真实Download、取消竞争、中断核查 | JVM注入发布边界与取消竞争通过；API36真实公共文件重读与核查通过；旧API待验 |
| 设置入口 | LOGUI-01 | Widget与3张完整滚动截图：外观、主题、语言、全部适用提醒、备份／诊断同卡片、完整关于及底部导航保留；备份不可用诊断仍可达 |
| 状态／控制 | LOGUI-02–04 | 控制器测试：读取失败与真空分开、失败保留确认状态、迟到结果不覆盖新状态、防重入；实际详细开关截图 |
| 导出界面 | LOGUI-05–08 | 预览前不写文件、主动保存、三阶段、实际结果及部分缺失、未知优先核查；第二次新导出进入预览；不自动发送 |
| 清空／故障／隐私 | LOGUI-09–11 | 默认取消焦点、取消不删、部分失败及互斥；L07数据库失败仍能导出并回故障来路，串行重试且不删库；notice3升级／确认失败回归 |
| 适配 | LOGUI-12、VIS-01–05、ADAPT-01–07 | Widget预览384组合：四主题色×浅深×双语×1.0／1.3／1.6×360／430／768／横屏；主要页另测英语大字号短屏。API36为中文浅色及英语深色截图，非全状态真机矩阵 |
| 平台 | API28／29／30／31+及目标API，无引擎入口 | API36实际通过；退出原因fake覆盖不支持、无记录、读取失败、ANR／崩溃／内存／用户退出及trace清理。旧API实际设备待验 |
| 发布行为 | release权限、符号、I/O、性能 | 最终APK权限及R8映射通过；debug平台StrictMode record路径无磁盘I/O通过；release主线程／低配p95与实际崩溃还原待验 |
| 人工 | TalkBack、真机、厂商迁移及听感 | 未执行，不以模拟器替代 |

## 业务真实性与故障注入

`test/diagnostics/repository_diagnostics_test.dart`使用实际SQLite验证创建／完成／撤销／修正、确认回滚、提交后读取／回调失败、删除及关联刷新失败，日志传输失败仍完成业务写入。`business_followup_diagnostics_test.dart`验证完成组后异步调度失败仍保留父操作、恢复核心提交后设置失败及原操作重试／epoch变化，另验证完整恢复不改变已关闭诊断策略。三条故障链使用真实业务仓储与受控后续失败，诊断传输在这些测试中使用fake；不将其称作物理设备崩溃实测。

原生存储测试覆盖总队列／在途预算、优先提交、异常风暴、16+4 MiB配置与缩小预算边界压力、辅助原子文件、7天保留／开机／墙钟变化、详细期限、清空代际、尾行损坏、写入／删除／控制失败和固定段互斥。磁盘／只读／中断由故障注入验证，未填满模拟器或宿主磁盘。导出测试覆盖必要环境失败、可选内容损坏、流式包限制、发布边界异常、取消胜负、journal恢复和原文件核查；这些是确定性注入，不代替所有厂商MediaStore行为。

## 真实Download样包

最新样包为 [SetTrace-diagnostics-2026-10-24-053107-450-9f75510c403948ca9ad8fb38cadcc32b.zip](local-diagnostics/android-ui/SetTrace-diagnostics-2026-10-24-053107-450-9f75510c403948ca9ad8fb38cadcc32b.zip)，从模拟器实际 `/sdcard/Download/` 导回，12,258字节，SHA-256为 `d4d32483b56ec36238839448ab0ea21712235bd8b187ee8390b4f9762b1d1209`。独立工具核对11个条目、96条事件、manifest字节／哈希、原始ID与敏感哨兵；不含控制、密钥、journal或业务数据库，见[校验报告](local-diagnostics/package-verification.json)。

UI结果为saved_partial：此前测试已观察queue_overflow=13，包与界面均保留此事实，没有改成完整成功。状态快照为active=true、completed_count=1，导出前后绝对restEndAt一致。训练测试使用隔离临时业务数据库；没有清理用户原有业务数据或为了截图清空已有诊断证据。样包是测试数据，不作为任意真实用户内容的隐私证明。

## UI截图检查

14张截图逐张核对完整设置、诊断主页、导出预览／三阶段／部分成功、临时详细关闭／开启、隐私、清空确认、深色英语及L07来路。长文件名可换行并选择复制；小容量已按B／KiB显示，未通过缩字／裁切适配。L03中的黄色十字属于测试触点可视化；图片保留原始运行结果，没有修图。Widget覆盖的失败／未知分支不冒充已取得每种设备截图。

## 尚未完成的验收

| OpenSpec任务 | 已完成部分 | 待验条件 |
| --- | --- | --- |
| 8.4 | MediaStore及旧版权限／不覆盖分支已实现，API36公共Download真实通过 | API28旧权限拒绝／永久拒绝与旧文件发布；API29实际MediaStore差异 |
| 10.3 | 所有诊断／控制／staging／journal均在noBackupFilesDir；APK未禁用业务备份，平台验证实际路径 | 真实系统备份→恢复、异机迁移及厂商行为；目录检查不等同恢复实测 |
| 11.2 | API36、无引擎原生、真实Download及fake退出分支 | API28／29／30／31各版本实际运行、旧权限和退出跟踪能力 |
| 11.4 | 当前release构建／权限／映射／依赖、debug StrictMode | 指定低配物理设备普通入队p95≤1 ms、导出中训练响应、release主线程I/O与受控崩溃符号还原 |
| 11.5 | 自动化返回／焦点／主题适配及API36截图 | TalkBack、减少动态效果人工操作、全状态代表性真机矩阵、真人听感与厂商限制 |

这些任务保持未勾选，当前OpenSpec为55／60项完成。未安装额外SDK或创建测试设备来绕过D盘规则；需要对应设备／系统能力才能完成，不能用debug或模拟器结果推定通过。

## 边界

本报告不改写既有备份／提醒／UI验收结论；未完成任务在OpenSpec保持未勾选。无提交、发布或自动上传操作。

设计图保持原版本；新增实现状态写在[对接说明](../design/diagnostics/implementation-handoff.md)。技术文档见[事件目录](../../lib/core/diagnostics/README.md)、[存储控制](../../lib/core/diagnostics/storage-and-control.md)、[ZIP格式](../../lib/core/diagnostics/export-format.md)、[故障运维](../../lib/core/diagnostics/faults-and-operations.md)。OpenSpec严格校验结果另存证据目录，不自动归档或同步主规格。

## 2026-10-25归档记录

用户确认同步主规格并保留5项待验后，变更已归档至 [2026-10-25-add-local-diagnostics](../../openspec/changes/archive/2026-10-25-add-local-diagnostics/archive-notes.md)。新建诊断主规格，更新应用体验与备份隔离要求；全部7份主规格及归档前变更严格校验通过，原有场景保留。

任务仍为55／60完成，5项未完成标记原样保留，不代表验收全部通过。归档文件逐份哈希核对，含 `.openspec.yaml`；见[同步核对](local-diagnostics/archive-spec-sync.json)与[归档结果](local-diagnostics/archive-result.json)。本次只同步规格、归档和整理文档，未执行Git提交或发布；此前测试与设备结论保持原日期及范围。
