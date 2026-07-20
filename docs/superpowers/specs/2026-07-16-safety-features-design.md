# Safety Features — Design

Date: 2026-07-16
Status: Implemented (phases 1-4; PRs #606, #609, #610, #611)
Branch/worktree: `worktree-safety-features`

## Summary

A four-phase "Safety" umbrella feature that makes Submersion the logbook that
takes diver safety seriously:

1. **Post-dive safety review** — automatic, neutral-toned analysis of recorded
   profiles (rapid ascents, missed/shortened stops, omitted safety stops,
   sawtooth profiles).
2. **Flying-after-diving** — DAN/UHMS guideline countdown plus an informational
   tissue-desaturation view; altitude-planning UX improvements.
3. **Offline emergency card** — a single offline screen with the diver's
   emergency/medical/insurance data, regional DAN hotline, local EMS number,
   and a bundled hyperbaric chamber directory with user overrides.
4. **Near-miss log** — standalone, optionally dive-linked incident records with
   a structured taxonomy, private by default.

Each phase is independently shippable, in the order above (ordered by leverage:
phase 1 is mostly a rules layer over infrastructure that already exists).

## UI architecture (hybrid)

Features integrate into existing contextual surfaces, tied together by a new
**Safety hub** page:

- **Dive detail**: new `DiveDetailSectionId.safetyReview` section (registry in
  `lib/core/constants/dive_detail_sections.dart`, builders in
  `dive_detail_page.dart`).
- **Dive list**: small neutral indicator on `DiveListItem` when a dive has
  non-dismissed findings.
- **Dashboard**: no-fly countdown and safety-review flags ride the existing
  `DashboardAlerts` channel (`lib/features/dashboard/.../alerts_card.dart`);
  emergency-card quick action.
- **Safety hub**: a routed page (same pattern as
  `lib/features/surface_interval_tool/`) hosting: current no-fly status, the
  emergency card, the near-miss log, and a link to safety settings. New feature
  slice `lib/features/safety/`.

Access patterns motivating the hybrid: the emergency card needs instant access
under stress; the no-fly timer needs ambient visibility; the review needs
per-dive context; the near-miss log needs deliberate access.

## Phase 1 — Post-dive safety review

### Engine

New pure service `lib/features/dive_log/domain/services/safety_review_service.dart`:

- Input: `ProfileAnalysis` (from the existing
  `ProfileAnalysisService.analyze()` Bühlmann replay) + dive metadata.
- Output: `SafetyReview` containing `SafetyFinding` records.

`SafetyFinding` fields: type, severity (`info` / `caution` / `significant`),
plain-language description, profile time range (startTs/endTs), numeric value
(e.g. peak ascent rate), engine version.

### Rules (initial set)

| Rule | Source data | Thresholds |
| --- | --- | --- |
| Rapid ascent | existing `ascentRateViolations` from `AscentRateCalculator` | sustained > 9 m/min = caution; > 12 m/min = significant |
| Missed / shortened deco stop | per-sample `decoStatuses` (depth above ceiling while `inDeco`) + imported `decoViolation` / `missedStop` events | any ceiling violation = significant |
| Omitted / short safety stop | `DivePhase` segmentation | dives > 10 m ending no-deco without a ≥ 2.5 min hold in the 4–7 m band = info (caution when max depth > 25 m) |
| Sawtooth profile | new detector | ≥ 3 depth-reversal cycles of ≥ 3 m after the bottom phase (thresholds tunable) |
| High surface GF | `DecoStatus.gf99` at surfacing | above diver's configured GF-high = info |

The sawtooth detector is the only genuinely new algorithm; everything else is a
thin classification over data the replay already produces. The safety review
section displays engine findings only; computer-reported violation events keep
appearing on the profile chart as today, so no cross-source dedup is needed.

### Storage

Two new child-of-dive tables: `dive_safety_reviews` (diveId PK, engineVersion,
reviewedAt — the "analyzed" marker, so clean dives are distinguishable from
never-analyzed dives without a replay) and `dive_safety_findings` (id, diveId,
ruleId, severity, startTimestamp/endTimestamp, value, engineVersion,
dismissedAt, createdAt). Both follow the write-once child-table sync
conventions (`DiveProfileEvents` pattern: no HLC columns; `markRecordPending`
on writes, per-row `logDeletion` on deletes). Reviews run against the dive's
active/merged profile, so no per-source column is needed. Findings are
computed lazily when a dive is viewed (compute-through-cache) and invalidated
at the profile-write choke points (`importProfile` replace path,
`saveEditedProfile`); a settings action backfills all dives on demand, so list
badges never require a replay.
`engineVersion` allows honest re-grading of history when rules improve: bump
the version, recompute lazily, never silently change what a finding said.

### Tone rules (product requirements)

- Neutral iconography; no red alarm glyphs on the dive list — a small dot.
- Wording states what happened, never judgment: "Ascent exceeded 12 m/min for
  40 s at 18 m", not "dangerous ascent".
- Per-finding dismiss/acknowledge; dismissed findings hide the badge.
- Global off switch and per-rule toggles in safety settings.

## Phase 2 — Flying-after-diving + altitude

### No-fly countdown

New `lib/features/safety/domain/services/no_fly_service.dart`:

- Classifies the trailing dive window per DAN/UHMS guidance:
  single no-deco dive → 12 h; repetitive dives / multi-day → 18 h; any dive
  with a deco obligation → 24 h. A "strict" preset raises these
  (18 h / 24 h / 48 h).
- Countdown anchors to the last surfacing time (dive end).
- Surfaces: `DashboardAlerts` entry ("No-fly: 14 h 20 m remaining — until Sat
  07:40") and the Safety hub. Entry disappears on expiry.
- Stretch (off by default): local notification on expiry.

### Tissue desaturation view (informational)

Alongside the countdown, a desaturation chart reusing the
`surface_interval_tool` recovery model, seeded from the last dive's ending
tissue state (per-sample `DecoStatus` already exists), showing compartment
desaturation toward a 0.75 bar cabin-altitude ceiling. Labeled clearly:
"educational — not a flight clearance". No agency endorses computed no-fly
times; the guideline countdown is always primary.

### Altitude UX

The engine already supports altitude end-to-end
(`Dives.altitude`, `DiveSites.altitude`, `DiveEnvironment.forConditions`,
`AltitudeCalculator`). This phase adds surfacing only:

- Planner: show/edit surface altitude prominently; default from the selected
  site's altitude.
- Logged dives: informational flag when the site has altitude set but the
  dive's environment was not altitude-adjusted.

## Phase 3 — Offline emergency card

### The card

One screen readable by a stranger under stress: large type, high contrast, no
navigation once open. All data local:

- Diver: name, blood type, allergies, medications (existing `Divers` columns).
- Emergency contacts ×2 (existing).
- Insurance provider + policy number + expiry (existing).
- **Call DAN** — always the top, largest action; regional DAN hotline from the
  bundled dataset.
- Local EMS number (bundled per-country dataset; small and stable).
- Nearest chambers from the bundled directory + user overrides, sorted by
  distance to the last-known dive-site GPS.

Entry points: Safety hub, dashboard quick action; platform app-icon shortcut is
a stretch goal.

### Chamber directory (bundled + overrides)

- Bundled JSON asset compiled from DAN regional lists and national hyperbaric
  registries — a scoped data-curation task within this phase.
- Loaded into a read-only reference table following the built-in reference-data
  conventions (`isBuiltIn`-style: excluded from exporters, re-seeded in
  `beforeOpen`).
- Every entry carries a `lastVerified` date, shown in the UI.
- Users can add, edit, and hide entries; overrides are user data (synced,
  backed up).
- Staleness mitigations: "Call DAN first" is the primary action; verification
  dates are visible; dataset updates ride app releases in v1 (remote refresh is
  out of scope).

### Region resolution

Current region inferred from the most recent dive's site country; manual region
picker fallback. No network or location permission required.

## Phase 4 — Near-miss log

### Model

New table `incidents`: id, optional diveId, timestamp, category, severity,
narrative, contributingFactors, lessonsLearned, plus standard HLC/sync columns.
Standalone-first so incidents without a logged dive (boat/surface incidents,
aborted dives) are recordable.

Categories (adapted from diving-incident taxonomies): buoyancy, gas supply,
equipment, buddy separation, marine life, boat/surface, medical, planning,
other.

### UX

- Entry deliberately low-friction: category chips + severity + free-text
  narrative; all other fields optional.
- Surfaces: list + create from the Safety hub; "add near-miss" in dive detail
  overflow; linked-incident chip inside the dive's safety review section.

### Privacy (product requirement)

Incidents are **excluded from all outbound export and share flows by
default**, with an explicit opt-in per export.
Non-punitive reporting only works if the diver trusts it stays private.
(They are included in the user's own encrypted backups and device sync — the
exclusion is for outbound sharing formats: UDDF/CSV/Subsurface exports and any
shared/printable logbook output.)

## Cross-cutting

### Schema and sync

- New migrations claim the next free schema rungs at implementation time. The
  shared `schema_user_version` scalar collides across parallel branches, so the
  exact number is resolved at merge (whoever merges second renumbers). Phase 1
  as implemented ships at **v115** (`AppDatabase.currentSchemaVersion = 115`);
  re-verify the ladder when each phase lands.
- All new tables follow existing conventions: HLC columns for parent/aggregate
  entities, write-once child conventions (no HLC; `markRecordPending` +
  per-row `logDeletion`) for children of dives, idempotent `createTable` in
  `onUpgrade`, `beforeOpen` backstop.
- `dive_safety_findings`: derived but synced (cheap, avoids recompute on every
  device).
- `incidents` and chamber overrides: user data — synced and in backups.
- Bundled chamber/hotline/EMS reference data: built-in reference data —
  excluded from exporters, re-seeded in `beforeOpen`.

### Settings

New safety settings page: master toggle for the safety review, per-rule
toggles, no-fly conservatism preset (standard/strict), manual region override
for the emergency card.

### Units and localization

All depths, rates, and altitudes respect the active diver's unit settings. All
new strings are translated into all 10 non-English locales.

### Testing

TDD throughout. The review engine and no-fly classifier are pure functions
tested against fixture profiles (synthetic sawtooth, missed-stop, omitted
safety stop, clean dives, deco dives). Widget tests for the emergency card,
safety review section, and hub. Migration tests per new schema version.

## Out of scope (v1)

- Remote refresh of the chamber directory.
- Aggregate/community incident reporting or anonymized submission (e.g. to
  DAN's incident program) — individual log only.
- Push notifications beyond the optional no-fly expiry notification.
- Real-time (during-dive) warnings — this is a logbook, not a dive computer.
