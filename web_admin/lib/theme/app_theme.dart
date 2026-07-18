import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BKK Carglass admin — a deep workshop red on warm white. Status color
/// intensity tracks job progress (pale -> deep red as a booking moves
/// forward); anything outside the active flow (cancelled, deactivated)
/// drops to neutral gray instead of a traffic-light color.
class AppColors {
  AppColors._();

  static const red900 = Color(0xFF7A121C); // sidebar, COMPLETED, deepest accent
  static const red700 = Color(0xFFB21E2B); // primary actions, IN_PROGRESS
  static const redTintMid = Color(0xFFF6D6D9); // CONFIRMED / active chip bg
  static const redTintLight = Color(0xFFF1EAE8); // PENDING chip bg

  static const ink = Color(0xFF201A1A);
  static const paper = Color(0xFFFBF9F7);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E1DE);
  static const muted = Color(0xFF8A7F7C);
  static const neutralChipBg = Color(0xFFEDEAE7); // cancelled / inactive
  static const neutralChipText = Color(0xFF8A8580);
}

class StatusTone {
  final Color background;
  final Color foreground;
  const StatusTone(this.background, this.foreground);
}

/// Booking status -> tonal red scale. Redder = further along.
StatusTone bookingStatusTone(String status) {
  switch (status) {
    case 'PENDING':
      return const StatusTone(AppColors.redTintLight, Color(0xFF8A5458));
    case 'CONFIRMED':
      return const StatusTone(AppColors.redTintMid, AppColors.red900);
    case 'IN_PROGRESS':
      return const StatusTone(AppColors.red700, Colors.white);
    case 'COMPLETED':
      return const StatusTone(AppColors.red900, Colors.white);
    case 'CANCELLED':
    default:
      return const StatusTone(AppColors.neutralChipBg, AppColors.neutralChipText);
  }
}

const Map<String, String> bookingStatusLabelTh = {
  'PENDING': 'รอดำเนินการ',
  'CONFIRMED': 'ยืนยันแล้ว',
  'IN_PROGRESS': 'กำลังดำเนินการ',
  'COMPLETED': 'เสร็จสิ้น',
  'CANCELLED': 'ยกเลิก',
};

ThemeData buildAppTheme() {
  final displayFont = GoogleFonts.oswaldTextTheme();
  final bodyFont = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red700,
      primary: AppColors.red700,
      onPrimary: Colors.white,
      surface: AppColors.surface,
    ),
    fontFamily: bodyFont.bodyMedium?.fontFamily,
    textTheme: bodyFont.copyWith(
      headlineLarge: displayFont.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.ink,
      ),
      headlineMedium: displayFont.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.ink,
      ),
      titleLarge: displayFont.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.ink,
      ),
      titleMedium: displayFont.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: AppColors.ink,
      ),
      labelLarge: displayFont.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red700,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.oswald(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red900,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.oswald(fontWeight: FontWeight.w500, letterSpacing: 0.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.red700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.red700, width: 1.6),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.red900),
      headingTextStyle: GoogleFonts.oswald(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        fontSize: 13,
      ),
      dataTextStyle: bodyFont.bodyMedium?.copyWith(color: AppColors.ink),
      dividerThickness: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
