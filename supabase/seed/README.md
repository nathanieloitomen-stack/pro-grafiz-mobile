# Seed Data

`0001_dev_seed.sql` — minimal, clearly development-only data (every code
is `DEV-` prefixed) covering branches, pattern categories, materials,
thicknesses, finishes, and one placeholder pattern with a preview asset.
Enough to exercise foreign keys locally; nothing else.

Deliberately **not** seeded: customers, quote requests, quotes, jobs, or
payments — fabricating those would mean inventing business scenarios,
not just enabling local development against the schema shape. Add those
in a later PG task once the corresponding feature flow is designed, and
keep the same `DEV-`-style marking convention when you do, per
`CLAUDE.md`:

> "Do not populate production catalogue with invented geometry.
> Development seed assets must be clearly marked as development data."

Apply locally with `supabase db reset` (runs migrations then seed) once
the Supabase CLI is available — this was authored without it (no
network access in the authoring environment).
