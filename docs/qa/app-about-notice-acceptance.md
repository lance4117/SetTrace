# 关于软件与首次说明验收

2026-10-15 后续边界修正：用户明确

当前状态：2026-10-15 已同步两份主规格并完成 [OpenSpec 归档](../../openspec/changes/archive/2026-10-15-add-app-about-and-first-run-notice/README.md)，21/21 项任务完成；未执行 Git 提交或发布。下文未同步／未归档的表述记录各轮验收结束时的状态。

日期：2026-10-15（Asia/Hong_Kong）。

后续已按用户确认精简第三方许可页，最新界面和 APK 验证见 [许可摘要调整验收](licenses-summary-acceptance.md)。下文记录首轮实施结果。变更：`add-app-about-and-first-run-notice`。沿用 `focus-a-2026-10-14` 和现有三线品牌资源；C05/D15/D16、INT-11、FLOW-17–19 / DATA-01 为本次增量。本文与截图是本次实施证据，不改写旧 A 方案验收结果。

## 实施结果

- 设置底部直接展示品牌、简介、实际安装版本／构建号，以及项目、反馈、隐私数据说明和离线第三方许可。元数据和外部打开失败均可重试。
- 计划图标使用 `list_alt_outlined`，保留原有导航顺序、文字和选中语义。
- 新装／旧用户首次遇到说明时显示欢迎弹窗；成功保存已阅后普通重启不重复。返回／遮罩关闭不记已阅，本进程不立即重弹。保存失败有重试及仅本次继续，重看只关闭。
- 欢迎说明与通知导航／权限解释串行；有效和失效通知均重新检查对应会话，等待期间保持原休息截止。
- Android 明确禁用私有数据自动备份，旧 full-backup 与 Android 12+ cloud-backup／device-transfer 配置均排除私有数据库、文件、偏好及相应设备保护存储域。公共 Downloads 不受影响。正式包无 INTERNET 权限。

## 自动化检查

| 检查 | 结果与证据 |
| --- | --- |
| `flutter analyze --no-pub` | 通过，No issues found |
| `dart run tool/check_localizations.dart` | 通过：正式包键／参数、UI 文字出口、ICU、未翻译报告、生成资源测试；中英文说明已人工核对用途、联网区别、删除及计划范围 |
| `flutter test --no-pub test/about_notice_test.dart --reporter expanded` | 60 项通过：偏好故障与缓存、版本及固定链接、许可正常／空／重试、首次／重看、48 个布局组合、长译文／辅助语义／键盘、新旧启动、有效／失效通知与休息截止／权限串行 |
| 最终全量 Flutter 回归 | 708 项全部通过（`--concurrency=2`，2 分 28 秒）；版本信息 mock、页面滚动断言和异步提醒队列清理问题已修正 |
| Android 实机运行方式的集成测试 | `integration_test/about_notice_android_test.dart` 在 API 36 模拟器的导出前、重装后两阶段均通过（各 1 项） |
| 发布构建 | `flutter build apk --release --no-pub --build-name=0.2.1 --build-number=7` 通过，APK 55,168,090 bytes |
| 发布包检查 | aapt 权限列表及合并 Manifest：无 INTERNET；allowBackup=false；两种备份规则引用正确，见 evidence 目录 |
| OpenSpec 严格校验 | 通过，`openspec validate add-app-about-and-first-run-notice --strict` |

最终 release APK：`build/app/outputs/flutter-apk/app-release.apk`，版本 `0.2.1 (7)`；SHA-256：`454766b5c6a3b5b566bd8826c42dfc0266c635ee56c362f0ae555523d6c0e903`。它仍沿用项目现有测试签名配置，本次没有发布。

## UI 与适配证据

主要组件矩阵：360／430 dp × Light／Dark × 中文／English × 字号 1.0／1.3／1.6；补充 740×390 短屏横屏及 768×1024 平板，正文可滚动、按钮可达，无 Flutter 布局异常。长文 fixture 覆盖新增简介／关于／隐私标题，键盘及辅助语义树检查通过；旧 Focus 矩阵也覆盖提醒正常、受限和失败状态下的设置页。

Android 16（API 36，Pixel_7_Pro 的临时只读副本）验证了中文首次弹窗、关于、重看、离线许可、浏览器打开及返回。外部打开确实进入 Chrome；该模拟器的 Chrome 首次使用引导由浏览器自身决定，不将网页加载成功作为 App 的承诺。QA release 使用覆盖值 `0.2.1-qa (7001)`，关于显示与实际安装包一致，证明未写死源码默认版本。正常 release 再以 `0.2.1 (7)` 构建并安装，包元数据另存。

Android 9（API 28，独立新建 QA AVD）验证首次说明、英文深色关于／重看和系统字号 160% 的可滚动说明。配置的 supplementary 窗口为 360×800 dp（wm override，160 dpi）；截图由系统原始 screencap 保存。无厂商真机外观的通过声明。

- [中文首次说明](app-about-notice-evidence/first-launch-zh.png)
- [中文关于与实际 QA 安装版本](app-about-notice-evidence/about-zh-light.png)
- [英文深色关于](app-about-notice-evidence/about-en-dark-api28.png)
- [英文深色大字号说明](app-about-notice-evidence/review-en-dark-api28-font160.png)
- [初版许可页面（精简前）](app-about-notice-evidence/licenses-zh.png)

## 数据、备份与恢复

1. API 36 集成测试创建计划及完整动作配置、已保存历史和活动会话，确认首次说明，并通过真实 Android 文件桥接导出到 Downloads。日志输出实际文件名 `SetTrace-plans-2026-10-15-055401-220.settrace.json`；保留文件副本作为内容证据。
2. Flutter Android 测试工具会清理测试安装。其后的手动卸载命令发现应用已不存在，未将该命令失败算作卸载成功。公共文件仍存在，重装后的第二阶段断言计划、历史、活动会话和已阅状态均未自动恢复；使用从保留文件读取的原始计划文本执行显式导入，仅恢复计划及动作参数，训练会话表仍为空。`ABOUT_QA_RESTORED_PLAN_ONLY` 记录于 after 日志。
3. 安装最终普通 release 后，`pm clear` 返回 Success，再次启动出现欢迎说明，证据见 `clear-data.json` 和相应截图／UI 层级。
4. API 36 的系统云备份 transport 和 Google D2D transport 均返回 `Backup is not allowed`；API 28 的备份请求也被拒绝。release 的实际权限及 Manifest 独立检查通过。新装后的数据空状态与显式导入结果补充验证了应用私有数据和公共导出文件的区别。

## 验证边界

- 以上为 Windows Flutter 测试和 Android 模拟器证据，未执行物理设备配对迁移、真实 Google 云恢复或厂商专有备份工具。系统 transport 拒绝备份不等于逐厂商迁移均已测试；没有声称清理系统既有备份或外部副本。
- 辅助语义树与键盘已检查；未进行真实 TalkBack 语音朗读的人工审听。减少动态效果沿用既有 Material／主题设置和 Focus 适配回归，无额外自定义位移动画。
- 备份／恢复仍仅限原 JSON v1 计划配置，本次不增加历史备份或全量恢复。SQLite 模式、业务仓储、训练快照、组数与休息含义、统计和历史证据均未修改。
- `build/about-*.log` 为本机命令日志；可分享的截图、导出样本、包信息、权限和备份结果位于 `docs/qa/app-about-notice-evidence/`。本次未提交 Git、同步主规格、归档或发布。

## 系统备份限制撤销核验（2026-10-15）

- 按用户澄清撤销额外的系统备份／迁移限制，保留 App 不主动联网、采集或上传记录的边界；手动计划导入导出规则保持原有范围。系统是否备份或恢复由用户设置与 Android 平台决定。
- 移除主 Manifest 的 `allowBackup`、`fullBackupContent`、`dataExtractionRules` 属性及两份排除 XML。未添加启用、禁用或自定义系统备份的替代配置。
- 中英文 D15/D16 本地数据说明区分当前安装的数据删除和 Android 系统恢复；同步当前主规格、README、INT-11 及 DATA-01。既有归档与证据不重写。
- `dart run tool/check_localizations.dart`、`openspec validate app-experience --type spec --strict`、`flutter analyze --no-pub` 通过；最后调整的集成测试另经 `dart analyze integration_test/about_notice_android_test.dart` 检查通过。
- 现有 `about_notice_test.dart`、`plan_transfer_repository_test.dart`、`plan_transfer_codec_test.dart` 共 74 项通过，覆盖说明布局／语言／主题及手动计划传输、重名和数据保留。
- `flutter build apk --release --no-pub` 成功。用 `aapt dump xmltree` 和 `aapt list` 检查实际 APK：无 INTERNET 权限、无上述三项备份覆盖属性、无两份排除规则资源。APK 为 `build/app/outputs/flutter-apk/app-release.apk`，版本 `0.2.2 (8)`，SHA-256：`A44D092E366AC61B499C02879663A95E2158BE9DE8BB9532A6746AF095DAE050`。
- Android 集成测试已取消“系统绝不恢复”的断言，改为允许已存在系统恢复的数据、先解析重名计划再显式导入，并断言已有计划、训练数量与活动会话身份保留。本轮未在设备运行该集成测试，也未验证系统云恢复或厂商换机；配置检查不代表这些流程已通过。本轮未安装、提交或发布。