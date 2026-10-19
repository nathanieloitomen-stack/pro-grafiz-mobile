import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/auth_repository.dart';
import '../data/staff_identity.dart';

/// Approved design screen #11 ("Sign-in"): scrollable staff account
/// list, then a 4-digit PIN step for the selected identity. Presented
/// as a bottom sheet, matching the handoff's copy and layout closely.
///
/// UNTESTED against a live backend — see AuthRepository's own caveat.
class StaffSignInSheet extends StatefulWidget {
  const StaffSignInSheet({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<StaffSignInSheet> createState() => _StaffSignInSheetState();
}

class _StaffSignInSheetState extends State<StaffSignInSheet> {
  List<StaffIdentity>? _identities;
  String? _loadError;
  StaffIdentity? _selected;
  final _pinController = TextEditingController();
  String? _pinError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final identities = await widget.authRepository.fetchStaffIdentities();
      if (!mounted) return;
      setState(() => _identities = identities);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _loadError = 'Could not load accounts. Check your connection.');
    }
  }

  Future<void> _submitPin() async {
    final identity = _selected;
    if (identity == null) return;
    if (_pinController.text.length != 4) {
      setState(() => _pinError = 'Enter your four-digit PIN.');
      return;
    }
    setState(() {
      _submitting = true;
      _pinError = null;
    });
    try {
      await widget.authRepository
          .signInStaffWithPin(identity: identity, pin: _pinController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pinError = 'Incorrect PIN. Try again.';
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
      child: _selected == null ? _buildUserStep() : _buildPinStep(_selected!),
    );
  }

  Widget _buildUserStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Staff sign-in',
            style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
        const SizedBox(height: 5),
        Text(
          'Pick your account. What you can do depends on your role, not on the device.',
          style: PGTextStyles.meta.copyWith(color: PGColors.textMid),
        ),
        const SizedBox(height: 13),
        if (_loadError != null)
          Text(_loadError!,
              style: PGTextStyles.body.copyWith(color: PGColors.dangerFg))
        else if (_identities == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PGRadius.insetNote),
                border: Border.all(color: PGColors.hairline(0.09)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PGRadius.insetNote),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _identities!.length,
                  separatorBuilder: (_, __) =>
                      Container(height: 1, color: PGColors.hairline(0.09)),
                  itemBuilder: (context, index) {
                    final identity = _identities![index];
                    return _AccountRow(
                        identity: identity,
                        onTap: () => setState(() => _selected = identity));
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinStep(StaffIdentity identity) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(identity.fullName,
            style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
        const SizedBox(height: 4),
        Text(
          'Enter your four-digit PIN. Every action you take is recorded against this account.',
          style: PGTextStyles.meta.copyWith(color: PGColors.textMid),
        ),
        const SizedBox(height: 16),
        Semantics(
          identifier: 'pg_staff_pin_field',
          child: TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: PGTextStyles.input
                .copyWith(fontSize: 20, letterSpacing: 8, color: PGColors.ink),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              errorText: _pinError,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PGSecondaryButton(
                testId: 'pg_staff_pin_back',
                label: 'Back',
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _selected = null;
                          _pinController.clear();
                          _pinError = null;
                        }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PGPrimaryButton(
                testId: 'pg_staff_pin_submit',
                label: _submitting ? 'Signing in…' : 'Sign in',
                onPressed: _submitting ? null : _submitPin,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.identity, required this.onTap});

  final StaffIdentity identity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PGPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  color: PGColors.clayDeep, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                identity.initials ?? identity.fullName.substring(0, 1),
                style: PGTextStyles.numeric
                    .copyWith(fontSize: 13, color: PGColors.textMid),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.fullName,
                    style: PGTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700, color: PGColors.ink),
                  ),
                  Text(
                    [identity.role.replaceAll('_', ' '), identity.branchName]
                        .whereType<String>()
                        .join(' · '),
                    style:
                        PGTextStyles.caption.copyWith(color: PGColors.textSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience launcher matching the [showPGBottomSheet] pattern used
/// elsewhere in the design system.
Future<bool?> showStaffSignInSheet(
    BuildContext context, AuthRepository authRepository) {
  return showPGBottomSheet<bool>(
    context: context,
    builder: (context) => StaffSignInSheet(authRepository: authRepository),
  );
}
