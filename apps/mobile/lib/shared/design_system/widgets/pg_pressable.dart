import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Wraps [child] with the approved design's only tap feedback: a scale
/// shrink on press, no ripple/hover (the product is touch-only). Use
/// this under custom tappable surfaces (cards, tiles) that aren't a
/// stock Material button — buttons already get press feedback via
/// [PGTheme]'s `splashFactory: NoSplash` plus this same scale approach
/// where wrapped explicitly.
class PGPressable extends StatefulWidget {
  const PGPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = PGMotion.pressScaleMax,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Approved range is .92–.98 depending on element size; default to the
  /// gentler end and override for small tappable icons/pills.
  final double pressedScale;

  @override
  State<PGPressable> createState() => _PGPressableState();
}

class _PGPressableState extends State<PGPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: PGMotion.riseMin,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
