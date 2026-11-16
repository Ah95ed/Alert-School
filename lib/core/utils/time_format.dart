String formatMinuteOfDay(
  int minute, {
  required bool use24Hour,
  String amLabel = 'AM',
  String pmLabel = 'PM',
}) {
  final normalized = minute % (24 * 60);
  final hour = normalized ~/ 60;
  final minutePart = normalized % 60;
  if (use24Hour) {
    return '${hour.toString().padLeft(2, '0')}:${minutePart.toString().padLeft(2, '0')}';
  }
  final period = hour < 12 ? amLabel : pmLabel;
  final twelveHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelveHour:${minutePart.toString().padLeft(2, '0')} $period';
}

String formatDateTime(
  DateTime time, {
  required bool use24Hour,
  String amLabel = 'AM',
  String pmLabel = 'PM',
}) =>
    formatMinuteOfDay(
      time.hour * 60 + time.minute,
      use24Hour: use24Hour,
      amLabel: amLabel,
      pmLabel: pmLabel,
    );
