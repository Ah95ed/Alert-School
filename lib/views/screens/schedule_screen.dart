import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/time_format.dart';
import '../../models/lesson.dart';
import '../widgets/action_error.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleController>();
    final schedule = controller.activeSchedule;
    final settings = context.watch<SettingsController>().settings;
    final previews = controller.previewStartTimes;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: schedule.id,
                  decoration: InputDecoration(
                    labelText: context.tr('schedule'),
                    prefixIcon: const Icon(Icons.calendar_month),
                  ),
                  items: controller.schedules
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      runUiAction(
                        context,
                        () => controller.activateSchedule(id),
                      );
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: context.tr('addSchedule'),
                onPressed: () => _addSchedule(context, controller),
                icon: const Icon(Icons.add_circle_outline),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => runUiAction(
                  context,
                  action == 'export'
                      ? controller.exportSchedules
                      : controller.importSchedules,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Text(context.tr('export')),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text(context.tr('import')),
                  ),
                ],
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(context.tr('days'),
                style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            children: List.generate(7, (index) {
              final weekday = index == 0 ? 7 : index;
              return FilterChip(
                label: Text(context.tr('weekday$weekday')),
                selected: schedule.activeWeekdays.contains(weekday),
                onSelected: (selected) {
                  final days = [...schedule.activeWeekdays];
                  if (selected) {
                    days.add(weekday);
                  } else {
                    days.remove(weekday);
                  }
                  runUiAction(context, () => controller.updateWeekdays(days));
                },
              );
            }),
          ),
        ),
        const Divider(height: 12),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: schedule.lessons.length,
            onReorderItem: (oldIndex, newIndex) => runUiAction(
              context,
              () => controller.reorderLessons(oldIndex, newIndex),
            ),
            itemBuilder: (context, index) {
              final lesson = schedule.lessons[index];
              final start = previews[lesson.id];
              return Card(
                key: ValueKey(lesson.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _editLesson(context, lesson),
                  leading: Switch(
                    value: lesson.enabled,
                    onChanged: (enabled) => runUiAction(
                      context,
                      () => controller.updateLesson(
                        lesson.copyWith(enabled: enabled),
                      ),
                    ),
                  ),
                  title: Text(lesson.name),
                  subtitle: Text(
                    '${context.tr('preview')}: '
                    '${start == null ? '--:--' : formatDateTime(start, use24Hour: settings.use24HourTime, amLabel: context.tr('am'), pmLabel: context.tr('pm'))}'
                    ' · ${lesson.durationMinutes} ${context.tr('minutes')}'
                    ' · ${lesson.startMode == StartMode.auto ? context.tr('auto') : context.tr('manual')}',
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => runUiAction(context, controller.addLesson),
                icon: const Icon(Icons.add),
                label: Text(context.tr('addLesson')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addSchedule(
    BuildContext context,
    ScheduleController controller,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _ScheduleNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await runUiAction(context, () => controller.addSchedule(name.trim()));
  }

  Future<void> _editLesson(BuildContext context, Lesson lesson) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _LessonEditor(lesson: lesson),
      );
}

class _ScheduleNameDialog extends StatefulWidget {
  @override
  State<_ScheduleNameDialog> createState() => _ScheduleNameDialogState();
}

class _ScheduleNameDialogState extends State<_ScheduleNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.tr('addSchedule')),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('scheduleName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(context.tr('save')),
          ),
        ],
      );
}

class _LessonEditor extends StatefulWidget {
  const _LessonEditor({required this.lesson});

  final Lesson lesson;

  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.lesson.name);
  late final _duration =
      TextEditingController(text: '${widget.lesson.durationMinutes}');
  late final _break = TextEditingController(
    text: '${widget.lesson.breakAfterMinutes}',
  );
  late int _startMinute = widget.lesson.startMinute;
  late StartMode _mode = widget.lesson.startMode;
  late bool _enabled = widget.lesson.enabled;
  late bool _bellOnStart = widget.lesson.bellOnStart;
  late bool _bellOnEnd = widget.lesson.bellOnEnd;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _break.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: context.tr('lessonName')),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '!' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('startTime')),
                subtitle: Text(formatMinuteOfDay(
                  _startMinute,
                  use24Hour: settings.use24HourTime,
                  amLabel: context.tr('am'),
                  pmLabel: context.tr('pm'),
                )),
                trailing: const Icon(Icons.access_time),
                onTap: _chooseTime,
              ),
              DropdownButtonFormField<StartMode>(
                initialValue: _mode,
                decoration: InputDecoration(labelText: context.tr('startTime')),
                items: [
                  DropdownMenuItem(
                    value: StartMode.auto,
                    child: Text(context.tr('auto')),
                  ),
                  DropdownMenuItem(
                    value: StartMode.manual,
                    child: Text(context.tr('manual')),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) setState(() => _mode = mode);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('duration')),
                validator: _validateDuration,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _break,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('break')),
                validator: _validateMinutes,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('enabled')),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('bellOnStart')),
                value: _bellOnStart,
                onChanged: (value) => setState(() => _bellOnStart = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('bellOnEnd')),
                value: _bellOnEnd,
                onChanged: (value) => setState(() => _bellOnEnd = value),
              ),
              Row(
                children: [
                  if (widget.lesson.id.isNotEmpty)
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
                  const SizedBox(width: 8),
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

  String? _validateMinutes(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 || number > 1440 ? '0–1440' : null;
  }

  String? _validateDuration(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 1 || number > 1440 ? '1–1440' : null;
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
      setState(() => _startMinute = time.hour * 60 + time.minute);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final controller = context.read<ScheduleController>();
    try {
      await controller.updateLesson(widget.lesson.copyWith(
        name: _name.text.trim(),
        startMinute: _startMinute,
        durationMinutes: int.parse(_duration.text),
        breakAfterMinutes: int.parse(_break.text),
        startMode: _mode,
        enabled: _enabled,
        bellOnStart: _bellOnStart,
        bellOnEnd: _bellOnEnd,
      ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('operationFailed')}: $error'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final controller = context.read<ScheduleController>();
    try {
      await controller.deleteLesson(widget.lesson.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('operationFailed')}: $error'),
        ),
      );
    }
  }
}
