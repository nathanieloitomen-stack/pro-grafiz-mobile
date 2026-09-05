// Shared notification-creation core for PG-013.
//
// `notifications` (PG-003/PG-005) has zero client INSERT policy —
// notifications are system-generated only. This function, called from
// service-role Edge Functions at existing trigger points, is the only
// way a row is created. It performs no authorization check of its own
// beyond what the calling function already did to reach this point —
// it is a plain insert helper, not a security boundary.
//
// `type` is free text (no fixed value list exists anywhere in the docs
// — same situation as several other status-like columns since PG-003).
// The values used across this task's call sites are listed in
// docs/notifications.md; none of them affects any commercial or
// authorization logic, so no enum was introduced.
//
// Failures here are swallowed by convention at each call site (matching
// PG-011's document-generation pattern): a notification failing to
// send must never roll back or block the real operation it's attached
// to.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.

// deno-lint-ignore no-explicit-any
type SupabaseClientLike = any;

export interface NotifyParams {
  recipientUserId: string;
  type: string;
  title: string;
  body?: string;
  entityType?: string;
  entityId?: string;
}

export async function notify(admin: SupabaseClientLike, params: NotifyParams): Promise<void> {
  await admin.from('notifications').insert({
    recipient_user_id: params.recipientUserId,
    type: params.type,
    title: params.title,
    body: params.body ?? null,
    entity_type: params.entityType ?? null,
    entity_id: params.entityId ?? null,
  });
}

/**
 * Looks up the Centre Manager's auth.users id for a given branch, if
 * one exists — used for staff-facing notifications (e.g. "new quote
 * request") where the natural recipient is that branch's manager.
 * Returns null if no active Centre Manager is assigned to the branch;
 * callers must handle that gracefully (no notification, not an error —
 * a branch without an assigned manager is a valid, if incomplete,
 * state, not a fault).
 */
export async function findBranchCentreManager(admin: SupabaseClientLike, branchId: string): Promise<string | null> {
  const { data } = await admin
    .from('profiles')
    .select('id')
    .eq('role', 'centre_manager')
    .eq('branch_id', branchId)
    .eq('active', true)
    .limit(1)
    .maybeSingle();
  return data?.id ?? null;
}
