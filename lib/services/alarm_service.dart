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
  }) => _channel.invokeMethod<void>('syncPlan', {
    'bells': bells.map((bell) => bell.toJson()).toList(),
    'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
    'activeScheduleId': activeScheduleId,
    'settings': settings.toJson(),
  });

  Future<Map<String, Object?>> getReadiness() async =>
      (await _channel.invokeMapMethod<String, Object?>('getReadiness')) ?? {};

  Future<bool> isBellRinging() async =>
      await _channel.invokeMethod<bool>('isBellRinging') ?? false;

  Future<void> stopBell() => _channel.invokeMethod<void>('stopBell');

  Future<void> repairPermission(String permission) => _channel
      .invokeMethod<void>('repairPermission', {'permission': permission});

  Future<Map<String, Object?>?> chooseSystemSound() =>
      _channel.invokeMapMethod<String, Object?>('chooseSystemSound');

  Future<Map<String, Object?>?> copySoundFile({
    required String path,
    required String name,
  }) => _channel.invokeMapMethod<String, Object?>('copySoundFile', {
    'path': path,
    'name': name,
  });
}
