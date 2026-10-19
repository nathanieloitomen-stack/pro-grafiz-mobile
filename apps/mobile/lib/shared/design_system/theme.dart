import 'package:flutter/material.dart';

import 'tokens/tokens.dart';

/// Wires the Pro_Grafiz design tokens into a Flutter [ThemeData].
///
/// This is the only place tokens should be assembled into a theme — app
/// code should reach for `Theme.of(context)` or the token classes
/// directly, not redefine styling inline.
///
/// The approved design has no dark staff-only theme distinct from this;
/// "dark" surfaces (Ink, Ink deep) are achieved with specific widgets
/// (e.g. hero cards, camera overlay) on top of one light-background app
/// theme, not a system-level dark mode. Do not add a `ThemeMode.dark`
/// variant without checking that against the approved design first.
class PGTheme {
  PGTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: PGColors.ember,
      onPrimary: PGColors.paper,
      secondary: PGColors.amber,
      onSecondary: PGColors.ink,
      error: PGColors.dangerFg,
      onError: PGColors.paper,
      surface: PGColors.paper,
      onSurface: PGColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PGColors.paper,
      fontFamily: PGFonts.sans,
      splashFactory: NoSplash
          .splashFactory, // approved design has no ripple/hover, only press-scale
      textTheme: const TextTheme(
        displayLarge: PGTextStyles.hero,
        headlineLarge: PGTextStyles.screenTitle,
        headlineMedium: PGTextStyles.cardTitle,
        headlineSmall: PGTextStyles.sectionHead,
        titleLarge: PGTextStyles.quote,
        titleMedium: PGTextStyles.numeric,
        bodyLarge: PGTextStyles.input,
        bodyMedium: PGTextStyles.body,
        bodySmall: PGTextStyles.meta,
        labelLarge: PGTextStyles.button,
        labelMedium: PGTextStyles.label,
        labelSmall: PGTextStyles.tag,
      ),
      dividerColor: PGColors.hairline(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PGColors.ember,
          foregroundColor: PGColors.paper,
          disabledBackgroundColor: PGColors.hairline(),
          minimumSize: const Size.fromHeight(50), // primary CTAs 50–54px
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(PGRadius.pill)),
          ),
          textStyle: PGTextStyles.button,
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PGRadius.pill),
          borderSide: BorderSide(color: PGColors.hairline()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PGRadius.pill),
          borderSide: BorderSide(color: PGColors.hairline()),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PGRadius.pill)),
          borderSide: BorderSide(color: PGColors.ember, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PGRadius.pill)),
          borderSide: BorderSide(color: PGColors.dangerFg, width: 1.5),
        ),
        hintStyle: PGTextStyles.input.copyWith(color: PGColors.textFaint),
      ),
    );
  }
}
