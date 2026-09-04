import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/auth_repository.dart';

/// OTP entry following [CustomerPhoneSignInScreen]. Same "no approved
/// design" caveat applies — see that file's header comment.
class CustomerOtpVerifyScreen extends StatefulWidget {
  const CustomerOtpVerifyScreen({super.key, required this.authRepository, required this.phone});

  final AuthRepository authRepository;
  final String phone;

  @override
  State<CustomerOtpVerifyScreen> createState() => _CustomerOtpVerifyScreenState();
}

class _CustomerOtpVerifyScreenState extends State<CustomerOtpVerifyScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _verifying = false;

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.authRepository.verifyCustomerOtp(phone: widget.phone, token: code);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "That code didn't work. Try again.");
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PGSpacing.screenHorizontal,
            vertical: PGSpacing.screenTopMax,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Enter the code', style: PGTextStyles.screenTitle.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.groupGap),
              Text('We sent a code to ${widget.phone}.', style: PGTextStyles.body.copyWith(color: PGColors.textMid)),
              const SizedBox(height: PGSpacing.sectionGap),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: PGTextStyles.input.copyWith(letterSpacing: 4),
                decoration: InputDecoration(hintText: '••••••', errorText: _error),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGPrimaryButton(
                label: _verifying ? 'Verifying…' : 'Verify',
                onPressed: _verifying ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
