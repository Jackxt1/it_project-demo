import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette matches the customer app (`mobile/lib/theme/app_theme.dart`) plus
/// the extra tones used by the technician mockup's status badges.
class AppColors {
  static const primary = Color(0xFFEE2020);
  static const primaryDark = Color(0xFFB31818);
  static const primaryDarker = Color(0xFF8F1313);
  static const surfaceLight = Color(0xFFFDE9E9);
  static const splashBg = Color(0xFF530B0B);

  static const amber = Color(0xFFE08A1E);
  static const amberSurface = Color(0xFFFDF1DE);
  static const green = Color(0xFF1F9254);
  static const greenSurface = Color(0xFFE5F6EC);

  static const ink900 = Color(0xFF231F20);
  static const ink700 = Color(0xFF4A4547);
  static const ink500 = Color(0xFF8A8384);
  static const ink300 = Color(0xFFC9C4C5);
  static const ink100 = Color(0xFFF1EEEE);
  static const paper = Color(0xFFF7F5F4);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.paper,
        textTheme: GoogleFonts.ibmPlexSansThaiTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
