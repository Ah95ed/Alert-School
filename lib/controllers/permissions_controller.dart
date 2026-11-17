import 'package:flutter/foundation.dart';

import '../services/alarm_service.dart';

class PermissionsController extends ChangeNotifier {
  PermissionsController({required this._alarmService});

  final AlarmService _alarmService;
  Map<String, Object?> _readiness = const {};
  bool _loaded = false;

  Map<String, Object?> get readiness => _readiness;
  bool get loaded => _loaded;

  Future<void> refresh() async {
    _readiness = await _alarmService.getReadiness();
    _loaded = true;
    notifyListeners();
  }

  Future<void> repair(String permission) async {
    await _alarmService.repairPermission(permission);
    await refresh();
  }

}
