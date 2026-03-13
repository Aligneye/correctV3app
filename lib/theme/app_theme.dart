import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Core brand teal provided by the user.
  static const Color brandPrimary = Color(0xFF008090);

  // Accent colors inspired by modern product palettes (Stripe/Notion/Slack style).
  static const Color brandSecondary = Color(0xFF14B8A6);
  static const Color brandTertiary = Color(0xFF0EA5E9);

  static const Color _lightBackground = Color(0xFFF6FAFB);
  static const Color _darkBackground = Color(0xFF0D1A1D);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: brandPrimary,
        secondary: brandSecondary,
        tertiary: brandTertiary,
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        outline: const Color(0xFFD1D9E0),
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF32B5C4),
        secondary: const Color(0xFF2DD4BF),
        tertiary: const Color(0xFF38BDF8),
        surface: const Color(0xFF152429),
        onSurface: const Color(0xFFE2E8F0),
        outline: const Color(0xFF3A4A52),
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightScheme,
      scaffoldBackgroundColor: _lightBackground,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: _lightScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lightScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lightScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lightScheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: _lightScheme.outline),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: _darkBackground,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: _darkScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _darkScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _darkScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _darkScheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: _darkScheme.outline),
        ),
      ),
    );
  }
}
