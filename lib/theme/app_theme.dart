import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg       = Color(0xFFF7EFE3);
  static const bgCard   = Color(0xFFFFFBF5);
  static const surface  = Color(0xFFFFFBF5);
  static const accent   = Color(0xFF7B4A2A);
  static const accentDark = Color(0xFF4E2C17);
  static const accentLight = Color(0xFFB07A4F);
  static const accent2  = Color(0xFF6B7A3A);
  static const accent3  = Color(0xFFB3412E);
  static const accent4  = Color(0xFFC08A1E);
  static const glass    = Color(0xE6FFFBF5);
  static const glassBorder = Color(0x337B4A2A);
  static const inputFill   = Color(0xFFF3E8D8);
  static const textPrimary   = Color(0xFF3B2416);
  static const textSecondary = Color(0xFF7A5A43);
  static const textMuted     = Color(0xFFA88C74);
  static const gradientStart = Color(0xFFFBF6EE);
  static const gradientEnd   = Color(0xFFEFE2CF);

  static const List<Color> moduleColors = [
    Color(0xFF7B4A2A), Color(0xFFB5562C), Color(0xFF6B7A3A),
    Color(0xFFC08A1E), Color(0xFF2F6F6A), Color(0xFF9C3D2E),
    Color(0xFF4A6378), Color(0xFF6D4C6F), Color(0xFFB07A2A),
    Color(0xFF7E8F6A), Color(0xFFC06A45), Color(0xFF5D4037),
  ];
}

class AppTheme {
  static ThemeData get theme {
    final base = GoogleFonts.interTextTheme();
    final serif = GoogleFonts.playfairDisplay;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.surface,
        error: AppColors.accent3,
      ),
      textTheme: base.copyWith(
        displaySmall:   serif(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800),
        headlineMedium: serif(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        headlineSmall:  serif(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge:     GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium:    GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge:      GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
        bodyMedium:     GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        labelMedium:    GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: serif(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
    );
  }

  static BoxDecoration get bgGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [AppColors.gradientStart, AppColors.bg, AppColors.gradientEnd],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  static BoxDecoration glassCard({double radius = 20, Color? color, List<Color>? gradient}) => BoxDecoration(
    color: gradient == null ? (color ?? AppColors.glass) : null,
    gradient: gradient != null
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)
        : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorder, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x1F4E2C17), blurRadius: 24, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x0F4E2C17), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  // ── PhonePe-style building blocks (in the app's brown palette) ─────────────

  /// Solid brand header, like PhonePe's top bar.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [AppColors.accentDark, AppColors.accent],
  );

  /// Flat rounded card used for every section on the home screen.
  static BoxDecoration sectionCard({double radius = 16}) => BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: Color(0x144E2C17), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );

  static BoxDecoration glossyBrown({double radius = 16, BoxShape shape = BoxShape.rectangle}) => BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [AppColors.accentLight, AppColors.accent, AppColors.accentDark],
      stops: [0.0, 0.55, 1.0],
    ),
    border: Border.all(color: const Color(0x66FFE9CF), width: 1),
  );
}
