# 当前 UI 状态目录

本文完整登记页面与分支；captured 仅表示已有图像，功能验证见 [结果](verification/results.json)。

- [交互规范](specs/interaction-spec.md) · [备份专项](specs/features/backup.md) · [诊断专项](specs/features/diagnostics.md)
- [历史与设置等原始编号说明](../archive/2026-10-31-design-history/docs/design/screens-and-states.md)

| ID | 页面／状态与条件 | 实施位置 | 交互／验收 | 当前图像 |
| --- | --- | --- | --- | --- |
| A01 | 360 dp 小屏；内容可滚动，无横向溢出，底部主操作独立 | `lib/core/widgets/app_task_layout.dart` | ADAPT-01–07 | [widget-test](<screenshots/adaptation/A01-C01-430-1.3-blue-reduced-motion-zh-light-430-widget.png>) |
| A02 | 360 dp + 160% 字号 + 长英文动作名；完整换行，按钮增高、工具重排，不缩正文或裁断目标名 | `lib/core/widgets/app_task_layout.dart` | ADAPT-01–07 | [widget-test](<screenshots/adaptation/A02-W01-360-1.6-teal-reduced-motion-zh-light-360-widget.png>) |
| A03 | 键盘弹出后的导入表单；焦点字段、错误与确认均可达；键盘外观由系统决定 | `lib/core/widgets/app_task_layout.dart` | ADAPT-01–07 | [release-emulator](<screenshots/adaptation/A03-keyboard-zh-dark-360-s1.png>) |
| A04 | 740×390 横屏；主要任务与动作并排，短屏工具可滚动，尊重系统区域 | `lib/core/widgets/app_task_layout.dart` | ADAPT-01–07 | [widget-test](<screenshots/adaptation/A04-P03-740-1.6-teal-reduced-motion-zh-light-740-widget.png>) |
| A05 | 约 768 dp 平板；上下文与当前任务双栏，正文宽度与触控目标受控 | `lib/core/widgets/app_task_layout.dart` | ADAPT-01–07 | [widget-test](<screenshots/adaptation/A05-H01-768-1.3-teal-reduced-motion-zh-light-768-widget.png>) |
| B00 | 设置入口；数据分区、备份与恢复；关于与一级导航保留 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/settings/L00-data-entry-zh-light-360-s1.png>) |
| B01 | 备份首页；当前数量／日期、上次导出、变化提示、创建、恢复、副本；适用时撤回 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/backup/B01-full-scroll-00-zh-light-360-s1.png>) |
| B01a | 未备份；尚未创建，不显示虚构成功日期 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B01b-normal-zh-light-360-widget.png>) |
| B01b | 空数据；0 计划／0 记录仍可备份与恢复；无虚构日期范围 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B01b-normal-zh-light-360-widget.png>) |
| B01c | 读取失败；不冒充 0；重试；写入前必须核实当前数据 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B01c-controlled-view-fixture-zh-light-360-widget.png>) |
| B01d | 首页持续显示设置待处理，只重试设置或终止旧意图。BK-FLOW-04； | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B01d-controlled-view-fixture-zh-light-360-widget.png>) |
| B02 | 创建预览；全量范围、数量、Downloads 位置、个人记录提示；保存文件 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/backup/B02-full-scroll-00-zh-light-360-s1.png>) |
| B03 | 创建中；读取、保存、核对阶段，无假百分比；防重复 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B03-normal-zh-light-360-widget.png>) |
| B04 | 已保存；实际文件名、位置、时间、数量；完成 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B04-normal-zh-light-360-widget.png>) |
| B04a | 文件已发布但标记未写入；核实原目标，只修复记账，不另导出。BK-FLOW-01／VIS-05； | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B04a-controlled-view-fixture-zh-light-360-widget.png>) |
| B05 | 选择说明；完整范围、整份替换、保护；打开系统文件选择器 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/backup/B05-choose-explanation-zh-dark-360-s1.png>) |
| B05a | 等待选择；Android 系统窗口打开期间的背景态 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/backup/B05a-system-picker-stable-zh-dark-360-s1.png>) |
| B06 | 恢复预览；文件时间、当前／恢复后数量、日期范围、设置选项、保护说明、展开详情 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B06-normal-zh-light-360-widget.png>) |
| B07 | 替换确认；指定目标、影响、保护承诺；取消／替换并恢复 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B07-normal-zh-light-360-widget.png>) |
| B08 | 保护中；创建并验证恢复前副本；失败停止 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B08-normal-zh-light-360-widget.png>) |
| B08a | 恢复中；副本已就绪，恢复和核对；不重复执行 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B08a-controlled-view-fixture-zh-light-360-widget.png>) |
| B09 | 完成；实际数量、查看记录、撤回、返回备份 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B09-normal-zh-light-360-widget.png>) |
| B10 | 副本列表／空态；时间、用途、数量、应用内存储边界；查看副本 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B10-normal-zh-light-360-widget.png>) |
| B11 | 撤回预览；当前与目标对比；新数据也先保护；继续 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B11-normal-zh-light-360-widget.png>) |
| B12 | 撤回确认；指定时间／数量；取消／保留当前数据并撤回 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B12-normal-zh-light-360-widget.png>) |
| B13 | 撤回前保护；与恢复相同的保护要求 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B13-normal-zh-light-360-widget.png>) |
| B13a | 撤回中；用目标副本恢复，其他副本保留 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B13a-controlled-view-fixture-zh-light-360-widget.png>) |
| B14 | 撤回完成；目标数量、完成、查看副本 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B14-normal-zh-light-360-widget.png>) |
| B15 | 活动训练；真实名称／进度；回既有训练页或稍后处理 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B15-normal-zh-light-360-widget.png>) |
| B16 | 中断检查；核实持久化结果，不显示假空页或猜测结果 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [release-emulator](<screenshots/backup/B16-startup-checking-saved-results-en-light-360-s1-registration-corrected.png>) |
| B16a | 核心结果无法核实，保留错误与检查重试，限制正常写入。BK-FLOW-04／07； | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B16a-controlled-view-fixture-zh-light-360-widget.png>) |
| B17 | 原数据完整；未完成、原数据已保留；继续／重新选择 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B17-controlled-view-fixture-zh-light-360-widget.png>) |
| B18 | 中断前已提交；报告完成，不重复恢复 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B18-controlled-view-fixture-zh-light-360-widget.png>) |
| B19 | 副本详情；数量／日期；导出、恢复、删除指定副本 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B19-normal-zh-light-360-widget.png>) |
| B20 | 删除副本确认；具体对象；当前记录不受影响，适用时失去撤回能力 | `lib/features/backup/backup_pages.dart` | BK; VIS-01–05; ADAPT-01–07 | [widget-test](<screenshots/backup/B20-normal-zh-light-360-widget.png>) |
| C01 | 主题、语言、提醒正常；系统／浅色／深色；English／中文；提醒开关和状态说明；持久化失败不伪报成功 | `lib/features/settings/settings_page.dart` | COLOR; FLOW-14/17; INT-10–12 | [release-emulator](<screenshots/settings/C01-full-scroll-00-zh-light-360-s1.png>) |
| C01-sound | 系统通知声音；系统声音读取、试听／停止、渠道设置；替代 D19 三音面板。 | `lib/features/rest_alerts/rest_reminder_controls.dart` | REM-04/06; INT-12; ADAPT-01–07 | [release-emulator](<screenshots/settings/C01-full-scroll-00-zh-light-360-s1.png>) |
| C02 | 提醒能力受限；通知被拒绝或渠道禁用明确后台不可用；准时能力不足明确可能延迟；按实际能力显示对应系统设置入口，不能混为同一权限 | `lib/features/settings/settings_page.dart` | COLOR; FLOW-14/17; INT-10–12 | [widget-test](<screenshots/core/C02-normal-zh-light-360-widget.png>) |
| C03 | Android 提醒与返回示意；系统决定实际样式；自然到期提醒一次，不完成组；返回最新对应会话，结束／删除／失效目标不打开别的会话 | `lib/features/settings/settings_page.dart` | COLOR; FLOW-14/17; INT-10–12 | [release-emulator](<screenshots/workout/C03-background-notification-zh-dark-360-s1.png>) |
| C04 | 调度或偏好保存失败；区分训练已保存与提醒失败；重试当前能力或偏好写入，休息截止不重置；提示实际状态 | `lib/features/settings/settings_page.dart` | COLOR; FLOW-14/17; INT-10–12 | [widget-test](<screenshots/core/C04-normal-zh-light-360-widget.png>) |
| C05 | C01/C02/C04 底部关于分区；三线正式标志、名称、简介、实际版本／构建号；版本加载／失败重试，主页／反馈主动外部打开及失败重试；离线第三方许可含加载、空、失败和返回；所有提醒状态下可达 | `lib/features/about/app_notice_dialog.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [release-emulator](<screenshots/about/C05-about-and-version-zh-light-360-s1.png>) |
| C05-license-all | C05-license-all；补充子状态；见原帧及来源说明。 | `lib/features/about/licenses_page.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [release-emulator](<screenshots/about/C05-license-all-actual-registry-zh-dark-360-s1.png>) |
| C05-license-detail | C05-license-detail；补充子状态；见原帧及来源说明。 | `lib/features/about/licenses_page.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [release-emulator](<screenshots/about/C05-license-detail-actual-text-scroll-zh-dark-360-s1.png>) |
| C05-license-summary | C05-license-summary；补充子状态；见原帧及来源说明。 | `lib/features/about/licenses_page.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [release-emulator](<screenshots/about/C05-license-summary-actual-registry-zh-dark-360-s1.png>) |
| D01 | 首页新建计划；标签、40 字符上限、非空校验、成功后关闭、失败保留；普通名称可重复 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/D01-create-plan-en-light-360-s1.png>) |
| D02 | 计划重命名；预填原名、同一校验规则、保存／取消 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [widget-test](<screenshots/core/D02-normal-zh-light-360-widget.png>) |
| D03 | 删除计划；目标名称、不可恢复；明确保留历史及活动快照 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [widget-test](<screenshots/core/D03-normal-zh-light-360-widget.png>) |
| D04 | 删除计划动作；目标动作及影响范围；不删除已有会话与历史快照 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [widget-test](<screenshots/core/D04-normal-zh-light-360-widget.png>) |
| D05 | 有实际完成组的结束；保存实际完成组／继续／放弃，放弃与主操作分隔 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [release-emulator](<screenshots/workout/D05-end-options-en-light-360-s1.png>) |
| D06 | 放弃已有完成记录；二次确认、不可恢复、保留计划和其他记录 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [widget-test](<screenshots/core/D06-normal-zh-light-360-widget.png>) |
| D07 | 零完成时结束；继续／放弃；不显示不可用保存，不额外重复放弃确认 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [widget-test](<screenshots/core/D07-normal-zh-light-360-widget.png>) |
| D08 | 跳过当前动作剩余组；动作、已完成／将跳过数量、不计实际完成、下一动作或结束后果 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [widget-test](<screenshots/core/D08-normal-zh-light-360-widget.png>) |
| D09 | 恢复最近一批跳过；具体动作和数量、回到该动作、保留全部真实完成组 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [widget-test](<screenshots/core/D09-normal-zh-light-360-widget.png>) |
| D10 | 开始新训练遇到活动会话；继续原训练或留在当前页；不提供静默覆盖 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [widget-test](<screenshots/core/D10-normal-zh-light-360-widget.png>) |
| D11 | 休息提醒授权前解释；说明后台／锁屏用途、系统权限、拒绝不影响训练；不伪造系统授权结果 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [release-emulator](<screenshots/workout/D11-permission-explanation-en-light-360-s1-registration-corrected.png>) |
| D12 | 首页计划更多菜单；导入／导出与新建共存；空首页可导入，导出禁用或说明原因 | `lib/features/plans/plan_transfer_pages.dart` | FLOW-10/11; INT-08 | [release-emulator](<screenshots/transfer/D12-menu-zh-dark-360-s1.png>) |
| D13 | 记录详情更多菜单；删除目标记录入口；随后确认必须显示记录名称、日期、不可恢复及统计更新 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [widget-test](<screenshots/core/D13-normal-zh-light-360-widget.png>) |
| D14 | 会话草稿过期；解释状态变化；重载／取消，保留真实完成记录，不将过期草稿直接覆盖 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [widget-test](<screenshots/core/D14-normal-zh-light-360-widget.png>) |
| D15 | 当前说明版本无已阅记录时；中英文简介、隐私联网、本地数据、完整备份与应用内副本边界；默认／保存中／保存失败、重试和失败态本次继续；非提交返回或遮罩关闭不记已阅，本进程不立即重弹 | `lib/features/about/app_notice_dialog.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [release-emulator](<screenshots/about/D15-first-run-en-light-360-s1-1793408866.png>) |
| D16 | C05 隐私与数据说明；与 D15 同正文，只关闭不写首次状态，返回设置原位置与焦点；大字号正文滚动而操作保持可达 | `lib/features/about/app_notice_dialog.dart` | FLOW-18/19; VIS-03–05; LOGUI-11 | [widget-test](<screenshots/about/D16-normal-zh-light-360-widget.png>) |
| D17 | 休息自然到期、待确认／确认中／失败重试；前台弹窗＋暗色遮罩；不显示系统横幅；返回只收起，W01 保留“停止本次提醒”；确认后恢复普通待练页 | `lib/features/workout/workout_page.dart` | VIS-04/05; FLOW-16; INT-07 | [release-emulator](<screenshots/workout/D17-rest-due-en-light-360-s1.png>) |
| D18 | 提醒间隔选择；10／15／30／60 秒，默认 10 秒；取消保留原值，保存失败留面板重试 | `lib/features/rest_alerts/rest_reminder_controls.dart` | REM-04/06; INT-12; ADAPT-01–07 | [widget-test](<screenshots/settings/D18-normal-zh-light-360-widget.png>) |
| D19 | 卡片内系统声音状态与独立操作；读取中／实际系统音／受限／读取失败、试听中／取消／失败重试、系统设置失败；不发通知、不振动、不保存偏好，离页停止 | `lib/features/rest_alerts/rest_reminder_controls.dart` | REM-04/06; INT-12; ADAPT-01–07 | 已替代 |
| E01 | 更新格式不支持；更新应用／换文件；当前数据未变 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E01-controlled-view-fixture-zh-light-360-widget.png>) |
| E02 | 文件损坏／结构无效；整份拒绝，重新选原始完整文件 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E02-normal-zh-light-360-widget.png>) |
| E02a | 超过 64 MiB，整份停止，原数据不变。BK-DATA-01／02； | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E02a-controlled-view-fixture-zh-light-360-widget.png>) |
| E03 | 计划分享文件；不含历史，前往原计划导入／重新选 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E03-controlled-view-fixture-zh-light-360-widget.png>) |
| E04 | 导出空间不足；未生成完整文件，数据不变，重试 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | pending：未采集 |
| E05 | 下载不可写；按真实存储／必要权限原因提示，重试 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E05-controlled-view-fixture-zh-light-360-widget.png>) |
| E06 | 保护失败；替换未开始，重新检查并预览 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E06-controlled-view-fixture-zh-light-360-widget.png>) |
| E07 | 恢复失败、回滚已确认；原数据完整，重新预览再试 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E07-controlled-view-fixture-zh-light-360-widget.png>) |
| E08 | 预览过期；当前数据有变化，更新对比后再确认 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E08-controlled-view-fixture-zh-light-360-widget.png>) |
| E09 | 核心成功、设置失败；明确记录已恢复；只重试设置／使用当前设置继续 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E09-controlled-view-fixture-zh-light-360-widget.png>) |
| E10 | 核心成功、刷新失败；只重试加载，不再次恢复 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E10-controlled-view-fixture-zh-light-360-widget.png>) |
| E11 | 副本缺失／不可读；撤回不可执行，重试读取／选其他备份 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E11-controlled-view-fixture-zh-light-360-widget.png>) |
| E12 | 删除失败；副本保留，重试删除，当前训练不变 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E12-controlled-view-fixture-zh-light-360-widget.png>) |
| E13 | 撤回失败、回滚已确认；当下数据及副本保留，重新预览撤回 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E13-controlled-view-fixture-zh-light-360-widget.png>) |
| E14 | 文件读取失败；与取消分开，重新选择，旧预览不能继续提交 | `lib/features/backup/backup_pages.dart` | BK; VIS-05 | [widget-test](<screenshots/backup/E14-controlled-view-fixture-zh-light-360-widget.png>) |
| H01 | 月份历史与统计；本周／自然月次数、最近训练、所选月时长与实际完成组数；月份可切换；列表进入目标详情 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [release-emulator](<screenshots/history/H01-normal-zh-light-360-s1.png>) |
| H02 | 含跳过组的记录详情；名称、日期、时间、时长与真实完成比例；动作按最终快照顺序；逐组完成时间／跳过状态；删除从更多菜单进入 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [widget-test](<screenshots/core/H02-normal-zh-light-360-widget.png>) |
| H03 | 所选历史月份为空；所选月时长／组数为零；自然周／月次数和最近训练仍按各自口径计算，不随所选月一并清零 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [widget-test](<screenshots/core/H03-normal-zh-light-360-widget.png>) |
| H04 | 提前保存，完成／跳过／未完成并存；三类组状态独立，不把待练组补成跳过或完成；已保存快照不受原计划改动影响 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [release-emulator](<screenshots/history/H04-partial-detail-en-light-360-s1.png>) |
| H05 | 没有任何已保存记录；相关次数、时长、完成组数均归零，最近训练暂无；不删除活动会话和计划 | `lib/features/history/history_page.dart` | FLOW-12/13; HIST-01–06; INT-09 | [widget-test](<screenshots/core/H05-normal-zh-light-360-widget.png>) |
| L00 | L00；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/settings/L00-data-entry-zh-light-360-s1.png>) |
| L01 | L01；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/diagnostics/L01-normal-zh-light-360-s1.png>) |
| L01a | L01a；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L01a-normal-zh-light-360-widget.png>) |
| L01b | L01b；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L01b-normal-zh-light-360-widget.png>) |
| L01c | L01c；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L01c-normal-zh-light-360-widget.png>) |
| L01d | L01d；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L01d-normal-zh-light-360-widget.png>) |
| L01e | L01e；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L01e-normal-zh-light-360-widget.png>) |
| L02 | L02；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/diagnostics/L02-preview-zh-light-360-s1.png>) |
| L02a | L02a；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L02a-normal-zh-light-360-widget.png>) |
| L03 | L03；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L03-normal-zh-light-360-widget.png>) |
| L03a | L03a；补充子状态；见原帧及来源说明。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L03a-normal-zh-light-360-widget.png>) |
| L04 | L04；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/diagnostics/L04-saved-actual-download-zh-dark-360-s1.png>) |
| L05 | L05；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/diagnostics/L05-detailed-off-zh-light-360-s1.png>) |
| L06 | L06；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/L06-normal-zh-light-360-widget.png>) |
| L07 | L07；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/main.dart` | LOGUI-10; INT-13 | [widget-test](<screenshots/diagnostics/L07-normal-zh-light-360-widget.png>) |
| L08 | L08；具体条件、返回和失败分支见对应交互／专项规范。 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [release-emulator](<screenshots/diagnostics/L08-privacy-bottom-zh-light-360-s1.png>) |
| LD01 | 清空本机日志确认；取消默认焦点；只清空诊断，不删训练／备份或已导出文件；开启时后续继续记录 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/LD01-normal-zh-light-360-widget.png>) |
| LE01 | 导出失败／记录偏好保存失败；明确原因与恢复操作，不报成功；偏好失败保留原有效状态 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/LE01-normal-zh-light-360-widget.png>) |
| LE02 | 导出失败／记录偏好保存失败；明确原因与恢复操作，不报成功；偏好失败保留原有效状态 | `lib/features/diagnostics/diagnostics_pages.dart` | LOGUI-01–12; INT-13 | [widget-test](<screenshots/diagnostics/LE02-normal-zh-light-360-widget.png>) |
| P01 | 计划首页，活动会话卡片、计划摘要；活动会话存在时优先“继续训练”；“新建”与导入导出更多菜单共存；卡片进入详情 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P01-normal-zh-light-360-s1.png>) |
| P02 | 计划详情，动作顺序、组数、休息摘要；开始进入准备；添加／编辑动作、改名、删除、默认换序可达；默认换序不受本次训练锁定规则限制 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P02-normal-en-light-360-s1.png>) |
| P03 | 添加／编辑动作，名称、组数、两类休息、可选重量；保存及适用时删除；数字显示、滑动 Picker 与显式加减共用规则；键盘不遮挡字段和按钮 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P03-add-exercise-en-light-360-s1.png>) |
| P04 | 开始前预览计划、动作顺序与总组数；确认后才创建快照；发生单会话冲突时 D10；不显示预计训练时长 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P04-normal-en-light-360-s1.png>) |
| P05 | 没有计划的首页；新建与导入均可达；导出禁用或说明无计划；仍有活动快照时保留继续入口，不因来源计划被删而丢失 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P05-empty-en-light-360-s1.png>) |
| P06 | 已建计划没有动作；添加动作可用；开始训练禁用并说明原因；改名和删除仍可用 | `lib/features/plans/plans_page.dart` | FLOW-01/02; INT-01/02/07 | [release-emulator](<screenshots/plans/P06-empty-plan-en-light-360-s1.png>) |
| S01 | 全部动作与编辑；全部动作按会话顺序，完成／进行中／待练／已跳过可区分；提供适用的本次编辑、剩余换序、独立恢复跳过；已跳过动作说明先恢复再编辑 | `lib/features/workout/session_order_sheet.dart` | FLOW-07/08; INT-05 | [release-emulator](<screenshots/workout/S01-all-exercises-en-light-360-s1.png>) |
| S02 | 调整剩余顺序；完成、部分完成、有跳过记录的位置锁定；可移动行有手柄及非拖动替代；草稿保存／取消明确，仅影响本次快照 | `lib/features/workout/session_order_sheet.dart` | FLOW-07/08; INT-05 | [widget-test](<screenshots/core/S02-normal-zh-light-360-widget.png>) |
| S03 | 选择下一动作；当前尚未开始可被替换；已有完成组时只调整其后的待练顺序；候选数量不足时不给无效入口 | `lib/features/workout/session_order_sheet.dart` | FLOW-07/08; INT-05 | [widget-test](<screenshots/core/S03-normal-zh-light-360-widget.png>) |
| S04 | 编辑本次配置；只编辑所选动作目标组数与两类休息；组数至少为 max(1, 已完成组数)；不新增名称、重量或次数编辑；成功返回原会话 | `lib/features/workout/session_order_sheet.dart` | FLOW-07/08; INT-05 | [widget-test](<screenshots/core/S04-normal-zh-light-360-widget.png>) |
| W01 | 当前待练第 3 / 4 组，当前动作实际完成 2 组；完成本组固定底部；查看动作、符合条件的更换下一动作、跳过剩余 2 组、撤销完成、结束可达；总进度只计真实完成 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [release-emulator](<screenshots/workout/W01-notification-return-zh-dark-360-s1.png>) |
| W02 | 全场尚未完成任何组；不提供跳过剩余组、无效撤销或保存；可查看／调整符合条件的动作，结束使用 D07 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [release-emulator](<screenshots/workout/W02-zero-completed-en-light-360-s1.png>) |
| W03 | 组间休息，接下来仍是当前动作；计时、−30 秒、＋30 秒、结束休息；符合条件时另有跳过剩余组；不是把“结束休息”叫作跳过动作 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [release-emulator](<screenshots/workout/W03-fresh-rest-zh-dark-360-s1.png>) |
| W04 | 动作间休息，下一动作尚未开始；明确“动作间休息”；当前目标和组数可读；更换下一动作保持绝对截止；无跳过剩余组入口 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [widget-test](<screenshots/core/W04-normal-zh-light-360-widget.png>) |
| W05 | 上个动作完成 2 / 4，剩余 2 组被跳过；下一动作待练；明确跳过对象和数量；独立恢复最近跳过；普通撤销仍只撤销真实完成；不会把实际 2 / 4 画成完成 4 / 4 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [widget-test](<screenshots/core/W05-normal-zh-light-360-widget.png>) |
| W06 | 所有组均已处理，实际完成 11 / 15，4 组跳过；可保存，但进度不是 100%；仍能恢复可撤销的跳过及完成记录，结束／放弃遵守确认规则 | `lib/features/workout/workout_page.dart` | FLOW-03–09; INT-03–07/12 | [widget-test](<screenshots/core/W06-normal-zh-light-360-widget.png>) |
| X01 | 导出计划选择；**进入时默认全选**；图中选中两个只是取消选择后的例子；全选／取消全选、所选数量、复制和文件保存都保留；空选择及执行中禁用两种输出 | `lib/features/plans/plan_transfer_pages.dart` | FLOW-10/11; INT-08 | [widget-test](<screenshots/core/X01-normal-zh-light-360-widget.png>) |
| X02 | 文本输入／主动粘贴／文件选择；不主动读取剪贴板；无内容不能预览；取消文件选择正常返回，不报成功或错误；读取、格式错误有可理解提示 | `lib/features/plans/plan_transfer_pages.dart` | FLOW-10/11; INT-08 | [release-emulator](<screenshots/transfer/X02-input-zh-dark-360-s1.png>) |
| X03 | 导入前预览、拟用名称；显示数量和新增副本含义、改名、完整配置展开入口、取消／重新选择／确认；同名不覆盖已有数据 | `lib/features/plans/plan_transfer_pages.dart` | FLOW-10/11; INT-08 | [widget-test](<screenshots/core/X03-normal-zh-light-360-widget.png>) |
| X04 | 展开完整动作配置；展示动作顺序、组数、两类休息及可选重量；长配置滚动，确认可达；字段校验或名称新冲突保留并更新预览，重新确认 | `lib/features/plans/plan_transfer_pages.dart` | FLOW-10/11; INT-08 | [widget-test](<screenshots/core/X04-normal-zh-light-360-widget.png>) |

## 入口、操作与返回映射

状态表给出具体条件，以下逐项保留导航与错误范围；严格条件以对应 INT／专项规范为准。

### A01
- 入口：对应页面的适配配置。前置：宽度／字号／键盘／长文本按具体原帧。
- 操作：可滚动，主要操作可达。返回／取消：遵循原页面语义。
- 失败：溢出与安全区按单独证据，不推断 TalkBack。实施：`lib/core/widgets/app_task_layout.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### A02
- 入口：对应页面的适配配置。前置：宽度／字号／键盘／长文本按具体原帧。
- 操作：可滚动，主要操作可达。返回／取消：遵循原页面语义。
- 失败：溢出与安全区按单独证据，不推断 TalkBack。实施：`lib/core/widgets/app_task_layout.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### A03
- 入口：对应页面的适配配置。前置：宽度／字号／键盘／长文本按具体原帧。
- 操作：可滚动，主要操作可达。返回／取消：遵循原页面语义。
- 失败：溢出与安全区按单独证据，不推断 TalkBack。实施：`lib/core/widgets/app_task_layout.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### A04
- 入口：对应页面的适配配置。前置：宽度／字号／键盘／长文本按具体原帧。
- 操作：可滚动，主要操作可达。返回／取消：遵循原页面语义。
- 失败：溢出与安全区按单独证据，不推断 TalkBack。实施：`lib/core/widgets/app_task_layout.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### A05
- 入口：对应页面的适配配置。前置：宽度／字号／键盘／长文本按具体原帧。
- 操作：可滚动，主要操作可达。返回／取消：遵循原页面语义。
- 失败：溢出与安全区按单独证据，不推断 TalkBack。实施：`lib/core/widgets/app_task_layout.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B00
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B01
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B01a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B01b
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B01c
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B01d
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B02
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B03
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B04
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B04a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B05
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B05a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B06
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B07
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B08
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B08a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B09
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B10
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B11
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B12
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B13
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B13a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B14
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B15
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B16
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B16a
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B17
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B18
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B19
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### B20
- 入口：设置→备份与恢复。前置：无活动训练才可创建／替换；预览完整校验。
- 操作：创建、恢复、副本或撤回按状态执行。返回／取消：写入前可取消；替换期间禁止重复与返回。
- 失败：先保护再替换；未知结果不称成功／原数据完整。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C01
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/settings/settings_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C01-sound
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/rest_alerts/rest_reminder_controls.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C02
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/settings/settings_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C03
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/settings/settings_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C04
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/settings/settings_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C05
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/about/app_notice_dialog.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C05-license-all
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/about/licenses_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C05-license-detail
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/about/licenses_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### C05-license-summary
- 入口：设置一级页及关于／提醒子项。前置：控件按真实权限／开关显隐。
- 操作：外观、语言、声音、提醒、数据及关于。返回／取消：子页返回设置并保留位置。
- 失败：保存失败保留原有效值并允许重试。实施：`lib/features/about/licenses_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D01
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D02
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D03
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D04
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D05
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D06
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D07
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D08
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D09
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D10
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D11
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D12
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/plans/plan_transfer_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D13
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D14
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D15
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/about/app_notice_dialog.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D16
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/about/app_notice_dialog.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D17
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D18
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/rest_alerts/rest_reminder_controls.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### D19
- 入口：对应操作显式触发确认或菜单。前置：按描述中的资格和真实目标。
- 操作：显示具体后果并确认。返回／取消：取消／返回不提交；D17 返回仅收起。
- 失败：操作失败保留真实数据，显示实际结果。实施：`lib/features/rest_alerts/rest_reminder_controls.dart`。
- 状态：superseded；采集：pending；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E01
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E02
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E02a
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E03
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E04
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：pending；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E05
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E06
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E07
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E08
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E09
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E10
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E11
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E12
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E13
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### E14
- 入口：备份流程错误分支。前置：受控夹具或真实平台失败；不制造生产故障。
- 操作：按对应原因重新选择／预览／有限重试。返回／取消：保留真实已提交结果与原有文件。
- 失败：错误种类、回滚、设置与核心成功分开。实施：`lib/features/backup/backup_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### H01
- 入口：记录一级页及目标记录。前置：按已保存快照与月份计算。
- 操作：切月、详情、删除确认。返回／取消：返回月份；取消删除保留记录。
- 失败：读失败不冒充空；刷新失败只重试加载。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### H02
- 入口：记录一级页及目标记录。前置：按已保存快照与月份计算。
- 操作：切月、详情、删除确认。返回／取消：返回月份；取消删除保留记录。
- 失败：读失败不冒充空；刷新失败只重试加载。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### H03
- 入口：记录一级页及目标记录。前置：按已保存快照与月份计算。
- 操作：切月、详情、删除确认。返回／取消：返回月份；取消删除保留记录。
- 失败：读失败不冒充空；刷新失败只重试加载。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### H04
- 入口：记录一级页及目标记录。前置：按已保存快照与月份计算。
- 操作：切月、详情、删除确认。返回／取消：返回月份；取消删除保留记录。
- 失败：读失败不冒充空；刷新失败只重试加载。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### H05
- 入口：记录一级页及目标记录。前置：按已保存快照与月份计算。
- 操作：切月、详情、删除确认。返回／取消：返回月份；取消删除保留记录。
- 失败：读失败不冒充空；刷新失败只重试加载。实施：`lib/features/history/history_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L00
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01a
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01b
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01c
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01d
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L01e
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L02
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L02a
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L03
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L03a
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L04
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L05
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L06
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L07
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/main.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### L08
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### LD01
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### LE01
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### LE02
- 入口：设置→诊断；L07 由启动失败进入。前置：本机诊断／导出能力和实际日志状态。
- 操作：开关、详细模式、导出、清理与隐私。返回／取消：返回来路；清理取消不删除。
- 失败：限制／部分成功／失败／未知分别表达。实施：`lib/features/diagnostics/diagnostics_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P01
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P02
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P03
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P04
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P05
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### P06
- 入口：计划一级页或目标计划。前置：计划／动作按实际条件存在；空态单列。
- 操作：新建、详情、编辑或准备。返回／取消：返回来路；未保存草稿不提交。
- 失败：名称／数值校验，失败保留输入。实施：`lib/features/plans/plans_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### S01
- 入口：训练页查看动作或更换下一动作。前置：存在活动会话；资格由完成／跳过记录决定。
- 操作：本次编辑、换序或选择下一动作。返回／取消：取消草稿不写入，仅影响本次。
- 失败：过期草稿重载，不能覆盖最新状态。实施：`lib/features/workout/session_order_sheet.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### S02
- 入口：训练页查看动作或更换下一动作。前置：存在活动会话；资格由完成／跳过记录决定。
- 操作：本次编辑、换序或选择下一动作。返回／取消：取消草稿不写入，仅影响本次。
- 失败：过期草稿重载，不能覆盖最新状态。实施：`lib/features/workout/session_order_sheet.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### S03
- 入口：训练页查看动作或更换下一动作。前置：存在活动会话；资格由完成／跳过记录决定。
- 操作：本次编辑、换序或选择下一动作。返回／取消：取消草稿不写入，仅影响本次。
- 失败：过期草稿重载，不能覆盖最新状态。实施：`lib/features/workout/session_order_sheet.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### S04
- 入口：训练页查看动作或更换下一动作。前置：存在活动会话；资格由完成／跳过记录决定。
- 操作：本次编辑、换序或选择下一动作。返回／取消：取消草稿不写入，仅影响本次。
- 失败：过期草稿重载，不能覆盖最新状态。实施：`lib/features/workout/session_order_sheet.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W01
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W02
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W03
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W04
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W05
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### W06
- 入口：准备确认或继续活动训练。前置：存在本次会话快照。
- 操作：完成、休息、撤销、结束等按真实进度开放。返回／取消：结束走确认；不因返回暗中保存／放弃。
- 失败：状态变化重载；持久化失败不伪报成功。实施：`lib/features/workout/workout_page.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### X01
- 入口：计划首页更多菜单。前置：导出有计划；导入具有有效文本／文件。
- 操作：全选／预览／复制／文件／确认。返回／取消：取消文件选择正常返回；确认前不导入。
- 失败：保留输入、整批回滚；同名创建副本。实施：`lib/features/plans/plan_transfer_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### X02
- 入口：计划首页更多菜单。前置：导出有计划；导入具有有效文本／文件。
- 操作：全选／预览／复制／文件／确认。返回／取消：取消文件选择正常返回；确认前不导入。
- 失败：保留输入、整批回滚；同名创建副本。实施：`lib/features/plans/plan_transfer_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### X03
- 入口：计划首页更多菜单。前置：导出有计划；导入具有有效文本／文件。
- 操作：全选／预览／复制／文件／确认。返回／取消：取消文件选择正常返回；确认前不导入。
- 失败：保留输入、整批回滚；同名创建副本。实施：`lib/features/plans/plan_transfer_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

### X04
- 入口：计划首页更多菜单。前置：导出有计划；导入具有有效文本／文件。
- 操作：全选／预览／复制／文件／确认。返回／取消：取消文件选择正常返回；确认前不导入。
- 失败：保留输入、整批回滚；同名创建副本。实施：`lib/features/plans/plan_transfer_pages.dart`。
- 状态：implemented；采集：captured；验证按 [results.json](verification/results.json) 的 screen_id 查询。

