import 'package:alert_school/models/app_settings.dart';
import 'package:alert_school/models/bell.dart';
import 'package:alert_school/models/lesson.dart';
import 'package:alert_school/models/schedule.dart';
import 'package:alert_school/services/bell_schedule_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = BellScheduleCalculator(
    strategy: AutoAndManualBellTimeStrategy(),
  );
  final monday = DateTime(2026, 11, 16);

  Lesson lesson(
    String id, {
    int start = 8 * 60 + 30,
    int duration = 40,
    int gap = 5,
    bool enabled = true,
    StartMode mode = StartMode.auto,
  }) => Lesson(
    id: id,
    name: id,
    startMinute: start,
    durationMinutes: duration,
    breakAfterMinutes: gap,
    enabled: enabled,
    startMode: mode,
  );

  Schedule schedule(List<Lesson> lessons) => Schedule(
    id: 'weekday',
    name: 'weekday',
    lessons: lessons,
    activeWeekdays: const [1],
  );

  test('auto starts follow prior duration and break, manual starts anchor', () {
    final result = calculator.calculate(
      schedule: schedule([
        lesson('one', mode: StartMode.manual),
        lesson('two'),
        lesson('three', start: 10 * 60, mode: StartMode.manual),
      ]),
      from: DateTime(2026, 11, 16),
      days: 1,
    );

    expect(
      result
          .where((bell) => bell.type == BellType.start)
          .map((bell) => bell.timestamp.hour * 60 + bell.timestamp.minute),
      [510, 555, 600],
    );
  });

  test('changing a duration recalculates following automatic lessons', () {
    final before = schedule([
      lesson('one', mode: StartMode.manual),
      lesson('two'),
    ]);
    final after = before.copyWith(
      lessons: [
        before.lessons.first.copyWith(durationMinutes: 50),
        before.lessons.last,
      ],
    );
    List<DateTime> starts(Schedule value) => calculator
        .calculate(schedule: value, from: monday, days: 1)
        .where((bell) => bell.type == BellType.start)
        .map((bell) => bell.timestamp)
        .toList();

    expect(starts(before).last, DateTime(2026, 11, 16, 9, 15));
    expect(starts(after).last, DateTime(2026, 11, 16, 9, 25));
  });

  test('disabled lessons do not ring and are excluded from auto chain', () {
    final result = calculator.calculate(
      schedule: schedule([
        lesson('one', mode: StartMode.manual),
        lesson('disabled', enabled: false),
        lesson('three'),
      ]),
      from: monday,
      days: 1,
    );
    expect(result.every((bell) => bell.lessonId != 'disabled'), isTrue);
    expect(
      result
          .firstWhere(
            (bell) => bell.type == BellType.start && bell.lessonId == 'three',
          )
          .timestamp,
      DateTime(2026, 11, 16, 9, 15),
    );
  });

  test('automatic chain can continue past midnight', () {
    final result = calculator.calculate(
      schedule: schedule([
        lesson(
          'one',
          start: 23 * 60 + 30,
          duration: 40,
          gap: 5,
          mode: StartMode.manual,
        ),
        lesson('two'),
      ]),
      from: DateTime(2026, 11, 16),
      days: 1,
    );
    expect(
      result
          .firstWhere(
            (bell) => bell.type == BellType.start && bell.lessonId == 'two',
          )
          .timestamp,
      DateTime(2026, 11, 17, 0, 15),
    );
  });

  test(
    'manual earlier clock time moves to next day; pause skips all bells',
    () {
      final value = schedule([
        lesson('one', start: 23 * 60, mode: StartMode.manual),
        lesson('two', start: 30, mode: StartMode.manual),
      ]);
      final result = calculator.calculate(
        schedule: value,
        from: monday,
        days: 1,
      );
      expect(
        result
            .firstWhere(
              (bell) => bell.type == BellType.start && bell.lessonId == 'two',
            )
            .timestamp,
        DateTime(2026, 11, 17, 0, 30),
      );

      expect(
        calculator.calculate(
          schedule: value,
          from: monday,
          days: 1,
          settings: const AppSettings(pausedDate: '2026-11-16'),
        ),
        isEmpty,
      );
    },
  );
}
