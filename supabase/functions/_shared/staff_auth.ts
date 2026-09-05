// Shared authorization helper for PG-012 operational actions
// (hold/resume/cancel/reopen a job). Mirrors
// quote_requests_update_staff_only's exact condition (PG-005) rather
// than inventing a new rule: Centre Manager restricted to their own
// branch, or a broader operational role.
//
// AUTHORITY DECISION (flagged, not specified anywhere in the docs):
// Master Spec never states who may hold/cancel/resume/reopen a job.
// Restricted here to Centre Manager (own branch) and Super Admin only —
// NOT Designer/Production/Accountant/Inventory, who each have their own
// specific domain and no stated general job-management authority. This
// is narrower than the "any central staff" pattern used for read access
// and for quote_request decisions elsewhere in this codebase — a
// deliberate, conservative choice for operational actions that can
// disrupt or end a job, made because no broader authority is given, not
// because a broader one was ruled out. See docs/operations.md.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.

// deno-lint-ignore no-explicit-any
type SupabaseClientLike = any;

export interface StaffAuthResult {
  authorized: boolean;
  profileId?: string;
  reason?: string;
}

/**
 * Checks whether the given profile may perform an operational action
 * (hold/resume/cancel/reopen) on a job in the given branch. Does NOT
 * check job state (e.g. current status) — callers do that themselves,
 * since the valid preconditions differ per action.
 */
export async function authorizeOperationalAction(
  admin: SupabaseClientLike,
  callerId: string,
  jobBranchId: string,
): Promise<StaffAuthResult> {
  const { data: profile } = await admin
    .from('profiles')
    .select('id, role, branch_id, active')
    .eq('id', callerId)
    .maybeSingle();

  if (!profile?.active) {
    return { authorized: false, reason: 'No active staff profile' };
  }
  if (profile.role === 'super_admin') {
    return { authorized: true, profileId: profile.id };
  }
  if (profile.role === 'centre_manager' && profile.branch_id === jobBranchId) {
    return { authorized: true, profileId: profile.id };
  }
  return {
    authorized: false,
    reason: 'Only a Super Admin, or the Centre Manager of this job\'s own branch, may perform this action',
  };
}
