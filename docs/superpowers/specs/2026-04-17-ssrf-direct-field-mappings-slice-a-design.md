# SSRF Direct Field Mappings (Slice A) — Design

**Date:** 2026-04-17
**Status:** Draft
**Relates to:** Issue #155; closes a subset of the "Gaps NOT addressed by PR #170" follow-up work. Also corrects an inaccuracy in `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`.

## Purpose

Close three concrete SSRF-import gaps that map directly from Subsurface XML to columns that already exist in the backend, and correct a factual error in the import-gap tracker. The scope is deliberately limited to the "low-risk direct field mapping" pattern established by PR #170 so the slice can ship without a schema migration.

## In Scope

1. **SSRF sample `setpoint` parsing.** Populate `DiveProfiles.setpoint` from Subsurface XML when the source exports it.
2. **SSRF partial cylinder preservation.** Stop dropping `<cylinder>` elements that carry only a gas mix (a common pattern for CCR diluent/oxygen cylinders in real corpora).
3. **Import-gap tracker correction.** The tracker's "UDDF Support: No" rating for tank role and tank material is incorrect — both are already wired end-to-end. Update the tracker to reflect reality, and update the rows affected by this slice.

## Out of Scope (Explicitly Deferred)

- **Active-tank-per-sample (Slice A.2).** Populating an `activeTankIndex` field on each profile sample from `gaschange` events requires a new `DiveProfiles` column. This slice deliberately contains no schema migration; active-tank gets its own slice.
- **SSRF rebreather dive fields** (setpoint low/high/deco, SCR config, diluent gas, loop O2, scrubber, loop volume). That is Slice B.
- **Profile events / markers persistence** (bookmarks, alarms, non-gas events). That is Slice C.
- **Inferring SSRF tank material from cylinder `description` presets.** Description-to-material heuristics (`"AL80" -> aluminum`) are a distinct feature (a preset-matcher) and are intentionally not bundled here.
- **UDDF changes.** UDDF tank role and tank material are already supported end-to-end; see "Tracker Correction Rationale" below.

## Architecture Changes

**Files touched (code):**
- `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` — add a shared event-forward-fill helper, wire it for setpoint, and relax the empty-cylinder skip condition.

**Files touched (docs):**
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` — correct UDDF rows, update SSRF rows affected by this slice.

**Files touched (tests):**
- `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — add tests for setpoint parsing and partial cylinders.
- `test/features/universal_import/data/parsers/fixtures/` — add small fixtures exercising `SP change` events and a gas-only cylinder.

**No schema migration. No UDDF code changes. No changes to `database.dart`.**

The `DiveProfiles.setpoint REAL` column already exists (see `lib/core/database/database.dart:270` and migration at line 1623). This slice is purely parser-layer work.

## The Shared Helper (Approach B)

Introduce a small private helper in `subsurface_xml_parser.dart`:

```dart
void _applyEventFillOntoSamples<T>({
  required List<Map<String, dynamic>> samples,
  required List<({int timestamp, T value})> events,
  required String sampleField,
})
```

**Semantics:**
- Events are timestamp-sorted ascending on input.
- For each sample, find the last event with `timestamp <= sample.timestamp` and set `sample[sampleField] = event.value`.
- Samples before the first event are left untouched.
- If `sample[sampleField]` already has a value (e.g., parsed directly from a sample attribute), it is **not overwritten**. This is what makes the priority cascade in the setpoint path correct: direct sample attribute > event-derived value.

**Why generic over `T`:** this slice only uses the helper for `double` setpoint values, but keeping it generic avoids a cast-heavy implementation when Slice A.2 reuses it for `int` active-tank indices.

**Why a shared helper for one call site in this slice:** the same helper unlocks Slice A.2 (active-tank) with zero new abstraction work, and Slice C (profile events) will likely reuse it for bookmark/alarm annotations. The cost of the abstraction is one small generic function; the payoff is consistent semantics across future event-driven sample fields.

## Detailed Changes

### 1. SSRF sample `setpoint`

**a. Direct sample attribute (rare but possible):**
Inside `_parseProfile`, for each `<sample>` element, read a direct `setpoint` attribute when present. Extracted inline alongside the existing `ppO2`, `ndl`, `cns`, `tts` reads at `subsurface_xml_parser.dart:453-465`.

```dart
final setpoint = _parseDouble(sample.getAttribute('setpoint'));
if (setpoint != null) point['setpoint'] = setpoint;
```

**b. `SP change` events with forward-fill:**
After the sample-parse loop, call a new `_parseSetpointEvents(divecomputer)` that walks `<event>` children whose `name` equals `'SP change'` (case-insensitive match, trimmed). For each matching event, extract `time` -> timestamp and `value` -> setpoint value. Pass the resulting list to `_applyEventFillOntoSamples` with `sampleField: 'setpoint'`.

Samples that already got a direct `setpoint` from step (a) are preserved by the helper's "do not overwrite existing value" rule.

**c. Setpoint value-unit normalization:**
Subsurface typically emits SP-change event `value` attributes in **mbar** (e.g., `1200` for 1.2 bar) but some third-party exporters use bar (`1.2`). Normalization rule:

- Parse `value` as double.
- If the parsed value is greater than `10.0`, divide by `1000` (mbar to bar).
- Otherwise, treat as bar.

Rationale: realistic setpoint values are in the range `0.2 - 1.6` bar, i.e., `200 - 1600` mbar. A value of `10.0` is well above the largest plausible bar value (`~1.6`) and well below the smallest plausible mbar value (`~200`), so the heuristic is unambiguous across the realistic range.

**d. Fixed-CCR fallback (strategy iv):**
If the dive's `diveMode == ccr` AND no sample ended up with a setpoint after (a) and (b), attempt to find a dive-level fixed setpoint in the Subsurface extradata:
- `<extradata key='Setpoint' value='...'>` (case-insensitive key match).

If found, normalize via the same rule as (c) and apply to every sample.

**Deferral note:** If no real SSRF in our corpus exposes a fixed-CCR setpoint via extradata that we can reliably verify, (d) becomes dead code and we remove it from this slice, deferring the fallback to Slice B (full rebreather fields). The implementation plan should verify against available fixtures and real files before keeping (d). The slice still delivers value from (a) + (b) even if (d) is dropped.

### 2. SSRF partial cylinder preservation

**Current behavior (to change):**
`_parseCylinders` at `subsurface_xml_parser.dart:566-629` skips any `<cylinder>` element whose `size` attribute is empty AND `description` attribute is empty. Real SSRF files (CCR in particular) include cylinders with only a gas mix and `use` role:

```xml
<cylinder o2='98%' use='oxygen' />
<cylinder o2='21%' he='45%' use='diluent' />
```

These are silently dropped today.

**New skip condition:**
Skip a cylinder only when the element carries no cylinder-property signal. The preservation-signal attributes are: `size`, `description`, `o2`, `he`, `workpressure`, `use`, and `depth`. Any one of those being present means the cylinder is real and must be preserved.

`start` and `end` are deliberately excluded from the preservation signal: they are pressure-reading attributes that Subsurface dive computers sometimes emit for phantom cylinder slots (see the `does not invent extra tanks from placeholder cylinders` regression test in `subsurface_xml_parser_test.dart` using `subsurface_export.ssrf`). Including them would re-introduce phantom tanks from DC artifacts.

The presence check uses the private helper `_hasNonEmptyAttribute` so empty-string attribute values (e.g., `<cylinder o2='' />`) count as absent.

**Cylinder indexing contract (unchanged):**
`cylinderIndex` (the SSRF source-position counter used for `pressureN` lookups) must continue to increment on every `<cylinder>` element, including truly-empty skipped ones, so that `pressureN` attribute indices in `<sample>` elements continue to line up with the source file's cylinder ordering. `index` (the output array index in `tanks`) only increments when a cylinder is actually emitted. The current code already maintains this separation; the change is only to the skip predicate.

**Emitted tank shape for a gas-only cylinder:**
- `gasMix`: parsed from `o2` / `he` (defaults 21/0 when missing).
- `role`: mapped from `use` via the existing `_mapTankRole`.
- `order`: the output-array index.
- `uddfTankId`: `_subsurfaceTankRef(cylinderIndex, description)` (still unique even when description is empty — uses `"tank"` as the safe description fallback).
- `volume`, `workingPressure`, `startPressure`, `endPressure`, `name`: all null / absent.

### 3. Tracker correction

In `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`:

**Combined table row "Tank role / material metadata":**
- Change `UDDF Support` column from `No` to `Yes`.
- Leave `Fixed` as `[ ]` (SSRF material remains explicitly unaddressed).
- Add a footnote: "UDDF role + material are already supported end-to-end via `<tankrole>` and `<tankmaterial>` mappings; the `[ ]` reflects only the SSRF-side material gap."

**UDDF sub-table row "Tank role / material metadata":**
- Change `Fixed` to `[x]`.
- Update the rationale cell: "Already supported end-to-end — role via `<tankrole>` to `TankRole`, material via `<tankmaterial>` to `TankMaterial`."

**SSRF sub-table row "Tank role / material metadata":**
- Keep as currently worded; add a note clarifying that description-based material inference is intentionally deferred: "No direct SSRF cylinder material field exists. Inferring material from description presets (e.g., `AL80 -> aluminum`) is a separate preset-matcher feature and is not bundled with direct field mappings."

**Combined table row "Sample `setpoint`":**
- After this slice ships, change `SSRF Support` from `No` to `Yes`, `Fixed` to `[x]`.
- The split between "Sample `setpoint`" (now closed for SSRF via this slice) and richer CCR semantics (Slice B) is preserved by the existing row structure.

**Combined table row "Multi-tank definitions":**
- After this slice ships, change `SSRF Support` from `No` to `Partial`. Leave `Fixed` as `[ ]` because active-tank-per-sample is deferred to Slice A.2.
- Update notes section to mention: "Partial cylinder preservation is in; active-tank-per-sample is tracked as Slice A.2."

## Data Flow

```
Subsurface XML
     |
     v
SubsurfaceXmlParser._parseDive
     |
     +--- _parseProfile(divecomputer) ----> [sample maps]
     |        |
     |        +-- per-sample attribute reads (incl. direct `setpoint`)
     |        +-- _parseSetpointEvents() -> event list
     |        +-- _applyEventFillOntoSamples(sampleField: 'setpoint')
     |        +-- (existing forward-fills for pressure, temperature)
     |
     +--- _parseCylinders(dive, profilePoints) ----> [tank maps]
              |
              +-- [revised skip predicate preserves gas-only cylinders]
              +-- (existing: gasMix, volume, pressures, role, uddfTankId)
```

Downstream consumers (dive import service, profile persistence, profile chart) receive the same shape as today, plus populated `setpoint` fields on samples when the source provides it, plus additional tank maps when the source has gas-only cylinders.

## Error Handling / Edge Cases

- **Setpoint event with missing or unparseable `value`:** skip the event silently (same pattern as existing event parsing elsewhere in the file).
- **Setpoint event with missing or unparseable `time`:** skip the event silently.
- **Setpoint value `0` or negative:** skip (physically implausible).
- **Mixed bar/mbar within a single dive:** per-event normalization at parse time via the `> 10` heuristic means each event is normalized independently. The realistic-range argument above shows no overlap.
- **`diveMode` not set but SP-change events present:** still apply setpoint — events are the authoritative signal even for non-CCR dives (rare but possible OC-with-mCCR exports).
- **Fixed-CCR fallback with no events AND no extradata:** samples remain with no `setpoint`; this is correct behavior.
- **Gas-only cylinder with no `o2`:** defaults to `21%` via the existing `o2Raw ?? 21.0` pattern at `subsurface_xml_parser.dart:585`. Preserved silently — this is the existing contract for any cylinder without `o2`.
- **Cylinder completely empty (no attributes at all):** still skipped. `cylinderIndex` still increments so downstream `pressureN` lookups stay consistent.
- **Non-monotonic event timestamps:** the helper sorts events by timestamp at call time to be defensive. Subsurface emits sorted events in practice, but sorting is cheap and prevents silent bugs.

## Testing Strategy

All new tests go in `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`. New fixtures in `test/features/universal_import/data/parsers/fixtures/`.

### New fixtures

1. `ccr-setpoint-events.ssrf` — minimal CCR dive with `<event name='SP change' time='0:00 min' value='700'>` and `<event name='SP change' time='25:00 min' value='1300'>` plus a handful of samples spanning both windows.
2. `setpoint-direct-attribute.ssrf` — a dive where one sample carries `setpoint='1.2'` and a later SP-change event specifies `value='700'`. Used to assert direct-attribute precedence.
3. `ccr-gas-only-cylinder.ssrf` — a CCR dive with one cylinder of `<cylinder o2='98%' use='oxygen' />` and one fully-defined cylinder; a few samples. Used to assert partial cylinders are preserved without breaking pressure indexing.
4. `empty-cylinder-between-full.ssrf` — a dive with `<cylinder />` (truly empty) between two populated cylinders; samples with `pressure0` and `pressure2`. Used to assert `cylinderIndex` still increments past the truly-empty slot so `pressure2` lookups still match the second real cylinder.

### New assertions

1. **Setpoint forward-fill from events:** `ccr-setpoint-events.ssrf`. Samples before 25:00 have `setpoint == 0.7`. Samples at or after 25:00 have `setpoint == 1.3`. A sample before the t=0 event has no setpoint (the t=0 event IS at t=0, so all samples receive it — assert this end-state).
2. **Setpoint direct attribute precedence:** `setpoint-direct-attribute.ssrf`. The sample with direct `setpoint='1.2'` retains `setpoint == 1.2` even though a later SP-change event set `0.7`. Other samples after that event still get `setpoint == 0.7`.
3. **Setpoint unit normalization:** `value='1200'` yields `setpoint == 1.2`. `value='1.2'` yields `setpoint == 1.2`.
4. **Setpoint implausible values ignored:** `value='0'` and `value='-100'` produce no setpoint.
5. **Fixed-CCR fallback** (only if (d) is kept — plan phase decides). `diveMode == ccr`, no SP-change events, `<extradata key='Setpoint' value='1000'>` yields `setpoint == 1.0` on every sample.
6. **Partial cylinder preservation:** `ccr-gas-only-cylinder.ssrf` produces a `tanks` array including both cylinders. The gas-only cylinder has `gasMix.o2 == 98.0`, `role == TankRole.oxygenSupply`, no `volume` key.
7. **Empty cylinder indexing preserved:** `empty-cylinder-between-full.ssrf` produces a `tanks` array with two cylinders. The second cylinder's pressure time series matches the `pressure2` attribute values from the samples (confirming `cylinderIndex` incremented past the truly-empty slot).

### Regression assertions (existing behavior must not change)

- `dual-cylinder.ssrf` still produces two tanks with the same volumes/pressures/roles as before.
- Existing tests for NDL, TTS, RBT, CNS, heart rate, in_deco sample parsing continue to pass.

### Manual verification (before declaring complete)

- Run `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — must pass.
- Run `dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — zero issues.
- Run `dart format` on changed files — no changes.

## Verification Plan

At the end of implementation, these commands must all succeed with zero warnings/errors:

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Additionally, a smoke-import of a real CCR SSRF file (if available in the working directory or via the user during review) should show non-null `setpoint` values on CCR dive profile samples that previously had none, and preserved gas-only cylinders in the dive's tank list.

## Follow-Up Slices

- **Slice A.2 — Active-tank-per-sample.** Closes the multi-tank "(a) active-tank tracking per sample" gap identified during brainstorming. Required work:
  - Schema: add `IntColumn get activeTankIndex => integer().nullable()` to `DiveProfiles`.
  - Migration: SQL `ALTER TABLE dive_profiles ADD COLUMN active_tank_index INTEGER`.
  - Parser: enhance `_parseGasSwitches` to emit `cylinderIndex` alongside the existing `timestamp`/`tankRef` fields, then call `_applyEventFillOntoSamples` (the helper introduced in Slice A) to forward-fill `activeTankIndex` onto each sample. Seeding rule: if the first gas-change event is within a small epsilon of `t=0`, apply its cylinder to every earlier sample.
  - Downstream: plumb `activeTankIndex` through the dive import service to profile persistence; update UI consumers (profile chart legend, markers service) if they should reflect the active tank.
  - **Why separated from Slice A:** schema migrations carry a different risk profile than parser-only changes — they trigger a database rebuild on user machines and are hard to reverse. Slice A's "direct field mapping" premise explicitly excludes migrations.
- **Slice B — CCR/rebreather dive fields (SSRF).** Setpoint low/high/deco, SCR config, diluent gas, loop O2, scrubber, loop volume.
- **Slice C — Profile events / markers.** Bookmarks, alarms, non-gas events.
- **Slice D — Dive-level deco metadata + surface pressure/altitude + provenance fill-out.**
- **Slice E — Sample next-stop.** Requires a new sample-level backend field.

## Tracker Correction Rationale

The `2026-04-05-imported-profile-gap-priority-tracker.md` document rates UDDF tank role/material as "No" in the combined table (line 56) and as "not fixed" in the UDDF sub-table (line 81). Grepping the code disproves both claims:

- `lib/core/services/export/uddf/uddf_full_import_service.dart:1315-1329` reads `<tankrole>` and `<tankmaterial>` elements.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart:1290-1306` maps those values to `TankRole` and `TankMaterial` enums and passes them into tank creation.

The tracker was filed alongside PR #170, which shipped UDDF role/material changes. The most likely explanation is that the tracker was authored from memory before the PR's code state was re-checked, and the row never got updated. This slice corrects that in the same commit as the other changes so the tracker stays authoritative.
