# 文案与路径清单

本清单覆盖全部正式资源键，方便新增语言时逐条核对语境。英文按 Workout／Exercise／Set／Rest／History 统一审阅；用户名字、文件名原样保留。ICU 占位符表示运行时参数。

| 键 | English | 中文 | 使用位置 |
| --- | --- | --- | --- |
| `languageSelfName` | English | 中文 | `lib/l10n/language_settings.dart` |
| `settings` | Settings | 设置 | `lib/features/settings/settings_page.dart`, `lib/core/widgets/app_bottom_nav.dart` |
| `appearance` | Appearance | 外观 | `lib/features/settings/settings_page.dart` |
| `language` | Language | 语言 | `lib/features/settings/settings_page.dart` |
| `systemTheme` | System default | 跟随系统 | `lib/features/settings/settings_page.dart` |
| `lightTheme` | Light | 浅色 | `lib/features/settings/settings_page.dart` |
| `darkTheme` | Dark | 深色 | `lib/features/settings/settings_page.dart` |
| `localDataNote` | Your workout data stays on this device. | 训练数据仅保存在本机。 | `lib/features/settings/settings_page.dart` |
| `plansTab` | Plans | 计划 | `lib/core/widgets/app_bottom_nav.dart` |
| `historyTab` | History | 记录 | `lib/core/widgets/app_bottom_nav.dart` |
| `cancel` | Cancel | 取消 | `lib/features/history/history_page.dart`, `lib/features/plans/exercise_editor_page.dart`, `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_transfer_pages.dart`, `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_page.dart` |
| `save` | Save | 保存 | `lib/features/plans/plans_page.dart` |
| `delete` | Delete | 删除 | `lib/features/history/history_page.dart`, `lib/features/plans/exercise_editor_page.dart`, `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/workout/workout_repository.dart` |
| `retry` | Retry | 重试 | `lib/l10n/localization.dart` |
| `newPlanTitle` | Create a plan | 新建训练计划 | `lib/features/plans/plans_page.dart` |
| `renamePlanTitle` | Rename plan | 编辑计划名称 | `lib/features/plans/plans_page.dart` |
| `planNameHint` | For example: Back day | 例如：练背 | `lib/features/plans/plans_page.dart` |
| `plansTitle` | Workout plans | 训练计划 | `lib/features/plans/plans_page.dart` |
| `newPlan` | ＋ New | ＋ 新建 | `lib/features/plans/plans_page.dart` |
| `transferMenu` | Import or export plans | 计划导入导出 | `lib/features/plans/plans_page.dart` |
| `importPlans` | Import plans | 导入计划 | `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_transfer_pages.dart` |
| `exportPlans` | Export plans | 导出计划 | `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_transfer_pages.dart` |
| `whatToTrain` | What are you training today? | 今天练什么？ | `lib/features/plans/plans_page.dart` |
| `resumeWorkout` | Resume workout | 继续训练 | `lib/features/plans/plans_page.dart`, `lib/features/workout/workout_page.dart` |
| `noPlansYet` | No plans yet. Create your first one. | 还没有训练计划，先新建一个吧 | `lib/features/plans/plans_page.dart` |
| `noExercises` | No exercises yet | 还没有动作 | `lib/features/plans/plans_page.dart` |
| `planDetails` | Plan details | 计划详情 | `lib/features/plans/plans_page.dart` |
| `rename` | Rename | 修改名称 | `lib/features/plans/plans_page.dart` |
| `deletePlan` | Delete plan | 删除计划 | `lib/features/plans/plans_page.dart` |
| `deletePlanTitle` | Delete this plan? | 删除这个计划？ | `lib/features/plans/plans_page.dart` |
| `deletePlanNote` | Your saved workouts and current workout will be kept. | 已有训练记录和进行中的训练不会被删除。 | `lib/features/plans/plans_page.dart` |
| `reorderPlanHint` | Drag the handles on the left to reorder exercises. | 长按左侧把手调整动作顺序 | `lib/features/plans/plans_page.dart` |
| `noExercisesAdd` | No exercises yet. Add one below. | 还没有动作，点击下方添加 | `lib/features/plans/plans_page.dart` |
| `addExerciseAction` | ＋ Add exercise | ＋ 添加动作 | `lib/features/plans/plans_page.dart` |
| `startWorkout` | Start workout | 开始训练 | `lib/features/plans/plans_page.dart` |
| `activeWorkoutTitle` | A workout is already in progress | 已有未完成训练 | `lib/features/plans/plans_page.dart` |
| `stayHere` | Stay here | 留在此处 | `lib/features/plans/plans_page.dart` |
| `resumeOriginal` | Resume that workout | 继续原训练 | `lib/features/plans/plans_page.dart` |
| `prepareWorkout` | Before you start | 准备训练 | `lib/features/plans/plans_page.dart` |
| `exerciseOrder` | Exercise order | 动作顺序 | `lib/features/plans/plans_page.dart` |
| `exerciseInvalid` | Enter an exercise name. If you enter a weight, use a positive number with one decimal point or comma. | 请填写动作名称；重量可留空，填写时须为正数，且只能使用一个小数点或逗号。 | `lib/l10n/error_messages.dart`, `lib/features/plans/exercise_editor_page.dart` |
| `deleteExerciseTitle` | Delete this exercise? | 删除动作？ | `lib/features/plans/exercise_editor_page.dart` |
| `deleteExerciseNote` | This removes the exercise from this plan. Saved workouts will be kept. | 只会从计划中删除，已有训练记录不会改变。 | `lib/features/plans/exercise_editor_page.dart` |
| `addExercise` | Add exercise | 添加动作 | `lib/features/plans/exercise_editor_page.dart` |
| `editExercise` | Edit exercise | 编辑动作 | `lib/features/plans/exercise_editor_page.dart` |
| `exerciseName` | Exercise name | 动作名称 | `lib/features/plans/exercise_editor_page.dart` |
| `exerciseNameHint` | For example: Seated row | 例如：坐姿划船 | `lib/features/plans/exercise_editor_page.dart` |
| `setsLabel` | Sets | 组数 | `lib/l10n/error_messages.dart`, `lib/features/plans/exercise_editor_page.dart` |
| `betweenSets` | Rest between sets | 组间休息 | `lib/l10n/error_messages.dart`, `lib/features/plans/exercise_editor_page.dart`, `lib/features/workout/workout_page.dart` |
| `afterExercise` | Rest after exercise | 动作完成后休息 | `lib/features/plans/exercise_editor_page.dart` |
| `weightLabel` | Weight (optional, kg) | 重量（可选，kg） | `lib/features/plans/exercise_editor_page.dart`, `lib/features/plans/plan_transfer_pages.dart`, `lib/features/workout/workout_page.dart` |
| `pickerHint` | Swipe to adjust. Each step gives light haptic feedback. | 左右滑动切换档位 · 每跨一档轻震反馈 | `lib/features/plans/exercise_editor_page.dart` |
| `saveExercise` | Save exercise | 保存动作 | `lib/features/plans/exercise_editor_page.dart` |
| `finishWorkoutTitle` | Save this workout? | 完成训练？ | `lib/features/workout/workout_page.dart` |
| `endWorkoutTitle` | End this workout? | 结束这次训练？ | `lib/features/workout/workout_page.dart` |
| `emptyWorkoutExit` | You have not completed any sets. Resume the workout or discard it. | 尚未完成任何一组。可继续训练或丢弃本次会话。 | `lib/features/workout/workout_page.dart` |
| `discard` | Discard | 丢弃 | `lib/features/workout/workout_page.dart` |
| `saveCompleted` | Save completed sets | 保存已完成 | `lib/features/workout/workout_page.dart` |
| `confirmDiscardTitle` | Discard this workout? | 确认丢弃？ | `lib/features/workout/workout_page.dart` |
| `confirmDiscardNote` | Your completed sets in this workout will be permanently deleted. | 已完成的组记录会永久删除。 | `lib/features/workout/workout_page.dart` |
| `confirmDiscard` | Discard workout | 确认丢弃 | `lib/features/workout/workout_page.dart` |
| `sessionExercises` | Exercises in this workout | 本次训练动作 | `lib/features/workout/workout_page.dart` |
| `reorderRemaining` | Reorder remaining exercises | 调整剩余顺序 | `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_page.dart` |
| `workoutInProgress` | Workout in progress | 训练中 | `lib/features/workout/workout_page.dart` |
| `endOrReturn` | End or return to workout | 结束或返回 | `lib/features/workout/workout_page.dart` |
| `exitWorkout` | Exit | 退出 | `lib/features/workout/workout_page.dart` |
| `allExercisesEdit` | View and edit exercises | 全部动作与编辑 | `lib/features/workout/workout_page.dart` |
| `undoLastSet` | Undo last set | 撤销上一组 | `lib/features/workout/workout_page.dart` |
| `allSetsCompleted` | All sets completed | 全部组已完成 | `lib/features/workout/workout_page.dart` |
| `saveWorkout` | Save workout | 保存训练 | `lib/features/workout/workout_page.dart` |
| `completeSet` | Complete set | 完成本组 | `lib/features/workout/workout_page.dart` |
| `currentExerciseMovable` | No sets completed for this exercise yet. You can switch to another exercise. | 当前动作尚无完成组，可换成其他待练动作。 | `lib/features/workout/workout_page.dart` |
| `currentExerciseFixed` | Finish this exercise first. You can still reorder the exercises that follow. | 当前动作继续完成，可安排后续动作。 | `lib/features/workout/workout_page.dart` |
| `changeNext` | Change next exercise | 更换下一动作 | `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_page.dart` |
| `nextExercise` | Next exercise | 下一动作 | `lib/features/workout/workout_page.dart` |
| `lastExercise` | This is your last exercise. | 这是最后一个动作 | `lib/features/workout/workout_page.dart` |
| `betweenExercises` | Rest between exercises | 动作间休息 | `lib/features/workout/workout_page.dart` |
| `subtractRest` | −30 sec | −30 秒 | `lib/features/workout/workout_page.dart` |
| `skip` | Skip | 跳过 | `lib/l10n/language_settings.dart`, `lib/features/workout/workout_page.dart` |
| `addRest` | +30 sec | +30 秒 | `lib/features/workout/workout_page.dart` |
| `targetSets` | Target sets | 目标组数 | `lib/features/history/history_page.dart`, `lib/features/plans/exercise_editor_page.dart`, `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_models.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/plans/plan_transfer.dart`, `lib/features/plans/plan_transfer_pages.dart`, `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_models.dart`, `lib/features/workout/workout_page.dart` |
| `afterExerciseShort` | Rest after exercise | 动作后休息 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_page.dart` |
| `sessionEditNote` | Changes apply only to this workout. The current rest timer stays unchanged. | 只修改本次训练；已开始的休息时间不变。 | `lib/features/workout/workout_page.dart` |
| `saveSessionConfig` | Save workout settings | 保存本次配置 | `lib/features/workout/workout_page.dart` |
| `replaceCurrentNote` | Switch to another exercise without recording any extra sets. | 替换当前待练动作，不记录额外完成组。 | `lib/features/workout/session_order_sheet.dart` |
| `chooseFollowingNote` | Choose what comes after this exercise. Current sets and rest stay unchanged. | 当前动作做完后练；当前组数和休息保持。 | `lib/features/workout/session_order_sheet.dart` |
| `reorderSessionNote` | Drag unstarted exercises to reorder them. Exercises with completed sets stay in place. Changes apply only to this workout. | 拖动待练动作；已记录组的动作固定。只影响本次训练。 | `lib/features/workout/session_order_sheet.dart` |
| `noReorderCandidates` | No other unstarted exercises to reorder. | 没有其他可换序的待练动作 | `lib/features/workout/session_order_sheet.dart` |
| `completed` | Completed | 已完成 | `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_models.dart`, `lib/features/workout/workout_page.dart` |
| `pending` | Not started | 待练 | `lib/features/workout/session_order_sheet.dart` |
| `inProgress` | In progress | 进行中 | `lib/features/workout/session_order_sheet.dart` |
| `reload` | Reload | 重新加载 | `lib/app/app.dart`, `lib/features/workout/session_order_sheet.dart` |
| `saveOrder` | Save order | 保存顺序 | `lib/features/workout/session_order_sheet.dart` |
| `historyTitle` | Workout history | 训练记录 | `lib/features/history/history_page.dart` |
| `thisWeek` | Workouts this week | 本周训练 | `lib/features/history/history_page.dart` |
| `thisMonth` | Workouts this month | 本月训练 | `lib/features/history/history_page.dart` |
| `monthDuration` | Time in selected month | 所选月份时长 | `lib/features/history/history_page.dart` |
| `monthSets` | Sets in selected month | 所选月份完成组 | `lib/features/history/history_page.dart` |
| `noRecentWorkout` | No recent workout | 最近训练：暂无 | `lib/features/history/history_page.dart` |
| `previousMonth` | Previous month | 上个月 | `lib/features/history/history_page.dart` |
| `nextMonth` | Next month | 下个月 | `lib/features/history/history_page.dart` |
| `retryRefresh` | Retry refresh | 重试刷新 | `lib/features/history/history_page.dart` |
| `noHistoryMonth` | No workouts this month | 这个月还没有训练记录 | `lib/features/history/history_page.dart` |
| `historyDeleted` | Workout deleted | 记录已删除 | `lib/features/history/history_page.dart` |
| `historyMissing` | This workout no longer exists | 记录已不存在 | `lib/features/history/history_page.dart` |
| `historyLoadFailed` | Could not load your workout history. Try again. | 记录加载失败，请重试 | `lib/features/history/history_page.dart` |
| `deleteHistoryTitle` | Delete this workout? | 删除这条训练记录？ | `lib/features/history/history_page.dart` |
| `activeHistoryDelete` | Only saved workouts can be deleted. Your current workout will be kept. | 只能删除已保存的训练，正在进行的训练不会被删除。 | `lib/features/history/history_page.dart` |
| `historyDeleteFailed` | Could not delete this workout. Try again. | 删除失败，请重试。 | `lib/features/history/history_page.dart` |
| `workoutDetails` | Workout details | 训练详情 | `lib/features/history/history_page.dart` |
| `historyMenu` | Workout actions | 训练记录操作 | `lib/features/history/history_page.dart` |
| `deleteHistory` | Delete workout | 删除记录 | `lib/features/history/history_page.dart` |
| `retryDelete` | Retry delete | 重试删除 | `lib/features/history/history_page.dart` |
| `notCompleted` | Not completed | 未完成 | `lib/features/history/history_page.dart` |
| `exportNote` | Backups contain your plans and exercise settings, but not your workout history. | 训练计划备份包含计划及动作配置，不包含训练记录。 | `lib/features/plans/plan_transfer_pages.dart` |
| `selectAll` | Select all | 全选 | `lib/features/plans/plan_transfer_pages.dart` |
| `deselectAll` | Deselect all | 取消全选 | `lib/features/plans/plan_transfer_pages.dart` |
| `noExportPlans` | No plans to export | 没有可导出的计划 | `lib/features/plans/plan_transfer_pages.dart` |
| `copyClipboard` | Copy to clipboard | 复制到剪贴板 | `lib/features/plans/plan_transfer_pages.dart` |
| `exportFile` | Export to file | 导出到文件 | `lib/features/plans/plan_transfer_pages.dart` |
| `importPreview` | Import preview | 导入预览 | `lib/features/plans/plan_transfer_pages.dart` |
| `importHint` | Paste shared plan text or choose a local plan file. | 粘贴别人分享的计划文本，或选择本地计划文件。 | `lib/features/plans/plan_transfer_pages.dart` |
| `importTextHint` | Paste plan text here | 在这里粘贴计划文本 | `lib/features/plans/plan_transfer_pages.dart` |
| `paste` | Paste | 粘贴 | `lib/features/plans/plan_transfer_pages.dart` |
| `planName` | Plan name | 计划名称 | `lib/features/history/history_page.dart`, `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_transfer_pages.dart`, `lib/features/workout/workout_models.dart`, `lib/features/workout/workout_page.dart` |
| `emptyPlanNote` | This plan is empty. Add an exercise before starting a workout. | 空计划，添加动作后可开始训练 | `lib/features/plans/plan_transfer_pages.dart` |
| `viewExerciseConfig` | View exercise settings | 查看动作配置 | `lib/features/plans/plan_transfer_pages.dart` |
| `weightNotSet` | Not set | 未设置 | `lib/l10n/localization.dart` |
| `chooseFile` | Choose a file | 从文件选择 | `lib/features/plans/plan_transfer_pages.dart` |
| `previewPlans` | Preview plans | 预览计划 | `lib/features/plans/plan_transfer_pages.dart` |
| `chooseAgain` | Choose again | 重新选择 | `lib/features/plans/plan_transfer_pages.dart` |
| `confirmImport` | Import plans | 确认导入 | `lib/features/plans/plan_transfer_pages.dart` |
| `nameConflict` | Some names are already in use. Review the updated names and confirm again. | 名称存在冲突，已调整为副本名称，请检查后再次确认 | `lib/features/plans/plan_transfer_pages.dart` |
| `nameTaken` | A name was taken while you were reviewing. Check the updated preview and confirm again. | 名称已被占用，已更新预览，请再次确认 | `lib/features/plans/plan_transfer_pages.dart` |
| `planNameRequired` | Enter a plan name. | 计划名称不能为空 | `lib/l10n/error_messages.dart`, `lib/features/plans/plans_page.dart` |
| `plansLoadFailed` | Could not load plans. Go back and try again. | 无法加载计划，请返回后重试 | `lib/features/plans/plan_transfer_pages.dart` |
| `exportFailed` | Could not export plans. Try again. | 导出失败，请重试 | `lib/features/plans/plan_transfer_pages.dart` |
| `importFailed` | Could not import plans. Try again. | 导入失败，请重试 | `lib/features/plans/plan_transfer_pages.dart` |
| `operationFailed` | Could not complete this action. Try again. | 操作失败，请重试。 | `lib/l10n/error_messages.dart` |
| `loadFailed` | Could not load this workout. Try again. | 加载失败，请重试。 | `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_page.dart` |
| `saveFailed` | Could not save your changes. Try again. | 保存失败，请重试。 | `lib/features/plans/exercise_editor_page.dart`, `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_page.dart` |
| `languageSaveFailed` | Could not save your language choice. Try again. | 无法保存语言选择，请重试。 | `lib/features/settings/settings_page.dart` |
| `fileTooLarge` | Plan content exceeds 2 MiB. Use fewer plans or a smaller file. | 计划内容超过 2 MiB，请减少计划数量后重试 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `emptyContent` | No plan content. Paste plan text or choose a file. | 没有计划内容，请粘贴文本或选择文件 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `damagedContent` | The plan content is damaged. Use the complete exported text or file. | 计划内容损坏，请使用完整的计划导出文本或文件 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `wrongFormat` | This file is not a SetTrace plan backup. | 无法识别此文件，请选择 SetTrace 导出的计划 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `unsupportedVersion` | This plan format version is not supported. Update the app and try again. | 计划格式版本不受支持，请更新应用后重试 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `noImportPlans` | No plans to import. | 没有可导入的计划 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `selectPlans` | Select at least one plan. | 请至少选择一个计划 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/plans/plan_transfer.dart` |
| `clipboardCopyFailed` | Could not copy plans. Try again or export to a file. | 复制失败，请重试或选择导出到文件 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `clipboardReadFailed` | Could not read the clipboard. Paste your plan text manually. | 无法读取剪贴板，请手动粘贴计划文本 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `clipboardEmpty` | No plan text in the clipboard. Paste text manually or choose a file. | 剪贴板没有计划文本，请手动粘贴或选择文件 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_pages.dart` |
| `fileBusy` | A file operation is already in progress. Please wait. | 文件操作正在进行，请稍候 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileIncomplete` | The file operation did not finish. Try again. | 文件操作未完成，请重试 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileOperationFailed` | The file operation failed. Try again. | 文件操作失败，请重试 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileUnsupported` | Plan file operations are not supported on this platform. | 当前平台暂不支持计划文件操作 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileNotDownloads` | The file was not saved to Downloads. Try again. | 文件未保存到下载目录，请重试 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileReadFailed` | Could not read this file. Choose a valid UTF-8 plan file. | 无法读取文件，请重新选择有效的 UTF-8 计划文件 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `fileEmpty` | This file is empty. Choose another file. | 文件为空，请重新选择 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer_platform.dart` |
| `filePickerFailed` | Could not open the file picker. Paste plan text instead. | 无法打开文件选择器，请使用粘贴文本 | `lib/l10n/error_messages.dart` |
| `permissionDenied` | Allow access to save in Downloads, or copy plans to the clipboard. | 未获得下载目录写入权限，请重试或复制到剪贴板 | `lib/l10n/error_messages.dart` |
| `fileSaveFailed` | Could not save to Downloads. Check available storage and try again. | 无法保存到下载目录，请检查可用空间后重试 | `lib/l10n/error_messages.dart` |
| `plansChanged` | A selected plan was deleted. Go back and select plans again. | 选中的计划已被删除，请返回重新选择 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_repository.dart` |
| `workoutChanged` | This workout has changed. Reload it before reordering. | 训练状态已变化，请重新加载后排序 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `invalidOrder` | Include every unstarted exercise once. Exercises with completed sets must stay in place. | 排序必须包含所有待练动作各一次，不能移动已记录组的动作 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/workout/workout_repository.dart` |
| `sessionEnded` | This workout has ended. Return to your plans. | 本次训练已结束 | `lib/l10n/error_messages.dart`, `lib/features/workout/session_order_sheet.dart` |
| `activeExists` | Resume or end your current workout before starting another. | 已有未完成训练，请先继续或结束。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `emptyPlan` | Add an exercise before starting a workout. | 请先添加动作再开始训练。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `restActive` | Rest is still in progress. Wait or skip it. | 休息仍在进行，请等待或跳过。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `positionChanged` | Your workout progress has changed. Try again. | 训练进度已变化，请重试。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `setAlreadyCompleted` | This set is already completed. Refresh the workout. | 本组已经完成，请刷新。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `noSetToUndo` | There are no completed sets to undo. | 没有可撤销的已完成组。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `noRest` | There is no active rest timer. | 当前没有进行中的休息。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `invalidConfiguration` | Check the number of sets and rest times. | 组数或休息时间无效，请检查。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `exerciseNotFound` | This exercise no longer exists. Refresh the workout. | 动作已不存在，请刷新。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `completedExercise` | Completed exercises cannot be edited. | 已完成的动作不能修改。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `targetBelowCompleted` | The target cannot be lower than the number of completed sets. | 目标组数不能小于已完成组数。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `emptyWorkout` | Complete at least one set before saving this workout. | 未完成任何一组，无法保存训练。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `activeNotFound` | This workout is no longer active. Return to your plans. | 进行中的训练已不存在，请返回计划。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `setCount` | {count, plural, one{{count} set} other{{count} sets}} | {count} 组 | `lib/features/plans/exercise_editor_page.dart`, `lib/features/workout/workout_page.dart` |
| `exerciseSummary` | {exercises, plural, one{{exercises} exercise} other{{exercises} exercises}} · {sets, plural, one{{sets} set} other{{sets} sets}} | {exercises} 个动作 · {sets} 组 | `lib/features/plans/plans_page.dart`, `lib/features/plans/plan_transfer_pages.dart` |
| `importSuccess` | {count, plural, one{Imported {count} plan} other{Imported {count} plans}} | 成功导入 {count} 个计划 | `lib/features/plans/plans_page.dart` |
| `copySuccess` | {count, plural, one{Copied {count} plan} other{Copied {count} plans}} | 已复制 {count} 个计划 | `lib/features/plans/plan_transfer_pages.dart` |
| `selectedPlans` | {count, plural, one{{count} plan selected} other{{count} plans selected}} | 已选 {count} 个计划 | `lib/features/plans/plan_transfer_pages.dart` |
| `importPreviewNote` | {count, plural, one{This will add {count} plan. Duplicate names will get a new name.} other{This will add {count} plans. Duplicate names will get new names.}} | 将新增 {count} 个计划，同名计划创建副本。 | `lib/features/plans/plan_transfer_pages.dart` |
| `fileSaved` | Saved to Downloads: {fileName} | 已保存到下载目录：{fileName} | `lib/features/plans/plan_transfer_pages.dart` |
| `unfinishedPlan` | In progress · {name} | 尚未完成 · {name} | `lib/features/plans/plans_page.dart` |
| `exerciseCurrentSet` | {name} · Set {number} | {name} · 第 {number} 组 | `lib/features/plans/plans_page.dart` |
| `exerciseSets` | {name} · {sets, plural, one{{sets} set} other{{sets} sets}} | {name} · {sets} 组 | `lib/features/workout/workout_page.dart` |
| `exerciseRest` | {sets, plural, one{{sets} set} other{{sets} sets}} · Rest {minutes} min between sets | {sets} 组 · 组间 {minutes} min | `lib/features/plans/plans_page.dart` |
| `exerciseProgressRest` | {total, plural, one{{completed} / {total} set} other{{completed} / {total} sets}} · Rest {minutes} min between sets | {completed} / {total} 组 · 组间 {minutes} 分钟 | `lib/features/workout/workout_page.dart` |
| `exercisePreview` | {index}. {name}    {sets, plural, one{{sets} set} other{{sets} sets}} | {index}  {name}    {sets} 组 | `lib/features/plans/plans_page.dart` |
| `resumePlanNote` | Resume or end “{name}” first. | 请先继续或结束「{name}」。 | `lib/features/plans/plans_page.dart` |
| `exitCompletedNote` | {count, plural, one{You have completed {count} set. Save it to view in your history.} other{You have completed {count} sets. Save them to view in your history.}} | 已完成 {count} 组。可以保存已完成内容，稍后在记录中查看。 | `lib/features/workout/workout_page.dart` |
| `exercisePosition` | Exercise {current} / {total} | 动作 {current} / {total} | `lib/features/workout/workout_page.dart` |
| `currentSet` | Current set: {number} | 当前第 {number} 组 | `lib/features/workout/workout_page.dart` |
| `nextSet` | Next set: {name} · {current} / {total} | 下一组：{name} · {current} / {total} | `lib/features/workout/workout_page.dart` |
| `sessionEditTitle` | Edit for this workout · {name} | 本次编辑 · {name} | `lib/features/workout/workout_page.dart` |
| `pendingSets` | {sets, plural, one{{sets} set} other{{sets} sets}} · Not started | {sets} 组 · 待练 | `lib/features/workout/session_order_sheet.dart` |
| `orderProgress` | {state} · {total, plural, one{{completed} / {total} set} other{{completed} / {total} sets}} | {state} · {completed} / {total} 组 | `lib/features/workout/session_order_sheet.dart` |
| `dragExercise` | Drag {name} | 拖动{name} | `lib/features/workout/session_order_sheet.dart` |
| `minutesDuration` | {minutes, plural, one{{minutes} minute} other{{minutes} minutes}} | {minutes} 分钟 | `lib/l10n/localization.dart` |
| `hoursDuration` | {hours, plural, one{{hours} hour} other{{hours} hours}} {minutes, plural, one{{minutes} minute} other{{minutes} minutes}} | {hours} 小时 {minutes} 分钟 | `lib/l10n/localization.dart` |
| `minutesShort` | {minutes} min | {minutes} min | `lib/features/plans/exercise_editor_page.dart`, `lib/features/workout/workout_page.dart` |
| `weightKg` | {weight} kg | {weight} kg | `lib/l10n/localization.dart` |
| `weightHint` | For example: {weight} | 例如：{weight} | `lib/features/plans/exercise_editor_page.dart` |
| `recentWorkout` | Latest workout: {name} · {duration} | 最近训练：{name} · {duration} | `lib/features/history/history_page.dart` |
| `historySummary` | {duration} · {exercises, plural, one{{exercises} exercise} other{{exercises} exercises}} · {sets, plural, one{{sets} set} other{{sets} sets}} | {duration} · {exercises} 个动作 · {sets} 组 | `lib/features/history/history_page.dart` |
| `historyRefreshFailed` | {notice}. Could not refresh. Try again. | {notice}，刷新失败，请重试 | `lib/features/history/history_page.dart` |
| `deleteHistoryNote` | {name}<br>{date}<br><br>This cannot be undone. Your workout statistics will be updated. | {name}<br>{date}<br><br>删除后无法恢复，相关训练统计将同步更新。 | `lib/features/history/history_page.dart` |
| `historyTimeRange` | {date} · {start}–{end} · {duration} | {date} · {start}–{end} · {duration} | `lib/features/history/history_page.dart` |
| `completedSets` | {total, plural, one{{completed} / {total} set completed} other{{completed} / {total} sets completed}} | 完成 {completed} / {total} 组 | `lib/features/history/history_page.dart`, `lib/features/history/history_stats.dart`, `lib/features/workout/session_order_sheet.dart`, `lib/features/workout/workout_models.dart`, `lib/features/workout/workout_page.dart` |
| `setResult` | Set {number} · {result} | 第 {number} 组 · {result} | `lib/features/history/history_page.dart` |
| `transferExerciseDetails` | {index}. {name}<br>{sets, plural, one{{sets} set} other{{sets} sets}} · Rest between sets: {between, plural, one{{between} second} other{{between} seconds}}<br>Rest after exercise: {after, plural, one{{after} second} other{{after} seconds}} · Weight: {weight} | {index}. {name}<br>{sets} 组 · 组间休息 {between} 秒<br>动作后休息 {after} 秒 · 重量 {weight} | `lib/features/plans/plan_transfer_pages.dart` |
| `importSuffix` | {number, plural, =1{ (imported)} other{ (imported {number})}} | {number, plural, =1{（导入）} other{（导入{number}）}} | `lib/features/plans/plan_transfer_pages.dart` |
| `planLocation` | Plan {index} | 第 {index} 个计划 | `lib/l10n/error_messages.dart` |
| `exerciseLocation` | Plan {plan}, exercise {exercise} | 第 {plan} 个计划第 {exercise} 个动作 | `lib/l10n/error_messages.dart` |
| `fieldLocation` | {location}: {field} | {location}的{field} | `lib/l10n/error_messages.dart` |
| `invalidObject` | {location} must be a valid object. | {location}必须是有效的对象 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `invalidName` | {location} must contain 1–{max} characters. | {location}必须为 1–{max} 个字符 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `invalidInteger` | {location} must be an integer from {min} to {max}. | {location}必须为 {min}–{max} 的整数 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `invalidRest` | {location} must be a multiple of 30 seconds. | {location}必须为 30 秒的倍数 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/plans/plan_transfer.dart` |
| `invalidWeight` | {location} must be empty or a finite positive number. | {location}必须为空或有效的正数 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_repository.dart`, `lib/features/plans/plan_transfer.dart` |
| `invalidExercises` | {location} needs a valid exercise list. | {location}缺少有效的动作列表 | `lib/l10n/error_messages.dart`, `lib/features/plans/plan_transfer.dart` |
| `planContent` | Plan content | 计划内容 | `lib/l10n/error_messages.dart` |
| `nameField` | Name | 名称 | `lib/l10n/error_messages.dart` |
| `exercisesField` | Exercises | 动作列表 | `lib/l10n/error_messages.dart` |
| `weightField` | Weight | 重量 | `lib/l10n/error_messages.dart` |
| `planNotFound` | This plan no longer exists. Return to your plans and try again. | 这个计划已不存在，请返回计划列表重试。 | `lib/l10n/error_messages.dart`, `lib/features/workout/workout_repository.dart` |
| `planOrderInvalid` | Include every exercise in the plan exactly once. | 排序必须包含计划中的所有动作各一次。 | `lib/l10n/error_messages.dart` |
