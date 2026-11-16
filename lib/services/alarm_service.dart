import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/bell.dart';
import '../models/schedule.dart';

/// محوّل يربط واجهة Dart بمحرك المنبه الأصلي في Android.
class AlarmService {
  static const MethodChannel _channel = MethodChannel('school_bell/alarm');

  Future<void> syncPlan({
    required List<Bell> bells,
    required List<Schedule> schedules,
    required String activeScheduleId,
    required AppSettings settings,
  }) =>
      _channel.invokeMethod<void>('syncPlan', {
        'bells': bells.map((bell) => bell.toJson()).toList(),
        'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
        'activeScheduleId': activeScheduleId,
        'settings': settings.toJson(),
      });

  Future<Map<String, Object?>> getReadiness() async =>
      (await _channel.invokeMapMethod<String, Object?>('getReadiness')) ?? {};

  Future<void> repairPermission(String permission) =>
      _channel.invokeMethod<void>('repairPermission', {'permission': permission});

  Future<void> confirmAutostartConfigured() =>
      _channel.invokeMethod<void>('confirmAutostartConfigured');

  Future<void> playTestBell() =>
      _channel.invokeMethod<void>('playTestBell');

  Future<void> scheduleTestBell() =>
      _channel.invokeMethod<void>('scheduleTestBell');

  Future<String?> pickSound() =>
      _channel.invokeMethod<String>('pickSound');

  Future<String?> importScheduleFile() =>
      _channel.invokeMethod<String>('importScheduleFile');

  Future<void> exportScheduleFile(String json) =>
      _channel.invokeMethod<void>('exportScheduleFile', {'json': json});
}
