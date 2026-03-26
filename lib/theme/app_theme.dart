import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum UIMode { dark, light }

class AppTheme {
  // ─── Art Therapy Palette ───
  // Warm, organic colours inspired by natural pigments,
  // handcrafted paper, and botanical studio spaces.

  // Light palette — sun-dappled studio
  static const Color _warmCream = Color(
    0xFFFBF8F1,
  ); // warm parchment background (lighter, sunnier)
  static const Color _softSage = Color(0xFF8BA888); // softer, warmer sage green
  static const Color _dustyRose = Color(
    0xFFD49A89,
  ); // soft warm terracotta blush
  static const Color _sandstone = Color(0xFFE5DCC5); // pale sandstone border
  static const Color _warmCharcoal = Color(
    0xFF26231F,
  ); // starker text for contrast
  static const Color _lightLinen = Color(
    0xFFFEFCF8,
  ); // luminous linen card surface
  static const Color _mutedTerracotta = Color(
    0xFFC89073,
  ); // earthy tertiary tone
  static const Color _warmWhite = Color(0xFFFFFFFF); // pure warm white
  static const Color _accentGold = Color(0xFFE2B45A); // warm organic gold

  // Dark palette — evening candlelight studio
  static const Color _deepForest = Color(
    0xFF232521,
  ); // deep, rich organic charcoal
  static const Color _moonlitSage = Color(
    0xFF9CB89C,
  ); // glowing sage, desaturated
  static const Color _duskRose = Color(0xFFD9A098); // softened dusty rose
  static const Color _charcoalBark = Color(
    0xFF2C2F2C,
  ); // dark woody card surface
  static const Color _ashBorder = Color(0xFF3F443F); // smooth dark borders
  static const Color _parchment = Color(0xFFEBE3D5); // warm reading text
  static const Color _amberGlow = Color(0xFFDCAE71); // candlelight accent
  static const Color _nightLinen = Color(0xFF323632); // elevated surface

  static ThemeData getTheme(UIMode mode) {
    if (mode == UIMode.dark) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _deepForest,
        primaryColor: _moonlitSage,
        colorScheme: ColorScheme.dark(
          primary: _moonlitSage,
          secondary: _duskRose,
          tertiary: _amberGlow,
          surface: _charcoalBark,
          onSurface: _parchment,
          outline: _ashBorder,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              headlineLarge: GoogleFonts.lora(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: _parchment,
              ),
              headlineMedium: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _parchment,
              ),
              headlineSmall: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _parchment,
              ),
              bodyLarge: GoogleFonts.outfit(
                fontSize: 16,
                color: _parchment,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
              bodyMedium: GoogleFonts.outfit(
                fontSize: 14,
                color: _parchment.withValues(alpha: 0.9),
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: _deepForest,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _parchment,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: _charcoalBark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              28,
            ), // Softer, more organic corners
            side: BorderSide(
              color: _ashBorder.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _moonlitSage,
          foregroundColor: _deepForest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 6,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: _nightLinen,
          indicatorColor: _moonlitSage.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          selectedIconTheme: IconThemeData(color: _moonlitSage, size: 26),
          unselectedIconTheme: IconThemeData(
            color: _parchment.withValues(alpha: 0.4),
            size: 24,
          ),
          selectedLabelTextStyle: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _moonlitSage,
          ),
          unselectedLabelTextStyle: GoogleFonts.outfit(
            fontSize: 12,
            color: _parchment.withValues(alpha: 0.4),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _nightLinen,
          indicatorColor: _moonlitSage.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: _ashBorder.withValues(alpha: 0.4),
        hintColor: _parchment.withValues(alpha: 0.4),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _charcoalBark,
          contentTextStyle: GoogleFonts.outfit(color: _parchment),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _nightLinen.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: _ashBorder.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: _moonlitSage.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          labelStyle: GoogleFonts.outfit(
            color: _parchment.withValues(alpha: 0.6),
          ),
          hintStyle: GoogleFonts.outfit(
            color: _parchment.withValues(alpha: 0.35),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _charcoalBark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 24,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _nightLinen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: GoogleFonts.outfit(color: _parchment),
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _warmCream,
        primaryColor: _softSage,
        colorScheme: ColorScheme.light(
          primary: _softSage,
          secondary: _dustyRose,
          tertiary: _accentGold,
          surface: _lightLinen,
          onSurface: _warmCharcoal,
          outline: _sandstone,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
            .copyWith(
              headlineLarge: GoogleFonts.lora(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: _warmCharcoal,
              ),
              headlineMedium: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _warmCharcoal,
              ),
              headlineSmall: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _warmCharcoal,
              ),
              bodyLarge: GoogleFonts.outfit(
                fontSize: 16,
                color: _warmCharcoal,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
              bodyMedium: GoogleFonts.outfit(
                fontSize: 14,
                color: _warmCharcoal.withValues(alpha: 0.9),
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: _warmCream,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _warmCharcoal,
          titleTextStyle: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _warmCharcoal,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: _lightLinen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Organic, rounded corners
            side: BorderSide(
              color: _sandstone.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          elevation: 2,
          shadowColor: _mutedTerracotta.withValues(alpha: 0.15),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _softSage,
          foregroundColor: _warmWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 6,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: _lightLinen,
          indicatorColor: _softSage.withValues(alpha: 0.12),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          selectedIconTheme: IconThemeData(color: _softSage, size: 26),
          unselectedIconTheme: IconThemeData(
            color: _warmCharcoal.withValues(alpha: 0.35),
            size: 24,
          ),
          selectedLabelTextStyle: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _softSage,
          ),
          unselectedLabelTextStyle: GoogleFonts.outfit(
            fontSize: 12,
            color: _warmCharcoal.withValues(alpha: 0.4),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _lightLinen,
          indicatorColor: _softSage.withValues(alpha: 0.12),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: _sandstone.withValues(alpha: 0.3),
        hintColor: _warmCharcoal.withValues(alpha: 0.4),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _warmCharcoal,
          contentTextStyle: GoogleFonts.outfit(color: _warmWhite),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _warmWhite,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: _sandstone.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: _softSage.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          labelStyle: GoogleFonts.outfit(
            color: _warmCharcoal.withValues(alpha: 0.6),
          ),
          hintStyle: GoogleFonts.outfit(
            color: _warmCharcoal.withValues(alpha: 0.35),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _lightLinen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 24,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _warmWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: GoogleFonts.outfit(color: _warmCharcoal),
        ),
      );
    }
  }

  // ─── Semantic colours for Gantt chart hierarchy ───
  // Bold, highly contrasting colours for clear hierarchy visibility
  static const Color _boldPhaseLight = Color(0xFF0A58CA); // Bold vibrant blue
  static const Color _boldPhaseDark = Color(0xFF3D8BFD); // Bright vivid blue

  static const Color _boldTaskLight = Color(0xFFD63384); // Bold magenta/pink
  static const Color _boldTaskDark = Color(0xFFFF66A3); // Bright vivid pink

  static const Color _boldSubtaskLight = Color(
    0xFFFD7E14,
  ); // Bold bright orange
  static const Color _boldSubtaskDark = Color(
    0xFFFF9D4D,
  ); // Bright vivid orange

  static Color phaseColor(UIMode mode) =>
      mode == UIMode.dark ? _boldPhaseDark : _boldPhaseLight;
  static Color taskColor(UIMode mode) =>
      mode == UIMode.dark ? _boldTaskDark : _boldTaskLight;
  static Color subtaskColor(UIMode mode) =>
      mode == UIMode.dark ? _boldSubtaskDark : _boldSubtaskLight;

  static List<Color> get phaseColors => [
        const Color(0xFF0A58CA),
        const Color(0xFFD63384),
        const Color(0xFFFD7E14),
        const Color(0xFF198754),
        const Color(0xFF6F42C1),
        const Color(0xFF0DCAF0),
      ];
  // Alternating row tints for Gantt readability — warmer
  static Color ganttRowTint(UIMode mode, int index) {
    if (mode == UIMode.dark) {
      return index.isEven
          ? const Color(0xFF2D322D).withValues(alpha: 0.4)
          : Colors.transparent;
    }
    return index.isEven
        ? const Color(0xFFF0E8D8).withValues(alpha: 0.45)
        : Colors.transparent;
  }

  // ─── Gantt bar heights (organic thin lines) ───
  // Doubled thickness for better visibility
  static double ganttPhaseHeight = 10.0;
  static double ganttTaskHeight = 6.0;
  static double ganttSubtaskHeight = 3.0;

  // ─── Today marker colour  ───
  static Color todayMarker(UIMode mode) =>
      mode == UIMode.dark ? _amberGlow : _dustyRose;
}
