import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/operations_repository.dart';

/// Intake — reviewing pending quote requests. The server-side decision
/// logic (`decide-quote-request`) already existed from PG-008; this is
/// the staff UI PG-008 explicitly deferred to "a later task, most
/// likely PG-012 Operations." Visibility follows
/// `quote_requests_select_own_or_staff` (PG-005) exactly.
///
/// UNTESTED against a live backend.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key, required this.repository});

  final OperationsRepository repository;

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  List<PendingQuoteRequest>? _requests;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await widget.repository.fetchPendingQuoteRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load pending requests.');
    }
  }

  Future<void> _accept(PendingQuoteRequest request) async {
    setState(() => _busy = true);
    try {
      await widget.repository.decideQuoteRequest(request.id, accept: true);
      if (!mounted) return;
      showPGToast(context, 'Accepted — quote issued and job opened.');
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(PendingQuoteRequest request) async {
    final controller = TextEditingController();
    final reason = await showPGBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decline request',
                style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(
                controller: controller,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'Reason (required)')),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(
                label: 'Decline',
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim())),
          ],
        ),
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.repository
          .decideQuoteRequest(request.id, accept: false, reason: reason);
      if (!mounted) return;
      showPGToast(context, 'Declined.');
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
        title: Text('Intake',
            style: PGTextStyles.cardTitle
                .copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style:
                        PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _requests == null
                ? const Center(child: CircularProgressIndicator())
                : _requests!.isEmpty
                    ? Center(
                        child: Text('No pending requests.',
                            style: PGTextStyles.body
                                .copyWith(color: PGColors.textSoft)))
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _requests!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request = _requests![index];
                          final age =
                              DateTime.now().difference(request.createdAt);
                          return PGCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Request ${request.id.substring(0, 8)}',
                                    style: PGTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: PGColors.ink)),
                                Text(
                                    '${age.inHours}h ${age.inMinutes % 60}m ago',
                                    style: PGTextStyles.caption
                                        .copyWith(color: PGColors.textSoft)),
                                const SizedBox(height: PGSpacing.groupGap),
                                Row(
                                  children: [
                                    Expanded(
                                        child: PGSecondaryButton(
                                            label: 'Decline',
                                            onPressed: _busy
                                                ? null
                                                : () => _decline(request))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: PGPrimaryButton(
                                            label: 'Accept',
                                            onPressed: _busy
                                                ? null
                                                : () => _accept(request))),
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
