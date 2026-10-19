import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/env.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/design_system/design_system.dart';

/// Pro_Grafiz mobile entry point.
///
/// PG-001 (Foundation) + PG-002 (Design System) + PG-004
/// (Authentication): the app now has a real theme, a small library of
/// generic components, and working (if untested against a live
/// backend) staff PIN sign-in and customer phone-OTP sign-in. Still no
/// feature screens, no catalogue/job/payment data, no navigation
/// framework beyond the minimum needed to reach the auth screens — that
/// starts with later PG tasks (PG-006 onward).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    await Supabase.initialize(
        url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }
  // If not configured, the app still runs — see _MissingEnvPlaceholder
  // below — rather than crashing on a bare `flutter run` with no
  // --dart-define flags supplied.

  runApp(const ProGrafizApp());
}

class ProGrafizApp extends StatelessWidget {
  const ProGrafizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro_Grafiz',
      debugShowCheckedModeBanner: false,
      theme: PGTheme.light(),
      home: Env.isConfigured
          ? AuthGate(authRepository: AuthRepository(Supabase.instance.client))
          : const _MissingEnvPlaceholder(),
    );
  }
}

/// Shown when the app is run without SUPABASE_URL / SUPABASE_ANON_KEY
/// --dart-define values — see apps/mobile/README.md "Environment".
class _MissingEnvPlaceholder extends StatelessWidget {
  const _MissingEnvPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PGSpacing.screenHorizontal,
            vertical: PGSpacing.screenTopMax,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pro_Grafiz',
                  style: PGTextStyles.hero.copyWith(color: PGColors.ink)),
              const SizedBox(height: PGSpacing.groupGap),
              const PGLabel('Missing configuration'),
              const SizedBox(height: PGSpacing.sectionGap),
              Text(
                'Run with --dart-define=SUPABASE_URL=... '
                '--dart-define=SUPABASE_ANON_KEY=... to reach sign-in. '
                'See apps/mobile/README.md.',
                style: PGTextStyles.body.copyWith(color: PGColors.textMid),
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              Wrap(
                spacing: 8,
                children: const [
                  PGPill(label: 'All', selected: true),
                  PGPill(label: 'Geometric Lattice'),
                  PGTag(label: 'Matched', tone: PGTagTone.success),
                  PGTag(label: 'No match', tone: PGTagTone.danger),
                ],
              ),
              const SizedBox(height: PGSpacing.sectionGap),
              PGHeroCard(
                child: Text(
                  'Design system — PG-002',
                  style: PGTextStyles.cardTitle.copyWith(color: PGColors.paper),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
