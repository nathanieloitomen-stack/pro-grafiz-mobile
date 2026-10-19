import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/auth_repository.dart';

/// Completes first-time PIN setup (after an admin's staff-invite) or a
/// PIN reset (after staff-reset-pin).
///
/// No approved screen design exists for this — the prototype only shows
/// an admin-side toast ("Invite sent. The new user sets their own PIN
/// on first sign-in.") with no corresponding screen. This is a minimal,
/// functional stand-in using PG-002 tokens, not a pixel-approved
/// screen — revisit with the product owner/designer before treating it
/// as final. How the invite token actually reaches this screen (deep
/// link vs. manual entry from a WhatsApp message) is also an open UX
/// question left for a later task; both fields are editable here so it
/// works either way in the meantime.
class StaffSetPinScreen extends StatefulWidget {
  const StaffSetPinScreen({
    super.key,
    required this.authRepository,
    this.initialProfileId,
    this.initialInviteToken,
  });

  final AuthRepository authRepository;
  final String? initialProfileId;
  final String? initialInviteToken;

  @override
  State<StaffSetPinScreen> createState() => _StaffSetPinScreenState();
}

class _StaffSetPinScreenState extends State<StaffSetPinScreen> {
  late final _profileIdController =
      TextEditingController(text: widget.initialProfileId ?? '');
  late final _tokenController =
      TextEditingController(text: widget.initialInviteToken ?? '');
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_pinController.text != _confirmController.text) {
      setState(() => _error = "PINs don't match.");
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pinController.text)) {
      setState(() => _error = 'PIN must be exactly four digits.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authRepository.setInitialPin(
        profileId: _profileIdController.text.trim(),
        inviteToken: _tokenController.text.trim(),
        newPin: _pinController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'That invite code is invalid or has expired.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _profileIdController.dispose();
    _tokenController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
          title: const Text('Set your PIN'),
          backgroundColor: PGColors.paper,
          elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a four-digit PIN. Every action you take is recorded against this account.',
                style: PGTextStyles.body.copyWith(color: PGColors.textMid),
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              if (widget.initialProfileId == null) ...[
                TextField(
                  controller: _profileIdController,
                  decoration: const InputDecoration(
                      hintText: 'Profile ID (from your admin)'),
                ),
                const SizedBox(height: PGSpacing.groupGap),
              ],
              if (widget.initialInviteToken == null) ...[
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                      hintText: 'Invite code (from your admin)'),
                ),
                const SizedBox(height: PGSpacing.groupGap),
              ],
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style:
                    PGTextStyles.input.copyWith(fontSize: 20, letterSpacing: 8),
                decoration:
                    const InputDecoration(hintText: '••••', counterText: ''),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              TextField(
                controller: _confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style:
                    PGTextStyles.input.copyWith(fontSize: 20, letterSpacing: 8),
                decoration: InputDecoration(
                    hintText: '••••', counterText: '', errorText: _error),
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              PGPrimaryButton(
                label: _submitting ? 'Saving…' : 'Save PIN',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
