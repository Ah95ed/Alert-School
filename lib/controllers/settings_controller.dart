import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/alarm_service.dart';
import 'schedule_controller.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._scheduleController, this._alarmService);

  final ScheduleController _scheduleController;
  final AlarmService _alarmService;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> initialize() async {
    _settings = _scheduleController.settings;
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    await _scheduleController.updateSettings(settings);
    notifyListeners();
  }

  Future<void> chooseSound() async {
    final uri = await _alarmService.pickSound();
    if (uri == null) return;
    await update(_settings.copyWith(soundUri: uri));
  }

  Future<void> testBell() => _alarmService.playTestBell();

  Future<void> testBellInOneMinute() => _alarmService.scheduleTestBell();

  Future<void> pauseToday() async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await update(_settings.copyWith(pausedDate: date));
  }
}
