# 主题色预设实施与验收

变更：`add-theme-color-presets`。日期：2026-10-15。基线：`focus-a-2026-10-14`；应用 `0.2.2+8`，本次 Debug 构建。主题色功能已实施；已于 2026-10-15 同步两份主规格并[归档](../../openspec/changes/archive/2026-10-15-add-theme-color-presets/README.md)，16/16 项任务完成；未执行 Git 提交或发布。上文应用版本为初版验收构建，后续色块简化见文末。

## 实现结果

设置顺序为外观→主题色→语言→提醒→关于。青色／蓝色／紫色／石墨具有浅深两套强调色，独立于系统／浅色／深色模式。圆形色块和名称合并为整项操作，勾号／外圈／字重表达唯一选中；按实际译文、字号和空间选择四列或两列，不固定卡片高度。

换色即时预览，串行自动保存并合并最新目标；失败回滚最后成功值并提供重试，旧结果不覆盖新选择，回选原色有必要补写。SharedPreferences 缓存失败和重载异常有独立确认值保护。主按钮交互态与逆表面反馈按实际配色满足对比要求；键盘焦点有预留边框，不改变布局。

## 自动化结果

| 检查 | 结果与证据 |
| --- | --- |
| Flutter 静态分析 | `flutter analyze --no-pub` 无问题，见 `theme-color-presets-evidence/analyze.log` |
| 全量回归 | `flutter test --no-pub --timeout 60s --reporter expanded`：902 项通过，见 `theme-color-presets-evidence/full-regression.log` |
| 配色／按钮状态 | `focus_components_test.dart`：八套主色、浅底、pressed／focus 合成与 Snackbar 逆表面正文至少 4.5:1；必要边界至少 3:1 |
| 持久化状态 | `theme_color_controller_test.dart`：有效／缺失／无效值、读取异常、即时预览、重复点选、合并、false／异常／reload 失败、过期结果、回选补写与显式重试；包含真实 SharedPreferences 失败缓存用例 |
| 卡片适配 | `theme_color_ui_test.dart`：96 个宽度×明暗×语言×配色×字号组合，每个验证选择、保存中、失败及重试；360／430 dp、1.0／1.3／1.6；额外短屏横屏／768 dp／长译文／键盘 |
| 共享页面 | `theme_color_scenes_test.dart`：八套配色×P05/W03/W06/X02/H05/C04/D01/D13，共 64 个空／正常／完成／禁用／错误／弹层场景 |
| 根应用集成 | 即时预览先于写入；tab、设置位置、弹层输入、会话身份、完成／跳过、绝对截止保留；语言变化重译失败而不重试，换色本身不增加提醒 schedule 调用；有效通知复用原根状态 |
| 语言资源 | `flutter gen-l10n`、`dart run tool/check_localizations.dart`、`dart run tool/test_language_extension.dart` 均通过；正式包仍仅 en／zh |

原有语言及提醒用例改为适应新增卡片后的内容位置；关于启动用例的销毁后提醒队列等待改为先推进 fake-async 再等待队尾，避免夹具死锁，保留原断言。未改相应业务逻辑。

## Android 实测

仅使用新建的独立 `SetTraceThemeQA` / `emulator-5580`，Android API 36、google_apis x86_64；不使用个人 Pixel AVD。主要截图为 1080×1920、density 480，即 360×640 dp。布局矩阵另覆盖 430 dp、横屏和平板；模拟器证据不等同所有真机。

- `integration_test/theme_color_android_test.dart` 以隔离开关 `THEME_QA_ISOLATED=true` 运行，在独立模拟器内创建测试计划和活动休息。验证全部八套配色、明暗独立、快速选择后离开设置、重新构建应用并重载偏好、同一活动会话的真实完成数与休息截止；日志有八条 PALETTE、RESTART_REST 和 `All tests passed`。
- 主机 `flutter test -d emulator-5580` 遇到 DDS／VM 监听器连接失败；改为 `flutter build apk --debug --no-pub --dart-define=THEME_QA_ISOLATED=true -t integration_test/theme_color_android_test.dart`，安装并直接启动 APK，读取设备端测试断言和日志。此条结果来自设备执行，不宣称主机集成测试命令成功。
- 随后安装 `lib/main.dart` 正常入口 Debug 包，原生 Tab／Enter 将石墨切换为紫色；开启已安装 TalkBack（touchExplorationEnabled=true、服务已绑定），通过探索和双击将紫色选为蓝色，UI hierarchy 确认选中值、颜色名称、默认属性且装饰不重复。
- 正常入口选择跟随系统后，系统 night yes／no 使用蓝色的不同明暗组合，偏好仍为 blue＋system。原生 Home／恢复、Android Back／恢复及 force-stop／冷启动后仍保持蓝色；`cold-restart.xml` 记录重启后的实际选择。
- 在正常入口中对活动会话执行 Home／恢复及 force-stop／冷启动，`rest-before.json` 与 `rest-after.json` 一致：同一会话、当前第 2 组、真实完成 1 组、同一毫秒绝对截止；首页仍显示该训练的 Resume 入口（`rest-cold-restart.xml`）。
- 中文正常布局为单行四项；英文在该短屏宽度及实际字体下重排为两列。完整卡片与后续语言／提醒可正常垂直滚动到达；大字号与长译文无溢出由上述 widget 矩阵验证。

原生键盘与 TalkBack 的 UI hierarchy／服务状态在 `theme-color-presets-evidence/`。设备自动测试与原生辅助服务检查分开执行；曾因运行中外部切换 TalkBack 触发测试框架的 SemanticsHandle 收尾断言，最终无外部干预的设备用例已通过。没有采集语音音频，不将检查语义和实际双击选中扩写为所有语音引擎的发音质量验证。

## 增量场景对应

以下编号只用于本验收索引，按各 delta 的 Scenario 顺序对应；保留主规格原有场景名称。

| Delta 场景 | 对应验证 |
| --- | --- |
| app-experience 1–3：深色、共享弹层、明暗保存失败 | 原 localization_ui、focus_matrix 全量回归；新八套共享场景 |
| 4–5：明暗独立、石墨可读 | Android 八套断言与截图；所有预设对比和逆表面测试 |
| 6–8：默认与顺序、色块／名称操作、大字号重排 | 根设置、卡片交互及 96 组矩阵 |
| 9–11：写入前预览、成功重启、无效回退 | 根应用受控延迟、控制器启动解析、Android 偏好重载和正常入口冷启动 |
| 12–16：失败重试、过期成功／失败、最近成功回滚、回选原色、重复及改选 | 控制器延迟／失败序列、卡片失败／重试、根应用状态用例 |
| 17：未完成请求退出后只认真实偏好 | 保存尚未完成时重新创建控制器仍读取原已确认值、真实失败缓存保护；正常入口读取已保存值，未承诺系统未完成写入必成功 |
| 18–21：休息保持、保存中离开、草稿弹层、减少动画 | 根应用提醒计数／截止／身份／草稿、Android 休息断言、矩阵的减少动画与键盘验证 |
| app-localization 1–4：语言重启、状态保留、写入失败、颜色失败重译 | 原语言持久化回归及根应用配色失败期间中英文切换 |
| 5–7：完整双语、TalkBack、键盘重试 | 正式资源／第三语言检查、单选语义矩阵、设备 TalkBack 双击及原生 Tab／Enter、组件键盘失败 |
| 8–10：长译文、横屏平板、辅助偏好即时换色 | 96 组与长译文／短屏／平板／减少动画测试、Android 语义与辅助输入 |

## 数据与边界

应用实现仅改主题、设置和资源层；SQLite schema、计划 JSON、仓储算法及正式品牌资产未改。跳过不计真实完成，原确认／取消／恢复语义保留，主题色不会调用训练写入或额外调度提醒。

失败／延迟及 reload 故障由受控自动化注入，没有在设备上制造真实存储损坏。Android 主要实测 API 36；未宣称其他 API、真实手机／厂商、所有语音引擎均已验证。新功能没有新增依赖或联网要求；本次不重复与主题无关的 release 隐私／系统迁移验收。

## 后续简化：仅显示色块

按用户后续要求，四个选项去掉可见颜色名称，保留 36 dp 色块、选中勾号／外圈、键盘焦点和完整的本地化辅助名称。常规宽度固定一行四项，不再测量名称；仅容器不足 232 dp 时按触控区域要求两列重排。标题及保存／失败反馈继续保留。上文带名称截图属于初版证据，不代表本次简化后的画面。

`theme_color_ui_test.dart` 的 100 项用例通过，新增断言验证中英文及 1.0／1.3／1.6 字号下不出现颜色文字、四项同一行且触控尺寸及辅助语义保持；原保存、失败／重试、键盘及根应用用例继续通过。见 `theme-color-presets-evidence/swatches-only-tests.log`；本次未重复 Android 实机验收。
