import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/auth_repository.dart';
import 'customer_phone_sign_in_screen.dart';
import 'staff_sign_in_sheet.dart';

/// Decides what the app shows based on whether a Supabase session
/// exists yet. Not a real navigation/routing framework — that's later
/// PG task territory (once there are actual feature screens to route
/// between). This exists so PG-004's auth flows are reachable at all.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authRepository.onAuthStateChange,
      builder: (context, snapshot) {
        final session = authRepository.currentSession;
        if (session != null) {
          return _SignedInPlaceholder(authRepository: authRepository);
        }
        return _SignedOutChoice(authRepository: authRepository);
      },
    );
  }
}

class _SignedOutChoice extends StatelessWidget {
  const _SignedOutChoice({required this.authRepository});

  final AuthRepository authRepository;

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
              Text('Pro_Grafiz', style: PGTextStyles.hero.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.sectionGap),
              PGPrimaryButton(
                label: 'Customer sign-in',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CustomerPhoneSignInScreen(authRepository: authRepository)),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Staff sign-in',
                onPressed: () => showStaffSignInSheet(context, authRepository),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedInPlaceholder extends StatelessWidget {
  const _SignedInPlaceholder({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signed in', style: PGTextStyles.screenTitle.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.groupGap),
              Text(
                'Feature screens (catalogue, jobs, queue, etc.) start in later PG tasks.',
                style: PGTextStyles.body.copyWith(color: PGColors.textMid),
              ),
              const Spacer(),
              PGSecondaryButton(label: 'Sign out', onPressed: authRepository.signOut),
            ],
          ),
        ),
      ),
    );
  }
}
