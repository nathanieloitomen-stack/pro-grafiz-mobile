import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'pg_pressable.dart';

/// Generic pill shape used for filter chips, category chips, and material
/// swatch pills. Purely presentational — selection state is passed in,
/// not managed here, so feature code stays responsible for its own state.
class PGPill extends StatelessWidget {
  const PGPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? PGColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(PGRadius.pill),
        border: Border.all(
          color: selected ? PGColors.ink : PGColors.hairline(),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: PGTextStyles.button.copyWith(
              color: selected ? PGColors.paper : PGColors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    return onTap == null ? pill : PGPressable(onTap: onTap, pressedScale: 0.96, child: pill);
  }
}

/// Small status tag (e.g. MATCHED, AUTO-DRAFT, over-SLA) — a coloured
/// background/foreground pair from the status palette, not a tappable
/// control.
enum PGTagTone { success, warning, danger, auto, neutral }

class PGTag extends StatelessWidget {
  const PGTag({super.key, required this.label, this.tone = PGTagTone.neutral});

  final String label;
  final PGTagTone tone;

  (Color, Color) get _colors => switch (tone) {
        PGTagTone.success => (PGColors.successBg, PGColors.successFg),
        PGTagTone.warning => (PGColors.warningBg, PGColors.warningFg),
        PGTagTone.danger => (PGColors.dangerBg, PGColors.dangerFg),
        PGTagTone.auto => (PGColors.autoTagBg, PGColors.autoFg),
        PGTagTone.neutral => (PGColors.clayDeep, PGColors.textMid),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PGRadius.pill)),
      child: Text(
        label.toUpperCase(),
        style: PGTextStyles.tag.copyWith(color: fg),
      ),
    );
  }
}
