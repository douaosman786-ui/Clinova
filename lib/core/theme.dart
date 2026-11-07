import 'package:flutter/material.dart';

/// Identité visuelle Clinova : bleu-vert profond (soin, calme) + sable chaud.
class ClinovaColors {
  ClinovaColors._();
  static const Color primary = Color(0xFF0E6B6B);
  static const Color primaryDark = Color(0xFF0A4F50);
  static const Color sand = Color(0xFFE9A24B);
  static const Color background = Color(0xFFF5F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF14232A);
  static const Color muted = Color(0xFF5E6E73);
  static const Color line = Color(0xFFE2DED5);

  static const Color scheduled = Color(0xFF1D6FB8);
  static const Color completed = Color(0xFF2E7D4F);
  static const Color cancelled = Color(0xFFB3412F);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ClinovaColors.primary,
    primary: ClinovaColors.primary,
    secondary: ClinovaColors.sand,
    surface: ClinovaColors.surface,
    brightness: Brightness.light,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: ClinovaColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: ClinovaColors.background,
      foregroundColor: ClinovaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ClinovaColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: const CardThemeData(
      color: ClinovaColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: ClinovaColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClinovaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ClinovaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ClinovaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ClinovaColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ClinovaColors.surface,
      indicatorColor: Color(0xFFD3EBE8),
      elevation: 0,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: ClinovaColors.surface,
      indicatorColor: Color(0xFFD3EBE8),
    ),
    dividerTheme: const DividerThemeData(color: ClinovaColors.line, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
