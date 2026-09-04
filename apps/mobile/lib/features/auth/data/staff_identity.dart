/// One entry in the staff sign-in account picker (approved design
/// screen #11). Mirrors exactly what the `staff-list-signin-identities`
/// Edge Function returns — see that function's own comments for why
/// each field is or isn't included.
class StaffIdentity {
  const StaffIdentity({
    required this.profileId,
    required this.fullName,
    required this.role,
    required this.authLoginHandle,
    this.initials,
    this.branchName,
  });

  final String profileId;
  final String fullName;
  final String role;

  /// Internal synthetic identifier used as the Supabase Auth "email"
  /// for this account — not sensitive, needed to sign in.
  final String authLoginHandle;

  final String? initials;
  final String? branchName;

  factory StaffIdentity.fromJson(Map<String, dynamic> json) {
    final branch = json['branches'] as Map<String, dynamic>?;
    return StaffIdentity(
      profileId: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      authLoginHandle: json['auth_login_handle'] as String,
      initials: json['initials'] as String?,
      branchName: branch?['name'] as String?,
    );
  }
}
