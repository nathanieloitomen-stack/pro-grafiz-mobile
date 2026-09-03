import 'package:flutter/material.dart';

import 'shared/design_system/design_system.dart';

/// Pro_Grafiz mobile entry point.
///
/// PG-001 (Foundation) + PG-002 (Design System): the app now has a real
/// theme and a small library of generic, content-free components
/// (`shared/design_system/`), but still no screens, navigation, or
/// business logic. Customer and staff feature screens are built starting
/// with later PG tasks (PG-006 onward).
void main() {
  runApp(const ProGrafizApp());
}

class ProGrafizApp extends StatelessWidget {
  const ProGrafizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro_Grafiz',
      debugShowCheckedModeBanner: false,
      theme: PGTheme.light(),
      home: const _DesignSystemPlaceholder(),
    );
  }
}

/// Temporary home screen proving the theme and a few base components
/// render correctly. Replaced by the real customer Home screen in a
/// later PG task — do not extend this with feature content.
class _DesignSystemPlaceholder extends StatelessWidget {
  const _DesignSystemPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PGSpacing.screenHorizontal,
            vertical: PGSpacing.screenTopMax,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pro_Grafiz', style: PGTextStyles.hero.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.groupGap),
              const PGLabel('Design system — PG-002'),
              const SizedBox(height: PGSpacing.sectionGap),
              Wrap(
                spacing: 8,
                children: const [
                  PGPill(label: 'All', selected: true),
                  PGPill(label: 'Geometric Lattice'),
                  PGTag(label: 'Matched', tone: PGTagTone.success),
                  PGTag(label: 'No match', tone: PGTagTone.danger),
                ],
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              PGHeroCard(
                child: Text(
                  'Deposit confirmed',
                  style: PGTextStyles.cardTitle.copyWith(color: PGColors.paper),
                ),
              ),
              const Spacer(),
              PGPrimaryButton(label: 'Primary action', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
