// Smoke test for the real Pro_Grafiz app entry point (replaces the
// Flutter counter template, which referenced a non-existent MyApp).
//
// `flutter test` runs without --dart-define values, so Env.isConfigured is
// false and the app must render the missing-configuration placeholder
// instead of crashing or attempting to reach Supabase.

import 'package:flutter_test/flutter_test.dart';

import 'package:pro_grafiz_mobile/main.dart';

void main() {
  testWidgets(
      'without env config, app shows the missing-configuration placeholder',
      (tester) async {
    await tester.pumpWidget(const ProGrafizApp());

    expect(find.text('Pro_Grafiz'), findsOneWidget);
    // PGLabel renders its text upper-cased.
    expect(find.text('MISSING CONFIGURATION'), findsOneWidget);
  });
}
