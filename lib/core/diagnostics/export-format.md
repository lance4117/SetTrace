# 诊断包与发布核查（版本1）

诊断包是 `settrace.diagnostics`，`format_version=1` 的不加密ZIP，不能恢复业务数据，也不能交给完整备份格式1的解析器。Android后台流式构建；跨平台桥只返回状态、实际文件名、字节数及有限原因码，不返回整个ZIP。

## 内容与独立校验

| 条目 | 内容与边界 |
| --- | --- |
| `manifest.json` | 报告身份、构建版本、截止、可读事件起止、计数、168小时／20 MiB限制、缺失原因、丢失计数及观察区间、内容条目的字节和SHA-256；不列自己的哈希 |
| `summary.txt` | 最多64条提交／警告／错误／未知阶段的可读事实、缺口及解释边界；不自动断言根因 |
| `environment.json` | 包名、安装版本／构建、支持的数据库schema、系统API／版本／型号、采集时间及可读取的通知／精确闹钟能力、退出信息能力；不声称业务数据库已经打开 |
| `state.json`（可选） | 单条只读SQL采集的活动标志、组数、修订、数据集epoch与绝对休息截止；单独采集时间，失败明确available=false，不读取计划名、动作名或重量 |
| `events/NNN.jsonl`（可选） | 再次按schema／字段白名单验证并重新编码的事件，不复制原始文件头或未知版本字节 |
| `incidents/NNN.jsonl`（可选） | 事件所引用的清理后帧及有限错误类别；不含异常消息、原始退出描述或tombstone |

`coverage_continuous=false`：即使未发现丢失，也不承诺覆盖每次操作。容量轮转可能少于七天；关闭记录、队列满、写入失败、损坏、未知版本与时钟不可证均可造成缺口。`known_missing` 与 `loss_counts` 是已观察事实，不能推算未观察到的错误总数。丢失区间保存最早／最近观察时刻，按最早证据过期，避免一个旧故障永久令报告受限。

ZIP最多24 MiB；固定源段仍计入20 MiB，不再复制一份全量源文件。源引用最多固定30秒，期间新日志不保证进入本次包。构建后逐项重读校验，发布前和发布后均重读公共输出的大小与SHA-256。SHA-256用于发现损坏，不证明真实性或发送者身份。导出最终发布事件在封包后产生，只能出现在之后的日志中。

## 状态与中断边界

`collecting → packaging → writing_unpublished → verifying → publishing → saved / saved_partial`。任何阶段还可能真实失败；可取消阶段进入 `cancelling → cancelled`，结果不明确进入 `unknown`。`publishing` 是短临界阶段，取消请求不能把已交付文件变成“取消成功”。

API29+使用 `MediaStore.Downloads` 和 `IS_PENDING`；发布前不作为最终可用输出。API28及以下使用既有受版本限制的写权限及自有临时文件，不覆盖重名文件。只有公共输出已经发布并核验，才返回成功。写入／关闭／发布发生异常但可能已交付时，优先核查已有输出。

私有 `export.properties` 只保留最近一个任务、有限定位信息与核验摘要，最大64 KiB，计入1 MiB辅助预算。预留前先保存报告身份／预定名称，再保存实际自有输出定位；进程丢失后将非终态转为待核查。核查原文件，不重放导出。无权确认、所有权歧义或journal损坏保持unknown；不删除可能已交付文件。外部删除／移动导致原定位不可用时不宣称仍保存成功。启动清理私有staging，保留公共文件和核查journal。

清空与进行中的导出互斥。取消只清理本次未交付自有输出；公共文件不会随清空本机日志、七天轮转或卸载而删除。

## 离线排查顺序

先校验manifest和条目哈希，再查看环境、截止／缺口以及summary。按operation_id与parent_operation_id追踪阶段；同域单调时间才能计算耗时，跨进程／Dart与Android时钟不能相减。备份持久ledger身份在写入前转换为独立命名空间HMAC correlation_id，可跨恢复epoch关联；数字对象代号仍按类型、epoch和清空代际隔离。密钥、原始ledger ID、业务ID和journal都不在ZIP中。

例如 `workout.complete committed` 后的 `rest.schedule failed` 表示组已保存、调度后续失败；`history.delete committed` 后的 `history.refresh partial_success` 只应重读；`backup.restore core_committed` 后的 `settings_pending` 按既有备份ledger恢复设置。缺少终态只能标未知。日志不驱动重放事务。

工具 [verify_diagnostics_package.ps1](../../../tool/verify_diagnostics_package.ps1) 可独立核对设备测试包的路径、大小、哈希、事件字段、HMAC对象代号、敏感哨兵和界面缺失原因。真实设备样包及结果见 [实施验收](../../../docs/qa/local-diagnostics-acceptance.md)。测试包中的queue_overflow必须保留，不因验收而修饰成完整成功。
