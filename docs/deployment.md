# Deployment

**Status: no environments provisioned yet.**

## Environments

`local → development → staging → production`, per `CLAUDE.md`. Production
data must never be used as casual development seed data.

## CI/CD

GitHub Actions (`.github/workflows/`):

- `lint.yml` — static analysis for mobile, admin-web, and cad-engine
- `build.yml` — build verification for mobile and admin-web

Neither workflow deploys anywhere yet. Android/iOS release pipelines and
web hosting deploy targets are not configured — no production
credentials exist in this repository, and none should be added outside
a reviewed, explicit change.

## Secrets

Managed via environment secrets in each target platform (GitHub Actions
secrets, Supabase project settings, hosting provider). Never committed —
see `.gitignore` and `.env.example` files per app.

## Rollback

To be defined before Gate 8 (production readiness) — not yet applicable
at this stage.
