import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/operations_repository.dart';

/// Job Queue — operational view across active jobs, with hold/resume/
/// cancel/reopen actions (PG-012, new). Visibility follows
/// `jobs_select_own_or_staff` (PG-005) exactly: a Centre Manager
/// session only ever receives their own branch's jobs from this
/// screen's query — there is no branch filter in this file at all,
/// because none is needed; RLS is the actual boundary.
///
/// Elapsed time in the current stage is shown as a plain fact (e.g.
/// "3h 20m in this stage") — deliberately NOT colored, flagged, or
/// compared against any threshold. No SLA threshold exists anywhere in
/// the docs (confirmed by direct search — see docs/operations.md); this
/// screen does not invent one.
///
/// UNTESTED against a live backend.
class JobQueueScreen extends StatefulWidget {
  const JobQueueScreen({super.key, required this.repository});

  final OperationsRepository repository;

  @override
  State<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends State<JobQueueScreen> {
  List<OperationalJob>? _jobs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.repository.fetchActiveJobs();
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load jobs.');
    }
  }

  Future<void> _hold(OperationalJob job) async {
    final controller = TextEditingController();
    final reason = await showPGBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hold ${job.jobRef}', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(controller: controller, maxLines: 2, decoration: const InputDecoration(hintText: 'Reason (required)')),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(label: 'Hold', onPressed: () => Navigator.of(context).pop(controller.text.trim())),
          ],
        ),
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => widget.repository.hold(job.id, reason), 'On hold.');
  }

  Future<void> _cancel(OperationalJob job) async {
    final controller = TextEditingController();
    final reason = await showPGBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel ${job.jobRef}', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(controller: controller, maxLines: 2, decoration: const InputDecoration(hintText: 'Reason (required)')),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(label: 'Cancel job', onPressed: () => Navigator.of(context).pop(controller.text.trim())),
          ],
        ),
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => widget.repository.cancel(job.id, reason), 'Cancelled.');
  }

  Future<void> _resume(OperationalJob job) => _run(() => widget.repository.resume(job.id), 'Resumed.');
  Future<void> _reopen(OperationalJob job) => _run(() => widget.repository.reopen(job.id), 'Reopened.');

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showPGToast(context, successMessage);
      _load();
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
        title: Text('Job Queue', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _jobs == null
                ? const Center(child: CircularProgressIndicator())
                : _jobs!.isEmpty
                    ? Center(child: Text('No active jobs.', style: PGTextStyles.body.copyWith(color: PGColors.textSoft)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _jobs!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = _jobs![index];
                          final elapsed = DateTime.now().difference(job.stageStartedAt);
                          return PGCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(job.jobRef, style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink)),
                                    PGTag(
                                      label: job.status.replaceAll('_', ' '),
                                      tone: switch (job.status) {
                                        'on_hold' => PGTagTone.warning,
                                        'cancelled' => PGTagTone.danger,
                                        _ => PGTagTone.neutral,
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  '${job.currentStage.replaceAll('_', ' ')} · ${elapsed.inHours}h ${elapsed.inMinutes % 60}m in this stage',
                                  style: PGTextStyles.caption.copyWith(color: PGColors.textSoft),
                                ),
                                const SizedBox(height: PGSpacing.groupGap),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (job.status == 'active') ...[
                                      PGSecondaryButton(label: 'Hold', expand: false, onPressed: _busy ? null : () => _hold(job)),
                                      PGSecondaryButton(label: 'Cancel', expand: false, onPressed: _busy ? null : () => _cancel(job)),
                                    ],
                                    if (job.status == 'on_hold') ...[
                                      PGPrimaryButton(label: 'Resume', expand: false, onPressed: _busy ? null : () => _resume(job)),
                                      PGSecondaryButton(label: 'Cancel', expand: false, onPressed: _busy ? null : () => _cancel(job)),
                                    ],
                                    if (job.status == 'cancelled')
                                      PGPrimaryButton(label: 'Reopen', expand: false, onPressed: _busy ? null : () => _reopen(job)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
