# 记录页通栏月度汇总验收

变更：`refine-history-summary-layout`。实施日期：2026-10-22—23。
目标设计：[记录页规范](../design/history-summary/README.md)。本记录区分 Flutter 自动化、Android 模拟器和真实读屏，原 HTML 草图证据不作 Flutter 通过依据。

## 实现与范围

两张次数卡同排等宽等高，通栏月度汇总位于最近训练和月份选择器上方。
月份之后直接显示日期与记录或相应空状态。汇总标题、时长、真实完成组数和列表
沿用同一 `month` 与 `HistoryStats`；自然周／自然月次数及全历史最近训练保持原口径。
`HistorySummaryCard` 为只读展示，未新增导航或可点击入口。

时长用结构化数字／单位单元与 `Wrap` 重排；小屏使用 16 dp 页面水平内距，
其余 24 dp，卡片按内容增高。完成组数横行空间不足时上下重排。
系统字体缩放保留；无缩字、固定高度、裁切或省略策略。
读屏时长使用一个完整的本地化消息，排除分层子文本重复播报；月份按钮至少 48 dp。

未修改 `HistoryStats`、数据库、仓储、原详情及删除事务、通知、日志、导入导出、依赖。
格式化层仅新增月度卡分量，旧 `duration()` 输出继续用于记录、最近训练和详情。

## Flutter 自动化

工具执行入口：`tool/history_flutter.ps1`，直接调用现有 D 盘 Flutter snapshot；
本地化检查仍运行 `dart run tool/check_localizations.dart`，其子进程通过项目
`build/qa/history-summary/bin/flutter.bat` 调用同一 SDK，未跳过检查步骤。

| 检查 | 命令／证据 | 结果 |
| --- | --- | --- |
| 本地化完整性、ICU 生成、未翻译清单与生成资源 | `dart run tool/check_localizations.dart`；`build/qa/history-summary/localizations.log` | 通过 |
| 新布局初次矩阵 | `flutter test --no-pub test/history_summary_ui_test.dart --reporter expanded`；`build/qa/history-summary/layout.log` | 76 项通过，后续扩展的语言／主题切换测试包含于下行 |
| 受影响回归 | `flutter test --no-pub test/history_summary_ui_test.dart test/history_stats_test.dart test/history_delete_ui_test.dart test/localization_test.dart test/localization_ui_test.dart test/focus_matrix_test.dart test/focus_redesign_ui_test.dart --reporter expanded`；`build/qa/history-summary/regression.log` | 614 项通过 |
| 静态分析 | `flutter analyze --no-pub`；`build/qa/history-summary/analyze.log` | 通过，无问题 |

覆盖依据：

- HIST-01／VIS-01/03／FLOW-12：区域几何顺序、通栏宽度、次数卡等宽等高、月份到记录之间无额外卡片。
- HIST-02/05／INT-09／FLOW-12/13/16：切月联动；当前月、历史月、所选月空 H03 与全部空 H05；初始读取和失败不冒充零统计；删除后保留月份；刷新失败仅重试加载；过期读取不能恢复已删除记录；按钮、遮罩、系统返回取消；防重复与失败重试。
- HIST-03／ADAPT-05：0、59 秒、59 分、整小时、2 小时 1 分和 123 小时 45 分的格式与复数；小时不对 24 取模；UI 使用 0 分、59 分、3 小时 12 分和 123 小时 45 分。
- HIST-04／ADAPT-01–05/07：中英文 × 360/430 dp × 1.0/1.3/1.6 字号；四主题色浅深 × 360×640、740×390、768×1024，长译文和减少动画；单元实际字形选择框及卡片包围范围、完整文本和换行几何断言；末条记录可达且保留底部安全区。语言、主题和字号重建保留所选月及真实值。
- HIST-06／VIS-04/05／ADAPT-06：Widget 语义树存在一次“训练时长，3 小时 12 分钟”，无重复子节点；月份箭头本地化名称、48 dp 命中、Tab 后 Enter 切月。几何顺序与语义共同验证阅读结构，尚不代表真实 TalkBack 连续阅读通过。

失败及修复依据：资源检查器原正则把 ICU `one{hour}` 的字面单位误认作参数，
修正为忽略分支的打开括号并保留嵌套参数检查，新增未知／缺失参数回归；
旧删除测试需等待 `ensureVisible` 动画完成；短屏长译文测试使用滚动寻找延迟构建的月份按钮。
字形边界检查允许 0.5 dp 的字体度量取整误差，仍检查完整内容位于卡片范围。
首次分析仅报冗余 `dart:ui` 导入，已移除并复验。

## Android 环境与设备

SDK：`D:\ProgramData\Android_SDK`；Flutter：`D:\DevTools\flutter`。
AVD：现有 `Pixel_7_Pro`，配置与磁盘在 `D:\ProgramData\Android_AVD`。
Gradle：`D:\ProgramData\DevCache\Gradle`；Pub：`D:\ProgramData\DevCache\Pub`。
Android 用户配置／ADB 密钥：`D:\ProgramData\DevCache\Android`。
TEMP/TMP：`D:\ProgramData\DevTemp\history-summary`。
宿主日志、截图、构建均在本项目 D 盘内。未安装 SDK、系统镜像或新建 AVD。
Android 应用内测试数据库和截图位于模拟器应用缓存，其虚拟磁盘仍在上述 D 盘 AVD 内。

设备：`emulator-5580`，Android 16 / API 36，`sdk_gphone16k_x86_64`。
物理 1440×3120 px，原 density 560；本轮临时 density 640，对应宽 360 dp。
ADB 首次连接未授权，已将密钥与 Android 用户配置改到 D 盘并冷启动同一 AVD 后连接成功，未清除设备数据。

集成脚本：`integration_test/history_summary_android_test.dart`。
每场景使用独立数据库，复用真实仓储与删除实现，包含真实底部导航。
中英文 × 浅深石墨 × 3 小时 12 分/1.0 与 123 小时 45 分/1.6，
核对切月、H03、回当前月、末条安全区、进入详情、取消删除、确认删除返回 H05。
8 个组合场景全部通过，日志：`build/qa/history-summary/android.log`。
完整命令：`flutter test --no-pub integration_test/history_summary_android_test.dart --device-id=emulator-5580 --dart-define=HISTORY_EXPORT_WAIT=true --reporter=expanded`。
已保存 16 张实际渲染截图与 [8 场景元数据](history-summary-layout-evidence/results.json)：

| 场景 | 普通时长／字号 1.0 | 长时长／字号 1.6 |
| --- | --- | --- |
| 中文浅色 | [3 小时 12 分](history-summary-layout-evidence/history-zh-light-11520.png) | [123 小时 45 分](history-summary-layout-evidence/history-zh-light-445500.png) |
| 中文深色 | [3 小时 12 分](history-summary-layout-evidence/history-zh-dark-11520.png) | [123 小时 45 分](history-summary-layout-evidence/history-zh-dark-445500.png) |
| 英文浅色 | [3 hours 12 minutes](history-summary-layout-evidence/history-en-light-11520.png) | [123 hours 45 minutes](history-summary-layout-evidence/history-en-light-445500.png) |
| 英文深色 | [3 hours 12 minutes](history-summary-layout-evidence/history-en-dark-11520.png) | [123 hours 45 minutes](history-summary-layout-evidence/history-en-dark-445500.png) |

同目录 `*-empty-month.png` 为对应切月空状态。截图为独立数据库生成的示例，
本批完成组数为真实生成的 2 组，不是原草图的 63 组，也不是用户个人数据。
已目视核对中文浅色正常字号和英文深色长时长截图：时长单位完整，长时长按完整单元换行，
同排次数卡对齐，统计位于最近训练／月份上方；大字号首屏未显示的内容通过滚动操作验证可达。

截图由设备上的 Flutter `RenderRepaintBoundary.toImage(pixelRatio: 2)` 生成，
是 Android 实际字体与渲染，包含应用底部导航，不包含 Android 系统状态栏和系统导航栏。
字号 1.6 通过 Flutter MediaQuery 注入；本次未核对 Android 系统字体设置的非线性缩放。
截图插件 `convertFlutterSurfaceToImage` 未注册，首次测试因此失败；采用上述渲染边界方式重跑通过，未更改原生注册代码。
首次安装遇到 AVD 内旧测试包签名不一致，Flutter 自动卸载并重装测试包。设备没有被恢复出厂或清除 AVD；该包原有应用数据随卸载清除。测试完成后 Flutter 也会自动卸载测试包，故截图通过导出等待窗口保存到宿主 D 盘。

## 未完成验收

真实 TalkBack 连续阅读、焦点顺序及月份操作仍待人工验证。
模拟器安装了 TalkBack，但本次为无音频的自动化会话；Widget 语义、键盘测试或
服务存在均不能冒充实际听读结果。厂商设备和物理手机未连接。
因此任务 4.2 在所有指定项目完成前保持未勾选。2026-10-23 用户明确选择同步主规格后按此已知待验状态归档；归档不代表真实 TalkBack 验收通过。

本轮没有进行 HyperOS 通知兼容、日志设计或日志导入导出；这些仍是用户明确安排的后续任务。

OpenSpec 严格校验通过。实现与文档任务为 12/13，剩余 4.2 的真实读屏项目；
已同步 `workout-history` 主规格并[归档变更](../../openspec/changes/archive/2026-10-23-refine-history-summary-layout/README.md)，未执行 Git 提交或发布。构建生成的 `app-debug.apk` 是集成测试入口包，
不作为日常安装版本交付。
