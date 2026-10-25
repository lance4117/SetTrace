# 故障捕获、提醒解释与构建留存

## 捕获边界

应用级 `SetTraceApplication` 创建单写入器，构造与调用方record路径不读写磁盘。Flutter引擎或Activity不存在时，原生提醒仍能提交事件；关闭记录的确认策略同样适用。Dart的FlutterError及PlatformDispatcher回调保留原handler和返回值，不改变zone处理。现有备份Isolate.run的异常通过Future返回原观察范围；任意未来自建、未接线的孤立isolate不保证捕获。

JVM未捕获处理器只提交有界清理后的最小记录，并在finally调用原handler。不会等待磁盘完成，所以进程立即退出时记录可能丢失。Flutter ERROR与JVM FATAL不等同于已确认发生进程崩溃；缺少结束事件不能证明崩溃。强杀、OOM、原生崩溃、系统限流或设备断电均可能没有完整堆栈。

API30+读取至多5条自有进程退出记录，后台总等待250 ms；读取失败或超时只报告read_failed。仅消费开启记录以来、仍在七天范围且未消费过的记录，持久保存有限摘要去重。退出原因与异常帧分开；不把用户停止或低内存退出记成Java崩溃。可选trace只读取最多64 KiB内存，保留至多96条允许的JVM帧，不落原始描述／tombstone。environment区分unsupported、not_available、no_records、supported、read_failed；exit_trace报告可选跟踪可用、缺失、读取失败、清理拒绝或截断。该字段是本次有限检查的能力说明，不承诺系统保有全部历史。

## 提醒因果链

`workout.complete`／休息调整提交 → `rest.synchronize` → `rest.schedule` → 原生 `rest.claim` → `rest.output` → `rest.next` 或 `rest.cancel`，用户确认关联 `rest.acknowledge`。跨桥保留操作身份和epoch；claim的拒绝原因来自同一次SQLite领取事务，并在事务成功结束后观察。日志异常不修改领取或补发策略。

首次迟到超过30秒过期，旧修订、旧轮次、已确认、无效会话和恢复保护分别解释；重复通知不补发已错过轮次，每轮仍最多领取一次。日常每秒倒计时、build、普通无变化同步和SQL不记录。首次、异常、停止及实际后续调度保留有限事件；同指纹60秒聚合。

notifications_allowed、channel_allowed、exact_allowed只说明读取时能力。sound／vibrate／notification事件只证明向平台提出输出请求，不能证明用户听到、看到或感知。系统静音、音量、勿扰、后台限制及厂商策略需结合实际设备排查；本次模拟器证据不替代真机听感。

## 构建身份与符号

按安装版本／build、APK SHA-256、源版本与生成时间对应构建。当前默认release启用Flutter工具的R8缩减；Dart未开启 `--obfuscate`，没有该模式的split-debug-info文件。`android/app/proguard-rules.pro`保留应用类名与行号属性，让写入前应用命名空间白名单在release中仍可识别；方法仍可优化或重命名。

每次准备分发构建时留存同一次构建的APK、`build/app/outputs/mapping/release/mapping.txt`及配置、锁文件／源版本。R8映射只在开发侧保存，不进入诊断包。使用对应mapping执行Retrace；不可用其他构建的映射还原。启用Dart混淆时必须增加受控split-debug-info留存与构建标识，再验证符号还原，不能只打开混淆开关。

当前release仍使用项目既有debug签名配置，验证构建不代表已签署可公开发行的安装包。APK权限／映射检查见实施验收；尚未执行的受控release崩溃及符号还原、指定低配设备入队p95与厂商迁移保持待验。
