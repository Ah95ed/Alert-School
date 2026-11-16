enum StartMode { auto, manual }

class Lesson {
  const Lesson({
    required this.id,
    required this.name,
    required this.startMinute,
    required this.durationMinutes,
    required this.breakAfterMinutes,
    this.enabled = true,
    this.bellOnStart = true,
    this.bellOnEnd = true,
    this.startMode = StartMode.auto,
  });

  final String id;
  final String name;
  /// Minutes after midnight; kept independent of the current date.
  final int startMinute;
  final int durationMinutes;
  final int breakAfterMinutes;
  final bool enabled;
  final bool bellOnStart;
  final bool bellOnEnd;
  final StartMode startMode;

  Lesson copyWith({
    String? id,
    String? name,
    int? startMinute,
    int? durationMinutes,
    int? breakAfterMinutes,
    bool? enabled,
    bool? bellOnStart,
    bool? bellOnEnd,
    StartMode? startMode,
  }) =>
      Lesson(
        id: id ?? this.id,
        name: name ?? this.name,
        startMinute: startMinute ?? this.startMinute,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        breakAfterMinutes: breakAfterMinutes ?? this.breakAfterMinutes,
        enabled: enabled ?? this.enabled,
        bellOnStart: bellOnStart ?? this.bellOnStart,
        bellOnEnd: bellOnEnd ?? this.bellOnEnd,
        startMode: startMode ?? this.startMode,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'startMinute': startMinute,
        'durationMinutes': durationMinutes,
        'breakAfterMinutes': breakAfterMinutes,
        'enabled': enabled,
        'bellOnStart': bellOnStart,
        'bellOnEnd': bellOnEnd,
        'startMode': startMode.name,
      };

  factory Lesson.fromJson(Map<String, Object?> json) {
    final modeName = json['startMode'] as String?;
    final mode = modeName == null
        ? StartMode.manual
        : StartMode.values.firstWhere(
            (value) => value.name == modeName,
            orElse: () => throw FormatException('Unknown lesson start mode: $modeName'),
          );
    return Lesson(
      id: json['id']! as String,
      name: json['name']! as String,
      startMinute: json['startMinute']! as int,
      durationMinutes: json['durationMinutes']! as int,
      breakAfterMinutes: json['breakAfterMinutes']! as int,
      enabled: json['enabled'] as bool? ?? true,
      bellOnStart: json['bellOnStart'] as bool? ?? true,
      bellOnEnd: json['bellOnEnd'] as bool? ?? true,
      startMode: mode,
    );
  }
}
