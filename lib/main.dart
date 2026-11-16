import 'package:flutter/widgets.dart';
import 'app.dart';
import 'controllers/schedule_controller.dart';
import 'controllers/settings_controller.dart';
import 'repositories/schedule_repository.dart';
import 'services/alarm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await ScheduleRepository.initialize();
  final alarmService = AlarmService();
  final scheduleController = ScheduleController(repository, alarmService);
  await scheduleController.initialize();
  final settingsController = SettingsController(scheduleController, alarmService);
  await settingsController.initialize();
  runApp(AlertSchoolApp(
    scheduleController: scheduleController,
    settingsController: settingsController,
    alarmService: alarmService,
  ));
}
