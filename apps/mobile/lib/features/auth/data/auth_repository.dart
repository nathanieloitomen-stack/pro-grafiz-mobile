import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_identity.dart';

/// Thin wrapper around Supabase Auth and the PG-004 Edge Functions.
/// Screens depend on this, not on `Supabase.instance` directly, so the
/// underlying auth mechanism can change later without touching UI code.
///
/// UNTESTED: written without a live Supabase project to run against —
/// the shape of every call here matches supabase_flutter's documented
/// API, but none of it has actually executed. Verify against a real
/// project before trusting it.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Staff sign-in account picker (approved design screen #11, step 1).
  Future<List<StaffIdentity>> fetchStaffIdentities() async {
    final response =
        await _client.functions.invoke('staff-list-signin-identities');
    final identities =
        (response.data as Map<String, dynamic>)['identities'] as List<dynamic>;
    return identities
        .map((e) => StaffIdentity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Staff sign-in PIN step (screen #11, step 2). The PIN *is* the
  /// Supabase Auth password for this account — see
  /// supabase/migrations/20260904000013_staff_authentication.sql for
  /// why.
  Future<void> signInStaffWithPin({
    required StaffIdentity identity,
    required String pin,
  }) {
    return _client.auth.signInWithPassword(
      email: identity.authLoginHandle,
      password: pin,
    );
  }

  /// Completes first-time PIN setup (after an admin's staff-invite) or
  /// a PIN reset (after staff-reset-pin) — both converge on the same
  /// Edge Function and the same UI shell, since the approved design has
  /// no separate screen for either.
  Future<void> setInitialPin({
    required String profileId,
    required String inviteToken,
    required String newPin,
  }) async {
    final response = await _client.functions.invoke(
      'staff-set-initial-pin',
      body: {
        'profile_id': profileId,
        'invite_token': inviteToken,
        'new_pin': newPin,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw AuthException(data['error'] as String);
    }
  }

  /// Customer sign-in, step 1 — no approved screen design exists for
  /// this (see apps/mobile/README.md "Fonts"-adjacent "Auth" note); kept
  /// deliberately minimal until a designer covers it.
  Future<void> signInCustomerWithPhone(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  /// Customer sign-in, step 2.
  Future<AuthResponse> verifyCustomerOtp({
    required String phone,
    required String token,
  }) {
    return _client.auth
        .verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<void> signOut() => _client.auth.signOut();
}
