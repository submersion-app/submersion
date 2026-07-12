# CCR Loop-Aware Deco/TTS for Logged Dives — Implementation Plan (issue #455)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Logged CCR dives compute inert-gas loading, ceiling, NDL, and TTS from the constant-ppO2 loop (inspired inert = ambient − loop ppO2, split by the DILUENT's He:N2 ratio) instead of modeling the dive as open-circuit on the first tank's gas — closing issue #455.

**Architecture:** All engine capability already exists on main (planner Phase 4, PR #488): `ProfileGasSegment.setpoint` → `ClosedCircuit` constant-ppO2 loading inside `BuhlmannAlgorithm.processProfileWithGasSegments`, and `CcrLoopAscentGas` expresses the loop as a depth-dependent ascent gas. This is a wiring fix in three layers: (1) the engine derives a per-sample loop ascent plan from setpoint-bearing segments so the TTS ascent simulation holds ppO2 at the setpoint; (2) `ProfileAnalysisService` stops gating gas segments to `DiveMode.oc`; (3) the analysis providers build CCR gas segments (diluent + per-sample resolved loop ppO2 as the setpoint) and pass them in. ppO2 source rule for loading = the existing `resolveRebreatherPpO2` rule: measured cells / dc-supplied ppO2, falling back to recorded setpoint samples.

**Tech Stack:** Dart/Flutter, existing `lib/core/deco/` engine, Riverpod providers, `flutter_test` with committed SSRF fixtures.

**Validation target (the "money number"):** dive 003 fixture (`test/dives/003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml`), GF 45/75, at minute 40 (44.1 m, loop ppO2 ~1.26 bar): app currently computes TTS ≈ 16–17 min (open-circuit EAN40 model); Subsurface computes **24 min**. After this fix the calculated TTS at that sample must be 24 min ± 2 min.

## Global Constraints

- No emojis in code, comments, or documentation.
- `dart format .` must be clean after every task; `flutter analyze` clean at the end of every task.
- Commit after each task; commit messages without Co-Authored-By.
- Scope: **CCR only**. SCR stays on its existing path (depth-varying loop FO2 is a follow-up per issue #455). Bailout-to-OC mid-dive and multi-diluent switches are follow-ups (see Out of scope).
- Do the work on a branch/worktree, not directly on main (use superpowers:using-git-worktrees at execution start; remember `git submodule update --init --recursive` + `flutter pub get` in a fresh worktree).

## Key facts an implementer needs (verified against main)

- `ProfileGasSegment` (`lib/core/deco/entities/profile_gas_segment.dart`) has `startTimestamp`, `fN2`, `fHe`, and optional `setpoint`. When `setpoint != null`, `fN2`/`fHe` describe the **diluent**.
- `BuhlmannAlgorithm.processProfileWithGasSegments` (`lib/core/deco/buhlmann_algorithm.dart:805`) already loads tissues via `ClosedCircuit` when the active segment has a setpoint (`_breathingFor`, line ~939), and passes `breathing:` into `getDecoStatus` → `calculateNdl`. What it does NOT do: give the TTS/schedule simulation a loop-aware ascent plan — `ascentGas:` is whatever the caller passed (null for CCR today), so the ascent breathes fixed OC fractions.
- `CcrLoopAscentGas` (`lib/core/deco/ascent/ccr_loop_ascent_gas.dart`) converts a setpoint + diluent into depth-dependent effective fractions the unchanged stop-search machinery consumes exactly. Constructor: `CcrLoopAscentGas({required environment, required setpointLow, required setpointHigh, required switchDepth, required diluentFO2, diluentFHe})`.
- `ProfileAnalysisService.analyze` (`lib/features/dive_log/data/services/profile_analysis_service.dart:526`) gates segments with `useOcGasSegments = diveMode == DiveMode.oc && gasSegments != null` (line ~579); CCR falls through to `processProfile(fN2, fHe)` on the **first tank's** fractions (the bug).
- Providers (`lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`): `computeAnalysisForProfile` builds `gasSegments`/`ascentGases` only for `DiveMode.oc` (lines ~809–822) and resolves `rebreatherPpO2 = resolveRebreatherPpO2(profile)` for non-OC dives (line ~825). The sync `diveProfileAnalysisProvider` (line ~1245) passes no gas segments at all.
- `resolveRebreatherPpO2` (same file, line ~453) returns a continuous per-sample ppO2 curve: dc-supplied ppO2 → cell average → setpoint samples, never mixed, gaps forward-filled. Returns null only when the profile has no ppO2/cell/setpoint data at all.
- `Dive.diluentTank` (`lib/features/dive_log/domain/entities/dive.dart:297`) returns the `TankRole.diluent` tank or null; `Dive.diluentGas` is an optional `GasMix?`; `dive.setpointHigh`/`setpointLow` are optional doubles. `GasMix` has `o2`/`he` percentages and `isAir`.
- `DiveProfilePoint` has `setpoint` and `ppO2` (bar); the Subsurface parser maps the XML `po2` attribute to `setpoint` (forward-filled) and `dc_supplied_ppo2` to `ppO2` (forward-filled).
- Fixture 003 has tanks: `[0]` EAN40 D12 (no role attr → back gas), `[1]` air D12 with `use='diluent'` → `TankRole.diluent`; per-sample `po2` (setpoint) and `dc_supplied_ppo2` samples; a setpoint switch mid-dive. Fixture 002 has setpoint samples only (no calculated ppO2).
- `test/core/deco/tts_fixture_shape_test.dart` lines 131–165 currently PIN the buggy behavior (CCR analysis identical with/without an ascent plan because segments are OC-gated). Task 2 removes those tests; Task 5 adds the correct fixture coverage.
- Direction-of-change intuition for assertions: at 44 m, an air-diluent loop at ppO2 1.3 has effective fN2 ≈ 0.76 — MORE inert than OC EAN40 (0.60), so loading/TTS increase vs today; at shallow stops the loop is far O2-richer than the diluent breathed OC, so holding the setpoint through the ascent (Task 1) is what keeps stops from overshooting (16 → ~24, not 60). The three wiring pieces ship together.

## File Structure

- Modify: `lib/core/deco/buhlmann_algorithm.dart` — derive loop ascent plan per sample (Task 1).
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` — un-gate segments for the deco integration (Task 2).
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` — `resolveCcrDiluentMix`, `buildCcrProfileGasSegments`, wiring in both analysis paths (Tasks 3–4).
- Tests: `test/core/deco/buhlmann_ccr_test.dart` (extend), `test/features/dive_log/data/services/profile_analysis_service_test.dart` (extend), `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` (extend), `test/core/deco/tts_fixture_shape_test.dart` (rework CCR section).

---

### Task 1: Engine — setpoint-bearing segments imply a loop ascent plan

The TTS/deco-schedule simulation must hold ppO2 at the active segment's setpoint through the ascent. Because the setpoint varies over the dive (per-sample segments from Task 4), the plan must be derived per sample inside the profile loop — a fixed caller-supplied plan cannot express this. An explicitly passed `ascentGasPlan` still wins (OC callers unaffected).

**Files:**
- Modify: `lib/core/deco/buhlmann_algorithm.dart`
- Test: `test/core/deco/buhlmann_ccr_test.dart`

**Interfaces:**
- Consumes: `CcrLoopAscentGas` (existing), `ProfileGasSegment.setpoint` (existing).
- Produces: `processProfileWithGasSegments` behavior — for any sample whose active segment has `setpoint != null` and when the caller passed no `ascentGasPlan`, TTS/ceiling/schedule use `CcrLoopAscentGas(setpointLow == setpointHigh == segment.setpoint, switchDepth: 0, diluent from segment fractions)`. No signature changes.

- [ ] **Step 1: Write the failing tests** — add a new group to `test/core/deco/buhlmann_ccr_test.dart`:

```dart
group('CCR loop ascent plan (issue #455)', () {
  // Square profile deep/long enough to be in deco at the last bottom sample.
  const depths = [0.0, 45.0, 45.0, 45.0, 45.0, 0.0];
  const times = [0, 180, 600, 1200, 2400, 2700];

  const loopSegments = [
    ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
  ];

  BuhlmannAlgorithm algo() => BuhlmannAlgorithm(gfLow: 0.45, gfHigh: 0.75);

  test('derived loop plan matches an explicit CcrLoopAscentGas', () {
    final derived = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: loopSegments,
    );
    final explicit = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: loopSegments,
      ascentGasPlan: CcrLoopAscentGas(
        environment: DiveEnvironment.standard,
        setpointLow: 1.3,
        setpointHigh: 1.3,
        switchDepth: 0.0,
        diluentFO2: 0.21,
        diluentFHe: 0.0,
      ),
    );
    expect(
      derived.map((s) => s.ttsSeconds).toList(),
      explicit.map((s) => s.ttsSeconds).toList(),
    );
    expect(
      derived.map((s) => s.ceilingMeters).toList(),
      explicit.map((s) => s.ceilingMeters).toList(),
    );
  });

  test('loop TTS is shorter than breathing the diluent open-circuit on the '
      'ascent (setpoint held through stops)', () {
    // Same loading for both runs (segments identical); only the ascent plan
    // differs: derived loop plan vs the diluent as a fixed OC ascent gas.
    final loop = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: loopSegments,
    );
    final ocAscent = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: loopSegments,
      ascentGasPlan: FixedAscentGas(fN2: 0.79),
    );
    // In deco at the last bottom sample; the O2-rich loop clears stops faster.
    expect(loop[4].ndlSeconds, -1);
    expect(loop[4].ttsSeconds, lessThan(ocAscent[4].ttsSeconds));
  });

  test('ascent plan follows the ACTIVE segment setpoint per sample', () {
    const twoSetpoints = [
      ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 0.7),
      ProfileGasSegment(startTimestamp: 900, fN2: 0.79, setpoint: 1.3),
    ];
    final derived = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: twoSetpoints,
    );
    CcrLoopAscentGas plan(double sp) => CcrLoopAscentGas(
      environment: DiveEnvironment.standard,
      setpointLow: sp,
      setpointHigh: sp,
      switchDepth: 0.0,
      diluentFO2: 0.21,
      diluentFHe: 0.0,
    );
    final lowRun = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: twoSetpoints,
      ascentGasPlan: plan(0.7),
    );
    final highRun = algo().processProfileWithGasSegments(
      depths: depths,
      timestamps: times,
      gasSegments: twoSetpoints,
      ascentGasPlan: plan(1.3),
    );
    // Sample index 2 (t=600) is in the 0.7 segment; index 4 (t=2400) in 1.3.
    expect(derived[2].ttsSeconds, lowRun[2].ttsSeconds);
    expect(derived[4].ttsSeconds, highRun[4].ttsSeconds);
  });
});
```

Add the needed imports to the test file: `package:submersion/core/deco/ascent/ascent_gas_plan.dart`, `package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart`, `package:submersion/core/deco/entities/dive_environment.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/deco/buhlmann_ccr_test.dart`
Expected: the three new tests FAIL (derived run currently has no ascent plan, so it uses `FixedAscentGas` on the sample gas — TTS lists differ from the explicit-plan runs).

- [ ] **Step 3: Implement** — in `lib/core/deco/buhlmann_algorithm.dart`:

Add import:

```dart
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
```

Add a private helper next to `_breathingFor` (~line 939):

```dart
/// Ascent plan implied by a setpoint-bearing segment: the loop itself, held
/// at the segment's setpoint all the way to the surface, so the TTS/schedule
/// simulation keeps constant-ppO2 physics (inert fraction changes with depth
/// as ppO2 stays fixed). Null for open-circuit segments.
CcrLoopAscentGas? _loopAscentPlanFor(ProfileGasSegment gas) {
  final setpoint = gas.setpoint;
  if (setpoint == null) return null;
  return CcrLoopAscentGas(
    environment: environment,
    setpointLow: setpoint,
    setpointHigh: setpoint,
    switchDepth: 0.0,
    diluentFO2: 1.0 - gas.fN2 - gas.fHe,
    diluentFHe: gas.fHe,
  );
}
```

In `processProfileWithGasSegments`, change the per-sample status call (~line 904):

```dart
final sampleGas = _activeGasAtTimestamp(timestamps[i], gasSegments);
results.add(
  getDecoStatus(
    currentDepth: depths[i],
    fN2: sampleGas.fN2,
    fHe: sampleGas.fHe,
    safetyStopTimeAccumulated: safetyStopTimeAccumulated,
    ascentGas: ascentGasPlan ?? _loopAscentPlanFor(sampleGas),
    breathing: _breathingFor(sampleGas),
  ),
);
```

- [ ] **Step 4: Run to verify pass, and no regressions in the deco suite**

Run: `flutter test test/core/deco/`
Expected: all PASS (OC paths unaffected: segments without setpoints derive a null plan, identical to before).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/core/deco/buhlmann_algorithm.dart test/core/deco/buhlmann_ccr_test.dart
git add lib/core/deco/buhlmann_algorithm.dart test/core/deco/buhlmann_ccr_test.dart
git commit -m "feat(deco): hold the CCR setpoint through TTS/schedule ascents for setpoint-bearing segments"
```

---

### Task 2: Service — gas segments drive the deco integration for CCR too

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (~lines 579–603)
- Modify: `test/core/deco/tts_fixture_shape_test.dart` (delete the two obsolete CCR identity tests, lines 131–165)
- Test: `test/features/dive_log/data/services/profile_analysis_service_test.dart`

**Interfaces:**
- Consumes: Task 1 behavior (setpoint segments imply loop ascent plan).
- Produces: `ProfileAnalysisService.analyze(diveMode: DiveMode.ccr, gasSegments: <setpoint-bearing segments>, ...)` runs `processProfileWithGasSegments` (loop loading + loop TTS). OC gas-aware CNS/OTU/fraction metrics (`_calculateOcGasAwareMetrics`) stay OC-only — CCR CNS/OTU keep coming from the resolved ppO2 curve as today.

- [ ] **Step 1: Write the failing test** — add to `test/features/dive_log/data/services/profile_analysis_service_test.dart`:

```dart
group('CCR gas segments drive deco (issue #455)', () {
  // 44 m for ~40 min on an air-diluent loop at setpoint 1.3, first tank EAN40.
  // Effective loop fN2 at 44 m is ~0.76 vs EAN40's 0.60, so the loop loads
  // MORE nitrogen than the legacy open-circuit first-tank model.
  const depths = [0.0, 44.0, 44.0, 44.0, 44.0, 0.0];
  const timestamps = [0, 180, 900, 1800, 2400, 2700];

  test('setpoint segments change deco output vs legacy first-tank model', () {
    final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);

    final legacy = service.analyze(
      diveId: 'ccr-legacy',
      depths: depths,
      timestamps: timestamps,
      o2Fraction: 0.40, // first tank EAN40 (the bug's model)
      diveMode: DiveMode.ccr,
      setpointHigh: 1.3,
    );
    final loop = service.analyze(
      diveId: 'ccr-loop',
      depths: depths,
      timestamps: timestamps,
      o2Fraction: 0.40,
      diveMode: DiveMode.ccr,
      setpointHigh: 1.3,
      gasSegments: const [
        ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
      ],
    );

    // In deco at the last bottom sample under both models.
    expect(loop.ndlCurve[4], -1);
    // The loop loads more inert gas at 44 m than OC EAN40, so the obligation
    // is LARGER than the legacy understated value.
    expect(loop.ttsCurve![4], greaterThan(legacy.ttsCurve![4]));
    // And the curves genuinely came from the segment path.
    expect(loop.ttsCurve, isNot(equals(legacy.ttsCurve)));
  });

  test('CCR CNS/OTU still come from the resolved ppO2 curve, not OC metrics',
      () {
    final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);
    final ppO2Curve = List<double>.filled(depths.length, 1.3);
    final analysis = service.analyze(
      diveId: 'ccr-cns',
      depths: depths,
      timestamps: timestamps,
      o2Fraction: 0.40,
      diveMode: DiveMode.ccr,
      setpointHigh: 1.3,
      gasSegments: const [
        ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
      ],
      rebreatherPpO2Curve: ppO2Curve,
    );
    expect(analysis.ppO2Curve, ppO2Curve);
    expect(analysis.o2Exposure.maxPpO2, closeTo(1.3, 0.001));
  });
});
```

Import `package:submersion/core/deco/entities/profile_gas_segment.dart` and `package:submersion/core/constants/enums.dart` in the test file if not present.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_service_test.dart`
Expected: first new test FAILS (`loop.ttsCurve` equals `legacy.ttsCurve` because segments are discarded for CCR).

- [ ] **Step 3: Implement** — in `profile_analysis_service.dart`, replace the gate (~line 579):

```dart
// Gas segments drive the deco integration whenever provided: for OC they
// carry the recorded tank/switch schedule; for CCR they carry the diluent
// fractions plus the loop setpoint per segment, which the engine turns into
// constant-ppO2 loading and a loop-held ascent (issue #455). The OC
// gas-aware CNS/OTU/fraction metrics below remain OC-only: rebreather
// CNS/OTU come from the resolved loop ppO2 curve instead.
final useGasSegmentsForDeco = gasSegments != null;
final useOcGasSegments = diveMode == DiveMode.oc && gasSegments != null;
final decoStatuses = useGasSegmentsForDeco
    ? _buhlmannAlgorithm.processProfileWithGasSegments(
        depths: depths,
        timestamps: timestamps,
        gasSegments: gasSegments,
        ascentGasPlan: ascentGasPlan,
      )
    : _buhlmannAlgorithm.processProfile(
        depths: depths,
        timestamps: timestamps,
        fN2: n2Fraction,
        fHe: heFraction,
      );
```

(`useOcGasSegments` keeps guarding `ocGasMetrics` exactly as before.)

- [ ] **Step 4: Delete the obsolete pinned-bug tests** — in `test/core/deco/tts_fixture_shape_test.dart`, remove the `for (final fixture in const [...])` block (lines 131–165) and the now-stale sentence in the file header comment ("and assert the CCR fixtures are untouched by the gas-aware machinery (it is gated to OC)"). Task 5 replaces this coverage with correct fixture assertions. Remove imports that become unused (`enums.dart` if nothing else uses `DiveMode`).

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: all PASS. If any test outside the deleted block pinned CCR-ignores-segments behavior, inspect it: update only tests that assert the buggy gating, never weaken OC assertions.

- [ ] **Step 6: Format + commit**

```bash
dart format lib/features/dive_log/data/services/profile_analysis_service.dart test/
git add lib/features/dive_log/data/services/profile_analysis_service.dart test/features/dive_log/data/services/profile_analysis_service_test.dart test/core/deco/tts_fixture_shape_test.dart
git commit -m "fix(deco): run CCR dives through the gas-segment deco path (issue #455)"
```

---

### Task 3: Provider — CCR segment builder (diluent + resolved loop ppO2 as setpoint)

Pure functions first, wiring in Task 4. The setpoint source follows the existing rebreather ppO2 rule: the per-sample curve from `resolveRebreatherPpO2` (measured cells / dc-supplied ppO2 → setpoint samples). A new segment starts whenever the resolved value moves more than 0.05 bar from the active segment's setpoint — this tracks real setpoint switches (0.7 → 1.3) and slow measured drift without emitting a segment per noisy sample.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (add functions near `buildProfileGasSegments`, ~line 175)
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`

**Interfaces:**
- Consumes: `Dive.diluentTank`, `Dive.diluentGas`, `GasMix`, `ProfileGasSegment`.
- Produces (used by Task 4 and tests):

```dart
/// Diluent mix for a CCR dive: the TankRole.diluent tank's mix, else the
/// dive-level diluentGas, else the first tank that is not the O2 supply or a
/// bailout, else air.
@visibleForTesting
GasMix resolveCcrDiluentMix(Dive dive);

/// CCR gas segments: diluent inert fractions with the loop ppO2 as the
/// per-segment setpoint. [loopPpO2Curve] is the resolved per-sample curve
/// (resolveRebreatherPpO2), aligned with [timestamps]; [fallbackSetpoint] is
/// used as a constant setpoint when the curve is absent. Returns null when
/// neither exists (no loop ppO2 information at all — callers keep the legacy
/// path).
@visibleForTesting
List<ProfileGasSegment>? buildCcrProfileGasSegments({
  required List<int> timestamps,
  required List<double>? loopPpO2Curve,
  required GasMix diluentMix,
  double? fallbackSetpoint,
  double setpointTolerance = 0.05,
});
```

- [ ] **Step 1: Write the failing tests** — add to `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` (reuse that file's existing helpers for constructing `Dive`/`DiveTank` if present; otherwise construct minimal instances the way its other tests do):

```dart
group('resolveCcrDiluentMix', () {
  DiveTank tank(GasMix mix, TankRole role) =>
      DiveTank(id: role.name, gasMix: mix, role: role);

  test('prefers the diluent-role tank over the first tank', () {
    final dive = makeDive(
      tanks: [
        tank(const GasMix(o2: 40), TankRole.backGas),
        tank(const GasMix(), TankRole.diluent), // air
      ],
    );
    expect(resolveCcrDiluentMix(dive).o2, 21);
  });

  test('falls back to dive.diluentGas when no diluent tank', () {
    final dive = makeDive(
      tanks: [tank(const GasMix(o2: 40), TankRole.backGas)],
      diluentGas: const GasMix(o2: 18, he: 45),
    );
    expect(resolveCcrDiluentMix(dive).he, 45);
  });

  test('skips O2-supply and bailout tanks in the positional fallback', () {
    final dive = makeDive(
      tanks: [
        tank(const GasMix(o2: 100), TankRole.oxygenSupply),
        tank(const GasMix(o2: 50), TankRole.bailout),
        tank(const GasMix(o2: 18, he: 45), TankRole.backGas),
      ],
    );
    expect(resolveCcrDiluentMix(dive).o2, 18);
  });

  test('defaults to air with no usable tanks', () {
    final dive = makeDive(tanks: []);
    expect(resolveCcrDiluentMix(dive).isAir, isTrue);
  });
});

group('buildCcrProfileGasSegments', () {
  const times = [0, 60, 120, 180, 240];
  const air = GasMix(); // 21/0

  test('flat curve yields one segment with diluent fractions and setpoint',
      () {
    final segments = buildCcrProfileGasSegments(
      timestamps: times,
      loopPpO2Curve: const [1.3, 1.3, 1.3, 1.3, 1.3],
      diluentMix: const GasMix(o2: 18, he: 45),
    );
    expect(segments, hasLength(1));
    expect(segments!.first.setpoint, 1.3);
    expect(segments.first.fHe, closeTo(0.45, 1e-9));
    expect(segments.first.fN2, closeTo(0.37, 1e-9));
  });

  test('a setpoint switch beyond the tolerance starts a new segment', () {
    final segments = buildCcrProfileGasSegments(
      timestamps: times,
      loopPpO2Curve: const [0.7, 0.7, 1.3, 1.3, 1.3],
      diluentMix: air,
    )!;
    expect(segments, hasLength(2));
    expect(segments[0].setpoint, 0.7);
    expect(segments[1].startTimestamp, 120);
    expect(segments[1].setpoint, 1.3);
  });

  test('measured noise within the tolerance stays one segment', () {
    final segments = buildCcrProfileGasSegments(
      timestamps: times,
      loopPpO2Curve: const [1.30, 1.28, 1.32, 1.27, 1.31],
      diluentMix: air,
    );
    expect(segments, hasLength(1));
  });

  test('no curve falls back to a constant fallback setpoint', () {
    final segments = buildCcrProfileGasSegments(
      timestamps: times,
      loopPpO2Curve: null,
      diluentMix: air,
      fallbackSetpoint: 1.2,
    );
    expect(segments, hasLength(1));
    expect(segments!.first.setpoint, 1.2);
  });

  test('no loop ppO2 information at all returns null (legacy path)', () {
    expect(
      buildCcrProfileGasSegments(
        timestamps: times,
        loopPpO2Curve: null,
        diluentMix: air,
      ),
      isNull,
    );
  });
});
```

If the test file has no `makeDive` helper, add one locally that fills only `Dive`'s required constructor fields plus the parameters shown (`tanks`, `diluentGas`), copying the minimal-construction pattern already used in that file.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
Expected: FAIL — `resolveCcrDiluentMix` / `buildCcrProfileGasSegments` undefined.

- [ ] **Step 3: Implement** — in `profile_analysis_provider.dart`, below `buildProfileGasSegments`:

```dart
/// Diluent mix for a CCR dive: the TankRole.diluent tank's mix, else the
/// dive-level diluentGas, else the first tank that is not the O2 supply or a
/// bailout, else air. The FIRST tank must not be assumed to be the diluent --
/// on imported CCR dives it is often the O2-richer loop/bailout mix
/// (issue #455: dive 003's first tank is EAN40, the diluent is air).
@visibleForTesting
GasMix resolveCcrDiluentMix(Dive dive) {
  final diluentTank = dive.diluentTank;
  if (diluentTank != null) return diluentTank.gasMix;
  final diluentGas = dive.diluentGas;
  if (diluentGas != null) return diluentGas;
  for (final tank in dive.tanks) {
    if (tank.role == TankRole.oxygenSupply || tank.role == TankRole.bailout) {
      continue;
    }
    return tank.gasMix;
  }
  return const GasMix();
}

/// Builds the CCR gas schedule for decompression analysis: the diluent's
/// inert fractions with the loop ppO2 as each segment's setpoint, so the
/// engine loads tissues at constant ppO2 (inspired inert = ambient - loop
/// ppO2, split by the diluent's He:N2 ratio) and holds the setpoint through
/// the TTS ascent.
///
/// [loopPpO2Curve] is the per-sample resolved loop ppO2
/// ([resolveRebreatherPpO2]: measured cells / dc-supplied ppO2, falling back
/// to recorded setpoint samples), aligned with [timestamps]. A new segment
/// starts when the value moves more than [setpointTolerance] bar from the
/// active segment's setpoint -- tracking real setpoint switches without
/// emitting a segment per noisy cell sample. [fallbackSetpoint] (the
/// dive-level setpoint) is used as a constant when no curve exists. Returns
/// null when neither exists: with no loop ppO2 information the loop cannot
/// be modeled and callers keep the legacy path.
@visibleForTesting
List<ProfileGasSegment>? buildCcrProfileGasSegments({
  required List<int> timestamps,
  required List<double>? loopPpO2Curve,
  required GasMix diluentMix,
  double? fallbackSetpoint,
  double setpointTolerance = 0.05,
}) {
  final fN2 = diluentMix.isAir
      ? airN2Fraction
      : (100.0 - diluentMix.o2 - diluentMix.he) / 100.0;
  final fHe = diluentMix.he / 100.0;

  final curve =
      loopPpO2Curve != null && loopPpO2Curve.length == timestamps.length
      ? loopPpO2Curve
      : null;
  if (curve == null) {
    if (fallbackSetpoint == null) return null;
    return [
      ProfileGasSegment(
        startTimestamp: 0,
        fN2: fN2,
        fHe: fHe,
        setpoint: fallbackSetpoint,
      ),
    ];
  }

  final segments = <ProfileGasSegment>[
    ProfileGasSegment(startTimestamp: 0, fN2: fN2, fHe: fHe, setpoint: curve[0]),
  ];
  for (int i = 1; i < timestamps.length; i++) {
    if ((curve[i] - segments.last.setpoint!).abs() > setpointTolerance) {
      segments.add(
        ProfileGasSegment(
          startTimestamp: timestamps[i],
          fN2: fN2,
          fHe: fHe,
          setpoint: curve[i],
        ),
      );
    }
  }
  return segments;
}
```

(`airN2Fraction` is already imported in this file; `TankRole` comes with the existing `enums.dart` import.)

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git commit -m "feat(dive-log): CCR diluent resolution and loop gas-segment builder"
```

---

### Task 4: Provider — wire CCR segments into both analysis paths

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` — `computeAnalysisForProfile` (~lines 809–870) and `diveProfileAnalysisProvider` (~lines 1296–1335)
- Test: `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 functions, Task 2 service behavior.
- Produces: both providers pass setpoint-bearing `gasSegments` for `DiveMode.ccr` dives; `ascentGases`/`ascentGasPlan` remain OC-only (the engine derives the loop plan — passing `OptimalOcAscentGas` for CCR would override it and is wrong).

- [ ] **Step 1: Write the failing test** — add a wiring test (async path) to the provider test file, following its existing container/override pattern. If the file has no end-to-end harness for `computeAnalysisForProfile`, test through `diveProfileAnalysisProvider` with a constructed CCR `Dive` (profile with `setpoint`/`ppO2` samples, EAN40 back-gas tank plus air diluent-role tank):

```dart
test('CCR dive analysis loads on the loop, not the first tank (issue #455)',
    () async {
  // 44 m square profile at setpoint 1.3, air diluent, EAN40 first tank.
  final profile = [
    for (final (t, d) in [(0, 0.0), (180, 44.0), (1200, 44.0), (2400, 44.0), (2700, 0.0)])
      DiveProfilePoint(timestamp: t, depth: d, setpoint: 1.3),
  ];
  final ccrDive = makeDive(
    diveMode: DiveMode.ccr,
    profile: profile,
    tanks: [
      DiveTank(id: 'bg', gasMix: const GasMix(o2: 40), role: TankRole.backGas),
      DiveTank(id: 'dil', gasMix: const GasMix(), role: TankRole.diluent),
    ],
  );
  // Identical dive analyzed as if the segments were absent (legacy model):
  // first tank EAN40 open circuit.
  final legacyDive = ccrDive.copyWith(
    profile: [
      for (final p in profile)
        p.copyWith(), // same profile; legacy comes from mode below
    ],
    diveMode: DiveMode.oc,
  );

  final container = createContainer(); // the file's existing helper
  final ccr = container.read(diveProfileAnalysisProvider(ccrDive));
  final legacy = container.read(diveProfileAnalysisProvider(legacyDive));

  expect(ccr, isNotNull);
  // Loop at 1.3 over air diluent at 44 m loads more N2 than OC EAN40:
  // the CCR TTS at the last bottom sample exceeds the legacy value.
  expect(
    ccr!.ttsCurve![3],
    greaterThan(legacy!.ttsCurve![3]),
  );
});
```

Adapt helper names (`makeDive`, `createContainer`) to what the test file actually provides; the assertion logic must stay as written. If `Dive.copyWith` cannot clear `diveMode`, build `legacyDive` with a second `makeDive` call instead.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`
Expected: new test FAILS (CCR path passes no segments yet, so both analyses model EAN40 OC and the TTS values match).

- [ ] **Step 3: Implement wiring** — in `computeAnalysisForProfile`, replace lines ~809–827 so the rebreather curve is resolved BEFORE segments are built, and CCR builds its own segments:

```dart
    // Resolve rebreather loop ppO2 once and reuse it for the analysis
    // (CNS/OTU and CCR inert-gas loading) and the display overlay so they
    // always agree.
    final rebreatherPpO2 = dive.diveMode == DiveMode.oc
        ? null
        : resolveRebreatherPpO2(profile);
    final gasSegments = switch (dive.diveMode) {
      DiveMode.oc => buildProfileGasSegments(
        dive,
        await repository.getGasSwitchesForDive(diveId),
      ),
      DiveMode.ccr => buildCcrProfileGasSegments(
        timestamps: timestamps,
        loopPpO2Curve: rebreatherPpO2?.curve,
        diluentMix: resolveCcrDiluentMix(dive),
        fallbackSetpoint: dive.setpointHigh ?? dive.setpointLow,
      ),
      DiveMode.scr => null,
    };
    final ascentMaxPpO2 = ref.watch(ppO2MaxDecoProvider);
    final ascentGases = dive.diveMode == DiveMode.oc
        ? buildAvailableGases(
            dive,
            maxPpO2: ascentMaxPpO2,
            gasSet: ref.watch(ascentGasSetProvider),
          )
        : null;
```

(Delete the old later `rebreatherPpO2` declaration at ~line 825 — it moved up. Everything else in the function stays; `gasSegments` and `rebreatherPpO2?.curve` already flow into `_ProfileAnalysisInput`.)

In `diveProfileAnalysisProvider`, after the existing `rebreatherPpO2` resolution (~line 1298), add the same segment construction and pass it to `service.analyze`:

```dart
    final gasSegments = dive.diveMode == DiveMode.ccr
        ? buildCcrProfileGasSegments(
            timestamps: timestamps,
            loopPpO2Curve: rebreatherPpO2?.curve,
            diluentMix: resolveCcrDiluentMix(dive),
            fallbackSetpoint: dive.setpointHigh ?? dive.setpointLow,
          )
        : null;
```

and in the `service.analyze(...)` call add `gasSegments: gasSegments,`. (This sync path never passed OC segments; do not add OC segments here — out of scope.)

- [ ] **Step 4: Run to verify pass + full suite**

Run: `flutter test test/features/dive_log/presentation/providers/ && flutter test`
Expected: all PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git add lib/features/dive_log/presentation/providers/profile_analysis_provider.dart test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart
git commit -m "fix(dive-log): analyze CCR dives with loop gas segments in both analysis paths (issue #455)"
```

---

### Task 5: Fixture regression tests — pin dive 003 against Subsurface

Replaces the coverage deleted in Task 2 with assertions of the CORRECT behavior, including the issue's headline number.

**Files:**
- Modify: `test/core/deco/tts_fixture_shape_test.dart` (new CCR section; reuse the file's `_parseFixture`, `_depths`, `_timestamps` helpers)

**Interfaces:**
- Consumes: fixture parser output maps (profile point maps carry `'setpoint'` and `'ppO2'` keys, forward-filled by the parser; tank maps carry `'gasMix'` and `'role'`), `buildCcrProfileGasSegments` + `resolveRebreatherPpO2` (import `profile_analysis_provider.dart`), `DiveProfilePoint`.

- [ ] **Step 1: Write the tests** (they should PASS immediately if Tasks 1–4 are correct — this is the cross-validation gate, not TDD of new code):

```dart
List<DiveProfilePoint> _profilePoints(Map<String, dynamic> dive) =>
    (dive['profile'] as List)
        .map(
          (p) => DiveProfilePoint(
            timestamp: (p as Map)['timestamp'] as int,
            depth: p['depth'] as double,
            setpoint: p['setpoint'] as double?,
            ppO2: p['ppO2'] as double?,
          ),
        )
        .toList();

/// Diluent mix straight from the fixture's TankRole.diluent cylinder.
GasMix _diluentMix(Map<String, dynamic> dive) => ((dive['tanks'] as List)
        .cast<Map>()
        .firstWhere((t) => t['role'] == TankRole.diluent))['gasMix']
    as GasMix;

group('CCR fixtures compute loop deco (issue #455)', () {
  test(
    'fixture 003 @ minute 40 matches Subsurface TTS (24 min +/- 2)',
    () async {
      final dive = await _parseFixture(
        '003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml',
      );
      final depths = _depths(dive);
      final timestamps = _timestamps(dive);
      final points = _profilePoints(dive);

      final resolved = resolveRebreatherPpO2(points);
      expect(resolved, isNotNull, reason: 'fixture carries po2 samples');

      final segments = buildCcrProfileGasSegments(
        timestamps: timestamps,
        loopPpO2Curve: resolved!.curve,
        diluentMix: _diluentMix(dive),
      );
      expect(segments, isNotNull);
      expect(segments!.first.setpoint, isNotNull);

      // Issue #455 reference point: GF 45/75, minute 40 (44.1 m, loop ppO2
      // ~1.26 bar). App used to show ~17 min (OC EAN40 model); Subsurface
      // shows 24 min.
      final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);
      final analysis = service.analyze(
        diveId: 'fixture-003',
        depths: depths,
        timestamps: timestamps,
        diveMode: DiveMode.ccr,
        gasSegments: segments,
        rebreatherPpO2Curve: resolved.curve,
      );

      var idx = timestamps.indexOf(2400);
      if (idx < 0) {
        // Nearest sample to minute 40 if 2400 s is not an exact sample.
        idx = timestamps.indexWhere((t) => t >= 2400);
      }
      final ttsMinutes = analysis.ttsCurve![idx] / 60.0;
      expect(ttsMinutes, closeTo(24.0, 2.0));
    },
  );

  test('fixture 002 (setpoint samples only) builds setpoint segments and '
      'surfaces with TTS 0', () async {
    final dive = await _parseFixture(
      '002_ccr_only_low_sp_no_calculated_po2.ssrf.xml',
    );
    final timestamps = _timestamps(dive);
    final points = _profilePoints(dive);

    final resolved = resolveRebreatherPpO2(points);
    expect(resolved, isNotNull, reason: 'setpoint samples drive the fallback');

    final segments = buildCcrProfileGasSegments(
      timestamps: timestamps,
      loopPpO2Curve: resolved!.curve,
      diluentMix: _diluentMix(dive),
    );
    expect(segments!.every((s) => s.setpoint != null), isTrue);

    final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);
    final analysis = service.analyze(
      diveId: 'fixture-002',
      depths: _depths(dive),
      timestamps: timestamps,
      diveMode: DiveMode.ccr,
      gasSegments: segments,
      rebreatherPpO2Curve: resolved.curve,
    );
    expect(analysis.ttsCurve!.last, 0);
  });
});
```

Add imports: `package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart` (for `resolveRebreatherPpO2`, `buildCcrProfileGasSegments`). If fixture 002 has no `TankRole.diluent` cylinder, fall back in `_diluentMix` to the first tank map's `gasMix` for that test only — check the fixture's `<cylinder>` elements first and match reality.

- [ ] **Step 2: Run**

Run: `flutter test test/core/deco/tts_fixture_shape_test.dart`
Expected: PASS. If the minute-40 TTS lands outside 22–26 min, STOP — do not widen the tolerance. Debug direction: (a) confirm `resolved.curve` at index ~2400 s is ~1.26 bar (dc-supplied ppO2, not the 1.3 setpoint); (b) confirm the diluent segments carry air fractions (fN2 ~0.79, fHe 0); (c) confirm the derived ascent plan is active (Task 1) — loading-only wiring overshoots toward ~60 min; ascent-only wiring stays near ~17.

- [ ] **Step 3: Format + commit**

```bash
dart format test/core/deco/tts_fixture_shape_test.dart
git add test/core/deco/tts_fixture_shape_test.dart
git commit -m "test(deco): pin CCR fixture TTS against Subsurface (issue #455)"
```

---

### Task 6: Verification sweep

- [ ] **Step 1:** `flutter analyze` — expect zero issues.
- [ ] **Step 2:** `dart format .` — expect no changes ("0 changed").
- [ ] **Step 3:** `flutter test` — full suite green.
- [ ] **Step 4:** Manual verify (use the `verify` skill if available): run the app, open dive 003 (or import the fixture), check the profile's calculated TTS curve around minute 40 reads ~24 min and the deco panel shows a deeper/longer obligation than before; confirm an OC dive's detail page is unchanged.
- [ ] **Step 5:** Commit anything outstanding; prepare the PR per `superpowers:finishing-a-development-branch`. PR description: summary of the three wiring pieces + the fixture-003 validation table (17 → ~24 min vs Subsurface 24 min). No attribution line, no session URL (CLAUDE.md rule).

---

## Out of scope (follow-ups, note in the PR description)

- **SCR loop deco** — depth-varying loop FO2; issue #455 explicitly scopes it out.
- **Diluent switches / OC bailout mid-dive** — gas switches on CCR dives are ignored by the segment builder (constant diluent for the whole dive); bailout segments would need dive-mode-per-sample data.
- **CCR display curves other than deco** — ppN2/MOD/density curves for CCR still use the first tank's fractions (display-only; pre-existing).
- **No-ppO2-data CCR dives** — with no cells, no dc ppO2, no setpoint samples, and no dive-level setpoint, the analysis keeps the legacy first-tank model (returns null segments) rather than fabricating a loop.
- **Recorded vs configured GF** — dive 003 shows the imported Shearwater GF 45/75, not the user's configured GF; tracked separately in issue #455's notes.
