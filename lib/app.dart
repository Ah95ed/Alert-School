import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:provider/provider.dart';

import 'controllers/permissions_controller.dart';
import 'controllers/schedule_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'services/alarm_service.dart';
import 'views/screens/app_shell.dart';

class AlertSchoolApp extends StatelessWidget {
  const AlertSchoolApp({
    required this.scheduleController,
    required this.settingsController,
    required this.alarmService,
    super.key,
  });

  final ScheduleController scheduleController;
  final SettingsController settingsController;
  final AlarmService alarmService;

  @override
  Widget build(BuildContext context) => MultiProvider(
        // Provider is the dependency-injection boundary for MVC controllers.
        providers: [
          ChangeNotifierProvider.value(value: scheduleController),
          ChangeNotifierProvider.value(value: settingsController),
          ChangeNotifierProvider(
            create: (_) => PermissionsController(alarmService: alarmService),
          ),
        ],
        child: Consumer<SettingsController>(
          builder: (context, controller, _) {
            final settings = controller.settings;
            final themeMode = switch (settings.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            };
            final locale = Locale(settings.localeCode);
            return MaterialApp(
              title: AppConstants.appTitle,
              debugShowCheckedModeBanner: false,
              locale: locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalCupertinoLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  alwaysUse24HourFormat: settings.use24HourTime,
                ),
                child: child!,
              ),
              home: const AppShell(),
            );
          },
        ),
      );
}
