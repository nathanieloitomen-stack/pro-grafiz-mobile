import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/payment_repository.dart';
import 'accountant_pin_gate.dart';

/// Staff-facing Payments screen — approved design #17: payment cards
/// with job, kind, amount, reference, and a MATCHED / NO MATCH /
/// CONFIRMED tag with "the single permitted action". Visibility follows
/// PG-005's `payments_select_own_or_finance_staff` RLS exactly — this
/// screen makes no access decisions of its own; a Designer/Production/
/// Inventory session simply sees nothing here (that policy doesn't
/// grant them payment visibility at all).
///
/// Confirming (the "Accountant PIN gate", screen #18) is restricted to
/// the Accountant role specifically inside `confirm-payment` — this
/// screen shows the Confirm action to any viewer with payment
/// visibility, and lets the server reject it if the caller isn't the
/// Accountant, consistent with "no client-side authorization as a
/// substitute for database/server authorization."
///
/// UNTESTED against a live backend.
class StaffPaymentsScreen extends StatefulWidget {
  const StaffPaymentsScreen({super.key, required this.paymentRepository});

  final PaymentRepository paymentRepository;

  @override
  State<StaffPaymentsScreen> createState() => _StaffPaymentsScreenState();
}

class _StaffPaymentsScreenState extends State<StaffPaymentsScreen> {
  List<PaymentRecord>? _payments;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payments = await widget.paymentRepository.fetchStaffPayments();
      if (!mounted) return;
      setState(() => _payments = payments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load payments. Check your connection.');
    }
  }

  Future<void> _markMatched(PaymentRecord payment) async {
    final controller = TextEditingController();
    final reference = await showPGBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank reference', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.groupGap),
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'Reference found on statement')),
            const SizedBox(height: PGSpacing.groupGap),
            PGPrimaryButton(label: 'Mark matched', onPressed: () => Navigator.of(context).pop(controller.text.trim())),
          ],
        ),
      ),
    );
    if (reference == null || reference.isEmpty) return;
    try {
      await widget.paymentRepository.triage(paymentId: payment.id, result: 'matched', bankReference: reference);
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _markNoMatch(PaymentRecord payment) async {
    try {
      await widget.paymentRepository.triage(paymentId: payment.id, result: 'no_match');
      _load();
    } catch (e) {
      if (!mounted) return;
      showPGToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirm(PaymentRecord payment) async {
    final confirmed = await showAccountantPinGate(context, jobRef: payment.jobRef, paymentId: payment.id);
    if (confirmed != true) return;
    // showAccountantPinGate performs the confirm-payment call itself
    // (it needs the PIN in the same request) — reload to reflect it.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Payments', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _payments == null
                ? const Center(child: CircularProgressIndicator())
                : _payments!.isEmpty
                    ? Center(child: Text('No payments visible to your role.', style: PGTextStyles.body.copyWith(color: PGColors.textSoft)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _payments!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _PaymentCard(
                          payment: _payments![index],
                          onMarkMatched: () => _markMatched(_payments![index]),
                          onMarkNoMatch: () => _markNoMatch(_payments![index]),
                          onConfirm: () => _confirm(_payments![index]),
                        ),
                      ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.onMarkMatched,
    required this.onMarkNoMatch,
    required this.onConfirm,
  });

  final PaymentRecord payment;
  final VoidCallback onMarkMatched;
  final VoidCallback onMarkNoMatch;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return PGCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(payment.jobRef, style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink)),
              PGTag(
                label: payment.status.replaceAll('_', ' '),
                tone: switch (payment.status) {
                  'confirmed' => PGTagTone.success,
                  'no_match' || 'failed' => PGTagTone.danger,
                  'matched' => PGTagTone.warning,
                  _ => PGTagTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.kind} · ₦${(payment.amountKobo / 100).toStringAsFixed(0)}',
            style: PGTextStyles.caption.copyWith(color: PGColors.textSoft),
          ),
          if (payment.bankReference != null)
            Text('Ref: ${payment.bankReference}', style: PGTextStyles.caption.copyWith(color: PGColors.textSoft)),
          const SizedBox(height: PGSpacing.groupGap),
          if (payment.status == 'pending')
            Row(
              children: [
                Expanded(child: PGSecondaryButton(label: 'No match', onPressed: onMarkNoMatch)),
                const SizedBox(width: 8),
                Expanded(child: PGPrimaryButton(label: 'Mark matched', onPressed: onMarkMatched)),
              ],
            )
          else if (payment.status == 'matched' || payment.status == 'no_match')
            PGPrimaryButton(label: 'Confirm', onPressed: onConfirm),
        ],
      ),
    );
  }
}
