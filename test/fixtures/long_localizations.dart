import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:settrace/l10n/generated/app_localizations.dart';
import 'package:settrace/l10n/generated/app_localizations_en.dart';

class LongStrings extends AppLocalizationsEn {
  @override
  String get settings =>
      "Settings with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get appearance =>
      "Appearance with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get language =>
      "Language with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get localDataNote =>
      "Your workout data stays on this device. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get systemTheme =>
      "System default with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get lightTheme =>
      "Light with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get darkTheme =>
      "Dark with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get saveExercise =>
      "Save exercise with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get exerciseName =>
      "Exercise name with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get setsLabel =>
      "Sets with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get betweenSets =>
      "Rest between sets with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get afterExercise =>
      "Rest after exercise with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get weightLabel =>
      "Weight (optional, kg) with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get pickerHint =>
      "Swipe to adjust. Each step gives light haptic feedback. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get allExercisesEdit =>
      "View and edit exercises with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get completeSet =>
      "Complete set with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get undoLastSet =>
      "Undo last set with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get currentExerciseMovable =>
      "No sets completed for this exercise yet. You can switch to another exercise. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get currentExerciseFixed =>
      "Finish this exercise first. You can still reorder the exercises that follow. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get changeNext =>
      "Change next exercise with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get copyClipboard =>
      "Copy to clipboard with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get exportFile =>
      "Export to file with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get exportNote =>
      "Backups contain your plans and exercise settings, but not your workout history. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get chooseFile =>
      "Choose a file with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get previewPlans =>
      "Preview plans with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get chooseAgain =>
      "Choose again with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get confirmImport =>
      "Import plans with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get importHint =>
      "Paste shared plan text or choose a local plan file. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get permissionDenied =>
      "Allow access to save in Downloads, or copy plans to the clipboard. with additional translated wording for readability with additional translated wording for readability ";
  @override
  String get damagedContent =>
      "The plan content is damaged. Use the complete exported text or file. with additional translated wording for readability with additional translated wording for readability ";
}

class LongDelegate extends LocalizationsDelegate<AppLocalizations> {
  const LongDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == "en";
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(LongStrings());
  @override
  bool shouldReload(LongDelegate old) => false;
}
