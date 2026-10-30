# 后台休息提醒可靠性：实施证据

变更：`improve-background-rest-reminder-reliability`。代码已接入，验收按下表分别记录；未测项目不能由旧验收报告转为通过。

## 输入证据

用户确认约20:20漏提醒发生在后台。旧ZIP为0.3.0+11、format/schema 1、287条事件；SHA-256 `05fd376a088b52877a3e6b178f7aa36521549d22a4a72817bfa20571c761da29`，大小20,332字节，包内哈希和白名单核验通过。只读原件，不解压到C盘。

2026-10-27 UTC+08:00：20:18:08.028曾安排首轮，原截止20:20:08.016，20:20:15.937发生带同一截止的训练休息归一化（+7,921ms）；期间缺对应领取／输出证据。20:20:16.015原生取消的epoch未知，无法可靠与同一提醒关联。导出时通知和精确能力为true，不代表事发时能力。包的coverage_continuous=false；用户说明、日志事实、代码风险和HyperOS／恢复竞争假设分开，根因未定。

## 工具与平台

路径实测见 `environment-paths.json`。本次入口为 `tool/background_rest_dev.ps1`，TEMP/TMP固定D盘任务目录。复用旧脚本前已核对：旧声音release脚本禁止FGS／WAKE_LOCK，不适用于本次Manifest，不直接沿用该断言；原脚本和旧提案不改。

FlutterExtension实际值为minSdk 24、target/compile 36，最终以新包合并Manifest再核对。已有D盘Pixel_7_Pro AVD以只读、无窗口、无快照方式运行，端口5556。最初无连接设备，未接触个人手机。

服务声明specialUse用于用户主动训练中的本地计时提醒；不借用health／dataSync／mediaPlayback，不增加健康、定位或联网权限。当前工作是本地开发APK验证，没有可证实商店审核通过记录；未来渠道审核不能由本次运行结果替代，资格不符时保留alarm_only降级。

## 当前验证

| 项目 | 结果 |
| --- | --- |
| 旧诊断ZIP | 校验通过，事实范围如上 |
| D盘路径可写及AVD实际路径 | 核实通过 |
| 完整Flutter回归 | 1263项通过，见flutter-all-final.log；包含内容刷新保留dataset epoch及拒绝旧数据集更新 |
| 最终提醒／UI／诊断专项 | 118项通过，见flutter-targeted-final.log |
| 静态检查 | No issues found，见analyze-final.log |
| 原生编译及单元测试 | 71项通过，见android-build-final.log及build/app/test-results/testDebugUnitTest |
| API36原生平台 | 最终31项通过、零失败／assumption skip，见android-platform-final31.log；含真实短锁超时、DB锁及主线程失败 |
| v1/v2领域扩展样例 | 合法混合包通过，4种非法样例被拒绝，见fixture-valid.json／fixture-rejections.json |
| BG-01–10整体／模拟器 | 按下方矩阵记录单元／仪器／release证据；不把局部通过视为整套设备矩阵通过 |
| BG-11小米默认限制 | 待验，无设备证据 |
| BG-11小米无限制 | 待验，无设备证据 |
| release构建／Manifest／安装 | 最终APK已生成及安装；min24/target36，specialUse、non-exported，无新增联网／无关权限；调试宿主不进入release，见release-verification.json及release-manifest.txt |
| BG-12长时资源 | 30分钟对照与真实4小时仍待验；加速/边界单元测试不能代替长测 |
| 人工听感／触感／真实TalkBack | 待验 |

服务存活不等于CPU不休眠或解除厂商限制；单轮at-most-once仍有领取提交后、输出前进程退出的漏响窗口，不能自动重播同轮。无需修改训练schema或完整备份格式，不承诺后台严格每10秒送达。


## Release 实际运行（API36，只读AVD副本）

独立创建BGReleaseQA／BGPress，组间休息30秒，不修改既有test1计划。
- 从准备页明确开始训练后，dumpsys记录TrainingReminderService为isForeground=true、ID=-10001、specialUse=0x40000000、startCommandResult=2（NOT_STICKY）；持续通知sound/vibrate为空。见release-running-services.txt。
- 完成第1组后Home并熄屏，35秒后观察到一条id=7真实休息通知（BGPress第2/4组）及独立服务通知；没有声称用户听见。见release-alarms-before.txt、release-lockscreen-notifications.txt、release-lockscreen-services.txt。
- 普通返回出现同一待确认D17；确认后仍是1/4组完成，真实通知清理，服务持续通知独立保留。界面证据在build/qa/rest-alerts/bg-release-returned.*与bg-release-acknowledged.*，通知状态见release-after-ack-notifications.txt。
- 完成第2组后执行cmd activity stop-app（系统Task Manager等价停止，非force-stop）；35秒后系统闹钟产生id=8、BGPress第3/4组的通知，dumpsys没有增强服务。见release-task-stop-services.txt、release-recovered-notifications.txt、release-recovered-services.txt。没有把此结果外推为OOM、force-stop或小米杀后台工况。
- 设备时钟与主机可能不同，原截止／闹钟和通知只在设备时钟域解释；主机created_utc是采集/构建时间，不与设备deadline混算延迟。未修改设备时间。

Release APK及匹配符号保留在build/background-rest-reliability，具体哈希见release-verification.json；开发证书兼容签名，仅用于测试，不是商店发布。旧C盘开发证书只读使用，所有新增APK、符号、缓存和临时文件均在D盘。最初签名不兼容没有通过清库／卸载解决。

- Task Manager停止后冷启动仍呈现同一D17，没有自动启动服务；确认后根页保留未完成训练，明确“继续训练”才重新启动服务，进度仍为2/4。保存已完成的两组后服务退出。见release-cold-return-services.txt、release-explicit-continue-services.txt、release-after-save-services.txt及对应bg-release界面截图。
- 通过实际设置界面导出ZIP，见本目录SetTrace-diagnostics-2026-10-28-162614-384-bdd0b62a0a064ef5a465b86eb508cc2c.zip。校验结果release-diagnostics-validation.json：936条事件，SHA-256为5cfef0005af7c796b2483c5be9e5f64d44293c0179c8566068381806e62eee56，已报告13条queue_overflow丢失。包含先前debug仪器及release历史，不能把事件总数算成本次release输出数。领域汇总release-diagnostics-domain-summary.json只证明新service/source字段可经真实导出读取，覆盖不连续，不证明听见。

## 验收矩阵与待验边界

| 编号 | 实际证据 | 仍待验证 |
| --- | --- | --- |
| BG-01 | Flutter现有W01/D17交互回归；API36 debug服务后台竞争；release A/B组间锁屏、返回确认 | 其他API、动作间完整设备流程、小米两配置 |
| BG-02 | repository可控时钟due−1/due/+5s/+30s/+30001ms及自然清理先行；原生条件领取和旧轮拒绝 | 小米实际临界切换延迟 |
| BG-03 | 冷／暖／设置恢复及重复重排Dart测试；release A停止后冷启动不自启、明确继续才启动 | 不同系统回收原因及OEM差异 |
| BG-04 | SQLite三来源竞争单赢家、epoch保护、旧调度不覆盖未来；真实service/alarm后台竞争 | release领取提交后输出前的精确死亡切点 |
| BG-05 | 10/15/30/60秒及迟到多轮、修改／开关、暖恢复测试；原生重复领取验证 | 全API锁屏重复与长期Doze、真机间隔分布 |
| BG-06 | 原生旧轮不重领及保护注入；release A Task Manager停止后alarm通知、冷启动不重播服务 | release精确故障窗口、OOM、force-stop、重启设备实测 |
| BG-07 | 单元4小时单调时钟边界；API36真实FGS启动、一次实例、无休息待机、启动拒绝与读取失败停止 | API28/31/33/34、长时权限／通道变化、真实4小时退出 |
| BG-08 | 事务／训练回归，restore/undo各保护阶段、跨epoch同数字身份、旧清理不伤新事件；实际短锁超时、DB锁与主线程失败测试通过 | 长期系统压力及厂商回收下组合工况 |
| BG-09 | 两种通知隔离仪器；Flutter D17返回／弹层／错误／声音设置返回回归；release A/B实际确认、进度保持 | 真实通知点击完整系统矩阵、真人TalkBack与听感 |
| BG-10 | 只读snapshot、未知／失败／旧进程状态测试；v1/v2样例及真实导出ZIP通过 | 厂商私有能力仍unknown，alarmArmed无公开队列证明；不能由历史请求推出必达 |
| BG-11 | 尚无本次小米设备证据 | 默认限制与无限制须人工确认并分别记录，长期Doze／锁屏／功耗待验 |
| BG-12 | release合并Manifest、权限、版本、APK／符号哈希及API36安装；短时服务启停证据 | 相同设备两模式30分钟对照、真实4小时租期及耗电误差分析 |

FLOW-02/04/06/09/14–16与REM-01–06的自动化依据是完整Flutter回归和原生通知／领取测试；ADAPT/VIS依据为rest_reminder_ui_test覆盖360/430dp、1.6字号、中英文、浅深／四主题色。它们覆盖当前复用的Flutter页面；系统持续通知由Android绘制，不能由Widget结果推出所有OEM布局或TalkBack已验。任务4.4允许把真人TalkBack明确留待验，此处保持该边界。

后继“设置引导与锁屏自测”可直接对接lib/features/rest_alerts/rest_delivery_status.dart与settrace/rest_alerts的deliveryStatus(version=1)，字段来源及纯查询边界见docs/rest-alerts.md。vendorAutostart/vendorBatteryPolicy、alarmArmed保持unknown；无新增设置引导或自测界面。日志依赖仍为已归档声音／诊断提案的v2接口，本次仅扩展有限领域字段，旧事故根因仍未确定。

## 资源故障路径的最终验证

任务3.4对应android-platform-final31.log：真实服务到期后短锁已被系统持有，将串行工作者阻塞超过5秒，系统active Wake Locks中该锁消失；放行后增强以timeout停止，没有领取或输出。实际数据库写锁下服务预算拒绝且不领取；主线程输出抛错传回工作者，已提交轮次不重领。读取失败的服务停止并释放短锁，无休息时无周期业务任务。数据库重试、进入领取和主线程等待使用同一剩余预算，没有为各步骤重开5秒；等待期不持锁。

初次故障验证曾发现DB读取失败归类为platform，已改为read_failed；测试曾误把dumpsys的历史ACQ/REL当作当前锁，已限定检查active Wake Locks段，并保留失败日志以便追溯。预算PRAGMA返回值的Android查询方式问题也由新测试发现并修复，最终31项在同一源代码上通过。未用删除断言或assumption skip将失败转成通过。

Release构建A的哈希／符号与详细UI证据保留在release-build-a-verification.json及build/background-rest-reliability/build-a/。最终构建B额外包含dataset epoch内容刷新修复、读取失败分类及统一工作预算；最终APK／符号哈希以release-verification.json为准。A的详细锁屏／回收／确认／保存证据不能全部称为B实测；B的安装／冷启动及补充冒烟单独记录为release-final-*和bg-release-final-*。

构建B补充冒烟：覆盖安装成功并COLD启动，没有自动服务；明确开始独立BGReleaseQA训练后specialUse服务运行、NOT_STICKY。完成第1组后Home＋熄屏35秒，观察到id=9的BGPress第2/4组休息通知及独立静默服务通知。暖返回显示同一D17，确认后仍为1/4完成；通过两次明确丢弃确认结束本次QA会话，服务及两种通知均清理，原有test1计划及构建A已保存记录不受影响。证据见release-final-*与bg-release-final-*；没有模拟真人听见，也没有把这次短测称为资源长测。
