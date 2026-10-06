# Data Quality Assistant — Design

Date: 2026-07-17
Status: Approved (brainstorming session)
Branch: worktree-data-quality-assistant
Delivery: single branch, one PR

## Summary

A review inbox for suspicious dive data. Detectors scan dives — at import
time and retroactively across the library — and produce findings for:
clock/timezone errors, depth spikes and sample gaps, implausible temperature
or pressure changes, gas-switch/MOD inconsistencies, tank pressures assigned
to the wrong cylinder, conflicting computer profiles, and likely duplicates
or accidental dive splits. Every finding offers a guided, undoable repair
(full repair suite), delegating to existing services where they exist and to
a new ProfileRepairService for profile-sample surgery.

Core decisions (user-approved):

1. Scan scope: both import-time (targeted) and retroactive (full-library).
2. Fix depth: full repair suite, including profile-sample surgery.
3. Delivery: single branch, one PR.
4. Entry point: Dives app-bar icon with count badge; route `/dives/quality`.
5. Sync: findings are first-class HLC-synced entities.

Architecture: detector pipeline + materialized synced findings table, with
SQL pre-filters narrowing the full-library scan before context loading.

## Data model

### New table `quality_findings` (schema vNext — nominally v118)

Re-verify the ladder and open PR claims at implementation time; v113–v117
are claimed by open branches as of 2026-07-17 (see schema-version-ladder
memory). Migration test asserts `greaterThanOrEqualTo(118)` +
`contains(118)` from the start.

| Column            | Type            | Notes                                        |
|-------------------|-----------------|----------------------------------------------|
| `id`              | text PK         | UUIDv5 of `diveId \| detectorId \| discriminator` |
| `diveId`          | text FK → dives | cascade delete                               |
| `relatedDiveId`   | text FK, nullable, setNull | other dive for duplicates/splits  |
| `computerId`      | text FK, nullable, setNull | source-scoped findings            |
| `detectorId`      | text            | e.g. `clock_offset`, `depth_spike`           |
| `detectorVersion` | int             | bumped when detector logic changes           |
| `category`        | text            | time / profile / temperature / pressure / gas / tank / source / duplicate |
| `severity`        | text            | info / warning / critical                    |
| `status`          | text            | open / dismissed / resolved                  |
| `params`          | text (JSON)     | numeric args only; UI renders via l10n keys + unit prefs; never stored prose |
| `createdAt`       | int             |                                              |
| `updatedAt`       | int             |                                              |
| `hlc`             | text            | synced: `_hlcTables`, serializer, tombstone entity type |

Indexes: `(dive_id)`, `(status)`.

### Identity and lifecycle

- Deterministic ids: independent scans on two devices converge on the same
  row. Discriminators make multi-instance findings stable across rescans
  (a depth spike keys on its sample-time bucket; a duplicate keys on the
  sorted pair of dive ids).
- Upsert preserves status: a rescan that re-produces a finding updates
  `params`/`severity`/`detectorVersion`/`updatedAt`/`hlc` but never flips
  `dismissed` back to `open`. Dismissal is a status update (LWW-safe),
  never a row delete — deterministic ids + deletes would resurrect
  dismissed findings on rescan (junction-reinsert lesson, #347).
- Findings no longer produced by a rescan are deleted with per-row
  tombstones, whatever their status. A repaired finding is marked
  `resolved` immediately for UI feedback; the automatic post-repair rescan
  then deletes it.
- Dive deletion cascades findings locally; peers cascade identically when
  the dive tombstone arrives.
- Accepted trade-off: a dismissed finding whose discriminator shifts on
  rescan (e.g. a spike's time bucket moves) reappears as a new open
  finding. Bucketing keeps this rare; fuzzy-matching old dismissals is not
  worth the complexity.

### Scan bookkeeping (device-local, not synced)

Shared prefs: last full-scan time + the detector-version vector it ran
with. Only the scanning device writes findings; peers receive rows via
sync. A version-vector mismatch at app start shows a passive "new checks
available — rescan" banner in the inbox (never an automatic scan; the
startup-maintenance-runner precedent is abandoned).

## Detector framework

```dart
abstract class QualityDetector {
  String get id;
  int get version;
  QualityCategory get category;
  List<QualityFinding> detect(DiveQualityContext context);
}
```

- Detectors are pure, synchronous functions. `DiveQualityContext` bundles:
  the dive entity, profile samples grouped by source, tanks + per-tank
  pressure series, gas switches, `DiveDataSources` rows, and lightweight
  summaries of chronological prev/next dives for the same diver. One
  context load per dive, shared by all detectors.
- All thresholds live in a single `const QualityThresholds` object.
- SQL pre-filters: each detector family declares an optional pre-filter
  that narrows the library to candidate dive ids before context loading
  (self-join on entry-time windows for duplicates/splits/overlaps,
  `entryTime > now` for clock checks, `EXISTS(profile rows)` for
  sample-level detectors).

## Detectors (11 ids covering the 7 requested categories)

| Detector | Fires when | Severity |
|---|---|---|
| `clock_offset` | Sources of one dive disagree on entry time by ≈ whole hours (±1–14 h, minutes aligned — unset-timezone signature); entry time in the future or before 1950; consecutive same-diver dives overlap in time | warning; critical if future-dated |
| `sample_gap` | Sample interval > max(2× profile's median interval, 30 s) | info; warning if gaps total > 10% of runtime |
| `depth_spike` | Single sample departing and returning at implied rate > 3 m/s; any mid-dive depth < −0.5 m; stored `maxDepth` vs profile max disagree > 5% | warning |
| `impossible_rate` | Sustained (≥ 30 s) vertical rate > 30 m/min (data error, distinct from ascent-rate safety events) | warning |
| `temp_anomaly` | Water temp outside −2…40 °C (incl. Shearwater °F-as-Kelvin bug); adjacent-sample jump > 5 °C or > 10 °C within 60 s | warning |
| `pressure_anomaly` | Pressure rising > 5 bar mid-dive with no gas switch; end > start on tank record; tank record vs pressure-series endpoints differ > 10 bar; drop rate implying surface-equivalent consumption > 100 L/min sustained | warning |
| `gas_mod` | ppO2 = fO2 × (depth/10 + 1) sustained > 1.6 for ≥ 1 min on the gas in use; hypoxic mix (fO2 < 0.16) in use at < 3 m for > 2 min; gas switch targeting a tank whose MOD is shallower than the switch depth | warning; critical ≥ 1.8 ppO2 |
| `tank_assignment` | > 70% of a tank's pressure drop occurs while the gas-switch timeline says it wasn't in use (active tank flat); two tanks with near-identical pressure series (double-assigned transmitter) | warning |
| `source_conflict` | Multi-source dives where sources disagree: max depth > 5% or > 2 m; duration > 10%; temp > 3 °C. Params record depth ratio; consistent ≈ 1.025 → "salt/fresh setting" hint | info–warning |
| `duplicate` | Existing `DiveMatcher` (0.5 possible / 0.7 probable) over SQL pre-filtered ±15 min same-diver window; excludes pairs already consolidated as sources of one dive; id keys on sorted dive-id pair | warning; critical ≥ 0.7 |
| `split_pair` | Same source/serial, surface interval ≤ 10 min, boundary looks like a continuation (A ends > 1 m deep, or B starts deep, or both shallow with interval ≤ 3 min) | warning |

Out of v1 scope: CCR-specific plausibility (setpoint vs cell readings)
beyond what `gas_mod` covers — a future detector; per-detector versioning
makes adding it cheap.

Rationale for split ids: dismissal, versioning, and settings toggles key on
detector id (e.g. a freediver mutes `impossible_rate` without losing spike
detection). `duplicate` reuses `DiveMatcher` so the inbox and the import
wizard can never disagree about what counts as a duplicate.

## Scan orchestration

`QualityScanService` — two entry points:

### Targeted scan `scan(Set<String> diveIds)`

Runs after: import completion (all three adapters — universal file,
dive-computer download, HealthKit — pass the just-written dive ids; the
import summary step shows "N items need review" linking to the inbox),
any dive save (single edit, bulk edit, consolidation, split), and any
repair (so the fixed finding is cleaned up).

The scan set silently expands to chronological neighbors within the
duplicate/split window (±15 min, same diver). Cross-dive findings have two
parent dives but one row keyed on the sorted pair; scanning both members
together means either dive's edit retires the finding and no scan ordering
can produce two rows for one pair.

### Full scan (user-triggered only)

From the inbox ("Scan all dives"); never automatic at startup. Run SQL
pre-filters once → candidate ids per family → batches of ~200 dives
(load contexts, run detectors, write findings) with a progress stream and
cancellation at batch boundaries. Cancel keeps what was written; rerun is
idempotent (deterministic ids).

### Write discipline

- One transaction per batch; one `notifyLocalChange` per batch (not per
  finding) — avoids the sync invalidation storm.
- Per scope (dive ∈ scanned set, detector ∈ ran set): upsert re-produced
  findings preserving `dismissed`; delete non-re-produced ones with
  per-row tombstones. Detectors that did not run (pre-filtered out or
  disabled) leave their findings untouched — disabling a detector stops
  new detection, never mass-deletes.
- Single-flight: one scan at a time; targeted requests arriving mid-scan
  queue and merge.

## Repair engine

Sealed `QualityRepair` hierarchy; each finding maps to repair options.
Contract for every repair (bulk-edit engine discipline): snapshot prior
state → one transaction → single `notifyLocalChange` → undo snackbar →
targeted rescan of affected dives. Destructive repairs confirm first.

| Finding | Repairs | Delegates to |
|---|---|---|
| `clock_offset` | "Shift time by ±N" (pre-filled with detected offset); "Apply same shift to all dives from this computer in this import" | NEW `bulkShiftDiveTimes` repo method (set-based update; profile timestamps are seconds-from-start so only dive-level times move) |
| `sample_gap` | "Fill by interpolation" for gaps ≤ 5 min; longer gaps explain + navigate | NEW `ProfileRepairService` |
| `depth_spike` | "Remove spike" (neighbor interpolation); "Recalculate metrics from profile" for maxDepth mismatch | `ProfileRepairService`; existing analysis pipeline |
| `impossible_rate` | Despike if isolated; else explain + navigate | `ProfileRepairService` |
| `temp_anomaly` | "Convert temperature" when °F-as-Kelvin signature matches; "Smooth temperature" (temp channel only); edit for out-of-range scalars | `ProfileRepairService`; unit conversion |
| `pressure_anomaly` | "Swap start/end pressure"; "Set from pressure series" | Tank repo update |
| `gas_mod` | No auto-fix (cannot know whether mix or switch depth is the lie); quick actions open tank/gas editor with finding context | Navigation + existing editors |
| `tank_assignment` | "Swap pressure series between tanks"; "Reassign series to…" picker | NEW FK-update repair on `tank_pressure_profiles` rows (per-row `markRecordPending`) |
| `source_conflict` | "Set primary source"; "Split into separate dives"; "Compare profiles" | Active-source machinery; `DiveSplitService`; existing overlay/compare |
| `duplicate` | "Consolidate" (with comparison card + sparkline); "Delete this one"; "Not a duplicate" = dismiss | `DiveConsolidationService` via `runDiveConsolidation` |
| `split_pair` | "Combine into one dive" | Existing combine-dives flow |

Repair policy: automate mechanics, never judgment. A repair must be
information-preserving and unambiguous to get a one-tap action; otherwise
it explains and navigates.

### ProfileRepairService (the one new engine)

Input: dive, source family, list of sample operations
(replace-with-interpolation, drop). Follows the established edited-profile
pattern: write the corrected series as new rows in the primary family,
demote originals to `isPrimary = false`, never delete computer data. Undo
restores flags and tombstones the edited rows. Because the pattern already
exists, sync, source attribution UI, and original-vs-edited chart
affordances work unchanged. Repair sheet shows a before/after sparkline.

## UI

- Route `/dives/quality`, registered BEFORE the `:diveId` param route.
- Dives app-bar inbox icon: always visible; count badge when open findings
  exist; badge driven by a watch-query provider on
  `quality_findings where status = open` (live under sync).
- Inbox: flat list, most-severe/newest first; filter chips with counts —
  chips, not tabs (an inbox is usually sparse). Chip → category mapping:
  All; Time (time); Profile (profile, temperature); Gas (gas); Tanks
  (tank, pressure); Duplicates (duplicate); Sources (source). Consecutive
  findings on one dive collapse under a dive header.
- Cards (duplicate_action_card collapsible pattern):
  - collapsed: severity icon, localized title from detector l10n key +
    `params`, dive context line (date · site · depth), primary repair
    button;
  - expanded: full explanation, evidence visuals (before/after sparkline
    for profile repairs; `DiveComparisonCard` for duplicates/splits;
    per-source stat table for conflicts), all repair options, Dismiss,
    Go to dive.
- Bulk: multi-select bulk dismiss; "dismiss all in this filter".
- Scan UX: "Scan library" in inbox app bar; linear progress with count and
  cancel; empty state shows last-scan time + CTA; new-detector-version
  banner above the list.
- Peripheral surfacing (thin): import summary line "N items flagged for
  review" deep-linking to the inbox filtered to imported dives; dive
  detail header chip when the dive has open findings (links to inbox
  filtered to that dive); Settings > "Data quality" screen with
  per-detector toggles (all on by default; gate detection only).
- Localization: detector title/description/repair-label keys × all 11
  locales; messages interpolate numeric `params` through unit-preference
  formatting (depths, pressures, temperatures respect the diver's units).
  Storing facts not sentences is what makes synced findings locale- and
  unit-safe across devices.

## Testing

- Detector unit tests: synthetic profile builders; positive/negative/
  boundary vectors per detector with hand-computed expected values against
  `QualityThresholds` (e.g. EAN50 at 35 m → ppO2 = 0.5 × 4.5 = 2.25,
  computed in the test comment).
- Scan service integration (in-memory Drift, `test_database` helpers):
  upsert-preserves-dismissed; retire-with-tombstone; neighbor expansion
  retires a pair finding when one dive is edited; batch cancellation keeps
  partial results; single-flight merging.
- Sync: serializer round-trip for the new entity type; two-device
  dismissal-LWW test seeded via a real pull, not local inserts (tombstone
  semantics only hold for fully-synced rows).
- Repairs: undo restores byte-identical prior state; ProfileRepairService
  asserts originals demoted, never deleted.
- Migration v118 test: `greaterThanOrEqualTo(118)` + `contains(118)`.
- Widget tests: inbox empty state, chip filtering, card expand, dismiss
  flow, badge count provider.

## Error handling

- Per-detector, per-dive exception isolation: a throwing detector logs,
  increments an error counter, and the scan continues; scan summary
  reports "N dives could not be fully checked" — no silent skips.
- Context sanitization: guard empty/single-sample profiles and NaN depths
  before detectors run; detectors may assume finite numbers.
- Repair failure: transaction rolls back, error snackbar, finding stays
  open and retryable.
- Performance: profiles load per-batch, never whole-library; indexes on
  `quality_findings(dive_id)` and `(status)`.

## New / touched surfaces (implementation map)

- NEW `lib/features/data_quality/`: domain (detectors, thresholds,
  context, finding entity, repair hierarchy), data (findings repository,
  scan service, ProfileRepairService), presentation (inbox page, cards,
  providers, settings screen).
- `lib/core/database/database.dart`: `quality_findings` table, migration
  vNext (nominally v118), `beforeOpen` backstop assert, `_hlcTables` +
  serializer + tombstone entity type.
- Import adapters (universal, dive-computer, HealthKit): post-import
  targeted scan hook + summary line.
- Dive save paths (edit, bulk edit, consolidation, split): targeted rescan
  hook.
- `app_router.dart`: `/dives/quality` before `:diveId`.
- Dives app bar: inbox icon + badge. Dive detail header: findings chip.
- Settings: Data quality screen.
- l10n: new keys in all 11 locales + regeneration.
