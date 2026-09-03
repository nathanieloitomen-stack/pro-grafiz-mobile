/// Motion tokens, per the approved design handoff README ("Motion").
/// Four keyframes exist in the whole product, plus a handful of timed
/// transitions — nothing else. Don't add new easing curves or durations
/// for a new interaction without checking whether one of these already
/// covers it.
class PGMotion {
  PGMotion._();

  /// `pgPulse` — live-stage dots.
  static const pulse = Duration(milliseconds: 1800);

  /// `pgPulse`, faster variant used in the scan step list.
  static const pulseScan = Duration(milliseconds: 1200);

  /// `pgRise` — sheets, overlays, grid items entering. Range 0.2–0.3s.
  static const riseMin = Duration(milliseconds: 200);
  static const riseMax = Duration(milliseconds: 300);

  /// `pgToast` — toast lifecycle, self-clearing.
  static const toast = Duration(milliseconds: 2600);

  /// Progress bar width transition.
  static const progressBar = Duration(milliseconds: 600);

  /// Zoom step transition (design detail screen).
  static const zoom = Duration(milliseconds: 250);

  /// Colour and background changes.
  static const colorChangeMin = Duration(milliseconds: 180);
  static const colorChangeMax = Duration(milliseconds: 300);

  /// Shared easing curve for progress bar and zoom transitions:
  /// `cubic-bezier(.4,0,.2,1)` — Flutter's `Curves.easeInOut` is not an
  /// exact match; use `Cubic(0.4, 0.0, 0.2, 1.0)` from the `flutter`
  /// package's `Curves` when precision matters.
  static const pressScaleMin = 0.92;
  static const pressScaleMax = 0.98;
}
