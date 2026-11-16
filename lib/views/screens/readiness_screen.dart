import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/permissions_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../widgets/action_error.dart';

class ReadinessScreen extends StatelessWidget {
  const ReadinessScreen({super.key});

  static const _checks = [
    ('notifications', 'notificationPermission'),
    ('exactAlarms', 'exactAlarmPermission'),
    ('battery', 'batteryPermission'),
    ('autostart', 'autostart'),
    ('alarmVolume', 'alarmVolume'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PermissionsController>();
    final status = controller.readiness;
    if (!controller.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${context.tr('deviceManufacturer')}: '
            '${status['manufacturer'] ?? 'Android'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ..._checks.map((check) {
            final okay = status[check.$1] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  okay ? Icons.check_circle : Icons.cancel,
                  color: okay
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(context.tr(check.$2)),
                subtitle: Text(
                  okay ? context.tr('ready') : context.tr('notReady'),
                ),
                trailing: okay
                    ? null
                    : Wrap(
                        spacing: 4,
                        children: [
                          if (check.$1 == 'autostart')
                            TextButton(
                              onPressed: () => runUiAction(
                                context,
                                controller.confirmAutostartConfigured,
                              ),
                              child: Text(context.tr('confirm')),
                            ),
                          TextButton(
                            onPressed: () => runUiAction(
                              context,
                              () => controller.repair(check.$1),
                            ),
                            child: Text(context.tr('fix')),
                          ),
                        ],
                      ),
              ),
            );
          }),
          if (status['instructions'] is String)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('manufacturerHelp'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(status['instructions']! as String),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => runUiAction(context, controller.scheduleTestBell),
            icon: const Icon(Icons.timer),
            label: Text(context.tr('testInMinute')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('readiness')),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('readyDisclaimer'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
