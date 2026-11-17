import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../widgets/action_error.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('sound')),
            subtitle: Text(
              settings.soundName.isEmpty
                  ? context.tr('systemAlarm')
                  : settings.soundName,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseSound(context, controller),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('ringDuration')),
            trailing: DropdownButton<int>(
              value: settings.ringDurationSeconds,
              items: [5, 10, 15, 20, 30]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds ${context.tr('seconds')}'),
                    ),
                  )
                  .toList(),
              onChanged: (seconds) {
                if (seconds == null) return;
                runUiAction(
                  context,
                  () => controller.update(
                    settings.copyWith(ringDurationSeconds: seconds),
                  ),
                );
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('vibration')),
            value: settings.vibrationEnabled,
            onChanged: (value) => runUiAction(
              context,
              () =>
                  controller.update(settings.copyWith(vibrationEnabled: value)),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('clock')),
            trailing: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(context.tr('clock24'))),
                ButtonSegment(value: false, label: Text(context.tr('clock12'))),
              ],
              selected: {settings.use24HourTime},
              onSelectionChanged: (value) => runUiAction(
                context,
                () => controller.update(
                  settings.copyWith(use24HourTime: value.first),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseSound(
    BuildContext context,
    SettingsController controller,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(context.tr('phoneFiles')),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(context.tr('systemTones')),
              onTap: () => Navigator.pop(context, 'system'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    await runUiAction(
      context,
      choice == 'file'
          ? controller.chooseSoundFile
          : controller.chooseSystemSound,
    );
  }
}
