import 'dart:async';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/permissions_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/time_format.dart';
import '../../models/bell.dart';
import '../../models/lesson.dart';
import '../widgets/action_error.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        unawaited(context.read<ScheduleController>().refreshBellState());
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleController>();
    final settingsController = context.watch<SettingsController>();
    final permissions = context.watch<PermissionsController>();
    final settings = settingsController.settings;
    final schedule = controller.activeSchedule;
    final now = DateTime.now();
    final upcoming = controller.todayBells
        .where((bell) => bell.timestamp.isAfter(now))
        .toList();
    final nextBell = upcoming.isEmpty ? null : upcoming.first;
    final paused = settings.pausedDate == _dateKey(now);
    final missingPermission = _missingPermission(permissions.readiness);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('appTitle')),
        actions: [
          IconButton(
            tooltip: context.tr('settings'),
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => runUiAction(context, controller.addLesson),
        icon: const Icon(Icons.add),
        label: Text(context.tr('addLesson')),
      ),
      body: Column(
        children: [
          if (controller.isBellRinging)
            _NoticeStrip(
              text: context.tr('stopBell'),
              icon: Icons.notifications_active_outlined,
              onTap: () => runUiAction(context, controller.stopBell),
              trailing: TextButton(
                onPressed: () => runUiAction(context, controller.stopBell),
                child: Text(context.tr('stopBell')),
              ),
            ),
          if (missingPermission != null)
            _NoticeStrip(
              text: context.tr('tapToFix'),
              icon: Icons.notifications_none,
              onTap: () => runUiAction(
                context,
                () => permissions.repair(missingPermission),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 96.h),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    nextBell == null
                        ? context.tr('noUpcoming')
                        : '${context.tr('nextBell')}: '
                              '${_time(nextBell.timestamp, settings.use24HourTime)} '
                              '(${_bellDescription(context, nextBell)})',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    title: Text(context.tr('holidayToday')),
                    value: paused,
                    onChanged: (value) => runUiAction(
                      context,
                      () => settingsController.setHolidayToday(value),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 5.w,
                  runSpacing: 4.h,
                  alignment: WrapAlignment.center,
                  children: const [
                    6,
                    7,
                    1,
                    2,
                    3,
                    4,
                    5,
                  ].map((weekday) => _WeekdayButton(weekday: weekday)).toList(),
                ),
                SizedBox(height: 8.h),
                if (schedule.lessons.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(context.tr('noLessons')),
                    ),
                  )
                else
                  ...schedule.lessons.map((lesson) {
                    final start =
                        controller.previewStartTimes[lesson.id] ??
                        DateTime(
                          now.year,
                          now.month,
                          now.day,
                        ).add(Duration(minutes: lesson.startMinute));
                    final end = start.add(
                      Duration(minutes: lesson.durationMinutes),
                    );
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        onTap: () => _editLesson(context, lesson, start),
                        title: Text(
                          '${lesson.name}   '
                          '${_time(start, settings.use24HourTime)}'
                          ' ← ${_time(end, settings.use24HourTime)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${context.tr('breakShort')} '
                          '${lesson.breakAfterMinutes} ${context.tr('minutesShort')}',
                        ),
                        trailing: Switch(
                          value: lesson.enabled,
                          onChanged: (enabled) => runUiAction(
                            context,
                            () => controller.updateLesson(
                              lesson.copyWith(enabled: enabled),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _missingPermission(Map<String, Object?> readiness) {
    for (final permission in ['notifications', 'exactAlarms', 'battery']) {
      if (readiness[permission] != true) return permission;
    }
    return null;
  }

  String _time(DateTime date, bool use24Hour) =>
      formatDateTime(date, use24Hour: use24Hour);

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _bellDescription(BuildContext context, Bell bell) {
    final type = bell.type == BellType.end
        ? context.tr('endBell')
        : context.tr('startBell');
    final lessonNumber = bell.lessonName.replaceFirst('الحصة ', '');
    return '$type ${context.tr('lesson')} $lessonNumber';
  }

  Future<void> _editLesson(
    BuildContext context,
    Lesson lesson,
    DateTime previewStart,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LessonEditor(lesson: lesson, previewStart: previewStart),
  );
}

class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({required this.weekday});

  final int weekday;

  @override
  Widget build(BuildContext context) {
    final scheduleController = context.watch<ScheduleController>();
    final schedule = scheduleController.activeSchedule;
    final selected = schedule.activeWeekdays.contains(weekday);
    return FilterChip(
      visualDensity: VisualDensity.compact,
      label: Text(context.tr('weekday$weekday')),
      selected: selected,
      onSelected: (value) {
        final days = [...schedule.activeWeekdays];
        value ? days.add(weekday) : days.remove(weekday);
        runUiAction(context, () => scheduleController.updateWeekdays(days));
      },
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({
    required this.text,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon),
      title: Text(text),
      trailing: trailing,
    ),
  );
}

class _LessonEditor extends StatefulWidget {
  const _LessonEditor({required this.lesson, required this.previewStart});

  final Lesson lesson;
  final DateTime previewStart;

  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _duration = TextEditingController(
    text: '${widget.lesson.durationMinutes}',
  );
  late final _break = TextEditingController(
    text: '${widget.lesson.breakAfterMinutes}',
  );
  late int _startMinute =
      widget.previewStart.hour * 60 + widget.previewStart.minute;
  bool _startTimeChanged = false;
  bool _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    _break.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.viewInsetsOf(context).bottom + 16.h,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.tr('startTime')),
                subtitle: Text(
                  formatMinuteOfDay(
                    _startMinute,
                    use24Hour: settings.use24HourTime,
                    amLabel: context.tr('am'),
                    pmLabel: context.tr('pm'),
                  ),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _chooseTime,
              ),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('duration')),
                validator: _validateDuration,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _break,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('break')),
                validator: _validateBreak,
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.tr('delete')),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('cancel')),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(context.tr('save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateDuration(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 1 || number > 1440 ? '1–1440' : null;
  }

  String? _validateBreak(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 || number > 1440 ? '0–1440' : null;
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinute ~/ 60 % 24,
        minute: _startMinute % 60,
      ),
    );
    if (time != null) {
      setState(() {
        _startMinute = time.hour * 60 + time.minute;
        _startTimeChanged = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final controller = context.read<ScheduleController>();
    try {
      await controller.updateLesson(
        widget.lesson.copyWith(
          startMinute: _startMinute,
          durationMinutes: int.parse(_duration.text),
          breakAfterMinutes: int.parse(_break.text),
          startMode: _startTimeChanged
              ? StartMode.manual
              : widget.lesson.startMode,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('operationFailed')}: $error')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    try {
      await context.read<ScheduleController>().deleteLesson(widget.lesson.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('operationFailed')}: $error')),
      );
    }
  }
}
