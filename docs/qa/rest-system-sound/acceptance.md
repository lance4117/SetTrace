# 系统声音与诊断补强实施验收

变更 `fix-rest-sound-and-diagnostics`，2026-10-27 开始、2026-10-28 留存。安装包版本 `0.3.1+12`，当前任务验收 **26/30**。2026-10-28 已按用户选择同步主规格并[归档](../../../openspec/changes/archive/2026-10-28-fix-rest-sound-and-diagnostics/README.md)，四项待验保留；当前工作区有未提交改动，未执行 Git 提交或发布。

已实现：运行时系统通知音、单次可观察播放器、最多两个稳定振动通道、保守继承系统限制；设置显示真实有限状态并提供独立试听／停止与系统设置。三种历史声音值继续往返，SQLite v6、完整备份 1 不变。

诊断新事件版本 2、新包版本 2，接受旧 1／新 2 混存，旧证据不重写。补充音频请求与实际状态、真实生命周期和回调、提交后状态转换、取消身份、可见祖先、初始化终态及有界构建归属。摘要使用两个 64 项候选池、256 项归并缓存，最多 64 条／32 KiB，缓存淘汰与省略分别披露；缓存之外的操作组可能重复，不能把摘要省略当作原始日志丢失。

## 已执行的检查

| 范围 | 真实结果与证据 |
| --- | --- |
| Flutter 全量回归 | 1,246 项通过，见 `dart-regression.log`；之后补充边界的专项 94 项及因果／转换 6 项通过，不把重叠测试相加当作独立覆盖 |
| 原生 JVM | 68 项通过，每套件零失败结果见 `native-results.json`；声音策略／空创建／异步错误／迟到回调／超时／未知读数、版本混存、构建映射与摘要压力等 |
| Android API36 | `android-platform.log` 的 19 个条目：17 通过、2 个 assumption skip。跳过的是真实精确闹钟到期和替换／取消时序，原因是本模拟器没有精确闹钟能力；没有把跳过计为通过 |
| 平台已覆盖 | SQLite 领取与竞争、内容静默刷新、稳定通道、已有静音／封禁／禁振与开关往返、预览无通知／无领取、无 Activity 日志、真实 MediaStore Download 发布及哈希重读 |
| UI | 四主题色浅深、中英文、1.0／1.6 字号、360／430／640 横屏／768 dp，声音区独立操作至少 48×48 dp，无布局异常；D17、D18、保存失败重试及取消保留截止 |
| 静态分析 | `analyze.log`：No issues found |
| 独立 ZIP 校验 | 原始用户 ZIP 只读校验通过，见 `legacy-zip-verification.json`；隔离混合样本通过，见 `mixed-zip-verification.json`。未知版本、声音 URI、原始 ID、哈希损坏样本真实拒绝，见 `verifier-rejections.log` |
| OpenSpec | `openspec-validation.json` 严格校验通过；任务勾选按已完成验收，不把计划完成当作实施完成 |
| release | 最终包在 API36 模拟器覆盖安装、实际版本 0.3.1+12 和启动通过，见 `release-smoke.log`，这不是听感验收。`release-verification.json` 保存实际 APK 路径／字节／SHA-256／源提交／R8 映射；`release-permissions.txt`／`release-manifest.txt` 核对无网络、后台服务或额外广泛权限，正式声音路径不访问 raw 音频 |

首次离线 connectedDebugAndroidTest 缺少本机 UTP 宿主缓存，随后使用相同已构建 APK 直接 adb instrumentation 完成实际平台测试。没有下载 SDK 或创建新 AVD。

重复平台运行曾暴露旧测试的 `qa_muted` 标记未隔离，现仅清理该夹具明确创建的历史 QA 标记；没有清空应用数据或删除生产通知限制来取得通过。

## 路径与复现命令

所有命令显式在项目目录执行。SDK `D:\ProgramData\Android_SDK`，已有 AVD `D:\ProgramData\Android_AVD\Pixel_7_Pro.avd`，Gradle／Pub／Android 缓存在 `D:\ProgramData\DevCache`，TEMP/TMP 为 `D:\ProgramData\DevTemp\fix-rest-sound-and-diagnostics`。实际检查见 `build-environment.json`。

```powershell
./tool/diagnostics_dev.ps1 -Tool flutter -ToolArgs @('test','--no-pub')
./tool/diagnostics_dev.ps1 -Tool flutter -ToolArgs @('analyze','--no-pub')
./tool/diagnostics_dev.ps1 -Tool gradle -ToolArgs @(':app:testDebugUnitTest',':app:assembleDebug',':app:assembleDebugAndroidTest','-Ptarget-platform=android-x64','--offline')
./tool/rest_sound_platform_qa.ps1 -CompatibilityKey $ExistingDevelopmentKey
./tool/diagnostics_dev.ps1 -Tool flutter -ToolArgs @('build','apk','--release','--target','lib/main.dart')
./tool/rest_sound_release_evidence.ps1 -CompatibilityKey $ExistingDevelopmentKey
python tool/diagnostics_v2_fixtures.py
./tool/verify_diagnostics_package.ps1 -Package docs/qa/rest-system-sound/fixtures/mixed-v2.zip
openspec validate --specs --strict --json
```

兼容重签只读取已有开发签名，避免覆盖安装签名不匹配；APK 与符号均留存在本项目 D 盘 build/rest-system-sound。未复制或导出签名密钥。仍是原开发签名配置，不代表商店发布。

## 未完成的验收与证据边界

OpenSpec 2.3／2.5 保留未完成：虽然迁移及接口已经接入且 API36 的部分路径已验证，API26–29 能力差异、标记失败／目标丢失等迁移工况，以及系统默认音实际切换／通道自选覆盖的完整平台验收仍不足。

6.3／6.4 保留未完成：未连接小米 HyperOS 真机，未核对手机 APK 身份，没有正常模式下的真人听感、TalkBack、锁屏／后台声音证据。旧 API 系统音回退及跨版本真实通道迁移未完成。模拟器启动时禁用宿主音频，其结果不能证明“用户听到了”。

用户已纠正 10 月 27 日约 20:20 的漏提醒发生在后台。现有证据只能说明已安排后包内未见回调／输出，不能直接归因 HyperOS。此次没有引入前台服务、唤醒锁或后台无限制引导，没有改变首次窗口、重复不补发或恢复过期规则，不承诺修复后台必达。

旧手机安装包与此前本机缺 raw 资源 APK 未做哈希身份比对，因此资源缺失仍是线索，不能写成已确认手机根因。此次系统声音路径消除了对这些自定义资源的运行时依赖。

## 归档核对

归档 Schema 为 spec-driven。两份主规格共修改 6 条要求并增加 20 个场景，其余要求保持；全部 7 份主规格和归档前变更均通过严格校验。归档后活动列表不再包含本变更，原任务保持 26/30，目录移动前后文件哈希一致。核验见 `archive-verification.json`、`archive-sync-verification.json`、`archive-specs-validation.json` 和 `archive-change-validation.json`；此前的 `openspec-progress.json` 是归档前快照，其旧路径不再是活动变更路径。
