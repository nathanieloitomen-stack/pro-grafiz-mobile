import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Section heading used to introduce a group of content within a screen
/// (not a screen title — see [PGTextStyles.screenTitle] for that).
/// Optional trailing action (e.g. "See all").
class PGSectionHeader extends StatelessWidget {
  const PGSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: PGTextStyles.sectionHead.copyWith(color: PGColors.ink)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small uppercase eyebrow label (e.g. field labels, meta headers).
class PGLabel extends StatelessWidget {
  const PGLabel(this.text, {super.key, this.color = PGColors.textSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: PGTextStyles.label.copyWith(color: color));
  }
}
