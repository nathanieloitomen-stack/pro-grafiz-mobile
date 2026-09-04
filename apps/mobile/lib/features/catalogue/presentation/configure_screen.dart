import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../../quoting/data/quote_repository.dart';
import '../data/catalogue_repository.dart';
import '../data/models/material_option.dart';

/// Material/thickness/dimensions/finish configuration — the one part of
/// the approved "Quote builder" screen (#6) that belongs to PG-006
/// ("PGLC Catalogue") per Master Spec §6's V1 bullet list, which lists
/// "Material/thickness/dimensions/finish configuration" as its own line
/// item separate from "Server-side quotation engine" and "Quote
/// request/intake".
///
/// PG-007 update: the summary card now calls the real `estimate-quote`
/// Edge Function (public, no session required) for a live ₦ total —
/// but until a Super Admin configures `pricing_rates`/
/// `commercial_settings`, that function always honestly reports
/// "pricing not available yet" rather than a fabricated number, so
/// that's what this screen shows too. See docs/quote-engine.md.
///
/// PG-008 update: "Send to Pro_Grafiz" now submits a real
/// `quote_requests` row (customer's own default branch, this screen's
/// configured spec) — "Customer Job Flow" (PG-008) is the "designated
/// quotation workflow task" earlier reviews deferred this to. Staff
/// review/accept/decline it server-side (`decide-quote-request`, no
/// staff UI built in this task — see docs/customer-job-flow.md for why).
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
  late final _quoteRepository = QuoteRepository(Supabase.instance.client);

  List<MaterialOption> _materials = [];
  List<FinishOption> _finishes = [];
  String? _error;

  MaterialOption? _selectedMaterial;
  double? _selectedThickness;
  double _width = 900;
  double _height = 900;
  FinishOption? _selectedFinish;

  QuoteEstimate? _estimate;
  bool _estimating = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selectedMaterial == null || _selectedFinish == null || _selectedThickness == null) return;
    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        throw Exception('Sign in as a customer to send a request.');
      }
      final customerRow = await client.from('customers').select('id, default_branch_id').maybeSingle();
      if (customerRow == null) {
        throw Exception('Only a customer account can send a request — staff use the Intake flow.');
      }
      if (customerRow['default_branch_id'] == null) {
        throw Exception('Your account has no default centre set — contact Pro_Grafiz to set one.');
      }
      await client.from('quote_requests').insert({
        'customer_id': customerRow['id'],
        'branch_id': customerRow['default_branch_id'],
        'pattern_id': widget.patternId,
        'material_id': _selectedMaterial!.id,
        'finish_id': _selectedFinish!.id,
        'thickness_mm': _selectedThickness,
        'width_mm': _width,
        'height_mm': _height,
      });
      if (!mounted) return;
      showPGToast(context, 'Request sent — we\'ll notify you once it\'s reviewed.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
      _fetchEstimate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load material and finish options. Check your connection.');
    }
  }

  Future<void> _fetchEstimate() async {
    if (_selectedMaterial == null || _selectedFinish == null || _selectedThickness == null) return;
    setState(() => _estimating = true);
    try {
      final estimate = await _quoteRepository.estimate(
        materialId: _selectedMaterial!.id,
        finishId: _selectedFinish!.id,
        thicknessMm: _selectedThickness!,
        widthMm: _width,
        heightMm: _height,
      );
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _estimating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estimate = const QuoteEstimate(available: false, reason: 'Could not reach the pricing service.');
        _estimating = false;
      });
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
                  onTap: () {
                    setState(() {
                      _selectedMaterial = material;
                      _selectedThickness = material.thicknesses.isNotEmpty ? material.thicknesses.first : null;
                    });
                    _fetchEstimate();
                  },
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
              onChangeEnd: (_) => _fetchEstimate(),
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
            onChangeEnd: (_) => _fetchEstimate(),
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
            onChangeEnd: (_) => _fetchEstimate(),
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
                  onTap: () {
                    setState(() => _selectedFinish = finish);
                    _fetchEstimate();
                  },
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
                const SizedBox(height: 12),
                Container(height: 1, color: PGColors.paper.withOpacity(0.15)),
                const SizedBox(height: 12),
                if (_estimating)
                  Text('Getting a price…', style: PGTextStyles.meta.copyWith(color: PGColors.paper.withOpacity(0.8)))
                else if (_estimate == null)
                  Text('—', style: PGTextStyles.numeric.copyWith(color: PGColors.paper))
                else if (_estimate!.available)
                  Text(
                    '₦${_formatKobo(_estimate!.totalKobo!)}',
                    style: PGTextStyles.numeric.copyWith(color: PGColors.paper, fontSize: 24),
                  )
                else
                  Text(
                    _estimate!.reason ?? 'Pricing not available yet.',
                    style: PGTextStyles.meta.copyWith(color: PGColors.paper.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PGSpacing.groupGap),
          PGPrimaryButton(
            label: _submitting ? 'Sending…' : 'Send to Pro_Grafiz',
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 8),
          Text(
            'Sending creates a request for Pro_Grafiz to review — you\'ll be '
            'notified once it\'s accepted or declined. A live estimate shows '
            'above when pricing is configured, but isn\'t required to send.',
            style: PGTextStyles.caption.copyWith(color: PGColors.textFaint),
          ),
          const SizedBox(height: PGSpacing.screenBottomForNav),
        ],
      ),
    );
  }

  String _formatKobo(int kobo) {
    final naira = kobo / 100;
    final wholePart = naira.floor();
    final withCommas = wholePart.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
    return withCommas;
  }
}
