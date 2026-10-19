import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Primary call-to-action: ember pill, paper text, 50–54px tall, subtle
/// ember shadow. Uses [ElevatedButton] under the hood so it inherits
/// [PGTheme]'s button styling; this wrapper mainly fixes height/shadow.
class PGPrimaryButton extends StatelessWidget {
  const PGPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.expand = true,
    this.testId,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Approved range is 50–54px.
  final double height;
  final bool expand;

  /// Stable automation identifier for E2E tests (Appetize). Optional.
  final String? testId;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PGRadius.pill),
          boxShadow: onPressed == null ? null : PGShadows.primaryCta,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
    final sized = expand ? button : IntrinsicWidth(child: button);
    // Non-visual: exposes a stable automation id (Android resource-id)
    // for E2E tests. No effect on layout or appearance.
    return testId == null ? sized : Semantics(identifier: testId, child: sized);
  }
}

/// Secondary action: ink/hairline outline on paper, no fill, no shadow.
class PGSecondaryButton extends StatelessWidget {
  const PGSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.expand = true,
    this.testId,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  /// Stable automation identifier for E2E tests (Appetize). Optional.
  final String? testId;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: PGColors.ink,
          side: BorderSide(color: PGColors.hairline(0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PGRadius.pill),
          ),
          textStyle: PGTextStyles.button,
        ),
        child: Text(label),
      ),
    );
    final sized = expand ? button : IntrinsicWidth(child: button);
    // Non-visual: exposes a stable automation id (Android resource-id)
    // for E2E tests. No effect on layout or appearance.
    return testId == null ? sized : Semantics(identifier: testId, child: sized);
  }
}
