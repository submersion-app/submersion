# Standard gas catalog — association sources (issue #3117)

Research backing the `associations` field on each `StandardGasMix` entry in
`lib/features/gas_calculators/domain/standard_gas_mix.dart`. Not shown in the
UI (issue #3117 decision) — kept here for traceability only.

## Nitrox

| Entry | Association | Source |
| --- | --- | --- |
| Air (21/0) | — | Not a trained "standard mix", just ambient air. |
| EAN32 | NOAA | NOAA Diving Program's two-gas Nitrox tables (32% and 36%) are the long-standing US recreational/scientific-diving reference blends; EAN32 is the shallower of the pair. |
| EAN36 | NOAA | Same NOAA two-gas table; EAN36 is the richer, shallower-MOD blend of the pair. |
| EAN40 | — | Common in agency fill charts as a "rich nitrox" option, but not tied to one organization's named standard the way 32/36 are. |

## Deco gases

| Entry | Association | Source |
| --- | --- | --- |
| EAN50 | GUE | GUE's standard gas plan for technical dives names EAN50 as the single intermediate deco gas, switched to from bottom gas before oxygen. |
| O2 (100%) | GUE | Same GUE standard gas plan; pure O2 is the shallow-stop deco gas (6 m / 20 ft and shallower). |

## Bottom gases (trimix) — GUE ladder

GUE's Standards & Procedures and Technical/Cave curricula define a fixed
helium ladder of named trimixes for successive depth bands, each tuned to
keep END and ppO2 within the agency's chosen limits at that band's target
depth:

| Entry | Association |
| --- | --- |
| Trimix 21/35 | GUE |
| Trimix 18/45 | GUE, IANTD (see below — the two ladders coincide at this blend) |
| Trimix 15/55 | GUE |
| Trimix 12/65 | GUE |
| Trimix 10/70 | GUE |

## Bottom gases (trimix) — IANTD ladder

IANTD's own technical and advanced-trimix course materials name a parallel
but distinct set of blends for its depth bands. Two IANTD blends are
"Rec. Trimix" (recreational/normoxic trimix course range) and three are
"Tech Trimix" (advanced trimix course range):

| Entry | Association |
| --- | --- |
| Rec. Trimix 28/25 | IANTD |
| Rec. Trimix 32/15 | IANTD |
| Tech Trimix 19/40 | IANTD |
| Tech Trimix 14/50 | IANTD |
| Tech Trimix 12/60 | IANTD |
| Trimix 18/45 | IANTD (coincides with the GUE ladder's own 18/45) |

## Bottom gases (trimix) — no association found

These three are common enough in blending software and fill-station charts
to be worth listing, but the research did not turn up one organization that
names them as *its* defined standard blend (unlike the GUE/IANTD ladders
above, which are each named in that organization's own course material):

- Trimix 18/35
- Trimix 25/50
- Heliox/Trimix 50/20

## Selection and display decisions (recap)

- The catalog fully replaces the old fixed `[50, 40, 36, 32, 30, 28, 21]`
  list (no association data existed for that list; it was an arbitrary
  O2-percent ladder).
- `coveringStandardMixes` (in `best_mix.dart`) selects catalog entries whose
  MOD — and, for a trimix, END — covers the current target depth, sorted by
  MOD ascending (nearest fit first).
- Associations are not surfaced in the UI; they exist only in the domain
  model and this document.
- The common-mixes UI shows up to 6 covering entries by default, expandable
  to all covering entries (even beyond 6), and stays a flat list in both
  states — no grouping by category or association.
