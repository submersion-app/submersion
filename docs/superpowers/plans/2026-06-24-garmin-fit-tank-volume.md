# Garmin FIT Tank Cylinder Volume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import each air-integration tank's configured cylinder volume (liters) from Garmin FIT dives, derived from `volume_used` and the start/end pressures, so users stop entering tank volume manually (#403).

**Architecture:** Reuse the merged "make FIT speak UDDF" pipeline. Derive the volume in the pure `FitTankExtractor`, carry it on `FitTank` → `ImportedTank` → the UDDF-shaped `diveData['tanks'][i]['volume']`, where the existing `UddfEntityImporter` already maps it to `DiveTank.volume`. No new persistence code.

**Tech Stack:** Dart/Flutter, `fit_tool` 1.0.5 (FIT parsing), `flutter_test`, Drift (persistence, unchanged here).

## Global Constraints

- Derivation: `cylinderVolumeLiters = round0.1( volumeUsedLiters / (startBar − endBar) )`.
- Null-guards (return null → tank imports without volume, never a wrong number): `volumeUsed` null or ≤ 0; `startBar`/`endBar` null; drop `< FitConstants.minDeriveDropBar` (5.0); result ≤ 0 or `> FitConstants.maxPlausibleVolumeLiters` (60.0).
- Store metric internally (liters). Round derived value to 0.1 L.
- No emojis in code/comments.
- Lint `always_use_package_imports`: import siblings via `package:submersion/...`, never relative paths.
- `dart format .` (WHOLE project) must be clean before any commit; `flutter analyze` must be clean (whole project).
- Commit messages: Conventional Commits, scope `dive-import`. Do NOT add `Co-Authored-By` lines.

---

### Task 1: Derive cylinder volume in `FitTankExtractor`

**Files:**
- Modify: `lib/features/dive_import/data/services/fit/fit_constants.dart`
- Modify: `lib/features/dive_import/data/services/fit/fit_tank_extractor.dart`
- Test: `test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`

**Interfaces:**
- Consumes: existing `FitConstants.tsStartPressure/tsEndPressure/tsVolumeUsed`, `FitConstants.pressureScaleBar/volumeScaleLiters`.
- Produces: `FitTank.cylinderVolumeLiters` (`double?`) — the derived configured cylinder volume in liters, or null when not reliably derivable. Used by Task 2.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`, inside `void main() { ... }`:

```dart
  test('derives cylinder volume from volume_used and pressure drop', () {
    // Bouchot 72: 1993.5 L used over (221.25 - 88.11)=133.14 bar -> 14.97 -> 15.0 L.
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 1, startRaw: 22125, endRaw: 8811, volRaw: 199350),
    ]);
    expect(data.tanks.single.cylinderVolumeLiters, closeTo(15.0, 1e-9));
  });

  test('cylinder volume is null when volume_used is zero (overheard tx)', () {
    // Real pressures but zero gas used -> cannot derive; pressures still present.
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 1, startRaw: 21200, endRaw: 7400, volRaw: 0),
    ]);
    expect(data.tanks.single.cylinderVolumeLiters, isNull);
    expect(data.tanks.single.startPressureBar, closeTo(212.0, 1e-6));
  });

  test('cylinder volume is null when the pressure drop is below the floor', () {
    // 200.00 - 197.00 = 3 bar drop (< 5 bar floor) -> unreliable -> null.
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 1, startRaw: 20000, endRaw: 19700, volRaw: 4500),
    ]);
    expect(data.tanks.single.cylinderVolumeLiters, isNull);
  });

  test('cylinder volume is null when the result is implausibly large', () {
    // 500 L used over a 6 bar drop -> 83.3 L (> 60 L clamp) -> null.
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 1, startRaw: 20000, endRaw: 19400, volRaw: 50000),
    ]);
    expect(data.tanks.single.cylinderVolumeLiters, isNull);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`
Expected: FAIL — compile error, `cylinderVolumeLiters` is not defined on `FitTank`.

- [ ] **Step 3: Add the derivation constants**

In `lib/features/dive_import/data/services/fit/fit_constants.dart`, add after the `semicircleToDegrees` line (before the `fitEpochToUnixSeconds` doc block):

```dart
  /// Cylinder-volume derivation (`size = volume_used / pressure_drop`). Garmin
  /// does not transmit cylinder size; it stores volume_used computed from the
  /// user's configured size, so the size is recovered by reversing that.
  /// Below this pressure drop the quotient is noise; reject it.
  static const double minDeriveDropBar = 5.0;

  /// Reject an implausibly large derived cylinder volume (liters) as garbage.
  static const double maxPlausibleVolumeLiters = 60.0;
```

- [ ] **Step 4: Add the field and derivation to `FitTank`/`extract()`**

In `lib/features/dive_import/data/services/fit/fit_tank_extractor.dart`:

(a) Add the field to `FitTank` — replace the constructor + fields block:

```dart
class FitTank {
  const FitTank({
    required this.sensorId,
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
    this.cylinderVolumeLiters,
  });

  final int sensorId;
  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;

  /// Configured cylinder volume in liters, DERIVED from gas consumption (Garmin
  /// does not transmit size). Null when not reliably derivable, in which case
  /// the tank still imports with pressure/gas but no volume.
  final double? cylinderVolumeLiters;
}
```

(b) In `extract()`, replace the `tanks.add(FitTank(...))` call (the one inside the
summaries loop) with locals + derivation:

```dart
      final startBar = _scaled(
        m,
        FitConstants.tsStartPressure,
        FitConstants.pressureScaleBar,
      );
      final endBar = _scaled(
        m,
        FitConstants.tsEndPressure,
        FitConstants.pressureScaleBar,
      );
      final usedLiters = _scaled(
        m,
        FitConstants.tsVolumeUsed,
        FitConstants.volumeScaleLiters,
      );
      tanks.add(
        FitTank(
          sensorId: sensor,
          order: order,
          startPressureBar: startBar,
          endPressureBar: endBar,
          volumeUsedLiters: usedLiters,
          cylinderVolumeLiters: _deriveCylinderVolumeLiters(
            startBar,
            endBar,
            usedLiters,
          ),
        ),
      );
```

(c) Add the pure helper next to `_scaled` (inside `class FitTankExtractor`):

```dart
  /// Derives the configured cylinder volume (liters) by reversing Garmin's
  /// gas-consumption computation: `size = volumeUsed / (startBar - endBar)`.
  /// Returns null (no volume) when inputs are missing or the result is
  /// unreliable: see [FitConstants.minDeriveDropBar] /
  /// [FitConstants.maxPlausibleVolumeLiters]. Rounded to 0.1 L because the value
  /// is reconstructed, not measured.
  static double? _deriveCylinderVolumeLiters(
    double? startBar,
    double? endBar,
    double? usedLiters,
  ) {
    if (usedLiters == null || usedLiters <= 0) return null;
    if (startBar == null || endBar == null) return null;
    final drop = startBar - endBar;
    if (drop < FitConstants.minDeriveDropBar) return null;
    final size = usedLiters / drop;
    if (size <= 0 || size > FitConstants.maxPlausibleVolumeLiters) return null;
    return double.parse(size.toStringAsFixed(1));
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`
Expected: PASS (all existing + 4 new tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_import/data/services/fit/fit_constants.dart lib/features/dive_import/data/services/fit/fit_tank_extractor.dart test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart
git add lib/features/dive_import/data/services/fit/fit_constants.dart lib/features/dive_import/data/services/fit/fit_tank_extractor.dart test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart
git commit -m "feat(dive-import): derive Garmin cylinder volume from gas consumption"
```

---

### Task 2: Carry cylinder volume on `ImportedTank` and populate it from the orchestrator

**Files:**
- Modify: `lib/features/dive_import/domain/entities/imported_dive.dart`
- Modify: `lib/features/dive_import/data/services/fit_parser_service.dart`
- Test: `test/features/dive_import/data/services/fit_parser_service_test.dart`

**Interfaces:**
- Consumes: `FitTank.cylinderVolumeLiters` (Task 1).
- Produces: `ImportedTank.volumeLiters` (`double?`) — the configured cylinder volume in liters. Used by Task 3.

- [ ] **Step 1: Write the failing test**

In `test/features/dive_import/data/services/fit_parser_service_test.dart`, extend the existing test `'air-integration: tank pressure from msgs 319/323 merges to samples'` — add this assertion right after the `expect(tank.volumeUsedLiters, closeTo(1993.5, 1e-6));` line:

```dart
        // Cylinder volume derived from volume_used / pressure_drop:
        // 1993.5 / (221.25 - 88.11) = 14.97 -> rounded to 15.0 L.
        expect(tank.volumeLiters, closeTo(15.0, 1e-9));
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit_parser_service_test.dart --plain-name 'air-integration: tank pressure from msgs 319/323 merges to samples'`
Expected: FAIL — `volumeLiters` is not defined on `ImportedTank`.

- [ ] **Step 3: Add `volumeLiters` to `ImportedTank`**

In `lib/features/dive_import/domain/entities/imported_dive.dart`, replace the `ImportedTank` constructor, fields, and `props` so the new field is threaded through all three:

```dart
class ImportedTank extends Equatable {
  const ImportedTank({
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
    this.volumeLiters,
    this.o2Percent,
    this.hePercent,
  });

  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;

  /// Configured cylinder volume in liters (water volume). Derived for Garmin
  /// air-integration tanks; null when unknown.
  final double? volumeLiters;
  final double? o2Percent;
  final double? hePercent;

  @override
  List<Object?> get props => [
    order,
    startPressureBar,
    endPressureBar,
    volumeUsedLiters,
    volumeLiters,
    o2Percent,
    hePercent,
  ];
}
```

- [ ] **Step 4: Populate it in the orchestrator**

In `lib/features/dive_import/data/services/fit_parser_service.dart`, inside
`_buildImportedTanks`, add the `volumeLiters` line to the `ImportedTank(...)`
constructor (right after `volumeUsedLiters:`):

```dart
          volumeUsedLiters: i < realTanks.length
              ? realTanks[i].volumeUsedLiters
              : null,
          volumeLiters: i < realTanks.length
              ? realTanks[i].cylinderVolumeLiters
              : null,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit_parser_service_test.dart`
Expected: PASS (all existing + the new assertion).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_import/domain/entities/imported_dive.dart lib/features/dive_import/data/services/fit_parser_service.dart test/features/dive_import/data/services/fit_parser_service_test.dart
git add lib/features/dive_import/domain/entities/imported_dive.dart lib/features/dive_import/data/services/fit_parser_service.dart test/features/dive_import/data/services/fit_parser_service_test.dart
git commit -m "feat(dive-import): carry derived cylinder volume on ImportedTank"
```

---

### Task 3: Emit `volume` in the FIT import payload

**Files:**
- Modify: `lib/features/universal_import/data/parsers/fit_import_parser.dart`
- Test: `test/features/universal_import/data/parsers/fit_import_parser_test.dart`

**Interfaces:**
- Consumes: `ImportedTank.volumeLiters` (Task 2).
- Produces: `diveData['tanks'][i]['volume']` (`double`), consumed by the existing
  `UddfEntityImporter` (maps `t['volume']` → `DiveTank.volume`; no change there).

- [ ] **Step 1: Write the failing test**

In `test/features/universal_import/data/parsers/fit_import_parser_test.dart`, extend
the existing test `'emits tank pressure, allTankPressures, exit GPS, and heart rate'`
— add right after the `expect(tanks.single['endPressure'], closeTo(88.11, 1e-6));` line:

```dart
      // Cylinder volume derived from volume_used: 1993.5 / 133.14 -> 15.0 L.
      expect(tanks.single['volume'], closeTo(15.0, 1e-9));
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/fit_import_parser_test.dart --plain-name 'emits tank pressure, allTankPressures, exit GPS, and heart rate'`
Expected: FAIL — `tanks.single['volume']` is null (key not emitted).

- [ ] **Step 3: Emit the volume key**

In `lib/features/universal_import/data/parsers/fit_import_parser.dart`, inside the
`dive.tanks.map((t) { ... })` builder, add the `volume` line after the `endPressure`
line:

```dart
        if (t.endPressureBar != null) tank['endPressure'] = t.endPressureBar;
        if (t.volumeLiters != null) tank['volume'] = t.volumeLiters;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/fit_import_parser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/universal_import/data/parsers/fit_import_parser.dart test/features/universal_import/data/parsers/fit_import_parser_test.dart
git add lib/features/universal_import/data/parsers/fit_import_parser.dart test/features/universal_import/data/parsers/fit_import_parser_test.dart
git commit -m "feat(dive-import): import Garmin tank cylinder volume into dives"
```

---

### Task 4: Verification gate

**Files:** none (verification only).

- [ ] **Step 1: Whole-project format check**

Run: `dart format .`
Expected: "0 changed" (or it formats then shows changes — if so, re-run the relevant
commits' `git add`/`commit --amend` is NOT needed; instead `git add -A && git commit -m "style: dart format"`). The whole-project format must be clean (CI Analyze & Format checks the whole repo).

- [ ] **Step 2: Whole-project analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Run the full FIT test surface**

Run: `flutter test test/features/dive_import/data/services/fit test/features/dive_import/data/services/fit_parser_service_test.dart test/features/universal_import/data/parsers/fit_import_parser_test.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart`
Expected: all PASS.

- [ ] **Step 4: Real-file backstop (manual dev check, not CI)**

Re-derive cylinder volumes from the reporter's real files and confirm they match the
spec's validated table (Bouchot 15.0 L; Verdugo 43 mm ~9.4 L; 51 mm / X50i ~11.0 L).
Run (sample dir is outside the repo, on the dev's Desktop):

```bash
python3 - "$HOME/Desktop/Garmin_files" <<'PY'
import glob, os, sys
from fitparse import FitFile
for path in sorted(glob.glob(os.path.join(sys.argv[1], '**', '*.fit'), recursive=True)):
    ff = FitFile(path); ff.parse()
    for msg in ff.get_messages('unknown_323'):
        d = {f.def_num: f.raw_value for f in msg.fields}
        drop = (d.get(1) or 0)/100 - (d.get(2) or 0)/100
        used = (d.get(3) or 0)/100
        size = round(used/drop, 1) if drop > 5 and used > 0 else None
        print(f"{os.path.basename(path):40s} sensor={d.get(0)} size={size}")
PY
```

Expected: derived sizes round to 15.0 (Bouchot), ~9.4 (Verdugo 43 mm), ~11.0 (51 mm / X50i); zero-`volume_used` transmitters print `size=None`.

- [ ] **Step 5: (No commit)** — verification only. If Steps 1–3 surfaced fixes, they were committed within their own task.

---

## Out of scope (tracked, not built here)

- Dive notes from the file (absent from the binary) — handled by a reply to the reporter (see spec §9) asking what "notes" they mean. Posting requires product-owner approval.
- Notes/title from the Connect-export filename; tank nicknames (`unknown_147`) → `DiveTank.name`.

## Self-review (completed)

- **Spec coverage:** §4 derivation+guards → Task 1; §5/§6 plumbing → Tasks 2–3; §8 tests → Tasks 1–4; §8 real-file backstop → Task 4 Step 4; UddfEntityImporter mapping (§6.6) → pre-existing, exercised by `uddf_entity_importer_test.dart` lines 997/1057. Notes deferral (§2/§9) → Out of scope + reporter reply.
- **Placeholder scan:** none — every step has concrete code/commands.
- **Type consistency:** `cylinderVolumeLiters` (FitTank, Task 1) → read in Task 2; `volumeLiters` (ImportedTank, Task 2) → read in Task 3; payload key `'volume'` (Task 3) ↔ `UddfEntityImporter` `t['volume']`. Consistent throughout.
