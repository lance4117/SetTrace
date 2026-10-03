# Android 计划文件存储验收

日期：2026-10-03。变更：`add-plan-import-export`。

## 设备与数据

使用独立、可丢弃的 Android 模拟器：`SetTrace_QA_36` / `emulator-5580`（Android 16，API 36）和 `SetTrace_QA_28` / `emulator-5582`（Android 9，API 28）。关闭 Wi-Fi 和移动数据，360 dp 竖屏，系统字体 1.3 倍。未操作原有 `emulator-5554`。

测试配置为两个计划：“QA 练背”按顺序包含坐姿划船（3 组，组间 90 秒，动作后 0 秒，重量为空）、高位下拉（4 组，组间 120 秒，动作后 150 秒，45.5 kg）；“QA 空计划”的动作列表为空。

## 实际结果

| 检查 | API 36 | API 28 |
| --- | --- | --- |
| 默认文件位置 | 通过；MediaStore 公共 `/sdcard/Download`，无旧写权限声明及授权弹窗 | 通过；公共 `/sdcard/Download`，首次显示系统写权限弹窗 |
| 拒绝及重试 | 不需要旧权限 | 首次拒绝显示明确失败，未生成新备份；重试允许后成功 |
| 完成后反馈 | 显示真实 `.settrace.json` 文件名及“下载目录” | 相同 |
| 重复导出 | 两份 657 字节备份均保留，内容一致 | 两份 657 字节备份均保留，内容一致 |
| 强制同名 | 原生集成测试固定拟用名，两次实际名称不同；原文件字节不变 | 相同 |
| 写入失败清理 | 原生集成测试在真实文件写入部分字节后注入异常，新产物删除，已有备份字节不变 | 相同；临时 `.partial` 文件也未残留 |
| 卸载后保留 | 卸载后 `ls /sdcard/Download` 仍有原备份；重装后系统选择器可选择并恢复 | 相同 |
| 系统选择有效本地文件 | `.settrace.json` 完整进入预览 | 相同 |
| 普通文本 MIME | 系统选择器读取同内容 `.txt`，按内容进入预览 | 原生读取与 Flutter 内容校验均通过；未另做 `.txt` 选择器交互 |
| 取消、失效回调 | 原生结果为 cancelled，重复/旧回调只完成一次，不返回旧文本 | 相同 |
| 空、超限、坏编码、失去访问 | 原生真实 resolver 测试均返回 error；缺失文件、无 READ_CONTACTS 权限的 URI 也被拒绝 | 相同 |

[普通 TXT 预览](plan-import-export/api36-txt-preview.png)与[取消选择后界面](plan-import-export/api36-picker-cancelled.png)已通过实际系统选择器操作；取消预览和随后取消文件选择后，[数据库仍为原来的两个计划](plan-import-export/api36-after-cancel.json)，未显示旧预览。

API 36 的备份文件为 `训练计划备份-2026-10-03-121653-973.settrace.json` 和 `训练计划备份-2026-10-03-121720-379.settrace.json`；API 28 为 `训练计划备份-2026-10-03-121836-959.settrace.json` 和 `训练计划备份-2026-10-03-122003-413.settrace.json`。实际文件名来自保存后的查询/发布结果，未使用私有目录替代下载备份。

[API 36 导出前](plan-import-export/api36-before.json)、[恢复后](plan-import-export/api36-restored.json)、[API 28 导出前](plan-import-export/api28-before.json)保存逐字段核对结果。API 28 文件恢复先通过同样比较，随后清空本应用测试数据，完成跨设备文本恢复，最终配置见[剪贴板恢复结果](plan-import-export/api28-clipboard-restored.json)。SQLite 比较时先停止测试 App，再二进制复制数据库及可能存在的 WAL；没有修改源数据库。

## 自动验证及复现

`PlanFilesStorageTest` 的 2 项 JVM 测试通过：验证 write、flush、close 后才 publish，open/write/flush/close/publish 各阶段异常仅 discard 本次 entry，不返回成功。

`PlanFilesBridgeInstrumentedTest` 在两台设备各执行 3 项测试通过：真实 resolver 的 UTF-8 读取和流式 2 MiB 限制、取消/生命周期销毁/重复回调、公共目录重名和失败清理。大小测试使用没有 SIZE 元数据的 URI，证明限制也在流式读取时生效。picker intent 为 OPEN_DOCUMENT、CATEGORY_OPENABLE、`*/*`；扩展名及 MIME 不决定内容是否有效。

```powershell
# 构建测试 APK；Java 使用项目可用的 JDK
./android/gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebugAndroidTest
# 仅安装/运行在你选定的可丢弃设备上，替换 <serial>
adb -s <serial> install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s <serial> shell am instrument -w -e class 'com.settrace.settrace.PlanFilesBridgeInstrumentedTest#readsUtf8AndRejectsEmptyOversizedInvalidOrUnreadableFiles,com.settrace.settrace.PlanFilesBridgeInstrumentedTest#cancelledAndDisposedPickersNeverReturnStaleContent,com.settrace.settrace.PlanFilesBridgeInstrumentedTest#publicDownloadsCollisionsAndWriteFailureCleanup' com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner
```

旧系统存储测试需先在真实应用界面允许存储权限；如果使用 shell 设置测试权限，必须同时授予该系统存储组的 READ_EXTERNAL_STORAGE 和 WRITE_EXTERNAL_STORAGE。权限拒绝/允许/重试的用户流程已单独在 API 28 实际操作完成。

Dart 平台 5 项测试确认 native success/cancelled/error 的映射、重复请求防护、实际名称反馈、私有位置不能伪报成功及超限在调用前被拒绝。原生 I/O 在后台执行，结果回到主线程；Activity 销毁使 pending 请求取消，AtomicBoolean 保证一次完成。

本次执行范围是 API 28、36 模拟器及故障注入；没有把厂商真机、其他每个 API 版本或实际磁盘耗尽标记为已实测。
