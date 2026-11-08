import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One colour set for the whole app. [AppThemes.all] lists the choices.
class AppPalette {
  final String id, name;
  final Brightness brightness;
  final Color bg, bgCard, accent, accentDark, accentLight, accent2, accent3, accent4;
  final Color inputFill, textPrimary, textSecondary, textMuted, gradientStart, gradientEnd;
  final Color shadow;
  final List<Color> moduleColors;

  const AppPalette({
    required this.id,
    required this.name,
    this.brightness = Brightness.light,
    required this.bg,
    required this.bgCard,
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.accent2,
    required this.accent3,
    required this.accent4,
    required this.inputFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.gradientStart,
    required this.gradientEnd,
    required this.shadow,
    required this.moduleColors,
  });

  bool get isDark => brightness == Brightness.dark;
}

class AppThemes {
  static const classic = AppPalette(
    id: 'classic', name: 'Classic Brown',
    bg: Color(0xFFF7EFE3), bgCard: Color(0xFFFFFBF5),
    accent: Color(0xFF7B4A2A), accentDark: Color(0xFF4E2C17), accentLight: Color(0xFFB07A4F),
    accent2: Color(0xFF6B7A3A), accent3: Color(0xFFB3412E), accent4: Color(0xFFC08A1E),
    inputFill: Color(0xFFF3E8D8),
    textPrimary: Color(0xFF3B2416), textSecondary: Color(0xFF7A5A43), textMuted: Color(0xFFA88C74),
    gradientStart: Color(0xFFFBF6EE), gradientEnd: Color(0xFFEFE2CF),
    shadow: Color(0xFF4E2C17),
    moduleColors: [
      Color(0xFF7B4A2A), Color(0xFFB5562C), Color(0xFF6B7A3A),
      Color(0xFFC08A1E), Color(0xFF2F6F6A), Color(0xFF9C3D2E),
      Color(0xFF4A6378), Color(0xFF6D4C6F), Color(0xFFB07A2A),
      Color(0xFF7E8F6A), Color(0xFFC06A45), Color(0xFF5D4037),
    ],
  );

  static const ocean = AppPalette(
    id: 'ocean', name: 'Ocean Blue',
    bg: Color(0xFFEEF3F9), bgCard: Color(0xFFFFFFFF),
    accent: Color(0xFF1F5FAE), accentDark: Color(0xFF123B73), accentLight: Color(0xFF5B8FD6),
    accent2: Color(0xFF168A7A), accent3: Color(0xFFC6423A), accent4: Color(0xFFD08A16),
    inputFill: Color(0xFFE3EBF5),
    textPrimary: Color(0xFF14243A), textSecondary: Color(0xFF4A5E78), textMuted: Color(0xFF8A9AB0),
    gradientStart: Color(0xFFF6F9FD), gradientEnd: Color(0xFFDDE7F3),
    shadow: Color(0xFF123B73),
    moduleColors: [
      Color(0xFF1F5FAE), Color(0xFF168A7A), Color(0xFF6A4FB3),
      Color(0xFFD08A16), Color(0xFF2E7D32), Color(0xFFC6423A),
      Color(0xFF00838F), Color(0xFF5C6BC0), Color(0xFFAD5A1E),
      Color(0xFF3F7F5F), Color(0xFF8E44AD), Color(0xFF37474F),
    ],
  );

  static const forest = AppPalette(
    id: 'forest', name: 'Forest Green',
    bg: Color(0xFFEFF4EC), bgCard: Color(0xFFFCFEFA),
    accent: Color(0xFF2E6B3F), accentDark: Color(0xFF1B4227), accentLight: Color(0xFF5E9C6C),
    accent2: Color(0xFF7A6A2E), accent3: Color(0xFFB4442F), accent4: Color(0xFFC7951C),
    inputFill: Color(0xFFE3ECDE),
    textPrimary: Color(0xFF1C2E21), textSecondary: Color(0xFF4E6453), textMuted: Color(0xFF8DA090),
    gradientStart: Color(0xFFF7FAF5), gradientEnd: Color(0xFFDFE9D9),
    shadow: Color(0xFF1B4227),
    moduleColors: [
      Color(0xFF2E6B3F), Color(0xFF7A6A2E), Color(0xFF2F6F6A),
      Color(0xFFC7951C), Color(0xFF4A6378), Color(0xFFB4442F),
      Color(0xFF558B2F), Color(0xFF6D4C6F), Color(0xFF8D6E2A),
      Color(0xFF00796B), Color(0xFFBF6A3A), Color(0xFF455A64),
    ],
  );

  static const midnight = AppPalette(
    id: 'midnight', name: 'Midnight Dark', brightness: Brightness.dark,
    bg: Color(0xFF14161B), bgCard: Color(0xFF1F232B),
    accent: Color(0xFFE0A15A), accentDark: Color(0xFF2A2F3A), accentLight: Color(0xFFF2C38B),
    accent2: Color(0xFF8DBF6A), accent3: Color(0xFFEF6B5B), accent4: Color(0xFFF0C04A),
    inputFill: Color(0xFF272C36),
    textPrimary: Color(0xFFF1EDE7), textSecondary: Color(0xFFB9B3AA), textMuted: Color(0xFF7F8794),
    gradientStart: Color(0xFF181B21), gradientEnd: Color(0xFF101216),
    shadow: Color(0xFF000000),
    moduleColors: [
      Color(0xFFE0A15A), Color(0xFF6FA8DC), Color(0xFF8DBF6A),
      Color(0xFFF0C04A), Color(0xFF4DB6AC), Color(0xFFEF6B5B),
      Color(0xFF9FA8DA), Color(0xFFCE93D8), Color(0xFFFFB74D),
      Color(0xFFA5D6A7), Color(0xFFFF8A65), Color(0xFFB0BEC5),
    ],
  );

  static const all = [classic, ocean, forest, midnight];

  static AppPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => classic);
}

/// Current colours. They change when the user picks another theme
/// (see [ThemeController]), so read them at build time — never in a `const`.
class AppColors {
  static AppPalette palette = AppThemes.classic;

  static Color get bg => palette.bg;
  static Color get bgCard => palette.bgCard;
  static Color get surface => palette.bgCard;
  static Color get accent => palette.accent;
  static Color get accentDark => palette.accentDark;
  static Color get accentLight => palette.accentLight;
  static Color get accent2 => palette.accent2;
  static Color get accent3 => palette.accent3;
  static Color get accent4 => palette.accent4;
  static Color get glass => palette.bgCard.withValues(alpha: 0.9);
  static Color get glassBorder => palette.accent.withValues(alpha: palette.isDark ? 0.25 : 0.2);
  static Color get divider => palette.accent.withValues(alpha: palette.isDark ? 0.14 : 0.08);
  static Color get inputFill => palette.inputFill;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;
  static Color get gradientStart => palette.gradientStart;
  static Color get gradientEnd => palette.gradientEnd;
  static Color get shimmerBase => palette.isDark ? const Color(0xFF262B34) : palette.inputFill;
  static Color get shimmerHighlight => palette.isDark ? const Color(0xFF323845) : palette.bgCard;

  /// Text / icon colour on top of [accent] (buttons, chips).
  static Color get onAccent => palette.isDark ? const Color(0xFF1A1206) : Colors.white;

  static List<Color> get moduleColors => palette.moduleColors;
}

/// Saves the chosen theme and repaints the app when it changes.
class ThemeController extends ValueNotifier<AppPalette> {
  ThemeController._() : super(AppThemes.classic);
  static final instance = ThemeController._();
  static const _key = 'theme';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(AppThemes.byId(prefs.getString(_key)));
    } catch (_) {}
  }

  Future<void> set(AppPalette p) async {
    if (p.id == value.id) return;
    _apply(p);
    // Widgets read AppColors directly, so rebuild every element (keeps all state & navigation).
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, p.id);
  }

  void _apply(AppPalette p) {
    AppColors.palette = p;
    value = p;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
    ));
  }
}

class AppTheme {
  static ThemeData get theme {
    final p = AppColors.palette;
    final base = GoogleFonts.interTextTheme(p.isDark ? ThemeData.dark().textTheme : null);
    const serif = GoogleFonts.playfairDisplay;
    final scheme = p.isDark
        ? ColorScheme.dark(
            primary: p.accent, onPrimary: AppColors.onAccent, secondary: p.accent2,
            surface: p.bgCard, onSurface: p.textPrimary, error: p.accent3)
        : ColorScheme.light(
            primary: p.accent, secondary: p.accent2, surface: p.bgCard, onSurface: p.textPrimary, error: p.accent3);
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: scheme,
      canvasColor: p.bgCard,
      dialogTheme: DialogThemeData(backgroundColor: p.bgCard),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bgCard),
      popupMenuTheme: PopupMenuThemeData(color: p.bgCard),
      dividerColor: AppColors.divider,
      textTheme: base.copyWith(
        displaySmall:   serif(color: p.textPrimary, fontSize: 32, fontWeight: FontWeight.w800),
        headlineMedium: serif(color: p.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        headlineSmall:  serif(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge:     GoogleFonts.inter(color: p.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium:    GoogleFonts.inter(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge:      GoogleFonts.inter(color: p.textSecondary, fontSize: 15, height: 1.6),
        bodyMedium:     GoogleFonts.inter(color: p.textSecondary, fontSize: 13, height: 1.5),
        labelMedium:    GoogleFonts.inter(color: p.textMuted, fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: serif(color: p.textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 1.5)),
        hintStyle: GoogleFonts.inter(color: p.textMuted, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bgCard,
        selectedItemColor: p.accent,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
    );
  }

  static BoxDecoration get bgGradient => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [AppColors.gradientStart, AppColors.bg, AppColors.gradientEnd],
      stops: const [0.0, 0.5, 1.0],
    ),
  );

  static BoxDecoration glassCard({double radius = 20, Color? color, List<Color>? gradient}) => BoxDecoration(
    color: gradient == null ? (color ?? AppColors.glass) : null,
    gradient: gradient != null
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)
        : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorder, width: 1),
    boxShadow: [
      BoxShadow(color: AppColors.palette.shadow.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
      BoxShadow(color: AppColors.palette.shadow.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
    ],
  );

  // ── PhonePe-style building blocks ─────────────────────────────────────────

  /// Solid brand header, like PhonePe's top bar.
  static LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: AppColors.palette.isDark
        ? const [Color(0xFF2A2F3A), Color(0xFF1C2028)]
        : [AppColors.accentDark, AppColors.accent],
  );

  /// Flat rounded card used for every section on the home screen.
  static BoxDecoration sectionCard({double radius = 16}) => BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(radius),
    border: AppColors.palette.isDark ? Border.all(color: AppColors.divider) : null,
    boxShadow: [
      BoxShadow(
          color: AppColors.palette.shadow.withValues(alpha: AppColors.palette.isDark ? 0.3 : 0.08),
          blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );

  static BoxDecoration glossyBrown({double radius = 16, BoxShape shape = BoxShape.rectangle}) => BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: AppColors.palette.isDark
          ? [AppColors.accentLight, AppColors.accent, const Color(0xFF9A6A30)]
          : [AppColors.accentLight, AppColors.accent, AppColors.accentDark],
      stops: const [0.0, 0.55, 1.0],
    ),
    border: Border.all(color: const Color(0x66FFE9CF), width: 1),
  );
}
