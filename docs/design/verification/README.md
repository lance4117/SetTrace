# 设计资料验证与证据范围

版本 `focus-a-2026-10-14`。此目录记录设计稿与文档接入的检查，**不证明 Flutter 新 UI 或 Android 真机已通过验收**。

## 既有浏览器设计稿检查

- [delivery-checks.json](delivery-checks.json)：29 个主要画面在 Light / Dark × 中文 / English 下的横向溢出、按钮最小命中尺寸；小屏、大字号、键盘、横屏、平板样本；部分示例交互与 SVG 解析检查。
- [qa-results.json](qa-results.json)：设计稿运行错误、完成→休息→加时→跳过→恢复的示例状态及浏览器移动宽度检查。

这些是上一轮浏览器设计稿的原始结果；字段、示例数字和固定日期不是产品默认值。原型仅模拟，不操作系统权限、文件、剪贴板、通知或真实训练数据库。Picker 手势、真实主题／语言持久化和系统返回不能由这些报告认证。

## 本次文档接入检查

结果保存在 [documentation-checks.json](documentation-checks.json)，核对范围包括：

1. 旧设计四文件的归档哈希与大小。
2. 当前 Markdown 与设计稿、图像、代码／规格引用能否解析，页面编号和数量是否完整。
3. HTML 不依赖会话目录或外部资源；SVG 包无坏条目；引用不会指向旧稿为当前规范。
4. 本地 OpenSpec CLI 识别项目，读取真实 artifact instructions 时返回当前设计入口、授权限制和相应规则；不创建任何产物。
5. 应用代码、`openspec/specs`、已归档变更和现有未完成 change 文件的哈希未改变。

## OpenSpec 的读取方式

项目的 `openspec/config.yaml` 将阅读入口放在 `context`，并为 `proposal`、`design`、`specs`、`tasks` 设置相应规则。CLI 会把这些文字注入返回的 instructions，**不会自动把路径指向的 Markdown 全文拼进去**；代理必须依指令实际打开相关文件。apply guidance 是工作提示，不是访问控制或自动批准机制。

当前默认 `openspec` PowerShell 包装器使用的 Node 曾在此沙箱遇到 `EPERM lstat`。本次使用本机已存在的可用 Node 直接运行同一个全局 OpenSpec 入口完成只读验证，未安装依赖、修改 PATH 或系统配置。若其他机器出现同类问题，应使用其可用运行时排查，不复制本机会话绝对路径到项目配置。

真正的 UI／Android 验收清单位于 [acceptance-checklist.md](../acceptance-checklist.md)。后续用户已授权实施，新的 Flutter 结果单列在[实施报告](../../qa/focus-a-redesign-acceptance.md)，不改写本目录的设计资料历史结果。当前文档中的来源提交与既有 QA 图片仅用于核对功能覆盖。
