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
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
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
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: AppColors.darkText, displayColor: AppColors.darkText),
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
  // v2 type system: one modern grotesk for the whole app shell.
  //
  // The method names are kept from v1 (`serif`, `mono`) so that every screen
  // picks up the new look without a 200-call-site rename — but nothing here is
  // a serif or a monospace any more. Landing and Create ID keep their own
  // editorial styles on purpose.
  static TextStyle serif(
    double size, {
    Color? color,
    FontWeight w = FontWeight.w700,
    FontStyle style = FontStyle.normal,
    double h = 1.12,
    double ls = -0.7,
  }) => GoogleFonts.plusJakartaSans(
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
    double h = 1.5,
  }) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: w, height: h);

  static TextStyle mono(
    double size, {
    Color? color,
    FontWeight w = FontWeight.w600,
    double ls = 1.2,
  }) => GoogleFonts.inter(
    fontSize: size,
    color: color,
    fontWeight: w,
    letterSpacing: ls,
  );
}
