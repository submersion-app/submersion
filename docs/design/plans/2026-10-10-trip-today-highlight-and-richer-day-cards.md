# Trip Today Highlight and Richer Day Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, per the build-feature workflow). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make today stand out on a trip's Overview and Itinerary tabs, open both at today during the trip, and show the day's plan, conditions, totals, weather and media on the day cards.

**Architecture:** Pure domain helpers (day totals, conditions aggregation, plan progress) sit beside `TripStoryDay`; small shared widgets in `lib/features/trips/presentation/widgets/day/` render them on both tabs. The Overview story styles today from `TripStoryDayKind.today`; the Itinerary tab keeps its own dive grouping and edit sheet and borrows media and sightings from `tripStoryProvider` as a best-effort enrichment. Both lists anchor at today with `CustomScrollView(center:)`.

**Tech Stack:** Flutter, Riverpod 3, flutter_test, ARB l10n via `flutter gen-l10n`, `clock` for testable "now".

**Spec:** `docs/design/specs/2026-10-10-trip-today-highlight-and-richer-day-cards-design.md`

## Global Constraints

- No schema change, no new dependency.
- Colours only from `ColorScheme` roles (no `Colors.*` for the today treatment); must read in light and dark themes.
- Every displayed unit goes through `UnitFormatter` built from `settingsProvider` (temperature, depth, distance).
- Every new user-facing string is an ARB key translated into all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs only after every locale has its translations.
- Plural ARB branches use `one{...}` with the `{count}` placeholder, never `=1{1 ...}` with a literal digit.
- No em-dashes anywhere (code, comments, ARB values, commits).
- Files stay under 800 lines; new files under `lib/` require running `test/architecture/` and `test/shared/`.
- Itinerary "today" is derived from `clock.now()` (the tab's existing tests pin it with `withClock`); the Overview's today is `story.todayIndex`.

## Review Focus

1. A trip in progress whose today is Day 1: the Overview has no earlier days; the hero must still sit above today and be reachable by scrolling up.
2. Itinerary gaps: today has no itinerary row (anchor on the next row); every row is before today (no anchor, plain list).
3. Imperial diver: the conditions line must read in Fahrenheit and feet, not metric.
4. Dark theme: today's header text must use `onPrimaryContainer`, not the default `onSurface`, or it vanishes on the tint.
5. A past day that logged more dives than planned ("4 of 3 planned dives") and a planned rest day (0) that must show no plan line.

---

## File Structure

Create:
- `lib/features/trips/domain/services/day_conditions.dart`: `DayConditions` aggregate over a day's dives.
- `lib/features/trips/domain/services/day_plan_progress.dart`: `DayPlanProgress` and `dayPlanProgress(...)`.
- `lib/features/trips/presentation/widgets/day/today_chip.dart`: the "Today" chip.
- `lib/features/trips/presentation/widgets/day/day_weather_badge.dart`: icon plus air temperature (moved out of the header).
- `lib/features/trips/presentation/widgets/day/day_conditions_line.dart`: water, visibility, current line.
- `lib/features/trips/presentation/widgets/day/day_plan_line.dart`: "X of N planned dives" / "N dives planned".
- `lib/features/trips/presentation/widgets/day/day_format.dart`: `formatDayRuntime(Duration)`.
- `lib/features/trips/presentation/widgets/story/trip_story_day_plan.dart`: plan section of a story card (notes, plan line, history pills), moved from the card.
- `lib/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart`: the itinerary card, moved out of the tab.
- `lib/features/trips/presentation/widgets/itinerary/itinerary_dive_row.dart`: the itinerary dive row, moved out of the tab.
- Tests mirroring each new file under `test/features/trips/...`.

Modify:
- `lib/features/trips/domain/entities/trip_story_day.dart`: top-level `diveDayRuntime`, `diveDayMaxDepth`, `diveDayWeather`; `TripStoryDayWeather.resolve`.
- `lib/features/trips/domain/services/trip_dive_days.dart`: `tripDayKind(date, now)`.
- `lib/features/trips/domain/services/trip_story_builder.dart`: use `tripDayKind`.
- `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`: today styling, uses `DayWeatherBadge`.
- `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`: today outline, plan section, conditions line, runtime helper.
- `lib/features/trips/presentation/widgets/story/trip_story_view.dart`: drop divider, anchor at today.
- `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`: anchor at today, story lookup, uses the moved card.
- `lib/l10n/arb/app_*.arb` (11) and generated `lib/l10n/arb/app_localizations*.dart`.
- `docs/design/specs/2026-10-10-trip-today-highlight-and-richer-day-cards-design.md`: record that itinerary dives stay on `divesForTripProvider`.

---

### Task 1: Day totals and weather helpers

**Files:**
- Modify: `lib/features/trips/domain/entities/trip_story_day.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart` (weather rule only)
- Test: `test/features/trips/domain/entities/trip_story_day_test.dart`

**Interfaces:**
- Produces: `Duration diveDayRuntime(Iterable<Dive> dives)`, `double? diveDayMaxDepth(Iterable<Dive> dives)`, `TripStoryDayWeather? diveDayWeather(Iterable<Dive> dives)`, `static TripStoryDayWeather? TripStoryDayWeather.resolve({TripStoryDayWeather? logged, TripStoryDayWeather? stored})`. `TripStoryDay.totalRuntime`, `.maxDepth`, `.weather` delegate to them.

- [ ] **Step 1: Write the failing tests** (append a group to `trip_story_day_test.dart`)

```dart
  group('dive-day helpers', () {
    final d1 = Dive(
      id: 'a',
      dateTime: DateTime(2026, 3, 8, 9),
      runtime: const Duration(minutes: 50),
      maxDepth: 18,
      airTemp: 29,
    );
    final d2 = Dive(
      id: 'b',
      dateTime: DateTime(2026, 3, 8, 14),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 24,
      cloudCover: CloudCover.partlyCloudy,
    );

    test('runtime sums runtime, falling back to bottom time', () {
      expect(diveDayRuntime([d1, d2]), const Duration(minutes: 90));
      expect(diveDayRuntime(const []), Duration.zero);
    });

    test('max depth is the deepest dive, null without depths', () {
      expect(diveDayMaxDepth([d1, d2]), 24);
      expect(diveDayMaxDepth([Dive(id: 'c', dateTime: DateTime(2026))]), isNull);
    });

    test('weather combines the first non-null field of each kind', () {
      final w = diveDayWeather([d1, d2])!;
      expect(w.airTemp, 29);
      expect(w.cloudCover, CloudCover.partlyCloudy);
    });

    test('resolve prefers renderable logged weather, else stored', () {
      const logged = TripStoryDayWeather(airTemp: 28);
      const blank = TripStoryDayWeather(precipitation: Precipitation.none);
      const stored = TripStoryDayWeather(airTemp: 31);
      expect(TripStoryDayWeather.resolve(logged: logged, stored: stored), logged);
      expect(TripStoryDayWeather.resolve(logged: blank, stored: stored), stored);
      expect(TripStoryDayWeather.resolve(logged: blank, stored: null), blank);
      expect(TripStoryDayWeather.resolve(logged: null, stored: null), isNull);
    });
  });
```

Check `CloudCover` value names with `grep -n "enum CloudCover" -A8 lib/core/constants/enums.dart` and use an existing one.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart`
Expected: compile errors, `diveDayRuntime` / `resolve` not defined.

- [ ] **Step 3: Implement**

In `trip_story_day.dart`, add top-level functions above `class TripStoryDay` and make the getters delegate:

```dart
/// Total time in the water across [dives]: runtime (surface to surface),
/// falling back to bottom time for hand-logged dives that carry only that.
/// What the rest of the app sums (`COALESCE(runtime, bottom_time)`).
Duration diveDayRuntime(Iterable<Dive> dives) => dives.fold(
  Duration.zero,
  (sum, dive) => sum + (dive.runtime ?? dive.bottomTime ?? Duration.zero),
);

/// The deepest of [dives], or null when none logged a depth.
double? diveDayMaxDepth(Iterable<Dive> dives) {
  double? max;
  for (final dive in dives) {
    final depth = dive.maxDepth;
    if (depth != null && (max == null || depth > max)) max = depth;
  }
  return max;
}

/// Day-level weather from [dives], or null when no dive logged any. Each
/// field is the first non-null value in dive order, so a morning dive that
/// logged only air temperature and an afternoon dive that logged only sky
/// conditions combine into one summary.
TripStoryDayWeather? diveDayWeather(Iterable<Dive> dives) {
  double? airTemp;
  CloudCover? cloudCover;
  Precipitation? precipitation;
  for (final dive in dives) {
    airTemp ??= dive.airTemp;
    cloudCover ??= dive.cloudCover;
    precipitation ??= dive.precipitation;
  }
  if (airTemp == null && cloudCover == null && precipitation == null) {
    return null;
  }
  return TripStoryDayWeather(
    airTemp: airTemp,
    cloudCover: cloudCover,
    precipitation: precipitation,
  );
}
```

Replace the bodies of `totalRuntime`, `maxDepth` and `weather` with `diveDayRuntime(dives)`, `diveDayMaxDepth(dives)` and `diveDayWeather(dives)`, keeping their doc comments. In `TripStoryDayWeather` add:

```dart
  /// The weather a day shows: what the diver logged wins when it can draw
  /// something, since a stored day summary only ever stands in for days that
  /// logged none. A dive whose lookup resolved nothing still carries
  /// [Precipitation.none], and letting that mask a stored row would leave the
  /// day blank.
  static TripStoryDayWeather? resolve({
    TripStoryDayWeather? logged,
    TripStoryDayWeather? stored,
  }) => (logged != null && logged.isRenderable) ? logged : (stored ?? logged);
```

In `trip_story_day_header.dart`, replace the inline rule (the `diveWeather` / `weather` locals and their comment) with:

```dart
    final weather = TripStoryDayWeather.resolve(
      logged: day.weather,
      stored: storedWeather,
    );
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/entities/trip_story_day.dart lib/features/trips/presentation/widgets/story/trip_story_day_header.dart test/features/trips/domain/entities/trip_story_day_test.dart
git commit -m "refactor(trips): share day totals and weather rule as functions"
```

---

### Task 2: DayConditions aggregation

**Files:**
- Create: `lib/features/trips/domain/services/day_conditions.dart`
- Test: `test/features/trips/domain/services/day_conditions_test.dart`

**Interfaces:**
- Produces: `class DayConditions` with `double? minWaterTemp, maxWaterTemp` (celsius), `double? minVisibilityMeters, maxVisibilityMeters`, `VisibilityBand? legacyVisibility`, `CurrentStrength? minCurrent, maxCurrent`, `bool get isEmpty`, `factory DayConditions.fromDives(Iterable<Dive> dives)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';

Dive _dive(
  String id, {
  double? waterTemp,
  double? visMeters,
  Visibility? vis,
  CurrentStrength? current,
}) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 8, 9),
  waterTemp: waterTemp,
  visibilityMeters: visMeters,
  visibility: vis,
  currentStrength: current,
);

void main() {
  test('no dives or no logged conditions is empty', () {
    expect(DayConditions.fromDives(const []).isEmpty, isTrue);
    expect(DayConditions.fromDives([_dive('a')]).isEmpty, isTrue);
  });

  test('water temperature is the range of the dives that logged one', () {
    final c = DayConditions.fromDives([
      _dive('a', waterTemp: 28),
      _dive('b'),
      _dive('c', waterTemp: 26),
    ]);
    expect(c.minWaterTemp, 26);
    expect(c.maxWaterTemp, 28);
    expect(c.isEmpty, isFalse);
  });

  test('measured visibility is a range and ignores legacy buckets', () {
    final c = DayConditions.fromDives([
      _dive('a', visMeters: 20),
      _dive('b', visMeters: 12),
      _dive('c', vis: Visibility.poor),
    ]);
    expect(c.minVisibilityMeters, 12);
    expect(c.maxVisibilityMeters, 20);
    expect(c.legacyVisibility, isNull);
  });

  test('legacy visibility shows only when every bucketed dive agrees', () {
    expect(
      DayConditions.fromDives([
        _dive('a', vis: Visibility.good),
        _dive('b', vis: Visibility.good),
        _dive('c', vis: Visibility.unknown),
      ]).legacyVisibility,
      VisibilityBand.good,
    );
    expect(
      DayConditions.fromDives([
        _dive('a', vis: Visibility.good),
        _dive('b', vis: Visibility.poor),
      ]).legacyVisibility,
      isNull,
    );
    expect(
      DayConditions.fromDives([_dive('a', vis: Visibility.unknown)]).isEmpty,
      isTrue,
    );
  });

  test('current is the weakest to strongest logged', () {
    final c = DayConditions.fromDives([
      _dive('a', current: CurrentStrength.moderate),
      _dive('b', current: CurrentStrength.light),
      _dive('c', current: CurrentStrength.strong),
    ]);
    expect(c.minCurrent, CurrentStrength.light);
    expect(c.maxCurrent, CurrentStrength.strong);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/domain/services/day_conditions_test.dart`
Expected: FAIL, `day_conditions.dart` not found.

- [ ] **Step 3: Implement**

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The water a day's dives met: temperature, visibility and current, each as
/// the range across the dives that logged it.
///
/// Visibility comes in two shapes. Dives logged from v144 carry a measured
/// distance, which wins whenever any dive of the day has one. Older dives
/// carry only a coarse bucket, which can be shown only when every bucketed
/// dive agrees: two buckets have no honest range between them.
class DayConditions extends Equatable {
  final double? minWaterTemp; // celsius
  final double? maxWaterTemp; // celsius
  final double? minVisibilityMeters;
  final double? maxVisibilityMeters;
  final VisibilityBand? legacyVisibility;
  final CurrentStrength? minCurrent;
  final CurrentStrength? maxCurrent;

  const DayConditions({
    this.minWaterTemp,
    this.maxWaterTemp,
    this.minVisibilityMeters,
    this.maxVisibilityMeters,
    this.legacyVisibility,
    this.minCurrent,
    this.maxCurrent,
  });

  factory DayConditions.fromDives(Iterable<Dive> dives) {
    double? minTemp, maxTemp, minVis, maxVis;
    CurrentStrength? minCurrent, maxCurrent;
    final buckets = <VisibilityBand>{};
    for (final dive in dives) {
      final temp = dive.waterTemp;
      if (temp != null) {
        if (minTemp == null || temp < minTemp) minTemp = temp;
        if (maxTemp == null || temp > maxTemp) maxTemp = temp;
      }
      final vis = dive.visibilityMeters;
      if (vis != null) {
        if (minVis == null || vis < minVis) minVis = vis;
        if (maxVis == null || vis > maxVis) maxVis = vis;
      }
      final band = _legacyBand(dive.visibility);
      if (band != null) buckets.add(band);
      final current = dive.currentStrength;
      if (current != null) {
        if (minCurrent == null || current.index < minCurrent.index) {
          minCurrent = current;
        }
        if (maxCurrent == null || current.index > maxCurrent.index) {
          maxCurrent = current;
        }
      }
    }
    return DayConditions(
      minWaterTemp: minTemp,
      maxWaterTemp: maxTemp,
      minVisibilityMeters: minVis,
      maxVisibilityMeters: maxVis,
      legacyVisibility: minVis == null && buckets.length == 1
          ? buckets.single
          : null,
      minCurrent: minCurrent,
      maxCurrent: maxCurrent,
    );
  }

  bool get isEmpty =>
      minWaterTemp == null &&
      minVisibilityMeters == null &&
      legacyVisibility == null &&
      minCurrent == null;

  static VisibilityBand? _legacyBand(Visibility? visibility) =>
      switch (visibility) {
        Visibility.excellent => VisibilityBand.excellent,
        Visibility.good => VisibilityBand.good,
        Visibility.moderate => VisibilityBand.moderate,
        Visibility.poor => VisibilityBand.poor,
        Visibility.unknown || null => null,
      };

  @override
  List<Object?> get props => [
    minWaterTemp,
    maxWaterTemp,
    minVisibilityMeters,
    maxVisibilityMeters,
    legacyVisibility,
    minCurrent,
    maxCurrent,
  ];
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/domain/services/day_conditions_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/services/day_conditions.dart test/features/trips/domain/services/day_conditions_test.dart
git commit -m "feat(trips): aggregate a day's water conditions"
```

---

### Task 3: Day kind and plan progress

**Files:**
- Modify: `lib/features/trips/domain/services/trip_dive_days.dart`
- Modify: `lib/features/trips/domain/services/trip_story_builder.dart` (lines ~141-147)
- Create: `lib/features/trips/domain/services/day_plan_progress.dart`
- Test: `test/features/trips/domain/services/trip_dive_days_test.dart`, `test/features/trips/domain/services/day_plan_progress_test.dart`

**Interfaces:**
- Produces: `TripStoryDayKind tripDayKind(DateTime date, DateTime now)`; `class DayPlanProgress { final int planned; final int logged; final bool upcoming; }`; `DayPlanProgress? dayPlanProgress({required ItineraryDay? row, required int logged, required TripStoryDayKind kind})`.

- [ ] **Step 1: Write the failing tests**

Append to `trip_dive_days_test.dart`:

```dart
  group('tripDayKind', () {
    final now = DateTime(2026, 3, 8, 23, 30);
    test('compares calendar days, not instants', () {
      expect(tripDayKind(DateTime(2026, 3, 7, 23, 59), now), TripStoryDayKind.past);
      expect(tripDayKind(DateTime(2026, 3, 8), now), TripStoryDayKind.today);
      expect(tripDayKind(DateTime(2026, 3, 9), now), TripStoryDayKind.future);
    });
  });
```

(import `trip_story_day.dart` for the enum.) Create `day_plan_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';

ItineraryDay _row(int? planned) => ItineraryDay(
  id: 'r',
  tripId: 't',
  dayNumber: 1,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  plannedDives: planned,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('no row, a derived plan or a planned rest day has no progress', () {
    for (final row in [null, _row(null), _row(0)]) {
      expect(
        dayPlanProgress(row: row, logged: 1, kind: TripStoryDayKind.past),
        isNull,
      );
    }
  });

  test('past and today report logged against planned', () {
    for (final kind in [TripStoryDayKind.past, TripStoryDayKind.today]) {
      final p = dayPlanProgress(row: _row(3), logged: 4, kind: kind)!;
      expect((p.planned, p.logged, p.upcoming), (3, 4, false));
    }
  });

  test('a future day is upcoming', () {
    final p = dayPlanProgress(
      row: _row(2),
      logged: 0,
      kind: TripStoryDayKind.future,
    )!;
    expect(p.upcoming, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/domain/services/trip_dive_days_test.dart test/features/trips/domain/services/day_plan_progress_test.dart`
Expected: FAIL, symbols not defined.

- [ ] **Step 3: Implement**

In `trip_dive_days.dart` (import `trip_story_day.dart`):

```dart
/// Where the calendar day of [date] sits relative to the calendar day of
/// [now]. Both are compared date-only, so a dive at 23:59 yesterday is past.
TripStoryDayKind tripDayKind(DateTime date, DateTime now) {
  final day = tripDay(date);
  final today = tripDay(now);
  if (day.isBefore(today)) return TripStoryDayKind.past;
  if (day.isAfter(today)) return TripStoryDayKind.future;
  return TripStoryDayKind.today;
}
```

In `trip_story_builder.dart`, replace the `if (date.isBefore(todayDate)) ... else ...` kind block with `final kind = tripDayKind(date, todayDate);` (drop the now-unused `kind` declaration lines). Create `day_plan_progress.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// A day's plan against what was logged. [upcoming] days have nothing logged
/// yet, so they read as a plan; past days and today read as progress, which
/// lets the diver compare plan and reality afterwards.
class DayPlanProgress extends Equatable {
  final int planned;
  final int logged;
  final bool upcoming;

  const DayPlanProgress({
    required this.planned,
    required this.logged,
    required this.upcoming,
  });

  @override
  List<Object?> get props => [planned, logged, upcoming];
}

/// The plan to show for a day, or null when there is none to show: no
/// itinerary row, a derived plan (null), or a planned rest day (0), which the
/// story already labels a surface day.
DayPlanProgress? dayPlanProgress({
  required ItineraryDay? row,
  required int logged,
  required TripStoryDayKind kind,
}) {
  final planned = row?.plannedDives;
  if (planned == null || planned <= 0) return null;
  return DayPlanProgress(
    planned: planned,
    logged: logged,
    upcoming: kind == TripStoryDayKind.future,
  );
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/domain/services/`
Expected: PASS (including `trip_story_builder_test.dart`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/services/trip_dive_days.dart lib/features/trips/domain/services/trip_story_builder.dart lib/features/trips/domain/services/day_plan_progress.dart test/features/trips/domain/services/trip_dive_days_test.dart test/features/trips/domain/services/day_plan_progress_test.dart
git commit -m "feat(trips): day kind and plan progress helpers"
```

---

### Task 4: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files), generated `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces (generated): `trips_day_planProgress(int logged, int planned)`, `trips_day_valueRange(String from, String to)`, `trips_day_conditionWater(String value)`, `trips_day_conditionVisibility(String value)`, `trips_day_conditionCurrent(String value)`, `trips_day_photoCount(int count)`, `trips_day_speciesCount(int count)`.

- [ ] **Step 1: Insert the English keys** surgically (no JSON round trip of `app_en.arb`), directly after the `trips_dayType_*` block or the nearest `trips_d...` key so the file stays sorted:

```json
  "trips_day_conditionCurrent": "Current {value}",
  "@trips_day_conditionCurrent": {"placeholders": {"value": {"type": "String"}}},
  "trips_day_conditionVisibility": "Vis {value}",
  "@trips_day_conditionVisibility": {"placeholders": {"value": {"type": "String"}}},
  "trips_day_conditionWater": "Water {value}",
  "@trips_day_conditionWater": {"placeholders": {"value": {"type": "String"}}},
  "trips_day_photoCount": "{count, plural, one{{count} photo} other{{count} photos}}",
  "@trips_day_photoCount": {"placeholders": {"count": {"type": "int"}}},
  "trips_day_planProgress": "{planned, plural, one{{logged} of {planned} planned dive} other{{logged} of {planned} planned dives}}",
  "@trips_day_planProgress": {"placeholders": {"logged": {"type": "int"}, "planned": {"type": "int"}}},
  "trips_day_speciesCount": "{count, plural, one{{count} species} other{{count} species}}",
  "@trips_day_speciesCount": {"placeholders": {"count": {"type": "int"}}},
  "trips_day_valueRange": "{from} to {to}",
  "@trips_day_valueRange": {"placeholders": {"from": {"type": "String"}, "to": {"type": "String"}}},
```

- [ ] **Step 2: Insert translations** in the 10 locale ARBs, after their `trips_itinerary_plannedDives` line (`grep -n '"trips_itinerary_plannedDives"' lib/l10n/arb/app_*.arb` must hit all 11). No `@` entries in locale files. Before inserting, read each locale's `trips_itinerary_plannedDives` and align the words for "dive" and "planned" with it:

| key | ar | de | es | fr | he |
| --- | --- | --- | --- | --- | --- |
| conditionCurrent | `التيار {value}` | `Strömung {value}` | `Corriente {value}` | `Courant {value}` | `זרם {value}` |
| conditionVisibility | `الرؤية {value}` | `Sicht {value}` | `Visibilidad {value}` | `Visibilité {value}` | `ראות {value}` |
| conditionWater | `الماء {value}` | `Wasser {value}` | `Agua {value}` | `Eau {value}` | `מים {value}` |
| photoCount | `{count, plural, one{{count} صورة} other{{count} صور}}` | `{count, plural, one{{count} Foto} other{{count} Fotos}}` | `{count, plural, one{{count} foto} other{{count} fotos}}` | `{count, plural, one{{count} photo} other{{count} photos}}` | `{count, plural, one{{count} תמונה} other{{count} תמונות}}` |
| planProgress | `{planned, plural, other{{logged} من {planned} غطسات مخططة}}` | `{planned, plural, one{{logged} von {planned} geplanten Tauchgang} other{{logged} von {planned} geplanten Tauchgängen}}` | `{planned, plural, one{{logged} de {planned} inmersión planificada} other{{logged} de {planned} inmersiones planificadas}}` | `{planned, plural, one{{logged} sur {planned} plongée prévue} other{{logged} sur {planned} plongées prévues}}` | `{planned, plural, other{{logged} מתוך {planned} צלילות מתוכננות}}` |
| speciesCount | `{count, plural, one{{count} نوع} other{{count} أنواع}}` | `{count, plural, one{{count} Art} other{{count} Arten}}` | `{count, plural, one{{count} especie} other{{count} especies}}` | `{count, plural, one{{count} espèce} other{{count} espèces}}` | `{count, plural, one{{count} מין} other{{count} מינים}}` |
| valueRange | `{from} إلى {to}` | `{from} bis {to}` | `{from} a {to}` | `{from} à {to}` | `{from} עד {to}` |

| key | hu | it | nl | pt | zh |
| --- | --- | --- | --- | --- | --- |
| conditionCurrent | `Áramlás {value}` | `Corrente {value}` | `Stroming {value}` | `Corrente {value}` | `水流 {value}` |
| conditionVisibility | `Látótáv {value}` | `Visibilità {value}` | `Zicht {value}` | `Visibilidade {value}` | `能见度 {value}` |
| conditionWater | `Víz {value}` | `Acqua {value}` | `Water {value}` | `Água {value}` | `水温 {value}` |
| photoCount | `{count, plural, other{{count} fotó}}` | `{count, plural, other{{count} foto}}` | `{count, plural, one{{count} foto} other{{count} foto's}}` | `{count, plural, one{{count} foto} other{{count} fotos}}` | `{count, plural, other{{count} 张照片}}` |
| planProgress | `{planned, plural, other{{logged} / {planned} tervezett merülés}}` | `{planned, plural, one{{logged} di {planned} immersione pianificata} other{{logged} di {planned} immersioni pianificate}}` | `{planned, plural, one{{logged} van {planned} geplande duik} other{{logged} van {planned} geplande duiken}}` | `{planned, plural, one{{logged} de {planned} mergulho planejado} other{{logged} de {planned} mergulhos planejados}}` | `{planned, plural, other{已完成 {logged} 次，计划 {planned} 次潜水}}` |
| speciesCount | `{count, plural, other{{count} faj}}` | `{count, plural, other{{count} specie}}` | `{count, plural, one{{count} soort} other{{count} soorten}}` | `{count, plural, one{{count} espécie} other{{count} espécies}}` | `{count, plural, other{{count} 个物种}}` |
| valueRange | `{from}–{to}` | `da {from} a {to}` | `{from} tot {to}` | `{from} a {to}` | `{from} 至 {to}` |

Build each line with `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))` in a python3.14 script kept in the scratchpad, then `json.load` every file.

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n && git diff --numstat -- lib/l10n/arb && grep -A2 "trips_day_conditionWater" lib/l10n/arb/app_localizations_de.dart && flutter test test/l10n/`
Expected: 14 added / 0 removed in `app_en.arb`, 7 / 0 in each locale ARB; the German getter body says `Wasser`; l10n tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(trips): strings for day plan, conditions and media counts"
```

---

### Task 5: Shared day widgets

**Files:**
- Create: `lib/features/trips/presentation/widgets/day/{today_chip,day_weather_badge,day_conditions_line,day_plan_line,day_format}.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart` (use `DayWeatherBadge`), `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart` (`_DayStatStrip` uses `formatDayRuntime`)
- Test: `test/features/trips/presentation/widgets/day/day_widgets_test.dart`

**Interfaces:**
- Consumes: `DayConditions` (Task 2), `DayPlanProgress` (Task 3), `TripStoryDayWeather` (Task 1), l10n keys (Task 4).
- Produces: `TodayChip()` (key `Key('today-chip')`); `DayWeatherBadge({required TripStoryDayWeather weather, required UnitFormatter units, Color? color})`, with `static bool rendersAnything(TripStoryDayWeather? weather)`; `DayConditionsLine({required DayConditions conditions, required UnitFormatter units})` (key `Key('day-conditions-line')`, renders nothing when empty); `DayPlanLine({required DayPlanProgress progress, TextStyle? style})`; `String formatDayRuntime(Duration runtime)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_conditions_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_plan_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

const _metric = UnitFormatter(AppSettings());

void main() {
  test('runtime reads hours and minutes', () {
    expect(formatDayRuntime(const Duration(minutes: 102)), '1h 42m');
    expect(formatDayRuntime(const Duration(minutes: 45)), '45m');
  });

  testWidgets('today chip says Today', (tester) async {
    await _pump(tester, const TodayChip());
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('conditions line shows ranges and single values', (tester) async {
    await _pump(
      tester,
      const DayConditionsLine(
        conditions: DayConditions(
          minWaterTemp: 26,
          maxWaterTemp: 28,
          legacyVisibility: VisibilityBand.good,
          minCurrent: CurrentStrength.light,
          maxCurrent: CurrentStrength.light,
        ),
        units: _metric,
      ),
    );
    final text = tester.widget<Text>(find.byKey(const Key('day-conditions-line')));
    expect(text.data, contains('Water 26'));
    expect(text.data, contains(' to 28'));
    expect(text.data, contains('Vis Good'));
    expect(text.data, contains('Current Light'));
    expect(text.data, isNot(contains('Light to Light')));
  });

  testWidgets('conditions line follows imperial units', (tester) async {
    final imperial = UnitFormatter(
      const AppSettings().copyWith(
        temperatureUnit: TemperatureUnit.fahrenheit,
        depthUnit: DepthUnit.feet,
      ),
    );
    await _pump(
      tester,
      DayConditionsLine(
        conditions: const DayConditions(
          minWaterTemp: 26,
          maxWaterTemp: 26,
          minVisibilityMeters: 12,
          maxVisibilityMeters: 20,
        ),
        units: imperial,
      ),
    );
    final text = tester.widget<Text>(find.byKey(const Key('day-conditions-line')));
    expect(text.data, contains('°F'));
    expect(text.data, contains('ft'));
    expect(text.data, isNot(contains('°C')));
  });

  testWidgets('empty conditions render nothing', (tester) async {
    await _pump(
      tester,
      const DayConditionsLine(conditions: DayConditions(), units: _metric),
    );
    expect(find.byKey(const Key('day-conditions-line')), findsNothing);
  });

  testWidgets('plan line reads progress, or a plan when upcoming', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          DayPlanLine(
            progress: DayPlanProgress(planned: 3, logged: 4, upcoming: false),
          ),
          DayPlanLine(
            progress: DayPlanProgress(planned: 1, logged: 0, upcoming: false),
          ),
          DayPlanLine(
            progress: DayPlanProgress(planned: 2, logged: 0, upcoming: true),
          ),
        ],
      ),
    );
    expect(find.text('4 of 3 planned dives'), findsOneWidget);
    expect(find.text('0 of 1 planned dive'), findsOneWidget);
    expect(find.text('2 dives planned'), findsOneWidget);
  });

  testWidgets('weather badge shows the air temperature', (tester) async {
    await _pump(
      tester,
      const DayWeatherBadge(
        weather: TripStoryDayWeather(airTemp: 29),
        units: _metric,
      ),
    );
    expect(find.textContaining('29'), findsOneWidget);
  });
}
```

Before running, check how `UnitFormatter` and the settings type are constructed (`sed -n 1,23p lib/core/utils/unit_formatter.dart`, `grep -n "class AppSettings" -r lib/features/settings`) and where `TemperatureUnit`/`DepthUnit` live; adjust the `_metric` / `imperial` construction to match (if the constructor is not const, make them `final` locals inside each test).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/day/day_widgets_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement**

`day_format.dart`:

```dart
/// A day's time in the water as "1h 42m", or "45m" under an hour.
String formatDayRuntime(Duration runtime) => runtime.inHours > 0
    ? '${runtime.inHours}h ${runtime.inMinutes % 60}m'
    : '${runtime.inMinutes}m';
```

`today_chip.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// "Today" marker for the current trip day, filled in the primary colour so it
/// reads on a plain card and on today's tinted header alike.
class TodayChip extends StatelessWidget {
  const TodayChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      key: const Key('today-chip'),
      label: Text(context.l10n.trips_story_today),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: colorScheme.primary,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
```

`day_weather_badge.dart`: move `_weatherBadge` and `_conditionsLabel` out of `TripStoryDayHeader` into:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/weather_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Conditions icon plus air temperature in the diver's unit. Wind, humidity
/// and the free-text description stay out of this compact badge on purpose.
class DayWeatherBadge extends StatelessWidget {
  final TripStoryDayWeather weather;
  final UnitFormatter units;

  /// Foreground for icon and text; defaults to onSurfaceVariant.
  final Color? color;

  const DayWeatherBadge({
    super.key,
    required this.weather,
    required this.units,
    this.color,
  });

  /// Whether a badge for [weather] would draw anything at all.
  static bool rendersAnything(TripStoryDayWeather? weather) =>
      weather != null &&
      (weather.airTemp != null ||
          weatherIconFor(
                cloudCover: weather.cloudCover,
                precipitation: weather.precipitation,
              ) !=
              null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    final icon = weatherIconFor(
      cloudCover: weather.cloudCover,
      precipitation: weather.precipitation,
    );
    final airTemp = weather.airTemp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 16,
            color: foreground,
            semanticLabel: _conditionsLabel(context.l10n),
          ),
        if (airTemp != null)
          Text(
            units.formatTemperature(airTemp),
            style: theme.textTheme.bodySmall?.copyWith(color: foreground),
          ),
      ],
    );
  }

  /// Localized name of what the icon depicts, for screen readers. Mirrors
  /// [weatherIconFor]: active precipitation first, then cloud cover.
  String? _conditionsLabel(AppLocalizations l10n) {
    final precipitation = weather.precipitation;
    if (precipitation != null && precipitation != Precipitation.none) {
      return precipitation.localizedName(l10n);
    }
    return weather.cloudCover?.localizedName(l10n);
  }
}
```

In the header, replace `final weatherBadge = _weatherBadge(...)` with
`final weatherBadge = DayWeatherBadge.rendersAnything(weather) ? DayWeatherBadge(weather: weather!, units: units) : null;`, delete the two moved methods, and drop the now-unused imports.

`day_conditions_line.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One muted line: water temperature, visibility and current for a day, each
/// part only when some dive logged it, each a range when the dives differ.
class DayConditionsLine extends StatelessWidget {
  final DayConditions conditions;
  final UnitFormatter units;

  const DayConditionsLine({
    super.key,
    required this.conditions,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    if (conditions.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final c = conditions;
    final parts = <String>[
      if (c.minWaterTemp != null)
        l10n.trips_day_conditionWater(
          _range(
            l10n,
            units.formatTemperature(c.minWaterTemp, decimals: 0),
            units.formatTemperature(c.maxWaterTemp, decimals: 0),
          ),
        ),
      if (c.minVisibilityMeters != null)
        l10n.trips_day_conditionVisibility(
          _range(
            l10n,
            units.formatDistance(c.minVisibilityMeters!),
            units.formatDistance(c.maxVisibilityMeters!),
          ),
        )
      else if (c.legacyVisibility != null)
        l10n.trips_day_conditionVisibility(
          visibilityBandName(c.legacyVisibility!, l10n),
        ),
      if (c.minCurrent != null)
        l10n.trips_day_conditionCurrent(
          _range(
            l10n,
            c.minCurrent!.localizedName(l10n),
            c.maxCurrent!.localizedName(l10n),
          ),
        ),
    ];
    final theme = Theme.of(context);
    return Text(
      parts.join(' · '),
      key: const Key('day-conditions-line'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// One value when both ends read the same once formatted, so 26.2 and 26.4
  /// at whole degrees do not print "26 to 26".
  static String _range(AppLocalizations l10n, String from, String to) =>
      from == to ? from : l10n.trips_day_valueRange(from, to);
}
```

Confirm the `CurrentStrength` display extension's method name with `sed -n 25,40p lib/features/dive_log/presentation/widgets/environment_enum_display.dart` and use it. Check `formatDistance` reads in the depth unit (`sed -n 135,150p lib/core/utils/unit_formatter.dart`); if it is not the depth unit, use `units.formatDepth(meters, decimals: 0)` instead (visibility displays in the depth unit elsewhere, see `formatMeasuredVisibility`).

`day_plan_line.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "2 of 3 planned dives" for a day under way or done, "3 dives planned" for
/// a day ahead.
class DayPlanLine extends StatelessWidget {
  final DayPlanProgress progress;
  final TextStyle? style;

  const DayPlanLine({super.key, required this.progress, this.style});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Text(
      progress.upcoming
          ? l10n.trips_itinerary_plannedDives(progress.planned)
          : l10n.trips_day_planProgress(progress.logged, progress.planned),
      style:
          style ??
          theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
    );
  }
}
```

If the generated `trips_day_planProgress` signature orders its parameters differently, follow the generated signature; the rendered-text test is the check.

In `trip_story_day_card.dart` `_DayStatStrip`, replace the inline `runtimeLabel` computation with `formatDayRuntime(day.totalRuntime)`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/day/ test/features/trips/presentation/widgets/story/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/day/ lib/features/trips/presentation/widgets/story/trip_story_day_header.dart lib/features/trips/presentation/widgets/story/trip_story_day_card.dart test/features/trips/presentation/widgets/day/
git commit -m "feat(trips): shared day widgets for weather, conditions, plan and today"
```

---

### Task 6: Today's header on the Overview

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`

**Interfaces:**
- Consumes: `TodayChip`, `DayWeatherBadge` (Task 5).

- [ ] **Step 1: Write the failing tests** (add `ThemeData? theme` to `pumpHeader`, passed to `MaterialApp(theme: theme)`)

```dart
  group('today', () {
    final today = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.today,
    );

    testWidgets('band is primaryContainer with a Today chip', (tester) async {
      await pumpHeader(tester, today);
      final context = tester.element(find.byType(TripStoryDayHeader));
      final scheme = Theme.of(context).colorScheme;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TripStoryDayHeader),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, scheme.primaryContainer);
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
    });

    testWidgets('date reads onPrimaryContainer in a dark theme', (tester) async {
      await pumpHeader(
        tester,
        today,
        theme: ThemeData(brightness: Brightness.dark),
      );
      final context = tester.element(find.byType(TripStoryDayHeader));
      final date = tester.widget<Text>(find.text('Sun, Mar 8'));
      expect(date.style?.color, Theme.of(context).colorScheme.onPrimaryContainer);
    });

    testWidgets('other days keep the grey band and no chip', (tester) async {
      await pumpHeader(
        tester,
        TripStoryDay(
          date: DateTime(2026, 3, 8),
          dayNumber: 2,
          kind: TripStoryDayKind.past,
        ),
      );
      expect(find.byKey(const Key('today-chip')), findsNothing);
    });
  });
```

Use the exact date text the existing `'shows the day number badge and date'` test asserts.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`
Expected: FAIL on band colour and chip.

- [ ] **Step 3: Implement**

In `build`: `final isToday = day.kind == TripStoryDayKind.today;` and `final tinted = isToday && !compact;`. Band colour: `compact ? Colors.transparent : (isToday ? scheme.primaryContainer : scheme.surfaceContainer)`. Date style colour: `tinted ? scheme.onPrimaryContainer : null`. Subtitle colour: `tinted ? scheme.onPrimaryContainer.withValues(alpha: 0.8) : scheme.onSurfaceVariant`. Pass `color: tinted ? scheme.onPrimaryContainer : null` to `DayWeatherBadge`. After the weather badge add `if (isToday) ...[const SizedBox(width: 8), const TodayChip()]`. Pass `highlighted: tinted` to `_DayNumberBadge`, which uses `primary`/`onPrimary` when highlighted and `primaryContainer`/`onPrimaryContainer` otherwise. Update the class doc comment to describe today's band.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/trip_story_day_header.dart test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart
git commit -m "feat(trips): tint today's day header on the trip story"
```

---

### Task 7: Overview card: today outline, plan section, conditions

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_plan.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`

**Interfaces:**
- Consumes: `dayPlanProgress`, `DayPlanLine`, `DayConditions`, `DayConditionsLine`.
- Produces: `TripStoryDayPlan({required TripStoryDay day, required UnitFormatter units})` and `static bool TripStoryDayPlan.hasContent(TripStoryDay day)`.

- [ ] **Step 1: Write the failing tests** (append to the card test)

```dart
  group('plan and conditions', () {
    ItineraryDay planned(int dives, {String notes = ''}) =>
        _itin(notes: notes).copyWith(plannedDives: dives);

    testWidgets('today with no dives shows its notes and plan', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(3, notes: 'Two-tank boat dive'),
      );
      await pumpCard(tester, day);
      expect(find.text('Two-tank boat dive'), findsOneWidget);
      expect(find.text('0 of 3 planned dives'), findsOneWidget);
    });

    testWidgets("today's card has a primary outline", (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(2),
      );
      await pumpCard(tester, day);
      final card = tester.widget<Card>(find.byType(Card).first);
      final context = tester.element(find.byType(TripStoryDayCard));
      final side = (card.shape! as RoundedRectangleBorder).side;
      expect(side.color, Theme.of(context).colorScheme.primary);
      expect(side.width, 2);
    });

    testWidgets('a past day compares logged with planned', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: planned(3, notes: 'Reef day'),
        dives: _pastDay(['d1', 'd2', 'd3', 'd4']).dives,
      );
      await pumpCard(tester, day);
      expect(find.text('Reef day'), findsOneWidget);
      expect(find.text('4 of 3 planned dives'), findsOneWidget);
    });

    testWidgets('a planned rest day shows no plan line', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(0, notes: 'Rest'),
      );
      await pumpCard(tester, day);
      expect(find.textContaining('planned dive'), findsNothing);
      expect(find.text('Rest'), findsOneWidget);
    });

    testWidgets('dives with conditions show the conditions line', (
      tester,
    ) async {
      final base = _pastDay(['d1']);
      final day = TripStoryDay(
        date: base.date,
        dayNumber: base.dayNumber,
        kind: base.kind,
        dives: [base.dives.single.copyWith(waterTemp: 27)],
      );
      await pumpCard(tester, day);
      expect(find.byKey(const Key('day-conditions-line')), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`
Expected: the new tests FAIL (today with no dives renders nothing; no outline; no plan text).

- [ ] **Step 3: Implement**

Create `trip_story_day_plan.dart`, moving `_PlannedExtras` and `_HistoryPills` out of the card:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_plan_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The plan part of a story day card, on every day: the itinerary notes, the
/// planned dives (as progress once the day has come), and, for a day ahead,
/// the diver's history at its port or site.
class TripStoryDayPlan extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const TripStoryDayPlan({super.key, required this.day, required this.units});

  /// Whether the section would draw anything. Blank is not content: sync and
  /// import payloads can write whitespace-only notes or ports, which the edit
  /// sheet would have normalized away.
  static bool hasContent(TripStoryDay day) {
    final itinerary = day.itineraryDay;
    final isFuture = day.kind == TripStoryDayKind.future;
    return (itinerary?.notes.trim().isNotEmpty ?? false) ||
        _progress(day) != null ||
        (isFuture && (itinerary?.portName?.trim().isNotEmpty ?? false));
  }

  static DayPlanProgress? _progress(TripStoryDay day) => dayPlanProgress(
    row: day.itineraryDay,
    logged: day.diveCount,
    kind: day.kind,
  );

  @override
  Widget build(BuildContext context) {
    final itinerary = day.itineraryDay;
    final notes = itinerary?.notes.trim() ?? '';
    final portName = itinerary?.portName?.trim() ?? '';
    final progress = _progress(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (progress != null) ...[
          const SizedBox(height: 6),
          DayPlanLine(progress: progress),
        ],
        if (day.kind == TripStoryDayKind.future && portName.isNotEmpty)
          _HistoryPills(siteName: portName, units: units),
      ],
    );
  }
}
```

followed by `_HistoryPills` moved verbatim (with its imports). In the card:
- `final isToday = day.kind == TripStoryDayKind.today;`
- `hasBody` becomes `widget.mapPoints.isNotEmpty || day.dives.isNotEmpty || day.media.isNotEmpty || day.sightings.isNotEmpty || TripStoryDayPlan.hasContent(day)` (delete `hasPlannedExtras` and update the comment above it).
- `shape:` is `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary, width: 2))` when `isToday`, the existing outlineVariant border when `_isPlanned`, else null.
- Replace the trailing `if (_isPlanned) _PlannedExtras(...)` with `TripStoryDayPlan(day: day, units: units)` placed directly after the map block (before the summary band), so the plan reads first.
- In `_DaySummaryBand`, after the `DayRhythmBar`, add:

```dart
          if (!conditions.isEmpty) ...[
            const SizedBox(height: 8),
            DayConditionsLine(conditions: conditions, units: units),
          ],
```

with `final conditions = DayConditions.fromDives(day.dives);` at the top of its `build`.

Delete `_PlannedExtras` and `_HistoryPills` from the card file and drop unused imports.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/story/`
Expected: PASS. If an existing planned-day test asserted on order (notes after dives), update it to the new order and say so in the commit body.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/trip_story_day_plan.dart lib/features/trips/presentation/widgets/story/trip_story_day_card.dart test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart
git commit -m "feat(trips): plan and conditions on every story day card"
```

---

### Task 8: Overview opens at today

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: `story.todayIndex`.

- [ ] **Step 1: Write the failing tests** (replace `'in-progress trip shows a Today divider'`)

```dart
  group('in progress', () {
    TripStory longTrip({required int todayOffset}) {
      final now = DateTime.now();
      final today = _dayOnly(now);
      final trip = _trip(
        start: today.subtract(Duration(days: todayOffset)),
        end: today.add(const Duration(days: 3)),
      );
      return _story(
        trip,
        today: now,
        dives: [
          for (var i = 0; i <= todayOffset; i++)
            _dive('d$i', today.subtract(Duration(days: todayOffset - i))),
        ],
      );
    }

    testWidgets('opens with today at the top', (tester) async {
      final story = longTrip(todayOffset: 9);
      await pumpView(tester, story, viewSize: const Size(800, 900));
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      final chipTop = tester.getTopLeft(find.byKey(const Key('today-chip'))).dy;
      expect(chipTop, lessThan(120));
      expect(find.byType(TripStoryHero), findsNothing);
    });

    testWidgets('earlier days and the hero are above, by scrolling up', (
      tester,
    ) async {
      final story = longTrip(todayOffset: 9);
      await pumpView(tester, story, viewSize: const Size(800, 900));
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 20000),
        5000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TripStoryHero), findsOneWidget);
    });

    testWidgets('today on Day 1 keeps the hero just above', (tester) async {
      final story = longTrip(todayOffset: 0);
      await pumpView(tester, story, viewSize: const Size(800, 900));
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(TripStoryHero), findsOneWidget);
    });

    testWidgets('a past trip still opens at the hero', (tester) async {
      final trip = _trip(
        start: DateTime(2026, 3, 27),
        end: DateTime(2026, 3, 28),
      );
      await pumpView(tester, _story(trip, today: DateTime(2026, 5, 1)));
      expect(find.byType(TripStoryHero), findsOneWidget);
      expect(find.byKey(const Key('today-chip')), findsNothing);
    });
  });
```

Also update `'past trip renders day chapters, hero, and stat strip'` only if it asserted on the divider. A `pumpAndSettle` may not settle with tile loading maps; if so, use `pump()` plus `pump(const Duration(seconds: 1))` as `pumpView` does.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: 'opens with today at the top' FAILS (hero is on screen, chip far down or not built).

- [ ] **Step 3: Implement**

In `_contentSlivers`, split into header slivers (hero, stat strip, cylinders, flight countdown, vessel), the days, and trailing slivers (notes card, bottom gap). Then:

```dart
    final todayIndex = story.todayIndex;
    if (todayIndex == null) {
      return [
        ...header,
        _daysSliver(context, 0, story.days.length, storedWeather),
        ...trailing,
      ];
    }
    // Opening at today: today's chapter is the scroll view's center, so
    // offset 0 is its top. Slivers before the center grow upward, nearest
    // first, so they are listed in reverse: the earlier days (themselves
    // reversed), then the header slivers bottom to top.
    return [
      SliverList.builder(
        itemCount: todayIndex,
        itemBuilder: (context, i) =>
            _dayChapter(context, todayIndex - 1 - i, storedWeather),
      ),
      ...header.reversed,
      _daysSliver(
        context,
        todayIndex,
        story.days.length,
        storedWeather,
        key: _todayKey,
      ),
      ...trailing,
    ];
```

with `static const _todayKey = ValueKey('trip-story-today');`, and in `build`: `CustomScrollView(center: story.todayIndex == null ? null : _todayKey, slivers: ...)`. `_daysSliver(context, from, to, storedWeather, {Key? key})` is the existing `SliverList.builder` generalized to the range `[from, to)` (item `i` is day `from + i`; `findChildIndexCallback` subtracts `from` and returns null outside the range). `_dayChapter` loses its `todayIndex` parameter and the divider; delete `_TodayDivider`. Update the class doc comment ("one plain scroll ... opening at today while the trip is under way").

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/trip_overview_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/trip_story_view.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "feat(trips): open the trip story at today while under way"
```

---

### Task 9: Move the itinerary card out of the tab

**Files:**
- Create: `lib/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart`, `lib/features/trips/presentation/widgets/itinerary/itinerary_dive_row.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`

**Interfaces:**
- Produces: `ItineraryDayCard({required ItineraryDay day, required List<Dive> dives, required String tripId, required bool isLiveaboard})`, `ItineraryDiveRow({required Dive dive, required UnitFormatter units})`.

- [ ] **Step 1: Move** `_ItineraryDayCard` (with `_dayTypeIcon`, `_dayTypeColor`) to `itinerary_day_card.dart` as public `ItineraryDayCard`, and `_DiveRow` to `itinerary_dive_row.dart` as public `ItineraryDiveRow`, unchanged apart from the names and the imports each file needs. The tab imports the card and drops imports it no longer uses.

- [ ] **Step 2: Verify nothing changed**

Run: `flutter analyze lib/features/trips && flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
Expected: no issues; PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/trips/presentation/widgets/itinerary/ lib/features/trips/presentation/widgets/trip_itinerary_tab.dart
git commit -m "refactor(trips): move the itinerary day card into its own file"
```

---

### Task 10: Richer itinerary cards

**Files:**
- Modify: `lib/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart`, `itinerary_dive_row.dart`, `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`
- Modify: `docs/design/specs/2026-10-10-trip-today-highlight-and-richer-day-cards-design.md` (data source note)
- Test: `test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`

**Interfaces:**
- Consumes: Tasks 1-5. `tripStoryProvider(tripId)`, `tripDayWeatherProvider(tripId)` (`Map<int, TripDayWeather>`, keyed by `tripDayMillis`), `TripDayWeather.toStoryWeather()`.
- Produces: `ItineraryDayCard` gains `required TripStoryDayKind kind`, `List<MediaItem> media = const []`, `List<Sighting> sightings = const []`, `TripStoryDayWeather? storedWeather`.

- [ ] **Step 1: Write the failing tests**

Extend `_pumpTab` with `TripStory? story` and `Map<int, TripDayWeather>? tripDayWeather` parameters: pass `tripDayWeather` to `getBaseOverrides(tripDayWeather: ...)` and add `tripStoryProvider('trip-1').overrideWith((ref) async => story ?? (throw StateError('no story')))` to the overrides. Then add:

```dart
  group('richer day cards', () {
    final day = _row('r', DateTime(2026, 3, 8), 3);
    Dive dive(String id, int hour, {double? temp, int minutes = 50}) => Dive(
      id: id,
      diveNumber: hour,
      dateTime: DateTime(2026, 3, 8, hour),
      runtime: Duration(minutes: minutes),
      maxDepth: 18 + hour.toDouble(),
      waterTemp: temp,
      airTemp: 29,
    );

    testWidgets('totals, conditions, weather and richer rows', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day],
          dives: [dive('a', 9, temp: 26), dive('b', 14, temp: 28)],
        );
      });
      expect(find.textContaining('2 dives'), findsOneWidget);
      expect(find.textContaining('1h 40m'), findsOneWidget);
      expect(find.byKey(const Key('day-conditions-line')), findsOneWidget);
      expect(find.textContaining('29'), findsWidgets); // air temp badge
      expect(find.text('50m'), findsNWidgets(2)); // per-row runtime
    });

    testWidgets('stored weather fills in when no dive logged any', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day],
          tripDayWeather: {
            tripDayMillis(day.date): TripDayWeather(
              id: tripDayWeatherId('trip-1', tripDayMillis(day.date)),
              tripId: 'trip-1',
              dayDate: tripDayMillis(day.date),
              airTemp: 31,
            ),
          },
        );
      });
      expect(find.textContaining('31'), findsOneWidget);
    });

    testWidgets('photos and species from the story', (tester) async {
      final trip = _resortTrip();
      final diveA = dive('a', 9);
      final story = buildTripStory(
        trip: trip,
        dives: [diveA],
        itineraryDays: [day],
        mediaByDiveId: {
          'a': [_photo('m1'), _photo('m2')],
        },
        sightingsByDiveId: {
          'a': [_sighting('s1', 'sp-1'), _sighting('s2', 'sp-1'), _sighting('s3', 'sp-2')],
        },
        checklistItems: const [],
        today: DateTime(2026, 3, 9),
      );
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(tester, trip: trip, days: [day], dives: [diveA], story: story);
      });
      expect(find.textContaining('2 photos'), findsOneWidget);
      expect(find.textContaining('2 species'), findsOneWidget);
    });

    testWidgets('today is tinted and says Today', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
        await _pumpTab(tester, trip: _resortTrip(), days: [day]);
      });
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      final card = tester.widget<Card>(find.byType(Card).first);
      final context = tester.element(find.byType(TripItineraryTab));
      expect(
        (card.shape! as RoundedRectangleBorder).side.color,
        Theme.of(context).colorScheme.primary,
      );
    });

    testWidgets('a past day compares logged with planned', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day.copyWith(plannedDives: 3)],
          dives: [dive('a', 9)],
        );
      });
      expect(find.text('1 of 3 planned dives'), findsOneWidget);
    });
  });
```

Add helpers `_photo(id)` and `_sighting(id, speciesId)` modelled on the story card test's `_media` and `_sighting`. Check `TripDayWeather`'s constructor (`sed -n 50,110p lib/features/trips/domain/entities/trip_day_weather.dart`) and fill only its required fields. Update the existing `'a past day does not claim its plan is still to come'` test: the past day now reads `'0 of 3 planned dives'` (assert that, and that `'3 dives planned'` is absent), and rename it to `'a past day reports its plan as progress'`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Implement**

In the tab's `_buildTimeline`: `final story = ref.watch(tripStoryProvider(tripId)).valueOrNull;` (best effort: loading or error means no media line), `final stored = ref.watch(tripDayWeatherProvider(tripId)).asData?.value ?? const <int, TripDayWeather>{};`, `final now = clock.now();`. For each row, `final storyDay = story?.days.firstWhereOrNull((d) => tripDay(d.date) == tripDay(day.date));` and pass:

```dart
        ItineraryDayCard(
          day: day,
          dives: dayDives,
          tripId: tripId,
          isLiveaboard: trip?.isLiveaboard ?? false,
          kind: tripDayKind(day.date, now),
          media: storyDay?.media ?? const [],
          sightings: storyDay?.sightings ?? const [],
          storedWeather: stored[tripDayMillis(day.date)]?.toStoryWeather(),
        )
```

In `ItineraryDayCard.build`:
- `final isToday = kind == TripStoryDayKind.today;`. The `Card` gets `color: isToday ? colorScheme.primaryContainer.withValues(alpha: 0.35) : null` and `shape: isToday ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorScheme.primary, width: 2)) : null`.
- Title row: wrap the "Day N" `Text` in a `Row(children: [Text(...), if (isToday) ...[const SizedBox(width: 8), const TodayChip()]])`.
- Date line: a `Row` of the date `Text` and, when `DayWeatherBadge.rendersAnything(weather)`, `const SizedBox(width: 8)` plus `DayWeatherBadge(weather: weather!, units: units)`, where `weather = TripStoryDayWeather.resolve(logged: diveDayWeather(dives), stored: storedWeather)`.
- Replace the planned-dives block with: `final progress = dayPlanProgress(row: day, logged: dives.length, kind: kind);` and, when non-null, the indented `DayPlanLine(progress: progress)`. Delete the old `clock.now()` comparison (and the `clock` / `tripDay` imports if unused).
- Replace the "N dives" label with a totals `Text` joining with `' · '`: `context.l10n.trips_itinerary_diveCount(dives.length)`, `formatDayRuntime(diveDayRuntime(dives))` when non-zero, and `units.formatDepth(diveDayMaxDepth(dives))` when non-null. Keep its primary, w600 style. Under it, `DayConditionsLine(conditions: DayConditions.fromDives(dives), units: units)` (padded top 2 when non-empty), then the dive rows.
- Media line, indented like the others, when `media.isNotEmpty || speciesCount > 0` (`speciesCount = sightings.map((s) => s.speciesId).toSet().length`): a `Row` with `Icon(Icons.photo_library_outlined, size: 14)` and a `Text` joining `trips_day_photoCount(media.length)` (when non-zero) and `trips_day_speciesCount(speciesCount)` (when non-zero) with `' · '`, in bodySmall onSurfaceVariant.

In `ItineraryDiveRow`, after the time: runtime (`formatDayRuntime(dive.runtime ?? dive.bottomTime!)` when either is non-null), then max depth (existing), then water temperature (`units.formatTemperature(dive.waterTemp, decimals: 0)` when non-null), each preceded by `SizedBox(width: 8)` and styled like the time.

In the spec's "Shared data (approach A)" section, replace "That story day supplies the dives, media, sightings, `kind` (past, today, future) and logged weather. The tab no longer groups `divesForTripProvider` itself." with "The tab keeps grouping `divesForTripProvider` for the dives (so it never waits on the story's checklist and media reads), and takes media and sightings from the story day as a best-effort enrichment. Today comes from `clock.now()`."

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/itinerary/ lib/features/trips/presentation/widgets/trip_itinerary_tab.dart test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart docs/design/specs/2026-10-10-trip-today-highlight-and-richer-day-cards-design.md
git commit -m "feat(trips): weather, totals, conditions and media on itinerary cards"
```

---

### Task 11: Itinerary opens at today

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`
- Test: `test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`

**Interfaces:**
- Produces: `int? itineraryAnchorIndex(List<ItineraryDay> days, DateTime now)` (top-level, in the tab file): index of the first row dated today or later, or null.

- [ ] **Step 1: Write the failing tests**

```dart
  group('opens at today', () {
    List<ItineraryDay> rows(List<int> days) => [
      for (final d in days) _row('r$d', DateTime(2026, 3, d), d),
    ];
    Trip longTrip() => Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 20),
      tripType: TripType.resort,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('anchor is the first row today or later', () {
      final now = DateTime(2026, 3, 10, 9);
      expect(itineraryAnchorIndex(rows([8, 10, 12]), now), 1);
      expect(itineraryAnchorIndex(rows([8, 11, 12]), now), 1); // gap
      expect(itineraryAnchorIndex(rows([8, 9]), now), isNull);
    });

    testWidgets('an in-progress trip opens with today on top', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 20; d++) d]),
        );
      });
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      expect(find.text('Day 1'), findsNothing);
      final top = tester.getTopLeft(find.byKey(const Key('today-chip'))).dy;
      expect(top, lessThan(150));
    });

    testWidgets('a trip that has ended opens at Day 1', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 4, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 20; d++) d]),
        );
      });
      expect(find.text('Day 1'), findsOneWidget);
    });
  });
```

Note `_pumpTab` sets an 800x2000 view; that fits about 20 short cards, so the in-progress test needs a shorter view. Add a `Size viewSize = const Size(800, 2000)` parameter to `_pumpTab` and pass `const Size(800, 700)` in both widget tests.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart`
Expected: FAIL, `itineraryAnchorIndex` undefined.

- [ ] **Step 3: Implement**

```dart
/// The row an in-progress trip opens on: the first dated today or later, so
/// a day without a row anchors on the next planned one. Null when every row
/// is in the past.
int? itineraryAnchorIndex(List<ItineraryDay> days, DateTime now) {
  final today = tripDay(now);
  final index = days.indexWhere((d) => !tripDay(d.date).isBefore(today));
  return index < 0 ? null : index;
}
```

Replace the `ListView.builder` with a `CustomScrollView` inside the same 16px padding (`SliverPadding`). Without an anchor (`trip == null || !trip.isInProgress` or a null index): `[if (header != null) SliverToBoxAdapter(child: header), SliverList.builder(itemCount: days.length, itemBuilder: (c, i) => card(i))]`. With an anchor `a`:

```dart
    // Opening at today: the anchor row's sliver is the center, so offset 0
    // is its top; slivers before it grow upward, nearest first.
    slivers = [
      SliverList.builder(itemCount: a, itemBuilder: (c, i) => card(a - 1 - i)),
      if (header != null) SliverToBoxAdapter(child: header),
      SliverList.builder(
        key: _anchorKey,
        itemCount: days.length - a,
        itemBuilder: (c, i) => card(a + i),
      ),
    ];
```

with `center: _anchorKey` (`const _anchorKey = ValueKey('itinerary-today')`). Apply the 16px horizontal padding with `SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: ...)` around each list, plus a 16px top gap sliver only in the unanchored form and a 16px bottom gap after the last list. `card(i)` is the `ItineraryDayCard` construction from Task 10, extracted to a local closure.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart test/features/trips/presentation/widgets/trip_detail_tabs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_itinerary_tab.dart test/features/trips/presentation/widgets/trip_itinerary_tab_test.dart
git commit -m "feat(trips): open the itinerary at today while under way"
```

---

### Task 12: Whole-branch checks

- [ ] **Step 1:** `dart format .` then `git status --short` (commit any formatting as `style: dart format`).
- [ ] **Step 2:** `flutter analyze --fatal-infos`. Expected: no issues.
- [ ] **Step 3:** `flutter test test/features/trips/ test/architecture/ test/shared/ test/l10n/` (log to the scratchpad). Expected: all PASS.
- [ ] **Step 4:** `rg -n "\x{2014}" lib/features/trips docs/design/specs/2026-10-10-* docs/design/plans/2026-10-10-*` returns nothing.
- [ ] **Step 5:** Check the line counts of the files touched (`wc -l`) stay under 800.
