import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../design_desk/data/design_desk_repository.dart';
import '../../design_desk/presentation/design_desk_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/presentation/jobs_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../operations/data/operations_repository.dart';
import '../../operations/presentation/intake_screen.dart';
import '../../operations/presentation/job_queue_screen.dart';
import '../../operations/presentation/operations_dashboard_screen.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/staff_payments_screen.dart';
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (signedIn)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobsScreen(jobRepository: JobRepository(Supabase.instance.client)),
                      ),
                    ),
                    child: Text('My jobs', style: PGTextStyles.button.copyWith(color: PGColors.ink)),
                  ),
                if (signedIn)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationsScreen(repository: NotificationRepository(Supabase.instance.client)),
                      ),
                    ),
                    child: Text('Notifications', style: PGTextStyles.button.copyWith(color: PGColors.ink)),
                  ),
                TextButton(
                  onPressed: signedIn ? authRepository.signOut : () => _showSignInChoice(context),
                  child: Text(
                    signedIn ? 'Sign out' : 'Sign in',
                    style: PGTextStyles.button.copyWith(color: PGColors.ember),
                  ),
                ),
              ],
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
                'Admin (staff account management) starts in a later PG task.',
                style: PGTextStyles.body.copyWith(color: PGColors.textMid),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Payments',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StaffPaymentsScreen(paymentRepository: PaymentRepository(Supabase.instance.client)),
                  ),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Design Desk',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DesignDeskScreen(repository: DesignDeskRepository(Supabase.instance.client)),
                  ),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Intake',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IntakeScreen(repository: OperationsRepository(Supabase.instance.client)),
                  ),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Job Queue',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JobQueueScreen(repository: OperationsRepository(Supabase.instance.client)),
                  ),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Dashboard',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OperationsDashboardScreen(repository: OperationsRepository(Supabase.instance.client)),
                  ),
                ),
              ),
              const SizedBox(height: PGSpacing.groupGap),
              PGSecondaryButton(
                label: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(repository: NotificationRepository(Supabase.instance.client)),
                  ),
                ),
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
