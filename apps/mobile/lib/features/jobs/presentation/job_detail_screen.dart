import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../../documents/data/document_repository.dart';
import '../../payments/data/payment_repository.dart';
import '../data/job_repository.dart';
import '../data/models/job_summary.dart';

/// Job detail — approved screen #7: current stage card, hold/cancel
/// banner, eight-stage timeline, the approval card (Approve /
/// Request a change) wired to `respond-to-design`, a payment section
/// (PG-009), and (PG-011) the generated documents list.
///
/// Payment is bank-transfer only (no gateway is specified — see
/// docs/payments.md): this screen lets a customer request the
/// deposit/balance and see its status, but cannot show a "Pay now" card
/// for a card/USSD flow that doesn't exist. Documents (PGJO/PGAO) show
/// a "View" button once generated — viewing opens a signed URL (shown
/// in a dialog for now; no in-app document viewer was built).
///
/// UNTESTED against a live backend.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen(
      {super.key, required this.jobId, required this.jobRepository});

  final String jobId;
  final JobRepository jobRepository;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late final _paymentRepository = PaymentRepository(Supabase.instance.client);
  late final _documentRepository = DocumentRepository(Supabase.instance.client);

  JobDetail? _detail;
  List<Map<String, dynamic>> _history = [];
  PaymentRecord? _depositPayment;
  Set<String> _availableDocuments = {};
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
      final history =
          await widget.jobRepository.fetchStageHistory(widget.jobId);
      final deposit =
          await _paymentRepository.fetchLatestForJob(widget.jobId, 'deposit');
      final documents =
          await _documentRepository.fetchAvailableTypes(widget.jobId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _history = history;
        _depositPayment = deposit;
        _availableDocuments = documents;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'Could not load this job. Check your connection.');
    }
  }

  Future<void> _viewDocument(String type) async {
    try {
      final url = await _documentRepository.requestUrl(widget.jobId, type);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$type — signed URL (expires in 5 minutes)'),
          content: SelectableText(url),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'))
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// "Controlled WhatsApp handoff" (Master Spec §6 V1 bullet, distinct
  /// from V2's "Transactional WhatsApp" — this is a manual link to a
  /// human conversation, not automated messaging). Uses the company's
  /// already-known WhatsApp number (visible on HomeScreen, PG-006), not
  /// a new company detail invented here. Shows the wa.me link rather
  /// than launching it directly — no URL-launching package is declared
  /// in this project, and adding an unverified new dependency felt
  /// riskier than showing the link for the person to open themselves,
  /// matching the same choice made for signed URLs throughout PG-010/011.
  void _openWhatsAppHandoff(String jobRef) {
    final message = Uri.encodeComponent('Hi, I need help with job $jobRef.');
    final url = 'https://wa.me/2349152493122?text=$message';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue on WhatsApp'),
        content: SelectableText(url),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'))
        ],
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(
            PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request a change',
                style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(
              controller: noteController,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(
                  hintText: 'What would you like changed?'),
            ),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(
              label: 'Send',
              onPressed: () =>
                  Navigator.of(context).pop(noteController.text.trim()),
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

  Future<void> _requestDepositPayment() async {
    setState(() => _submitting = true);
    try {
      await _paymentRepository.requestPayment(
          jobId: widget.jobId, kind: 'deposit');
      if (!mounted) return;
      showPGToast(context,
          'Deposit payment requested — Pro_Grafiz will confirm it once received.');
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

  Widget _buildContent(JobDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back, color: PGColors.ink),
                  onPressed: () => Navigator.of(context).pop()),
              Text(detail.jobRef,
                  style:
                      PGTextStyles.screenTitle.copyWith(color: PGColors.ink)),
            ],
          ),
          const SizedBox(height: PGSpacing.groupGap),
          if (detail.status == 'on_hold')
            _buildBanner('On hold', detail.holdReason, detail.holdNote,
                PGColors.warningBg, PGColors.warningFg),
          if (detail.status == 'cancelled')
            _buildBanner('Cancelled', detail.cancelReason, detail.cancelNote,
                PGColors.dangerBg, PGColors.dangerFg),
          if (detail.status != 'active')
            const SizedBox(height: PGSpacing.groupGap),
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
                  Text(
                      'Total: ₦${(detail.totalKobo! / 100).toStringAsFixed(0)}',
                      style: PGTextStyles.body.copyWith(color: PGColors.paper)),
                ],
              ],
            ),
          ),
          const SizedBox(height: PGSpacing.sectionGap),
          const PGSectionHeader(title: 'Stages'),
          const SizedBox(height: PGSpacing.groupGap),
          ...jobStages.map((stage) {
            final reached = jobStages.indexOf(stage) <=
                jobStages.indexOf(detail.currentStage);
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
                    style: PGTextStyles.body.copyWith(
                        color: reached ? PGColors.ink : PGColors.textFaint),
                  ),
                ],
              ),
            );
          }),
          if (detail.currentStage == 'SUBMITTED' &&
              detail.status == 'active') ...[
            const SizedBox(height: PGSpacing.sectionGap),
            const PGSectionHeader(title: 'Deposit payment'),
            const SizedBox(height: PGSpacing.groupGap),
            PGCard(
              child: _depositPayment == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No deposit payment requested yet. Payment is by bank transfer '
                          'only for now — Pro_Grafiz will confirm it once received.',
                          style: PGTextStyles.body
                              .copyWith(color: PGColors.textMid),
                        ),
                        const SizedBox(height: PGSpacing.groupGap),
                        PGPrimaryButton(
                          label: 'Request deposit payment',
                          onPressed:
                              _submitting ? null : _requestDepositPayment,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₦${(_depositPayment!.amountKobo / 100).toStringAsFixed(0)}',
                              style: PGTextStyles.numeric
                                  .copyWith(color: PGColors.ink),
                            ),
                            if (_depositPayment!.bankReference != null)
                              Text(
                                'Ref: ${_depositPayment!.bankReference}',
                                style: PGTextStyles.caption
                                    .copyWith(color: PGColors.textSoft),
                              ),
                          ],
                        ),
                        PGTag(
                          label: _depositPayment!.status.replaceAll('_', ' '),
                          tone: switch (_depositPayment!.status) {
                            'confirmed' => PGTagTone.success,
                            'no_match' || 'failed' => PGTagTone.danger,
                            'matched' => PGTagTone.warning,
                            _ => PGTagTone.neutral,
                          },
                        ),
                      ],
                    ),
            ),
          ],
          if (_availableDocuments.isNotEmpty) ...[
            const SizedBox(height: PGSpacing.sectionGap),
            const PGSectionHeader(title: 'Documents'),
            const SizedBox(height: PGSpacing.groupGap),
            Row(
              children: [
                if (_availableDocuments.contains('PGJO'))
                  Expanded(
                    child: PGSecondaryButton(
                        label: 'View PGJO',
                        onPressed: () => _viewDocument('PGJO')),
                  ),
                if (_availableDocuments.contains('PGJO') &&
                    _availableDocuments.contains('PGAO'))
                  const SizedBox(width: 8),
                if (_availableDocuments.contains('PGAO'))
                  Expanded(
                    child: PGSecondaryButton(
                        label: 'View PGAO',
                        onPressed: () => _viewDocument('PGAO')),
                  ),
              ],
            ),
          ],
          const SizedBox(height: PGSpacing.sectionGap),
          PGSecondaryButton(
            label: 'Need help? Continue on WhatsApp',
            onPressed: () => _openWhatsAppHandoff(detail.jobRef),
          ),
          if (detail.currentStage == 'DESIGN_SENT_FOR_APPROVAL' &&
              detail.status == 'active') ...[
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
                          onPressed: (_submitting || !detail.hasReleasedDraft)
                              ? null
                              : _approve,
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

  Widget _buildBanner(
      String title, String? reason, String? note, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(PGRadius.smallNote)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: PGTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700, color: fg)),
          if (reason != null)
            Text(reason, style: PGTextStyles.caption.copyWith(color: fg)),
          if (note != null)
            Text(note, style: PGTextStyles.caption.copyWith(color: fg)),
        ],
      ),
    );
  }
}
