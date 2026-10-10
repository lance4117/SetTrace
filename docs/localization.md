# 语言包维护

SetTrace 使用 Flutter SDK `flutter_localizations`、`intl` 和 `gen-l10n`。英文模板是 `lib/l10n/app_en.arb`，简体中文是 `app_zh.arb`。所有选项从生成的 `supportedLocales` 和各包的 `languageSelfName` 派生，没有另一份语言注册表。仅支持 Flutter 官方控件与日期数字数据已覆盖的 LTR 语言。

## 添加语言

1. 复制英文模板为 `lib/l10n/app_fr.arb`（地区／脚本文件例：`app_fr_CA.arb`、`app_sr_Latn.arb`）。将 `@@locale` 改为文件名中的标签，`languageSelfName` 改为语言自称，例如 `Français`。
2. 翻译全部非 `@` 键，保留键名、具名参数及参数类型。保留模板上下文和占位符说明；不要用英文回退填补漏译。`@key.placeholders` 的类型必须与模板一致。ICU 的复数类别按目标语言编写，可与英文不同；包含 `other` 分支。配置启用了 ICU 转义，字面花括号需引用、单引号需双写 `''`，通过生成验证。
3. `importSuffix(number)` 的输出必须非空且短于 40 个 grapheme，包含数字的情况也要留下原名空间。中文为 `（导入）`／`（导入2）`，英文为 ` (imported)`／` (imported 2)`。一次预览和提交固定使用同一格式化回调；已保存的名字不随语言改变。
4. 按下面相同的命令检查、生成并构建，然后逐页面和失败分支审阅译文与小屏布局。无需改业务页面、resolver、原生资源或语言列表。语言包随构建发布，添加文件后需要重新构建。

```powershell
flutter pub get
dart run tool/check_localizations.dart
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
```

检查入口自动发现 ARB，拒绝缺键、额外键、空值、标签／自称问题、参数不一致；调用官方生成器检查 ICU 和缺译报告，并测试所有生成语言的官方 delegate、自称和导入后缀。`build/l10n-untranslated.json` 必须为空。生成的 `lib/l10n/generated` 被忽略，由生成／正常构建重建；不要手工编辑。

`dart run tool/test_language_extension.dart --build` 在临时副本新增合成法语测试包，执行离线依赖解析、生成和测试，验证自称、选项、系统首选匹配、复数、法语月份及逗号小数；另验证错误 ICU 被定位拒绝。结束即删除副本，不发布测试法语。测试用长文案 delegate 位于 `test/fixtures/long_localizations.dart`，同样不进入发布列表。

## 文案语境

| 英文 | 用法 |
| --- | --- |
| Workout | 一次训练会话或已保存记录，不用于单个动作 |
| Exercise | 计划／训练中的动作，用户动作名原样显示 |
| Set | 一个目标组或已完成组，数量用完整 ICU 复数消息 |
| Rest | 组间／动作后休息；存储为秒、增减仍为 30 秒 |
| History | 历史入口，详情使用 Workout details |
| Save completed sets | 结束当前训练并保存已完成组为历史，未完成组不标成完成 |
| Discard workout | 丢弃当前会话及其完成组，已有历史不变；有完成组时再次确认 |
| Undo last set | 撤销当前训练最近完成的一组 |
| Save workout settings | 只修改本次训练配置，不修改原计划或已开始的休息 |

完整资源／使用位置见 [文案清单](qa/localization-copy-inventory.md)。参数里的用户名字、实际文件名、已存后缀和历史快照不翻译。自动检查证明结构与已知出口的覆盖；准确和自然的译文仍须结合界面、操作后果及错误语境逐条审阅。

## 格式与数据边界

`AppFormats` 用当前应用语言格式化数字、日期、月份、24 小时时间、kg 重量及历史时长；ICU 数量参数使用模板的 `decimalPattern`。倒计时仍为 `mm:ss`。设备本地日期、时区、周一起算、训练统计和绝对休息截止时间保持原定义。切换语言不重算历史。

重量输入不接受分组符号：`45.5` 和 `45,5` 都是 45.5 kg；混合／重复分隔符、负数、零和非有限数被拒绝。空值代表未设置。已经输入的草稿不因切换语言改写。SQLite 数值、整数秒、UTC 时间戳及 JSON v1 与语言无关。

Dart／Kotlin 错误用稳定代码和有类型参数，显示层生成当前语言反馈。未知异常仅显示通用错误，不显示 `$error` 或原生堆栈。Android 成功位置标识固定 `downloads`，实际文件名原样反馈。系统文件选择器与权限弹窗遵循系统语言。

## 硬编码检查的边界与例外

AST 检查 `Text`、`TextSpan`、按钮、输入提示、tooltip、语义及反馈的已知文字参数，覆盖直接构造、隐式构造和动态插值中的中英文。条件判断中的协议值不是显示文字。唯一可直接出现在文字出口中的品牌是 `SetTrace`；固定 `mm:ss` 和纯数字／标点允许。方法通道、JSON／数据库键、路由／偏好键、测试 key 和内部诊断不翻译，不排除整个业务文件。Dart／原生文件另检查中文残留。

间接变量或新控件文字出口仍需要代码审阅，并在新增出口时扩展检查入口。源扫描与完整性检查不能证明译文语义。发布验收记录包含真实截图、语境审阅和设备结果。
