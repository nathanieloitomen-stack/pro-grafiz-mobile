import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Dark hero/summary card (e.g. the Home live-job card, quote builder
/// summary): ink background, paper text, the one "dark hero card" shadow.
class PGHeroCard extends StatelessWidget {
  const PGHeroCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PGColors.ink,
        borderRadius: BorderRadius.circular(PGRadius.heroCard),
        boxShadow: PGShadows.darkHeroCard,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PGColors.paper),
        child: child,
      ),
    );
  }
}

/// Light card on a warm paper background — the default list/detail card
/// surface used across most screens.
class PGCard extends StatelessWidget {
  const PGCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = PGRadius.jobCard,
    this.background = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: PGColors.hairline()),
      ),
      child: child,
    );
  }
}

/// Accent card on clay — testimonials, CTA blocks, promotional inserts.
class PGClayCard extends StatelessWidget {
  const PGClayCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PGColors.clay,
        borderRadius: BorderRadius.circular(PGRadius.heroCard),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PGColors.textWarm),
        child: child,
      ),
    );
  }
}
