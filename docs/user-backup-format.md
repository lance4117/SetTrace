# SetTrace 完整备份格式 v1

本协议由 `lib/features/backup/backup_codec.dart`、`backup_models.dart` 和
`backup_json.dart` 实现。首个完整备份格式为 v1；应用版本和 SQLite 版本独立。
计划分享 `settrace.training-plans` v1 仅包含配置、限制 2 MiB，不是本格式旧版本。

## 编码与完整性

UTF-8 JSON，整个原始文件（含空白及可选 UTF-8 BOM）不得超过 **67,108,864 字节
（64 MiB）**，读写同限。容器嵌套最大32层，根对象算第一层。文件按内容识别。
重复键（包括转义后同名）、非法 UTF-8、孤立 UTF-16 代理项、非有限数、非安全整数、
未知业务字段／枚举和任意无效关系均整份拒绝。整数范围为 ±9,007,199,254,740,991；
时间戳同时不得超出 Dart DateTime 支持的 ±8,640,000,000,000,000 毫秒。

摘要为排除根 `integrity` 成员后的整个文档的 **RFC 8785 JCS** 规范化 UTF-8
的 SHA-256，小写64位十六进制。对象键按 UTF-16 码元排序，数组不排序，字符串不做
Unicode 归一化；数值使用 ECMAScript 最短可往返表达，负零输出0。
摘要检测内容损坏，不提供来源认证、密码或加密；完整文件包含个人训练记录。
只有 `metadata.extensions` 内允许非业务扩展；它仍参与摘要及大小／深度校验。

## 根对象（所有字段必填）

| 字段 | 类型及规则 |
| --- | --- |
| format | 固定字符串 `settrace.user-backup` |
| schemaVersion | 整数1；决定读取器与转换器，不使用应用版本猜测 |
| backupId | 非空字符串；快照身份，不是用户或跨设备实体身份 |
| snapshotAt | UTC ISO 8601 `YYYY-MM-DDTHH:mm:ss[.ffffff]Z`，原快照时间 |
| exportedAt | 同上，本次导出时间；副本再导出不改 snapshotAt |
| sourceAppVersion | 非空字符串，实际安装版本／构建信息，仅用于展示 |
| data | 对象，恰含 plans、workouts、settings |
| metadata | 对象，恰含 extensions（JSON对象） |
| integrity | 对象，恰含 algorithm（`sha256`）、digest（小写十六进制摘要） |

## 数据字段

以下字段全部必填；允许空值的字段也必须写 `null`。名称保持用户原文，不 trim、
翻译、截断或添加导入后缀。所有 `key` 是非空文件局部字符串；每类实体各自唯一。
所有时间戳是 UTC epoch 毫秒整数；时长／休息是整数秒；重量单位 kg。

| 对象 | 完整字段与约束 |
| --- | --- |
| data | plans数组、workouts数组、settings对象；两数组均允许为空 |
| plan | key、name（非空）、createdAt、updatedAt、有序 exercises数组（允许空） |
| plan exercise | key、name（非空）、targetSets（整数≥1）、restBetweenSetsSeconds／restAfterExerciseSeconds（整数≥0）、defaultWeightKg（有限非负数或null） |
| workout | key、sourcePlanKey（现存计划key或null）、planNameSnapshot（非空）、startedAt、startedLocalDate、endedAt、durationSeconds（整数≥0）、有序 exercises数组 |
| workout exercise | key、sourceExerciseKey（所属来源计划动作key或null）、nameSnapshot（非空）、与计划动作同名的四个配置字段、有序 sets／skipBatches数组 |
| set | setNumber（按数组从1连续编号）、completedAt／completedSequence／skippedAt／skipBatchKey（均允许null） |
| skip batch | key、createdAt、undoneAt（时间戳或null）；所属动作／会话由嵌套结构确定 |

计划数组保存列表顺序，动作数组保存最终顺序。`startedLocalDate` 为实际存在的
`YYYY-MM-DD` 日期，直接保留原开始日，不按恢复设备时区重新生成。
`durationSeconds` 是原已保存值，不由起止时间重算；时钟回拨产生的结束早于开始与
零时长合法。文件仅含已保存训练，不承载活动会话及其游标／休息截止。

每动作组数必须等于 targetSets。完成时间与完成序号同时为null或同时存在，序号为
正整数且在同一训练中唯一（允许间隙）。跳过时间与批次引用同时为null或同时存在，
引用必须属于本动作且批次 undoneAt 为null。完成和跳过互斥；全null表示未完成，
不能推断为跳过。保留已撤销批次，但已撤销批次不能仍被跳过组引用。
历史来源允许null，非null时必须存在且所属正确；不能从当前计划重建历史。

## 设置

| 路径 | 值 |
| --- | --- |
| settings.themeMode | system / light / dark |
| settings.themeColor | teal / blue / violet / graphite |
| settings.languageTag | en / zh（已初始化的有效应用语言） |
| settings.reminder.enabled | boolean |
| settings.reminder.sound | three_tone / double_beep / voice |
| settings.reminder.vibration | boolean |
| settings.reminder.repeat | boolean |
| settings.reminder.interval | 整数10 / 15 / 30 / 60 |

系统权限、permission_requested、通知、说明已阅、导出状态、操作日志及副本索引
不得进入载荷。取消恢复设置时保留本机全部设置。勾选时，计划／历史先原子提交，
设置随后逐项确认；设置失败不能重做核心替换。

## 兼容与样本

已提交的可解析、独立计算摘要的样本：

- [空数据 v1](../test/fixtures/backup/v1-empty.settrace.json)：空集合与全部可迁移设置。
- [历史 v1](../test/fixtures/backup/v1-history.settrace.json)：中英文、同名及空计划、
  无来源历史、完成／跳过／未完成、已撤销批次、回拨时间与原零时长。
- [合成未来格式](../test/fixtures/backup/synthetic-v2.settrace.json)：仅测试拒绝，**从未发布**。

读取流程为识别格式→核验原格式摘要→原版本结构校验→纯转换→当前语义校验。
当前注册版本只有1，无默认值转换。应用补丁版本变化仍可读；高于支持版本整份拒绝。
未来版本必须保留所有已发布读取器和黄金样本，逐版声明新增字段缺省规则；
转换失败不得修改源文件或当前用户数据，不要求先安装中间版本。

## 内容比较

文件完整性摘要含身份、导出时间与扩展。语义摘要另外计算：遍历归一化局部key及其
引用后，coreDigest涵盖全部计划／历史；settingsDigest涵盖可迁移设置；contentDigest
组合二者。核心事务验证仅比较coreDigest，避免将尚未应用的设置误判为替换失败。
同数量改名、调整顺序、相同时间的完成次序、原始日期／时长改变均必须被发现。

## 容量验证

可重复命令：`dart run tool/benchmark_backup.dart decade|under|limit|over`，各模式
单独运行进程，输出原始字节数、编码／解码毫秒与进程peak RSS。decade生成3653场、
每场8动作×5组；另外三种分别为64 MiB−1、64 MiB、64 MiB＋1。
超过2 MiB与有界文件读取／isolate往返由 `test/backup_codec_test.dart` 验证。
2026-10-17 Windows x64 / Dart 3.13.4 桌面实测（每场景独立进程，JIT含运行时与夹具）：

| 场景 | 字节 | 编码ms | 解码ms | 峰值RSS字节 |
| --- | ---: | ---: | ---: | ---: |
| 十年3653场 | 21,547,424 | 2093 | 2536 | 578,473,984 |
| 上限−1 | 67,108,863 | 1190 | 1183 | 675,237,888 |
| 上限 | 67,108,864 | 1273 | 1150 | 675,287,040 |
| 上限＋1 | 拒绝 tooLarge | 1173 | — | 540,610,560 |

已去掉重复JSON解析及无迁移时的深拷贝，摘要逐块编码。峰值仍较高；必须在受支持的
Android设备测量。桌面结果不等同于 Android 门槛通过；若设备不满足容量契约，需继续
增量解析优化，不能缩小64 MiB或静默删历史。已完成下述 Android 模拟器读写验证，目标真机门槛仍需复核。


## Android 保存、恢复与副本使用

完整备份通过独立 `settrace/backup_files` 通道选择与保存，通道只传可信暂存令牌、
请求 ID 和回执，不传完整 JSON。系统文件选择器取消不产生可恢复候选。读取或校验
失败不会修改计划与历史；选择的外部源文件不被修改。暂存位于 cache/backup-stage，
保护副本位于 files/backup-recovery，导出请求日志位于 files/backup-export-journal。

Android 10 及以上使用 MediaStore Downloads 的 pending 条目；旧路径使用公共 Downloads，
按平台要求申请存储权限。文件名包含日期与唯一请求 ID，不覆盖已有文件。写入关闭后
重新计算完整文件摘要再发布。若发布结果不确定，重查既有目标，不再次生成另一个文件；
仅对已确认不完整的自有输出重试清理。文件成功但数据库记账失败时，只修复记账。
导出副本保留原 snapshotAt，并设置本次 exportedAt，不更新当前数据的上次导出标记。

完整备份为**未加密 JSON**。公共文件由用户自行保管，可能留存在 Downloads、用户手动
复制的位置或其他应用中；应用内删除副本不删除这些文件。卸载会删除应用内副本，
不能以应用内副本代替外部备份。系统自动备份与设备迁移能力由系统配置决定。

恢复先等待已发起的写入与设置保存结束，拒绝活动训练，核对候选摘要、当前内容与
数据集 epoch。随后写入、flush、同目录发布并重读保护副本，登记 ready 后才允许
核心替换。空间不足或保护文件校验失败时不开始替换，不提供跳过保护入口。

计划、历史、来源映射、完成次序、跳过批次、旧提醒清理以及核心提交标记在同一
SQLite 事务内完成，保留 AUTOINCREMENT 高水位。比较覆盖全部协议业务字段，
不以数量相同代替内容相同。设置另行逐项应用；设置失败只重试未完成设置，
手动修改某项设置会终止该项旧重试。已阅说明、权限和本机控制日志不来自备份。

撤回绑定具体恢复操作，并继承原来的“恢复设置”选择。执行撤回前再次保护当前数据：
例如恢复后新增训练，再撤回，新增训练仍能从此次撤回前生成的副本找回。
副本不会自动过期；可在设置 → 数据 → 备份与恢复 → 恢复前副本中导出、恢复或
确认删除指定副本。删除仅影响该副本及绑定它的快捷撤回，不删除当前记录。

进程退出后检查持久日志：未提交的 preparing/protected 操作需核实旧数据后终止；
core_committed/settings_pending 不重复核心替换，仅核实设置；已提交后新增的训练
不与旧目标摘要作误比较。无法核实核心结果时限制正常写入并提供重试。
禁用返回仅防误操作，不能防止系统杀进程。


本地数据库 v6 用 plans.sort_order 和 workout_sessions.backup_order 表达备份数组顺序。
v5→v6 按旧查询初始化，新建／计划导入／保存训练由事务内触发器追加，完整恢复写入
目标位置；这两个本地列不进入 JSON。逆时间与并列时间数组保持原序，createdAt、
startedAt 和 startedLocalDate 均不因此改写，历史展示仍使用原日期规则。


2026-10-17 Android 28 / 2 GiB 隔离模拟器 / Flutter debug 的真实文件读写测试：

| 场景 | 文件字节 | 工作isolate写入ms | 工作isolate读取ms | App进程峰值RSS字节 |
| --- | ---: | ---: | ---: | ---: |
| 十年3653场，8动作×5组 | 21,547,424 | 4490 | 4744 | 603,987,968 |
| 64 MiB边界 | 67,108,864 | 1961 | 2057 | 843,284,480 |

命令为 `flutter test --no-pub integration_test/backup_capacity_android_test.dart -d emulator-5556`。
两个场景在同一App进程依次由工作isolate执行，RSS是累计进程峰值（包含Flutter运行时与夹具），
不是单个对象或单个isolate的分配量；时间包含文件flush及完整校验。此项不测量十年数据的
SQLite全量恢复耗时，不代表所有内存档位真机已通过。当前未因测量结果缩小容量或删减历史。

恢复操作日志的 target_summary 保存原目标快照时间与数量，仅用于中断后的结果呈现，
不用于判断当前数据是否回滚。较旧导出请求补记时以操作顺序判断是否更新“最新导出”标记，
不以可能回拨的设备时钟覆盖较新记录。发布回执丢失时先核实同一请求，不重复生成公共文件。
