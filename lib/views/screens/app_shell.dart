import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/permissions_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../core/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  bool _startupFlowStarted = false;
  Completer<void>? _resumeCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<PermissionsController>().refresh();
    final completer = _resumeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _resumeCompleter = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startupFlowStarted) return;
    _startupFlowStarted = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestFirstRunPermissions(),
    );
  }

  Future<void> _requestFirstRunPermissions() async {
    final schedule = context.read<ScheduleController>();
    final permissionsController = context.read<PermissionsController>();
    final firstRun = await schedule.claimStartupPermissionSequence();
    if (!mounted) return;
    await permissionsController.refresh();
    if (!firstRun || !mounted) return;

    const permissions = [
      ('notifications', 'notificationPermission'),
      ('exactAlarms', 'exactAlarmPermission'),
      ('battery', 'batteryPermission'),
    ];
    for (final (permission, label) in permissions) {
      final controller = permissionsController;
      await controller.refresh();
      if (!mounted) return;
      if (controller.readiness[permission] == true) continue;
      final shouldOpen = await _showPermissionDialog(label);
      if (shouldOpen != true || !mounted) continue;
      final resume = Completer<void>();
      _resumeCompleter = resume;
      await controller.repair(permission);
      if (permission != 'notifications') {
        await resume.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () {},
        );
      }
      if (!mounted) return;
      await controller.refresh();
    }
  }

  Future<bool?> _showPermissionDialog(String label) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Text(context.tr(label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('later')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('continue')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => HomeScreen(
    onOpenSettings: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );
}
