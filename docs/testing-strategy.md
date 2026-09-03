# Testing Strategy

**Status: gates defined in `PRO_GRAFIZ_MASTER_SPEC.md`, Section 18;
no tests exist yet.**

| Gate | Focus |
|---|---|
| 0 | UX parity with the approved handoff |
| 1 | Database/security — migrations reproducible, backups verified, RLS/role tests pass |
| 2 | Commercial calculation — 100+ quote cases pass expected outputs and edge cases |
| 3 | Payment integrity — success/failure/retry/duplicate webhook tests, no client-only confirmation |
| 4 | Job lifecycle — every allowed/denied stage transition tested |
| 5 | CAD safety — failed mandatory checks block production release |
| 6 | Offline — queue/replay/restart/duplicate/conflict tests |
| 7 | UAT — real Pro_Grafiz staff complete scripted end-to-end scenarios |
| 8 | Production readiness — monitoring, backups, secrets, legal/privacy, signing, rollback |
| 9 | Pilot — controlled rollout metrics meet agreed thresholds |

CI (`.github/workflows/`) currently runs lint and build only. Test jobs
will be added as each app/package gains a test suite — do not mark a
gate satisfied without the corresponding automated or scripted evidence.
