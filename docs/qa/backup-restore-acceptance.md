# 完整备份与恢复实施验收

日期：2026-10-17。变更：`add-full-data-backup-restore`。代码已实现，人工辅助使用与完整设备故障验收尚未结束；本报告不表示可以发布。任务状态见[任务清单](../../openspec/changes/archive/2026-10-17-add-full-data-backup-restore/tasks.md)。

## 环境与证据边界

- Windows；Flutter 3.47.5 / Dart 3.13.4；SQLite FFI 仓储、Flutter Widget 与 Android JUnit 测试。
- API 36：隔离的 Pixel_7_Pro 只读模拟器实例，实测 MediaStore Downloads；未写入用户原 AVD。
- API 28：工作区 build 目录内的独立模拟器，1080×1920 / 420 dpi / 2 GiB；实测旧公共 Downloads 路径、系统选择器、卸载重装及 Honolulu 时区。未覆盖全部受支持 Android 版本。
- 本次全部数据来自测试夹具，不使用用户真实记录。没有真机验收证据。
- [原 HTML 核验](../design/backup/verification/qa-results.json)仍只证明原型；不得与下述 Widget、Android 文件或 Flutter 截图证据混用。
- 三个主规格已同步，用户确认保留两项未完成验收后，于2026-10-17完成[OpenSpec归档](../../openspec/changes/archive/2026-10-17-add-full-data-backup-restore/README.md)。未执行Git提交或发布。

命令日志位于 `build/qa/backup/`，是本地构建产物。需要复核时应重新运行对应命令，不把本机日志路径当作已提交附件。

## 实现结果

设置入口为：外观 → 主题色 → 语言 → 适用提醒 → **数据／备份与恢复** → 关于。页面使用 focus-a 的 AppCard、AppTaskLayout、语义主题和现有四主题色；首次／数据说明独立版本提高到2。

已实现完整导出、文件校验与预览、一次替换确认、恢复前保护、原子核心恢复、独立设置阶段、启动核实、撤回、副本导出／恢复／删除。活动会话包括“全部组完成但尚未保存”的情况，不能绕过保护；只浏览数据概况不结束训练。

完整格式是独立的 `settrace.user-backup` v1，UTF-8 JSON，64 MiB、深度32、有界读取、重复键／非法 Unicode／引用／状态校验、RFC 8785 SHA-256；工作 isolate 处理编解码和归一化。计划分享仍是原 v1、2 MiB、默认全选及新增导入语义。v1 黄金样本独立计算摘要，合成 v2 仅用于未来格式拒绝与转换管线测试，从未发布。

数据库升级到 **v6**：v4→v5 增加操作／副本／导出元数据，v5→v6 增加 `plans.sort_order`、`workout_sessions.backup_order` 和中断结果的 `target_summary`。用户已批准[顺序持久化补充](backup-ordering-decision.md)。旧行按原查询初始化，新建／导入／保存训练追加，恢复显式写数组位置；原创建时间、训练日期、时长和统计口径不改写。原生提醒明确接受 v4/v5/v6，不自行迁移。

保护文件先写入、flush、同目录改名、重读校验及登记 ready，之后才允许业务事务。核心数据、epoch 和提交标记同事务；AUTOINCREMENT 高水位保留。设置逐项确认，失败只处理剩余设置，不重做核心替换。启动允许提交后新增的合法记录，不拿旧目标摘要覆盖当前数据；无法核实结果时限制写入。未展示的中断结果在首次说明之后、通知导航之前呈现。

Android 导出先持久记录请求及唯一文件身份，再预留目标，写完关闭、重读摘要、发布。发布回执丢失时核实同一目标；记账失败只修复标记，旧请求不能覆盖较新的导出标记。副本不自动过期；删除针对指定副本，撤回绑定原操作且继承原设置范围，撤回前再次保护新增记录。

## 自动化验证

| 验证 | 实际结果与范围 |
| --- | --- |
| `flutter test --no-pub` | **1125 项全部通过**；日志 `flutter-final-complete.log`。包含既有迁移、计划传输、训练、跳过／撤销、历史／统计、提醒、通知、主题、说明及新增备份测试 |
| 最后 UI 调整后：`flutter test --no-pub test/backup_ui_test.dart --reporter expanded` | **101 项通过**；`backup-ui-final-review.log`。验证副本用途、删除后状态、读取阶段文案及首页调整 |
| `flutter analyze --no-pub` | **No issues found**；最新日志 `analyze-final-review.log` |
| `dart run tool/check_localizations.dart` | 语言包、UI 文案入口、ICU 生成、未翻译报告全部通过；`localizations-final-review.log`，包含最新三个副本用途资源 |
| Android：`./gradlew.bat :app:testDebugUnitTest --offline` | **15 项、0失败／0错误**；`native-final.log` 与 JUnit XML。包括备份存储4、输出提交策略4、数据库兼容2、选择器互斥1、既有计划存储2、提醒策略2 |
| Release：`./gradlew.bat :app:processReleaseMainManifest --offline` | 成功；`release-manifest.log`。实际 release 合并 manifest 无 INTERNET 权限；未修改原系统备份策略。此项不是 release 安装包真机测试 |
| `node --check docs/design/backup/prototype.js` | 通过；新增 B04a/E02a/B16a/B01d 及设置范围说明不沿用旧41状态的 HTML 验收结论 |
| OpenSpec strict 与差异／文档链接检查 | `openspec validate add-full-data-backup-restore --strict` 通过；`git diff --check`通过（仅正常CRLF提示）；16份Markdown的158个本地目标路径均存在，未验证锚点和远程URL |

软件故障注入覆盖：五个保护检查点；各实体写入失败的事务回滚；未知核心结果；每项设置失败、成功写入但日志未记、手动意图终止；提交后刷新失败；导出文件成功但记账失败、回执丢失与旧请求补记；副本缺失／损坏、孤立完整文件、删除中断与删除重试。原生输出提交策略使用与桥接相同的实际函数，注入读／写／空间／关闭／重读／摘要／发布／日志／清理错误。这些不等同于真实文件系统耗尽或在每个边界强制杀进程。

`backup_live_preferences_test.dart` 使用实际主题色控制器和提醒偏好事务，验证等待已确认保存、排空连续选择、失败缓存、恢复后的实际读值。当前锁定的 Android shared_preferences_android 2.4.28 legacy 写接口返回同步 `Editor.commit()` 结果；更换后端仍须保持此确认契约。

### Flutter UI 与辅助输入

- **64 个端到端配置**：360×800、430×800、740×390、768×1024；中英文、浅深；字号1.0／1.3／1.6／2.0与四主题色。运行首页→导出→文件取消→有效预览→确认取消→确认恢复→结果。
- **24 个全视图配置**：360／430 dp × 两语言 × 浅深 × 字号1.0／1.3／1.6，轮换四主题色；覆盖8类视图、全部 BackupFailure 和 checking／validating／protecting／restoring／settings／exporting。此组通过注入页面状态检查布局，不宣称每一种错误都通过实际平台触发。
- 真实服务交互补充：设置入口四种提醒服务状态、设置待处理首页入口、取消／确认删除、选择读取取消、计划分流、预览过期、回滚／未知结果、设置／刷新重试、处理中系统返回、撤回及指定副本导出／恢复；启动未展示结果与通知竞争也有根页面测试。
- 确认默认焦点为取消，Enter取消、切换语言保留候选和设置选择均有测试；共享主题组件测试检查实际四套深浅 tokens 的正文≥4.5:1、必要边界≥3:1及按钮状态。页面复用56 dp主动作／48 dp其他目标。
- 全视图组设置 `disableAnimations: true` 验证静态阶段仍可显示；这些 Widget 结果不能代替 TalkBack 实际朗读、完整键盘遍历、焦点返回或真人减少动画验收。**9.4 保持未完成**。

## Android 真实文件闭环

测试入口：`integration_test/backup_android_test.dart`。除单独指定系统选择器的场景外，测试适配器从实际公共下载文件复制到私有候选；文件输出、摘要、SQLite、持久副本与服务均使用真实实现，偏好使用测试实现。不能据此声称全部真实设置平台组合通过。

| 平台／场景 | 命令要点、日志与实际结果 |
| --- | --- |
| API36 MediaStore | `flutter test --no-pub integration_test/backup_android_test.dart -d emulator-5554`；`android36-integration.log`，1项通过。目标 `content://media/external/downloads/33` |
| API28 旧存储路径及36→28文件传递 | 同入口、`-d emulator-5556`；`android28-integration.log`，通过。API36输出经主机复制到API28公共Downloads后恢复，原文件保留 |
| API28 实际系统选择器点选 | 增加 `--dart-define=USE_SYSTEM_PICKER=true`；`android28-picker-reinstall.log`，通过。使用 DocumentsUI 中实际可见的下载文件，按读取到的UI层级选中。该旧日志的picker诊断字段仍是未修正前的固定值，应结合执行参数及实际UI操作判读；当前测试已修正该字段 |
| API28 系统选择器取消／并发拒绝 | `--name native.picker`；`android28-picker-cancel.log`，1项通过。打开原生选择器、并发allocate被拒绝、Android返回取消、通道再次可用 |
| API28 拒绝旧存储权限 | `--name native.legacy --dart-define=LEGACY_PERMISSION_DENIAL=true`；`android28-permission-denied.log`，1项通过。按实际系统弹窗层级点击DENY，返回permissionDenied、未预留目标、暂存原文不变，后续allocate／discard成功；此前成功导出另行保留 |
| 公共文件卸载保留、重装、跨时区 | 对隔离测试包执行卸载并确认公共源文件仍在，重装后以 `--dart-define=EXTERNAL_BACKUP_PATH=/sdcard/Download/SetTrace-qa-from-api36.settrace.json` 恢复；`android28-post-uninstall-final.log`，1项通过，设备时区偏移 **−600分钟** |
| Android Flutter 页面截图 | `--name native.Downloads --dart-define=CAPTURE_BACKUP_UI=true`；`android-ui-capture.log`，1项通过；见下方3张截图 |

API36实际导出文件：

`SetTrace-backup-2026-10-17-004601-675-ceb69759b6df42b855245b55c49261d7.settrace.json`

回读内容语义摘要：

`af751694db4a4454de61cd576ea05a534d2c21d145faa0d4d07c4a0a4e042861`

两平台均完成“导出→回读→已有数据恢复→新增→撤回→重建服务→副本恢复”。最终3个计划、1场历史；目标与回读的完整语义摘要吻合。夹具包含中英文／同名／空计划、来源已删除历史、完成／跳过／待练、已撤销跳过批次、结束早于开始和原零时长。恢复前后原日期和时长逐项比较，仓储与既有统计回归覆盖其统计口径。跨平台传递发生在两个模拟器环境，不能称为两台真机通过。

### 实际 Android Flutter 截图

API28，中文、浅色、青色，默认字体缩放（系统未设置额外倍率），Honolulu 时区。使用真实备份服务及测试数据的 AppTheme 页面测试入口；截图为 Flutter 渲染表面，不含完整系统状态栏／导航栏，也不是全应用手动使用录像。三张均已实际查看，文字和按钮未见明显溢出，长文件名在确认中换行，替换按钮使用危险语义。

- [备份首页](backup/screenshots/android28-home.png)
- [恢复预览](backup/screenshots/android28-preview.png)
- [替换确认](backup/screenshots/android28-confirmation.png)

预览截图仅显示当前滚动位置；设置选项和文件详情位于后续内容，不能单凭该截图判断滚动末尾、所有安全区或完整辅助使用通过。

## 容量与性能

完整结果及可复现的桌面命令见[格式文档](../user-backup-format.md#容量验证)。桌面 Windows JIT 的十年3653场、8动作×5组为21,547,424字节，编码2093 ms／解码2536 ms，进程峰值RSS 578,473,984字节；64 MiB边界约675 MB。上限−1、上限、上限＋1分别验证接受、接受、拒绝，不能因计划分享限制而拒绝大于2 MiB的完整备份。

API28 / 2 GiB隔离模拟器 / Flutter debug：
`flutter test --no-pub integration_test/backup_capacity_android_test.dart -d emulator-5556`；
`android28-capacity.log`，1项通过。

| 场景 | 字节 | 工作isolate写入ms | 工作isolate读取ms | App进程峰值RSS字节 |
| --- | ---: | ---: | ---: | ---: |
| 十年3653场，8动作×5组 | 21,547,424 | 4490 | 4744 | 603,987,968 |
| 恰好64 MiB | 67,108,864 | 1961 | 2057 | 843,284,480 |

两个场景在同一App进程依次执行，RSS为包含Flutter运行时和测试夹具的累计进程峰值，不是单个isolate的内存分配量。时间包含文件flush及完整校验，未测量十年数据SQLite全量恢复耗时。当前仍有较高峰值，低内存真机和release构建门槛待复核；如不达门槛需继续增量解析优化，不缩减64 MiB契约或丢弃历史。

## 剩余验收与执行步骤

**9.4：真实辅助使用。** Widget已覆盖横屏、平板、200%关键确认及安全取消，但尚需设备上的TalkBack／键盘完整遍历、关闭弹窗后的焦点恢复、阶段／结果播报和减少动态效果验收。记录设备型号、Android版本、语言／主题／字号、触发步骤和结果；分别验证恢复、撤回、删除、设置待处理和检查失败。不能用HTML字号或Widget语义节点存在代替真人辅助技术结果。

**10.3：完整设备故障矩阵。** 软件故障注入、真实选择器取消及通知竞争自动化已经通过；尚未在实际存储与进程边界完成以下矩阵，任务保持未完成：

1. 在隔离设备制造真实空间不足，验证保护文件失败停止替换、公共输出不伪报成功，清理失败后能重试；旧系统拒绝权限已实测，拒绝后再授权与完整重试仍需组合验证。
2. 分别在preparing、保护flush／rename／ready登记、核心事务提交前后、设置写入与日志之间强制结束进程。冷启动只核实，不重放核心；未知结果限制正常写入，副本保留。
3. 分别在导出预留、写入、关闭、重读、发布、记账之间结束进程；核实同一请求的唯一输出，完整文件不重复生成或误删，只有确认不完整目标才清理。
4. 将损坏、超限、预览后变更、旧通知／D17竞争与上述中断组合，检查唯一可核实的业务结果及保护副本。所有操作只对隔离测试数据执行。
5. 继续复核低内存真机的容量和耗时，记录未覆盖的Android版本及文件提供方；真机未通过前不扩展模拟器结论。

10.4已获得两个模拟器间文件传递、实际卸载保留、重装、跨时区及release manifest证据；仍不能推断任意OEM系统迁移、云文件提供方或所有真机结果。首版没有已发布的旧完整格式，兼容证据为独立v1黄金夹具、不同来源应用版本与转换注册测试，不将合成v2称为旧发布版。

## 交付状态

**43/45项完成**，9.4和10.3保持未完成。设计、格式、数据库说明和提案均记录v6顺序持久化及上述证据边界。最终静态检查、本地化检查、OpenSpec严格校验、Markdown本地路径及`git diff --check`均通过；新增权限拒绝集成测试也在API28实际通过。完整辅助使用、设备故障矩阵与低内存真机门槛仍不能视为已验收。
