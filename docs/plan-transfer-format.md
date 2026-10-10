# 训练计划传输格式 v1

SQLite 是计划的唯一实时数据源。导出时读取选中计划的快照并临时生成 JSON；已导出的文件不会随编辑自动更新。导入先校验、预览，再在一个事务内新增计划，不替换数据库。

文件为 UTF-8，扩展名 `.settrace.json`，剪贴板使用同一格式：

```json
{
  "format": "settrace.training-plans",
  "schemaVersion": 1,
  "exportedAt": "2026-10-03T08:00:00Z",
  "plans": [{
    "name": "练背",
    "exercises": [{
      "name": "高位下拉",
      "targetSets": 4,
      "restBetweenSetsSeconds": 120,
      "restAfterExerciseSeconds": 150,
      "defaultWeightKg": 45.0
    }]
  }]
}
```

`format`、整数 `schemaVersion`、非空 `plans` 为必填。`exportedAt` 是可选导出时间元数据，不作为本地创建时间。

| 字段 | 规则 |
| --- | --- |
| 计划 `name` | 去除首尾空白，1–40 个可见字符 |
| 动作 `name` | 去除首尾空白，1–60 个可见字符 |
| `exercises` | 必填数组，允许为空，数组顺序即训练顺序 |
| `targetSets` | 1–100 的整数 |
| 两个休息字段 | 0–3600 整数秒，30 的倍数 |
| `defaultWeightKg` | 可省略或 null，否则为有限正数，单位 kg |

接受首尾空白和 UTF-8 BOM；忽略 v1 未知附加字段。未知版本、错误标识、缺失必填字段、非法参数或空计划数组拒绝整份内容，不静默修正。两种渠道均有 2 MiB UTF-8 上限，超限应减少选择数量。导入按收到的原始内容大小校验；导出按实际生成的 JSON 大小校验。保存导入草稿不会为大小校验而重新格式化 JSON。Android 剪贴板可能有更低的平台限制，复制失败时改用文件。额外聊天说明和 Markdown 包裹不属于可导入内容。

内容不包含数据库 ID、训练历史、进行中会话和主题设置。导入使用新 ID、当前本地创建时间。同名时按本次预览语言生成后缀，中文为“（导入）”“（导入2）”，英文为“ (imported)”“ (imported 2)”，预留 grapheme 字符空间；预览与提交采用同一策略；确认期间出现新冲突则回到预览。任何保存失败均回滚整批。


语言切换只影响界面和新冲突后缀，JSON v1 的字段、标准数字和 UTC 时间戳不变。已保存名称与历史不改写。新文件名固定为 `SetTrace-plans-<本地时间戳>.settrace.json`；旧中文文件名按相同内容规则导入，文件名不参与格式识别。

内部 Android 桥接仍返回 `success`／`cancelled`／`error`。保存成功携带实际 `fileName` 和固定 `location: downloads`；错误携带稳定 `code`（例如 `permissionDenied`、`fileTooLarge`、`fileReadFailed`），不携带显示语言。Flutter 生成可理解反馈，未知代码回退通用失败，不泄露原生详情。此内部协议更新不影响外部 JSON v1。
