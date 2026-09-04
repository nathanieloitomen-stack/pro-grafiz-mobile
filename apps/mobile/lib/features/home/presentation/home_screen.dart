import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../../auth/data/auth_repository.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/data/models/pattern_summary.dart';
import '../../catalogue/presentation/pattern_detail_screen.dart';
import '../../catalogue/presentation/patterns_screen.dart';

/// Catalogue-relevant portions of approved design screen #1, "Home".
///
/// Deliberately NOT built here (each needs a later PG task, not this
/// one): the live job card (needs real job data — PG-008), the
/// scan-a-sketch card (Camera scan flow, deferred with Blend — see
/// docs/catalogue.md), and the "Start a job" shortcut's own distinct
/// destination (it currently routes to the same place as "Browse
/// patterns" since there is no job-creation flow yet to send it to).
/// The service lines, testimonial, and address/WhatsApp footer are
/// static approved copy, included since they cost nothing to build
/// correctly now.
///
/// UNTESTED against a live backend.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.catalogueRepository, required this.authRepository});

  final CatalogueRepository catalogueRepository;
  final AuthRepository authRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PatternSummary> _featured = [];

  @override
  void initState() {
    super.initState();
    widget.catalogueRepository.searchPatterns(limit: 5).then((results) {
      if (!mounted) return;
      setState(() => _featured = results);
    }).catchError((_) {});
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: PGSpacing.screenHorizontal,
            vertical: PGSpacing.screenTopMax,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: PGTextStyles.hero.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.sectionGap),

              Row(
                children: [
                  Expanded(
                    child: _ShortcutTile(
                      label: 'Start a job',
                      onTap: () => _openPatterns(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShortcutTile(
                      label: 'Browse patterns',
                      onTap: () => _openPatterns(context),
                    ),
                  ),
                ],
              ),

              if (_featured.isNotEmpty) ...[
                const SizedBox(height: PGSpacing.sectionGap),
                PGSectionHeader(
                  title: 'Suggested designs',
                  trailing: TextButton(
                    onPressed: () => _openPatterns(context),
                    child: Text('See all', style: PGTextStyles.button.copyWith(color: PGColors.ember)),
                  ),
                ),
                const SizedBox(height: PGSpacing.groupGap),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _featured.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final pattern = _featured[index];
                      return PGPressable(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatternDetailScreen(
                              patternId: pattern.id,
                              catalogueRepository: widget.catalogueRepository,
                              authRepository: widget.authRepository,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: PGColors.clayDeep,
                            borderRadius: BorderRadius.circular(PGRadius.thumbnail),
                          ),
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            pattern.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: PGSpacing.sectionGap),
              const PGSectionHeader(title: 'What we do'),
              const SizedBox(height: PGSpacing.groupGap),
              ..._serviceLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line, style: PGTextStyles.body.copyWith(color: PGColors.ink)),
                      const Divider(color: PGColors.clayDeep, height: 1),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: PGSpacing.sectionGap),
              PGClayCard(
                child: Text(
                  '"Pro_Grafiz turned our gate design around faster than we expected, '
                  'and the finish was exactly what we asked for."',
                  style: PGTextStyles.quote.copyWith(color: PGColors.textWarm),
                ),
              ),

              const SizedBox(height: PGSpacing.sectionGap),
              Text('Abuja & Lagos · WhatsApp +234 915 249 3122', style: PGTextStyles.caption.copyWith(color: PGColors.textFaint)),
              const SizedBox(height: PGSpacing.screenBottomForNav),
            ],
          ),
        ),
      ),
    );
  }

  void _openPatterns(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatternsScreen(
          catalogueRepository: widget.catalogueRepository,
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  static const _serviceLines = [
    'Architectural metal screens and gates',
    'Decorative laser-cut panels',
    'Precision CNC fabrication',
    'Custom blends and bespoke patterns',
    'Installation and finishing',
    'Maintenance and repair',
  ];
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PGPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PGRadius.jobCard),
          border: Border.all(color: PGColors.hairline()),
        ),
        child: Text(label, style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink)),
      ),
    );
  }
}
