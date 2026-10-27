import 'package:flutter/material.dart';

/// Font family names used across the app. Two families, per the approved
/// design: Instrument Serif for headings/numerals/prices/pull quotes,
/// Karla for everything else.
///
/// Font files are bundled under `assets/fonts/` and registered in
/// `pubspec.yaml` (`flutter.fonts`) as of PG-024. Family names here must
/// match the `family:` entries there exactly.
class PGFonts {
  PGFonts._();
  static const serif = 'InstrumentSerif';
  static const sans = 'Karla';
}

/// Type scale, per the approved design handoff README ("Typography").
/// Sizes below 11px are a deliberate, spec-called-out exception for tags
/// only — everything else respects the "never below 11px" floor.
class PGTextStyles {
  PGTextStyles._();

  // Instrument Serif — headings, numerals, prices, pull quotes.
  // line-height 0.9–1.3; letter-spacing -0.02em on the largest sizes.
  static const hero = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 38,
    height: 1.0,
    letterSpacing: -0.02 * 38,
    fontWeight: FontWeight.w400,
  );

  static const screenTitle = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 30,
    height: 1.05,
    letterSpacing: -0.02 * 30,
    fontWeight: FontWeight.w400,
  );

  static const cardTitle = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 26, // approved range 25–27px
    height: 1.15,
    fontWeight: FontWeight.w400,
  );

  static const sectionHead = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const quote = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 21,
    height: 1.25,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
  );

  static const numeric = TextStyle(
    fontFamily: PGFonts.serif,
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  // Karla — everything else.
  static const input = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const button = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 14, // approved range 13–14.5px
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 13.5,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  static const meta = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 12.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Uppercase label. Apply `.toUpperCase()` to the string at the call
  /// site — the style itself doesn't force casing.
  static const label = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.16 * 11,
  );

  /// Spec-called-out exception to the 11px floor — used only for small
  /// status tags (e.g. AUTO-DRAFT pill), never for body or label text.
  static const tag = TextStyle(
    fontFamily: PGFonts.sans,
    fontSize: 10.5,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
}
