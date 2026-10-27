import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/auth_repository.dart';
import 'customer_otp_verify_screen.dart';

/// Customer phone entry — step 1 of sign-in.
///
/// No approved screen design exists for customer sign-in at all: the
/// handoff's 19-screen inventory has a "Sign-in" screen (#11) that is
/// explicitly staff-only. Phone OTP was chosen as the customer auth
/// mechanism based on the product's own copy elsewhere ("Dial from the
/// phone number on your account") — see
/// supabase/migrations/20260904000014_customer_authentication.sql for
/// the full reasoning. This screen is kept minimal and functional,
/// styled with PG-002 tokens so it isn't jarring, but it is not a
/// pixel-approved design — revisit with the product owner/designer.
class CustomerPhoneSignInScreen extends StatefulWidget {
  const CustomerPhoneSignInScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<CustomerPhoneSignInScreen> createState() =>
      _CustomerPhoneSignInScreenState();
}

class _CustomerPhoneSignInScreenState extends State<CustomerPhoneSignInScreen> {
  final _phoneController = TextEditingController();
  String? _error;
  bool _sending = false;

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInCustomerWithPhone(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerOtpVerifyScreen(
              authRepository: widget.authRepository, phone: phone),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = 'Could not send a code. Check the number and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
              Image.asset(
                'assets/brand/logo-on-light.png',
                height: 34,
                semanticLabel: 'Pro_Grafiz Designs',
              ),
              const SizedBox(height: PGSpacing.groupGap),
              Text(
                'Enter your phone number to sign in or create an account.',
                style: PGTextStyles.body.copyWith(color: PGColors.textMid),
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              Semantics(
                identifier: 'pg_phone_field',
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: PGTextStyles.input,
                  decoration: InputDecoration(
                      hintText: '+234 8xx xxx xxxx', errorText: _error),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGPrimaryButton(
                  testId: 'pg_send_code_button',
                  label: _sending ? 'Sending…' : 'Send code',
                  onPressed: _sending ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
