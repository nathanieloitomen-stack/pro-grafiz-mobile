import 'package:flutter/material.dart';

/// Pro_Grafiz design tokens — colour.
///
/// Source of truth: the approved design handoff README, "Design tokens ▸
/// Colour". These values are fixed by the approved product design — do
/// not add, rename, or adjust a colour here without an explicit design
/// decision from the product owner; this file should never drift ahead
/// of what's actually approved.
class PGColors {
  PGColors._();

  // Ground
  static const ink =
      Color(0xFF1E1613); // Primary text, dark cards, active nav, staff headers
  static const inkDeep = Color(0xFF141010); // Full-bleed dark panels
  static const paper = Color(0xFFFBF4EA); // App background, text on dark
  static const paperWarm =
      Color(0xFFF6EDE1); // Selected rows, inset notes, secondary cards
  static const clay =
      Color(0xFFF2E4D2); // Accent cards, testimonial, CTA blocks
  static const clayDeep =
      Color(0xFFEDE2D4); // Pattern tile backgrounds, avatar fills, chips

  // Action
  static const ember =
      Color(0xFFC33B22); // Primary action, links, active state, counts
  static const emberBright =
      Color(0xFFE8452B); // Live pulse dot, submit on dark
  static const emberDark = Color(0xFF9E2C16); // Link hover / pressed
  static const amber =
      Color(0xFFF0A03C); // Staff dot, camera guides, gradient end, About accent

  // Text
  static const textMid = Color(0xFF5C4B3F); // Body copy on paper
  static const textSoft = Color(0xFF8A7566); // Labels, captions, meta
  static const textFaint = Color(0xFFA08F80); // Timestamps, disclaimers
  static const textWarm = Color(0xFF6E5A4C); // Copy on clay
  static const textDark = Color(0xFF3A2E27); // Body copy in the manual

  // Status
  static const successBg = Color(0xFFE4EFE7);
  static const successFg = Color(0xFF2F6B57);
  static const warningBg = Color(0xFFFAEFD8);
  static const warningFg = Color(0xFF8A6314);
  static const warningDot = Color(0xFFB07A1C);
  static const dangerBg = Color(0xFFF6E3DE);
  static const dangerFg = Color(0xFFA33B22);
  static const autoBg = Color(0xFFF3EFF7);
  static const autoFg = Color(0xFF5B4A7A);
  static const autoTagBg = Color(0xFFEDE6F3);

  /// Hairline borders/dividers/inert fills. The approved design specifies
  /// an opacity range of .07–.16 against [ink] rather than a fixed value;
  /// pick within that range for the specific use, defaulting to .12.
  static Color hairline([double opacity = 0.12]) {
    assert(opacity >= 0.07 && opacity <= 0.16,
        'Hairline opacity outside the approved .07–.16 range — check the token spec.');
    return ink.withOpacity(opacity);
  }
}

/// Material fills used inside pattern/plate geometry previews, and the
/// tinted backgrounds those previews sit on. Also fixed by the approved
/// design tokens.
class PGMaterialColors {
  PGMaterialColors._();

  static const mildSteelFill = Color(0xFF4A4038);
  static const stainlessFill = Color(0xFF8B8F93);
  static const aluminiumFill = Color(0xFFA9AEB2);
  static const cortenFill = Color(0xFF8C4A2B);
  static const blackFill = Color(0xFF1E1613);

  static const steelBg = Color(0xFFEDE2D4);
  static const stainlessBg = Color(0xFFE6E7E4);
  static const aluminiumBg = Color(0xFFE9EBEC);
  static const cortenBg = Color(0xFFF0DCCB);
}
