import 'package:sqflite/sqflite.dart';

import '../../app/theme/theme_color_controller.dart';
import '../../app/theme/theme_color_preset.dart';
import 'backup_coordinator.dart';
import 'backup_models.dart';

class LiveBackupPreferences implements BackupPreferences {
  LiveBackupPreferences({
    required this.db,
    required this.colors,
    required this.mode,
    required this.language,
    required this.saveMode,
    required this.saveLanguage,
  });
  final Database db;
  final ThemeColorController colors;
  final String Function() mode, language;
  final Future<void> Function(String) saveMode, saveLanguage;
  @override
  Future<void> get settled => colors.settled;
  @override
  Future<BackupSettings> readConfirmed() async {
    final r = (await db.query('rest_alert_preferences', where: 'id=1')).single;
    return BackupSettings.fromJson({
      'themeMode': mode(),
      'themeColor': colors.committed.name,
      'languageTag': language(),
      'reminder': {
        'enabled': r['enabled'] == 1,
        'sound': r['sound_id'],
        'vibration': r['vibration_enabled'] == 1,
        'repeat': r['repeat_enabled'] == 1,
        'interval': r['interval_seconds'],
      },
    });
  }

  @override
  Future<void> apply(String field, Object? value) async {
    switch (field) {
      case 'themeMode':
        await saveMode(value as String);
      case 'themeColor':
        await colors.restoreConfirmed(
          ThemeColorPreset.values.byName(value as String),
        );
      case 'languageTag':
        await saveLanguage(value as String);
      case 'reminder':
        final r = value as BackupMap;
        await db.transaction((txn) async {
          final changed = await txn.update('rest_alert_preferences', {
            'enabled': r['enabled'] == true ? 1 : 0,
            'sound_id': r['sound'],
            'vibration_enabled': r['vibration'] == true ? 1 : 0,
            'repeat_enabled': r['repeat'] == true ? 1 : 0,
            'interval_seconds': r['interval'],
          }, where: 'id=1');
          if (changed != 1) throw StateError('reminderPreferencesMissing');
        });
      default:
        throw ArgumentError.value(field);
    }
  }
}
