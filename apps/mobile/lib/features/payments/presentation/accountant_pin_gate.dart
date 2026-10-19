import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/payment_repository.dart';

/// Approved design screen #18, "Accountant PIN gate": job reference,
/// explanation that only the accountant may confirm, masked PIN,
/// inline error. This calls `confirm-payment` directly — the PIN never
/// goes anywhere except that one request, and the server re-verifies it
/// as a genuine fresh challenge (see that function's own comments), not
/// just a client-side check.
///
/// UNTESTED against a live backend.
class AccountantPinGate extends StatefulWidget {
  const AccountantPinGate(
      {super.key, required this.jobRef, required this.paymentId});

  final String jobRef;
  final String paymentId;

  @override
  State<AccountantPinGate> createState() => _AccountantPinGateState();
}

class _AccountantPinGateState extends State<AccountantPinGate> {
  final _pinController = TextEditingController();
  String? _error;
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_pinController.text.length != 4) {
      setState(() => _error = 'Enter your four-digit PIN.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = PaymentRepository(Supabase.instance.client);
      await repository.confirm(
          paymentId: widget.paymentId, pin: _pinController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.jobRef,
              style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
          const SizedBox(height: 5),
          Text(
            'Only the Accountant may confirm this payment. Enter your PIN to continue.',
            style: PGTextStyles.meta.copyWith(color: PGColors.textMid),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: PGTextStyles.input
                .copyWith(fontSize: 20, letterSpacing: 8, color: PGColors.ink),
            decoration: InputDecoration(
                counterText: '', hintText: '••••', errorText: _error),
          ),
          const SizedBox(height: 10),
          PGPrimaryButton(
            label: _submitting ? 'Confirming…' : 'Confirm payment',
            onPressed: _submitting ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

Future<bool?> showAccountantPinGate(BuildContext context,
    {required String jobRef, String? paymentId}) {
  return showPGBottomSheet<bool>(
    context: context,
    builder: (context) =>
        AccountantPinGate(jobRef: jobRef, paymentId: paymentId ?? ''),
  );
}
