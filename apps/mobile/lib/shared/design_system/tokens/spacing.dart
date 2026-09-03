/// Spacing tokens, per the approved design handoff README ("Spacing,
/// radius, shadow"). Where the source gives a range rather than a fixed
/// value, both ends are exposed — pick deliberately per use, don't
/// average them.
class PGSpacing {
  PGSpacing._();

  // Screen padding
  static const screenHorizontal = 18.0;
  static const screenTopMin = 16.0;
  static const screenTopMax = 18.0;

  /// Bottom padding needed to clear the floating bottom nav.
  static const screenBottomForNav = 130.0;

  // Stack gaps
  static const sectionGapMin = 20.0;
  static const sectionGapMax = 22.0;
  static const groupGapMin = 10.0;
  static const groupGapMax = 14.0;
  static const labelToValueMin = 6.0;
  static const labelToValueMax = 8.0;

  // Convenience defaults (midpoint-ish, safe when a single value is
  // needed and the specific use doesn't call for the min or max).
  static const sectionGap = 20.0;
  static const groupGap = 12.0;
  static const labelToValue = 8.0;
}
