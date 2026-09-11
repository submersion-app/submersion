# Equipment Condition Intelligence

Status: proposed
Date: 2026-09-09
Related: `2026-09-08-transmitter-registry-design.md` (PR #1677, schema v200),
the service ledger (schema v122 onward), the post-dive safety review.

## Problem

Service reminders are calendar clocks with an optional dive count or hours
count. They know nothing about what the gear went through: a regulator that
did 60 dives in 4 C water and one that did 60 dives in 28 C water read the
same. Divers who own rebreathers, transmitters and drysuits watch specific
signals by hand: cell millivolts in oxygen, transmitter dropouts, seal leaks.
The app stores some of that raw data already (per-sample cell millivolts,
tank pressure series, per-dive scrubber figures) and never looks at it.

This program evolves the service system into condition-based equipment
intelligence. Every item accumulates actual exposure, the app extracts
sensor evidence from each dive once, a rule engine reports trends with the
numbers behind them, and a light post-dive check-in captures the faults no
sensor sees.

Two rules govern every part of it:

1. Report evidence and trends. Never predict a failure, a remaining life, or a
   date. Every sentence carries its sample size and window.
2. Findings never change an item's status. The diver does that.

## Decisions taken during design

Each of these was asked and answered on 2026-09-09.

- One spec for the whole program, executed in four shippable phases.
- Gear check-in lives in the dive detail equipment section, inline per item.
- A regulator is linked to the cylinder it breathed from by a new field on
  each dive tank, defaulted from the last pairing seen.
- O2 cells and batteries are child equipment items with a parent link, not
  attributes and not dedicated tables.
- Thresholds (cold, deep, high O2) are built-in defaults with per-diver
  overrides, shown in the diver's units.
- Findings live in a new synced `equipment_findings` table shaped like the
  safety findings.
- Scrubber trip margin uses a history-based estimate with trip-level
  overrides.
- Architecture A: materialise only what needs a profile blob decode, once per
  dive, in a local sensor summary; exposure is a join over existing columns
  and thresholds apply at read time.
- Built-in service kinds ship exposure defaults (table below).
- Cell metrics keep per-dive divergence time ranges so the profile chart can
  highlight them.
- Several observations per item per dive are allowed.
- Observations are exported (UDDF full export, Excel, CSV). Findings are not.

## Architecture

```
dives, dive_tanks, dive_equipment, equipment(parent link)
        |                                    |
        v                                    v
DiveSensorSummaryService  --->  dive_sensor_summaries (local, per dive)
  (isolate; gain, divergence,                |
   gaps, scrubber, extremes)                 |
                                             v
ExposureRepository.getExposureSamplesForEquipment(id)   (one SQL union)
                                             |
                     +-----------------------+----------------------+
                     v                       v                      v
             ExposureClassifier       EquipmentConditionEngine   TripScrubberMargin
             (thresholds at read)     (rules, min n)             (provider, not stored)
                     |                       |
                     v                       v
             ServiceDueEngine         equipment_findings (synced)
             (units: days, dives,     equipment_condition_reviews (local marker)
              hours, saltHours,
              coldDives, o2Hours,
              deepCycles, cycles)
```

Inputs the engines never touch directly: profile blobs. The sensor summary
is the only consumer of decoded samples, and it runs once per dive version.

## Data model

Schema takes the next free rung after v200 (PR #1677). Before claiming it,
rescan open PRs and the worktree scalars, per the schema ladder memory. The
compatibility floor (`minimumCompatibleSchemaVersion`) does not move; every
change is additive.

### Changed tables

| Table | Change |
| --- | --- |
| `equipment` | `parent_equipment_id` TEXT NULL, references `equipment(id)` ON DELETE SET NULL |
| `dive_tanks` | `regulator_equipment_id` TEXT NULL, references `equipment(id)` ON DELETE SET NULL |
| `incidents` | `equipment_id` TEXT NULL, references `equipment(id)` ON DELETE SET NULL |
| `trips` | `expected_dives` INTEGER NULL, `expected_runtime_minutes` INTEGER NULL |
| `service_kinds` | `exposure_intervals` TEXT NOT NULL DEFAULT '{}' |
| `service_schedules` | `exposure_intervals` TEXT NOT NULL DEFAULT '{}' |

`exposure_intervals` is a JSON object keyed by `ExposureUnit` name with a
numeric value, for example `{"coldDives": 50, "o2Hours": 50}`. The schedule's
map overrides the kind's map key by key; a key absent from both means that
unit has no trigger. The existing `interval_days`, `interval_dives` and
`interval_hours` columns are untouched and keep their meaning. A future unit
needs a new enum value and no migration.

### New tables

`dive_sensor_summaries` (device-local, never synced, rebuilt by sweep):

| Column | Type | Meaning |
| --- | --- | --- |
| `dive_id` | TEXT PK, references `dives` ON DELETE CASCADE | |
| `engine_version` | INTEGER | `DiveSensorSummaryService.version` |
| `source_updated_at` | INTEGER | the dive's `updated_at` when computed |
| `computed_at` | INTEGER | |
| `min_temperature` | REAL NULL | profile minimum, Celsius |
| `max_depth` | REAL NULL | profile maximum, metres |
| `scrubber_consumed_minutes` | REAL NULL | see Scrubber below |
| `cell_metrics` | TEXT | JSON array, one entry per slot with data |
| `transmitter_gaps` | TEXT | JSON array, one entry per tank with a series |

`cell_metrics` entry:

```json
{"slot": 2, "samples": 1840, "gainMvPerBar": 51.3,
 "p95DivergenceBar": 0.04, "highPpO2Samples": 612, "lowAtHighFraction": 0.0,
 "divergenceRanges": [[1260, 1410, 0.14]]}
```

`transmitter_gaps` entry:

```json
{"tankId": "…", "transmitterSerial": "180777", "computerId": "…",
 "cadenceSeconds": 10, "gapSeconds": 130, "gapCount": 3,
 "longestGapSeconds": 80, "diveSeconds": 3480}
```

`equipment_observations` (synced aggregate root):

| Column | Type |
| --- | --- |
| `id` | TEXT PK |
| `diver_id` | TEXT NULL, references `divers` ON DELETE CASCADE |
| `equipment_id` | TEXT, references `equipment` ON DELETE CASCADE |
| `dive_id` | TEXT NULL, references `dives` ON DELETE SET NULL |
| `observed_at` | INTEGER |
| `status` | TEXT, `ok` or `issue` |
| `issue_tags` | TEXT, JSON array of `ObservationTag` names |
| `note` | TEXT NOT NULL DEFAULT '' |
| `created_at`, `updated_at` | INTEGER |
| `hlc` | TEXT NULL |

An `ok` row is a deliberate check and is evidence ("no issue in 12 checked
dives"). Any number of rows may share an item and a dive.

`equipment_findings` (synced, write-once except `dismissed_at`):

| Column | Type |
| --- | --- |
| `id` | TEXT PK, deterministic: `cf_<equipmentId>_<ruleId>` or `cf_<equipmentId>_<ruleId>_<slot>` |
| `equipment_id` | TEXT, references `equipment` ON DELETE CASCADE |
| `rule_id` | TEXT, `ConditionRuleId.dbValue` |
| `severity` | TEXT, `info`, `caution`, `significant` |
| `value` | REAL NULL, rule-specific number |
| `evidence` | TEXT, JSON: `{"n": 14, "windowStart": ms, "windowEnd": ms, "diveIds": [...], "values": {...}}` |
| `evidence_fingerprint` | TEXT, hash of the evidence dive ids and values |
| `engine_version` | INTEGER |
| `dismissed_at` | INTEGER NULL |
| `created_at` | INTEGER |

`equipment_condition_reviews` (device-local marker):

| Column | Type |
| --- | --- |
| `equipment_id` | TEXT PK, references `equipment` ON DELETE CASCADE |
| `engine_version` | INTEGER |
| `input_fingerprint` | TEXT |
| `reviewed_at` | INTEGER |

The input fingerprint is the newest exposure sample `updated_at`, the
observation and incident counts and newest `updated_at`, the thresholds, and
the engine version. An unchanged item costs one row read.

### Enums

`EquipmentType` gains `o2Cell('O2 Cell')` and `battery('Battery')`.

`ExposureUnit`: `days, dives, hours, saltHours, coldDives, o2Hours,
deepCycles, cycles`. `days`, `dives` and `hours` are represented by the
existing columns; the enum exists so the engine and the UI treat every unit
alike.

`ObservationTag`, grouped by the equipment types it is offered for. Names are
the stored values.

| Types | Tags |
| --- | --- |
| regulator | `freeFlow, hardBreathing, wetBreathing, leak, hoseDamage` |
| bcd | `inflatorStuck, inflatorSlow, bladderLeak, dumpLeak` |
| drysuit | `leakNeck, leakWrist, leakZip, leakBoot, leakValve, leakSeam` |
| wetsuit, undersuit, hood, gloves, boots | `tear, seamFailure` |
| light | `dim, died, flooded, switchFault` |
| computer | `batteryLow, screenFault, connectionFault` |
| transmitter | `dropout, batteryLow` |
| rebreather | `cellWarning, loopLeak, solenoidFault, scrubberBreakthrough` |
| o2Cell | `slowResponse, erratic` |
| battery | `died, lowCapacity` |
| dpv | `died, flooded, propFault` |
| fins, mask, snorkel | `strapBroke, leak` |
| every type | `other` |

`ConditionRuleId` and `ConditionSeverity` mirror `SafetyRuleId` and
`SafetySeverity` (`dbValue`, `fromDbValue`).

### Attribute catalog

- `o2Cell`: `cell_slot` (integer 1 to 6), `installed_date` (date).
- `battery`: `installed_date` (date), `battery_type` (text), `rechargeable`
  (flag).

A child inherits its parent's dive links for dives whose date is on or after
`installed_date` (or the child's `created_at` when the attribute is unset).
A retired child keeps its history; replacement creates a new child in the
same slot.

### Settings (SharedPreferences, like the safety settings)

| Key | Default | Notes |
| --- | --- | --- |
| condition engine enabled | true | master toggle |
| cold threshold | 10 C | stored Celsius, shown in diver units |
| deep threshold | 30 m | stored metres |
| high O2 threshold | 40 percent | O2 fraction |
| rule toggles | all on | one per `ConditionRuleId` |

## Exposure and service clocks

### Exposure sample

`DiveUsageSample` becomes `EquipmentExposureSample`:

| Field | Source |
| --- | --- |
| `date` | dive start |
| `durationSeconds` | dive runtime |
| `diveMode` | `dives.dive_mode` |
| `maxDepth` | summary `max_depth`, else `dives.max_depth` |
| `minTemperature` | summary `min_temperature`, else `dives.water_temp` |
| `waterType` | `dives.water_type` |
| `contactO2Fraction` | per link path, below; null when no contact |
| `updatedAt` | dive `updated_at`, for fingerprints |

Contact O2 by link path:

- tank item (`dive_tanks.equipment_id`): its own `o2_percent`;
- regulator (`dive_tanks.regulator_equipment_id`): max over the tanks naming
  it;
- rebreather (`dive_equipment`): max over tanks with role `diluent` or
  `oxygenSupply` on that dive; 1.0 when the dive is CCR mode and no such tank
  is recorded;
- child items: the parent's value;
- everything else: null, so O2 hours never accrue by accident.

### One query

`getExposureSamplesForEquipment(id)` replaces
`getUsageSamplesForEquipment`. It is a single SQL union over
`dive_equipment`, `dive_tanks.equipment_id`,
`dive_tanks.regulator_equipment_id`, and the parent's links filtered by the
child's install date, left-joined to `dive_sensor_summaries`. A test pins the
statement count at one. Exposure ignores `excluded_from_stats`; that flag
concerns statistics, and the gear was still wet.

### Classification

`ExposureClassifier(thresholds)` is pure. Per sample:

| Unit | Counts when |
| --- | --- |
| `saltHours` | water type is salt or brackish; adds runtime hours |
| `coldDives` | `minTemperature` is below the cold threshold |
| `deepCycles` | `maxDepth` is at or beyond the deep threshold |
| `o2Hours` | `contactO2Fraction` exceeds the O2 threshold; adds runtime hours |
| `cycles` | one per dive, except that a parent with an installed `battery` child accrues none (the child does) |
| `hours` | runtime hours; for rebreather items and their children, CCR and SCR mode dives only |
| `dives` | always one |

Changing a threshold changes every total on the next read. Nothing is
rebuilt.

### Engine

`ServiceDueEngine.evaluate` takes `List<EquipmentExposureSample>` and an
`ExposureClassifier`. For each configured unit (interval from the schedule's
map, else the kind's map, plus the three legacy columns) it computes the
since-anchor total and the remaining amount over the samples after the
anchor. The anchor chain is unchanged: newest service record of the kind,
then `anchor_date`, then purchase date, then `created_at`.

`ServiceClockStatus` gains `usageByUnit: Map<ExposureUnit, ClockUsage>` where
`ClockUsage(interval, since, remaining)`. `divesSinceAnchor`,
`divesRemaining`, `hoursSinceAnchor` and `hoursRemaining` become getters over
that map so every current consumer compiles unchanged. Severity is
unchanged: any unit at or below zero remaining is overdue; any unit within
10 percent of its interval is due soon; a date trigger keeps its window.

For the `scrubber-repack` kind, hours consume `scrubber_consumed_minutes`
from the summary when present and runtime otherwise.

### Seed defaults

The migration backfills `exposure_intervals` and `applicable_types` on the
built-in rows (`is_built_in = 1`). These are starting points, not
manufacturer figures. Built-in kinds stay read-only, as they are today; a
diver adjusts a default per item through the schedule override dialog, and
the custom-kind editor carries the same fields for kinds the diver creates.

| Kind | Exposure default | Applicable types change |
| --- | --- | --- |
| `regulator-service` | `coldDives: 50` | |
| `o2-clean` | `o2Hours: 50` | adds `regulator` |
| `transmitter-battery` | `hours: 250` (legacy hours column) | adds `battery` |
| `computer-battery` | none | adds `battery` |
| `drysuit-seals` | `saltHours: 200` | |
| `o2-cell-replacement` | none | adds `o2Cell` |

`kSeedBuiltInServiceKindsSql` and `kBuiltInServiceKindCategories` change
together, and the v160 category test that pins both is updated in the same
commit.

### Notifications

Usage-driven clocks get a push for the first time. When the scheduler
evaluates a clock whose worst unit is `dueSoon` or `overdue` and that clock
has no date trigger, it schedules one local notification for the next
reminder time, deduplicated per `(schedule_id, anchor)` through the existing
`scheduled_notifications` table. The per-item reminder override semantics
apply unchanged.

## Sensor summary

`DiveSensorSummaryService` (pure, `version = 1`) takes the decoded primary
profile, the dive's tanks with their pressure series, the dive mode and the
dive's scrubber fields, and returns a `DiveSensorSummary`. It runs on an
isolate through the same mechanism as `series_profile_aggregates.dart`.

`diveSensorSummaryProvider(diveId)` computes through the cache: it returns
the stored row when `engine_version` and `source_updated_at` match, else
recomputes and stores. `EquipmentConditionSweep` runs the provider over
dives whose row is stale or missing after a computer download, a re-parse, a
restore, and a dive edit that touched tanks or the profile, oldest first,
with the same cancel and progress contract as `SafetyReviewSweep`.

### Cell metrics, per slot with millivolt data

- Gain: median over samples of `mV / ppO2` for the slot's own calibrated
  reading, in mV per bar. The computer derives ppO2 from mV through its
  pre-dive calibration, so this is the calibration gain, which is the "mV in
  oxygen" figure that declines over a cell's life. Samples with ppO2 below
  0.2 bar are skipped.
- Divergence: the slot's ppO2 minus the median of all slots with data at that
  sample. Store the 95th percentile of the absolute value.
- Divergence ranges: contiguous runs where the absolute divergence exceeds
  0.1 bar for at least 30 seconds, as `[start, end, peak]` in profile
  seconds.
- Current limiting: over samples where the median ppO2 exceeds 1.2 bar, the
  fraction where the slot reads more than 0.1 bar below the median, computed
  only when the slot agreed within 0.05 bar at ppO2 at or below 1.0 bar on
  the same dive. Store `highPpO2Samples` and `lowAtHighFraction`.
- `samples`: count used, so every sentence can state n.

A dive with fewer than two slots carrying data yields gain only, no
divergence.

### Transmitter gaps, per tank with a pressure series

Cadence is the median interval between consecutive samples. A gap is an
interval longer than three times the cadence, or a run of samples with no
pressure value while the depth series continues. Store total gap seconds,
gap count, the longest gap, the cadence, and the dive seconds the series
spans. The gap fraction used by the rules is `gapSeconds / diveSeconds`.
The entry is keyed by the tank's normalised transmitter serial (through
`normalizeTransmitterSerial`) and the computer id; the registry from PR #1677
maps a serial to a transmitter item.

### Scrubber

`scrubber_consumed_minutes` is `scrubber_duration_minutes` minus
`scrubber_remaining_minutes` when both are present and the difference is
non-negative; else runtime minutes for CCR and SCR mode dives; else null.

### Extremes

Minimum temperature and maximum depth over the primary profile.

## Condition findings

### Engine

`EquipmentConditionEngine` (pure, `engineVersion = 1`) takes the item, its
children, its exposure samples with summaries, its observations, its
incidents, the thresholds, the enabled rule set and `now`, and returns
`List<EquipmentFinding>`. `equipmentConditionProvider(equipmentId)` computes
through the cache using the review marker. The sweep runs the engine over
active gear after summaries refresh and after any observation or incident
write for that item.

Windows are "the last k dives that have the relevant data", never calendar
windows, because usage is bursty. Every rule has a minimum n below which it
emits nothing.

### Rules

| Rule id | Applies to | Emits when | `value` |
| --- | --- | --- | --- |
| `cellOutputDeclining` | o2Cell, or a rebreather slot with no cell item | median gain over the last 5 dives is at least 15 percent below the median over the first 5 dives since install; n at least 10 | percent drop |
| `cellOutputLow` | same | median gain over the last 3 dives below 40 mV per bar | gain |
| `cellDivergent` | same | p95 divergence above 0.1 bar in at least 3 of the last 5 dives | worst p95 |
| `cellCurrentLimited` | same | `lowAtHighFraction` above 0.5 in at least 2 of the last 5 dives that reached 1.2 bar | fraction |
| `transmitterDropoutRising` | transmitter | mean gap fraction over the last 5 dives at least double the mean over the previous 10 and at least 0.05; n at least 15 | recent mean |
| `transmitterDropoutHigh` | transmitter | gap fraction at least 0.10 in 3 of the last 5 dives | recent mean |
| `issueRecurring` | any | the same tag on at least 3 observations whose dives fall within the item's last 20 dives | count |
| `issueColdCorrelated` | regulator, bcd, drysuit, light | share of cold dives with at least one issue observation is at least three times the share of warm dives; at least 3 cold issue dives and at least 5 dives on each side | ratio |
| `issueDeepCorrelated` | same | the same shape using the deep line | ratio |
| `incidentLinked` | any | an incident of severity moderate or serious names this item | count |

Severity: `info` for the two correlation rules and `incidentLinked`;
`caution` for `cellOutputDeclining`, `cellDivergent`,
`transmitterDropoutRising` and `issueRecurring`; `significant` for
`cellOutputLow`, `cellCurrentLimited` and `transmitterDropoutHigh`.

Slot rules emit one finding per slot. When a cell child item occupies the
slot on the evidence dives, the finding attaches to the child; otherwise to
the rebreather with the slot in the id.

### Evidence and wording

Each finding stores n, window start and end dates, the dive ids, and the
numbers the sentence is built from. Display text is composed at render time
from localized templates with values formatted in the diver's units:

- "Cell 2 output fell 22 percent across 14 dives since 3 March."
- "3 of 4 free-flow reports were on dives colder than 8 C, over 41 dives
  with this regulator."
- "Pressure dropped out for 12 percent of the last 5 dives, up from 3
  percent over the 10 before."

No rule produces a date, a remaining life, or a probability. The word
"predict" does not appear in any template.

### Dismissal

Deterministic ids mean a rule re-emits into the same row. A dismissed
finding stays dismissed until three new dives have contributed to its
evidence after `dismissed_at`; then `dismissed_at` clears and the fingerprint
updates. A finding whose rule stops firing is deleted (with `logDeletion`).

## Observations and incidents

### Gear check-in

In the dive detail equipment section, each linked item row shows a trailing
status chip: nothing when the item has no observation on this dive, a check
for `ok`, a warning glyph when any observation is an `issue`. Tapping opens
a bottom sheet listing the item's observations for this dive, each editable
and deletable, with an add action. A new observation has an OK/Issue toggle,
tag chips filtered to the item's type plus `other`, and a note.
`observed_at` defaults to the dive's exit time.

The same sheet opens from the item's condition section with an optional dive
picker, for problems noticed on the bench.

### Incidents

The incident form gains an optional equipment picker. When the incident has
a dive, the picker lists that dive's gear first and all active gear below.
Choosing an item preselects the `equipment` category when no category is
set.

## Surfaces

### Equipment detail: condition section

Below the service clocks card:

- Exposure card: totals per unit in the diver's units, with the dive count
  and date range covered.
- Findings list: undismissed first, dismissed collapsed; each shows its
  sentence, n and window, and taps through to the evidence dives.
- Trend chart, using `dive_trend_chart.dart`: cell gain per dive (one line
  per slot) for cells and rebreathers; gap fraction per dive for
  transmitters; consumed scrubber minutes per dive for rebreathers; minimum
  temperature per dive with issue markers for regulators, BCDs, drysuits and
  lights.
- Children card on rebreathers, computers, transmitters, lights and DPVs:
  each slot with its installed child, age since install, clock badge, and a
  replace action that retires the child and creates a new one in the slot.
- Observations list with edit and delete.

### Elsewhere

- Equipment list and dense tiles: the badge is the worst of clock severity
  and undismissed finding severity.
- Trip detail and the upcoming-trip banner: a scrubber margin card per
  active rebreather; the trip edit page carries the two override fields.
- Pre-dive session snapshot: `significant` findings join the overdue clocks.
- Equipment statistics page: exposure rankings by unit, findings by type,
  most frequent issue tags. `getMostUsedGear` starts unioning `dive_tanks`
  so cylinders count.
- Settings: an "Equipment condition" page with the master toggle, the three
  thresholds and the rule toggles. It is a settings page, not a manage page.
- Dive profile chart: divergence ranges highlighted through the existing
  highlight-range overlay when the O2 cell overlay is on.
- Tank editor: a regulator picker on each tank, prefilled from the most
  recent dive tank with the same equipment id or preset name that had a
  regulator.

### Trip scrubber margin

A provider, not a stored finding. For each active rebreather:

- remaining before trip = rated minutes (the `scrubber_duration_h` attribute,
  else the schedule's hours interval) minus consumed minutes since the newest
  `scrubber-repack` record;
- expected dives = `trips.expected_dives`, else dive days from the itinerary
  times the median dives per dive day over the diver's last three trips
  (default 2 when there is no history);
- expected use = expected dives times (`trips.expected_runtime_minutes`, else
  the median `scrubber_consumed_minutes` over the last 30 CCR and SCR dives
  (both pack a scrubber), default their median runtime when no dive carries
  scrubber figures);
- margin after = remaining minus expected use.

The card states all four figures, the n behind each estimate, and a caution
line when the margin is under 20 percent of the rated duration or negative.

## Sync, migration, export

### Sync

- `equipment_observations`: full-row aggregate root in `_baseTables`, delta
  export by hlc, the usual apply and merge arms.
- `equipment_findings`: the safety findings path; `markRecordPending` on
  create and on any `dismissed_at` change, `logDeletion` on removal.
- New columns on `equipment`, `dive_tanks`, `incidents`, `trips`,
  `service_kinds` and `service_schedules` travel with whole-row JSON. Each
  gets a line in `cross_version_roundtrip_test.dart`.
- `dive_sensor_summaries` and `equipment_condition_reviews` are device-local.
  After a restore or a first sync the sweep rebuilds them.
- No device-local columns are added to synced tables, so the import wipe
  concern from the clock-sync work does not apply.

### Migration

One rung. It adds the columns, creates the four tables, backfills
`exposure_intervals` and `applicable_types` on built-in kinds, and updates
the seed SQL for fresh installs. No summary or finding backfill; the first
sweep fills them. A migration test covers a v-previous database upgraded
through the rung.

### Export and import

- UDDF full export: under `<applicationdata><submersion><equipment><item>`,
  add `<parentref>` (the parent's `equip_` id) and
  `<observations><observation>` children with `date`, optional `diveref`,
  `status`, `<tags><tag>` and `note`. The full importer reads them back and
  resolves refs after equipment and dives are inserted.
- Excel whole-library export: an "Observations" sheet beside the
  maintenance sheet (item, type, date, dive number, status, tags, note).
- CSV: `generateObservationsCsvContent` and a companion
  `observations_export.csv` offered next to the equipment CSV.
- Findings and sensor summaries are derived and are not exported.
- Incidents remain excluded from every exporter.

## Localization and units

Every string goes through `context.l10n`. Keys use the prefixes
`equipment_condition_`, `equipment_observation_`, `equipment_exposure_` and
`trip_scrubberMargin_`, inserted into all eleven ARB files anchored on a
neighbouring key. Tag names, unit names and rule sentences are templates
whose numeric placeholders are formatted first in the diver's units through
the existing unit formatters, and date formatting receives the l10n
instance. Thresholds display and edit in the diver's temperature and depth
units and store metric.

## Testing (written first)

Pure:

- `ExposureClassifier` at each threshold boundary, including brackish water
  and null temperatures.
- `ServiceDueEngine` for every unit, the map override precedence, the
  compatibility getters, and the rebreather hours rule.
- `DiveSensorSummaryService` on synthetic samples: gain, p95 divergence,
  divergence ranges at exactly 30 seconds, current limiting with and without
  low-ppO2 agreement, a gap at exactly three times cadence, missing-pressure
  runs; and on `petrel3_ccr_o2_cells.bin`, pinning the gain per slot.
- `EquipmentConditionEngine` with fixtures at n minus one and n for every
  rule, slot attachment to a cell child, dismissal clearing after exactly
  three new dives, and rule toggles.
- Trip margin estimator: overrides, history medians, defaults with no
  history, the caution line boundary.

Database:

- Migration test for the rung; the v160 seed test updated for the new
  defaults and types.
- Exposure query statement count pinned at one, with a child item, a
  regulator link and a tank link on the same dive counted once each.
- Sync round-trip for both new tables and every new column.
- Observation cascade on equipment delete and set-null on dive delete.

Providers (in-memory Drift):

- Sweep skips a current summary and recomputes a stale one.
- Findings invalidate after an observation write and after a threshold
  change.
- Clock providers reflect an exposure interval within one poll.

Widgets:

- Check-in sheet (add, edit, delete, tag filtering by type).
- Condition section (exposure units in feet and Fahrenheit for an imperial
  diver).
- Trip margin card, settings page, child replace flow, incident equipment
  picker.

Every new regression test is run once against the unfixed code to prove it
fails before the implementation lands.

## Non-goals

- Battery voltage or charge level from computer downloads (a later
  libdivecomputer fork change, like the transmitter serial).
- Predicted failure dates, remaining-life estimates or probabilities.
- Automatic status changes on equipment.
- Per-service-kind thresholds.
- Scrubber derating factors beyond the diver's own consumption history.
- Exporting findings or sensor summaries.

## Implementation phases

Each phase leaves the app shippable and gets its own plan section.

1. Schema, enums, child items, regulator link, exposure query, classifier,
   engine units, seed defaults, schedule and kind editors, usage clock
   notifications.
2. Sensor summary service, provider, sweep hooks, profile chart divergence
   highlight.
3. Observations (table, sheet, item list), incident equipment link, condition
   engine, findings table, review marker, settings page, exports.
4. Condition section, trend charts, children card, badges, trip margin,
   pre-dive snapshot, statistics page.
