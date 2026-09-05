import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/design_desk_repository.dart';

/// Draft review — approved screens #15/16 area ("Auto-draft review").
/// "Auto" in the approved design's name refers to draft GENERATION,
/// which is Master Spec §6 V2 scope ("SVG/DXF generation",
/// "Manufacturing checks" as automated capabilities) — this screen
/// deliberately does not generate or infer any geometry or check
/// result. A human designer uploads a real file they created elsewhere
/// and records what they found reviewing it against the five mandatory
/// checks; the release gate itself (enforce_draft_release_gate, PG-005)
/// is real and enforced regardless of whether the check was determined
/// by a human or, eventually, a machine.
///
/// UNTESTED against a live backend.
class DraftReviewScreen extends StatefulWidget {
  const DraftReviewScreen({super.key, required this.job, required this.repository});

  final DesignJob job;
  final DesignDeskRepository repository;

  @override
  State<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends State<DraftReviewScreen> {
  DraftRecord? _draft;
  List<DraftCheckResult> _checks = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drafts = await widget.repository.fetchDrafts(widget.job.id);
      final draft = drafts.isNotEmpty ? drafts.first : null;
      final checks = draft != null ? await widget.repository.fetchChecks(draft.id) : <DraftCheckResult>[];
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _checks = checks;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this job\'s design data.');
    }
  }

  Future<void> _startDesign() async {
    setState(() => _busy = true);
    try {
      await widget.repository.startDesign(widget.job.id);
      if (!mounted) return;
      showPGToast(context, 'Design started.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDraft() async {
    setState(() => _busy = true);
    try {
      final draft = await widget.repository.createDraft(widget.job.id);
      if (!mounted) return;
      setState(() => _draft = draft);
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordCheck(String checkKey, String result) async {
    if (_draft == null) return;
    try {
      await widget.repository.recordCheck(_draft!.id, checkKey, result);
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _viewFile(String assetType) async {
    if (_draft == null) return;
    try {
      final url = await widget.repository.requestFileUrl(_draft!.id, assetType);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Signed URL (expires in 5 minutes)'),
          content: SelectableText(url),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _uploadFile(String assetType) async {
    if (_draft == null) return;
    try {
      final result = await widget.repository.requestUploadUrl(_draft!.id, assetType);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upload URL — $assetType'),
          content: SelectableText(
            'PUT the file to this URL (upload not performed by this app — '
            'this is the signed URL a real upload client would use):\n\n${result['signed_url']}',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _release() async {
    final hasFailure = _checks.any((c) => c.result == 'fail');
    String? overrideReason;
    if (hasFailure) {
      final controller = TextEditingController();
      overrideReason = await showPGBottomSheet<String>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Override required', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
              const SizedBox(height: 5),
              Text(
                'A mandatory check failed. Releasing anyway requires a reason.',
                style: PGTextStyles.meta.copyWith(color: PGColors.textMid),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Reason for override')),
              const SizedBox(height: PGSpacing.groupGap),
              PGPrimaryButton(label: 'Release anyway', onPressed: () => Navigator.of(context).pop(controller.text.trim())),
            ],
          ),
        ),
      );
      if (overrideReason == null || overrideReason.isEmpty) return;
    }

    setState(() => _busy = true);
    try {
      await widget.repository.release(_draft!.id, overrideReason: overrideReason);
      if (!mounted) return;
      showPGToast(context, 'Draft released — sent to the customer for approval.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text(widget.job.jobRef, style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.job.currentStage == 'PAYMENT_CONFIRMED') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This job is paid and waiting for design work to start.', style: PGTextStyles.body.copyWith(color: PGColors.textMid)),
              const SizedBox(height: PGSpacing.groupGap),
              PGPrimaryButton(label: _busy ? 'Starting…' : 'Start design', onPressed: _busy ? null : _startDesign),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_draft == null) ...[
            Text('No draft yet for this job.', style: PGTextStyles.body.copyWith(color: PGColors.textMid)),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(label: _busy ? 'Creating…' : 'Create draft', onPressed: _busy ? null : _createDraft),
          ] else ...[
            PGCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Draft v${_draft!.version}', style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink)),
                  const SizedBox(height: 4),
                  PGTag(
                    label: _draft!.releaseStatus,
                    tone: _draft!.releaseStatus == 'released' ? PGTagTone.success : PGTagTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PGSpacing.groupGap),
            Row(
              children: [
                Expanded(child: PGSecondaryButton(label: 'Upload preview', onPressed: () => _uploadFile('preview'), expand: true)),
                const SizedBox(width: 8),
                Expanded(child: PGSecondaryButton(label: 'View preview', onPressed: () => _viewFile('preview'), expand: true)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: PGSecondaryButton(label: 'Upload DXF', onPressed: () => _uploadFile('production'), expand: true)),
                const SizedBox(width: 8),
                Expanded(child: PGSecondaryButton(label: 'View DXF', onPressed: () => _viewFile('production'), expand: true)),
              ],
            ),

            const SizedBox(height: PGSpacing.sectionGap),
            const PGSectionHeader(title: 'Mandatory checks'),
            const SizedBox(height: PGSpacing.groupGap),
            ...mandatoryCheckKeys.map((key) {
              final existing = _checks.where((c) => c.checkKey == key).cast<DraftCheckResult?>().firstWhere((_) => true, orElse: () => null);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(key.replaceAll('_', ' '), style: PGTextStyles.body.copyWith(color: PGColors.ink))),
                    DropdownButton<String>(
                      value: existing?.result,
                      hint: const Text('—'),
                      items: const [
                        DropdownMenuItem(value: 'pass', child: Text('Pass')),
                        DropdownMenuItem(value: 'warning', child: Text('Warning')),
                        DropdownMenuItem(value: 'fail', child: Text('Fail')),
                      ],
                      onChanged: (value) {
                        if (value != null) _recordCheck(key, value);
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: PGSpacing.sectionGap),
            if (_draft!.releaseStatus != 'released')
              PGPrimaryButton(label: _busy ? 'Releasing…' : 'Release', onPressed: _busy ? null : _release)
            else
              Text('Released — visible to the customer for approval.', style: PGTextStyles.body.copyWith(color: PGColors.successFg)),
          ],
          const SizedBox(height: PGSpacing.screenBottomForNav),
        ],
      ),
    );
  }
}
