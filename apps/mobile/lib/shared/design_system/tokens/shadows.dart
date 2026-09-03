import 'package:flutter/material.dart';

import 'colors.dart';

/// Shadow tokens. The approved design uses exactly three shadows in the
/// whole product — do not add a fourth without an explicit design
/// decision; that constraint is itself part of the approved visual
/// language ("Shadows only three", handoff README).
class PGShadows {
  PGShadows._();

  /// `0 14px 30px -18px rgba(30,22,19,.85)` — dark hero cards.
  static List<BoxShadow> darkHeroCard = [
    BoxShadow(
      color: PGColors.ink.withOpacity(0.85),
      offset: const Offset(0, 14),
      blurRadius: 30,
      spreadRadius: -18,
    ),
  ];

  /// `0 10px 22px -12px rgba(195,59,34,.9)` — primary CTAs.
  static List<BoxShadow> primaryCta = [
    BoxShadow(
      color: PGColors.ember.withOpacity(0.9),
      offset: const Offset(0, 10),
      blurRadius: 22,
      spreadRadius: -12,
    ),
  ];

  /// `0 -20px 50px -20px rgba(30,22,19,.6)` — bottom sheets.
  static List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: PGColors.ink.withOpacity(0.6),
      offset: const Offset(0, -20),
      blurRadius: 50,
      spreadRadius: -20,
    ),
  ];
}
