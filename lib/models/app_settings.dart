class AppSettings {
  const AppSettings({
    this.localeCode = 'ar',
    this.themeMode = 'system',
    this.use24HourTime = true,
    this.reminderMinutes = 0,
    this.alarmVolume = 1,
    this.vibrationEnabled = true,
    this.soundUri = '',
    this.pausedDate = '',
  });

  final String localeCode;
  final String themeMode;
  final bool use24HourTime;
  final int reminderMinutes;
  final double alarmVolume;
  final bool vibrationEnabled;
  final String soundUri;
  final String pausedDate;

  AppSettings copyWith({
    String? localeCode,
    String? themeMode,
    bool? use24HourTime,
    int? reminderMinutes,
    double? alarmVolume,
    bool? vibrationEnabled,
    String? soundUri,
    String? pausedDate,
  }) =>
      AppSettings(
        localeCode: localeCode ?? this.localeCode,
        themeMode: themeMode ?? this.themeMode,
        use24HourTime: use24HourTime ?? this.use24HourTime,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        alarmVolume: alarmVolume ?? this.alarmVolume,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        soundUri: soundUri ?? this.soundUri,
        pausedDate: pausedDate ?? this.pausedDate,
      );

  Map<String, Object?> toJson() => {
        'localeCode': localeCode,
        'themeMode': themeMode,
        'use24HourTime': use24HourTime,
        'reminderMinutes': reminderMinutes,
        'alarmVolume': alarmVolume,
        'vibrationEnabled': vibrationEnabled,
        'soundUri': soundUri,
        'pausedDate': pausedDate,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        localeCode: json['localeCode'] as String? ?? 'ar',
        themeMode: json['themeMode'] as String? ?? 'system',
        use24HourTime: json['use24HourTime'] as bool? ?? true,
        reminderMinutes: json['reminderMinutes'] as int? ?? 0,
        alarmVolume: (json['alarmVolume'] as num?)?.toDouble() ?? 1,
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        soundUri: json['soundUri'] as String? ?? '',
        pausedDate: json['pausedDate'] as String? ?? '',
      );
}
