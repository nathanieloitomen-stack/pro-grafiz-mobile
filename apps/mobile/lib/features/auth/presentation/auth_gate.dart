import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../data/auth_repository.dart';
import 'customer_phone_sign_in_screen.dart';
import 'staff_sign_in_sheet.dart';

/// Decides what the app shows based on session state. Not a real
/// navigation/routing framework — that's later PG task territory (once
/// there are enough feature screens to need one). As of PG-006: the
/// catalogue (Home/Patterns/Detail/Configure) is genuinely browsable
/// signed-out, matching the fact that its RLS policies (PG-005) already
/// allow anonymous SELECT on active patterns — gating it behind a
/// sign-in wall here would contradict that design decision rather than
/// just reflect it. Favouriting and configuration-submission naturally
/// still require a session further down (enforced by RLS regardless of
/// what this screen shows).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    final catalogueRepository = CatalogueRepository(Supabase.instance.client);

    return StreamBuilder<AuthState>(
      stream: authRepository.onAuthStateChange,
      builder: (context, snapshot) {
        final session = authRepository.currentSession;
        if (session == null) {
          return _BrowsingShell(
            authRepository: authRepository,
            catalogueRepository: catalogueRepository,
            signedIn: false,
          );
        }
        // Signed in — could be staff or a customer (see PG-004: they're
        // never the same kind of row). Only customers get the catalogue
        // Home screen here; staff keep the existing placeholder, since
        // staff feature screens are out of PG-006's scope.
        return FutureBuilder<bool>(
          future: _isCustomer(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.data == true) {
              return _BrowsingShell(
                authRepository: authRepository,
                catalogueRepository: catalogueRepository,
                signedIn: true,
              );
            }
            return _StaffSignedInPlaceholder(authRepository: authRepository);
          },
        );
      },
    );
  }

  Future<bool> _isCustomer() async {
    try {
      final row = await Supabase.instance.client.from('customers').select('id').maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }
}

/// Wraps [HomeScreen] with a top-right sign-in/sign-out affordance,
/// since the catalogue is reachable both signed-out (browsing) and
/// signed-in (browsing + favourites).
class _BrowsingShell extends StatelessWidget {
  const _BrowsingShell({
    required this.authRepository,
    required this.catalogueRepository,
    required this.signedIn,
  });

  final AuthRepository authRepository;
  final CatalogueRepository catalogueRepository;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HomeScreen(catalogueRepository: catalogueRepository, authRepository: authRepository),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: TextButton(
              onPressed: signedIn ? authRepository.signOut : () => _showSignInChoice(context),
              child: Text(
                signedIn ? 'Sign out' : 'Sign in',
                style: PGTextStyles.button.copyWith(color: PGColors.ember),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSignInChoice(BuildContext context) {
    showPGBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(PGSpacing.screenHorizontal, 24, PGSpacing.screenHorizontal, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sign in', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink)),
            const SizedBox(height: PGSpacing.sectionGap),
            PGPrimaryButton(
              label: 'I\'m a customer',
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CustomerPhoneSignInScreen(authRepository: authRepository)),
                );
              },
            ),
            const SizedBox(height: PGSpacing.groupGap),
            PGSecondaryButton(
              label: 'I\'m on staff',
              onPressed: () {
                Navigator.of(context).pop();
                showStaffSignInSheet(context, authRepository);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffSignedInPlaceholder extends StatelessWidget {
  const _StaffSignedInPlaceholder({required this.authRepository});

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
              Text('Signed in — staff', style: PGTextStyles.screenTitle.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.groupGap),
              Text(
                'Staff feature screens (Intake, Job queue, Design desk, Payments, '
                'Admin) start in later PG tasks.',
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
