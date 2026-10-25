// lib/theme/app-theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color green = Color(0xFF1DB954);
  static const Color greenDeep = Color(0xFF0E7A3A);
  static const Color greenSoft = Color(0xFF8FE3AC);

  static const Color lightBg = Color(0xFFF7F8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE3E7E0);
  static const Color lightText = Color(0xFF0B0F0C);
  static const Color lightTextMuted = Color(0xFF4A5450);

  static const Color darkBg = Color(0xFF0A0F0C);
  static const Color darkSurface = Color(0xFF121815);
  static const Color darkBorder = Color(0xFF1F2A24);
  static const Color darkText = Color(0xFFF2F5F3);
  static const Color darkTextMuted = Color(0xFF9AA6A0);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.green,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.greenDeep,
            secondary: AppColors.green,
            surface: AppColors.lightSurface,
            onSurface: AppColors.lightText,
          ),
      scaffoldBackgroundColor: AppColors.lightBg,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.lightText,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.lightText,
        displayColor: AppColors.lightText,
      ),
      dividerColor: AppColors.lightBorder,
      iconTheme: const IconThemeData(color: AppColors.lightText),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.green,
            brightness: Brightness.dark,
          ).copyWith(
            primary: AppColors.green,
            secondary: AppColors.greenSoft,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkText,
          ),
      scaffoldBackgroundColor: AppColors.darkBg,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.darkText,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.darkText,
        displayColor: AppColors.darkText,
      ),
      dividerColor: AppColors.darkBorder,
      iconTheme: const IconThemeData(color: AppColors.darkText),
    );
  }

  static Color bg(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;

  static Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;

  static Color border(BuildContext c) => Theme.of(c).dividerColor;

  static Color text(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? AppColors.darkText
      : AppColors.lightText;

  static Color textMuted(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
      ? AppColors.darkTextMuted
      : AppColors.lightTextMuted;

  static Color accent(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
      ? AppColors.green
      : AppColors.greenDeep;

  static Color ink(BuildContext c) => text(c);
  static Color muted(BuildContext c) => textMuted(c);
  static Color line(BuildContext c) => border(c);
}

class AppText {
  static TextStyle serif(
    double size, {
    Color? color,
    FontWeight w = FontWeight.w600,
    FontStyle style = FontStyle.normal,
    double h = 1.05,
    double ls = -0.5,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    color: color,
    fontWeight: w,
    fontStyle: style,
    height: h,
    letterSpacing: ls,
  );

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight w = FontWeight.w400,
    double h = 1.55,
  }) => GoogleFonts.interTight(
    fontSize: size,
    color: color,
    fontWeight: w,
    height: h,
  );

  static TextStyle mono(
    double size, {
    Color? color,
    FontWeight w = FontWeight.w500,
    double ls = 1.2,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    color: color,
    fontWeight: w,
    letterSpacing: ls,
  );
}
