enum BellType { start, end }

class Bell {
  const Bell({
    required this.timestampMillis,
    required this.type,
    required this.lessonName,
    required this.lessonId,
    required this.id,
  });

  final int timestampMillis;
  final BellType type;
  final String lessonName;
  final String lessonId;
  final String id;

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMillis);

  Bell copyWith({
    int? timestampMillis,
    BellType? type,
    String? lessonName,
    String? lessonId,
    String? id,
  }) =>
      Bell(
        timestampMillis: timestampMillis ?? this.timestampMillis,
        type: type ?? this.type,
        lessonName: lessonName ?? this.lessonName,
        lessonId: lessonId ?? this.lessonId,
        id: id ?? this.id,
      );

  Map<String, Object?> toJson() => {
        'timestampMillis': timestampMillis,
        'type': type.name,
        'lessonName': lessonName,
        'lessonId': lessonId,
        'id': id,
      };

  factory Bell.fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String?;
    final type = BellType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw FormatException('Unknown bell type: $typeName'),
    );
    return Bell(
      timestampMillis: json['timestampMillis']! as int,
      type: type,
      lessonName: json['lessonName']! as String,
      lessonId: json['lessonId']! as String,
      id: json['id']! as String,
    );
  }
}
