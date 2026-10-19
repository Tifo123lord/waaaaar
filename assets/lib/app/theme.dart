import 'package:flutter/material.dart';

/// WORLD DOMINION design system.
///
/// Charcoal command-room surfaces, a single muted military-teal accent, a warm
/// brass highlight reserved for the player's own nation, and restrained
/// semantic colours for war/peace. Deliberately no gradients-by-default and no
/// pastel fills.
class WD {
  WD._();

  // --- Surfaces -----------------------------------------------------------
  static const Color void0 = Color(0xFF07090B); // app background
  static const Color surface1 = Color(0xFF0E1216); // panels
  static const Color surface2 = Color(0xFF151A20); // raised cards
  static const Color surface3 = Color(0xFF1D242B); // hover / selected fills
  static const Color line = Color(0xFF252D35); // 1px borders
  static const Color lineStrong = Color(0xFF323C46);

  // --- Text ---------------------------------------------------------------
  static const Color textPrimary = Color(0xFFE6EAEE);
  static const Color textSecondary = Color(0xFF9BA6B2);
  static const Color textMuted = Color(0xFF6B7783);

  // --- Accents ------------------------------------------------------------
  static const Color accent = Color(0xFF5FA893); // muted military teal
  static const Color accentDim = Color(0xFF37635A);
  static const Color brass = Color(0xFFC9A227); // player / highlights
  static const Color brassDim = Color(0xFF7A6318);

  // --- Semantic -----------------------------------------------------------
  static const Color danger = Color(0xFFC0563F);
  static const Color dangerDim = Color(0xFF6E3327);
  static const Color warning = Color(0xFFC98A3A);
  static const Color positive = Color(0xFF5FA36A);
  static const Color info = Color(0xFF4C7FA6);
  static const Color ally = Color(0xFF4C7FA6);

  // --- Map palette --------------------------------------------------------
  /// Colour matched to the painted map backdrop's own ocean so the letterbox
  /// margins around the 2:1 image read as a seamless full-bleed surface.
  static const Color mapVoid = Color(0xFF070C12);
  static const Color mapFrame = Color(0xFF35434F);
  static const Color mapGlow = Color(0xFF6C9E9A);
  static const Color mapBorder = Color(0xFF8FA6B4);

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 14;

  static const EdgeInsets padScreen = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets padCard = EdgeInsets.all(14);

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  /// Text style shorthand with tabular figures for numeric columns.
  static const TextStyle mono = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static ThemeData build({required bool isPersian, bool reduceMotion = false}) {
    final family = isPersian ? 'Vazirmatn' : 'Inter';
    final base = isPersian ? 'Vazirmatn' : 'Inter';

    ColorScheme scheme = const ColorScheme.dark().copyWith(
      primary: accent,
      onPrimary: const Color(0xFF06231C),
      primaryContainer: accentDim,
      onPrimaryContainer: textPrimary,
      secondary: brass,
      onSecondary: const Color(0xFF241C03),
      secondaryContainer: brassDim,
      onSecondaryContainer: textPrimary,
      surface: surface1,
      onSurface: textPrimary,
      surfaceContainerHighest: surface2,
      onSurfaceVariant: textSecondary,
      outline: line,
      outlineVariant: lineStrong,
      error: danger,
      onError: Colors.white,
    );

    final text = _textTheme(family);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: void0,
      canvasColor: void0,
      fontFamily: base,
      textTheme: text,
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: surface1,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleMedium,
        shape: const Border(bottom: BorderSide(color: line)),
      ),
      cardTheme: CardThemeData(
        color: surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lineStrong),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentDim,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: base,
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF06231C),
          disabledBackgroundColor: surface3,
          disabledForegroundColor: textMuted,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: TextStyle(
            fontFamily: base,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: lineStrong),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: TextStyle(
            fontFamily: base,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: TextStyle(
            fontFamily: base,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brass,
          foregroundColor: const Color(0xFF241C03),
          elevation: 0,
          minimumSize: const Size(0, 46),
          textStyle: TextStyle(
            fontFamily: base,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          fontFamily: base,
          color: textMuted,
          fontSize: 13.5,
        ),
        prefixIconColor: textMuted,
        border: _inputBorder(line),
        enabledBorder: _inputBorder(line),
        focusedBorder: _inputBorder(accent, width: 1.4),
        errorBorder: _inputBorder(danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: accentDim,
        side: const BorderSide(color: line),
        labelStyle: TextStyle(
          fontFamily: base,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: base,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surface3,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.14),
        trackHeight: 3,
        valueIndicatorColor: surface3,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: base,
          color: textPrimary,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentDim : surface3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(lineStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textMuted,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surface3,
        circularTrackColor: surface3,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface3,
        contentTextStyle: TextStyle(
          fontFamily: base,
          color: textPrimary,
          fontSize: 13.5,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: lineStrong),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface3,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: lineStrong),
        ),
        textStyle: TextStyle(
          fontFamily: base,
          color: textPrimary,
          fontSize: 12,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: line,
        labelStyle: TextStyle(
          fontFamily: base,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: base,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: reduceMotion
                ? const _NoTransitionBuilder()
                : const FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(String family) {
    TextStyle s(
      double size,
      FontWeight weight, {
      Color color = textPrimary,
      double spacing = 0,
      double height = 1.3,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );

    return TextTheme(
      displaySmall: s(30, FontWeight.w900, spacing: 3.0, height: 1.1),
      headlineMedium: s(24, FontWeight.w700, spacing: 0.4, height: 1.15),
      headlineSmall: s(20, FontWeight.w700, spacing: 0.2, height: 1.2),
      titleLarge: s(17, FontWeight.w700, spacing: 0.1),
      titleMedium: s(15, FontWeight.w600, spacing: 0.1),
      titleSmall: s(13, FontWeight.w600, spacing: 0.2),
      bodyLarge: s(14.5, FontWeight.w400, height: 1.45),
      bodyMedium: s(13.5, FontWeight.w400, color: textSecondary, height: 1.45),
      bodySmall: s(12, FontWeight.w400, color: textMuted, height: 1.4),
      labelLarge: s(13.5, FontWeight.w600, spacing: 0.3),
      labelMedium: s(11, FontWeight.w600, spacing: 0.9),
      labelSmall: s(10, FontWeight.w600, spacing: 0.7, color: textMuted),
    );
  }
}

class _NoTransitionBuilder extends PageTransitionsBuilder {
  const _NoTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
