class AppSettings {
  const AppSettings({
    this.localeCode = 'ar',
    this.themeMode = 'system',
    this.use24HourTime = true,
    this.alarmVolume = 1,
    this.vibrationEnabled = true,
    this.soundUri = '',
    this.soundName = '',
    this.ringDurationSeconds = 10,
    this.pausedDate = '',
  });

  final String localeCode;
  final String themeMode;
  final bool use24HourTime;
  final double alarmVolume;
  final bool vibrationEnabled;
  final String soundUri;
  final String soundName;
  final int ringDurationSeconds;
  final String pausedDate;

  AppSettings copyWith({
    String? localeCode,
    String? themeMode,
    bool? use24HourTime,
    double? alarmVolume,
    bool? vibrationEnabled,
    String? soundUri,
    String? soundName,
    int? ringDurationSeconds,
    String? pausedDate,
  }) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
    use24HourTime: use24HourTime ?? this.use24HourTime,
    alarmVolume: alarmVolume ?? this.alarmVolume,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    soundUri: soundUri ?? this.soundUri,
    soundName: soundName ?? this.soundName,
    ringDurationSeconds: ringDurationSeconds ?? this.ringDurationSeconds,
    pausedDate: pausedDate ?? this.pausedDate,
  );

  Map<String, Object?> toJson() => {
    'localeCode': localeCode,
    'themeMode': themeMode,
    'use24HourTime': use24HourTime,
    'alarmVolume': alarmVolume,
    'vibrationEnabled': vibrationEnabled,
    'soundUri': soundUri,
    'soundName': soundName,
    'ringDurationSeconds': ringDurationSeconds,
    'pausedDate': pausedDate,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    localeCode: json['localeCode'] as String? ?? 'ar',
    themeMode: json['themeMode'] as String? ?? 'system',
    use24HourTime: json['use24HourTime'] as bool? ?? true,
    alarmVolume: (json['alarmVolume'] as num?)?.toDouble() ?? 1,
    vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    soundUri: json['soundUri'] as String? ?? '',
    soundName: json['soundName'] as String? ?? '',
    ringDurationSeconds: json['ringDurationSeconds'] as int? ?? 10,
    pausedDate: json['pausedDate'] as String? ?? '',
  );
}
