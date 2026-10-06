# Tide Prediction Accuracy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the five math bugs that make tide predictions wildly wrong, replace placeholder site data with a NOAA CO-OPS station refinement layer, and surface data provenance in the tide UI.

**Architecture:** Five in-place fixes to the pure-Dart harmonic engine (`lib/core/tide/`), validated by golden tests against NOAA published predictions. A new `TideConstituentResolver` picks constituents in priority order (cached NOAA station within 25 km, then FES2022 grid) and reports provenance; station constituents are fetched once from the free NOAA API and cached in the local cache database (never synced). The UI gains a source badge and hides tides for freshwater sites.

**Tech Stack:** Flutter/Dart, Drift (local cache DB `submersion_local.db`), Riverpod, `package:http` with `MockClient` tests, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-08-09-tide-accuracy-design.md` (root causes, decisions, validation evidence).

## Global Constraints

- Work happens on branch `worktree-tide-accuracy` in this worktree; commit after each task (commits are preauthorized; no `Co-Authored-By` line, no session URL).
- All Dart code must pass `dart format .` with no changes; no emojis in code or comments.
- `flutter analyze` must be clean for the whole project (infos are treated as fatal in CI).
- Any new localized string must be added to ALL 11 ARB files (`en, ar, de, es, fr, he, hu, it, nl, pt, zh`) — `test/l10n/arb_parity_test.dart` fails otherwise — then run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart`.
- Tide heights are meters internally; anything displayed respects the diver's unit settings (`settingsProvider` → `DepthUnit`, `UnitFormatter.formatGeoDistance` for distances).
- New third-party cached data goes in `lib/core/database/local_cache_database.dart` (own schema ladder, currently v8), NOT the main synced DB.
- Run tests with a generous timeout (`flutter test` on this repo takes several minutes; never use a short Bash timeout).
- The Python reference implementation that validated all formulas is described in the spec; expected numeric results in this plan were verified against NOAA published predictions on 2026-08-09.

---

### Task 1: Fix the astronomy (Julian date half-day bug, solar longitude coefficients)

**Files:**
- Modify: `lib/core/tide/astronomical_arguments.dart` (lines 85 and 341-365)
- Test: `test/core/tide/tide_calculator_test.dart` (extend `AstronomicalArguments` group)

**Interfaces:**
- Produces: `AstronomicalArguments.forDateTime(DateTime)` with correct `T`, `s`, `h`, `p`, `n`, `ps` (all degrees, UTC-based). Signature unchanged; later tasks rely on correct values only.

- [ ] **Step 1: Write the failing tests**

Add to the `AstronomicalArguments` group in `test/core/tide/tide_calculator_test.dart`:

```dart
test('T is exactly zero at the J2000.0 epoch (noon Jan 1 2000)', () {
  // The old Julian date code was +0.5 day off; 0.5/36525 = 1.37e-5 passed
  // the old 0.001 tolerance. 1e-7 catches the half-day error.
  final args = AstronomicalArguments.forDateTime(
    DateTime.utc(2000, 1, 1, 12, 0, 0),
  );
  expect(args.T, closeTo(0.0, 1e-7));
});

test('lunar mean longitude matches Meeus worked example 47.a', () {
  // Meeus, Astronomical Algorithms: 1992 April 12.0 TD, L' = 134.290182 deg.
  // TD-UT difference (~59 s) moves the Moon ~0.009 deg; tolerance 0.02.
  final args = AstronomicalArguments.forDateTime(DateTime.utc(1992, 4, 12));
  expect(args.s, closeTo(134.290182, 0.02));
});

test('solar mean longitude matches Meeus worked example 25.a', () {
  // Meeus: 1992 October 13.0 TD, L0 = 201.80720 deg. Catches the
  // millennia-vs-century coefficient bug (h advanced 10x too fast).
  final args = AstronomicalArguments.forDateTime(DateTime.utc(1992, 10, 13));
  expect(args.h, closeTo(201.80720, 0.01));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/tide/tide_calculator_test.dart`
Expected: the three new tests FAIL (old `h` is wildly off; `T` off by 1.37e-5; `s` off by ~0.27 deg from the half-day error).

- [ ] **Step 3: Fix the two formulas**

In `lib/core/tide/astronomical_arguments.dart`:

Replace the solar mean longitude (line ~85):

```dart
    // Mean longitude of the Sun (h)
    // Meeus 25.2 with T in Julian centuries. (A previous version used the
    // Julian-millennia coefficients with a century argument, advancing the
    // Sun 10x too fast.)
    final h = _normalize(280.46646 + 36000.76983 * T + 0.0003032 * T * T);
```

In `_toJulianDate`, change the trailing constant (line ~358-364):

```dart
    // Gregorian calendar. The integer day-count formula yields the
    // noon-based Julian Day Number; subtract the extra half day so a
    // midnight input produces the true midnight Julian Date.
    return d +
        ((153 * m2 + 2) / 5).floor() +
        365 * y2 +
        (y2 / 4).floor() -
        (y2 / 100).floor() +
        (y2 / 400).floor() -
        32045.5;
```

Also tighten the existing test `calculates arguments for J2000 epoch` from `closeTo(0.0, 0.001)` to `closeTo(0.0, 1e-7)` and change its input from `DateTime.utc(2000, 1, 1, 12, 0, 0)` comment accordingly (input already noon; only tolerance changes).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/tide/tide_calculator_test.dart`
Expected: the three new tests PASS. Existing calculator tests still pass (they are property-based and insensitive to phase).

- [ ] **Step 5: Commit**

```bash
git add lib/core/tide/astronomical_arguments.dart test/core/tide/tide_calculator_test.dart
git commit -m "Fix Julian date half-day offset and solar longitude coefficients"
```

---

### Task 2: Fix the constituent tables and add Doodson phase constants

**Files:**
- Modify: `lib/core/tide/constants/harmonic_constituents.dart`
- Modify: `lib/core/tide/astronomical_arguments.dart` (`equilibriumPhase`)
- Test: `test/core/tide/tide_calculator_test.dart` (extend `HarmonicConstituents` group)

**Interfaces:**
- Produces: `const Map<String, double> doodsonPhaseConstants` in `harmonic_constituents.dart` (degrees; absent key means 0). `AstronomicalArguments.equilibriumPhase(String constituent)` now includes the constant. Task 3 relies on both.

- [ ] **Step 1: Write the failing table-consistency test**

This one test enforces the entire Doodson table against the published speeds (the angular speed IS the time-derivative of the Doodson sum, so any wrong integer or wrong speed shows up):

```dart
test('every Doodson entry differentiates to its published speed', () {
  // d(V0)/dt must equal the constituent's angular speed. Computed
  // numerically over one hour (06:00->07:00 UTC avoids the hour-of-day
  // wrap at midnight). Catches wrong Doodson integers and wrong speeds.
  final t1 = DateTime.utc(2026, 3, 10, 6, 0, 0);
  final t2 = DateTime.utc(2026, 3, 10, 7, 0, 0);
  final a1 = AstronomicalArguments.forDateTime(t1);
  final a2 = AstronomicalArguments.forDateTime(t2);

  double v0(AstronomicalArguments a, List<int> d) {
    final tau = a.hourOfDay * 15.0 + a.h - a.s;
    return d[0] * tau +
        d[1] * a.s +
        d[2] * a.h +
        d[3] * a.p +
        d[4] * (-a.n) +
        d[5] * a.ps;
  }

  for (final entry in doodsonNumbers.entries) {
    final speed = constituentSpeeds[entry.key];
    expect(speed, isNotNull, reason: 'missing speed for ${entry.key}');
    var rate = v0(a2, entry.value) - v0(a1, entry.value);
    rate = rate % 360.0;
    if (rate > 180.0) rate -= 360.0;
    expect(
      rate,
      closeTo(speed!, 0.001),
      reason: 'Doodson numbers for ${entry.key} disagree with its speed',
    );
  }
});

test('phase constants exist for every diurnal plus L2 and R2', () {
  const minusNinety = ['O1', 'Q1', '2Q1', 'Rho1', 'Sig1', 'P1', 'Pi1'];
  const plusNinety = ['K1', 'J1', 'OO1', 'The1', 'Chi1', 'Phi1', 'M1'];
  for (final name in minusNinety) {
    expect(doodsonPhaseConstants[name], -90.0, reason: name);
  }
  for (final name in plusNinety) {
    expect(doodsonPhaseConstants[name], 90.0, reason: name);
  }
  expect(doodsonPhaseConstants['L2'], 180.0);
  expect(doodsonPhaseConstants['R2'], 180.0);
  expect(doodsonPhaseConstants.containsKey('M2'), false);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/tide/tide_calculator_test.dart`
Expected: FAIL — `doodsonPhaseConstants` undefined (compile error) and, once defined, the rate test fails for `The1`, `M1`, and `Mtm`.

- [ ] **Step 3: Fix the tables**

In `lib/core/tide/constants/harmonic_constituents.dart`:

1. Fix `Mtm` speed (it is 3s - p, not the previous value):

```dart
  'Mtm': 1.6424078,
```

2. Fix the two wrong Doodson entries:

```dart
  'M1': [1, 0, 0, 1, 0, 0],
```

```dart
  'The1': [1, 2, -2, 1, 0, 0],
```

(`J1` keeps `[1, 2, 0, -1, 0, 0]` — that entry was correct; `The1` had accidentally duplicated it.)

3. Add the phase-constant map (after `doodsonNumbers`):

```dart
/// Additive phase constants (degrees) completing the equilibrium argument.
///
/// The six Doodson integers define V0 only up to a per-constituent constant
/// (Schureman's tables). In this codebase's convention (tau = 15t + h - s,
/// solar time from midnight) the O1-group diurnals carry -90 degrees, the
/// K1-group diurnals +90 degrees, and L2/R2 +180 degrees. Constituents not
/// listed have a zero constant.
const Map<String, double> doodsonPhaseConstants = {
  'O1': -90.0,
  'Q1': -90.0,
  '2Q1': -90.0,
  'Rho1': -90.0,
  'Sig1': -90.0,
  'P1': -90.0,
  'Pi1': -90.0,
  'K1': 90.0,
  'J1': 90.0,
  'OO1': 90.0,
  'The1': 90.0,
  'Chi1': 90.0,
  'Phi1': 90.0,
  'M1': 90.0,
  'L2': 180.0,
  'R2': 180.0,
};
```

4. In `astronomical_arguments.dart`, `equilibriumPhase`, add the constant to `v0` (after the Doodson sum, before adding `u`):

```dart
    final v0 =
        doodson[0] * tau +
        doodson[1] * s +
        doodson[2] * h +
        doodson[3] * p +
        doodson[4] * (-n) + // Note: Doodson uses N' = -N
        doodson[5] * ps +
        (doodsonPhaseConstants[constituent] ?? 0.0);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/tide/tide_calculator_test.dart`
Expected: PASS, including the rate test for all 34 constituents.

- [ ] **Step 5: Commit**

```bash
git add lib/core/tide/constants/harmonic_constituents.dart lib/core/tide/astronomical_arguments.dart test/core/tide/tide_calculator_test.dart
git commit -m "Fix Doodson table entries and add equilibrium phase constants"
```

---

### Task 3: Fix the double-counted phase and pin the engine with golden NOAA tests

**Files:**
- Modify: `lib/core/tide/tide_calculator.dart` (lines 61-91)
- Create: `test/core/tide/fixtures/noaa_station_9414290.json`
- Create: `test/core/tide/fixtures/noaa_station_8443970.json`
- Create: `test/core/tide/fixtures/noaa_station_8729840.json`
- Create: `test/core/tide/tide_golden_test.dart`

**Interfaces:**
- Consumes: corrected `equilibriumPhase` from Tasks 1-2.
- Produces: `TideCalculator.calculateHeight` computing `phase = V(t) + u - g`. `TideCalculator({required constituents, double z0 = 0.0})` unchanged — Task 8's resolver passes `z0` for station data.

- [ ] **Step 1: Write the M2 frequency regression test**

Create `test/core/tide/tide_golden_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/tide/tide.dart';

void main() {
  group('M2 frequency regression', () {
    test('M2-only prediction has the true M2 period of 12.4206 hours', () {
      // The pre-fix engine double-counted the time evolution and cycled
      // M2 at ~6.1 hours. Average the high-to-high spacing over 10 days.
      final calculator = TideCalculator(
        constituents: {
          'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
        },
      );
      final extremes = calculator.findExtremes(
        start: DateTime.utc(2026, 6, 1),
        end: DateTime.utc(2026, 6, 11),
      );
      final highs = extremes
          .where((e) => e.type == TideExtremeType.high)
          .toList();
      expect(highs.length, greaterThan(15));
      final spanMinutes = highs.last.time
          .difference(highs.first.time)
          .inSeconds /
          60.0;
      final periodMinutes = spanMinutes / (highs.length - 1);
      expect(periodMinutes, closeTo(12.4206 * 60, 1.0));
    });
  });

  group('Golden reference: NOAA published predictions', () {
    // Fixtures fetched 2026-08-09 from NOAA CO-OPS (harcon + datums +
    // hilo predictions). Constituents in, published extremes out: any
    // error in astronomy, tables, or phase math fails these.
    const stations = [
      'noaa_station_9414290', // San Francisco, mixed
      'noaa_station_8443970', // Boston, semi-diurnal
      'noaa_station_8729840', // Pensacola, diurnal
    ];

    for (final fixtureName in stations) {
      test('$fixtureName extremes within 20 min / 0.15 m of NOAA', () {
        final fixture =
            json.decode(
                  File(
                    'test/core/tide/fixtures/$fixtureName.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        final constituents = <String, TideConstituent>{};
        (fixture['constituents'] as Map<String, dynamic>).forEach((name, c) {
          constituents[name] = TideConstituent(
            name: name,
            amplitude: (c['amplitude'] as num).toDouble(),
            phase: (c['phase'] as num).toDouble(),
          );
        });
        final calculator = TideCalculator(
          constituents: constituents,
          z0: (fixture['z0MetersAboveMllw'] as num).toDouble(),
        );

        final expected = (fixture['expectedExtremes'] as List)
            .cast<Map<String, dynamic>>();

        // Compute extremes over each fixture window (two 2-day windows).
        final windows = [
          (DateTime.utc(2026, 9, 14, 21), DateTime.utc(2026, 9, 17, 3)),
          (DateTime.utc(2027, 6, 14, 21), DateTime.utc(2027, 6, 17, 3)),
        ];
        final ours = <TideExtreme>[];
        for (final (start, end) in windows) {
          ours.addAll(calculator.findExtremes(start: start, end: end));
        }

        for (final e in expected) {
          final time = DateTime.parse(e['time'] as String);
          final type = e['type'] == 'H'
              ? TideExtremeType.high
              : TideExtremeType.low;
          final height = (e['height'] as num).toDouble();

          final match = ours
              .where((o) => o.type == type)
              .reduce(
                (a, b) =>
                    a.time.difference(time).abs() <
                        b.time.difference(time).abs()
                    ? a
                    : b,
              );

          expect(
            match.time.difference(time).abs().inMinutes,
            lessThanOrEqualTo(20),
            reason:
                '${fixture['name']}: $type at $time matched ${match.time}',
          );
          expect(
            match.heightMeters,
            closeTo(height, 0.15),
            reason: '${fixture['name']}: $type height at $time',
          );
        }
      });
    }
  });
}
```

- [ ] **Step 2: Create the three fixture files**

Write each JSON below verbatim (single line is fine) to the listed path.

`test/core/tide/fixtures/noaa_station_9414290.json`:

```json
{"station":"9414290","name":"San Francisco, CA (mixed)","source":"NOAA CO-OPS harcon/datums/predictions APIs, fetched 2026-08-09","z0MetersAboveMllw":0.951,"constituents":{"M2":{"amplitude":0.576,"phase":208.2},"S2":{"amplitude":0.137,"phase":216.2},"N2":{"amplitude":0.122,"phase":183.2},"K1":{"amplitude":0.37,"phase":225.4},"M4":{"amplitude":0.022,"phase":136.8},"O1":{"amplitude":0.23,"phase":208.4},"Nu2":{"amplitude":0.026,"phase":189.9},"Mu2":{"amplitude":0.007,"phase":100.2},"2N2":{"amplitude":0.013,"phase":153.3},"OO1":{"amplitude":0.012,"phase":260.0},"La2":{"amplitude":0.007,"phase":214.3},"M1":{"amplitude":0.011,"phase":237.5},"J1":{"amplitude":0.019,"phase":244.3},"Ssa":{"amplitude":0.03,"phase":272.3},"Sa":{"amplitude":0.044,"phase":200.2},"Mf":{"amplitude":0.015,"phase":153.1},"Rho1":{"amplitude":0.009,"phase":200.0},"Q1":{"amplitude":0.041,"phase":202.4},"T2":{"amplitude":0.009,"phase":204.6},"R2":{"amplitude":0.001,"phase":126.8},"2Q1":{"amplitude":0.006,"phase":208.6},"P1":{"amplitude":0.114,"phase":222.1},"L2":{"amplitude":0.018,"phase":229.6},"K2":{"amplitude":0.04,"phase":206.0},"MS4":{"amplitude":0.01,"phase":149.0}},"expectedExtremes":[{"time":"2026-09-15T03:34:00Z","type":"L","height":0.171},{"time":"2026-09-15T10:19:00Z","type":"H","height":1.386},{"time":"2026-09-15T15:17:00Z","type":"L","height":0.75},{"time":"2026-09-15T21:40:00Z","type":"H","height":1.758},{"time":"2026-09-16T04:23:00Z","type":"L","height":0.194},{"time":"2026-09-16T11:26:00Z","type":"H","height":1.293},{"time":"2026-09-16T15:59:00Z","type":"L","height":0.916},{"time":"2026-09-16T22:16:00Z","type":"H","height":1.703},{"time":"2027-06-15T03:55:00Z","type":"H","height":1.916},{"time":"2027-06-15T10:57:00Z","type":"L","height":-0.108},{"time":"2027-06-15T17:55:00Z","type":"H","height":1.265},{"time":"2027-06-15T22:10:00Z","type":"L","height":0.807},{"time":"2027-06-16T04:35:00Z","type":"H","height":1.929},{"time":"2027-06-16T11:41:00Z","type":"L","height":-0.197},{"time":"2027-06-16T18:53:00Z","type":"H","height":1.333},{"time":"2027-06-16T23:00:00Z","type":"L","height":0.901}]}
```

`test/core/tide/fixtures/noaa_station_8443970.json`:

```json
{"station":"8443970","name":"Boston, MA (semi-diurnal)","source":"NOAA CO-OPS harcon/datums/predictions APIs, fetched 2026-08-09","z0MetersAboveMllw":1.586,"constituents":{"M2":{"amplitude":1.371,"phase":109.2},"S2":{"amplitude":0.208,"phase":146.2},"N2":{"amplitude":0.305,"phase":76.7},"K1":{"amplitude":0.143,"phase":205.6},"M4":{"amplitude":0.023,"phase":29.0},"O1":{"amplitude":0.116,"phase":187.1},"Nu2":{"amplitude":0.066,"phase":84.0},"Mu2":{"amplitude":0.01,"phase":53.3},"2N2":{"amplitude":0.041,"phase":53.7},"OO1":{"amplitude":0.004,"phase":218.7},"La2":{"amplitude":0.02,"phase":140.1},"M1":{"amplitude":0.005,"phase":223.2},"J1":{"amplitude":0.01,"phase":210.0},"Ssa":{"amplitude":0.022,"phase":97.5},"Sa":{"amplitude":0.049,"phase":136.3},"Rho1":{"amplitude":0.005,"phase":179.3},"Q1":{"amplitude":0.019,"phase":172.1},"T2":{"amplitude":0.018,"phase":120.1},"R2":{"amplitude":0.004,"phase":13.1},"2Q1":{"amplitude":0.002,"phase":211.3},"P1":{"amplitude":0.047,"phase":204.8},"L2":{"amplitude":0.068,"phase":160.4},"K2":{"amplitude":0.059,"phase":146.1},"MS4":{"amplitude":0.009,"phase":74.0}},"expectedExtremes":[{"time":"2026-09-15T00:24:00Z","type":"L","height":0.014},{"time":"2026-09-15T06:38:00Z","type":"H","height":2.941},{"time":"2026-09-15T12:39:00Z","type":"L","height":0.267},{"time":"2026-09-15T18:51:00Z","type":"H","height":3.095},{"time":"2026-09-16T01:10:00Z","type":"L","height":0.137},{"time":"2026-09-16T07:24:00Z","type":"H","height":2.78},{"time":"2026-09-16T13:23:00Z","type":"L","height":0.426},{"time":"2026-09-16T19:35:00Z","type":"H","height":2.986},{"time":"2027-06-15T00:42:00Z","type":"H","height":3.143},{"time":"2027-06-15T07:05:00Z","type":"L","height":0.142},{"time":"2027-06-15T13:21:00Z","type":"H","height":2.754},{"time":"2027-06-15T19:14:00Z","type":"L","height":0.375},{"time":"2027-06-16T01:34:00Z","type":"H","height":3.155},{"time":"2027-06-16T08:01:00Z","type":"L","height":0.104},{"time":"2027-06-16T14:16:00Z","type":"H","height":2.737},{"time":"2027-06-16T20:05:00Z","type":"L","height":0.411}]}
```

`test/core/tide/fixtures/noaa_station_8729840.json`:

```json
{"station":"8729840","name":"Pensacola, FL (diurnal)","source":"NOAA CO-OPS harcon/datums/predictions APIs, fetched 2026-08-09","z0MetersAboveMllw":0.188,"constituents":{"M2":{"amplitude":0.017,"phase":172.1},"S2":{"amplitude":0.005,"phase":175.9},"N2":{"amplitude":0.003,"phase":195.9},"K1":{"amplitude":0.125,"phase":58.2},"M4":{"amplitude":0.002,"phase":320.0},"O1":{"amplitude":0.122,"phase":47.9},"Nu2":{"amplitude":0.001,"phase":173.1},"Mu2":{"amplitude":0.001,"phase":300.2},"OO1":{"amplitude":0.011,"phase":34.8},"La2":{"amplitude":0.001,"phase":153.8},"M1":{"amplitude":0.005,"phase":96.4},"J1":{"amplitude":0.005,"phase":89.8},"Ssa":{"amplitude":0.054,"phase":49.1},"Sa":{"amplitude":0.113,"phase":150.4},"Rho1":{"amplitude":0.005,"phase":33.3},"Q1":{"amplitude":0.026,"phase":37.9},"T2":{"amplitude":0.001,"phase":131.5},"R2":{"amplitude":0.001,"phase":314.1},"2Q1":{"amplitude":0.002,"phase":33.1},"P1":{"amplitude":0.037,"phase":63.8},"L2":{"amplitude":0.001,"phase":163.9},"K2":{"amplitude":0.006,"phase":186.2},"MS4":{"amplitude":0.001,"phase":324.3}},"expectedExtremes":[{"time":"2026-09-15T06:39:00Z","type":"H","height":0.498},{"time":"2026-09-15T17:32:00Z","type":"L","height":0.151},{"time":"2026-09-16T07:15:00Z","type":"H","height":0.517},{"time":"2026-09-16T18:51:00Z","type":"L","height":0.144},{"time":"2027-06-15T00:08:00Z","type":"L","height":0.004},{"time":"2027-06-15T13:46:00Z","type":"H","height":0.453},{"time":"2027-06-16T00:59:00Z","type":"L","height":-0.028},{"time":"2027-06-16T14:24:00Z","type":"H","height":0.473}]}
```

- [ ] **Step 3: Run the new tests to verify they fail**

Run: `flutter test test/core/tide/tide_golden_test.dart`
Expected: FAIL — the M2 period comes out near 6.1 hours (double-counted phase) and golden extremes are hours off.

- [ ] **Step 4: Fix `calculateHeight`**

In `lib/core/tide/tide_calculator.dart`, replace the loop body of `calculateHeight` (keep the `speed == null` skip — it filters constituents we have no tables for):

```dart
  double calculateHeight(DateTime time) {
    final astro = AstronomicalArguments.forDateTime(time);

    double height = z0;

    for (final entry in constituents.entries) {
      final name = entry.key;
      final constituent = entry.value;

      // Skip constituents without astronomical tables.
      final speed = constituentSpeeds[name];
      if (speed == null) continue;

      // Nodal modulation (amplitude and phase corrections)
      final f = astro.nodalFactor(name);
      final equilibriumPhase = astro.equilibriumPhase(name);

      // Total phase angle in degrees: V(t) + u - g. The equilibrium
      // argument evaluated at time t already carries the full time
      // evolution; adding a separate omega*t term double-counts it.
      final phase = equilibriumPhase - constituent.phase;

      final phaseRad = degreesToRadians(phase);
      height += f * constituent.amplitude * math.cos(phaseRad);
    }

    return height;
  }
```

Also remove the now-unused line `final hoursFromEpoch = ...` and its import usage if the analyzer flags it. `hoursFromReferenceEpoch` stays in `AstronomicalArguments` (still exercised by an existing test).

Update the class doc comment formula at the top of the file to:

```
/// h(t) = Z0 + sum over n of: f_n x H_n x cos(V_n(t) + u_n - g_n)
```

- [ ] **Step 5: Run all tide tests to verify they pass**

Run: `flutter test test/core/tide/`
Expected: PASS — including all three golden stations at 20 min / 0.15 m (validated headroom: worst observed 15.6 min / 0.071 m).

- [ ] **Step 6: Commit**

```bash
git add lib/core/tide/tide_calculator.dart test/core/tide/tide_golden_test.dart test/core/tide/fixtures/
git commit -m "Fix double-counted tide phase and add NOAA golden reference tests"
```

---

### Task 4: Remove placeholder sample-site data and its APIs

**Files:**
- Delete: `assets/data/tide/constituents_sites.json`
- Modify: `lib/features/tides/data/services/tide_data_service.dart`
- Modify: `lib/features/tides/presentation/providers/tide_providers.dart` (remove `tideSiteIdsProvider`)

**Interfaces:**
- Produces: `TideDataService` keeps ONLY `initialize()`, `getCalculatorForLocation(lat, lon)` (grid path only), `hasTideData(lat, lon)`, `getMetadata()`, and the private grid helpers. Task 8's resolver consumes `getCalculatorForLocation`.

- [ ] **Step 1: Confirm nothing else references the site APIs**

Run: `grep -rn "getCalculatorForSiteId\|getAvailableSiteIds\|getSiteInfo\|tideSiteIdsProvider\|TideSiteInfo\|constituents_sites" lib/ test/`
Expected: hits only in `tide_data_service.dart` and `tide_providers.dart`. If anything else appears, update those call sites in this task too.

- [ ] **Step 2: Delete the asset and the code paths**

```bash
git rm assets/data/tide/constituents_sites.json
```

In `tide_data_service.dart`:
- Remove `_siteData`, `_coordinateTolerance`, `_findSiteConstituents`, `getCalculatorForSiteId`, `getAvailableSiteIds`, `getSiteInfo`, and the `TideSiteInfo` class.
- `initialize()` now loads only `metadata.json`:

```dart
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final metadataStr = await rootBundle.loadString(
        'assets/data/tide/metadata.json',
      );
      _metadata = await compute(_parseJsonInIsolate, metadataStr);
      _initialized = true;
    } catch (e) {
      // Allow initialization to succeed even if files missing
      _initialized = true;
      _metadata = {};
    }
  }
```

- `getCalculatorForLocation` drops the site branch and goes straight to grid interpolation.
- `hasTideData` drops the site check.

In `tide_providers.dart`, delete `tideSiteIdsProvider`.

- [ ] **Step 3: Analyze and run tide tests**

Run: `flutter analyze lib/features/tides lib/core/tide && flutter test test/core/tide/ test/features/tides/`
Expected: no errors; all tests pass (nothing tested the deleted APIs).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove placeholder tide sample-site data and site-ID APIs"
```

---

### Task 5: Local cache DB v9 — NOAA station table and repository

**Files:**
- Modify: `lib/core/database/local_cache_database.dart`
- Create: `lib/features/tides/data/repositories/noaa_station_cache_repository.dart`
- Test: `test/features/tides/data/noaa_station_cache_repository_test.dart`

**Interfaces:**
- Produces:
  - Drift table `NoaaTideStations` in `LocalCacheDatabase` (schema v9).
  - `enum NoaaStationCacheStatus { ok, unavailable }`
  - `class CachedNoaaStation { String stationId; String name; double latitude; double longitude; Map<String, TideConstituent> constituents; double? datumOffsetMllw; NoaaStationCacheStatus status; DateTime fetchedAt; }`
  - `class NoaaStationCacheRepository { NoaaStationCacheRepository(LocalCacheDatabase db, {DateTime Function()? now}); Future<CachedNoaaStation?> read(String stationId); Future<void> write({required String stationId, required String name, required double latitude, required double longitude, required Map<String, TideConstituent> constituents, double? datumOffsetMllw, required NoaaStationCacheStatus status}); }`
  - `read` applies no TTL itself; it returns the row with `fetchedAt` and the resolver applies policy (Task 8).

- [ ] **Step 1: Add the table and migration**

In `lib/core/database/local_cache_database.dart` add after `ReefDataCache`:

```dart
/// Cached NOAA CO-OPS harmonic station constituents. Re-derivable
/// third-party data: never synced, never backed up. status semantics:
/// 'ok' = usable constituents in constituentsJson; 'unavailable' = the
/// station deterministically has no harmonic data. Transient fetch
/// failures write NO row.
class NoaaTideStations extends Table {
  TextColumn get stationId => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// JSON object: {"M2": {"amplitude": 0.576, "phase": 208.2}, ...}
  TextColumn get constituentsJson => text().withDefault(const Constant('{}'))();

  /// MSL minus MLLW in meters (station datum offset); null when the
  /// station's datums were unavailable (heights then reference MSL).
  RealColumn get datumOffsetMllw => real().nullable()();
  TextColumn get status => text()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {stationId};
}
```

Register `NoaaTideStations` in the `@DriftDatabase(tables: [...])` list, bump `schemaVersion` to `9`, and add to `onUpgrade`:

```dart
      // v9: NOAA tide station constituent cache.
      if (from < 9) {
        await m.createTable(noaaTideStations);
      }
```

Add to `beforeOpen` (ladder-collision self-heal, mirroring the existing pattern — keep column shapes in sync with the table):

```dart
      await customStatement('''
        CREATE TABLE IF NOT EXISTS noaa_tide_stations (
          station_id TEXT NOT NULL,
          name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          constituents_json TEXT NOT NULL DEFAULT '{}',
          datum_offset_mllw REAL NULL,
          status TEXT NOT NULL,
          fetched_at INTEGER NOT NULL,
          PRIMARY KEY (station_id)
        )
      ''');
```

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Write the failing repository test**

Create `test/features/tides/data/noaa_station_cache_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late NoaaStationCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = NoaaStationCacheRepository(
      db,
      now: () => DateTime.utc(2026, 8, 9, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('read returns null for unknown station', () async {
    expect(await repo.read('0000000'), isNull);
  });

  test('ok roundtrip preserves constituents and datum offset', () async {
    await repo.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.806,
      longitude: -122.466,
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 0.576, phase: 208.2),
      },
      datumOffsetMllw: 0.951,
      status: NoaaStationCacheStatus.ok,
    );

    final cached = await repo.read('9414290');
    expect(cached, isNotNull);
    expect(cached!.status, NoaaStationCacheStatus.ok);
    expect(cached.constituents['M2']!.amplitude, 0.576);
    expect(cached.constituents['M2']!.phase, 208.2);
    expect(cached.datumOffsetMllw, 0.951);
    expect(cached.fetchedAt, DateTime.utc(2026, 8, 9, 12));
  });

  test('unavailable roundtrip has empty constituents', () async {
    await repo.write(
      stationId: '1111111',
      name: 'No Harmonics',
      latitude: 0,
      longitude: 0,
      status: NoaaStationCacheStatus.unavailable,
      constituents: const {},
    );

    final cached = await repo.read('1111111');
    expect(cached!.status, NoaaStationCacheStatus.unavailable);
    expect(cached.constituents, isEmpty);
    expect(cached.datumOffsetMllw, isNull);
  });

  test('write replaces an existing row', () async {
    await repo.write(
      stationId: '9414290',
      name: 'SF',
      latitude: 1,
      longitude: 2,
      constituents: const {},
      status: NoaaStationCacheStatus.unavailable,
    );
    await repo.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.806,
      longitude: -122.466,
      constituents: {
        'K1': const TideConstituent(name: 'K1', amplitude: 0.37, phase: 225.4),
      },
      datumOffsetMllw: 0.951,
      status: NoaaStationCacheStatus.ok,
    );
    final cached = await repo.read('9414290');
    expect(cached!.status, NoaaStationCacheStatus.ok);
    expect(cached.constituents.keys, ['K1']);
  });
}
```

Run: `flutter test test/features/tides/data/noaa_station_cache_repository_test.dart`
Expected: FAIL (repository does not exist).

- [ ] **Step 3: Implement the repository**

Create `lib/features/tides/data/repositories/noaa_station_cache_repository.dart` (model on `ReefCacheDao`):

```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';

enum NoaaStationCacheStatus { ok, unavailable }

/// One cached NOAA harmonic station.
class CachedNoaaStation {
  final String stationId;
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, TideConstituent> constituents;
  final double? datumOffsetMllw;
  final NoaaStationCacheStatus status;
  final DateTime fetchedAt;

  const CachedNoaaStation({
    required this.stationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.constituents,
    required this.datumOffsetMllw,
    required this.status,
    required this.fetchedAt,
  });
}

/// Reads and writes the NOAA station constituent cache in the local
/// cache database. TTL policy lives in the resolver, not here.
class NoaaStationCacheRepository {
  final LocalCacheDatabase _db;
  final DateTime Function() _now;

  NoaaStationCacheRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<CachedNoaaStation?> read(String stationId) async {
    final row = await (_db.select(
      _db.noaaTideStations,
    )..where((t) => t.stationId.equals(stationId))).getSingleOrNull();
    if (row == null) return null;

    final constituents = <String, TideConstituent>{};
    (json.decode(row.constituentsJson) as Map<String, dynamic>).forEach((
      name,
      c,
    ) {
      constituents[name] = TideConstituent(
        name: name,
        amplitude: ((c as Map<String, dynamic>)['amplitude'] as num).toDouble(),
        phase: (c['phase'] as num).toDouble(),
      );
    });

    return CachedNoaaStation(
      stationId: row.stationId,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      constituents: constituents,
      datumOffsetMllw: row.datumOffsetMllw,
      status: row.status == NoaaStationCacheStatus.ok.name
          ? NoaaStationCacheStatus.ok
          : NoaaStationCacheStatus.unavailable,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        row.fetchedAt,
        isUtc: true,
      ),
    );
  }

  Future<void> write({
    required String stationId,
    required String name,
    required double latitude,
    required double longitude,
    required Map<String, TideConstituent> constituents,
    double? datumOffsetMllw,
    required NoaaStationCacheStatus status,
  }) async {
    final constituentsJson = json.encode({
      for (final e in constituents.entries)
        e.key: {'amplitude': e.value.amplitude, 'phase': e.value.phase},
    });
    await _db
        .into(_db.noaaTideStations)
        .insertOnConflictUpdate(
          NoaaTideStationsCompanion.insert(
            stationId: stationId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            constituentsJson: Value(constituentsJson),
            datumOffsetMllw: Value(datumOffsetMllw),
            status: status.name,
            fetchedAt: _now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/tides/data/noaa_station_cache_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/ lib/features/tides/data/repositories/noaa_station_cache_repository.dart test/features/tides/data/
git commit -m "Add NOAA tide station cache table (local cache DB v9) and repository"
```

---

### Task 6: Bundled NOAA station index (asset + generator + loader)

**Files:**
- Create: `scripts/tide/generate_noaa_station_index.py`
- Create: `assets/data/tide/noaa_stations.json` (generated by the script)
- Create: `lib/features/tides/data/services/noaa_station_index.dart`
- Test: `test/features/tides/data/noaa_station_index_test.dart`

**Interfaces:**
- Produces:
  - `class NearbyStation { String id; String name; double latitude; double longitude; double distanceKm; }`
  - `class NoaaStationIndex { NoaaStationIndex(List<List<dynamic>> rows); factory NoaaStationIndex.fromJsonString(String s); NearbyStation? nearest(double latitude, double longitude, {double maxKm = 25.0}); }`
  - Asset format: JSON array of `[id, name, lat, lng]` rows. `assets/data/tide/` is already registered in `pubspec.yaml`; no pubspec change needed.

- [ ] **Step 1: Write the generator script**

Create `scripts/tide/generate_noaa_station_index.py`:

```python
"""Generate the bundled NOAA harmonic station index asset.

Fetches the list of NOAA CO-OPS stations that publish harmonic
constituents (type=harcon; ~1,365 stations) and writes a compact JSON
array of [id, name, lat, lng] rows to assets/data/tide/noaa_stations.json.

Usage (from the repo root):
    python3 scripts/tide/generate_noaa_station_index.py
"""

import json
import urllib.request

URL = (
    "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/"
    "stations.json?type=harcon"
)
OUT = "assets/data/tide/noaa_stations.json"


def main() -> None:
    req = urllib.request.Request(URL, headers={"User-Agent": "submersion"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)

    rows = []
    for s in data["stations"]:
        if not s.get("id") or s.get("lat") is None or s.get("lng") is None:
            continue
        rows.append(
            [s["id"], s.get("name", s["id"]), round(s["lat"], 4), round(s["lng"], 4)]
        )
    rows.sort(key=lambda r: r[0])

    with open(OUT, "w") as f:
        json.dump(rows, f, separators=(",", ":"))
    print(f"Wrote {len(rows)} stations to {OUT}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it to generate the asset**

Run from the repo root: `python3 scripts/tide/generate_noaa_station_index.py`
Expected: `Wrote 1365 stations to assets/data/tide/noaa_stations.json` (count may drift slightly as NOAA adds stations; anything above 1,300 is sane). Sanity-check the file starts with `[["` and is roughly 60-90 KB.

- [ ] **Step 3: Write the failing loader test**

Create `test/features/tides/data/noaa_station_index_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';

void main() {
  final index = NoaaStationIndex.fromJsonString(
    '[["8443970","Boston",42.3539,-71.0503],'
    '["9414290","San Francisco",37.8063,-122.4659],'
    '["9413450","Monterey",36.6089,-121.8914]]',
  );

  test('nearest returns the closest station within range', () {
    // Point Lobos, ~10 km south of the Monterey station.
    final hit = index.nearest(36.5215, -121.9527);
    expect(hit, isNotNull);
    expect(hit!.id, '9413450');
    expect(hit.name, 'Monterey');
    expect(hit.distanceKm, closeTo(10.2, 1.5));
  });

  test('nearest returns null when nothing is within maxKm', () {
    // Mid-Atlantic: no station within 25 km.
    expect(index.nearest(30.0, -40.0), isNull);
  });

  test('maxKm is respected', () {
    expect(index.nearest(36.5215, -121.9527, maxKm: 5.0), isNull);
  });

  test('bundled asset parses and covers known stations', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loaded = await NoaaStationIndex.load();
    final sf = loaded.nearest(37.8063, -122.4659, maxKm: 1.0);
    expect(sf, isNotNull);
    expect(sf!.id, '9414290');
  });
}
```

Run: `flutter test test/features/tides/data/noaa_station_index_test.dart`
Expected: FAIL (loader does not exist).

- [ ] **Step 4: Implement the loader**

Create `lib/features/tides/data/services/noaa_station_index.dart`:

```dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// A NOAA harmonic station near a queried coordinate.
class NearbyStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const NearbyStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });
}

/// In-memory index of NOAA CO-OPS harmonic stations, loaded from the
/// bundled asset generated by scripts/tide/generate_noaa_station_index.py.
class NoaaStationIndex {
  final List<List<dynamic>> _rows;

  NoaaStationIndex(this._rows);

  factory NoaaStationIndex.fromJsonString(String s) {
    return NoaaStationIndex(
      (json.decode(s) as List).cast<List<dynamic>>(),
    );
  }

  static Future<NoaaStationIndex> load() async {
    final s = await rootBundle.loadString('assets/data/tide/noaa_stations.json');
    return NoaaStationIndex.fromJsonString(s);
  }

  /// Nearest station within [maxKm] of the coordinate, or null.
  NearbyStation? nearest(
    double latitude,
    double longitude, {
    double maxKm = 25.0,
  }) {
    NearbyStation? best;
    for (final row in _rows) {
      final lat = (row[2] as num).toDouble();
      final lon = (row[3] as num).toDouble();
      final d = _haversineKm(latitude, longitude, lat, lon);
      if (d <= maxKm && (best == null || d < best.distanceKm)) {
        best = NearbyStation(
          id: row[0] as String,
          name: row[1] as String,
          latitude: lat,
          longitude: lon,
          distanceKm: d,
        );
      }
    }
    return best;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/tides/data/noaa_station_index_test.dart`
Expected: PASS (the asset test loads the real generated file).

- [ ] **Step 6: Commit**

```bash
git add scripts/tide/generate_noaa_station_index.py assets/data/tide/noaa_stations.json lib/features/tides/data/services/noaa_station_index.dart test/features/tides/data/noaa_station_index_test.dart
git commit -m "Add bundled NOAA harmonic station index with generator script"
```

---

### Task 7: NoaaStationService (fetch harmonic constituents and datums)

**Files:**
- Create: `lib/features/tides/data/services/noaa_station_service.dart`
- Test: `test/features/tides/data/noaa_station_service_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure HTTP + parsing).
- Produces:
  - `enum NoaaFetchStatus { ok, unavailable, failed }` — `unavailable` is deterministic (cache it), `failed` is transient (do NOT cache).
  - `class NoaaStationData { Map<String, TideConstituent> constituents; double? datumOffsetMllw; }`
  - `class NoaaFetchResult { NoaaFetchStatus status; NoaaStationData? data; }`
  - `class NoaaStationService { NoaaStationService({http.Client? client}); Future<NoaaFetchResult> fetchStation(String stationId); }`

- [ ] **Step 1: Write the failing tests**

Create `test/features/tides/data/noaa_station_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';

const _harconBody = '''
{"HarmonicConstituents":[
  {"name":"M2","amplitude":0.576,"phase_GMT":208.2,"speed":28.984104},
  {"name":"K1","amplitude":0.37,"phase_GMT":225.4,"speed":15.041069},
  {"name":"LAM2","amplitude":0.007,"phase_GMT":214.3,"speed":29.455625},
  {"name":"RHO","amplitude":0.009,"phase_GMT":200.0,"speed":13.471515},
  {"name":"MK3","amplitude":0.018,"phase_GMT":100.0,"speed":44.025173},
  {"name":"ZERO","amplitude":0.0,"phase_GMT":10.0,"speed":1.0}
]}''';

const _datumsBody = '''
{"datums":[
  {"name":"MHHW","value":2.949},
  {"name":"MSL","value":2.773},
  {"name":"MLLW","value":1.822}
]}''';

void main() {
  test('parses constituents, maps NOAA names, computes MLLW offset', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      if (request.url.path.endsWith('harcon.json')) {
        expect(request.url.queryParameters['units'], 'metric');
        return http.Response(_harconBody, 200);
      }
      if (request.url.path.endsWith('datums.json')) {
        return http.Response(_datumsBody, 200);
      }
      return http.Response('not found', 404);
    });

    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');

    expect(result.status, NoaaFetchStatus.ok);
    final data = result.data!;
    // Identity names kept, NOAA aliases mapped, unknown (MK3) and
    // zero-amplitude entries skipped.
    expect(data.constituents.keys.toSet(), {'M2', 'K1', 'La2', 'Rho1'});
    expect(data.constituents['La2']!.amplitude, 0.007);
    expect(data.constituents['Rho1']!.phase, 200.0);
    expect(data.datumOffsetMllw, closeTo(0.951, 1e-9));
    expect(requested.first, contains('/stations/9414290/'));
  });

  test('missing datums yields null offset but still ok', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('harcon.json')) {
        return http.Response(_harconBody, 200);
      }
      return http.Response('{}', 200);
    });
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.ok);
    expect(result.data!.datumOffsetMllw, isNull);
  });

  test('empty constituent list is deterministic unavailable', () async {
    final client = MockClient(
      (request) async => http.Response('{"HarmonicConstituents":[]}', 200),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('1111111');
    expect(result.status, NoaaFetchStatus.unavailable);
  });

  test('404 is deterministic unavailable', () async {
    final client = MockClient((request) async => http.Response('nope', 404));
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('1111111');
    expect(result.status, NoaaFetchStatus.unavailable);
  });

  test('network error is transient failure, not unavailable', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('boom'),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.failed);
    expect(result.data, isNull);
  });

  test('malformed payload is deterministic unavailable', () async {
    final client = MockClient(
      (request) async => http.Response('{"HarmonicConstituents":"garbage"}', 200),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.unavailable);
  });
}
```

Run: `flutter test test/features/tides/data/noaa_station_service_test.dart`
Expected: FAIL (service does not exist).

- [ ] **Step 2: Implement the service**

Create `lib/features/tides/data/services/noaa_station_service.dart` (model error handling on `ReefHealthService`; inject `http.Client`):

```dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/core/tide/constants/harmonic_constituents.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';

enum NoaaFetchStatus {
  /// Constituents fetched and parsed.
  ok,

  /// The station deterministically has no usable harmonic data
  /// (404, empty list, malformed payload). Safe to cache.
  unavailable,

  /// Transient problem (network, timeout, 5xx). Do NOT cache.
  failed,
}

/// Harmonic data for one NOAA station.
class NoaaStationData {
  final Map<String, TideConstituent> constituents;

  /// MSL minus MLLW in meters, or null when datums were unavailable.
  final double? datumOffsetMllw;

  const NoaaStationData({
    required this.constituents,
    required this.datumOffsetMllw,
  });
}

class NoaaFetchResult {
  final NoaaFetchStatus status;
  final NoaaStationData? data;

  const NoaaFetchResult(this.status, [this.data]);
}

/// Fetches a NOAA CO-OPS station's published harmonic constituents and
/// datum offsets. One successful fetch is cached forever by the caller;
/// this service is stateless.
class NoaaStationService {
  static const _base =
      'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations';
  static const _timeout = Duration(seconds: 10);

  /// NOAA constituent spellings that differ from this codebase's names.
  /// Identity for everything else; names absent from our tables are
  /// skipped entirely (no Doodson/nodal data to predict them with).
  static const _nameMap = {
    'NU2': 'Nu2',
    'MU2': 'Mu2',
    'LAM2': 'La2',
    'RHO': 'Rho1',
    'MM': 'Mm',
    'SSA': 'Ssa',
    'SA': 'Sa',
    'MF': 'Mf',
  };

  final http.Client _client;

  NoaaStationService({http.Client? client}) : _client = client ?? http.Client();

  Future<NoaaFetchResult> fetchStation(String stationId) async {
    final http.Response harconResponse;
    try {
      harconResponse = await _client
          .get(Uri.parse('$_base/$stationId/harcon.json?units=metric'))
          .timeout(_timeout);
    } catch (e) {
      developer.log(
        'NOAA harcon fetch failed for $stationId: $e',
        name: 'NoaaStationService',
      );
      return const NoaaFetchResult(NoaaFetchStatus.failed);
    }

    if (harconResponse.statusCode == 404) {
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }
    if (harconResponse.statusCode != 200) {
      return const NoaaFetchResult(NoaaFetchStatus.failed);
    }

    final Map<String, TideConstituent> constituents;
    try {
      constituents = _parseConstituents(harconResponse.body);
    } catch (e) {
      developer.log(
        'NOAA harcon payload malformed for $stationId: $e',
        name: 'NoaaStationService',
      );
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }
    if (constituents.isEmpty) {
      return const NoaaFetchResult(NoaaFetchStatus.unavailable);
    }

    // Datums are best-effort: without them heights reference MSL.
    double? datumOffsetMllw;
    try {
      final datumsResponse = await _client
          .get(Uri.parse('$_base/$stationId/datums.json?units=metric'))
          .timeout(_timeout);
      if (datumsResponse.statusCode == 200) {
        datumOffsetMllw = _parseMllwOffset(datumsResponse.body);
      }
    } catch (e) {
      developer.log(
        'NOAA datums fetch failed for $stationId: $e',
        name: 'NoaaStationService',
      );
    }

    return NoaaFetchResult(
      NoaaFetchStatus.ok,
      NoaaStationData(
        constituents: constituents,
        datumOffsetMllw: datumOffsetMllw,
      ),
    );
  }

  Map<String, TideConstituent> _parseConstituents(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final list = decoded['HarmonicConstituents'] as List;
    final result = <String, TideConstituent>{};
    for (final raw in list) {
      final c = raw as Map<String, dynamic>;
      final noaaName = c['name'] as String;
      final name = _nameMap[noaaName] ?? noaaName;
      final amplitude = (c['amplitude'] as num).toDouble();
      if (amplitude <= 0 || !constituentSpeeds.containsKey(name)) continue;
      result[name] = TideConstituent(
        name: name,
        amplitude: amplitude,
        phase: (c['phase_GMT'] as num).toDouble(),
      );
    }
    return result;
  }

  double? _parseMllwOffset(String body) {
    final decoded = json.decode(body) as Map<String, dynamic>;
    final datums = decoded['datums'];
    if (datums is! List) return null;
    double? msl;
    double? mllw;
    for (final raw in datums) {
      final d = raw as Map<String, dynamic>;
      if (d['name'] == 'MSL') msl = (d['value'] as num).toDouble();
      if (d['name'] == 'MLLW') mllw = (d['value'] as num).toDouble();
    }
    if (msl == null || mllw == null) return null;
    return msl - mllw;
  }
}
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `flutter test test/features/tides/data/noaa_station_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/tides/data/services/noaa_station_service.dart test/features/tides/data/noaa_station_service_test.dart
git commit -m "Add NOAA station constituent fetch service"
```

---

### Task 8: TideConstituentResolver and provider rework

**Files:**
- Create: `lib/features/tides/data/services/tide_constituent_resolver.dart`
- Modify: `lib/features/tides/presentation/providers/tide_providers.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (line ~4880)
- Test: `test/features/tides/data/tide_constituent_resolver_test.dart`

**Interfaces:**
- Consumes: `NoaaStationIndex.nearest`, `NoaaStationService.fetchStation`, `NoaaStationCacheRepository.read/write`, `TideDataService.getCalculatorForLocation` (Tasks 4-7).
- Produces:
  - `enum TideDataSourceKind { noaaStation, fesModel }`
  - `class TideDataSource { TideDataSourceKind kind; String? stationId; String? stationName; double? distanceKm; bool mllwDatum; const TideDataSource.fesModel(); const TideDataSource.noaaStation({required stationId, required stationName, required distanceKm, required mllwDatum}); }`
  - `class ResolvedTideData { TideCalculator calculator; TideDataSource source; }`
  - `class TideConstituentResolver { TideConstituentResolver({required NoaaStationIndex? stationIndex, required NoaaStationService stationService, required NoaaStationCacheRepository cache, required TideDataService fesService, DateTime Function()? now}); Future<ResolvedTideData?> resolve(double latitude, double longitude); }`
  - Providers: `resolvedTideDataProvider` (`FutureProvider.family<ResolvedTideData?, GeoPoint>`), `tideDataSourceProvider` (`FutureProvider.family<TideDataSource?, GeoPoint>`). `tideCalculatorProvider` and `hasTideDataProvider` keep their existing signatures but are reimplemented on top of `resolvedTideDataProvider`, so the 12 downstream providers and `dive_detail_page.dart` are untouched.
  - Cache policy constants on the resolver: `static const staleAfter = Duration(days: 365);` `static const retryUnavailableAfter = Duration(days: 30);`

- [ ] **Step 1: Write the failing resolver tests**

Create `test/features/tides/data/tide_constituent_resolver_test.dart`. Use a real in-memory `LocalCacheDatabase` for the cache and `MockClient` for HTTP; stub FES by pointing `TideDataService` at nothing (its asset loads fail gracefully in tests, yielding null calculators — that exercises the "no FES data" path; the FES-hit path is covered by asserting fallback ordering with a fake service subclass).

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/data/services/tide_data_service.dart';

const _harconBody = '''
{"HarmonicConstituents":[
  {"name":"M2","amplitude":0.576,"phase_GMT":208.2},
  {"name":"S2","amplitude":0.137,"phase_GMT":216.2},
  {"name":"K1","amplitude":0.37,"phase_GMT":225.4},
  {"name":"O1","amplitude":0.23,"phase_GMT":208.4}
]}''';

const _datumsBody =
    '{"datums":[{"name":"MSL","value":2.773},{"name":"MLLW","value":1.822}]}';

/// FES stand-in returning a fixed calculator for any location.
class _FakeFesService extends TideDataService {
  final TideCalculator? calculator;
  _FakeFesService(this.calculator);

  @override
  Future<TideCalculator?> getCalculatorForLocation(
    double latitude,
    double longitude,
  ) async => calculator;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final index = NoaaStationIndex.fromJsonString(
    '[["9414290","San Francisco",37.8063,-122.4659]]',
  );
  final fesCalculator = TideCalculator(
    constituents: {
      'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0),
    },
  );

  late LocalCacheDatabase db;
  late NoaaStationCacheRepository cache;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    cache = NoaaStationCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  TideConstituentResolver resolver({
    NoaaStationIndex? idx,
    required http.Client client,
    TideCalculator? fes,
    DateTime Function()? now,
  }) {
    return TideConstituentResolver(
      stationIndex: idx,
      stationService: NoaaStationService(client: client),
      cache: cache,
      fesService: _FakeFesService(fes),
      now: now,
    );
  }

  test('station in range: fetches, caches, returns station provenance',
      () async {
    var harconCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('harcon.json')) {
        harconCalls++;
        return http.Response(_harconBody, 200);
      }
      return http.Response(_datumsBody, 200);
    });
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    // Point ~5 km from the SF station.
    final resolved = await r.resolve(37.83, -122.42);
    expect(resolved, isNotNull);
    expect(resolved!.source.kind, TideDataSourceKind.noaaStation);
    expect(resolved.source.stationId, '9414290');
    expect(resolved.source.mllwDatum, true);
    expect(resolved.calculator.z0, closeTo(0.951, 1e-9));
    expect(resolved.calculator.constituents.containsKey('M2'), true);

    // Second resolve hits the cache, not the network.
    await r.resolve(37.83, -122.42);
    expect(harconCalls, 1);
  });

  test('no station in range falls back to FES with model provenance',
      () async {
    final client = MockClient((request) async => http.Response('x', 500));
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    final resolved = await r.resolve(-17.5, 177.5); // Fiji: no NOAA station
    expect(resolved, isNotNull);
    expect(resolved!.source.kind, TideDataSourceKind.fesModel);
    expect(resolved.calculator.z0, 0.0);
  });

  test('transient fetch failure falls back to FES and caches nothing',
      () async {
    final client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    final resolved = await r.resolve(37.83, -122.42);
    expect(resolved!.source.kind, TideDataSourceKind.fesModel);
    expect(await cache.read('9414290'), isNull);
  });

  test('unavailable station is cached and skipped thereafter', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('nope', 404);
    });
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    final first = await r.resolve(37.83, -122.42);
    expect(first!.source.kind, TideDataSourceKind.fesModel);
    expect((await cache.read('9414290'))!.status,
        NoaaStationCacheStatus.unavailable);

    await r.resolve(37.83, -122.42);
    expect(calls, 1);
  });

  test('stale ok row triggers refetch but survives fetch failure', () async {
    // Seed a 2-year-old ok row.
    await cache.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.8063,
      longitude: -122.4659,
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 208.2),
      },
      datumOffsetMllw: 0.9,
      status: NoaaStationCacheStatus.ok,
    );
    final client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );
    final r = resolver(
      idx: index,
      client: client,
      fes: fesCalculator,
      now: () => DateTime.now().toUtc().add(const Duration(days: 800)),
    );

    final resolved = await r.resolve(37.83, -122.42);
    // Stale data beats no data: still station-tier.
    expect(resolved!.source.kind, TideDataSourceKind.noaaStation);
  });

  test('returns null when neither station nor FES has data', () async {
    final client = MockClient((request) async => http.Response('x', 500));
    final r = resolver(idx: index, client: client, fes: null);
    expect(await r.resolve(-17.5, 177.5), isNull);
  });
}
```

Run: `flutter test test/features/tides/data/tide_constituent_resolver_test.dart`
Expected: FAIL (resolver does not exist).

- [ ] **Step 2: Implement the resolver**

Create `lib/features/tides/data/services/tide_constituent_resolver.dart`:

```dart
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';
import 'package:submersion/features/tides/data/services/tide_data_service.dart';

enum TideDataSourceKind { noaaStation, fesModel }

/// Provenance of a resolved tide calculator, shown in the tide UI.
class TideDataSource {
  final TideDataSourceKind kind;
  final String? stationId;
  final String? stationName;
  final double? distanceKm;

  /// True when station heights reference MLLW (datum offset applied),
  /// false when they reference mean sea level.
  final bool mllwDatum;

  const TideDataSource.fesModel()
    : kind = TideDataSourceKind.fesModel,
      stationId = null,
      stationName = null,
      distanceKm = null,
      mllwDatum = false;

  const TideDataSource.noaaStation({
    required this.stationId,
    required this.stationName,
    required this.distanceKm,
    required this.mllwDatum,
  }) : kind = TideDataSourceKind.noaaStation;
}

/// A tide calculator plus where its constituents came from.
class ResolvedTideData {
  final TideCalculator calculator;
  final TideDataSource source;

  const ResolvedTideData({required this.calculator, required this.source});
}

/// Resolves harmonic constituents for a coordinate in priority order:
/// cached NOAA station within [NoaaStationIndex] snap range, then a
/// one-time NOAA fetch, then FES2022 grid interpolation, then null.
/// All failures are silent: the caller always gets the best available
/// tier or null, never an error.
class TideConstituentResolver {
  static const staleAfter = Duration(days: 365);
  static const retryUnavailableAfter = Duration(days: 30);

  final NoaaStationIndex? _stationIndex;
  final NoaaStationService _stationService;
  final NoaaStationCacheRepository _cache;
  final TideDataService _fesService;
  final DateTime Function() _now;

  TideConstituentResolver({
    required NoaaStationIndex? stationIndex,
    required NoaaStationService stationService,
    required NoaaStationCacheRepository cache,
    required TideDataService fesService,
    DateTime Function()? now,
  }) : _stationIndex = stationIndex,
       _stationService = stationService,
       _cache = cache,
       _fesService = fesService,
       _now = now ?? DateTime.now;

  Future<ResolvedTideData?> resolve(double latitude, double longitude) async {
    final station = await _resolveStation(latitude, longitude);
    if (station != null) return station;

    final fesCalculator = await _fesService.getCalculatorForLocation(
      latitude,
      longitude,
    );
    if (fesCalculator != null) {
      return ResolvedTideData(
        calculator: fesCalculator,
        source: const TideDataSource.fesModel(),
      );
    }
    return null;
  }

  Future<ResolvedTideData?> _resolveStation(
    double latitude,
    double longitude,
  ) async {
    final nearby = _stationIndex?.nearest(latitude, longitude);
    if (nearby == null) return null;

    final cached = await _cache.read(nearby.id);
    final age = cached == null
        ? null
        : _now().toUtc().difference(cached.fetchedAt);

    final useCached =
        cached != null &&
        ((cached.status == NoaaStationCacheStatus.ok && age! < staleAfter) ||
            (cached.status == NoaaStationCacheStatus.unavailable &&
                age! < retryUnavailableAfter));

    if (!useCached) {
      final result = await _stationService.fetchStation(nearby.id);
      switch (result.status) {
        case NoaaFetchStatus.ok:
          final data = result.data!;
          await _cache.write(
            stationId: nearby.id,
            name: nearby.name,
            latitude: nearby.latitude,
            longitude: nearby.longitude,
            constituents: data.constituents,
            datumOffsetMllw: data.datumOffsetMllw,
            status: NoaaStationCacheStatus.ok,
          );
          return _fromStation(nearby, data.constituents, data.datumOffsetMllw);
        case NoaaFetchStatus.unavailable:
          await _cache.write(
            stationId: nearby.id,
            name: nearby.name,
            latitude: nearby.latitude,
            longitude: nearby.longitude,
            constituents: const {},
            status: NoaaStationCacheStatus.unavailable,
          );
          return null;
        case NoaaFetchStatus.failed:
          // Transient: keep whatever we have, even stale.
          break;
      }
    }

    if (cached != null && cached.status == NoaaStationCacheStatus.ok) {
      return _fromStation(nearby, cached.constituents, cached.datumOffsetMllw);
    }
    return null;
  }

  ResolvedTideData _fromStation(
    NearbyStation nearby,
    Map<String, dynamic> constituents,
    double? datumOffsetMllw,
  ) {
    return ResolvedTideData(
      calculator: TideCalculator(
        constituents: Map.from(constituents),
        z0: datumOffsetMllw ?? 0.0,
      ),
      source: TideDataSource.noaaStation(
        stationId: nearby.id,
        stationName: nearby.name,
        distanceKm: nearby.distanceKm,
        mllwDatum: datumOffsetMllw != null,
      ),
    );
  }
}
```

Note: `_fromStation` takes the constituent map; both call sites pass `Map<String, TideConstituent>` — declare the parameter as `Map<String, TideConstituent>` (adjust the snippet's `Map<String, dynamic>` accordingly when writing the file; the test will catch a type mismatch).

- [ ] **Step 3: Rework the providers**

In `lib/features/tides/presentation/providers/tide_providers.dart` add (and keep everything downstream unchanged):

```dart
/// Provider for the NOAA station index (bundled asset).
final noaaStationIndexProvider = FutureProvider<NoaaStationIndex?>((ref) async {
  try {
    return await NoaaStationIndex.load();
  } catch (e) {
    return null; // Missing asset: resolver degrades to FES-only.
  }
});

/// Provider for the [NoaaStationService] singleton.
final noaaStationServiceProvider = Provider<NoaaStationService>((ref) {
  return NoaaStationService();
});

/// Provider for the [NoaaStationCacheRepository].
final noaaStationCacheRepositoryProvider = Provider<NoaaStationCacheRepository>(
  (ref) {
    return NoaaStationCacheRepository(
      LocalCacheDatabaseService.instance.database,
    );
  },
);

/// Provider for resolved tide data (calculator plus provenance) at a
/// location. Station tier when a cached or fetchable NOAA station is
/// within range, FES model tier otherwise, null when no data exists.
final resolvedTideDataProvider =
    FutureProvider.family<ResolvedTideData?, GeoPoint>((ref, location) async {
      final index = await ref.watch(noaaStationIndexProvider.future);
      final resolver = TideConstituentResolver(
        stationIndex: index,
        stationService: ref.watch(noaaStationServiceProvider),
        cache: ref.watch(noaaStationCacheRepositoryProvider),
        fesService: ref.watch(tideDataServiceProvider),
      );
      return resolver.resolve(location.latitude, location.longitude);
    });

/// Provider for the provenance of tide data at a location (badge UI).
final tideDataSourceProvider = FutureProvider.family<TideDataSource?, GeoPoint>(
  (ref, location) async {
    final resolved = await ref.watch(resolvedTideDataProvider(location).future);
    return resolved?.source;
  },
);
```

Reimplement the two existing entry points on top of it (signatures unchanged):

```dart
final tideCalculatorProvider = FutureProvider.family<TideCalculator?, GeoPoint>(
  (ref, location) async {
    final resolved = await ref.watch(resolvedTideDataProvider(location).future);
    return resolved?.calculator;
  },
);

final hasTideDataProvider = FutureProvider.family<bool, GeoPoint>((
  ref,
  location,
) async {
  final resolved = await ref.watch(resolvedTideDataProvider(location).future);
  return resolved != null;
});
```

Add the needed imports (`local_cache_database_service.dart`, `noaa_station_cache_repository.dart`, `noaa_station_index.dart`, `noaa_station_service.dart`, `tide_constituent_resolver.dart`).

- [ ] **Step 4: Switch dive_edit_page to the resolver**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (~line 4880), replace the tide-recording block's calculator acquisition and add the freshwater gate:

```dart
      // Record tide conditions if site has coordinates (skip freshwater
      // sites: tides are meaningless there and a nearby ocean station
      // must not leak in).
      if (savedDiveId != null &&
          _selectedSite != null &&
          _selectedSite!.hasCoordinates &&
          _selectedSite!.waterType != WaterType.fresh) {
        try {
          final resolved = await ref.read(
            resolvedTideDataProvider(_selectedSite!.location!).future,
          );
          if (resolved != null) {
            // Record tide status at dive entry time
            final status = resolved.calculator.getStatus(entryDateTime);
            final tideRepository = ref.read(tideRecordRepositoryProvider);
            await tideRepository.createFromStatus(
              diveId: savedDiveId,
              status: status,
            );
          }
        } catch (e) {
          // Silently fail - tide recording is optional enhancement
          debugPrint('Failed to record tide data: $e');
        }
      }
```

Add `WaterType` import if the analyzer asks (`package:submersion/core/constants/enums.dart`).

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/tides/ test/core/tide/ && flutter analyze`
Expected: resolver tests PASS; existing widget tests PASS (they override the family providers directly, which still exist); analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tides/ lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/tides/
git commit -m "Add tide constituent resolver with NOAA station tier and provenance"
```

---

### Task 9: Freshwater gate in the tide UI

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (~line 197)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildTideSection`, ~line 3447)

**Interfaces:**
- Consumes: `DiveSite.waterType` (`WaterType?` — only `WaterType.fresh` hides tides; brackish/null are treated as ocean).

- [ ] **Step 1: Gate the site detail page**

In `site_detail_page.dart`, find `TideSection(location: site.location!)` and guard it with the water type (adapt to the surrounding list/column syntax):

```dart
              if (site.waterType != WaterType.fresh)
                TideSection(location: site.location!),
```

Add the `WaterType` import if not already present.

- [ ] **Step 2: Gate the dive detail page**

In `dive_detail_page.dart` `_buildTideSection`, add an early return before the stored-record lookup (a stored record on a freshwater site is hidden too — the section disappears entirely per spec):

```dart
  Widget _buildTideSection(BuildContext context, WidgetRef ref, Dive dive) {
    // Freshwater sites have no tides; hide the section entirely.
    if (dive.site?.waterType == WaterType.fresh) {
      return const SizedBox.shrink();
    }
```

- [ ] **Step 3: Verify no regressions**

Run: `flutter test test/features/tides/ test/features/dive_sites/ && flutter analyze`
Expected: PASS/clean (existing tests use sites without `waterType: fresh`).

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "Hide tide sections for freshwater sites"
```

---

### Task 10: Source badge UI and localization

**Files:**
- Create: `lib/features/tides/presentation/widgets/tide_source_badge.dart`
- Modify: `lib/features/tides/presentation/widgets/tide_section.dart` (header of `_TideSectionContent`)
- Modify: all 11 ARB files in `lib/l10n/arb/`
- Test: `test/features/tides/presentation/widgets/tide_source_badge_test.dart`

**Interfaces:**
- Consumes: `tideDataSourceProvider(location)`, `TideDataSource` (Task 8), `UnitFormatter(settings).formatGeoDistance(double meters)`, `context.l10n`.
- Produces: `class TideSourceBadge extends ConsumerWidget { final GeoPoint location; const TideSourceBadge({super.key, required this.location}); }`

- [ ] **Step 1: Add the localization keys**

Add to `lib/l10n/arb/app_en.arb` (keys follow the `feature_category_name` convention):

```json
  "tides_source_noaaStation": "NOAA station: {name} ({distance})",
  "@tides_source_noaaStation": {
    "placeholders": {
      "name": {"type": "String"},
      "distance": {"type": "String"}
    }
  },
  "tides_source_modelEstimate": "Ocean-model estimate",
  "tides_source_modelCaveat": "Modeled from satellite data. Times and heights may differ near complex coastlines.",
  "tides_source_sheetTitle": "Tide data source",
  "tides_source_datumMllw": "Heights relative to MLLW (station datum)",
  "tides_source_datumMsl": "Heights relative to mean sea level"
```

Translations for the other 10 locales (same placeholders for `tides_source_noaaStation`; the `@` metadata block is only needed in `app_en.arb`):

| Key | de | es | fr |
|---|---|---|---|
| noaaStation | `NOAA-Station: {name} ({distance})` | `Estación NOAA: {name} ({distance})` | `Station NOAA : {name} ({distance})` |
| modelEstimate | `Ozeanmodell-Schätzung` | `Estimación de modelo oceánico` | `Estimation par modèle océanique` |
| modelCaveat | `Aus Satellitendaten modelliert. Zeiten und Höhen können in der Nähe komplexer Küstenlinien abweichen.` | `Modelado a partir de datos satelitales. Las horas y alturas pueden diferir cerca de costas complejas.` | `Modélisé à partir de données satellitaires. Les heures et hauteurs peuvent différer près des côtes complexes.` |
| sheetTitle | `Quelle der Gezeitendaten` | `Fuente de datos de mareas` | `Source des données de marée` |
| datumMllw | `Höhen relativ zu MLLW (Stationsdatum)` | `Alturas relativas a MLLW (datum de la estación)` | `Hauteurs par rapport au MLLW (datum de la station)` |
| datumMsl | `Höhen relativ zum mittleren Meeresspiegel` | `Alturas relativas al nivel medio del mar` | `Hauteurs par rapport au niveau moyen de la mer` |

| Key | it | nl | pt |
|---|---|---|---|
| noaaStation | `Stazione NOAA: {name} ({distance})` | `NOAA-station: {name} ({distance})` | `Estação NOAA: {name} ({distance})` |
| modelEstimate | `Stima da modello oceanico` | `Oceaanmodel-schatting` | `Estimativa de modelo oceânico` |
| modelCaveat | `Modellato da dati satellitari. Orari e altezze possono differire vicino a coste complesse.` | `Gemodelleerd op basis van satellietdata. Tijden en hoogten kunnen afwijken bij complexe kustlijnen.` | `Modelado a partir de dados de satélite. Horários e alturas podem diferir perto de costas complexas.` |
| sheetTitle | `Fonte dei dati di marea` | `Bron getijdendata` | `Fonte dos dados de maré` |
| datumMllw | `Altezze rispetto al MLLW (datum della stazione)` | `Hoogten ten opzichte van MLLW (stationsdatum)` | `Alturas relativas ao MLLW (datum da estação)` |
| datumMsl | `Altezze rispetto al livello medio del mare` | `Hoogten ten opzichte van gemiddeld zeeniveau` | `Alturas relativas ao nível médio do mar` |

| Key | hu | he | ar | zh |
|---|---|---|---|---|
| noaaStation | `NOAA állomás: {name} ({distance})` | `תחנת NOAA: {name} ({distance})` | `محطة NOAA: {name} ({distance})` | `NOAA 站点：{name}（{distance}）` |
| modelEstimate | `Óceánmodell-becslés` | `אומדן מודל אוקיינוס` | `تقدير نموذج المحيط` | `海洋模型估算` |
| modelCaveat | `Műholdadatok alapján modellezve. Az időpontok és magasságok eltérhetnek összetett partvonalak közelében.` | `מבוסס על נתוני לוויין. זמנים וגבהים עשויים להיות שונים ליד קווי חוף מורכבים.` | `نموذج مبني على بيانات الأقمار الصناعية. قد تختلف الأوقات والارتفاعات قرب السواحل المعقدة.` | `基于卫星数据建模，复杂海岸线附近的时间和高度可能有偏差。` |
| sheetTitle | `Árapályadatok forrása` | `מקור נתוני הגאות` | `مصدر بيانات المد والجزر` | `潮汐数据来源` |
| datumMllw | `Magasságok az MLLW-hez képest (állomási alapszint)` | `גבהים ביחס ל-MLLW (ייחוס התחנה)` | `الارتفاعات نسبة إلى MLLW (مرجع المحطة)` | `高度基于 MLLW（站点基准面）` |
| datumMsl | `Magasságok a közepes tengerszinthez képest` | `גבהים ביחס לגובה פני הים הממוצע` | `الارتفاعات نسبة إلى متوسط مستوى سطح البحر` | `高度基于平均海平面` |

Then run: `flutter gen-l10n` and `flutter test test/l10n/arb_parity_test.dart`
Expected: parity test PASS.

- [ ] **Step 2: Write the failing badge widget test**

Create `test/features/tides/presentation/widgets/tide_source_badge_test.dart` (follow the `ProviderScope` + localization pattern from `tide_section_time_format_test.dart`; no `Intl` pinning needed — no dates rendered):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_source_badge.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _location = GeoPoint(37.83, -122.42);

Future<Widget> _host(TideDataSource? source) async {
  final overrides = await getBaseOverrides();
  return ProviderScope(
    overrides: [
      ...overrides,
      tideDataSourceProvider(
        _location,
      ).overrideWith((ref) async => source),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TideSourceBadge(location: _location)),
    ),
  );
}

void main() {
  testWidgets('station tier shows station name and distance', (tester) async {
    await tester.pumpWidget(
      await _host(
        const TideDataSource.noaaStation(
          stationId: '9414290',
          stationName: 'San Francisco',
          distanceKm: 5.2,
          mllwDatum: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NOAA station'), findsOneWidget);
    expect(find.textContaining('San Francisco'), findsOneWidget);
    // Default settings are metric: 5.2 km renders via formatGeoDistance.
    expect(find.textContaining('km'), findsOneWidget);
  });

  testWidgets('model tier shows estimate label and caveat on tap',
      (tester) async {
    await tester.pumpWidget(await _host(const TideDataSource.fesModel()));
    await tester.pumpAndSettle();

    expect(find.text('Ocean-model estimate'), findsOneWidget);

    await tester.tap(find.text('Ocean-model estimate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Modeled from satellite data'), findsOneWidget);
    expect(
      find.textContaining('relative to mean sea level'),
      findsOneWidget,
    );
  });

  testWidgets('null source renders nothing', (tester) async {
    await tester.pumpWidget(await _host(null));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
```

Run: `flutter test test/features/tides/presentation/widgets/tide_source_badge_test.dart`
Expected: FAIL (widget does not exist).

- [ ] **Step 3: Implement the badge**

Create `lib/features/tides/presentation/widgets/tide_source_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact provenance line for the tide section: which data tier is
/// backing the predictions, tappable for datum and caveat details.
class TideSourceBadge extends ConsumerWidget {
  final GeoPoint location;

  const TideSourceBadge({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceAsync = ref.watch(tideDataSourceProvider(location));
    final source = sourceAsync.valueOrNull;
    if (source == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final String label;
    final IconData icon;
    switch (source.kind) {
      case TideDataSourceKind.noaaStation:
        label = context.l10n.tides_source_noaaStation(
          source.stationName ?? source.stationId ?? '',
          units.formatGeoDistance((source.distanceKm ?? 0) * 1000),
        );
        icon = Icons.verified_outlined;
      case TideDataSourceKind.fesModel:
        label = context.l10n.tides_source_modelEstimate;
        icon = Icons.public;
    }

    return InkWell(
      onTap: () => _showDetails(context, source),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, TideDataSource source) {
    final isStation = source.kind == TideDataSourceKind.noaaStation;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tides_source_sheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (isStation) ...[
                  Text(source.stationName ?? source.stationId ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    source.mllwDatum
                        ? context.l10n.tides_source_datumMllw
                        : context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(context.l10n.tides_source_modelCaveat),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Mount the badge in the tide section header**

In `tide_section.dart`, `_TideSectionContent.build`, insert directly after the header `Row` (before `const SizedBox(height: 12)`):

```dart
            TideSourceBadge(location: location),
```

Add the import and export it from `widgets.dart` alongside the other tide widgets.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/tides/ && flutter analyze`
Expected: badge tests PASS; `tide_section_time_format_test.dart` still passes (it overrides `tideDataSourceProvider`'s upstream `resolvedTideDataProvider` implicitly by overriding nothing — the badge renders `SizedBox.shrink` while loading/erroring in that test, which is fine; if it errors loudly, add `tideDataSourceProvider(_location).overrideWith((ref) async => null)` to that test's overrides).

- [ ] **Step 6: Commit**

```bash
git add lib/features/tides/presentation/widgets/ lib/l10n/ test/features/tides/presentation/widgets/tide_source_badge_test.dart
git commit -m "Add tide data source badge with datum details and localization"
```

---

### Task 11: Lazy self-heal of stale stored TideRecords

**Files:**
- Create: `lib/features/tides/domain/services/tide_record_heal.dart`
- Modify: `lib/features/tides/presentation/providers/tide_providers.dart` (add `healedTideRecordProvider`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildTideSection`)
- Test: `test/features/tides/domain/tide_record_heal_test.dart`

**Interfaces:**
- Consumes: `TideRecord` (domain), `TideStatus`, `tideRecordRepositoryProvider`, `resolvedTideDataProvider`.
- Produces:
  - `bool tideRecordNeedsHeal({required domain.TideRecord stored, required domain.TideRecord fresh})` — true when height differs > 0.05 m, state differs, or either extreme time differs > 10 minutes (null vs non-null counts as differing).
  - `healedTideRecordProvider`: `FutureProvider.family<domain.TideRecord?, ({String diveId, GeoPoint? location, DateTime entryTime})>`.

- [ ] **Step 1: Write the failing pure-function tests**

Create `test/features/tides/domain/tide_record_heal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/tide_record_heal.dart';

TideRecord _record({
  double height = 1.0,
  TideState state = TideState.rising,
  DateTime? highTime,
  DateTime? lowTime,
}) {
  return TideRecord(
    id: 'r1',
    diveId: 'd1',
    heightMeters: height,
    tideState: state,
    highTideTime: highTime,
    lowTideTime: lowTime,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final high = DateTime.utc(2026, 6, 15, 14, 0);
  final low = DateTime.utc(2026, 6, 15, 8, 0);

  test('identical records need no heal', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: high, lowTime: low),
        fresh: _record(highTime: high, lowTime: low),
      ),
      false,
    );
  });

  test('small differences inside thresholds need no heal', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(height: 1.0, highTime: high),
        fresh: _record(
          height: 1.04,
          highTime: high.add(const Duration(minutes: 9)),
        ),
      ),
      false,
    );
  });

  test('height difference above 0.05 m heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(height: 1.0),
        fresh: _record(height: 1.06),
      ),
      true,
    );
  });

  test('state difference heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(state: TideState.rising),
        fresh: _record(state: TideState.falling),
      ),
      true,
    );
  });

  test('extreme time difference above 10 minutes heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: high),
        fresh: _record(highTime: high.add(const Duration(minutes: 11))),
      ),
      true,
    );
  });

  test('null versus non-null extreme heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: null),
        fresh: _record(highTime: high),
      ),
      true,
    );
  });
}
```

Run: `flutter test test/features/tides/domain/tide_record_heal_test.dart`
Expected: FAIL (function does not exist).

- [ ] **Step 2: Implement the pure function**

Create `lib/features/tides/domain/services/tide_record_heal.dart`:

```dart
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

const _heightToleranceMeters = 0.05;
const _extremeTimeTolerance = Duration(minutes: 10);

/// Whether a stored tide record disagrees with a freshly computed one
/// enough to overwrite it. Records written before the 2026 harmonic
/// engine fixes are wrong by hours; records written after match within
/// these thresholds and are left alone (guaranteeing convergence).
bool tideRecordNeedsHeal({
  required TideRecord stored,
  required TideRecord fresh,
}) {
  if ((stored.heightMeters - fresh.heightMeters).abs() >
      _heightToleranceMeters) {
    return true;
  }
  if (stored.tideState != fresh.tideState) return true;
  if (_timesDiffer(stored.highTideTime, fresh.highTideTime)) return true;
  if (_timesDiffer(stored.lowTideTime, fresh.lowTideTime)) return true;
  return false;
}

bool _timesDiffer(DateTime? a, DateTime? b) {
  if (a == null || b == null) return (a == null) != (b == null);
  return a.difference(b).abs() > _extremeTimeTolerance;
}
```

Run the tests again: `flutter test test/features/tides/domain/tide_record_heal_test.dart`
Expected: PASS.

- [ ] **Step 3: Add the healing provider**

In `tide_providers.dart` add:

```dart
/// Provider for a dive's tide record, lazily self-healing rows written
/// by the pre-2026 broken engine. When the stored record disagrees with
/// a fresh computation beyond the heal thresholds it is overwritten and
/// the new record returned. Converges: post-fix records match the fresh
/// computation and are never rewritten.
final healedTideRecordProvider =
    FutureProvider.family<
      TideRecord?,
      ({String diveId, GeoPoint? location, DateTime entryTime})
    >((ref, params) async {
      final repository = ref.watch(tideRecordRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      final stored = await repository.getTideRecordForDive(params.diveId);
      if (stored == null) return null;

      final location = params.location;
      if (location == null) return stored;

      final resolved = await ref.watch(
        resolvedTideDataProvider(location).future,
      );
      if (resolved == null) return stored;

      final status = await resolved.calculator.getStatusAsync(params.entryTime);
      final fresh = TideRecord.fromStatus(
        id: stored.id,
        diveId: params.diveId,
        status: status,
      );
      if (!tideRecordNeedsHeal(stored: stored, fresh: fresh)) return stored;

      return repository.createFromStatus(
        diveId: params.diveId,
        status: status,
      );
    });
```

Add imports for `tide_record_heal.dart` (and confirm `TideRecord`/`diveRepositoryProvider` imports are already present in the file — they are, for `tideRecordForDiveProvider`).

- [ ] **Step 4: Use it from the dive detail page**

In `dive_detail_page.dart` `_buildTideSection`, replace

```dart
    final tideRecordAsync = ref.watch(tideRecordForDiveProvider(dive.id));
```

with

```dart
    final tideRecordAsync = ref.watch(
      healedTideRecordProvider((
        diveId: dive.id,
        location: dive.site?.location,
        entryTime: dive.effectiveEntryTime,
      )),
    );
```

The rest of the `when(...)` body is unchanged (`healedTideRecordProvider` returns the same `TideRecord?`). `tideRecordForDiveProvider` stays for other callers.

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/tides/ && flutter analyze`
Expected: PASS/clean. Note the heal write bumps the dive's `updatedAt`, which re-fires `watchDiveDetailChanges` and re-runs the provider once; the second pass finds no difference and stops (convergence by construction).

- [ ] **Step 6: Commit**

```bash
git add lib/features/tides/ lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/tides/domain/
git commit -m "Lazily self-heal tide records computed by the broken engine"
```

---

### Task 12: Full verification and PR

**Files:**
- No new files; whole-tree verification.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: no files changed (fix and re-commit if any are).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (infos are fatal — fix everything).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test` (allow 10+ minutes; do not shorten the timeout)
Expected: all tests pass. Known-flaky suites are documented in memory; rerun an isolated failure once before investigating.

- [ ] **Step 4: Push and open the PR**

```bash
git push -u origin worktree-tide-accuracy
gh pr create --title "Fix tide prediction accuracy: harmonic engine bugs plus NOAA station refinement" --body "$(cat <<'EOF'
## Summary
- Fixes five stacked math bugs that made tide charts wildly inaccurate since introduction: double-counted phase evolution, solar-longitude coefficients 10x too fast, missing Doodson phase constants, a half-day Julian date offset, and two wrong Doodson table entries (The1, M1) plus a wrong Mtm speed.
- Removes the placeholder "Sample Data" site constituents that shadowed real FES2022 data at popular dive sites.
- Adds a NOAA CO-OPS refinement tier: station harmonic constituents are fetched once (free API, no key), cached in the local cache DB, and drive station-quality offline predictions with MLLW datum alignment; FES2022 remains the global fallback.
- Adds a provenance badge (NOAA station vs ocean-model estimate) with datum details, hides tide sections for freshwater sites, and lazily self-heals per-dive tide records written by the broken engine.

## Validation
- Golden tests pin the engine against NOAA published predictions for San Francisco (mixed), Boston (semi-diurnal), and Pensacola (diurnal) on 2026-09-15 and 2027-06-15: worst error 15.6 minutes / 0.071 m (asserted at 20 min / 0.15 m).
- M2 frequency regression test (12.4206 h period), Meeus astronomy tests, Doodson-vs-speed table consistency test, resolver/service/cache/badge/heal unit and widget tests.

Spec: docs/superpowers/specs/2026-08-09-tide-accuracy-design.md
EOF
)"
```

Expected: pre-push hooks pass (format, analyze, tests); PR opens against `main`.

---

## Self-Review Notes (already applied)

- Spec coverage: root causes 1-5 → Tasks 1-3; sample data removal → Task 4; cache table → Task 5; station index → Task 6; fetch service → Task 7; resolver + provider + dive-edit gate → Task 8; freshwater UI gate → Task 9; badge + l10n + datum display → Task 10; TideRecord self-heal → Task 11; project gates → Task 12.
- Type consistency: `TideDataSource` constructors and `ResolvedTideData` fields match between Tasks 8, 10, and 11; `NoaaStationCacheStatus`/`CachedNoaaStation` match between Tasks 5 and 8; `NearbyStation` matches between Tasks 6 and 8.
- The Task 8 note about `_fromStation`'s parameter type is intentional: declare it `Map<String, TideConstituent>`.
- Numbers in golden fixtures and tolerances were validated against a Python port of the corrected algorithm on 2026-08-09 (see spec "Validation of the combined fix").
