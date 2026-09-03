/// Corner radius tokens, per the approved design handoff README
/// ("Spacing, radius, shadow"). Every radius used anywhere in the
/// approved product appears in this list — if a new screen seems to need
/// a radius not here, that's a signal to check with the product owner
/// before inventing one.
class PGRadius {
  PGRadius._();

  static const pill = 999.0; // pills and buttons
  static const heroCard = 28.0; // hero and summary cards
  static const jobCard = 26.0;
  static const listGroup = 24.0; // list groups and inputs-in-cards
  static const insetNote = 22.0;
  static const thumbnail = 20.0;
  static const smallNote = 18.0;
  static const iconTileMax = 16.0;
  static const iconTileMin = 14.0;

  /// Bottom sheets: 32px 32px 0 0 — top corners only.
  static const bottomSheetTop = 32.0;
}
