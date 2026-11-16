import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/permissions_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../core/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'readiness_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _checkedFirstRun = false;

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
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionsController>().refresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedFirstRun) return;
    _checkedFirstRun = true;
    final schedule = context.read<ScheduleController>();
    final permissions = context.read<PermissionsController>();
    _selectedIndex = schedule.isFirstRun ? 3 : 0;
    permissions.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('home'),
      context.tr('schedule'),
      context.tr('settings'),
      context.tr('readiness'),
    ];
    const pages = [
      HomeScreen(),
      ScheduleScreen(),
      SettingsScreen(),
      ReadinessScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex]), centerTitle: true),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.tr('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule),
            label: context.tr('schedule'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune),
            label: context.tr('settings'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.health_and_safety_outlined),
            selectedIcon: const Icon(Icons.health_and_safety),
            label: context.tr('readiness'),
          ),
        ],
      ),
    );
  }
}
