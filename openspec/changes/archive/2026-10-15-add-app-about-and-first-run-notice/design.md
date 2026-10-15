# Design

## Context

动机及范围见 [proposal.md](proposal.md)。当前 `SettingsPage` 以 `ListView`、24 dp 页面内距及 `AppCard` 组织主题、语言和可选提醒设置；底部显示本地数据短说明。`AppBottomNav` 使用 22 dp Material 图标，计划当前为 `fitness_center_outlined`。`SetTraceApp` 已持有 `SharedPreferences`、根 Navigator、通知跳转及提醒授权解释弹窗，尚无首次说明状态。

`pubspec.yaml` 当前配置 `0.2.1+7`，Android Gradle 使用 Flutter 的版本字段并允许构建覆盖，因而不能将 YAML 数字硬编码到界面。主 Manifest 无 INTERNET 权限，但未显式配置系统备份；debug/profile Manifest 为开发保留 INTERNET。导出桥接将计划写入公共 Downloads，按现有规格在卸载后保留。当前未发现项目根许可证文件，不能在本变更中臆定项目开源许可证。

本设计涉及跨启动流程、原生配置和依赖，满足创建 design 的条件。与现状的差异是新增说明及元数据入口、明确备份限制和替换一个导航图标；现有数据库、训练规则与传输格式保持。

## Goals / Non-Goals

**Goals:**
- 在现有设置页和弹窗体系内补齐可验证的产品与数据说明；元数据、链接和偏好失败都有真实结果。
- 首次说明与通知跳转／权限解释协调，始终保持活动会话和绝对休息截止。
- 发布包的数据与联网行为能够支持界面中的承诺。

**Non-Goals:**
- 不重做设置页布局、全局导航或品牌，不引入另一套 UI 主题、装饰插画、远程字体或网页内容。
- 不添加历史导出、全量恢复、云同步、账户、自动更新或数据清理按钮；不修改业务库版本、仓储事务及训练资格判断。
- 不删除用户旧导出文件、清理系统既有备份或承诺能控制任意厂商／第三方备份工具，不为仓库指定新许可证。

## Decisions

### 1. 所有画面延续 docs/design 的现有组件

以 `docs/design/README.md`、`SetTrace_UI_Design_System_and_Flutter_Spec.md`、`screens-and-states.md`、`interaction-spec.md`、`acceptance-checklist.md` 的 `focus-a-2026-10-14` 为准，品牌另遵循 `settrace-brand-final/design-guide.md`。不采用先前图标预览图中的放大尺寸作为运行尺寸。

| 本次画面／行为 | 既有依据 | 组件及落点 | 验收 |
| --- | --- | --- | --- |
| C01/C02/C04 底部关于分区；本变更局部 C05 | CMP-02、INT-10 | `SettingsPage`、`AppCard`、有标签的链接行；所有提醒状态下均保留 | VIS-01–05、ADAPT-01–06 |
| 本变更局部 D15 首次说明 | CMP-01/04/05、INT-06/07/10 | 根 Navigator 上的可滚动说明弹窗、`AppButton` 或统一主题按钮 | FLOW-16、ADAPT-01–04/06/07 |
| 本变更局部 D16 重看说明 | CMP-04、INT-07/10 | 与 D15 共用正文，使用“关闭”动作，不改首次已阅值 | VIS-01–05、ADAPT-01–07 |
| P01 等一级页面底部计划入口 | 主规范第 4 节、INT-10 | `AppBottomNav` 中替换为 `list_alt_outlined` | VIS-01–04、ADAPT-06 |
| X01–X04 的备份说明 | INT-08 | 引用现有导出范围，不新增备份入口或动作 | FLOW-10/11 |

C05/D15/D16 在本变更中用于定位新目标；实施时再写入现行设计页面清单，不重写归档产物。

关于标题与现有“外观／语言／提醒”分区标题同级，间距 24 dp、标题与卡片间 12 dp。卡片 16 dp 圆角，不套卡；品牌标志与名称、简介及版本在上，项目主页、问题反馈、隐私与数据说明、第三方开源许可为下方普通行。现有本地数据短说明保留在合理页尾，避免重复整段正文。三线品牌使用正式母版衍生的打包 PNG，独立标志显示 40 dp，保持比例、单色、净空和主题对比，不将品牌深绿替换成全局交互色。

所有颜色取现有 `appColors`／Material 语义色；正文 16 sp，辅助 14 sp，弹窗标题 22–24 sp；对比标准沿用 VIS-02。导航维持 22 dp 和现有选中背景。声明弹窗 20 dp 圆角，宽度受可用空间约束，正文滚动与按钮区分离；主按钮至少 56 dp，其余操作至少 48×48 dp。中英文、长文与 1.6 字号采用换行／增高／滚动，不缩字。关闭后恢复焦点；装饰标志和图标不重复朗读。

替代方案：单独完整“关于”页面、多页引导及系统默认未适配的 AboutDialog。当前内容有限，直接展示元数据更易找，且能复用现有风格；仅许可明细可进入独立可返回页面，其主题、标题和返回标签也必须符合现行规范。

### 2. 共享说明正文，使用明确的数据边界

中英文使用同一组结构化 ARB 消息，首次和重看共用正文，标题／动作可分别本地化。首版内容基线如下，译文保持同义，不扩张承诺：

| 内容 | 中文 | English |
| --- | --- | --- |
| 首次标题 | 欢迎使用 SetTrace | Welcome to SetTrace |
| 简介 | SetTrace 是一款轻量、离线的训练记录工具，帮助你制定训练计划、记录每组训练并查看历史。 | SetTrace is a lightweight, offline workout tracker for creating workout plans, logging sets, and reviewing your workout history. |
| 隐私与联网 | 无需注册账号，不收集或上传你的个人信息与使用数据，App 本身不主动联网。打开项目主页等外部链接时，将由浏览器访问网络。 | No account is required. SetTrace does not collect or upload your personal information or usage data, and the app itself does not initiate network connections. External links, such as the project page, open in your browser and may use the internet. |
| 本地数据 | 训练计划、训练记录和设置保存在设备上。卸载 App 或清除应用数据会删除应用内的数据，请提前保存需要保留的计划。 | Your workout plans, history, and settings are stored on this device. Uninstalling the app or clearing its data removes the data stored inside the app. Export any plans you want to keep beforehand. |
| 计划备份与分享 | 你可以通过文件或复制文本导入、导出训练计划。备份仅包含计划和动作配置，不包含训练历史或进行中的训练；已导出到下载目录的文件不会随卸载自动删除。 | Import and export workout plans using files or copied text. Backups contain only plan and exercise settings, not workout history or an ongoing workout. Files exported to Downloads are not automatically deleted when you uninstall the app. |
| 首次动作 | 我知道了，开始使用 | Got it, let's begin |
| 重看标题／动作 | 隐私与数据说明／关闭 | Privacy and data / Close |

关于分区的一句简介为“轻量、离线的训练记录工具，专注每一组。”／“A lightweight, offline workout tracker. Focus on every set.”。不加入同意协议勾选、广告标语或额外权限申请。

### 3. 按说明版本持久化已阅，退出说明不等于同意协议

为说明建立独立本地偏好键（例如 `app_notice_seen_version`），本次说明版本为 1，与应用版本解耦。键缺失、无效或低于当前说明版本则待展示；旧用户无需检测是否已有计划。普通升级保持已阅，不按每次应用版本升级重弹。

启动在主题／语言初始化和根页面可展示后检查，仅在前台安全时机展示一次；维护会话内已展示／展示中状态，重建、旋转、前后台切换不会重复压栈。用户点击首次按钮时进入提交态、禁止重复提交及破坏提交的返回，成功持久化后关闭。写入返回 false 或异常时恢复真实偏好缓存，显示当前语言的“无法记住已读状态，下次打开可能再次显示”反馈，允许重试；额外提供失败态“继续使用”出口，仅在本次进程抑制再次展示，不伪报保存成功。

非提交中 Android 返回／点击遮罩可关闭，返回根页面或原上下文，不记录已阅；本次进程不立即重弹，下次冷启动仍展示。进程在确认前退出同样不记录已阅。读取偏好失败时不崩溃，按未读处理。清除数据及正常不恢复私有数据的重装重新展示。D16 手动重看不写首次状态、不改变下次自动展示资格。

替代方案：强制勾选同意、禁止退出、每次版本升级弹出。说明不构成数据处理授权，采用一次已阅提示减少干扰，失败时保留可用出口。

### 4. 启动弹窗与通知使用串行呈现

在 `SetTraceApp` 的根路由层协调 D15、通知导航和 D11 授权解释，不能用全局布尔变量各自弹窗造成叠层。待展示说明时先记录通知目标，待关闭后再用既有会话身份校验导航；重复目标不堆栈。期间目标结束则依原规则给出不可用反馈，不打开其他会话。D11 仅在原有实际使用条件成立时、D15 关闭后展示，不因首次声明触发通知权限申请。

提醒配置、有效休息同步、到期判断和后台调度继续执行；只延后导航／授权解释的呈现，不延后仓储写入，不重置绝对截止。说明期间自然到期仍使用现有一次有效反馈规则。计划默认配置与活动快照独立；本变更不调用完成、结束休息、跳过剩余组、撤销完成或恢复跳过操作。

### 5. 安装信息和外部访问使用可替换的平台服务

拟采用 `package_info_plus` 读取实际安装版本和构建号、`url_launcher` 用 external application 模式交给浏览器；实施时选择适配当前 Flutter/Dart/Android 工具链的稳定版本并锁定依赖，不升级整个项目工具链。服务可注入以验证失败，UI 不直接耦合测试环境插件。

关于分区显示版本名称和构建号（例如 `0.2.1 (7)`，此值仅为格式示例）。异步读取失败显示“版本信息暂不可用”及重试，不阻止其他内容，不以 YAML 或猜测值伪装真实安装版本；重复重建避免重复请求。

固定项目 URL 为 `https://github.com/lance4117/SetTrace`，问题反馈 URL 为其 `/issues`。仅用户点击才交给浏览器；不嵌入 WebView、不预取网页或自动检查更新、不把计划和设备数据附加到 URL。打开失败显示本地化提示及重试，返回 App 保留设置滚动位置、tab 与训练。第三方许可从 Flutter 已打包许可注册表读取，页面离线可用；空列表显示真实空状态。许可正文保留来源原文，应用拥有的导航和标题使用当前语言。

### 6. 本地隐私承诺落实到发布配置

在主 Manifest 明确关闭平台自动备份（`allowBackup=false`），补充旧系统 full-backup 与 Android 12+ data-extraction 规则，分别排除 cloud-backup 和 device-transfer 的应用数据库、shared preferences、内部文件及相关设备保护存储域；覆盖规则必须以目标 SDK 支持的合法域和合并产物为准。仅设置 allowBackup 不足以验证各平台设备迁移，必须检查规则并运行可用的备份／迁移验证。

保持 release 无 INTERNET 权限，不添加分析、远程日志或上传 SDK；debug/profile 保留 Flutter 调试权限，不能用调试包证明 release 承诺。外部浏览器联网和用户主动选择的文档提供方由外部应用负责；本 App 不主动上传。

该配置限制之后的应用私有数据备份，不保证清理系统已有副本或控制任意 OEM／第三方工具。验收记录实际 Android 版本和备份传输器，未验证项明确列出；发现目标平台仍会恢复私有数据时阻止按该隐私目标发布，先修正平台规则或重新讨论措辞，不能静默弱化承诺。公共 Downloads 不加入应用私有数据清理，沿用卸载后保留的导出规格。

## Risks / Trade-offs

- [旧用户升级遇到说明遮住通知目标] → 串行呈现并在关闭后重新验证最新会话；不缓存旧训练位置。
- [已阅保存失败导致反复阻塞] → 明确失败反馈、重试及本次继续出口；下次启动仍按真实状态提示。
- [外部链接被误认为 App 联网／浏览器无法打开] → 声明区分浏览器，失败可重试，禁止启动时预取。
- [系统备份实现因 Android/OEM 不同而变化] → 两代规则和合并产物检查，平台行为验证记录环境；不承诺抹除既有外部副本。
- [关于内容挤压提醒设置、大字号弹窗按钮不可达] → 保留原设置顺序，单层卡片、正文滚动和安全区，执行中英文主题矩阵。
- [既有启动测试被首次弹窗拦截] → 普通测试显式标记已阅或经过真实确认；单独测试未读路径，不在生产逻辑加入测试绕过。

## Migration Plan

不迁移 SQLite；首次说明偏好缺失自然覆盖新装与旧用户升级。安装版本信息由已安装包提供。新增打包品牌资源不改 Android 启动器身份。

实施按依赖接入、说明内容、启动协调、平台配置和验收推进，同时在现行设计文档中补充目标画面／状态和增量验收项；不改历史证据。回退 UI 时可忽略新偏好键，保留全部业务数据；不得为回退而自动开启系统备份。不得在未重新评估声明的情况下发布改变隐私边界的回退版本。

### 7. 许可页面采用主要项目摘要、完整列表与独立详情（后续确认）

默认页按固定顺序展示 Flutter、sqflite、shared_preferences、package_info_plus、url_launcher，普通 ListTile 仅显示名称和本地化用途，点击进入可滚动、可选择复制的许可原文详情。底部用低强调文字按钮“查看全部开源许可”进入完整项目列表。许可数据仅在初始页加载一次，后续页面复用同一份索引，不重新加载或联网。

索引按原始 package 名称组织，将同一项目的多个许可片段保留在同一详情中；仅去除完全相同的全文重复项，不删除不同声明。多项目共享的许可分别关联各项目，无名称的声明在完整列表归入本地化“其他声明”。摘要只展示实际加载到的主要项目，不伪造条目；空注册表、失败与重试仍真实表达。完整列表按项目名稳定排序，返回保留原滚动和焦点。

继续遵循 C05、CMP-02、INT-11、FLOW-17、VIS-01–05、ADAPT-01–07，不用卡片堆叠或在列表内展开长正文；中英文用途、完整列表标题及返回由现有本地化提供。
