import 'lesson.dart';

class Schedule {
  Schedule({
    required this.id,
    required this.name,
    required List<Lesson> lessons,
    List<int> activeWeekdays = const [7, 1, 2, 3, 4],
  })  : lessons = List.unmodifiable(lessons),
        activeWeekdays = List.unmodifiable(activeWeekdays);

  final String id;
  final String name;
  final List<Lesson> lessons;
  /// DateTime weekday values (Monday=1 ... Sunday=7).
  final List<int> activeWeekdays;

  Schedule copyWith({
    String? id,
    String? name,
    List<Lesson>? lessons,
    List<int>? activeWeekdays,
  }) =>
      Schedule(
        id: id ?? this.id,
        name: name ?? this.name,
        lessons: List.unmodifiable(lessons ?? this.lessons),
        activeWeekdays:
            List.unmodifiable(activeWeekdays ?? this.activeWeekdays),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
        'activeWeekdays': activeWeekdays,
      };

  factory Schedule.fromJson(Map<String, Object?> json) => Schedule(
        id: json['id']! as String,
        name: json['name']! as String,
        lessons: (json['lessons']! as List<Object?>)
            .map((item) => Lesson.fromJson(item! as Map<String, Object?>))
            .toList(growable: false),
        activeWeekdays: (json['activeWeekdays'] as List<Object?>?)
                ?.map((value) => value! as int)
                .toList(growable: false) ??
            const [7, 1, 2, 3, 4],
      );
}
