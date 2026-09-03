# CAD Engine

Isolated Python geometry/CAD worker: SVG generation, geometry validation,
DXF export, mandatory manufacturing checks (minimum bridge width,
thickness floor, closed cut paths, fixing positions, nesting
efficiency), and nesting optimization.

## Status

Not started. Owned primarily by PG-015 (CAD Pipeline), though V1's
Definition of Done (Master Spec Section 19) requires *some* real DXF
generation and check path to exist before launch — that scope boundary
(how much of PG-015 pulls into V1) is one of the open items flagged in
the production-readiness assessment and needs a decision before this
directory gets real code.

Nothing here is a placeholder for fake/mock geometry — per `CLAUDE.md`,
the prototype's procedurally generated pattern tiles must never inform
production catalogue or CAD logic.
