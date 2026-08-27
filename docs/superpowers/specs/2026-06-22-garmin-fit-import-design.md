# Comprehensive Garmin FIT Import — Design Spec

- **Date:** 2026-06-22
- **Status:** Approved (ready for implementation plan)
- **Related issues:** #172 (FIT GPS → site matching), #173 (FIT heart rate), #310 (DC import GPS → site matching), #171 (FIT timezone — closed), #225 (raw source storage — closed)
- **Reporters / test data:** Bouchot (`theRealBlackRabbit`, Descent Mk3i + T2 transmitter), AngelSMF/Verdugo (Descent X50i + Mk3i, simultaneous recordings), stiebs (Garmin + Ratio)

## 1. Background & problem

Submersion imports Garmin dives only from FIT files (the vendored libdivecomputer fork has **no Garmin backend**; FIT parsing uses the `fit_tool` Dart package). The current parser (`fit_parser_service.dart`) is a skeleton: it extracts only depth/temperature/heart-rate samples, entry GPS, and a summary, and silently drops everything else the file contains.

This was confirmed by **decoding 15 sample FIT files** from two users with a Python FIT decoder (`fitparse`), cross-checked against the users' Garmin-app screenshots and the libraries' source. Bouchot independently proved the data is present: round-tripping the same file through Subsurface restores air-integration and GPS that Submersion's direct import loses.

**Data confirmed present in the files but dropped today:**

| Data | FIT source (verified) | Reported by |
|---|---|---|
| Tank pressure / air-integration (start/end + ~1 Hz series, **multi-transmitter**) | `tank_summary` (msg 323), `tank_update` (msg 319) | Bouchot, AngelSMF, stiebs |
| Gas mixes (e.g. EAN30 + EAN50 deco gas) | `dive_gas` (msg 259) | Bouchot |
| Deco ceiling / TTS / NDL (per sample) | `record.next_stop_depth` / `time_to_surface` / `ndl_time` | Bouchot |
| CNS / OTU / N2 loading | `dive_summary.start_cns`/`end_cns`/`o2_toxicity`; `record.cns_load`/`n2_load` | completeness |
| Heart rate | `record.heart_rate` | #173 |
| GPS entry (verified → Malta 35.81°N/14.45°E; Kona 19.69°N/156.0°W) | `session.start_position_lat`/`long` | #172 |
| Water type (salt) + density | `dive_settings.water_type` / `water_density` | Bouchot |
| Dive number | `dive_summary.dive_number` | AngelSMF |
| Bottom time (≠ runtime) | `dive_summary.bottom_time` | screenshot "87 == 87" |
| Surface interval | `dive_summary.surface_interval` | completeness |
| Deco model + GF + ppO2 limits | `dive_settings.model`/`gf_low`/`gf_high`/`po2_*` | completeness |
| Computer model + serial + firmware | `file_id.garmin_product`/`serial_number`; `device_info.software_version` | completeness |

**Two facts that de-risk implementation:**

1. **No library fork needed.** `fit_tool` 1.0.5 has named message classes for `dive_gas`, `dive_settings`, `dive_summary`, `gps_metadata`, `record`, `session`, and the `record` class exposes every deco/HR/GPS getter we need (`nextStopDepth`, `timeToSurface`, `ndlTime`, `n2Load`, `cnsLoad`, `heartRate`, `temperature`, `absolutePressure`, `positionLat/Long`). It has **no** class for `tank_update`/`tank_summary`, **but** its `MessageFactory` default case returns a `GenericMessage` for any unknown global ID, with field access by number via `DataMessage.getField(int id)`. So tank pressure is reachable by reading messages 319/323 by field number and applying the scale manually.
2. **Timezone source identified.** The `activity` message carries both `timestamp` (UTC) and `local_timestamp`; their delta is the dive's local UTC offset. The dive's true wall-clock is `local_timestamp` — the correct source for Submersion's "wall-clock-as-UTC" storage convention.

## 2. Goals / non-goals

**Goals (in scope):**
- FIT import extracts all data the file contains: tank pressure/air-integration (multi-transmitter), gas mixes, per-sample deco (ceiling/TTS/NDL), CNS/OTU/N2, heart rate, dive number, bottom time vs runtime, surface interval, water type/salinity, deco model + GF + ppO2 limits, computer model/serial/firmware.
- Correct dive local time via `local_timestamp` (re-verify the #171 fix).
- Carry entry/exit GPS coordinates onto imported FIT dives so they become eligible for the **existing** site-match review flow; surface that same flow on the dive-computer download path (#310). **Reuse the existing matching engine — no new matcher.**
- Populate `sourceUuid` for FIT dives (fixes the `sourceId`→`sourceUuid` key mismatch so duplicate detection works on re-import).

**Non-goals (explicitly out of scope):**
- **No automatic dive-site creation.** Match only to existing sites; never auto-create. Coordinates are stored on the dive so the user can create/assign a site manually.
- **No locale-geocode normalization (#214).** Deferred.
- **No multi-source same-dive merge** (Verdugo X50i+Mk3i, stiebs Garmin+Ratio). `DiveDataSources` multi-source exists but is unsurfaced; separate future project.
- **No Garmin MTP/USB direct download.** Separate native/transport effort; no libdivecomputer Garmin backend.
- **No FIT re-parse plumbing and no re-import update-in-place.** The existing "Re-parse raw data" menu is libdivecomputer-only and FIT imports never stored raw bytes, so already-imported dives cannot be re-parsed regardless. **Existing dives are refreshed by delete + re-import.**

## 3. Decisions (settled with product owner)

1. Scope = core FIT enrichment **+** GPS → site matching. Multi-source and MTP/USB are separate.
2. Re-parse = **parser fix only**; users delete + re-import to refresh existing dives.
3. GPS = import coordinates + **match-only to existing sites, no auto-create**.
4. #214 locale geocoding = not addressed.

## 4. Architecture — "Make FIT speak UDDF"

`UddfEntityImporter` already persists multi-tank records, per-tank pressure time-series (`_storeTankPressures`), gas mixes, gas switches, profile events, and per-sample deco fields — UDDF imports get all of this today. FIT is starved only because `FitImportParser` emits a tiny payload. **Strategy: make the FIT parser emit the same payload shape UDDF already produces, so FIT inherits UDDF-grade fidelity through the shared persistence path.** New code is concentrated in extraction + mapping (cheap to unit-test); little new persistence code.

```
 .fit bytes
   │
   ▼
FitDiveReader ──(orchestrates)──► extractors ──► UDDF-shaped ImportPayload
   │                                                   │ (same keys UDDF emits:
   │  GenericMessage.getField(n) for msgs 319/323      │  tanks, gasMixRef, gasSwitches,
   ▼                                                   │  profileEvents, profile extras,
 tank/gas/deco/summary/device/time extractors          │  entry/exitLat/Long, cns/otu, …)
                                                        ▼
                                              UddfEntityimporter ──persists──► DB
                                                        │
                                                        └─► GPS coords on Dive → EXISTING /dives/match-sites flow (reused)
```

**Rejected alternatives:** fully-typed intermediate model (larger refactor; payload reuse gets ~90% of the benefit); parsing FIT straight into domain entities (loses `UddfEntityImporter` reuse); forking `fit_tool` (unnecessary — `GenericMessage` suffices).

## 5. Components

Decompose the current ~230-line `FitParserService` into an orchestrator plus focused extractors (per the 200–400-line file convention and for isolated unit testing):

| Unit | Responsibility | Source messages |
|---|---|---|
| `FitDiveReader` | Read messages once; drive extractors; assemble payload | — |
| `FitMessageAccess` | `GenericMessage.getField(n)` helper + scale constants | 319/323 |
| `FitTankExtractor` | Multi-sensor tanks: start/end pressure, volume-used, pressure series keyed by sensor ID | `tank_summary` 323, `tank_update` 319 |
| `FitGasExtractor` | Gas mixes (O2/He, enabled), gas-switch points | `dive_gas` 259, `event` |
| `FitProfileExtractor` | Per-sample depth/temp/HR **+ deco** (ceiling, TTS, NDL, cns, n2) | `record` |
| `FitSummaryExtractor` | Dive number, bottom time, surface interval, CNS/OTU/N2, entry GPS, temps, water type/density, deco model, GF, ppO2 | `dive_summary`, `session`, `dive_settings` |
| `FitDeviceMapper` | `garmin_product` → model name; serial; firmware | `file_id`, `device_info` |
| `FitTimeResolver` | Wall-clock from `local_timestamp` (or local−UTC delta) | `activity`, `session` |

Then:
- `imported_dive.dart` — extend `ImportedDive` modestly to carry the new fields (or assemble the payload map directly in the parser).
- `fit_import_parser.dart` — emit the UDDF-shaped payload (incl. `sourceUuid`).
- `uddf_entity_importer.dart` — close the gaps it has even for UDDF: write entry/exit GPS onto the `Dive` (currently the Dive is built without lat/long), and OTU. Confirm per-sample columns (`DiveProfiles.pressure`, deco columns) are written.
- **Reuse** the existing site-matching system (`geo_math` + `dive_sites/domain/matching` + `SiteMatchingService` + `/dives/match-sites`); **no new matcher** (see §7).

## 6. Data mapping (authoritative)

| Domain target | FIT source | Transform |
|---|---|---|
| `Dive.diveNumber` | `dive_summary.dive_number` | as-is |
| `Dive.diveDateTime` / entry / exit | `activity.local_timestamp`; `session.total_elapsed_time` | wall-clock-as-UTC; exit = entry + elapsed |
| `Dive.bottomTime` | `dive_summary.bottom_time` | seconds (distinct from runtime) |
| `Dive.runtime` | `session.total_elapsed_time` | seconds |
| `Dive.surfaceIntervalSeconds` | `dive_summary.surface_interval` | seconds |
| `Dive.maxDepth` / `avgDepth` / `waterTemp` | `dive_summary` / `session` | metres / °C |
| `Dive.cnsStart` / `cnsEnd` / `otu` | `dive_summary.start_cns` / `end_cns` / `o2_toxicity` | % / % / OTU |
| `Dive.decoAlgorithm` / `gradientFactorLow` / `High` | `dive_settings.model` / `gf_low` / `gf_high` | "zhl_16c" / 50 / 85 |
| water type / density | `dive_settings.water_type` / `water_density` | salt/fresh; kg/m³ |
| `Dive.diveComputerModel` / `Serial` / `Firmware` | `file_id.garmin_product` / `serial_number`; `device_info.software_version` | product map; as-is |
| `Dive.entry/exitLatitude/Longitude` | `session.start_position_*`; last `record.position_*` | semicircles × (180 / 2³¹) |
| `DiveTanks[]` (one per sensor) | `tank_summary` 323 | startP = field1 ÷ 100 (bar); endP = field2 ÷ 100 (bar); volumeUsed = field3 ÷ 100 (L); sensor = field0 |
| `DiveTanks[].o2Percent` / `hePercent` | `dive_gas` | match gas to tank where derivable |
| `TankPressureProfiles[]` | `tank_update` 319 | t = field253; sensor = field0; pressure = field1 ÷ 100 (bar) |
| `DiveProfiles[].depth` / `temperature` / `heartRate` | `record.depth` / `temperature` / `heart_rate` | HR nullable |
| `DiveProfiles[].ceiling` / `ndl` / `tts` / `cns` | `record.next_stop_depth` / `ndl_time` / `time_to_surface` / `cns_load` | recorded values, never recomputed |
| `GasSwitches[]` | `dive_gas` + `event` | best-effort |
| `sourceUuid` | `garmin-{serial}-{startMs}` | populate the dedup key (fixes `sourceId` mismatch) |

## 7. GPS → dive-site matching (reuse the existing system)

**There is no new matcher.** The app already has a complete, source-agnostic GPS→site matching engine and review workflow; this project reuses it unchanged and only closes the two gaps that keep imported dives from reaching it.

Existing pieces (reused as-is):
- `lib/core/utils/geo_math.dart` — Haversine `distanceMeters`.
- `lib/features/dive_sites/domain/matching/` — pure matcher (`rankCandidates`, `matchRanked`, `matchDive`) with `MatchThresholds` driven by the user setting **`siteMatchSensitivity`** (radius is **not** hard-coded by this project).
- `lib/features/dive_sites/data/services/site_matching_service.dart` — `computeProposals` / `applyConfirmed`, with a 100 m coincidence guard against duplicate sites.
- Review UI at route `/dives/match-sites` (`site_match_review_page.dart`), plus the dive-list "Match Dives to Sites" menu.
- Shared chokepoint `DiveRepository.getDivesNeedingSiteMatch` (predicate: `siteId IS NULL AND has entry/exit GPS`) — both FIT and DC dives converge here once they carry coordinates.

The two gaps to close:
1. **FIT (#172):** the importer drops the GPS coordinates today, so FIT dives never become eligible. Fix = carry entry/exit lat/long onto the `Dive` (see §5). The universal import-summary step **already** offers "Match Sites" → `/dives/match-sites` for eligible imported dives (`import_summary_step.dart`), so once the coordinates are present, FIT inherits the existing match UX with no further work.
2. **DC download (#310):** the dive-computer download path stores GPS but never surfaces the match flow after import. Fix = surface the same "Match Sites" affordance after a download completes (mirroring the import-summary step), rather than auto-applying.

**Match-only / no-auto-create is honored by construction:** the existing flow is **user-confirmed** (the review page), links to existing sites via `setSite`, and never creates a site without user confirmation. This project adds **no** headless auto-assignment and **no** new site-creation logic.

## 8. Domain semantics (from the tech-diving skill)

- **Deco = recorded, never recomputed.** Import the Garmin's own ceiling/TTS/NDL into the profile. Bouchot's "massive difference" is consistent with Submersion currently showing *recomputed* deco; part of this work is to display the recorded values (and confirm/stop any recompute for imported dives). *Open item: locate where the displayed deco value currently originates.*
- **Bottom time ≠ runtime.** Use `dive_summary.bottom_time` (fixes the "87 == 87" screenshot).
- **SAC** derives from tank start/end pressure → **bar/min** (existing model). FIT provides `volume_used` in L but not cylinder size, so L/min remains unavailable.

## 9. Error handling / edge cases

- Non-dive FIT (sport ≠ diving) → skip; corrupt/empty → null (unchanged behaviour).
- **Multiple tank sensors** → multiple tanks; pressure series matched by sensor ID (X50i had 3; the deco dive 92 had 0).
- **Null HR / no GPS / no transmitter** → graceful degradation; emit only what exists.
- **Multi-session FIT** (rare for Garmin) → import each session as a separate dive instead of silently taking the first; do not drop data.
- **Unknown `garmin_product`** → fall back to a generic "Garmin Descent" model name.
- GenericMessage fields carry **no profile scale/offset** — the extractor must apply ÷100 explicitly for pressure (bar) and volume (L).

## 10. Testing

- **Commit a small set of sanitized real `.fit` fixtures** (the repo currently has none). Sanitize: scrub serial numbers and round/offset GPS coordinates. Real fixtures are necessary because synthetic builders can't easily emit the unnamed 319/323 tank messages. *Open item: sanitization approach (re-encode via `fit_tool` builder vs targeted byte edits with CRC fix).*
- Unit tests per extractor, especially `FitTankExtractor` (pressure scale ÷100; multi-sensor mapping; tank_summary/tank_update cross-consistency).
- Golden test: decode a sample → assert tanks, gas mixes, deco samples, GPS, CNS/OTU.
- Importer integration test: FIT payload → DB rows (tanks, `TankPressureProfiles`, `DiveProfiles` deco columns, GPS on `Dive`).
- GPS integration tests (the matcher itself already has tests — we test the *wiring*): a FIT import writes entry/exit lat/long onto the `Dive` so it appears in `getDivesNeedingSiteMatch`; a DC download surfaces the `/dives/match-sites` affordance. No new matcher logic to test.

## 11. Open verification items (resolve while writing the plan; do not change the architecture)

1. Exact GPS plumbing in `UddfEntityImporter` — the `Dive` is currently built without entry/exit lat/long; confirm the minimal change to carry coordinates onto the Dive so it satisfies `getDivesNeedingSiteMatch`. Also confirm the dive-computer download completion point where the existing `/dives/match-sites` affordance should be surfaced (#310).
2. Where Submersion's *displayed* deco value currently comes from (recompute vs stored) and how to switch to recorded values for imported dives.
3. Reliability of gas→tank association (FIT does not always bind a gas to a specific transmitter).
4. `fit_tool` builder's ability to emit synthetic 319/323 messages for tests (else rely on sanitized real fixtures).

## 12. Affected files (reference)

- `lib/features/dive_import/data/services/fit_parser_service.dart` (decompose + enrich)
- `lib/features/dive_import/domain/entities/imported_dive.dart` (extend)
- `lib/features/universal_import/data/parsers/fit_import_parser.dart` (UDDF-shaped payload)
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` (GPS onto Dive, OTU, confirm profile columns)
- `lib/core/database/database.dart` (Dives, DiveProfiles, DiveTanks, TankPressureProfiles, GasSwitches, DiveSites, DiveDataSources — schema reference; add columns only if a needed field has no home)
- Dive-computer download completion path — surface the existing `/dives/match-sites` affordance (#310). The matching engine (`dive_sites/domain/matching/`, `site_matching_service.dart`, `core/utils/geo_math.dart`, route `/dives/match-sites`) is **reused unchanged, not modified**.
- Tests under `test/features/dive_import/` and `test/features/universal_import/`, plus sanitized fixtures

## Appendix A — verified ground truth (preserve; expensive to re-derive)

- **`fit_tool` 1.0.5** retains unknown messages as `GenericMessage` (`MessageFactory` default case), field access via `DataMessage.getField(int id)`; GenericMessage fields lack profile scale/offset (apply manually).
- **tank_update (msg 319):** field 253 = timestamp, field 0 = sensor ID, **field 1 = pressure ×0.01 bar**. (Bouchot 72: 221.25 → 88.11 bar.)
- **tank_summary (msg 323):** field 0 = sensor, **field 1 = start_pressure ×0.01 bar**, **field 2 = end_pressure ×0.01 bar**, **field 3 = volume_used ×0.01 L**. Cross-checked: start = first update, end = last update, 1993.5 L ≈ a 15 L tank drained 133 bar.
- **Multiple `tank_summary`/sensors per dive** = multiple tanks (X50i: 3 sensors).
- **garmin_product codes:** 4223 = Descent Mk3i, 4518 = Descent X50i, 3865 = T2 transmitter.
- **Timezone:** `activity.timestamp` (UTC) vs `activity.local_timestamp` (local); delta = dive's UTC offset; use `local_timestamp` as wall-clock.
- **GPS:** `session.start_position_lat/long` in semicircles; degrees = value × (180 / 2³¹). `gps_metadata` messages in these files carried only altitude/speed (no fix) — rely on `session` position.
- **Deco per sample (record):** `next_stop_depth` (ceiling, m), `next_stop_time` (s), `time_to_surface` (TTS, s), `ndl_time` (NDL, s), `n2_load` (%), `cns_load` (%). `absolute_pressure` is *ambient* water pressure (Pa), not tank pressure.
- **`fitparse` 1.2.0** is too old to name 319/323 (shows `unknown_319`/`unknown_323`); used only for offline analysis, not in the app.

## Appendix B — existing GPS→site matching system (REUSE; do not rebuild)

A complete, source-agnostic matcher already exists. This project reuses it and only feeds it / triggers it.

- `lib/core/utils/geo_math.dart` — `distanceMeters` (Haversine), `initialBearingDegrees`.
- `lib/features/dive_sites/domain/matching/` — `site_matcher.dart` (`rankCandidates`, `matchRanked` → `AutoMatch`/`Suggested`/`NoMatch`, `matchDive`), `match_thresholds.dart`, `site_match_sensitivity.dart` (thresholds from user setting `siteMatchSensitivity`).
- `lib/features/dive_sites/data/services/site_matching_service.dart` — `computeProposals(List<Dive>)` (no writes), `applyConfirmed(...)` (links via `DiveRepository.setSite`; 100 m coincidence guard; only materializes a **bundled-catalog** site on user confirmation).
- `DiveRepository.getDivesNeedingSiteMatch` (`dive_repository_impl.dart:295`) — shared eligibility query (`siteId IS NULL AND entry/exit GPS`); both FIT and DC dives land here once coordinates are present.
- Review UI: route `/dives/match-sites` → `site_match_review_page.dart` / `site_match_review_notifier.dart`. Triggers today: import-summary "Match Sites" (`import_summary_step.dart:192-209`, file imports incl. FIT) and dive-list "Match Dives to Sites" menu.
- **Current gaps (this project's GPS work):** (1) FIT importer drops entry/exit lat/long, so FIT dives are never eligible — fix by writing coords onto the `Dive`; (2) the dive-computer download path never surfaces the match flow — fix by adding that affordance (#310).
- **Site resolution on import is name-based, not coordinate-based:** UDDF import find-or-creates sites by lowercased name (`uddf_entity_importer.dart` `_importSites` ~:730-815) and reverse-geocodes country/region on creation (`LocationService.reverseGeocode`, ~:778). DC import sets no site at all (`siteId` null). Neither does GPS proximity inline — that is exclusively the post-import matcher above.
