# 验证证据与结果解释

当前参考复用 focus-a 与后续增量的要求；版本、构建和采集信息见 [构建记录](build.json) 与 [清单](../manifest.json)。

实现与验证是两个维度：implemented/planned/unknown 描述实现；passed-current、passed-historical、pending、failed、not-implemented、not-applicable 描述某个环境下的检查结果。

- passed-current 必须有当前源码／构建、预期、观察、环境及落盘证据。
- 旧报告仅能记为 passed-historical。代码存在或页面截图不能证明事务、文件写入、失败恢复或全部适配通过。
- release-emulator 是新 release APK 的实际 Android 原帧；widget-test 是当前生产组件在隔离 SQLite／平台夹具下的测试渲染。Windows 字体回退与 Android 字体存在差异。
- 正常、空、加载／提交、禁用、失败、未知和取消分别记录。预览不是文件保存成功，停止提醒不是完成训练，通知请求不证明真人听见。
- TalkBack、真实听感／振动、小米后台、系统迁移、旧 API 和长时资源条件需独立证据；未执行即 pending。
- 长页面以分段原帧为参考，首屏与末尾均保留；若日后生成拼接图必须列出原帧，不将其称为原始系统截图。

结果字段：screen_id/state_id、criteria、expected、observed、implementation、test、evidence、baseline_id、environment、method、result。当前执行与历史结果分别保存，未取得证据不自动升级。

资料交付 REF-01–08：入口唯一、来源保全、状态索引完整、构建可追溯、截图与适配范围清晰、验证有据、离线及链接有效、业务与历史未被改变。资料可完成而产品人工待验仍存在；必需截图缺失时对应任务不完成。
