# SetTrace 本地化验收

日期：2026-10-10。变更：`add-app-localization`。执行与逐条语境核对：Codex。本记录区分资源／代码核对、自动断言和实际 Android 操作；没有委托外部译者独立审校。

## 资源与语境

正式资源为 `app_en.arb` 和 `app_zh.arb`，各 230 个文案键，键集和参数一致，缺译报告为空。[完整文案与使用位置](localization-copy-inventory.md)包含正常、空状态、校验、取消、重试、原生失败及语义出口。逐条结合调用方核对 Workout／Exercise／Set／Rest／History，保存已完成组、放弃、撤销、删除历史和仅修改本次配置的实际后果。

核对过程中修正：可选重量误暗示必须填写；计划换序误用“未开始动作”规则；所选月份统计误称当前月份；总目标只有一组时的英文复数。最终英文保持完整句子、数量语法和自然操作动词。用户输入的中文计划／动作名是保留的数据，不算应用中文残留。

| 功能域 | 核对与证据 |
| --- | --- |
| 计划、详情、准备 | 创建／改名／删除／空列表／空计划及顺序文案已对照资源和实现核对；中英文实际创建计划、添加动作、进入准备页通过。[英文准备](localization/prepare-en.png)、[中文准备](localization/prepare-zh.png) |
| 动作编辑与校验 | 参数、可选重量、删除含义、滑动提示统一本地化。设备输入 `45,5` 保存为 45.5 kg；解析测试还覆盖 `45.5`、混合分隔、重复分隔、零、负数和非有限数。[英文编辑](localization/editor-en.png)、[中文编辑](localization/editor-zh.png) |
| 设置／主题／语言 | 顺序固定 English、中文；自称不随界面语言翻译。实际切换、偏好重新加载、根应用重建及正常入口进程强制停止／重启后选择与深色主题保持；失败保留原值、重试测试通过。[中文深色设置](localization/settings-zh-dark.png)、[进程重启后的设置](localization/restart-settings.png) |
| 训练／休息／结束 | 两种语言完成 4 组训练、跳过休息、保存并进入历史；倒计时保持 mm:ss。[英文训练](localization/workout-en.png)、[英文休息](localization/rest-en.png)、[英文结束确认](localization/finish-en.png)、[中文训练](localization/workout-zh.png) |
| 本次换序／编辑／撤销／放弃 | 按资源及已有流程核对移动限制、取消、保存、撤销和二次放弃含义；会话 UI、事务、过期状态、失败重试及历史快照回归通过。屏幕阅读器拖动标签也来自语言资源。 |
| 历史／详情／删除 | 日期、月份、时间、时长、数量及定位文案核对通过；删除、取消、目标不存在、失败和刷新重试回归通过。[英文历史](localization/history-en.png)、[英文详情](localization/history-detail-en.png)、[中文详情](localization/history-detail-zh.png) |
| 导入／导出 | 中英文公共 Downloads 写入和内容往返通过；实际名称显示 SetTrace 前缀。同名后缀及事务内新冲突回到预览、取消与整批回滚测试通过。[英文导出](localization/export-en.png)、[英文预览](localization/import-en.png)、[中文预览](localization/import-zh.png) |
| 平台／业务错误 | codec 有类型定位包括第二计划第三动作；两种语言从错误代码生成反馈。权限、未知代码、取消、超限、读取失败、重复提交和私有位置误报测试通过，不直接显示异常栈或协议参数。 |

## Android 实际验证

使用本次新建、可丢弃的 `SetTrace_L10n_QA_36`／`emulator-5580`（API36）和 `SetTrace_L10n_QA_28`／`emulator-5582`（API28），没有操作原有 Pixel_7_Pro。API36 的完整流程为 360 dp、系统字体 1.3 倍、深色主题。另有 360／430 dp、深浅主题、1.6 倍字体和加长文案 widget 矩阵，设置、导航、训练／休息／结束、编辑和传输反馈均无布局异常；主要按钮、拖动与导航点击区域至少 48 dp。长正文和反馈可滚动，按钮允许换行。

| 场景 | 实际结果 |
| --- | --- |
| 英文系统，无语言偏好 | 首屏英文，保存 en。[截图](localization/system-en.png) |
| 中文系统 zh-CN，无语言偏好 | 重启系统后首屏中文，保存 zh；实际系统配置已核对。[截图](localization/system-zh.png) |
| 法语系统 fr-FR，无语言偏好 | 重启系统后首屏英文，保存 en；实际系统配置已核对。[截图](localization/system-fr.png) |
| 中文地区／脚本、第二偏好、无效偏好 | zh-CN／TW／HK／Hant 兼容中文；fr 第一、zh 第二仍英文；空语言列表、非法标签及错误类型读取回退英文。由初始化单元测试覆盖，未把每个变体都称为设备实测。 |
| 手动选择与重启 | 法语系统 fr-FR 下安装正常 main 入口 APK，通过设置选择中文和深色；`am force-stop` 后重新 `am start`，首屏导航为中文，设置仍勾选中文／深色；真实偏好为 `flutter.app_language=zh`、`flutter.theme_mode=dark`。另有实际偏好重读与根应用重建验证。[重启首屏](localization/restart-home.png)、[重启设置](localization/restart-settings.png)、[语义树](localization/restart-settings.xml)。 |
| 状态保持 | 根 widget 集成测试比较同一个 Navigator、tab、编辑 State／controller、完成组数及绝对休息截止时间，切换均不重置。已打开对话框和 Snackbar 也刷新。 |
| 中英文完整训练 | 分别从 UI 创建计划与动作、输入 45,5、完成 4 组、保存历史并打开详情，原中文用户名字不变。 |
| 中英文下载备份 | 实际桥接保存至 `/sdcard/Download`，名称 `SetTrace-plans-<timestamp>.settrace.json`；读取字节与快照相同，经 UI 预览／确认导入后重量与用户名称一致。 |
| API28 权限拒绝／重试 | 真实权限弹窗拒绝，Dart 返回 permissionDenied，未误报成功；再次允许后公共 Downloads 保存成功。[系统权限与 SetTrace 名称](localization/legacy-system-permission.png)、[英文失败提示](localization/legacy-permission-denied.png)、[成功提示](localization/legacy-save-success.png) |
| API28 取消与旧备份 | 真实选择器返回取消时得到 null；随后从 Downloads 实际选择 `训练计划备份-legacy.settrace.json`，读取并解码成功，计划名 `旧中文备份` 保持原样。[文件选择](localization/legacy-system-old-file.png)、[取消后](localization/legacy-picker-cancelled.png) |
| 真实 resolver／原生存储 | API28、36 各 4 项原生测试通过；覆盖 UTF-8、空／超限／损坏／不可读文件、取消／销毁／重复回调、公共下载同名避让、失败清理和实际剪贴板。JVM 存储写入／发布／清理 2 项通过。 |
| 旧数据库与训练恢复 | 现有 v1→v2 迁移、会话／历史快照、训练恢复、休息绝对时间和事务回滚测试全部通过。本变更没有升级数据库或改 JSON v1。 |

实际设备验证使用 Flutter SDK 的官方原生 `FlutterTestRunner`，避开本机调试服务连接问题。`LocalizationIntegrationTest` 必须显式传 `localizationQa=true` 才运行，平常的原生存储测试不会启动 Flutter 场景。完整场景文件为 `integration_test/localization_android_test.dart`；旧系统交互为 `localization_legacy_test.dart`，在日志标记的阶段由执行者操作系统拒绝、允许、取消和文件选择。

```powershell
# 在项目根目录，JAVA_HOME 使用可用的 Android Studio JDK
./android/gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebug :app:assembleDebugAndroidTest -Ptarget=integration_test/localization_android_test.dart
# 只安装在指定的可丢弃 QA 设备上
adb -s <serial> install -r build/app/outputs/apk/debug/app-debug.apk
adb -s <serial> install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s <serial> shell am instrument -w -e localizationQa true -e class com.settrace.settrace.LocalizationIntegrationTest com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner
# 原生故障注入
adb -s <serial> shell am instrument -w -e class com.settrace.settrace.PlanFilesBridgeInstrumentedTest com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner
# 交付前重新构建正常入口，避免把 QA 入口 APK 当作交付 APK
flutter build apk --debug
```

系统首屏测试使用 `EXPECTED_SYSTEM`、`SYSTEM_TAG`、`STARTUP_ONLY=true` Dart defines；Gradle 的 `-Pdart-defines` 需要将每个 `key=value` Base64 编码后用逗号连接。测试截图保存到 QA 应用的 `code_cache`，通过 `adb exec-out run-as` 按原始字节复制到本记录目录。

## 扩展与发布检查

临时完整项目仅新增合成法语 ARB，并生成、验证设置自称／选项／首选匹配／复数／法语日期与逗号小数，实际 debug APK 构建通过。未改业务代码、原生翻译或第二份清单；错误 ICU fixture 被定位拒绝。副本已删除，正式发布只有 en、zh。合成法语是机制测试，不宣称完整法语翻译已发布。

统一语言资源检查、官方生成、静态分析、全部 Flutter 测试、正常入口 debug APK 和 OpenSpec strict 验证的最终结果见[执行摘要](localization/verification.txt)。源扫描不能证明任意未来间接文字出口和翻译语义；新增文案仍须按照语言包维护文档补齐、检查并结合实际语境审阅。本次未将厂商真机、全部 Android 版本或真实磁盘耗尽宣称为实测。
