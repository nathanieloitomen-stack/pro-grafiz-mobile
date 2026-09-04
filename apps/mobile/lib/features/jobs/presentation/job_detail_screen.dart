import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/job_repository.dart';
import '../data/models/job_summary.dart';

/// Job detail — approved screen #7: current stage card, hold/cancel
/// banner, eight-stage timeline, and the approval card (Approve /
/// Request a change), wired to `respond-to-design`.
///
/// Deliberately NOT shown here (need later tasks): the payment card
/// (PG-009) and the documents list (PG-011) — both tables already have
/// correct customer-read RLS from PG-005, so this screen queries them
/// gracefully and just shows nothing if empty, rather than faking data
/// or blocking on those tasks.
///
/// UNTESTED against a live backend.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId, required this.jobRepository});

  final String jobId;
  final JobRepository jobRepository;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  JobDetail? _detail;
  List<Map<String, dynamic>> _history = [];
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.jobRepository.fetchJobDetail(widget.jobId);
      final history = await widget.jobRepository.fetchStageHistory(widget.jobId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _history = history;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this job. Check your connection.');
    }
  }

  Future<void> _approve() async {
    setState(() => _submitting = true);
    try {
      await widget.jobRepository.approve(widget.jobId);
      if (!mounted) return;
      showPGToast(context, 'Design approved — moving to production.');
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestChange() async {
    final noteController = TextEditingController();
    final note = await showPGBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request a change', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(
              controller: noteController,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(hintText: 'What would you like changed?'),
            ),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(
              label: 'Send',
              onPressed: () => Navigator.of(context).pop(noteController.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (note == null || note.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.jobRepository.requestChange(widget.jobId, note);
      if (!mounted) return;
      showPGToast(context, 'Change request sent to the design desk.');
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _detail == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(_detail!),
      ),
    );
  }

  Widget _buildContent(JobDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: PGColors.ink), onPressed: () => Navigator.of(context).pop()),
              Text(detail.jobRef, style: PGTextStyles.screenTitle.copyWith(color: PGColors.ink)),
            ],
          ),
          const SizedBox(height: PGSpacing.groupGap),

          if (detail.status == 'on_hold') _buildBanner('On hold', detail.holdReason, detail.holdNote, PGColors.warningBg, PGColors.warningFg),
          if (detail.status == 'cancelled') _buildBanner('Cancelled', detail.cancelReason, detail.cancelNote, PGColors.dangerBg, PGColors.dangerFg),
          if (detail.status != 'active') const SizedBox(height: PGSpacing.groupGap),

          PGHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PGLabel('Current stage', color: PGColors.textFaint),
                const SizedBox(height: 4),
                Text(
                  detail.currentStage.replaceAll('_', ' '),
                  style: PGTextStyles.cardTitle.copyWith(color: PGColors.paper),
                ),
                if (detail.totalKobo != null) ...[
                  const SizedBox(height: 8),
                  Text('Total: ₦${(detail.totalKobo! / 100).toStringAsFixed(0)}', style: PGTextStyles.body.copyWith(color: PGColors.paper)),
                ],
              ],
            ),
          ),

          const SizedBox(height: PGSpacing.sectionGap),
          const PGSectionHeader(title: 'Stages'),
          const SizedBox(height: PGSpacing.groupGap),
          ...jobStages.map((stage) {
            final reached = jobStages.indexOf(stage) <= jobStages.indexOf(detail.currentStage);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    reached ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: reached ? PGColors.ember : PGColors.textFaint,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    stage.replaceAll('_', ' '),
                    style: PGTextStyles.body.copyWith(color: reached ? PGColors.ink : PGColors.textFaint),
                  ),
                ],
              ),
            );
          }),

          if (detail.currentStage == 'DESIGN_SENT_FOR_APPROVAL' && detail.status == 'active') ...[
            const SizedBox(height: PGSpacing.sectionGap),
            const PGSectionHeader(title: 'Approve your design'),
            const SizedBox(height: PGSpacing.groupGap),
            PGCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.hasReleasedDraft
                        ? 'Your design is ready for review.'
                        : 'Your design is still being prepared — check back soon.',
                    style: PGTextStyles.body.copyWith(color: PGColors.textMid),
                  ),
                  const SizedBox(height: PGSpacing.groupGap),
                  Row(
                    children: [
                      Expanded(
                        child: PGSecondaryButton(
                          label: 'Request a change',
                          onPressed: _submitting ? null : _requestChange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PGPrimaryButton(
                          label: 'Approve',
                          onPressed: (_submitting || !detail.hasReleasedDraft) ? null : _approve,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: PGSpacing.screenBottomForNav),
        ],
      ),
    );
  }

  Widget _buildBanner(String title, String? reason, String? note, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PGRadius.smallNote)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: fg)),
          if (reason != null) Text(reason, style: PGTextStyles.caption.copyWith(color: fg)),
          if (note != null) Text(note, style: PGTextStyles.caption.copyWith(color: fg)),
        ],
      ),
    );
  }
}
