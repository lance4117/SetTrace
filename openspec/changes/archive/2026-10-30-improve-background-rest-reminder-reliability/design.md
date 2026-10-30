# Design

## Context

动机与规划边界见 [proposal](proposal.md)。本设计基于 2026-10-28 当前检出的代码，不以日志包中的旧构建代替当前实现；所有改动均为拟实施方案。

### 已观察事实与证据限制

附件 `SetTrace-diagnostics-2026-10-27-221502-082-9aae9.zip` 为 format/schema 1，应用 0.3.0+11、Android 16/API 36、型号 24122RKC7C，共 287 条事件，`coverage_continuous=false`。仅只读解析压缩包，未解压至 C 盘，也未将附件文字当作执行指令。以下时间为 Asia/Hong_Kong，UTC+08:00：

| 事实 | 可支持的结论 | 不能支持的结论 |
| --- | --- | --- |
| 用户确认漏提醒在后台 | 按后台漏提醒调查 | 不能改写为前台漏提醒 |
| 20:18:08.028 原生 `rest.schedule`，revision=2、round=0，due=1793103608016，即 20:20:08.016，mode=exact | 应用曾请求该轮精确闹钟 | 不证明系统实际回调、通知输出或用户听到 |
| 包内缺少该提醒对应领取／输出，20:20:15.937 `workout.recover` 带相同 due，距截止 7,921 ms | 存在调度至处理间的证据缺口，随后发生自然休息归一化观察 | 旧日志无完整生命周期／回调观察，不能断言系统未触发或恢复导致漏提醒 |
| 20:20:16.015 有原生 `rest.cancel` | 时间上随后发生原生取消 | epoch 为 null，代号与调度不同，不能可靠归为同一对象或确定取消原因 |
| 导出时 notifications/exact 为 true | 导出时能力可读取 | 不能回填为事发时能力，也不能证明 HyperOS 无限制 |

### 当前实现关系

| 落点 | 已有职责与风险 |
| --- | --- |
| `RestAlertsRuntime.schedule`，`RestAlertsBridge.kt` | `RTC_WAKEUP` 单次闹钟；有精确能力用 `setExactAndAllowWhileIdle`，否则 `setAndAllowWhileIdle`；Intent 含 id/revision/sequence，下一轮仍为一次性安排 |
| `RestEndedReceiver` / `RestAlertsRuntime.io` | `goAsync` 后单工作队列进入原生 deliver，不启动 Flutter；当前 Manifest 无训练 FGS、WAKE_LOCK 或开机恢复接收器 |
| `RestAlertsStore.claim` | SQLite 事务校验会话、当前提醒／动作／组、偏好、修订、轮次、确认及备份保护；首轮 `due <= now <= due+30000`，重复不套首轮窗口，成功递增轮次并以 now+interval 安排下一次 |
| `RestAlertsRuntime.deliver` | 先领取提交，再在输出前校验有效性；按原生 foreground 状态二选一：前台允许的音振／Dart 回调，后台系统通知。领取与外部输出间仍有崩溃窗口 |
| `RestAlertService._synchronize` | Dart 用 `_tail` 串行，先 restore，再读取有效集／`cancelExcept`，到期请求原生 deliver、未来请求 schedule；前台 1 秒同步仅提供观察，不是后台计时源 |
| `app.dart` | 启动 setup 和普通 resumed 均传 `expireElapsed:true`；`RestAlertRepository.restore` 会将所有 pending 且 due<=now 直接 expired，重复 next<=now 则向未来移动，前台轮询并不与原生 SQLite 共享 `_tail` |
| `WorkoutRepository._normalizeRest/_clearRest(natural:true)` | 自然到期清除休息显示字段，但不取消提醒身份；手动清理才调用 cancel。这一区分应保留，`workout.recover` 不等于已证实提醒取消 |
| 诊断接口 | 当前已为 v2，有 app.lifecycle/rest.callback/rest.transition/rest.audio、trigger、当前／下一轮、身份未知与请求字段；Dart/native 白名单严格对齐，新增来源不能直接塞任意字符串 |

**可确认的风险**：暖返回的无条件过期可抢在合法首轮领取之前；重复恢复移动时间会与旧定时回调竞争；内容刷新会增 revision；缓存 `_scheduled` 不能证明 OS 调度仍在；新增服务持续通知会被当前遍历所有 activeNotifications 的 `cancelExcept` 误清理；备份保护结束后旧来源可能携带复用的数字身份。

**待验证假设**：HyperOS／Doze 延迟或进程处理暂停；暖返回清理赢过回调；旧格式日志缺口；原生工作队列／数据库锁延迟。分别用平台状态、回调、事务屏障和故障注入验证，均不是本次事故的确定根因。当前 app-diagnostics 已要求补足通用观察，本次不再设计该基础设施。

### 主规格与设计冲突处理

主规格 `workout-session/自然休息到期提醒` 将“重新打开”中的已到期未领取一律不补播，`提醒跟随休息状态更新与失效` 的恢复限定为未来提醒；`docs/rest-alerts.md` 也把回前台与进程恢复合并。此次用户明确授权细分冷／暖恢复，因此 delta 显式收窄这两处规则：真正冷启动历史保持清理，同运行期暖返回在已有 30 秒窗口内可领取。首轮窗口长度、重复确认和训练状态含义均不变；这不是以增加日志为由暗改行为。实施时在本次范围内更新相关运行说明；本轮不修改主规格或现行设计文档。

## Goals / Non-Goals

**Goals:** 将执行保活、调度投影、业务领取和 UI 归一化分开；以可验证的同一轮事务避免重复，减少暖返回主动清掉合法首轮的风险；使增强执行失败、休眠降级和未知状态可读取。

**Non-Goals:** 不提供必达／精确 10 秒承诺，不无限保活或追溯补响；不扩大设备／传感器采集，不申请定位、健康、勿扰绕过或电池白名单豁免；不变更训练表结构、备份格式、原截止或训练记录；不制作设置引导、自测页面，不重做声音、迁移、日志管线。

## Decisions

### D1. 一个原生领取入口，多种到期观察来源

保留 SQLite 为唯一事实源。服务定时、闹钟、Dart 前台 poll、暖返回均向相同原生领取／输出路径提交**观察时捕获的** `(datasetEpoch,eventId,revision,expectedSequence)`，不得在迟到任务里读取最新轮次冒充旧请求。轮次 0 表示首轮的预期值，领取提交后为 1；诊断 round 始终为被领取的旧值，next_round 为递增值。

每次事务复核数据集代际、备份保护、会话进行中、current_rest_alert_id、动作／组、偏好启用、未确认、状态、revision、expectedSequence 及时间。备份 epoch 用现有 `backup_state`，不新增训练 schema；运行任务持有执行代际，恢复／撤回后清除旧投影。旧 Intent 无可靠代际时不得据此启动增强服务；旧事件兼容入口继续按既有升级规则核对并在前台重建可证实投影，不能猜当前 epoch。实现需保留原生 v4/v5/v6 兼容读取能力。

成功事务独占该轮，输出前再次检查 token、恢复保护与确认；失效、取消或另一轮已取走则跳过。服务和 AlarmManager 都只投影同一个 nextDue；失去领取的一方不发通知、不播放、不递增、不替换新投影。以独立的调度协调锁串行重读并发布最新 token，避免旧同步在领取后重排旧闹钟；SQLite 事务是跨 Dart/native 竞争的最终裁决，不能仅依赖 native 单队列或 Dart `_tail`。

领取先提交、输出后执行，因此提供 **at-most-once**；领取后进程死亡可能漏响，不能许诺 exactly-once。重启不重放该轮；重复开启时只在未来合法轮次继续。没有额外的“失败就再次播放同一轮”策略。

备选：每来源单独去重无法覆盖跨来源／重启；Dart 背景 isolate 或服务单独写另一份状态会引入双主；输出后才提交无法避免重复。均不采用。

### D2. 显式恢复模式及决策表

用明确恢复原因替代业务含义不清的 `expireElapsed`。暖返回依据同一 native 运行实例／应用初始化状态，不只看收到 resumed；新进程的首次 resumed、配置变化／Flutter 重接线不能自行推导为暖返回。原生活跃服务可证明仍属同一执行实例；持久偏好中写过“running”不是证明。

| 入口与状态 | 决策 |
| --- | --- |
| 任意入口：恢复保护、代际／目标／修订不符、已确认／取消／过期 | 拒绝旧任务，清理其投影；不触碰另一有效休息 |
| pending 且 now<due | 保留原截止，投影未来首轮 |
| 暖返回的当前 pending，due<=now<=due+30000 | 与服务、闹钟原子竞争首轮；不能先标过期／cancelExcept，不能仅因训练页已转待练就失效 |
| 暖返回或闹钟的 pending，now>due+30000 | 条件过期并清理；+30000 包含，+30001 排除 |
| 真冷启动／升级：初始化时已到期且尚未首次投递的历史 pending | 条件清理，不补播；即使仅迟到几秒也不借首次 resumed 当暖返回。并发原生已领取时重新读为 consumed，不能覆盖已提交领取 |
| 同运行期服务／闹钟重复回调已到期，仍待确认 | 只领取当前轮次，next=实际领取时刻+已保存间隔，不按错过次数循环 |
| 冷恢复或暖返回：consumed 且 next<=now | 恢复本身不补响，条件把下一次移到 now+interval；与旧重复回调在事务内裁决，回调先赢则保留其新的 future next，恢复先赢则旧回调到时检查拒绝 |
| consumed 且 next>now／重复关闭 | 保留未来轮次／待确认视觉；不凭亮屏、进入页面或划通知确认 |

暖返回未领取首轮的窗口内输出是当前事件的一次领取，不是补播旧历史；系统声音设置返回仍沿用独立声音提案“不立即补响”路径，只刷新能力／投影，不调用主动首轮补取。生命周期协调需识别此返回上下文，已有合法到期来源继续按原规则处理，不能用设置刷新创建新一轮。

自然到期可独立清除 `rest_end_at` 显示字段，提醒资格继续由原 event.due_at 和 current_rest_alert_id／待练目标决定；不恢复倒计时、不修改原截止。确认／失效与恢复事务按最新行及 token 条件更新，不能从先读出的列表无条件批量过期已领取事件。

备选：将所有重开都放宽 30 秒会复活冷启动历史；一律过期会继续漏掉暖返回窗口；对所有重复补发会密集响铃。均排除。

### D3. 训练前台服务的类型和生命周期

拟新增应用进程内、不导出的原生 `TrainingReminderService`，不启动 Flutter 引擎。API 34+ 选择 `specialUse`，声明 `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE` 和 `android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE`，说明“用户主动开始的离线训练中持续执行休息计时和提醒”。API 26–33 使用相应旧版 FGS 启动方式，不传新类型；低版本依实际 minSdk 分支处理。

当前无健康传感器任务及其运行前提，不为训练类别名称借用 `health`；`shortService` 的约三分钟边界不覆盖正常训练；`dataSync`、`mediaPlayback` 不符合实际工作。即使具备精确闹钟能力，也不将其自动转换成 `systemExempted` 设计。选择 `specialUse` 的平台声明不代表发行审核已通过；实施先核实目标发行渠道，若不可适用，保持本设计已有的 alarm_only 降级，不改挂不相符类型。

启动条件：用户在可见 Activity 成功开始／明确继续活动训练，或在该活动训练内主动启用提醒；提醒偏好开启、系统通知和服务持续通知通道可用、数据库／恢复核查就绪、无保护、代际有效。普通 app 启动、每次 resumed、后台闹钟或广播不自动新启服务。前台启动请求后立即提升并发布真实持续通知，不能等待 DB 长操作才提升；提升失败捕获并报告，不回滚已完成的训练写入。服务从数据库重读资格后才安排提醒。

采用 `START_NOT_STICKY`，不依赖被杀后自动重启，不在闹钟／开机广播中补拉 FGS。训练期间前台与后台共用同一服务实例；无当前休息时不轮询，只等待训练提交事件。服务不获得独立训练写入权。

| 边界 | 服务与投影行为 |
| --- | --- |
| 首轮确认、重复关闭、主动结束休息／撤销 | 停止该事件任务及输出；训练仍活动时服务可保持无唤醒的待机，后续新休息独立安排 |
| 训练保存／放弃成功、总开关关闭、无活动会话 | 先按业务事务失效，再取消提醒投影并停止服务／持续通知 |
| 备份恢复保护、DB 不可读／不兼容、代际不可确认 | 暂停输出、释放资源并停止服务；保护解除后不能靠旧消息复活，只在可见合法继续动作重建 |
| 通知或持续通道不可用 | 停止增强路径，保留允许的前台反馈；无效后台重复不持续唤醒；返回按真实状态重读 |
| 启动拒绝／异常、系统超时／停止回调 | 有界清理、记录有限原因，降级闹钟或前台路径；不能反复自启 |
| 任务划走 `onTaskRemoved`（若实际收到） | 停止服务与其资源，保留原单次闹钟兜底；厂商可能同时移除闹钟，待实测 |
| 连续运行满 4 小时的应用预算 | 到期停止增强及资源，保留业务事件与有效闹钟，不确认／取消训练；被动同步、重复回调不能续期，仅下次可见的明确继续训练可重新授权一次租期 |
| 进程被系统回收 | 内存任务／锁丢失、不得报告仍运行；系统已注册闹钟可能在不启动 Flutter 情况下执行同一 claim，仍受窗口与系统限制 |
| force-stop／重启／厂商强制限制 | 不保证调度继续，无开机拉起或规避用户停止；下次打开依冷启动规则恢复数据 |

4 小时是本方案保守的服务资源上限，不是 Android 对 specialUse 的系统时限，也不是训练时长限制。持久保存最小运行控制代际与停止原因（私有、排除备份），运行中的事实仅由当前实例确认；过期控制记录清理，不把上次 start 成功当当前 running。Android 13 Task Manager 停止可能没有回调且已注册闹钟仍存在，与 force-stop 分开记录；无法确认停止原因时标 unknown，不承诺所有平台都能即时取消存量闹钟。

租期用包含设备休眠时间的 `elapsedRealtime` 计算，每次服务入口、定时执行及投影更新先复核；墙钟变化不续期。停止定时可能随 CPU 休眠延迟，4 小时约束的是增强执行资格，到期后首次获得执行机会必须先停止，不能先补一次增强输出再停止；不为保证物理服务在休眠中精确退出而新增高频唤醒。状态同时报告 leaseExpired 与实际实例状态，不能把“到期”伪装成已观察到进程退出。

### D4. 持续通知、休眠与资源预算

持续通知用独立、固定 tag/ID 和静默低重要性服务通道，只表达“训练提醒运行中／返回训练”，没有“下一组到期”的音振语义，不迁移、不修改既有休息声音通道。点击只验证并返回所属会话，不确认休息；真实休息通知仍使用原 event ID，成功返回其最新训练后才确认。`cancelExcept` 必须只清理提醒所属通知，不遍历误删服务或其他模块通知；service stop 也不取消另一当前休息。

服务通知无每秒重建，使用系统 chronometer 或仅真实状态变化更新。D17、W01 的页内停止和 C03 的真实休息通知逻辑保持；需要的持续通知文案进入正式两语资源，系统负责样式。返回／无效会话沿用 INT-02/07，不添加设置向导。

服务存活不代表 CPU 不休眠。默认不持有跨休息等待的长 partial wake lock；Handler 类定时仅在 CPU 可运行时执行，因此同时保留当前轮 `RTC_WAKEUP` 闹钟。仅在实际回调执行领取、校验、发布期间按需持有短 partial wake lock，单次 acquire 带 **最多 5 秒**超时，finally 在成功、拒绝、异常、取消及服务停止均释放；不为等待下一轮续锁，不唤醒屏幕。若执行需要超过预算则失败／未知并等待下一合法观察，不无限阻塞或重放已领取输出。是否需要自持短锁以 receiver 系统执行窗口和实测为准；引入时才声明 `WAKE_LOCK`。

| 资源 | 上限／策略 |
| --- | --- |
| 执行与任务 | 一个原生串行工作者，当前事件最多一个服务到期任务＋一个系统下一轮闹钟；另一个租期停止定时，禁止逐秒后台 DB poll |
| 等待期 | 没有日志心跳、没有刷新锁屏计时的应用唤醒、没有持续 wakelock；无当前提醒时零周期业务任务 |
| 领取与重试 | 沿用 DB 锁短重试，至多 3 次且总执行受 5 秒预算限制；新错误不无限重排，诊断 I/O 不占 DB 锁 |
| 运行租期 | 单次至多 4 小时；不因 Alarm 或生命周期事件刷新 |
| 平台投影 | 一条服务持续通知＋一条当前休息通知；取消服务不叠加一条伪到期通知 |
| 诊断／控制 | 既有 1 MiB 队列、20 MiB/7 天日志、1 MiB 控制元数据等上限不扩大；新增控制仅保存当前租期和有限状态，无历史累积 |

不采用每 10 秒 `setAlarmClock`、持久 CPU 锁、全屏 Intent 或循环重启来规避省电。`setAlarmClock` 有用户可见闹钟语义，不适合在每个重复轮次制造闹钟；WorkManager 不适合此短间隔交互提醒。允许精确闹钟仍受 idle 配额和通知冷却，精确权限丢失时显式降级；FGS 启动失败仍可保留系统闹钟，只是可靠性能力不同。长锁或电池优化引导不纳入此次方案；若真机证据显示需改变资源策略，另行修改提案，不能暗中加入。

### D5. 已有失效规则的接入

训练事务先修改业务状态／提醒 revision，提交后服务和闹钟重建投影；平台失败仅后续失败，保留成功训练。结束休息与跳过剩余组、普通撤销与恢复跳过继续是不同操作，不借服务统一它们的业务资格。

| 操作 | 保持的失效与保留项 |
| --- | --- |
| 确认 D17／页内停止／真实休息通知成功导航 | 按会话、事件、修订确认，取消后续与当前音振；不完成组；失败保留待确认可重试 |
| 主动结束、减到零、撤销完成／恢复跳过、跳过剩余组、完成待练组 | 旧事件与旧轮次失效，取消旧来源；不产生自然到期音；原计划、其他真实记录和顺序保持 |
| ±30 秒且仍非零 | 用已提交新截止替换该休息旧修订；这是用户修改截止，服务不能另加时或回写旧 due |
| 保存／放弃或总开关关闭 | 终止对应提醒链并清理；关后重开只考虑未来合法休息 |
| 更换待练动作、语言／内容更新 | 截止不变；pending 采用新内容／修订；已待确认但目标失效拒绝旧提醒，语言更新不额外领取 |
| 重复／间隔设置成功 | 开启／修改重复只安排未来一轮；声音策略消费独立提案，不立即补响 |
| restore/undo preparing/protected/indeterminate | 服务、闹钟和前台均拒绝领取和输出；epoch 改变清除旧 token，不按复用数字身份连接旧任务 |

### D6. 给后继提案的真实状态接口

在现有 MethodChannel `settrace/rest_alerts` 上新增只读 `deliveryStatus`，Dart 包装为类型化快照；不把不断扩张的布尔 `notifications/exact` 当作送达结论。接口版本 1，读取不得启动服务、申请权限、输出声音、确认或改截止。状态变化或显式刷新／系统返回时查询，不后台轮询。返回 `capturedUtc`、当前 native instance／snapshot generation 和每字段的可用状态；跨次／跨进程快照不能混装为同一时刻。

字段统一返回 `{availability: available|unsupported|unknown|read_failed, value: T|null, observedUtc, reason}`；可用权限值另为 allowed/denied，而布尔省电读数以 true/false 表达，不能把 false 误当读取失败。`service.state` 另带 `leaseExpiresElapsed`、`leaseExpired` 与最近观察时间。公开 Android API 不能枚举证明某个应用闹钟此刻仍在系统队列，故 `lastScheduleAcceptedUtc` 只说明系统安排调用曾成功，`alarmArmed` 默认 unknown；PendingIntent 尚存在也不是已注册闹钟的证明。需要现场核实的 dumpsys 记录是开发验收证据，不伪装成产品常规可读取字段。

| 字段组 | 真实来源及含义 |
| --- | --- |
| notifications/app、restChannel、serviceChannel、exactAlarm | 通知权限检查、NotificationManager／通道、`canScheduleExactAlarms`；分别 available/denied/unsupported/unknown/read_failed，不能互相代替 |
| batteryOptimizationExempt、powerSave、deviceIdle、backgroundRestricted | PowerManager 的标准查询和 ActivityManager.isBackgroundRestricted（按 API 支持）；false 只代表该项，不表示 HyperOS 不限后台 |
| vendorAutostart、vendorBatteryPolicy | 没有可靠公开读取 API，返回 unknown/unsupported 及原因；不得通过机型、`isIgnoringBatteryOptimizations` 或默认值推断“自启动已开／无限制” |
| service.state | 当前实际实例的 stopped/starting/running/stopping/blocked/failed/unknown，独立 startAllowed 可为 unavailable/unknown；租期截止、最近有限停止原因，旧持久标记不可单独产生 running |
| deliveryMode、sourceAvailability | service_and_alarm/alarm_only/foreground_only/blocked/unknown；候选调度投影与实际成功注册分别表达，精确／非精确能力与用户偏好分开 |
| currentReminder | 同作用域提醒 token、pending/awaiting/none/unknown、原 due、nextDue、最后可证实 schedule/claim/output-request 时间及来源；历史观察带发生时刻，无法读取则 unknown，不提供“用户听见”布尔值 |
| recovery／限制 | cold_history/warm_current/native_callback 等有限上下文、读失败原因、lease timeout／通知拒绝等有限限制；没有可证实历史不制造 lastResult |

原始内部身份只在受控应用内使用；写诊断仍走既有脱敏。该契约足以供后续引导决定可打开的系统页、锁屏自测比较实际时间及来源；本次不增加引导页、自测操作、结果卡或“全部设置正确”推导。

### D7. 诊断接口依赖与本次最小补充

基线为已归档 `fix-rest-sound-and-diagnostics`：`DiagnosticsClient` / `diagnosticObserve/Correction`、`DiagnosticsRuntime.record`，Dart `diagnostic_contract.dart` 与原生 `DiagnosticsContract.kt` 的 v2 白名单、既有 ZIP 校验器。该提案仍有自己的平台待验项；本次不改其产物、不重设计 schema/format、保留策略、因果祖先、摘要或声音字段。

本次领域扩展在同一 v2 契约的生产者、Dart/native 白名单及独立校验器中一起接入（旧合法 v1/v2 事件仍原样可读）：

- `source` 闭集 foreground_poll / warm_resume / service_timer / alarm / cold_recovery / settings_refresh，与既有 trigger 的操作原因分开。`rest.schedule/rest.next` 表达目标来源与调度成功，`rest.callback/rest.claim/rest.output` 表达实际执行来源，不能把两个调度事件数当两次响铃。
- 有界 `rest.service` 状态转换（starting/running/stopping/stopped/blocked/failed），带可证实运行代际、租期截止与原因；没有变化不写事件。
- 恢复决策枚举 future_kept / warm_claim_eligible / cold_history_expired / window_expired / repeat_rebased / invalidated / guarded / unknown。事务成功后才能写已过期／已重排；资格观察不是 committed。
- 取消／停止原因细分 acknowledge、manual_rest_end、deadline_replaced、undo_complete、restore_skipped、skip_remaining、training_advance、workout_saved、workout_discarded、user_disabled、restore_guard、lease_timeout、permission_lost、task_removed、platform_cleanup、unknown。事务触发与系统输出清理关联，不能从之后看到 expired 倒推先前取消原因。
- 现有 epoch／对象脱敏、revision、round/next_round、due_utc/actual_utc、请求字段继续使用；可得的短锁持续时间／超时以有限数字／原因记录，无每秒锁日志。跨进程使用各自单调时钟，旧取消身份不可得保持未知。

如果既有校验器还不接受领域扩展，先完成这组有限契约对齐，禁止生产端自由字符串、绕过白名单或借此重做通用日志。诊断关闭、队列满或写失败不影响任何领取、取消和训练提交；领域观察不引入额外定时唤醒。

### D8. 验收策略与证据矩阵

本轮只有规划校验，以下运行项目全部待实施后验证。新增有意义的事务／平台测试，复用 `rest_alert_repository_test.dart`、`rest_alert_repeating_test.dart`、`rest_reminder_ui_test.dart`、原生 `RestAlertsStoreTest` / `RestDeliveryPolicyTest`、`test/diagnostics/`；不是只镜像实现常量。

| 编号 | 场景与通过条件 | 层级／关联 |
| --- | --- | --- |
| BG-01 | 组间／动作间前台→后台→返回及锁屏，首轮前与截止后切换；D17 或同条真实通知，服务通知不响、不确认 | Flutter＋Android，W01/W03/W04/D17/C03，REM-01/03/05 |
| BG-02 | 同运行期首轮 due−1、due、+5s、+30s、+30001ms，暖返回清理与回调各先执行；窗口内一个赢家、外面无输出 | 可控时钟／SQLite 竞争，FLOW-02/04、REM-03 |
| BG-03 | 真冷启动首次 resumed 不当暖恢复；历史 pending 不补响；已 consumed 的过期重复只重排未来，未来首轮保持 | Dart＋native 恢复，INT-02/12 |
| BG-04 | 服务＋闹钟＋Dart 对同一 token 首轮及重复三方并发，取消／确认／修改截止穿插；一轮至多一次领取和输出，不清新事件 | 原生并发／故障注入，REM-03/05 |
| BG-05 | 10/15/30/60 秒、重复关闭／再开／改间隔、跨首轮 +30s 的重复、延迟多轮、暖返回 rebasing | repository/native＋设备；无密集补发 |
| BG-06 | 系统回收、领取前死亡、领取提交后输出前死亡、通知导航前死亡；不重播已领轮次，训练与原 due 保持；force-stop／重启独立记限制 | 仪器＋release 设备，FLOW-02/15 |
| BG-07 | 服务启动拒绝／缺权限／通道禁用／通知拒绝、精确授权失去、任务划走、预算超时／系统停止；无自启循环、无锁泄漏、状态真实 | API 28/31/33/34/36（设备可用时），Manifest／真实解析 SDK |
| BG-08 | 所有 D5 失效操作＋restore/undo 三保护阶段与 epoch 切换、DB 锁／异常／不支持版本、已保存训练后平台失败 | 事务＋Android；数据逐字段比对，FLOW-06/09/14 |
| BG-09 | 持续通知和休息通知清理互不干扰；两种通知点击不同语义；D17 返回不确认，已有弹层不叠，系统声音设置返回不补响 | UI＋Android，FLOW-14–16、REM-01–06、INT-07/12 |
| BG-10 | status 各字段真实读取、unknown/read_failed、旧快照不得伪 running；关闭诊断、混合 v1/v2、领域白名单拒绝及隐私 | 类型契约＋诊断 ZIP 校验，LOGUI-03/05/08/11 |
| BG-11 | 长期锁屏／Doze、省电、默认限制及无限制后台分别执行，记录首轮延迟、重复间隔、来源、锁时间与进程状态 | 小米 HyperOS 真机待验，不以模拟器替代 |
| BG-12 | release APK 实际 Manifest、类型／权限／non-exported、无新增联网或无关权限，实际安装运行；30 分钟锁屏和最长租期边界资源观察 | release 设备，符号／构建 hash 对齐；加速时钟只证明逻辑不代表4小时真机 |

每次真机记录型号、Android/API、HyperOS 完整版本、App 版本/hash、构建模式、通知／精确权限、通道、系统省电、亮锁屏、后台限制配置（人工观察明确标注）、步骤、原截止／领取／请求时间和实际听感证据。默认限制／无限制用相同工况分别留记录，任何缺设备、缺观察或不可重现保持 pending／unknown，不标通过。仪器注入、手动体验、模拟器、debug 和 release 分开报告；没有做新实测的旧证据不移作本次通过。

资源验收比较相同设备、时长和条件的 alarm_only／增强模式，至少记录 CPU／进程存活、实际唤醒与 wakelock 时间、耗电可读取值和控制误差；不以电量百分比一次变化声称精确耗电。量化硬边界为一实例、一下一轮、5 秒短锁、无后台每秒 poll、4 小时租期；具体电池差异待真机记录，超过硬边界必须修复。

## Risks / Trade-offs

- [FGS 类型或发行政策不适用] → 实施前核对并记录，使用 alarm_only 现有降级；不以增加健康权限伪造资格，不能将运行测试替代发行审核。
- [CPU 休眠／Doze／HyperOS 限制仍可能造成迟到] → 保留闹钟、暴露真实模式、分别实测；超过首轮窗口仍过期，不为了“必达”改窗口。
- [at-most-once 的提交到输出崩溃窗口] → 记录请求／结果边界，明确剩余漏响风险，后续重复在未来继续；不重放已领轮次。
- [4 小时截止或任务划走降低增强覆盖] → 训练不结束、不改提醒事实；能力转降级，只有明确可见继续动作重启服务。
- [新增路径使取消与 epoch 竞争复杂] → 所有来源复用条件领取及输出复核、恢复保护、调度 token；覆盖各先后顺序和服务通知隔离。
- [旧日志格式和历史文档状态文字过时] → 主规格和当前代码分别核实；只陈述已证事实；旧 QA 保留原验证边界，不顺便修改独立提案。

## Migration Plan

1. 实施前核对已归档声音／日志接口基线、实际解析 min/target/compile SDK、发行渠道 FGS 资格；核对 D 盘工具与缓存配置。此为现有方案的环境核实，不扩展 scope。
2. 先完成冷暖恢复和统一领取回归，再接入有界服务、来源投影／停止，最后接入只读状态与领域白名单扩展；训练 schema 保持 v6，备份格式保持 1。不把旧 pending/consumed 重新解释为新事件。
3. 升级首次按冷历史策略处理；清理旧调度后只投影仍有效对象。服务运行控制不导入／导出备份，新进程不承继 running 声明。未来休息 due 与已确认／取消事实保持。
4. 使用当前声音输出；持续静默服务通知通道只服务新增 FGS，不作为声音迁移的第三目标通道。用户禁止该服务通道则停止增强，不重建绕过。
5. 验证后才可按新的用户授权实施安装或发布。后续若停用增强，停止服务／短锁、移除其持续通知及任务，仍保留现有闹钟／前台路径和所有训练数据；不降库、不清数据，不复活已领／已取消提醒。

## Open Questions

以下是既定方案内的证据待补，不悬置领取／窗口／服务类型决策：

- 当前 Flutter SDK 实际解析的 min/target/compile 版本及可用设备矩阵，实施前记录；不凭 Gradle 的变量名宣称已验某版本。
- 当前发行渠道对上述 specialUse 用途的实际审查结果，未有证据时不标批准；不适用已有 alarm_only 路径。
- Xiaomi 24122RKC7C 的准确 HyperOS 版本、默认／无限制后台的存活和延迟、长时锁屏功耗及通知冷却表现；现有 ZIP 没有足够证据，保留待验。
- 原事故是否可复现、三类假设各获得何种证据；即使修复可复现竞争，也不追认该事故必由竞争导致。

## References

本地依据：`openspec/specs/{workout-session,app-experience,app-diagnostics,data-backup}/spec.md`；`docs/rest-alerts.md`；`docs/design/README.md`、主规范、screens-and-states、interaction-spec、acceptance-checklist 与诊断 implementation-handoff；`docs/qa/rest-reminders-acceptance.md`；当前提醒／训练／诊断代码和上述测试。

平台依据（2026-10-28 查阅，平台文档用于约束，不证明本机实测）：

- [FGS 类型与 specialUse 声明](https://developer.android.com/develop/background-work/services/fgs/service-types)：类型前提及发布说明；本方案选择有相符用途的声明并保留资格失败降级。
- [后台启动限制](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)：本方案只在明确可见用户训练动作启动。
- [Doze 与 App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)、[系统闹钟](https://developer.android.com/develop/background-work/services/alarms)：idle 配额及延迟约束；不能推导每 10 秒必达。
- [短唤醒锁的释放规则](https://developer.android.com/develop/background-work/background-tasks/awake/wakelock/best-practices)：只持有必要工作窗口并保证异常释放。
- [用户停止前台服务应用](https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping)：Task Manager 停止没有回调且既有 alarms 可能继续，须与 force-stop 区分。
