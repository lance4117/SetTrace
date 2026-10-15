# 第三方许可摘要调整验收

当前状态：2026-10-15 已同步两份主规格并完成 [OpenSpec 归档](../../openspec/changes/archive/2026-10-15-add-app-about-and-first-run-notice/README.md)，21/21 项任务完成；未执行 Git 提交或发布。下文未同步／未归档的表述记录各轮验收结束时的状态。

2026-10-15（Asia/Hong_Kong）。用户已确认默认五项摘要、独立详情、完整入口及按项目合并的方案。本轮延续 `add-app-about-and-first-run-notice`，补充任务 7.1–7.3；不修改业务数据、联网策略和首次说明行为。

## 结果

默认仅显示实际存在的 Flutter、sqflite、shared_preferences、package_info_plus、url_launcher，分别附应用框架、本地数据库、本地偏好设置、版本信息、外部链接用途。点击进入可滚动／选择复制的原文详情；低强调“查看全部开源许可”进入按项目排序的完整列表。

相同项目的不同声明集中到同一详情，只去除完全相同全文；共享许可仍关联到每个项目，未命名声明在“其他声明”保留。页面使用现有主题、普通列表行、24 dp 内距及系统返回，无新增装饰卡片，返回保持列表位置。

## 验证

- `flutter test --no-pub test/licenses_page_test.dart test/about_notice_test.dart --reporter expanded`：80 项全部通过，包含 20 项许可专项测试和 60 项原关于／首次说明测试。
- 专项覆盖五项筛选／顺序和用途、共享／多份／重复／未命名声明、原文详情、完整列表、滚动位置、空状态、失败重试，以及 360／430 dp × 中英文 × 浅深主题 × 字号 1.0／1.6。
- `flutter analyze --no-pub`：通过，No issues found。
- `dart run tool/check_localizations.dart`：通过；新增入口、用途、完整列表与其他声明均进入正式中英文资源。
- `openspec validate add-app-about-and-first-run-notice --strict`：通过。
- `flutter build apk --release --build-name=0.2.1 --build-number=7`：通过。测试后使用正常 build 刷新插件注册，避免 `--no-pub` 沿用测试插件生成文件；未手改生成代码。
- 直接读取最终 APK 的 NOTICES.Z：1623 个原始片段，154 个唯一项目；五个主要项目均存在，Flutter 有 10 份不同声明，摘要没有将它们丢弃。声明文件仍打包在 APK 内；发布包依旧不含 INTERNET 权限。

## 交付与边界

最新 APK 为 `build/app/outputs/flutter-apk/app-release.apk`，版本 0.2.1 (7)，55,184,474 bytes；SHA-256：`a37ed49707e09cda8b59126a2762897128101f020c965004a716321a25e51e11`。本轮以组件导航／布局测试和实际 release 包检查为证据，没有新增物理设备或 Android UI 截图验收；前一批许可截图仅代表调整前状态。未重新执行与本次改动无关的全量 708 项测试、卸载／备份验证。

本轮更新了现行页面清单、INT-11／FLOW-17 补充、change 设计／规格和任务记录。未提交、归档、同步主规格或发布。
