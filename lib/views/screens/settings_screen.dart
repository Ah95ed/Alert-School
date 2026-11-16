import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Text(
          context.tr('language'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8.h),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
            ButtonSegment(value: 'en', label: Text(context.tr('english'))),
          ],
          selected: {settings.localeCode},
          onSelectionChanged: (value) => runUiAction(
            context,
            () => controller.update(settings.copyWith(localeCode: value.first)),
          ),
        ),
        SizedBox(height: 20.h),
        DropdownButtonFormField<String>(
          initialValue: settings.themeMode,
          decoration: InputDecoration(
            labelText: context.tr('appearance'),
            prefixIcon: const Icon(Icons.palette_outlined),
          ),
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(context.tr('system')),
            ),
            DropdownMenuItem(value: 'light', child: Text(context.tr('light'))),
            DropdownMenuItem(value: 'dark', child: Text(context.tr('dark'))),
          ],
          onChanged: (value) {
            if (value != null) {
              runUiAction(
                context,
                () => controller.update(settings.copyWith(themeMode: value)),
              );
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('clock')),
          subtitle: Text(
            settings.use24HourTime
                ? context.tr('clock24')
                : context.tr('clock12'),
          ),
          value: settings.use24HourTime,
          onChanged: (value) => runUiAction(
            context,
            () => controller.update(settings.copyWith(use24HourTime: value)),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: settings.reminderMinutes,
          decoration: InputDecoration(
            labelText: context.tr('reminder'),
            prefixIcon: const Icon(Icons.alarm_add_outlined),
          ),
          items: [
            DropdownMenuItem(value: 0, child: Text(context.tr('reminderOff'))),
            for (final minutes in [1, 2, 5, 10])
              DropdownMenuItem(
                value: minutes,
                child: Text('$minutes ${context.tr('minutes')}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              runUiAction(
                context,
                () => controller.update(
                  settings.copyWith(reminderMinutes: value),
                ),
              );
            }
          },
        ),
        SizedBox(height: 20.h),
        Text(
          context.tr('sound'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedBuiltIn(settings.soundUri),
          decoration: InputDecoration(
            labelText: context.tr('builtInSound'),
            prefixIcon: const Icon(Icons.music_note_outlined),
          ),
          items: [
            DropdownMenuItem(
              value: 'builtin:alarm',
              child: Text(context.tr('soundAlarm')),
            ),
            DropdownMenuItem(
              value: 'builtin:notification',
              child: Text(context.tr('soundNotification')),
            ),
            DropdownMenuItem(
              value: 'builtin:ringtone',
              child: Text(context.tr('soundRingtone')),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text(context.tr('customSoundSelected')),
            ),
          ],
          onChanged: (value) {
            if (value != null && value != 'custom') {
              runUiAction(
                context,
                () => controller.update(settings.copyWith(soundUri: value)),
              );
            }
          },
        ),
        OutlinedButton.icon(
          onPressed: () => runUiAction(context, controller.chooseSound),
          icon: const Icon(Icons.folder_open),
          label: Text(context.tr('chooseSound')),
        ),
        if (settings.soundUri.startsWith('content://'))
          Text(context.tr('customSoundSelected')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('volume')),
          subtitle: _VolumeSlider(
            value: settings.alarmVolume,
            onChangeEnd: (value) =>
                controller.update(settings.copyWith(alarmVolume: value)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('vibration')),
          value: settings.vibrationEnabled,
          onChanged: (value) => runUiAction(
            context,
            () => controller.update(settings.copyWith(vibrationEnabled: value)),
          ),
        ),
        SizedBox(height: 12.h),
        FilledButton.icon(
          onPressed: () => runUiAction(context, controller.testBell),
          icon: const Icon(Icons.play_arrow),
          label: Text(context.tr('testBell')),
        ),
        SizedBox(height: 8.h),
        OutlinedButton.icon(
          onPressed: () => runUiAction(context, controller.testBellInOneMinute),
          icon: const Icon(Icons.timer_outlined),
          label: Text(context.tr('testInMinute')),
        ),
      ],
    );
  }

  String _selectedBuiltIn(String uri) =>
      uri.startsWith('builtin:') ? uri : 'custom';
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.value, required this.onChangeEnd});

  final double value;
  final Future<void> Function(double value) onChangeEnd;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Slider(
    value: _value.clamp(0, 1),
    divisions: 10,
    label: '${(_value * 100).round()}%',
    onChanged: (value) => setState(() => _value = value),
    onChangeEnd: (value) =>
        runUiAction(context, () => widget.onChangeEnd(value)),
  );
}
