# 归档说明

归档日期：2026-10-25（Asia/Hong_Kong）。变更：`add-local-diagnostics`；schema：`spec-driven`。

用户已明确选择“同步主规格后归档，保留5项待验”。本次归档不表示所有设备验收完成，不修改原任务勾选，也不执行Git提交或发布。

主规格同步：新建 `app-diagnostics`（12条要求），修改 `app-experience`（4条要求）及 `data-backup`（1条要求）。逐项核验增量已全部合入，既有其他要求及场景保留；全部7份主规格及本变更严格校验通过。

任务保持55／60完成，以下5项未完成：

- 8.4：API28旧版权限与文件发布、API29实际MediaStore差异。
- 10.3：真实系统备份恢复、异机及厂商迁移。
- 11.2：API28／29／30／31各版本实际设备覆盖。
- 11.4：指定低配release性能、主线程I/O及受控崩溃符号还原。
- 11.5：TalkBack、减少动态效果人工操作、代表性真机矩阵与听感。

实施与验证证据见[验收报告](../../../../docs/qa/local-diagnostics-acceptance.md)和[证据索引](../../../../docs/qa/local-diagnostics/README.md)。这些未验项在归档后的 `tasks.md` 中继续保留，不以已有自动化或模拟器结果冒充通过。SQLite仍为v6，完整备份格式仍为1，首次说明为版本3。
