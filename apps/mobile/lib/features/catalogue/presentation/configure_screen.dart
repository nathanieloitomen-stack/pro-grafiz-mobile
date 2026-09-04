import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/catalogue_repository.dart';
import '../data/models/material_option.dart';

/// Material/thickness/dimensions/finish configuration — the one part of
/// the approved "Quote builder" screen (#6) that belongs to PG-006
/// ("PGLC Catalogue") per Master Spec §6's V1 bullet list, which lists
/// "Material/thickness/dimensions/finish configuration" as its own line
/// item separate from "Server-side quotation engine" and "Quote
/// request/intake".
///
/// Deliberately NOT built here: the live ₦ estimate, sheet count, and
/// lead time (all require the Quote Engine, PG-007) and the
/// "Send to Pro_Grafiz" submission itself (Quote request/intake,
/// PG-008) — even though `quote_requests` already has a working RLS
/// INSERT policy for customers from PG-005, wiring an actual submission
/// here would mean building a customer journey step this task wasn't
/// authorized for. The button below is intentionally inert, with an
/// explanation, rather than either a fake success state or a silent
/// no-op.
///
/// UNTESTED against a live backend.
class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({
    super.key,
    required this.patternId,
    required this.patternName,
    required this.catalogueRepository,
  });

  final String patternId;
  final String patternName;
  final CatalogueRepository catalogueRepository;

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  List<MaterialOption> _materials = [];
  List<FinishOption> _finishes = [];
  String? _error;

  MaterialOption? _selectedMaterial;
  double? _selectedThickness;
  double _width = 900;
  double _height = 900;
  FinishOption? _selectedFinish;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final materials = await widget.catalogueRepository.fetchMaterials();
      final finishes = await widget.catalogueRepository.fetchFinishes();
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _finishes = finishes;
        _selectedMaterial = materials.isNotEmpty ? materials.first : null;
        _selectedThickness = _selectedMaterial?.thicknesses.isNotEmpty == true
            ? _selectedMaterial!.thicknesses.first
            : null;
        _selectedFinish = finishes.isNotEmpty ? finishes.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load material and finish options. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Configure', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _materials.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.patternName, style: PGTextStyles.sectionHead.copyWith(color: PGColors.ink)),
          const SizedBox(height: PGSpacing.sectionGap),

          const PGLabel('Material'),
          const SizedBox(height: PGSpacing.labelToValue),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3,
            children: [
              for (final material in _materials)
                PGPill(
                  label: material.name,
                  selected: _selectedMaterial?.id == material.id,
                  onTap: () => setState(() {
                    _selectedMaterial = material;
                    _selectedThickness = material.thicknesses.isNotEmpty ? material.thicknesses.first : null;
                  }),
                ),
            ],
          ),

          const SizedBox(height: PGSpacing.sectionGap),
          const PGLabel('Thickness'),
          const SizedBox(height: PGSpacing.labelToValue),
          if (_selectedMaterial != null && _selectedMaterial!.thicknesses.isNotEmpty)
            Slider(
              value: _selectedThickness ?? _selectedMaterial!.thicknesses.first,
              min: _selectedMaterial!.thicknesses.first,
              max: _selectedMaterial!.thicknesses.last,
              divisions: _selectedMaterial!.thicknesses.length > 1
                  ? _selectedMaterial!.thicknesses.length - 1
                  : null,
              activeColor: PGColors.ember,
              label: '${_selectedThickness?.toStringAsFixed(1)} mm',
              onChanged: (v) => setState(() => _selectedThickness = v),
            )
          else
            Text('No thickness options for this material yet.', style: PGTextStyles.caption.copyWith(color: PGColors.textFaint)),

          const SizedBox(height: PGSpacing.sectionGap),
          const PGLabel('Width'),
          const SizedBox(height: PGSpacing.labelToValue),
          Slider(
            value: _width,
            min: 600,
            max: 3000,
            divisions: 24,
            activeColor: PGColors.ember,
            label: '${_width.round()} mm',
            onChanged: (v) => setState(() => _width = v),
          ),
          const PGLabel('Height'),
          const SizedBox(height: PGSpacing.labelToValue),
          Slider(
            value: _height,
            min: 600,
            max: 3000,
            divisions: 24,
            activeColor: PGColors.ember,
            label: '${_height.round()} mm',
            onChanged: (v) => setState(() => _height = v),
          ),

          const SizedBox(height: PGSpacing.sectionGap),
          const PGLabel('Finish'),
          const SizedBox(height: PGSpacing.labelToValue),
          Wrap(
            spacing: 8,
            children: [
              for (final finish in _finishes)
                PGPill(
                  label: finish.name,
                  selected: _selectedFinish?.id == finish.id,
                  onTap: () => setState(() => _selectedFinish = finish),
                ),
            ],
          ),

          const SizedBox(height: PGSpacing.sectionGap),
          PGHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your specification', style: PGTextStyles.cardTitle.copyWith(color: PGColors.paper, fontSize: 19)),
                const SizedBox(height: 8),
                Text(
                  '${_selectedMaterial?.name ?? '—'} · ${_selectedThickness?.toStringAsFixed(1) ?? '—'} mm\n'
                  '${_width.round()} × ${_height.round()} mm · ${_selectedFinish?.name ?? '—'}',
                  style: PGTextStyles.body.copyWith(color: PGColors.paper),
                ),
              ],
            ),
          ),
          const SizedBox(height: PGSpacing.groupGap),
          const PGPrimaryButton(
            label: 'Send to Pro_Grafiz',
            onPressed: null, // intentionally inert — see file header comment
          ),
          const SizedBox(height: 8),
          Text(
            'Pricing and quote submission arrive in a later stage of the build '
            '(Quote Engine and Quote Request/Intake) — this screen only covers '
            'the catalogue configuration step.',
            style: PGTextStyles.caption.copyWith(color: PGColors.textFaint),
          ),
          const SizedBox(height: PGSpacing.screenBottomForNav),
        ],
      ),
    );
  }
}
