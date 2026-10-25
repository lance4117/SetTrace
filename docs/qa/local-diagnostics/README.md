# 本机诊断实施证据

对应变更 `add-local-diagnostics`，UI版本 `diagnostics-ui-2026-10-23`。本目录保存命令输出、测试报告、包检查和设备截图，全部保存在当前D盘项目。

开发入口：在项目工作目录运行 `powershell -NoProfile -ExecutionPolicy Bypass -File tool/diagnostics_dev.ps1 -CheckOnly`；通过后用同一脚本的 `-Tool flutter/dart/gradle/adb` 执行工具。脚本固定SDK、AVD、Android用户目录、Gradle/Pub缓存和本任务TEMP/TMP，并检查实际AVD磁盘路径。

每条证据记录日期、命令、构建／版本、设备／API、语言／主题／字号、操作、实际结果、验收编号和限制。自动化、模拟器、真机分开；未执行项不标通过。公共样包只使用测试数据，不存个人诊断内容。

汇总见 [实施验收](../local-diagnostics-acceptance.md)。设计草图仅作视觉对照，不是功能或设备证据。

## 最新可复跑入口

在本项目目录依次运行，Android构建不要并行（Flutter插件注册文件按debug／release重生成）：

```powershell
& tool/diagnostics_dev.ps1 -Tool flutter -ToolArgs @('test','--no-pub','--reporter','expanded')
& tool/diagnostics_dev.ps1 -Tool flutter -ToolArgs @('analyze','--no-pub')
& tool/diagnostics_android_qa.ps1 -Mode ui -CompatibilityKey 'C:\Users\Lance\.android\debug.keystore'
& tool/diagnostics_pull_evidence.ps1
& tool/verify_diagnostics_package.ps1
& tool/diagnostics_android_qa.ps1 -Mode platform -CompatibilityKey 'C:\Users\Lance\.android\debug.keystore'
& tool/diagnostics_release_qa.ps1
```

CompatibilityKey只用于兼容现有模拟器安装签名，**只读既有C盘密钥**，所有重新签名副本在D盘 `build/local-diagnostics/`；不卸载、不清空已有业务应用。其他设备没有该兼容需要时省略参数。脚本限定已选的emulator-5554，不会自动测试真机。UI测试使用临时隔离业务数据库、测试哨兵并恢复偏好；不会为了截图清空已有诊断记录，因此样包可以含此前测试留下的真实缺口。

AGP9当前debug APK是 `build/app/intermediates/apk/debug/app-debug.apk`，测试APK是对应 `androidTest/debug` 文件；`build/app/outputs/apk`可能是旧产物，不用于安装。release由Flutter正常入口构建，不使用 `--no-pub`，避免保留integration_test开发插件注册；测试插件未加入release运行依赖。

| 证据 | 最新结果／用途 |
| --- | --- |
| [full-flutter-tests.log](full-flutter-tests.log) | 1237项完整回归通过；涵盖计划、训练、历史、提醒、传输、备份、本地化、主题与诊断 |
| [final-diagnostics-tests.log](final-diagnostics-tests.log) | 最终诊断专项及新增isolate／备份隔离检查 |
| [analyze.log](analyze.log) | 静态检查 |
| [native-test-results.json](native-test-results.json) | 54项JVM测试，诊断核心38项；测试XML汇总 |
| [android-platform-tests.log](android-platform-tests.log) | API36，19项原生平台／提醒测试 |
| [android-ui-tests.log](android-ui-tests.log) | API36，1条实际UI集成流程 |
| [实际截图](android-ui/local-diagnostics-evidence/) | 14张原始运行截图及export-result.json；不是重绘草图 |
| [package-verification.json](package-verification.json) | 最新公共Download ZIP的独立校验；文件路径／大小／SHA-256、缺失原因与训练连续性 |
| [release-verification.json](release-verification.json) | APK／R8对应哈希、签名边界与权限；映射留在D盘build产物 |
| [release-manifest.txt](release-manifest.txt)／[release-dependencies.log](release-dependencies.log) | 最终release资源与运行依赖证据 |

只有API36镜像已实际可用。API28／29／30／31单独设备、旧权限界面、TalkBack、真人听感、厂商迁移、指定低配release性能均未执行。JVM故障注入、适配fake、Widget矩阵、模拟器平台测试与人工真机结论不能互相替代。

历史分批日志保留其原测试范围；最终汇总优先引用以上文件。设计阶段 `documentation-checks.json`、草图哈希和既有备份／提醒验收报告保持历史含义，不回写成此次实施证据。

## 归档状态（2026-10-25）

用户已确认同步规格并保留5项待验。变更已移至 [2026-10-25-add-local-diagnostics](../../../openspec/changes/archive/2026-10-25-add-local-diagnostics/archive-notes.md)，主规格新增app-diagnostics并更新app-experience／data-backup；任务保持55／60，未执行Git提交或发布。[同步核对](archive-spec-sync.json)、[规格校验](archive-spec-validation.log)、[归档前变更校验](archive-change-validation.log)与[移动文件核验](archive-result.json)分别记录本次操作；早期JSON中的活动路径属于原始运行记录，不批量改写。
