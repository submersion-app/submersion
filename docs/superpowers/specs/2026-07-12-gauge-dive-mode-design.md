# Gauge Dive Mode — Design

- **Issue:** [#569 — Ability to remove tank for gauge dives](https://github.com/submersion-app/submersion/issues/569)
- **Date:** 2026-07-12
- **Branch:** `worktree-gauge-dive-mode`

## Problem

The reporter logs gauge (bottom-timer) dives where they only want the depth+time
profile. If they populate a tank/gas, "the deco profile and all the other stats
get messed up."

Investigation surfaced a mismatch between the issue title ("remove the tank") and
the body ("deco profile ... gets messed up"):

- The OC deco profile, CNS%, OTU, ppO2, MOD/END, and gas-density curves are
  computed from the **depth+time profile alone, assuming air (21/0) whenever the
  gas is unknown**. This air fallback fires at
  `profile_analysis_provider.dart:770`, `:1277`, and
  `buildProfileGasSegments:179` **whether or not a tank exists**.
- Therefore deleting the tank does **not** stop the deco/tox analysis. Removing
  tanks only cleans up the gas-mix statistic (which mis-counts a gauge dive as an
  "Air" dive), the cylinder tile on the detail page, and per-cylinder SAC.

To fully deliver on the body's complaint we need a **gate** keyed off dive intent,
not tank presence. The chosen approach is a first-class **Gauge dive mode**.

## Decisions (confirmed with maintainer)

1. **First-class Gauge mode.** Add `gauge` to the `DiveMode` enum
   (`oc`/`ccr`/`scr`/`gauge`). This matches how real dive computers expose a
   Gauge/bottom-timer mode and is the domain-correct model.
2. **Keep tank data, suppress by mode.** Switching an existing dive to Gauge keeps
   its tank rows in the DB but hides the tank/gas UI and suppresses all gas/deco
   analysis based on `dive_mode == gauge`. Gas-stat SQL queries gain a
   `dive_mode <> 'gauge'` filter so retained rows don't pollute stats. Fully
   reversible: switching back to OC restores gas/deco.
3. **Auto-detect from downloads.** A dive downloaded from a computer in gauge mode
   auto-classifies as Gauge and skips air-tank synthesis.

## Non-goals

- No decompression/gas analysis for gauge dives (by design — that's the point).
- No new schema table or column. `DiveMode.gauge` is a new *value* of the existing
  free-text `dive_mode` column.
- Freedive computer mode is **not** mapped to gauge in this change (see Open
  Questions). Only libdivecomputer's gauge mode maps to `DiveMode.gauge`.

## Architecture

### 1. Domain & schema — no migration

`dive_mode` is `text().withDefault(const Constant('oc'))`
(`lib/core/database/database.dart:463`) with **no CHECK constraint and no enum
TypeConverter** — the string is mapped to the enum in Dart via `DiveMode.fromCode`.
Adding a new allowed value is a pure Dart change: no schema-version bump, no Drift
codegen for the column, no data migration. Old rows stay `'oc'`; unknown strings
still fall back to `'oc'`.

Changes:
- `lib/core/constants/enums.dart:317` — add `gauge` to `enum DiveMode`; extend
  `code`/`fromCode`, `label`, and description accessors. `fromCode` keeps its
  default-to-`oc` behavior for unknown strings.
- `lib/features/dive_log/domain/entities/dive.dart:288` — add `bool get isGauge`
  alongside `isCCR`/`isSCR`.

### 2. Analysis suppression (core of the fix)

Gauge dives produce a **profile-only** analysis: depth, temperature, ascent rate;
**no** deco/ceiling/NDL/TTS/GF, CNS/OTU, ppO2/MOD/END, or gas-density curves.

There is precedent: CCR/SCR already refuse the air fallback at
`profile_analysis_service.dart:623-661`. Gauge follows the same shape but suppresses
the deco/tox curves entirely rather than substituting cell/setpoint ppO2.

Touch points (all currently default to air 0.21):
- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
  - `computeAnalysisForProfile` (~:706, air default at :770) — when
    `dive.diveMode == DiveMode.gauge`, skip deco/tox and return a profile-only
    result.
  - `diveProfileAnalysisProvider` (~:1277) — same gate.
  - `buildProfileGasSegments` (:179) — return no gas segments for gauge.
- `lib/features/dive_log/data/services/profile_analysis_service.dart` —
  `analyze()` (:526) should honor a "no gas analysis" signal so it does not emit
  deco/tox/density curves. Prefer passing an explicit flag/mode rather than faking
  empty gas, to keep the intent legible.

### 3. Dive detail page

Gate section visibility on `!isGauge`:
- Cylinders card (`lib/features/dive_log/presentation/widgets/cylinders_card.dart`)
- Deco / ceiling / NDL / TTS / GF panel
- CNS / OTU / ppO2 / MOD / END / gas-density panels

Keep: profile chart (depth+time), temperature overlay, ascent-rate coloring,
environment, marine life, buddies, weights, equipment, notes.

Sections are registered via `DiveDetailSectionId`; gate their inclusion on the
gauge flag at the section-assembly site.

### 4. Edit form

- `DiveModeSelector` (wired at `dive_edit_page.dart:2392`) gains a **Gauge**
  option.
- `GasGearSection`
  (`lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`)
  hides the tank cards, the add-tank affordance, and the rebreather panel when the
  selected mode is gauge. **Weights and equipment stay visible** — a gauge diver
  still wears weight and gear.
- Tank rows remain in the page's `_tanks` state and are saved as-is (the repository
  update path at `dive_repository_impl.dart:1198-1284` already reconciles), so
  switching back to OC restores them.
- Add a short helper line explaining that gauge mode omits gas/deco.

### 5. Statistics

Add `d.dive_mode <> 'gauge'` to the gas-derived queries in
`lib/features/statistics/data/repositories/statistics_repository.dart`:
- gas-mix distribution (`getGasMixDistribution`, :275) — the one that visibly
  mis-attributes a gauge dive as "Air".
- SAC volume/pressure trends (:78, :209), SAC records (:325, :454), SAC by tank
  role (:598).

This keeps a gauge dive's retained (hidden) tank rows out of gas stats while
preserving them for reversibility.

### 6. Download auto-detect

- `reparse_service.dart:751` `_mapDiveMode` — add a case mapping libdivecomputer's
  gauge mode string to `'gauge'`. Verify the exact string emitted by the
  native/pigeon layer (`parsed.diveMode`).
- Confirm the **live-download** path
  (`lib/features/dive_computer/data/services/parsed_dive_mapper.dart`) carries
  `diveMode` at all; reparse does, but live download currently may not. If it
  doesn't, plumb it so both paths classify gauge consistently.
- `lib/features/dive_computer/data/services/parsed_tank_resolver.dart` — when the
  dive is gauge, **skip air-tank synthesis** (the `parsed.tanks.isEmpty` branch at
  :89 and the `?? 21.0` gauge fallback at :117). A gauge dive should import with no
  tanks.

### 7. Localization

Add to `en` + all 10 non-en locales, then regenerate (project rule: translate all
locales):
- `enum_diveMode_gauge`
- `diveLog_diveMode_gaugeDescription`
- any helper string used in the edit form for gauge mode.

## Data flow

```
DiveMode.gauge originates from:
  (a) manual DiveModeSelector, or
  (b) download mapper (_mapDiveMode gauge -> 'gauge')
        |
        v
persisted as text 'gauge' in dives.dive_mode  (no migration)
        |
        v
read into Dive.diveMode via DiveMode.fromCode
        |
        +--> profile_analysis_provider: gauge => profile-only (no deco/tox)
        +--> dive detail page: gauge => hide cylinders + deco/tox sections
        +--> edit form: gauge => hide tank/gas/rebreather (keep weights/equipment)
        +--> statistics_repository: WHERE dive_mode <> 'gauge' on gas queries
        +--> parsed_tank_resolver: gauge => no synthesized air tank
```

## Edge cases

- **Existing OC dive -> Gauge -> OC:** tanks preserved throughout; gas/deco returns
  on switch back.
- **Gauge dive with pre-existing (hidden) non-air tank:** analysis stays suppressed
  regardless of the mix; stats exclude it via the mode filter.
- **Downloaded gauge dive that still reports tanks/gas:** classified gauge; tank
  synthesis skipped; if the computer emitted real tank rows, they are retained but
  hidden and excluded from stats (consistent with decision 2).
- **Unknown/again-default mode strings:** still fall back to `oc` (unchanged).
- **CCR/SCR:** untouched; they keep their existing non-air handling.

## Testing (TDD — tests written first)

- `DiveMode.fromCode('gauge')` round-trips; `code`/`label` correct; `isGauge` true
  only for gauge.
- Analysis: a gauge dive yields null deco/ceiling/NDL, CNS/OTU, ppO2/MOD, and
  density curves; profile-only fields (depth/temp/ascent) still present.
- Statistics: `getGasMixDistribution` (and one SAC query) exclude a gauge dive that
  has a tank row.
- Edit form: selecting Gauge hides tank cards + add-tank + rebreather, keeps
  weights/equipment; the mode round-trips through save/load.
- Download mapping: a gauge mode string maps to `DiveMode.gauge`; no air tank is
  synthesized; live and reparse paths agree.
- Regression: OC/CCR/SCR analysis, cylinders card, and gas stats unchanged for
  non-gauge dives.

## Open questions (flagged, non-blocking)

- **Freedive.** libdivecomputer distinguishes freedive from gauge. There is already
  a separate `diveType.freedive`. This change maps only gauge -> `DiveMode.gauge`;
  freedive handling is deferred.
