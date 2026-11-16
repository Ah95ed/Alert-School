import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_localizations.dart';

Future<void> runUiAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${context.tr('operationFailed')}: $error')),
    );
  }
}
