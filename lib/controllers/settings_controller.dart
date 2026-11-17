import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<void> chooseSoundFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a'],
    );
    if (files.isEmpty) return;
    final file = files.single;
    final path = file.path;
    if (path == null) {
      throw StateError('The selected audio file has no readable local path.');
    }
    final sound = await _alarmService.copySoundFile(
      path: path,
      name: file.name,
    );
    if (sound == null) {
      throw StateError('The selected audio file could not be saved.');
    }
    await update(
      _settings.copyWith(
        soundUri: sound['uri']! as String,
        soundName: sound['name']! as String,
      ),
    );
  }

  Future<void> chooseSystemSound() async {
    final sound = await _alarmService.chooseSystemSound();
    if (sound == null) return;
    await update(
      _settings.copyWith(
        soundUri: sound['uri']! as String,
        soundName: sound['name']! as String,
      ),
    );
  }

  Future<void> setHolidayToday(bool value) async {
    final now = DateTime.now();
    final date = value
        ? '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}'
        : '';
    await update(_settings.copyWith(pausedDate: date));
  }
}
