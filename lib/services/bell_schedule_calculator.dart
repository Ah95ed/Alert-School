import '../models/app_settings.dart';
import '../models/bell.dart';
import '../models/lesson.dart';
import '../models/schedule.dart';

abstract interface class BellTimeStrategy {
  List<DateTime> calculateStarts(Schedule schedule, DateTime date);
}

/// استراتيجية تفصل تسلسل الحصص التلقائي عن أوقات الحصص اليدوية.
class AutoAndManualBellTimeStrategy implements BellTimeStrategy {
  const AutoAndManualBellTimeStrategy();

  @override
  List<DateTime> calculateStarts(Schedule schedule, DateTime date) {
    final starts = <DateTime>[];
    DateTime? previousStart;
    Lesson? previousLesson;

    for (final lesson in schedule.lessons) {
      if (!lesson.enabled) continue;

      final DateTime start;
      if (lesson.startMode == StartMode.auto &&
          previousStart != null &&
          previousLesson != null) {
        start = previousStart
            .add(Duration(minutes: previousLesson.durationMinutes))
            .add(Duration(minutes: previousLesson.breakAfterMinutes));
      } else {
        final manualStart = DateTime(
          date.year,
          date.month,
          date.day,
        ).add(Duration(minutes: lesson.startMinute));
        start = previousStart != null && !manualStart.isAfter(previousStart)
            ? manualStart.add(const Duration(days: 1))
            : manualStart;
      }

      starts.add(start);
      previousStart = start;
      previousLesson = lesson;
    }
    return List.unmodifiable(starts);
  }
}

/// مصنع موحد لإنشاء هوية الجرس وبياناته.
class BellFactory {
  const BellFactory();

  Bell create({
    required DateTime time,
    required BellType type,
    required Lesson lesson,
  }) {
    final millis = time.millisecondsSinceEpoch;
    final id = '${lesson.id}_${type.name}_$millis';
    return Bell(
      timestampMillis: millis,
      type: type,
      lessonName: lesson.name,
      lessonId: lesson.id,
      id: id,
    );
  }
}

class BellScheduleCalculator {
  const BellScheduleCalculator({
    required this.strategy,
    this.factory = const BellFactory(),
  });

  final BellTimeStrategy strategy;
  final BellFactory factory;

  List<Bell> calculate({
    required Schedule schedule,
    required DateTime from,
    int days = 7,
    AppSettings settings = const AppSettings(),
  }) {
    final bells = <Bell>[];
    final today = DateTime(from.year, from.month, from.day);
    for (var offset = 0; offset < days; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      if (!schedule.activeWeekdays.contains(date.weekday) ||
          settings.pausedDate == _dateKey(date)) {
        continue;
      }

      final enabledLessons =
          schedule.lessons.where((lesson) => lesson.enabled).toList();
      final starts = strategy.calculateStarts(schedule, date);
      for (var index = 0; index < starts.length; index++) {
        final lesson = enabledLessons[index];
        final start = starts[index];
        if (lesson.bellOnStart) {
          _addIfFuture(
            bells,
            factory.create(time: start, type: BellType.start, lesson: lesson),
            from,
          );
        }
        if (lesson.bellOnEnd) {
          _addIfFuture(
            bells,
            factory.create(
              time: start.add(Duration(minutes: lesson.durationMinutes)),
              type: BellType.end,
              lesson: lesson,
            ),
            from,
          );
        }
      }
    }
    bells.sort((a, b) => a.timestampMillis.compareTo(b.timestampMillis));
    return List.unmodifiable(bells);
  }

  static void _addIfFuture(List<Bell> bells, Bell bell, DateTime from) {
    if (bell.timestamp.isAfter(from)) bells.add(bell);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
