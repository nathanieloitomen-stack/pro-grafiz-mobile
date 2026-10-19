import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../../auth/data/auth_repository.dart';
import '../data/catalogue_repository.dart';
import '../data/models/pattern_detail.dart';
import 'configure_screen.dart';

/// Approved design screen #3, "Design detail". The approved design
/// also includes a 4-step material-recolouring zoom slider and a gated
/// DXF download for customers who hold a `dxf_release_grants` entry —
/// both are simplified here: material pills are shown but only recolour
/// a flat swatch (not the actual plate geometry, which needs the real
/// SVG rendering pipeline — a later task), and the DXF download itself
/// is not wired up (that's the signed-URL flow from Master Spec §14,
/// explicitly a later PG task, not part of "PGLC Catalogue").
/// "Request a quote" routes to [ConfigureScreen] — configuring a spec is
/// this task's scope; actually submitting it needs the Quote Engine
/// (PG-007), not built yet.
///
/// UNTESTED against a live backend.
class PatternDetailScreen extends StatefulWidget {
  const PatternDetailScreen({
    super.key,
    required this.patternId,
    required this.catalogueRepository,
    required this.authRepository,
  });

  final String patternId;
  final CatalogueRepository catalogueRepository;
  final AuthRepository authRepository;

  @override
  State<PatternDetailScreen> createState() => _PatternDetailScreenState();
}

class _PatternDetailScreenState extends State<PatternDetailScreen> {
  PatternDetail? _detail;
  String? _error;

  static const _materialSwatches = <String, Color>{
    'Mild steel': PGMaterialColors.mildSteelFill,
    'Stainless': PGMaterialColors.stainlessFill,
    'Aluminium': PGMaterialColors.aluminiumFill,
    'Corten': PGMaterialColors.cortenFill,
  };
  String _selectedMaterialLabel = 'Mild steel';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail =
          await widget.catalogueRepository.fetchPatternDetail(widget.patternId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'Could not load this design. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style:
                        PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _detail == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(_detail!),
      ),
    );
  }

  Widget _buildContent(PatternDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: PGColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: _materialSwatches[_selectedMaterialLabel],
                borderRadius: BorderRadius.circular(PGRadius.heroCard),
              ),
              alignment: Alignment.center,
              child: Text(
                detail.name,
                textAlign: TextAlign.center,
                style: PGTextStyles.cardTitle.copyWith(color: PGColors.paper),
              ),
            ),
          ),
          const SizedBox(height: PGSpacing.groupGap),
          Wrap(
            spacing: 8,
            children: [
              for (final label in _materialSwatches.keys)
                PGPressable(
                  onTap: () => setState(() => _selectedMaterialLabel = label),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _materialSwatches[label],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedMaterialLabel == label
                            ? PGColors.ember
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PGSpacing.sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(detail.name,
                    style:
                        PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
              ),
              IconButton(
                icon: Icon(
                  detail.isFavourited ? Icons.favorite : Icons.favorite_border,
                  color:
                      detail.isFavourited ? PGColors.ember : PGColors.textFaint,
                ),
                onPressed:
                    () {}, // favouriting from detail mirrors PatternsScreen's toggle — omitted here to avoid duplicating that logic; see docs/catalogue.md
              ),
            ],
          ),
          Text(
            '${detail.pglcCode} · ${detail.categoryName}',
            style: PGTextStyles.meta.copyWith(color: PGColors.textSoft),
          ),
          const SizedBox(height: PGSpacing.groupGap),
          Wrap(
            spacing: 8,
            children: [
              PGTag(
                  label: detail.hasSvg ? 'SVG ready' : 'SVG pending',
                  tone: detail.hasSvg ? PGTagTone.success : PGTagTone.neutral),
              PGTag(
                label: detail.hasDxf ? 'DXF on file' : 'DXF pending',
                tone: detail.hasDxf ? PGTagTone.success : PGTagTone.neutral,
              ),
              const PGTag(label: 'Cut-ready geometry', tone: PGTagTone.neutral),
            ],
          ),
          const SizedBox(height: PGSpacing.sectionGap),
          PGCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Category', detail.categoryName),
                if (detail.minThicknessMm != null)
                  _detailRow(
                      'Minimum thickness', '${detail.minThicknessMm} mm'),
                if (detail.typicalUses != null)
                  _detailRow('Typical uses', detail.typicalUses!),
              ],
            ),
          ),
          if (detail.categoryDescription != null) ...[
            const SizedBox(height: PGSpacing.groupGap),
            Text(detail.categoryDescription!,
                style: PGTextStyles.body.copyWith(color: PGColors.textMid)),
          ],
          if (detail.engineeringNote != null) ...[
            const SizedBox(height: PGSpacing.groupGap),
            PGLabel('Engineering note', color: PGColors.textSoft),
            const SizedBox(height: 4),
            Text(detail.engineeringNote!,
                style: PGTextStyles.body.copyWith(color: PGColors.textMid)),
          ],
          const SizedBox(height: PGSpacing.sectionGap),
          PGPrimaryButton(
            label: 'Configure this design',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConfigureScreen(
                  patternId: detail.id,
                  patternName: detail.name,
                  catalogueRepository: widget.catalogueRepository,
                ),
              ),
            ),
          ),
          const SizedBox(height: PGSpacing.screenBottomForNav),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PGSpacing.labelToValue),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PGLabel(label, color: PGColors.textSoft),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: PGTextStyles.body.copyWith(color: PGColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
