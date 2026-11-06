import 'package:flutter/material.dart';

class AppColors {
  static const bg       = Color(0xFF07111F);
  static const bgCard   = Color(0xFF0E1E35);
  static const surface  = Color(0xFF132542);
  static const accent   = Color(0xFF3D8EFF);
  static const accent2  = Color(0xFF06D6A0);
  static const accent3  = Color(0xFFFF6B6B);
  static const accent4  = Color(0xFFFFD166);
  static const glass    = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x26FFFFFF);
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8BA5C5);
  static const textMuted     = Color(0xFF4A6480);

  static const gradientStart = Color(0xFF0D1B4B);
  static const gradientEnd   = Color(0xFF07111F);

  static const List<Color> moduleColors = [
    Color(0xFF3D8EFF),
    Color(0xFF06D6A0),
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFFBB86FC),
    Color(0xFF06B6D4),
    Color(0xFFFF9F43),
    Color(0xFFEE5A24),
    Color(0xFF0652DD),
    Color(0xFF1289A7),
    Color(0xFFC4E538),
    Color(0xFF9980FA),
  ];
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
      labelMedium: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgCard,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );

  static BoxDecoration get bgGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.gradientStart, AppColors.gradientEnd, AppColors.bg],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  static BoxDecoration glassCard({double radius = 20, Color? color, List<Color>? gradient}) => BoxDecoration(
    color: color ?? AppColors.glass,
    gradient: gradient != null
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)
        : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorder, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0DFFFFFF), blurRadius: 1, offset: Offset(0, 1)),
    ],
  );
}
