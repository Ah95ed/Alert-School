import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const cream = Color(0xFFFFF8E7);
  static const card = Color(0xFFFFFCF3);
  static const border = Color(0xFFF0E2BE);
  static const honey = Color(0xFFE0A93B);
  static const text = Color(0xFF4A3B26);
  static const secondaryText = Color(0xFF8A7A5C);
  static const disabled = Color(0xFFD9CDB4);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: honey,
          brightness: Brightness.light,
        ).copyWith(
          primary: honey,
          onPrimary: text,
          secondary: honey,
          onSecondary: text,
          tertiary: honey,
          onTertiary: text,
          surface: cream,
          onSurface: text,
          surfaceContainerLowest: card,
          surfaceContainerLow: card,
          outline: border,
          outlineVariant: border,
          error: secondaryText,
          onError: cream,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 1,
        shadowColor: const Color(0x1A4A3B26),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: secondaryText),
        titleLarge: TextStyle(color: text),
        titleMedium: TextStyle(color: text),
        titleSmall: TextStyle(color: secondaryText),
      ),
      iconTheme: const IconThemeData(color: text),
      disabledColor: disabled,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(14.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: honey,
        foregroundColor: text,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? honey : disabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? border : card,
        ),
        trackOutlineColor: WidgetStateProperty.all(border),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: honey,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
    );
  }
}
