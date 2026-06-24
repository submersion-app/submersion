# Garmin FIT — Import Tank Cylinder Volume (and defer Notes) — Design Spec

Issue: [#403 "Garmin .fit issues"](https://github.com/submersion-app/submersion/issues/403)
(reporter: Floris Bouchot, who supplied the sample files used to validate PR #391).
Builds on the merged FIT-import enrichment (PR #391, "make FIT speak UDDF").

## 1. Background & problem

The reporter asks for two enrichments to Garmin `.fit` import:

1. **Tank details such as cylinder size from T2 transmitters**, so the user does not
   set tank volume manually.
2. **Dive notes** imported from the file.

Empirical investigation of all 21 reporter-supplied sample files (Bouchot Mk3i+T2,
Verdugo X50i + 2×Mk3i recorded simultaneously) using `python fitparse` established:

- **Tank/cylinder size is NOT transmitted** by the T2, and is NOT a stored field
  anywhere in the FIT stream. But Garmin's `tank_summary` (msg 323) stores
  `volume_used` (surface gas consumed), which Garmin computes *from* the user's
  configured cylinder size. The size is therefore recoverable by reversing that
  computation. **Feasible.**
- **Dive notes are NOT in the FIT binary at all.** Across every sample (both raw
  device files and Garmin Connect exports) the only strings are the activity-profile
  name (`"Single-Gas"`/`"Multi-Gas"`), the diver's name, transmitter nicknames, and
  enum labels. Garmin keeps user dive notes in the **Connect cloud**; they do not
  travel into the exported `.fit`. The dive *site* in the reporter's filenames
  ("Qrendi") exists only in the **filename** (Connect names exports after the Connect
  activity title), never in the bytes — and raw device files are timestamp-named
  (`2026-06-07-09-17-09.fit`). **Not feasible from the file.**

## 2. Goals / non-goals

**Goals**
- Import the configured cylinder volume (liters) for each air-integration tank in a
  Garmin FIT dive, derived from `volume_used` and the start/end pressures.
- Persist it to `DiveTank.volume` via the existing FIT→UDDF→importer path with no new
  persistence code.
- Degrade safely to "no volume" (tank still imports with pressure/gas) whenever the
  derivation is unreliable.

**Non-goals (this PR)**
- Importing dive notes from the file (impossible — see §1). Handled by a reply to the
  reporter asking what "notes" they mean (§9).
- Importing notes/title from the export *filename* (product owner deferred this; would
  require threading the filename through `ImportParser` and a fragile, Connect-export-only
  heuristic).
- Tank *nicknames* (the user labels "A2", "z Backup" found in `unknown_147`) → possible
  future enhancement, out of scope here.
- Deriving size for non-Garmin sources (see §4.4 — the required input does not exist there).

## 3. Decisions (settled with product owner)

- **Scope:** tank volume now; notes deferred to a reporter clarification reply.
- **Source:** derive from `volume_used / (startBar − endBar)`. There is no direct size
  field. (A single-file look would have mis-identified `unknown_147.field77`=`150` as
  "15.0 L"; the multi-tank Verdugo files disprove it — field77 is a constant `800`
  behind both 9.4 L and 11 L tanks; it is a pressure-alarm threshold in the user's
  pressure unit, not size.)
- **Rounding:** round the derived liters to **0.1 L**. The value is reconstructed, not
  measured; 0.1 L communicates "≈15 L" without implying false precision (`14.97`).
- **Scoping of the helper:** implement the math as a **pure, reusable** function, but
  wire it only into the Garmin FIT extractor. No generic "any dive with pressure" path
  (YAGNI — and the input is unavailable elsewhere).

## 4. The derivation

### 4.1 Formula

```
cylinderVolumeLiters = round0.1( volumeUsedLiters / (startPressureBar − endPressureBar) )
```

Units resolve to liters: surface gas consumed (L) = cylinder size (L) × pressure drop
(bar), since 1 L of cylinder at 1 bar over ambient ≈ 1 L of surface gas. Reversing
yields size in liters, matching `DiveTank.volume` (water volume, liters).

### 4.2 Guards — return `null` (no volume) when

- `volumeUsedLiters` is null or ≤ 0 — catches the dive-92 phantom summary and the
  X50i "overheard" transmitter (pressure present, `volume_used = 0`).
- `startPressureBar` or `endPressureBar` is null.
- pressure drop `< 5 bar` (`FitConstants.minDeriveDropBar`) — avoids divide-by-near-zero
  and noise from an essentially unused tank.
- result ≤ 0 or > 60 L (`FitConstants.maxPlausibleVolumeLiters`) — plausibility clamp
  against garbage. A single cylinder or manifolded twinset realistically falls well
  inside this range.

`null` means the tank still imports (pressure, gas mix) but without a volume — never a
wrong number.

### 4.3 Accuracy & confidence

Validated against the reporter's files:

| Tank | Derived size across dives | Spread |
|---|---|---|
| Bouchot Mk3i+T2 | 14.97, 14.98 → **15.0 L** | 0.01 L |
| Verdugo 43 mm (×2) | 9.37–9.39 → **9.4 L** | 0.02 L |
| Verdugo 51 mm | 10.94–10.95 → **11.0 L** | 0.01 L |
| Verdugo X50i | 10.93–10.95 → **11.0 L** | 0.02 L |

- **Precision (reproducibility): ≤0.2%.** The size is near-constant per physical tank
  across dives whose pressure drops range ~100–180 bar. A pressure-dependent real-gas
  (Z-factor) correction in Garmin's `volume_used` would make the derived size drift
  across those dives; it does not, so Garmin uses the same linear model we invert and we
  recover its value. Residual error is integer rounding (inputs stored ×100) ≈ <0.01%.
- **Fidelity to configured size: effectively exact** (to 0.1 L). Proof it recovers
  *config*, not a guess: the same physical transmitter (sensor 2504425580) derives
  9.4 L on the 43 mm computer but 11.0 L on the X50i — one tank, two computers, two
  configs. This is the desired behavior ("instead of setting tank volume manually").
- **Fidelity to true physical cylinder: bounded by the user's own config.** We cannot
  beat their input. One residual unknown: a *constant* (pressure-independent) Z-factor
  in `volume_used` would add a small (~1–2%) systematic offset invisible to the
  cross-dive check; the clean landings (15.0, 11.0) argue against it, and the reporter
  can confirm against the device. Worst case is far better than manual entry.

### 4.4 Why this does not generalize to "any dive with pressure"

The formula needs **absolute gas consumed** (surface liters), not just pressure.
Pressure drop alone is size-independent — a 100 bar drop is identical in a 7 L pony and
a 15 L steel. Garmin is unusual in storing `volume_used` directly; that is the only
reason derivation is possible.

- Other dive computers (Shearwater/Suunto/Perdix via libdivecomputer): pressure
  time-series only, no absolute gas-used → circular, cannot derive.
- UDDF/Subsurface/MacDive: tank volume is typically a direct field → read it, no derivation.
- Apple Watch/HealthKit: no air integration.

So the derivation lives in the Garmin path. The pure helper is reusable if a future
source ever reports absolute gas-used.

## 5. Architecture & data flow

Reuses the merged "make FIT speak UDDF" pipeline unchanged; the volume rides existing
plumbing:

```
tank_summary (323)        FitTankExtractor            ImportedTank      FitImportParser         UddfEntityImporter
 field1 startP ─┐         derive (§4):                .volumeLiters ──► tank['volume'] = …  ──►  DiveTank.volume
 field2 endP   ─┼─►FitTank used/(start−end) ────────► (NEW field)       (NEW line)               (EXISTING map; no change)
 field3 used   ─┘         →FitTank.cylinderVolumeLiters (NEW)
```

## 6. Components / affected files

1. `lib/features/dive_import/data/services/fit/fit_tank_extractor.dart`
   - Add `cylinderVolumeLiters` to `FitTank`.
   - Compute it in `extract()` from a pure helper applying §4.1–§4.2. The helper is a
     private static for now, but takes only `(usedLiters, startBar, endBar)` with no
     Garmin coupling, so it can be promoted to a shared util if a second consumer
     (a source that reports absolute gas-used) ever appears.
2. `lib/features/dive_import/data/services/fit/fit_constants.dart`
   - Add `minDeriveDropBar = 5.0` and `maxPlausibleVolumeLiters = 60.0`.
3. `lib/features/dive_import/domain/entities/imported_dive.dart`
   - Add `volumeLiters` to `ImportedTank` (ctor + `props`).
4. `lib/features/dive_import/data/services/fit_parser_service.dart`
   - In `_buildImportedTanks`, set `volumeLiters: realTanks[i].cylinderVolumeLiters`.
5. `lib/features/universal_import/data/parsers/fit_import_parser.dart`
   - In the tank map, emit `tank['volume'] = t.volumeLiters` when non-null.
6. `UddfEntityImporter` — **no change** (already maps `t['volume']` → `DiveTank.volume`,
   line ~1591); locked in by a test.

## 7. Edge cases

- Phantom zero-pressure `tank_summary` (dive 92) — already dropped by the orchestrator's
  `realTanks` pressure>0 filter; never reaches derivation.
- "Overheard" transmitter (X50i 3rd sensor): pressure present, `volume_used = 0` →
  guard returns null; tank imports with pressure, no volume.
- Gas-only padded tanks (more gases than transmitters): no real tank → `volumeLiters` null.
- Multiple tanks (X50i, 2–3): each derives independently by sensor/order.

## 8. Testing (TDD)

- `fit_tank_extractor_test.dart` (extend; synthetic `GenericMessage` builder already present):
  Bouchot-72 raw values → `cylinderVolumeLiters ≈ 15.0`; `volume_used=0` → null;
  drop < 5 bar → null; absurd (huge used / tiny drop) → null.
- `fit_import_parser_test.dart`: synthetic file with a `tank_summary` → emitted
  `diveData['tanks'][i]['volume']` present and ≈ derived; not-derivable → key absent.
- Importer/converter test: `t['volume']` → `DiveTank.volume` persisted.
- Backstop: re-run the Python derivation over all 21 real sample files (the FIT lesson:
  real-file bugs do not reproduce against `FitFileBuilder` round-trips).

## 9. Reporter reply (deferred notes)

Post after the PR (product owner to approve wording first):

> Tank size: recoverable and being added — the T2 does not transmit cylinder size, but
> your Descent computes gas consumption from the size you configured, so we reverse it
> (your 15 L came through exactly). Notes: we checked all the files you sent — Garmin
> stores dive notes in Garmin Connect (the cloud), not in the exported `.fit`, so there
> is no notes field to read. Could you clarify which you mean: the dive **title** you set
> in Connect (it survives in the export *filename*, e.g. "72 Qrendi Single-Gas Dive"),
> or free-text **notes** typed in Connect? That tells us what is actually achievable.

## 10. Out of scope / future

- Notes from the Connect-export filename (needs `ImportParser` filename threading;
  Connect-export-only; revisit after reporter clarifies).
- Tank nicknames from `unknown_147` → `DiveTank.name`.
- Direct Garmin USB/MTP download.

## Appendix A — verified ground truth (preserve; expensive to re-derive)

- `tank_summary` (msg 323) fields: 0=sensor, 1=startPressure (×0.01 bar),
  2=endPressure (×0.01 bar), 3=`volume_used` (×0.01 L, surface gas consumed — NOT size).
- `volume_used` varies with the dive's consumption (e.g. Verdugo 43 mm: 926→1622 L over
  6 dives) while `used / drop` stays ~9.38 L → confirms field 3 is gas-used and the
  quotient is the configured size.
- `unknown_147` = per-transmitter registration: field0=sensor (matches `tank_summary`),
  field52=O2%, field2/91=user nickname, fields 75/76/77 = pressure-alarm thresholds in
  the user's pressure unit (Bouchot metric 232/50/150 bar; Verdugo imperial
  3500/700/800 psi). **field77 is NOT tank size** (constant 800 across 9.4 L and 11 L).
- No free-text notes field exists in any sample. Dive site name appears only in
  Connect-export filenames, not the binary; entry/exit GPS (already imported by #391)
  drives site matching instead.
- Garmin product codes (from #391): 4223=Descent Mk3i, 4518=Descent X50i, 3865=T2.
