import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/lesson.dart';
import '../models/schedule.dart';

/// مستودع يخفي Hive ويحفظ JSON بصيغة مناسبة للنسخ والاستيراد.
class ScheduleRepository {
  ScheduleRepository._(this._box);

  static const _boxName = 'school_bell';
  static const _schedulesKey = 'schedules';
  static const _settingsKey = 'settings';
  static const _readinessShownKey = 'readinessShown';
  static const _activeScheduleKey = 'activeScheduleId';

  final Box<String> _box;

  static Future<ScheduleRepository> initialize() async {
    await Hive.initFlutter();
    return ScheduleRepository._(await Hive.openBox<String>(_boxName));
  }

  Future<List<Schedule>> loadSchedules() async {
    final value = _box.get(_schedulesKey);
    if (value == null) return [_defaultSchedule()];
    final decoded = jsonDecode(value) as List<Object?>;
    return decoded
        .map((item) => Schedule.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }

  Future<void> saveSchedules(List<Schedule> schedules) async {
    await _box.put(
      _schedulesKey,
      jsonEncode(schedules.map((schedule) => schedule.toJson()).toList()),
    );
  }

  Future<String?> loadActiveScheduleId() async =>
      _box.get(_activeScheduleKey);

  Future<void> saveActiveScheduleId(String id) async =>
      _box.put(_activeScheduleKey, id);

  Future<AppSettings> loadSettings() async {
    final value = _box.get(_settingsKey);
    if (value == null) return const AppSettings();
    return AppSettings.fromJson(
      jsonDecode(value) as Map<String, Object?>,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<bool> claimFirstReadinessScreen() async {
    if (_box.get(_readinessShownKey) == 'true') return false;
    await _box.put(_readinessShownKey, 'true');
    return true;
  }

  static Schedule _defaultSchedule() => Schedule(
        id: 'default',
        name: 'الجدول العادي',
        activeWeekdays: const [7, 1, 2, 3, 4],
        lessons: List.generate(
          7,
          (index) => Lesson(
            id: 'lesson_${index + 1}',
            name: 'الحصة ${_arabicNumber(index + 1)}',
            startMinute: 8 * 60 + 30 + index * 45,
            durationMinutes: 40,
            breakAfterMinutes: 5,
            startMode: index == 0 ? StartMode.manual : StartMode.auto,
          ),
        ),
      );

  static String _arabicNumber(int number) {
    const numbers = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة'];
    return numbers[number - 1];
  }
}
