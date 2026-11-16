import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  static ThemeData light() => _create(Brightness.light);
  static ThemeData dark() => _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF397E78),
      brightness: brightness,
      surface: brightness == Brightness.light
          ? const Color(0xFFF5F8F6)
          : const Color(0xFF141A19),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
      ),
    );
  }
}
