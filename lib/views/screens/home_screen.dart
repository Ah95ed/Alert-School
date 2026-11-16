import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/time_format.dart';
import '../../models/bell.dart';
import '../widgets/action_error.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleController>();
    final settings = context.watch<SettingsController>().settings;
    final now = DateTime.now();
    final today = schedule.todayBells;
    final upcoming = today
        .where((bell) => bell.timestamp.isAfter(now))
        .toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final isPaused =
        settings.pausedDate ==
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('currentLesson'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8.h),
                Text(
                  schedule.currentLessonName ?? context.tr('noCurrentLesson'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 20.h),
                Text(
                  context.tr('nextBell'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 6.h),
                if (next == null)
                  Text(context.tr('noUpcoming'))
                else
                  Row(
                    children: [
                      Icon(
                        _iconFor(next.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '${next.lessonName} · ${_bellLabel(context, next)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        formatDateTime(
                          next.timestamp,
                          use24Hour: settings.use24HourTime,
                          amLabel: context.tr('am'),
                          pmLabel: context.tr('pm'),
                        ),
                      ),
                    ],
                  ),
                if (next != null) ...[
                  SizedBox(height: 8.h),
                  Text(_countdown(next.timestamp.difference(now))),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        FilledButton.tonalIcon(
          onPressed: isPaused
              ? null
              : () => runUiAction(
                  context,
                  context.read<SettingsController>().pauseToday,
                ),
          icon: const Icon(Icons.notifications_off_outlined),
          label: Text(
            isPaused ? context.tr('paused') : context.tr('pauseToday'),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          context.tr('todayBells'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10.h),
        if (today.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(18.w),
              child: Text(context.tr('noUpcoming')),
            ),
          )
        else
          ...today.map(
            (bell) => Card(
              margin: EdgeInsets.only(bottom: 8.h),
              child: ListTile(
                leading: Icon(
                  _iconFor(bell.type),
                  color: bell.timestamp.isBefore(now)
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  '${bell.lessonName} · ${_bellLabel(context, bell)}',
                ),
                subtitle: Text(
                  formatDateTime(
                    bell.timestamp,
                    use24Hour: settings.use24HourTime,
                    amLabel: context.tr('am'),
                    pmLabel: context.tr('pm'),
                  ),
                ),
                trailing: Text(
                  bell.timestamp.isBefore(now) ? '✓' : context.tr('scheduled'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(BellType type) => switch (type) {
    BellType.start => Icons.login,
    BellType.end => Icons.logout,
    BellType.reminder => Icons.notifications_active_outlined,
  };

  String _bellLabel(BuildContext context, Bell bell) => switch (bell.type) {
    BellType.start => context.tr('startBell'),
    BellType.end => context.tr('endBell'),
    BellType.reminder => context.tr('reminderBell'),
  };

  String _countdown(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 1 << 31);
    final hours = totalSeconds ~/ 3600;
    final minutes = totalSeconds ~/ 60 % 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
