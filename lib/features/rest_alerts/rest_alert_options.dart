class RestAlertOptions {
  const RestAlertOptions({
    this.sound = 'three_tone',
    this.vibration = true,
    this.repeat = true,
    this.interval = 10,
  });
  static const sounds = ['three_tone', 'double_beep', 'voice'];
  static const intervals = [10, 15, 30, 60];
  final String sound;
  final bool vibration, repeat;
  final int interval;
  factory RestAlertOptions.fromMap(Map<String, Object?> row) =>
      RestAlertOptions(
        sound: sounds.contains(row['sound_id'])
            ? row['sound_id'] as String
            : 'three_tone',
        vibration: row['vibration_enabled'] != 0,
        repeat: row['repeat_enabled'] != 0,
        interval: intervals.contains(row['interval_seconds'])
            ? row['interval_seconds'] as int
            : 10,
      );
  Map<String, Object?> toMap() => {
    'sound_id': sound,
    'vibration_enabled': vibration ? 1 : 0,
    'repeat_enabled': repeat ? 1 : 0,
    'interval_seconds': interval,
  };
  RestAlertOptions copyWith({
    String? sound,
    bool? vibration,
    bool? repeat,
    int? interval,
  }) => RestAlertOptions(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    repeat: repeat ?? this.repeat,
    interval: interval ?? this.interval,
  );
}
