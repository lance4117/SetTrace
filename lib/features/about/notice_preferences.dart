import 'package:shared_preferences/shared_preferences.dart';

const noticePreferenceKey = 'app_notice_seen_version';
const currentNoticeVersion = 1;

class NoticePreferences {
  NoticePreferences(this.preferences);
  final SharedPreferences preferences;
  bool? _stateAfterFailedWrite;
  bool get hasSeenCurrent {
    if (_stateAfterFailedWrite != null) return _stateAfterFailedWrite!;
    try {
      final value = preferences.get(noticePreferenceKey);
      return value is int && value >= currentNoticeVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> acknowledge() async {
    final before = hasSeenCurrent;
    try {
      final saved = await preferences.setInt(
        noticePreferenceKey,
        currentNoticeVersion,
      );
      if (!saved) throw StateError('noticePreferenceWriteFailed');
      _stateAfterFailedWrite = null;
    } catch (_) {
      // Legacy preferences update their cache before the platform write.
      _stateAfterFailedWrite = before;
      try {
        await preferences.reload();
      } catch (_) {}
      rethrow;
    }
  }
}
