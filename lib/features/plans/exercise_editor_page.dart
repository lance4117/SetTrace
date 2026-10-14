import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/step_picker.dart';
import 'plan_models.dart';
import 'plan_repository.dart';

class ExerciseEditorPage extends StatefulWidget {
  const ExerciseEditorPage({
    super.key,
    required this.plans,
    required this.planId,
    this.exercise,
  });

  final PlanRepository plans;
  final int planId;
  final PlanExercise? exercise;

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

class _ExerciseEditorPageState extends State<ExerciseEditorPage> {
  late final TextEditingController name = TextEditingController(
    text: widget.exercise?.name ?? '',
  );
  late final TextEditingController weight = TextEditingController(
    text: widget.exercise?.defaultWeightKg?.toString() ?? '',
  );
  late int sets = widget.exercise?.targetSets ?? 4;
  late int between = widget.exercise?.restBetweenSetsSeconds ?? 120;
  late int after = widget.exercise?.restAfterExerciseSeconds ?? 150;
  bool saving = false;
  bool confirming = false;
  bool nameInvalid = false, weightInvalid = false;
  LocalizedMessage? saveError;
  bool initializedWeight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initializedWeight) {
      initializedWeight = true;
      weight.text = widget.exercise?.defaultWeightKg == null
          ? ''
          : context.formats.weight(widget.exercise!.defaultWeightKg!);
    }
  }

  @override
  void dispose() {
    name.dispose();
    weight.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final trimmed = name.text.trim();
    final rawWeight = weight.text.trim();
    final parsedWeight = rawWeight.isEmpty ? null : parseWeight(rawWeight);
    setState(() {
      nameInvalid = trimmed.isEmpty || trimmed.characters.length > 60;
      weightInvalid =
          rawWeight.isNotEmpty && (parsedWeight == null || parsedWeight <= 0);
      saveError = null;
    });
    if (nameInvalid || weightInvalid) return;
    setState(() => saving = true);
    var succeeded = false;
    try {
      if (widget.exercise == null) {
        await widget.plans.addExercise(
          planId: widget.planId,
          name: trimmed,
          targetSets: sets,
          restBetweenSetsSeconds: between,
          restAfterExerciseSeconds: after,
          defaultWeightKg: parsedWeight,
        );
      } else {
        await widget.plans.updateExercise(
          id: widget.exercise!.id,
          name: trimmed,
          targetSets: sets,
          restBetweenSetsSeconds: between,
          restAfterExerciseSeconds: after,
          defaultWeightKg: parsedWeight,
        );
      }
      succeeded = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              saveError = (l) => failureText(l, error, fallback: l.saveFailed),
        );
      }
    } finally {
      if (mounted && !succeeded) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    if (saving || confirming) return;
    confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Builder(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.deleteExerciseTitle),
          content: Text(
            [
              widget.exercise!.name,
              context.l10n.deleteExerciseNote,
              context.l10n.irreversible,
            ].join("\n\n"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.danger,
              ),
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
    confirming = false;
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.plans.deleteExercise(widget.exercise!.id, widget.planId);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          saveError = (l) => failureText(l, error);
        });
      }
    }
  }

  Widget fieldLabel(BuildContext context, String label) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      label,
      style: TextStyle(color: context.appColors.textSecondary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !saving,
          title: Text(
            widget.exercise == null
                ? context.l10n.addExercise
                : context.l10n.editExercise,
          ),
          actions: widget.exercise == null
              ? null
              : [
                  TextButton(
                    onPressed: saving ? null : delete,
                    child: Text(
                      context.l10n.delete,
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
                ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      fieldLabel(context, context.l10n.exerciseName),
                      TextField(
                        key: const ValueKey('exercise-name'),
                        controller: name,
                        enabled: !saving,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        maxLength: 60,
                        decoration: InputDecoration(
                          hintText: context.l10n.exerciseNameHint,
                          errorText: nameInvalid
                              ? context.l10n.exerciseNameError
                              : null,
                          counterText: '',
                        ),
                      ),
                      SizedBox(height: 20),
                      fieldLabel(context, context.l10n.setsLabel),
                      StepPicker(
                        value: sets,
                        enabled: !saving,
                        semanticLabel: context.l10n.setsLabel,
                        min: 1,
                        max: 100,
                        step: 1,
                        label: (value) => context.l10n.setCount(value),
                        onChanged: (value) => setState(() => sets = value),
                      ),
                      SizedBox(height: 20),
                      fieldLabel(context, context.l10n.betweenSets),
                      StepPicker(
                        value: between,
                        enabled: !saving,
                        semanticLabel: context.l10n.betweenSets,
                        min: 0,
                        max: 3600,
                        step: 30,
                        label: (value) => context.l10n.minutesShort(
                          context.formats.decimal(value / 60),
                        ),
                        onChanged: (value) => setState(() => between = value),
                      ),
                      SizedBox(height: 20),
                      fieldLabel(context, context.l10n.afterExercise),
                      StepPicker(
                        value: after,
                        enabled: !saving,
                        semanticLabel: context.l10n.afterExercise,
                        min: 0,
                        max: 3600,
                        step: 30,
                        label: (value) => context.l10n.minutesShort(
                          context.formats.decimal(value / 60),
                        ),
                        onChanged: (value) => setState(() => after = value),
                      ),
                      SizedBox(height: 20),
                      fieldLabel(context, context.l10n.weightLabel),
                      TextField(
                        key: const ValueKey('exercise-weight'),
                        controller: weight,
                        enabled: !saving,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          errorText: weightInvalid
                              ? context.l10n.weightInputError
                              : null,
                          hintText: context.l10n.weightHint(
                            context.formats.weight(45.5),
                          ),
                        ),
                      ),
                      if (saveError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          saveError!(context.l10n),
                          style: TextStyle(color: colors.danger),
                        ),
                      ],
                      SizedBox(height: 16),
                      Text(
                        context.l10n.pickerHint,
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: context.l10n.saveExercise,
                  busy: saving,
                  onPressed: saving ? null : save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
