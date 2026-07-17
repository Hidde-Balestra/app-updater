import 'package:flutter/material.dart';

/// Accent + status colors approximated from the Figma design (indigo/purple
/// accent, orange "Update" chip, green "Actueel" chip).
class AppColors {
  AppColors._();

  static const accent = Color(0xFF5B4FE5);

  static const updateOrange = Color(0xFFE08A00);
  static const updateOrangeBgLight = Color(0xFFFFF1DA);
  static const updateOrangeBgDark = Color(0x33E08A00);

  static const upToDateGreen = Color(0xFF1E9E5A);
  static const upToDateGreenBgLight = Color(0xFFE0F6E9);
  static const upToDateGreenBgDark = Color(0x331E9E5A);

  static const errorRed = Color(0xFFD64545);
  static const errorRedBgLight = Color(0xFFFDE6E6);
  static const errorRedBgDark = Color(0x33D64545);

  static const neutralGrey = Color(0xFF8A8A98);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    );
    return _base(
      scheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFFF6F6FA));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    );
    return _base(
      scheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF121212));
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
