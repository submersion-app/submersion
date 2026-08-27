# CNS Calculation Method Setting Implementation Plan

Role: this document is the EXECUTION PLAN (how, task by task) for the
specification in 2026-07-16-cns-calculation-method-setting-design.md. It is
scaffolding for the implementation and can be archived after the feature
merges. Deviations discovered during execution: schema landed as v113 (main
had consumed v112 after planning); the Task 1 test tolerances were corrected
against measured fit behavior (8.1 percent worst-case, 1.5 bar
discontinuity); user-facing source links were added as follow-up Task 6b.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** User-selectable CNS toxicity calculation method (classic NOAA step table, Shearwater-style linear interpolation, Subsurface-style exponential fit) with Shearwater-style as the new default, per the approved design in `docs/plans/2026-07-16-cns-calculation-method-setting-design.md`.

**Architecture:** A `CnsCalculationMethod` enum in the deco core owns all three rate functions; `CnsTable`/`O2ToxicityCalculator` delegate to it. The chosen method is a per-diver setting persisted like gradient factors (Drift `diver_settings` column, `AppSettings` field, `settingsProvider`), threaded into profile analysis and both planners via existing provider wiring, and edited from a dialog in the settings Decompression section.

**Tech Stack:** Flutter/Dart, Drift ORM (schema v111 -> v112, build_runner codegen), Riverpod, flutter gen-l10n (11 locales).

## Global Constraints

- Branch/worktree: `worktree-cns-method-design` at `f:/GitHub/submersion/.claude/worktrees/cns-method-design` (PR #599, draft). All commands run there.
- Worktree init before first build: `git submodule update --init --recursive` then `flutter pub get`.
- No emojis anywhere. All Dart code passes `dart format` with no changes.
- No Claude attribution or co-author trailers in commits or PR text.
- Do NOT copy any code from Subsurface (GPL-2.0-only vs our GPL-3.0). Implement only from the formulas written in this plan.
- The pre-push hook mistargets worktrees: run tests manually in the worktree, push with `git push --no-verify`.
- New user-visible strings must exist in ALL 11 arb files (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`) - the files have full key parity today; keep it.
- Keep "NOAA", "Shearwater", "Subsurface" untranslated in all locales.

---

### Task 1: CnsCalculationMethod enum with all three rate functions

**Files:**
- Create: `lib/core/deco/entities/cns_calculation_method.dart`
- Test: `test/core/deco/cns_calculation_method_test.dart`

**Interfaces:**
- Produces: `enum CnsCalculationMethod { classic, shearwater, subsurface }` with `String dbValue`, `static CnsCalculationMethod fromDbValue(String? value)` (unknown -> `shearwater`), and `double cnsPerMinute(double ppO2)` returning CNS %/min.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';

void main() {
  group('CnsCalculationMethod.classic (NOAA step table)', () {
    const m = CnsCalculationMethod.classic;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
      expect(m.cnsPerMinute(0.2), 0.0);
    });
    test('whole band charged at upper-bound rate', () {
      expect(m.cnsPerMinute(0.55), closeTo(100 / 720, 1e-9));
      expect(m.cnsPerMinute(1.25), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.21), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.2), closeTo(100 / 210, 1e-9));
    });
    test('legacy flat rule above 1.6 bar', () {
      expect(m.cnsPerMinute(1.61), 10.0);
      expect(m.cnsPerMinute(2.0), 10.0);
    });
  });

  group('CnsCalculationMethod.shearwater (linear interpolation)', () {
    const m = CnsCalculationMethod.shearwater;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
    });
    test('flat 720-min rate between 0.5 and 0.6', () {
      expect(m.cnsPerMinute(0.55), closeTo(100 / 720, 1e-9));
    });
    test('exact at every NOAA entry', () {
      expect(m.cnsPerMinute(0.6), closeTo(100 / 720, 1e-9));
      expect(m.cnsPerMinute(1.0), closeTo(100 / 300, 1e-9));
      expect(m.cnsPerMinute(1.3), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.5), closeTo(100 / 120, 1e-9));
      expect(m.cnsPerMinute(1.6), closeTo(100 / 45, 1e-9));
    });
    test('interpolates the time limits between entries', () {
      expect(m.cnsPerMinute(1.25), closeTo(100 / 195, 1e-9));
      expect(m.cnsPerMinute(0.65), closeTo(100 / 645, 1e-9));
      expect(m.cnsPerMinute(1.45), closeTo(100 / 135, 1e-9));
      expect(m.cnsPerMinute(1.55), closeTo(100 / 82.5, 1e-9));
    });
    test('1.6-1.65 window uses the 45-min rate, above 1.65 flat 15 %/min', () {
      expect(m.cnsPerMinute(1.62), closeTo(100 / 45, 1e-9));
      expect(m.cnsPerMinute(1.65), closeTo(100 / 45, 1e-9));
      expect(m.cnsPerMinute(1.66), 15.0);
      expect(m.cnsPerMinute(2.0), 15.0);
    });
  });

  group('CnsCalculationMethod.subsurface (two-line exponential fit)', () {
    const m = CnsCalculationMethod.subsurface;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
    });
    test('lower fit line values', () {
      expect(m.cnsPerMinute(0.55), closeTo(0.13272, 5e-4));
      expect(m.cnsPerMinute(1.0), closeTo(0.31757, 5e-4));
      expect(m.cnsPerMinute(1.25), closeTo(0.51563, 5e-4));
      expect(m.cnsPerMinute(1.3), closeTo(0.56811, 5e-4));
      expect(m.cnsPerMinute(1.5), closeTo(0.83720, 5e-4));
    });
    test('upper fit line values', () {
      expect(m.cnsPerMinute(1.55), closeTo(1.30665, 2e-3));
      expect(m.cnsPerMinute(1.6), closeTo(2.13375, 2e-3));
      expect(m.cnsPerMinute(1.9), closeTo(40.462, 0.1));
    });
    test('reproduces the NOAA table within 8.1 percent at every entry', () {
      const knots = [0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6];
      const limits = [720, 570, 450, 360, 300, 240, 210, 180, 150, 120, 45];
      // Worst deviation of the two-line fit is 8.08% at ppO2 1.1 (259 vs 240 min).
      for (var i = 0; i < knots.length; i++) {
        final equivalentLimit = 100 / m.cnsPerMinute(knots[i]);
        expect(
          (equivalentLimit - limits[i]).abs() / limits[i],
          lessThan(0.081),
          reason: 'at ppO2 ${knots[i]}',
        );
      }
    });
  });

  group('shared properties', () {
    test('shearwater rate is monotonically non-decreasing', () {
      const m = CnsCalculationMethod.shearwater;
      for (var p = 0.51; p < 2.5; p += 0.01) {
        expect(
          m.cnsPerMinute(p + 0.01) + 1e-12 >= m.cnsPerMinute(p),
          isTrue,
          reason: 'not monotone at ppO2 $p',
        );
      }
    });

    test('subsurface rate is monotone within each fit line', () {
      // The two fitted lines meet discontinuously at 1.5 bar: the rate drops
      // about 4.5% stepping onto the upper line. This mirrors Subsurface's
      // actual formula and is asserted here so the dip is documented, not
      // accidental.
      const m = CnsCalculationMethod.subsurface;
      for (var p = 0.51; p < 1.48; p += 0.01) {
        expect(m.cnsPerMinute(p + 0.01) >= m.cnsPerMinute(p), isTrue,
            reason: 'lower line not monotone at ppO2 $p');
      }
      for (var p = 1.51; p < 2.5; p += 0.01) {
        expect(m.cnsPerMinute(p + 0.01) >= m.cnsPerMinute(p), isTrue,
            reason: 'upper line not monotone at ppO2 $p');
      }
      expect(m.cnsPerMinute(1.501), lessThan(m.cnsPerMinute(1.5)));
    });
    test('dbValue roundtrip and unknown fallback', () {
      for (final m in CnsCalculationMethod.values) {
        expect(CnsCalculationMethod.fromDbValue(m.dbValue), m);
      }
      expect(
        CnsCalculationMethod.fromDbValue('bogus'),
        CnsCalculationMethod.shearwater,
      );
      expect(
        CnsCalculationMethod.fromDbValue(null),
        CnsCalculationMethod.shearwater,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/deco/cns_calculation_method_test.dart`
Expected: FAIL - `cns_calculation_method.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;

/// Selectable algorithms converting a ppO2 exposure into CNS %/min.
///
/// All methods derive from the NOAA Diving Manual (4th ed.) oxygen exposure
/// limits and differ only in how they read between and beyond the table
/// entries. Method references (no code copied from any of them):
/// - Shearwater, "Shearwater and the CNS Oxygen Clock" (shearwater.com blog)
/// - Subsurface core/divelist.cpp, commit a0912b38bd (Robert C. Helling)
/// - R. C. Helling, "Calculating Oxygen CNS toxicity", thetheoreticaldiver.org
enum CnsCalculationMethod {
  /// Steps: each 0.1-bar band charged at its harsher edge (legacy behavior).
  classic('classic'),

  /// Linear interpolation of the NOAA time limits between entries; flat
  /// 15 %/min above 1.65 bar. Matches Shearwater's documented method.
  shearwater('shearwater'),

  /// Two-line least-squares fit to the log of the NOAA table, as used by
  /// Subsurface since 2019. Continuous and extrapolates above the table.
  subsurface('subsurface');

  final String dbValue;
  const CnsCalculationMethod(this.dbValue);

  static CnsCalculationMethod fromDbValue(String? value) {
    for (final method in CnsCalculationMethod.values) {
      if (method.dbValue == value) return method;
    }
    return CnsCalculationMethod.shearwater;
  }

  /// NOAA Diving Manual (4th ed.) single-exposure limits.
  static const List<double> _noaaPpO2 = [
    0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6,
  ];
  static const List<double> _noaaLimitMinutes = [
    720, 570, 450, 360, 300, 240, 210, 180, 150, 120, 45,
  ];

  /// CNS accumulation rate in %/min at [ppO2] (bar). Zero at or below 0.5.
  double cnsPerMinute(double ppO2) {
    if (ppO2 <= 0.5) return 0.0;
    switch (this) {
      case CnsCalculationMethod.classic:
        return _classicRate(ppO2);
      case CnsCalculationMethod.shearwater:
        return _shearwaterRate(ppO2);
      case CnsCalculationMethod.subsurface:
        return _subsurfaceRate(ppO2);
    }
  }

  static double _classicRate(double ppO2) {
    for (var i = 0; i < _noaaPpO2.length; i++) {
      if (ppO2 <= _noaaPpO2[i]) return 100.0 / _noaaLimitMinutes[i];
    }
    // Legacy flat rule above 1.6 bar. Known wart: milder than the table's
    // own trend above ~1.76 bar; kept verbatim for reproducibility of
    // historic values (design decision 2, PR #599).
    return 100.0 / 10.0;
  }

  static double _shearwaterRate(double ppO2) {
    if (ppO2 <= _noaaPpO2.first) return 100.0 / _noaaLimitMinutes.first;
    if (ppO2 > 1.65) return 15.0; // 1% per 4 s, per the Shearwater blog.
    if (ppO2 > _noaaPpO2.last) return 100.0 / _noaaLimitMinutes.last;
    for (var i = 1; i < _noaaPpO2.length; i++) {
      if (ppO2 <= _noaaPpO2[i]) {
        final t = (ppO2 - _noaaPpO2[i - 1]) /
            (_noaaPpO2[i] - _noaaPpO2[i - 1]);
        final limit = _noaaLimitMinutes[i - 1] +
            (_noaaLimitMinutes[i] - _noaaLimitMinutes[i - 1]) * t;
        return 100.0 / limit;
      }
    }
    return 100.0 / _noaaLimitMinutes.last;
  }

  static double _subsurfaceRate(double ppO2) {
    final mbar = ppO2 * 1000.0;
    final perSecond = mbar <= 1500.0
        ? math.exp(-11.7853 + 0.00193873 * mbar)
        : math.exp(-23.6349 + 0.00980829 * mbar);
    return perSecond * 100.0 * 60.0;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/deco/cns_calculation_method_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/deco/entities/cns_calculation_method.dart test/core/deco/cns_calculation_method_test.dart
git add lib/core/deco/entities/cns_calculation_method.dart test/core/deco/cns_calculation_method_test.dart
git commit -m "feat(deco): add CnsCalculationMethod with three CNS rate algorithms"
```

---

### Task 2: Thread method through CnsTable, O2ToxicityCalculator, ProfileAnalysisService; flip default

**Files:**
- Modify: `lib/core/deco/entities/o2_exposure.dart:124-153` (CnsTable)
- Modify: `lib/core/deco/o2_toxicity_calculator.dart:12-96`
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (constructor around line 485)
- Test: `test/core/deco/o2_toxicity_calculator_test.dart` (extend + repair)

**Interfaces:**
- Consumes: `CnsCalculationMethod` from Task 1.
- Produces: `CnsTable.cnsPerMinute(double ppO2, {CnsCalculationMethod method = CnsCalculationMethod.shearwater})`; `CnsTable.cnsForSegment(double ppO2, int durationSeconds, {CnsCalculationMethod method = ...shearwater})`; `O2ToxicityCalculator({..., CnsCalculationMethod cnsMethod = CnsCalculationMethod.shearwater})` using it in `getCnsPerMinute`/`calculateCnsForSegment`; `ProfileAnalysisService({..., CnsCalculationMethod cnsCalculationMethod = CnsCalculationMethod.shearwater})` passing it to its `O2ToxicityCalculator`.

- [ ] **Step 1: Write the failing tests** (append to `test/core/deco/o2_toxicity_calculator_test.dart`)

```dart
group('CNS method selection', () {
  test('default method is Shearwater-style interpolation', () {
    const calc = O2ToxicityCalculator();
    expect(calc.getCnsPerMinute(1.25), closeTo(100 / 195, 1e-9));
  });
  test('classic method reproduces the step table', () {
    const calc = O2ToxicityCalculator(
      cnsMethod: CnsCalculationMethod.classic,
    );
    expect(calc.getCnsPerMinute(1.25), closeTo(100 / 180, 1e-9));
  });
  test('subsurface method uses the exponential fit', () {
    const calc = O2ToxicityCalculator(
      cnsMethod: CnsCalculationMethod.subsurface,
    );
    expect(calc.getCnsPerMinute(1.25), closeTo(0.51563, 5e-4));
  });
});
```

Add the import `package:submersion/core/deco/entities/cns_calculation_method.dart` at the top of the test file.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/deco/o2_toxicity_calculator_test.dart`
Expected: FAIL - `cnsMethod` named parameter does not exist.

- [ ] **Step 3: Implement**

In `o2_exposure.dart`, add the import and replace the body of `CnsTable.cnsPerMinute` / `cnsForSegment` (delete the inline if-chain; the classic ladder now lives in the enum):

```dart
import 'cns_calculation_method.dart';
```

```dart
class CnsTable {
  /// CNS %/min at [ppO2] using [method] (default: Shearwater-style).
  static double cnsPerMinute(
    double ppO2, {
    CnsCalculationMethod method = CnsCalculationMethod.shearwater,
  }) {
    return method.cnsPerMinute(ppO2);
  }

  /// CNS% for a segment of [durationSeconds] at constant [ppO2].
  static double cnsForSegment(
    double ppO2,
    int durationSeconds, {
    CnsCalculationMethod method = CnsCalculationMethod.shearwater,
  }) {
    return cnsPerMinute(ppO2, method: method) * (durationSeconds / 60.0);
  }
  // cnsHalfTimeMinutes and cnsAfterSurfaceInterval stay unchanged.
}
```

In `o2_toxicity_calculator.dart`: add field `final CnsCalculationMethod cnsMethod;`, constructor param `this.cnsMethod = CnsCalculationMethod.shearwater`, add the import, and change:

```dart
double getCnsPerMinute(double ppO2) {
  return CnsTable.cnsPerMinute(ppO2, method: cnsMethod);
}

double calculateCnsForSegment(double ppO2, int durationSeconds) {
  return CnsTable.cnsForSegment(ppO2, durationSeconds, method: cnsMethod);
}
```

In `profile_analysis_service.dart`: add constructor parameter `CnsCalculationMethod cnsCalculationMethod = CnsCalculationMethod.shearwater` and pass `cnsMethod: cnsCalculationMethod` in the `_o2ToxicityCalculator = O2ToxicityCalculator(...)` initializer (line ~485). Add the import.

- [ ] **Step 4: Run deco and dive_log test suites; repair expectations**

Run: `flutter test test/core/deco/ test/features/dive_log/`
Rule for every failure caused by the default flip: if the test intends to verify the old band semantics, pass `cnsMethod: CnsCalculationMethod.classic` (or `method:` param) explicitly; if it asserts an end-to-end CNS number, update the expected value to the newly computed one ONLY after confirming the delta is explained by step-vs-interpolation (a decrease, typically a few percent relative). Do not loosen tolerances to paper over anything else.

- [ ] **Step 5: Verify passes, format, commit**

```bash
dart format lib/ test/
git add -u lib test
git commit -m "feat(deco): thread CNS method through calculators, default Shearwater-style"
```

---

### Task 3: Fixture cross-validation test (issue #578 reference values)

**Files:**
- Create: `test/core/deco/cns_method_fixture_cross_validation_test.dart`

**Interfaces:**
- Consumes: `ProfileAnalysisService(cnsCalculationMethod: ...)` from Task 2; fixture-loading helpers copied from `test/core/deco/tts_fixture_shape_test.dart` (`_parseFixture`, `_depths`, `_timestamps`, `_profilePoints`, `_diluentMix`, `resolveRebreatherPpO2`, `buildCcrProfileGasSegments` - copy the private helpers and their imports verbatim from that file).

- [ ] **Step 1: Write the test**

```dart
// Copy imports + private fixture helpers from tts_fixture_shape_test.dart,
// then:

Future<double> _cnsEndFor(CnsCalculationMethod method) async {
  final dive = await _parseFixture(
    '003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml',
  );
  final resolved = resolveRebreatherPpO2(_profilePoints(dive));
  final segments = buildCcrProfileGasSegments(
    timestamps: _timestamps(dive),
    loopPpO2Curve: resolved!.curve,
    diluentMix: _diluentMix(dive),
  );
  final service = ProfileAnalysisService(
    gfLow: 0.45,
    gfHigh: 0.75,
    cnsCalculationMethod: method,
  );
  final analysis = service.analyze(
    diveId: 'fixture-003-cns',
    depths: _depths(dive),
    timestamps: _timestamps(dive),
    diveMode: DiveMode.ccr,
    gasSegments: segments!,
    rebreatherPpO2Curve: resolved.curve,
  );
  return analysis.o2Exposure.cnsEnd;
}

void main() {
  group('issue #578 reference values on CCR fixture 003', () {
    test('classic reproduces the pre-change 51.8%', () async {
      expect(await _cnsEndFor(CnsCalculationMethod.classic), closeTo(51.8, 1.0));
    });
    test('Shearwater-style lands at the interpolation reference 46.1%', () async {
      expect(
        await _cnsEndFor(CnsCalculationMethod.shearwater),
        closeTo(46.1, 1.0),
      );
    });
    test('Subsurface fit stays within 1.5 points of interpolation', () async {
      final subsurface = await _cnsEndFor(CnsCalculationMethod.subsurface);
      final shearwater = await _cnsEndFor(CnsCalculationMethod.shearwater);
      expect(subsurface, closeTo(46.4, 1.2));
      expect((subsurface - shearwater).abs(), lessThan(1.5));
    });
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/deco/cns_method_fixture_cross_validation_test.dart`
Expected: PASS. If a value falls outside tolerance, STOP and investigate the ppO2 resolution path before touching any tolerance - these numbers are the external validation of the whole feature (issue #578 analysis comment).

- [ ] **Step 3: Format and commit**

```bash
dart format test/core/deco/cns_method_fixture_cross_validation_test.dart
git add test/core/deco/cns_method_fixture_cross_validation_test.dart
git commit -m "test(deco): cross-validate CNS methods against issue #578 references"
```

---

### Task 4: Persistence - DB column v112, repository, AppSettings, notifier, provider

**Files:**
- Modify: `lib/core/database/database.dart` (DiverSettings table ~line 1197 area; `currentSchemaVersion` line 2207; `migrationVersions` list ~line 2212; `onUpgrade` after the `from < 111` block ~line 5526)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:95,232,412`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (AppSettings field/ctor/copyWith; SettingsNotifier setter ~line 1048; convenience provider ~line 1442)
- Test: `test/features/settings/presentation/providers/settings_providers_test.dart` (extend)

**Interfaces:**
- Consumes: `CnsCalculationMethod` (Task 1).
- Produces: `AppSettings.cnsCalculationMethod` (default `shearwater`); `SettingsNotifier.setCnsCalculationMethod(CnsCalculationMethod)`; `final cnsCalculationMethodProvider = Provider<CnsCalculationMethod>`; Drift column `diver_settings.cns_calculation_method` TEXT DEFAULT 'shearwater'.

- [ ] **Step 1: Write the failing test** (extend `settings_providers_test.dart`, mirroring its existing setter tests)

```dart
test('setCnsCalculationMethod updates state and persists', () async {
  // Use the same container/notifier setup as the sibling setter tests
  // in this file.
  expect(
    container.read(settingsProvider).cnsCalculationMethod,
    CnsCalculationMethod.shearwater,
  );
  await container
      .read(settingsProvider.notifier)
      .setCnsCalculationMethod(CnsCalculationMethod.subsurface);
  expect(
    container.read(settingsProvider).cnsCalculationMethod,
    CnsCalculationMethod.subsurface,
  );
  expect(
    container.read(cnsCalculationMethodProvider),
    CnsCalculationMethod.subsurface,
  );
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/providers/settings_providers_test.dart`
Expected: FAIL - `cnsCalculationMethod` not defined.

- [ ] **Step 3: Implement schema + mapping + state**

`database.dart` DiverSettings table, next to `defaultCnsSource`:

```dart
// CNS calculation method: 'classic' | 'shearwater' | 'subsurface' (v112)
TextColumn get cnsCalculationMethod =>
    text().withDefault(const Constant('shearwater'))();
```

Bump `currentSchemaVersion` from 111 to 112; append `112,` to `migrationVersions`; add to `onUpgrade` directly after the `if (from < 111) await reportProgress();` line:

```dart
if (from < 112) {
  await m.addColumn(diverSettings, diverSettings.cnsCalculationMethod);
}
if (from < 112) await reportProgress();
```

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

`diver_settings_repository.dart` - three mappings (match surrounding style):
- line ~95: `cnsCalculationMethod: Value(s.cnsCalculationMethod.dbValue),`
- line ~232: `cnsCalculationMethod: Value(settings.cnsCalculationMethod.dbValue),`
- line ~412: `cnsCalculationMethod: CnsCalculationMethod.fromDbValue(row.cnsCalculationMethod),`

`settings_providers.dart`:
- AppSettings: field `final CnsCalculationMethod cnsCalculationMethod;` (doc: "Algorithm used for calculated CNS%; see docs/plans/2026-07-16-cns-calculation-method-setting-design.md"), constructor default `this.cnsCalculationMethod = CnsCalculationMethod.shearwater`, copyWith param + assignment.
- SettingsNotifier, next to `setDefaultCnsSource`:

```dart
Future<void> setCnsCalculationMethod(CnsCalculationMethod value) async {
  state = state.copyWith(cnsCalculationMethod: value);
  await _saveSettings();
}
```

- Convenience provider next to `cnsWarningThresholdProvider`:

```dart
final cnsCalculationMethodProvider = Provider<CnsCalculationMethod>((ref) {
  return ref.watch(settingsProvider.select((s) => s.cnsCalculationMethod));
});
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/settings/`
Expected: PASS, including pre-existing tests (the new column has a default so existing rows and fixtures are unaffected). Also run `flutter test test/core/services/sync/` - diver settings sync serializes rows generically; confirm nothing asserts an exhaustive column list. If a sync test fails on the new column, add it to the serializer the same way `defaultCnsSource` is handled there.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add -u lib test && git add lib/core/database/database.g.dart
git commit -m "feat(settings): persist CNS calculation method per diver (schema v112)"
```

---

### Task 5: Wire the setting into profile analysis and both planners

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:369,605,685` (the three `ProfileAnalysisService(` constructions)
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (PlanEngineConfig fields ~21-58; `O2ToxicityCalculator(` ~114)
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart:17-24`
- Modify: `lib/features/dive_planner/data/services/plan_calculator_service.dart:36-51,90`
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart:26-40`
- Test: existing suites (behavior covered by Tasks 2-4; this task is wiring only)

**Interfaces:**
- Consumes: `cnsCalculationMethodProvider` (Task 4), `ProfileAnalysisService.cnsCalculationMethod` (Task 2).
- Produces: `PlanEngineConfig.cnsMethod` and `PlanCalculatorService.cnsMethod` fields (both default `CnsCalculationMethod.shearwater`).

- [ ] **Step 1: Wire profile analysis**

At each of the three `ProfileAnalysisService(` sites in `profile_analysis_provider.dart` add:

```dart
cnsCalculationMethod: ref.watch(cnsCalculationMethodProvider),
```

- [ ] **Step 2: Wire planner (PlanEngine)**

`plan_engine.dart`: add to `PlanEngineConfig` a field `final CnsCalculationMethod cnsMethod;` with constructor default `this.cnsMethod = CnsCalculationMethod.shearwater`; pass `cnsMethod: config.cnsMethod` in the `O2ToxicityCalculator(` construction (~line 114). Add import.

`plan_canvas_providers.dart` inside `planEngineConfigProvider`:

```dart
cnsMethod: ref.watch(cnsCalculationMethodProvider),
```

- [ ] **Step 3: Wire dive_planner (PlanCalculatorService)**

`plan_calculator_service.dart`: add field `final CnsCalculationMethod cnsMethod;`, constructor param `this.cnsMethod = CnsCalculationMethod.shearwater`, pass `cnsMethod: cnsMethod` to the `O2ToxicityCalculator(` at ~line 90. Add import.

`dive_planner_providers.dart` in `planCalculatorServiceProvider`, alongside the other watches:

```dart
cnsMethod: ref.watch(cnsCalculationMethodProvider),
```

- [ ] **Step 4: Verify**

Run: `flutter analyze && flutter test test/features/planner/ test/features/dive_planner/ test/features/dive_log/`
Expected: analyzer clean; suites PASS (defaults unchanged relative to Task 2).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/
git add -u lib
git commit -m "feat: respect CNS method setting in profile analysis and planners"
```

---

### Task 6: Settings UI (Decompression section) + English strings

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Decompression section, after the GF Card ~line 894; new methods near `_showGradientFactorPicker` ~line 1070)
- Modify: `lib/l10n/arb/app_en.arb` (new keys next to the `settings_decompression_*` block ~line 6930)
- Test: `test/features/settings/presentation/pages/cns_method_picker_test.dart` (create)

**Interfaces:**
- Consumes: `settingsProvider`, `setCnsCalculationMethod` (Task 4).
- Produces: settings tile "CNS calculation" opening `_showCnsMethodPicker` dialog.

- [ ] **Step 1: Add English l10n keys** to `app_en.arb` (with `@` descriptions following the file's convention):

```json
"settings_decompression_cnsMethodTitle": "CNS calculation",
"settings_decompression_cnsMethodClassic": "NOAA table, stepped (classic)",
"settings_decompression_cnsMethodClassicDesc": "Charges each 0.1 bar band at its harsher edge. Submersion's original method.",
"settings_decompression_cnsMethodShearwater": "Linear interpolation (Shearwater-style)",
"settings_decompression_cnsMethodShearwaterDesc": "Interpolates between the NOAA limits as documented by Shearwater. Matches most dive computers.",
"settings_decompression_cnsMethodSubsurface": "Exponential fit (as Subsurface)",
"settings_decompression_cnsMethodSubsurfaceDesc": "Smooth curve fit to the NOAA table. Matches Subsurface's calculated CNS.",
"settings_decompression_cnsMethodAboutTitle": "About these methods",
"settings_decompression_cnsMethodAboutBody": "All three methods are built on the oxygen exposure limits of the NOAA Diving Manual (300 minutes at a ppO2 of 1.0 bar, 45 minutes at 1.6 bar). The table only defines limits in 0.1 bar steps: the classic method charges everything in a band at the band's harsher edge, which systematically overstates exposure between entries. Shearwater's dive computers document interpolating linearly between the NOAA limits, with a fixed 15% per minute above 1.65 bar. Subsurface replaced its table lookup in 2019 with a smooth two-line exponential fit to the same NOAA data (Robert C. Helling), which also extends naturally beyond 1.6 bar. Between table entries the two smooth methods agree within about one CNS point; the classic method reads higher.",
"settings_decompression_cnsMethodDisclaimer": "Names refer to the published methods of the respective projects and manufacturers; no affiliation or endorsement is implied. Computed values may differ from actual dive computer readings."
```

Run `flutter gen-l10n` - expect it to complete; missing-translation warnings for the other 10 locales are resolved in Task 7.

Note: gen-l10n requires key parity only if configured; regardless, Task 7 restores full parity before the final commit of this PR.

- [ ] **Step 2: Write the widget test**

```dart
// cns_method_picker_test.dart - mirror the harness (pumpWidget with
// ProviderScope + MaterialApp + localizations delegates) used by existing
// tests under test/features/settings/presentation/.
testWidgets('picker lists three methods and applies selection',
    (tester) async {
  // pump the settings page, scroll to and tap the "CNS calculation" tile
  // expect three radio options by their l10n labels
  // tap "Exponential fit (as Subsurface)"
  // expect(container.read(settingsProvider).cnsCalculationMethod,
  //     CnsCalculationMethod.subsurface);
});
```

Write it fully against the sibling harness (the commented skeleton above defines the required assertions; the pump/scroll mechanics follow the neighboring settings widget tests).

- [ ] **Step 3: Implement the tile and dialog** in `settings_page.dart`.

Tile (after the GF Card in the Decompression section):

```dart
const SizedBox(height: 8),
Card(
  child: ListTile(
    leading: const Icon(Icons.percent),
    title: Text(context.l10n.settings_decompression_cnsMethodTitle),
    subtitle: Text(_cnsMethodLabel(context, settings.cnsCalculationMethod)),
    trailing: const Icon(Icons.edit),
    onTap: () => _showCnsMethodPicker(context, ref, settings),
  ),
),
```

Helpers (near `_showGradientFactorPicker`):

```dart
String _cnsMethodLabel(BuildContext context, CnsCalculationMethod method) {
  switch (method) {
    case CnsCalculationMethod.classic:
      return context.l10n.settings_decompression_cnsMethodClassic;
    case CnsCalculationMethod.shearwater:
      return context.l10n.settings_decompression_cnsMethodShearwater;
    case CnsCalculationMethod.subsurface:
      return context.l10n.settings_decompression_cnsMethodSubsurface;
  }
}

String _cnsMethodDescription(BuildContext context, CnsCalculationMethod method) {
  switch (method) {
    case CnsCalculationMethod.classic:
      return context.l10n.settings_decompression_cnsMethodClassicDesc;
    case CnsCalculationMethod.shearwater:
      return context.l10n.settings_decompression_cnsMethodShearwaterDesc;
    case CnsCalculationMethod.subsurface:
      return context.l10n.settings_decompression_cnsMethodSubsurfaceDesc;
  }
}

void _showCnsMethodPicker(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.settings_decompression_cnsMethodTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final method in CnsCalculationMethod.values)
              ListTile(
                title: Text(_cnsMethodLabel(context, method)),
                subtitle: Text(_cnsMethodDescription(context, method)),
                trailing: settings.cnsCalculationMethod == method
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setCnsCalculationMethod(method);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ExpansionTile(
              title: Text(
                context.l10n.settings_decompression_cnsMethodAboutTitle,
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Text(context.l10n.settings_decompression_cnsMethodAboutBody),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.settings_decompression_cnsMethodDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
```

Match the dialog conventions used by the unit-picker dialogs in this file (dialogContext usage, no action buttons needed since taps apply immediately).

- [ ] **Step 4: Run the widget test and format**

Run: `flutter test test/features/settings/presentation/pages/cns_method_picker_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/
git add -u lib test && git add lib/l10n test/features/settings/presentation/pages/cns_method_picker_test.dart
git commit -m "feat(settings): CNS calculation method picker with method provenance"
```

---

### Task 7: Translations for the other 10 locales

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`

- [ ] **Step 1: Add all 10 keys to every locale.** Translate naturally per language; keep "NOAA", "Shearwater", "Subsurface", "CNS", "ppO2" and all numbers untranslated. German reference (write the other locales to the same standard):

```json
"settings_decompression_cnsMethodTitle": "CNS-Berechnung",
"settings_decompression_cnsMethodClassic": "NOAA-Tabelle, gestuft (klassisch)",
"settings_decompression_cnsMethodClassicDesc": "Berechnet jedes 0,1-bar-Band mit dem strengeren Rand. Submersions urspruengliche Methode.",
"settings_decompression_cnsMethodShearwater": "Lineare Interpolation (Shearwater-Stil)",
"settings_decompression_cnsMethodShearwaterDesc": "Interpoliert zwischen den NOAA-Grenzwerten, wie von Shearwater dokumentiert. Entspricht den meisten Tauchcomputern.",
"settings_decompression_cnsMethodSubsurface": "Exponentieller Fit (wie Subsurface)",
"settings_decompression_cnsMethodSubsurfaceDesc": "Glatte Kurvenanpassung an die NOAA-Tabelle. Entspricht dem berechneten CNS von Subsurface.",
"settings_decompression_cnsMethodAboutTitle": "Ueber diese Methoden",
"settings_decompression_cnsMethodAboutBody": "<full translation of the English body>",
"settings_decompression_cnsMethodDisclaimer": "<full translation of the English disclaimer>"
```

(Use proper umlauts in the actual German file - the repo's arb files are UTF-8; the transliterations above are only an artifact of this plan document.)

- [ ] **Step 2: Verify parity and codegen**

Run: `flutter gen-l10n` then re-run the parity check:

```bash
python -c "
import json,glob
en=json.load(open('lib/l10n/arb/app_en.arb',encoding='utf-8'))
enk={k for k in en if not k.startswith('@')}
for f in sorted(glob.glob('lib/l10n/arb/app_*.arb')):
    d=json.load(open(f,encoding='utf-8'))
    missing=len(enk-{x for x in d if not x.startswith('@')})
    print(f, missing)
"
```

Expected: `0` missing for every file.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "i18n: translate CNS method setting strings"
```

---

### Task 8: Full verification, docs, PR update

**Files:**
- Modify: `docs/plans/2026-07-16-cns-calculation-method-setting-design.md` (status line only)

- [ ] **Step 1: Full gate**

```bash
dart format lib/ test/   # expect: no changes
flutter analyze          # expect: no issues
flutter test             # expect: all pass
```

- [ ] **Step 2: Update design doc status and changelog.** Set the design doc status line to `Status: implemented on this branch (PR #599)`. In `CHANGELOG.md`, under the current unreleased/top section following the file's category style, add a Features entry:

```markdown
- configurable CNS calculation method: NOAA stepped table (classic),
  Shearwater-style linear interpolation (new default), or Subsurface-style
  exponential fit (#578). Calculated CNS values decrease slightly under the
  new default; select "classic" in Settings > Decompression to reproduce
  previous values.
```

```bash
git add docs/plans/2026-07-16-cns-calculation-method-setting-design.md CHANGELOG.md
git commit -m "docs: mark CNS method design as implemented, changelog entry"
```

- [ ] **Step 3: Push and update PR #599**

```bash
git push --no-verify
gh pr edit 599 --repo submersion-app/submersion --title "feat: configurable CNS calculation method (NOAA / Shearwater-style / Subsurface-style)"
```

Update the PR body: keep the design summary, add an "Implementation" section (methods, new default, schema v112, settings UI, fixture cross-validation results with the actual numbers from Task 3's test output). Keep the PR as draft. No attribution lines.
