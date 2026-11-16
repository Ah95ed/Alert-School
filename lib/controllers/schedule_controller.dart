import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/bell.dart';
import '../models/lesson.dart';
import '../models/schedule.dart';
import '../repositories/schedule_repository.dart';
import '../services/alarm_service.dart';
import '../services/bell_schedule_calculator.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(
    this._repository,
    this._alarmService, {
    this._calculator = const BellScheduleCalculator(
      strategy: AutoAndManualBellTimeStrategy(),
    ),
  });

  final ScheduleRepository _repository;
  final AlarmService _alarmService;
  final BellScheduleCalculator _calculator;
  List<Schedule> _schedules = const [];
  String _activeScheduleId = '';
  AppSettings _settings = const AppSettings();
  List<Bell> _bells = const [];
  bool _isReady = false;
  bool _isFirstRun = false;

  List<Schedule> get schedules => _schedules;
  Schedule get activeSchedule => _schedules.firstWhere(
    (schedule) => schedule.id == _activeScheduleId,
    orElse: () => _schedules.first,
  );
  List<Bell> get bells => _bells;
  bool get isReady => _isReady;
  bool get isFirstRun => _isFirstRun;
  AppSettings get settings => _settings;
  List<Bell> get todayBells {
    final now = DateTime.now();
    return _calculator.calculate(
      schedule: activeSchedule,
      from: DateTime(now.year, now.month, now.day),
      days: 1,
      settings: _settings,
    );
  }

  String? get currentLessonName {
    final now = DateTime.now();
    if (!activeSchedule.activeWeekdays.contains(now.weekday) ||
        _settings.pausedDate == _dateKey(now)) {
      return null;
    }
    final starts = const AutoAndManualBellTimeStrategy().calculateStarts(
      activeSchedule,
      now,
    );
    final lessons = activeSchedule.lessons.where((lesson) => lesson.enabled);
    final enabledLessons = lessons.toList(growable: false);
    for (var index = 0; index < starts.length; index++) {
      final end = starts[index].add(
        Duration(minutes: enabledLessons[index].durationMinutes),
      );
      if (!now.isBefore(starts[index]) && now.isBefore(end)) {
        return enabledLessons[index].name;
      }
    }
    return null;
  }

  Map<String, DateTime> get previewStartTimes {
    final starts = const AutoAndManualBellTimeStrategy().calculateStarts(
      activeSchedule,
      DateTime.now(),
    );
    final enabled = activeSchedule.lessons.where((lesson) => lesson.enabled);
    return {
      for (var index = 0; index < starts.length; index++)
        enabled.elementAt(index).id: starts[index],
    };
  }

  Future<void> initialize() async {
    _schedules = await _repository.loadSchedules();
    _settings = await _repository.loadSettings();
    _isFirstRun = await _repository.claimFirstReadinessScreen();
    final savedScheduleId = await _repository.loadActiveScheduleId();
    _activeScheduleId =
        _schedules.any((schedule) => schedule.id == savedScheduleId)
        ? savedScheduleId!
        : _schedules.first.id;
    await rebuildPlan();
    _isReady = true;
    notifyListeners();
  }

  Future<void> rebuildPlan({AppSettings? settings}) async {
    if (_schedules.isEmpty) return;
    if (settings != null) _settings = settings;
    _bells = _calculator.calculate(
      schedule: activeSchedule,
      from: DateTime.now(),
      settings: _settings,
    );
    await _alarmService.syncPlan(
      bells: _bells,
      schedules: _schedules,
      activeScheduleId: _activeScheduleId,
      settings: _settings,
    );
    notifyListeners();
  }

  Future<void> _saveAndRebuild() async {
    await _repository.saveSchedules(_schedules);
    await _repository.saveActiveScheduleId(_activeScheduleId);
    await rebuildPlan();
  }

  Future<void> updateLesson(Lesson lesson) async {
    if (!activeSchedule.lessons.any((current) => current.id == lesson.id)) {
      throw ArgumentError.value(lesson.id, 'lesson.id', 'Lesson does not exist');
    }
    final schedule = activeSchedule.copyWith(
      lessons: activeSchedule.lessons
          .map((current) => current.id == lesson.id ? lesson : current)
          .toList(),
    );
    _replaceSchedule(schedule);
    await _saveAndRebuild();
  }

  Future<void> addLesson() async {
    final index = activeSchedule.lessons.length + 1;
    final last = activeSchedule.lessons.isEmpty
        ? null
        : activeSchedule.lessons.last;
    final lesson = Lesson(
      id: 'lesson_${DateTime.now().microsecondsSinceEpoch}',
      name: 'الحصة ${_arabicOrdinal(index)}',
      startMinute: last == null
          ? 8 * 60 + 30
          : last.startMinute + last.durationMinutes + last.breakAfterMinutes,
      durationMinutes: 40,
      breakAfterMinutes: 5,
      startMode: last == null ? StartMode.manual : StartMode.auto,
    );
    _replaceSchedule(
      activeSchedule.copyWith(lessons: [...activeSchedule.lessons, lesson]),
    );
    await _saveAndRebuild();
  }

  Future<void> deleteLesson(String lessonId) async {
    if (!activeSchedule.lessons.any((lesson) => lesson.id == lessonId)) {
      throw ArgumentError.value(lessonId, 'lessonId', 'Lesson does not exist');
    }
    _replaceSchedule(
      activeSchedule.copyWith(
        lessons: activeSchedule.lessons
            .where((lesson) => lesson.id != lessonId)
            .toList(),
      ),
    );
    await _saveAndRebuild();
  }

  Future<void> reorderLessons(int oldIndex, int newIndex) async {
    final lessons = [...activeSchedule.lessons];
    final item = lessons.removeAt(oldIndex);
    lessons.insert(newIndex, item);
    _replaceSchedule(activeSchedule.copyWith(lessons: lessons));
    await _saveAndRebuild();
  }

  Future<void> updateWeekdays(List<int> weekdays) async {
    _replaceSchedule(activeSchedule.copyWith(activeWeekdays: weekdays));
    await _saveAndRebuild();
  }

  Future<void> addSchedule(String name) async {
    final created = Schedule(
      id: 'schedule_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      lessons: activeSchedule.lessons,
      activeWeekdays: activeSchedule.activeWeekdays,
    );
    _schedules = [..._schedules, created];
    _activeScheduleId = created.id;
    await _saveAndRebuild();
  }

  Future<void> activateSchedule(String id) async {
    if (!_schedules.any((schedule) => schedule.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown schedule');
    }
    _activeScheduleId = id;
    await _repository.saveActiveScheduleId(id);
    await rebuildPlan();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _repository.saveSettings(settings);
    await rebuildPlan();
  }

  Future<void> exportSchedules() async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'schedules': _schedules.map((schedule) => schedule.toJson()).toList(),
    });
    await _alarmService.exportScheduleFile(json);
  }

  Future<void> importSchedules() async {
    final contents = await _alarmService.importScheduleFile();
    if (contents == null) return;
    final root = jsonDecode(contents) as Map<String, Object?>;
    final imported = (root['schedules']! as List<Object?>)
        .map((item) => Schedule.fromJson(item! as Map<String, Object?>))
        .toList();
    if (imported.isEmpty) {
      throw const FormatException('لا يحتوي الملف على جداول');
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final cloned = imported.map((schedule) {
      final newId = '${schedule.id}_$suffix';
      return schedule.copyWith(
        id: newId,
        lessons: schedule.lessons
            .map((lesson) => lesson.copyWith(id: '${lesson.id}_$suffix'))
            .toList(),
      );
    });
    _schedules = [..._schedules, ...cloned];
    await _saveAndRebuild();
  }

  void _replaceSchedule(Schedule schedule) {
    _schedules = _schedules
        .map((current) => current.id == schedule.id ? schedule : current)
        .toList(growable: false);
  }

  String _arabicOrdinal(int index) {
    const ordinals = [
      'الأولى',
      'الثانية',
      'الثالثة',
      'الرابعة',
      'الخامسة',
      'السادسة',
      'السابعة',
      'الثامنة',
      'التاسعة',
      'العاشرة',
    ];
    return index <= ordinals.length ? ordinals[index - 1] : '$index';
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
