-- PG-005: RLS — payments, payment_events.
--
-- No write policy at all for authenticated/anon on either table.
-- CLAUDE.md "PAYMENT RULES" is unambiguous: payment confirmation must
-- come from a verified gateway/webhook or an accountant action backed
-- by "a fresh challenge" (PIN re-entry), never a raw client write, and
-- "NO MATCH cannot be confirmed automatically." A fresh-PIN-challenge
-- requirement cannot be expressed as an RLS policy at all — it needs a
-- dedicated Edge Function (service_role, not built yet — PG-009) that
-- re-verifies the accountant's PIN in the same request before writing.
-- Locking out ALL direct writes here, including for the accountant
-- role, is the correct interim state, not a gap: it's what makes
-- "Designer cannot confirm payments" hold trivially, and it means a
-- compromised or careless accountant session can't confirm a payment
-- without going through the (to-be-built) challenge flow either.
--
-- Read access is deliberately narrower than the general central-staff
-- pattern used elsewhere: payments are financial data, so only
-- Accountant + Super Admin (plus branch-scoped Centre Manager) can see
-- them — Designer/Production/Inventory have no reason to.

alter table payments enable row level security;
alter table payment_events enable row level security;

create policy payments_select_own_or_finance_staff on payments
  for select using (
    exists (
      select 1 from jobs j
      where j.id = payments.job_id
        and (
          j.customer_id = current_customer_id()
          or (is_centre_manager() and j.branch_id = current_staff_branch_id())
          or is_accountant()
          or is_super_admin()
        )
    )
  );

create policy payment_events_select_finance_staff on payment_events
  for select using (is_accountant() or is_super_admin());

-- Deliberately no INSERT/UPDATE/DELETE policy on either table for
-- authenticated/anon — see header comment.
