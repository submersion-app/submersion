# Cumulative Ascent and Descent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A card on Insights > Profile that draws the diver's total descent and total ascent on a vertical scale against ocean depths and mountains, with a readout that says when the running total reached any level (issue #4569).

**Architecture:** Pure Dart in `insights/domain/vertical_distance/` works out one dive's vertical distance, the running total, the landmarks and the scale layout. A device-only cache table holds each dive's figure, keyed by a fingerprint of its primary profile rows; a repository part reads the scoped dives, fills cache misses on a worker isolate and returns a timeline. One card widget draws the scale and owns a three-state selection (idle, hovering, pinned) that drives a fixed readout strip.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite, `LocalCacheDatabase`), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-15-cumulative-ascent-descent-design.md`. Read "What was decided", "The per-dive figure", "The scale" and "The readout" before any task.

## Global Constraints

- Every figure a diver sees, landmark heights included, follows the active diver's depth unit. Storage and all domain code are in metres.
- The deadband is 1 m, a metric constant. It does not change with the display unit.
- No change to the library database (`AppDatabase`), sync, backup or export. The only schema change is `LocalCacheDatabase` 22 to 23.
- `lib/core/database/local_cache_database.dart` is at 784 lines; it must stay under 800. The new table and its `CREATE TABLE IF NOT EXISTS` text live in their own file.
- `insights_providers.dart` (913 lines) and `insights_repository.dart` (2,997 lines) gain no code beyond a `part` line. New code goes in new files.
- Stored dive times are decoded with `wallClockUtcFromMillis` (`lib/core/util/wall_clock_utc.dart`) and shown with `UnitFormatter.formatDate`. `test/architecture/` enforces both.
- Paths in tests are built with `p.join`. A test that replaces process-wide state (the `LocalCacheDatabaseService` test database) restores it in `tearDown`.
- No em-dashes anywhere. No emojis in code, comments or docs.
- Strings: every new key is added to `app_en.arb` and to all ten locale ARBs, inserted textually beside a neighbouring key of the same group, never by a JSON round trip. `flutter gen-l10n` is run again after the translations are in.
- Never run the whole test suite locally. Run the files named in each task, plus `test/architecture/` and `test/shared/` once new `lib/` files exist.
- Commits are `feat(insights): <summary>`, one per task, staged by explicit path.

## Review Focus

Inputs the spec implies and that are easy to leave untested. Each has a test in the task named.

1. **Imperial display.** A diver on feet sees every landmark, headline, readout and "to go" distance in feet with grouped digits, while the deadband and the stored values stay metric. Task 7.
2. **A profile stored as several series rows.** A dive whose primary stream arrived in two pieces must be interleaved and counted once, not as two dives. Task 6.
3. **Nothing to draw.** A filter that keeps no dives, or only dives with no depth, gives the empty state and never divides by a zero extent. Tasks 4 and 8.
4. **A very large total.** Past the last named landmark (1,000 km and beyond) the next landmark is found without walking the multiples, the passed list is finite, and the layout's labels still keep their gap. Tasks 3 and 4.
5. **Narrow and right-to-left.** At 320 logical pixels wide, and under an RTL locale, labels ellipsize or mirror; nothing overflows and the bars stay hittable. Task 8.

---

## File map

| File | Responsibility |
| --- | --- |
| `lib/features/insights/domain/vertical_distance/vertical_distance.dart` | One dive's vertical distance from its depths |
| `lib/features/insights/domain/vertical_distance/vertical_distance_timeline.dart` | Ordered per-dive figures, running total, crossing lookup |
| `lib/features/insights/domain/vertical_distance/vertical_landmarks.dart` | The two landmark lists, multiples, passed and next |
| `lib/features/insights/domain/vertical_distance/vertical_scale_layout.dart` | Extent, pixel mapping, marks, label thinning, snapping |
| `lib/features/insights/domain/vertical_distance/vertical_selection.dart` | The idle, hovering, pinned state machine |
| `lib/core/database/local_cache_vertical_distance_table.dart` | The cache table and its self-heal SQL |
| `lib/features/insights/data/repositories/vertical_distance_cache.dart` | Read and write access to the cache table |
| `lib/features/insights/data/repositories/insights_repository_vertical_distance.dart` | `part of` the repository: scoped dives, cache, misses, timeline |
| `lib/features/insights/presentation/providers/vertical_distance_providers.dart` | `verticalDistanceTimelineProvider` |
| `lib/features/insights/presentation/formatters/vertical_landmark_labels.dart` | A landmark's localized name |
| `lib/features/insights/presentation/widgets/vertical_distance/vertical_distance_card.dart` | The card: states, estimated note |
| `lib/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart` | The scale: layout, gestures, semantics |
| `lib/features/insights/presentation/widgets/vertical_distance/vertical_scale_painter.dart` | Bars, ticks, dashed marks, hairline |
| `lib/features/insights/presentation/widgets/vertical_distance/vertical_distance_strip.dart` | The readout strip |

Tests mirror these paths under `test/`.

---

### Task 0: Before screenshot

Not a code task. Before any code changes, capture Insights > Profile as it is today (light, desktop width, and phone width) and save the images in the session scratchpad as `01-insights-profile-before.png` and `01-insights-profile-before-phone.png`. The card is new, so there is no "before" of the card itself; these show the page it joins.

---

### Task 1: One dive's vertical distance

**Files:**
- Create: `lib/features/insights/domain/vertical_distance/vertical_distance.dart`
- Test: `test/features/insights/domain/vertical_distance/vertical_distance_test.dart`

**Interfaces:**
- Produces:
  - `const double verticalDistanceDeadbandMeters = 1.0;`
  - `const int verticalDistanceAlgorithmVersion = 1;`
  - `double verticalDistanceMeters(Iterable<double> depths, {double deadband = verticalDistanceDeadbandMeters})`

- [ ] **Step 1: Write the failing tests.** Each expected value is worked out by hand in a comment beside it.

```dart
test('a simple dive counts its max depth', () {
  expect(verticalDistanceMeters([0, 5, 12, 20, 20, 14, 6, 0]), 20);
});
test('a multi-level dive counts the second descent', () {
  // 0 -> 30 (30), up to 12, down to 18 (6), up to 0. 30 + 6.
  expect(verticalDistanceMeters([0, 30, 12, 18, 0]), 36);
});
test('a sawtooth under the deadband adds nothing', () {
  expect(verticalDistanceMeters([0, 20, 19.5, 20, 19.4, 20, 0]), 20);
});
test('a sawtooth over the deadband counts each descent', () {
  // 20, then 18 -> 20 twice: 20 + 2 + 2.
  expect(verticalDistanceMeters([0, 20, 18, 20, 18, 20, 0]), 24);
});
test('a dip under the deadband does not split a descent', () {
  expect(verticalDistanceMeters([0, 20, 19.2, 20.5, 0]), 20.5);
});
test('a profile that starts and ends at depth is counted from the surface', () {
  expect(verticalDistanceMeters([5, 20, 3]), 20);
});
test('a reversal of exactly the deadband counts', () {
  // 10, up exactly 1 m to 9, down to 10 again: 10 + 1.
  expect(verticalDistanceMeters([0, 10, 9, 10, 0]), 11);
});
test('a dive shallower than the deadband still counts', () {
  expect(verticalDistanceMeters([0.2, 0.5, 0.3]), 0.5);
});
test('one sample counts its depth; none counts nothing', () {
  expect(verticalDistanceMeters([12]), 12);
  expect(verticalDistanceMeters(const []), 0);
});
test('non-finite and negative depths are skipped', () {
  expect(
    verticalDistanceMeters([0, double.nan, 10, -3, double.infinity, 10, 0]),
    10,
  );
});
```

- [ ] **Step 2: Run** `flutter test test/features/insights/domain/vertical_distance/vertical_distance_test.dart`. Expected: fails to compile, `verticalDistanceMeters` undefined.

- [ ] **Step 3: Implement.** One pass, no allocation. The tests do not fix the algorithm on their own, so this is it:

```dart
double verticalDistanceMeters(
  Iterable<double> depths, {
  double deadband = verticalDistanceDeadbandMeters,
}) {
  var total = 0.0;
  var last = 0.0; // depth of the last confirmed turning point
  var extreme = 0.0; // deepest (descending) or shallowest (ascending) since
  var descending = true; // the path starts at the surface
  for (final d in depths) {
    if (!d.isFinite || d < 0) continue;
    if (descending) {
      if (d > extreme) {
        extreme = d;
      } else if (extreme - d >= deadband) {
        total += extreme - last;
        last = extreme;
        descending = false;
        extreme = d;
      }
    } else {
      if (d < extreme) {
        extreme = d;
      } else if (d - extreme >= deadband) {
        last = extreme;
        descending = true;
        extreme = d;
      }
    }
  }
  // The surface at the end is always a turning point, whatever the deadband.
  if (descending) total += extreme - last;
  return total;
}
```

- [ ] **Step 4: Run the test file.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(insights): work out one dive's vertical distance`.

---

### Task 2: The running total and the crossing lookup

**Files:**
- Create: `lib/features/insights/domain/vertical_distance/vertical_distance_timeline.dart`
- Test: `test/features/insights/domain/vertical_distance/vertical_distance_timeline_test.dart`

**Interfaces:**
- Produces:

```dart
class DiveVerticalDistance {
  const DiveVerticalDistance({
    required this.diveId,
    required this.startMillis, // stored wall clock flagged UTC, as in dives
    required this.meters,
    required this.estimated,
  });
}

class VerticalDistanceTimeline {
  /// [dives] in dive order. Dives with meters <= 0 are kept out of the
  /// counts and are never a crossing.
  VerticalDistanceTimeline(List<DiveVerticalDistance> dives);
  static final VerticalDistanceTimeline empty;
  double get totalMeters;
  int get countedDives; // dives contributing more than 0
  int get estimatedDives; // of those, how many were estimated
  bool get isEmpty; // totalMeters == 0
  /// The dive whose running total first reached [meters]; null when
  /// [meters] <= 0 or above the total.
  DiveVerticalDistance? crossingAt(double meters);
}
```

- [ ] **Step 1: Write the failing tests.** Dives A 10 m, B 0 m, C 25.5 m (estimated), D 4.5 m give running totals 10, 10, 35.5, 40.

```dart
expect(t.totalMeters, 40);
expect(t.countedDives, 3);
expect(t.estimatedDives, 1);
expect(t.crossingAt(0.5)!.diveId, 'A');
expect(t.crossingAt(10)!.diveId, 'A'); // a level exactly on a dive's total
expect(t.crossingAt(10.01)!.diveId, 'C'); // B added nothing, never returned
expect(t.crossingAt(35.5)!.diveId, 'C');
expect(t.crossingAt(40)!.diveId, 'D');
expect(t.crossingAt(40.01), isNull);
expect(t.crossingAt(0), isNull);
expect(VerticalDistanceTimeline.empty.isEmpty, isTrue);
expect(VerticalDistanceTimeline.empty.crossingAt(1), isNull);
```

  Add one test with 10,000 dives of 1 m each asserting `crossingAt(7500.5)!.diveId` is the 7,501st dive, to pin the lookup to the prefix sums.

- [ ] **Step 2: Run** the test file. Expected: fails to compile.
- [ ] **Step 3: Implement.** Prefix sums in a `Float64List` built once in the constructor; `crossingAt` is a lower-bound binary search for the first prefix sum `>= meters`.
- [ ] **Step 4: Run the test file.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(insights): running vertical distance and its crossing lookup`.

---

### Task 3: Landmarks

**Files:**
- Create: `lib/features/insights/domain/vertical_distance/vertical_landmarks.dart`
- Test: `test/features/insights/domain/vertical_distance/vertical_landmarks_test.dart`

**Interfaces:**
- Produces:

```dart
enum VerticalLeg { ascent, descent }

enum VerticalLandmarkId { statueOfLiberty, greatPyramid, /* ... one per named landmark */ }

class VerticalLandmark {
  const VerticalLandmark(this.id, this.meters, {this.multiple = 1});
  final VerticalLandmarkId id;
  final double meters; // already multiplied
  final int multiple; // 1 for a named landmark, n for "n x Everest"
}

const List<VerticalLandmark> ascentLandmarks; // ascending by meters
const List<VerticalLandmark> descentLandmarks; // ascending by meters

/// Everything with meters <= [total], ascending: named landmarks merged
/// with the multiples (2 x and up) of Everest or Challenger Deep.
List<VerticalLandmark> passedLandmarks(VerticalLeg d, double total);

/// The smallest landmark with meters > [total]. Never null: multiples go on.
VerticalLandmark nextLandmark(VerticalLeg d, double total);
```

- [ ] **Step 1: Verify the figures.** For each landmark in the spec's two lists, look the figure up in a source and record the source in a one-line comment above its constant. Where a source disagrees with the spec's figure, use the sourced one and note the change for the PR description. Drop any landmark whose figure cannot be sourced.

- [ ] **Step 2: Write the failing tests.** The multiples base values below assume Everest 8,849 m and Challenger Deep 10,935 m; if step 1 changes either, recompute.

```dart
test('lists are strictly ascending and ids are unique', () { /* both lists */ });
test('next from nothing is the smallest landmark', () {
  expect(nextLandmark(VerticalLeg.ascent, 0).id,
      VerticalLandmarkId.statueOfLiberty);
});
test('a landmark is passed at exactly its height', () {
  final passed = passedLandmarks(VerticalLeg.ascent, 8849);
  expect(passed.last.id, VerticalLandmarkId.everest);
  final next = nextLandmark(VerticalLeg.ascent, 8849);
  expect((next.id, next.multiple, next.meters),
      (VerticalLandmarkId.everest, 2, 17698.0));
});
test('named landmarks interleave with multiples', () {
  expect(nextLandmark(VerticalLeg.ascent, 20000).id,
      VerticalLandmarkId.olympusMons); // 21,900
  final n = nextLandmark(VerticalLeg.ascent, 22000);
  expect((n.multiple, n.meters), (3, 26547.0));
  expect(nextLandmark(VerticalLeg.ascent, 98000).id,
      VerticalLandmarkId.karmanLine); // 11 x Everest is 97,339
});
test('multiples continue past the last named landmark', () {
  final n = nextLandmark(VerticalLeg.ascent, 500000);
  expect((n.id, n.multiple, n.meters),
      (VerticalLandmarkId.everest, 57, 504393.0));
  final far = nextLandmark(VerticalLeg.descent, 1000000);
  expect((far.multiple, far.meters), (92, 1006020.0));
});
test('descent leans on Challenger Deep multiples', () {
  expect(nextLandmark(VerticalLeg.descent, 11000).id,
      VerticalLandmarkId.kolaBorehole);
  final n = nextLandmark(VerticalLeg.descent, 12262);
  expect((n.id, n.multiple, n.meters),
      (VerticalLandmarkId.challengerDeep, 2, 21870.0));
});
test('passed merges named and multiples in order', () {
  final passed = passedLandmarks(VerticalLeg.ascent, 26547);
  expect(passed.map((l) => l.meters), orderedEquals(/* sorted copy */));
  expect(passed.where((l) => l.multiple > 1).map((l) => l.multiple), [2, 3]);
});
```

- [ ] **Step 3: Run** the test file. Expected: fails to compile.
- [ ] **Step 4: Implement.** `nextLandmark` compares the next named landmark against `max(2, floor(total / base) + 1) * base`; it never iterates over multiples.
- [ ] **Step 5: Run the test file.** Expected: all pass.
- [ ] **Step 6: Commit** `feat(insights): ocean and mountain landmarks with multiples`.

---

### Task 4: Scale layout and selection

**Files:**
- Create: `lib/features/insights/domain/vertical_distance/vertical_scale_layout.dart`
- Create: `lib/features/insights/domain/vertical_distance/vertical_selection.dart`
- Test: `test/features/insights/domain/vertical_distance/vertical_scale_layout_test.dart`
- Test: `test/features/insights/domain/vertical_distance/vertical_selection_test.dart`

**Interfaces:**
- Consumes: Task 3's `VerticalLeg`, `VerticalLandmark`, `passedLandmarks`, `nextLandmark`.
- Produces:

```dart
class VerticalScaleMark {
  final VerticalLandmark landmark;
  final double offsetPx; // from sea level, always >= 0
  final bool passed;
  final bool labelled;
  final double labelOffsetPx; // equals offsetPx unless nudged
}

class VerticalScaleLayout {
  /// [halfHeightPx] is the room on each side of sea level.
  factory VerticalScaleLayout.compute({
    required double totalMeters,
    required double halfHeightPx,
    double headroom = 0.08,
    double minLabelGapPx = 18,
  });
  final double extentMeters; // the larger of the two next landmarks
  final double barPx; // length of each bar
  final List<VerticalScaleMark> ascentMarks; // passed, then the next one
  final List<VerticalScaleMark> descentMarks;
  double offsetFor(double meters);
  /// Metres for a distance from sea level, clamped to 0..totalMeters.
  double metersAt(double offsetPx);
  /// The passed mark within [tolerancePx] of [offsetPx], or null.
  VerticalScaleMark? snap(VerticalLeg d, double offsetPx,
      {double tolerancePx = 4});
}

class VerticalProbe { // what the pointer is on
  final VerticalLeg direction;
  final double meters;
  final VerticalLandmark? landmark; // set when snapped, or on the next mark
  final bool ahead; // the dashed next landmark, above the total
}

sealed class VerticalSelection { /* VerticalIdle, VerticalHovering(probe), VerticalPinned(probe) */ }

VerticalSelection hoverSelection(VerticalSelection s, VerticalProbe? probe);
VerticalSelection exitSelection(VerticalSelection s);
VerticalSelection tapSelection(VerticalSelection s, VerticalProbe? probe);
```

Rules for the label thinning, in order: the next unpassed landmark is always labelled at its own offset. The most recently passed landmark is always labelled; if its offset is within `minLabelGapPx` of the next landmark's label, its `labelOffsetPx` is moved toward sea level until the gap holds (its tick stays at `offsetPx`). Remaining passed landmarks are visited from the largest down and labelled only when at least `minLabelGapPx` from every label already placed. `pixels per metre = halfHeightPx / (extentMeters * (1 + headroom))`.

Rules for selection: `hoverSelection` returns the state unchanged while pinned; otherwise hovering with the probe, or idle for a null probe. `exitSelection` returns idle unless pinned. `tapSelection` with a probe pins it (from any state); with null it returns idle.

- [ ] **Step 1: Write the failing layout tests.** Worked example: total 525 m, `halfHeightPx` 240. Next up is the Burj Khalifa (828), next down is Crater Lake (594), so the extent is 828 and there are 240 / (828 x 1.08) = 0.26839 px per metre.

```dart
expect(layout.extentMeters, 828);
expect(layout.barPx, closeTo(140.9, 0.1)); // 525 x 0.26839
expect(layout.offsetFor(828), closeTo(222.2, 0.1));
// Up: 828 at 222.2, 443 at 118.9, 330 at 88.6, 139 at 37.3, 93 at 25.0.
expect(labelled(layout.ascentMarks), [828, 443, 330, 139]); // 93 is 12.3 px from 139
// Down: 594 at 159.4, 332 at 89.1, 301 at 80.8, 202 at 54.2, 124 at 33.3, 40 at 10.7.
expect(labelled(layout.descentMarks), [594, 332, 202, 124, 40]); // 301 is 8.3 px from 332
expect(layout.ascentMarks.last.passed, isFalse);
expect(layout.metersAt(layout.barPx + 50), 525); // clamped to the total
expect(layout.metersAt(-5), 0);
expect(layout.snap(VerticalLeg.descent, 90.5)!.landmark.meters, 332);
expect(layout.snap(VerticalLeg.descent, 100), isNull);
```

  And these:

```dart
test('the most recent passed label is nudged clear of the next one', () {
  // Total 8,700: K2 (8,611) passed, Everest (8,849) next. The extent is the
  // Tonga Trench (10,820), so the two sit about 5 px apart.
  final l = VerticalScaleLayout.compute(totalMeters: 8700, halfHeightPx: 240);
  final next = l.ascentMarks.last;
  final recent = l.ascentMarks[l.ascentMarks.length - 2];
  expect(recent.labelled, isTrue);
  expect(next.labelOffsetPx - recent.labelOffsetPx,
      greaterThanOrEqualTo(18));
  expect(recent.offsetPx, closeTo(l.offsetFor(8611), 0.001)); // tick unmoved
});
test('a zero total lays out to the first landmarks without dividing by zero', () {
  final l = VerticalScaleLayout.compute(totalMeters: 0, halfHeightPx: 240);
  expect(l.barPx, 0);
  expect(l.extentMeters, 93); // Statue of Liberty against the 40 m limit
  expect(l.ascentMarks.single.passed, isFalse);
});
test('a very large total stays finite and labels stay apart', () {
  final l = VerticalScaleLayout.compute(
      totalMeters: 1000000, halfHeightPx: 240);
  expect(l.barPx.isFinite, isTrue);
  expect(l.barPx, lessThanOrEqualTo(240));
  final offsets = l.descentMarks.where((m) => m.labelled)
      .map((m) => m.labelOffsetPx).toList()..sort();
  for (var i = 1; i < offsets.length; i++) {
    expect(offsets[i] - offsets[i - 1], greaterThanOrEqualTo(18));
  }
});
```

- [ ] **Step 2: Write the failing selection tests:** hover from idle gives hovering; hover with null gives idle; exit from hovering gives idle; tap with a probe pins; hover and exit while pinned change nothing; tap with a probe while pinned moves the pin; tap with null unpins.

- [ ] **Step 3: Run** both test files. Expected: fail to compile.
- [ ] **Step 4: Implement** both files.
- [ ] **Step 5: Run both test files.** Expected: all pass.
- [ ] **Step 6: Commit** `feat(insights): vertical scale layout and selection states`.

---

### Task 5: The cache table

**Files:**
- Create: `lib/core/database/local_cache_vertical_distance_table.dart`
- Modify: `lib/core/database/local_cache_database.dart` (import and export, `tables:` list, `schemaVersion` 23, one `if (from < 23)` rung, one self-heal line in `beforeOpen`)
- Create: `lib/features/insights/data/repositories/vertical_distance_cache.dart`
- Modify: `lib/core/services/storage/local_cache_sweep.dart` (`verticalDistanceRows` in the report, `rowsDeleted`, `toString`, and the sweep call)
- Test: `test/core/database/local_cache_migration_v23_vertical_distance_test.dart`
- Test: `test/features/insights/data/repositories/vertical_distance_cache_test.dart`
- Test: `test/core/services/storage/local_cache_sweep_test.dart` (add a case)

**Interfaces:**
- Produces:

```dart
// local_cache_vertical_distance_table.dart
class DiveVerticalDistanceCache extends Table {
  // tableName 'dive_vertical_distance_cache'
  // dive_id TEXT pk, meters REAL, inputs_hash TEXT, computed_at INTEGER
}
const String diveVerticalDistanceCacheCreateSql; // CREATE TABLE IF NOT EXISTS ...

// vertical_distance_cache.dart
typedef VerticalDistanceCacheEntry = ({double meters, String inputsHash});

class VerticalDistanceCacheRepository {
  VerticalDistanceCacheRepository({LocalCacheDatabase? database});
  Future<Map<String, VerticalDistanceCacheEntry>> getEntries(Set<String> diveIds);
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries);
  Future<void> clear();
}
```

Model every piece on `DecoClassificationCache` and `DecoClassificationCacheRepository`: chunked reads of 900 ids, `insertOnConflictUpdate`, `LocalCacheDatabaseService.instance.database` as the default. `putAll` writes in one drift `batch`.

- [ ] **Step 1: Write the failing migration test**, modelled on `local_cache_migration_v22_site_catalogue_kind_test.dart`: a database stamped 22 without the table opens at 23 with it; a fresh database has it; a database already stamped 23 that lacks the table (the ladder-collision case) gains it from `beforeOpen`.
- [ ] **Step 2: Write the failing cache tests**, modelled on `deco_classification_cache_test.dart`: empty before anything is cached; `putAll` then `getEntries` round-trips meters and hash; a second `putAll` for the same dive replaces the row; 2,000 ids read back across chunks; `clear` empties it.
- [ ] **Step 3: Write the failing sweep test:** a cache row whose dive no longer exists is deleted and counted in `verticalDistanceRows`; a row whose dive exists stays.
- [ ] **Step 4: Run** the three test files. Expected: fail to compile.
- [ ] **Step 5: Implement.** Then run `dart run build_runner build --delete-conflicting-outputs` unfiltered (never with `--build-filter`), in the background, and confirm `lib/core/database/local_cache_database.g.dart` mentions `dive_vertical_distance_cache`. Confirm `wc -l lib/core/database/local_cache_database.dart` is under 800.
- [ ] **Step 6: Run the three test files** and `flutter test test/core/database/` for the local cache files only (`--name` is not needed; pass the `local_cache_*` files). Expected: all pass.
- [ ] **Step 7: Commit** `feat(insights): device-only cache of each dive's vertical distance`.

---

### Task 6: The repository

**Files:**
- Modify: `lib/features/insights/data/series_profile_aggregates.dart` (`_forEachStream` passes the stream key; add the isolate entry point)
- Create: `lib/features/insights/data/repositories/insights_repository_vertical_distance.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (one `part` line)
- Test: `test/features/insights/data/series_profile_aggregates_test.dart` (add a group)
- Test: `test/features/insights/data/repositories/insights_repository_vertical_distance_test.dart`

**Interfaces:**
- Consumes: Task 1's `verticalDistanceMeters` and `verticalDistanceAlgorithmVersion`; Task 2's `DiveVerticalDistance`, `VerticalDistanceTimeline`; Task 5's `VerticalDistanceCacheRepository`.
- Produces:

```dart
// series_profile_aggregates.dart: top-level, so `compute` can run it.
/// Each dive's vertical distance from its blobs. A dive whose every blob
/// fails to decode is absent. Two streams of one dive: the larger wins.
Map<String, double> verticalDistanceByDiveFromBlobs(List<SeriesBlob> blobs);

// insights_repository_vertical_distance.dart
String verticalDistanceInputsHash(String seriesFingerprint) =>
    'v$verticalDistanceAlgorithmVersion|$seriesFingerprint';

extension InsightsRepositoryVerticalDistance on InsightsRepository {
  Future<VerticalDistanceTimeline> getVerticalDistanceTimeline({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    VerticalDistanceCacheRepository? cache, // tests inject; default is the service's
  });
}
```

How `getVerticalDistanceTimeline` works:

1. One query over `dives d` with `_diveFilter(filter, alias: 'd')` and the diver clause, as `getDivesByTimeOfDay` builds them: `d.id`, `diveStartMillisSql('d') AS start_ms`, `d.max_depth`, and a series fingerprint. The fingerprint is a correlated subquery over `dive_profile_series` rows with `is_primary = 1` for the dive, ordered by `start_timestamp, id`, concatenating `id`, `updated_at` and `sample_count`; null when there are none. `ORDER BY start_ms, d.id`. `readsFrom: {dives, diveProfileSeries}`.
2. For dives with a fingerprint, read the cache. A row whose hash equals `verticalDistanceInputsHash(fingerprint)` is a hit.
3. Misses go through `_diveChunks` and `_primaryBlobs` to `compute(verticalDistanceByDiveFromBlobs, blobs)`, as `getAscentDescentRatesForDives` does, and the results are written back with `putAll`.
4. Per dive: with a profile figure, `meters = max(figure, max_depth ?? 0)` and `estimated = false`. With no fingerprint, or a miss the worker returned nothing for, `meters = max_depth ?? 0` and `estimated = true`.
5. A cache read failure is logged and every fingerprinted dive is treated as a miss. A cache write failure is logged and ignored. Neither fails the call. A failure of the dives query is logged and rethrown, as the sibling methods do.

- [ ] **Step 1: Write the failing fold tests** in `series_profile_aggregates_test.dart`, encoding blobs with `ProfileSeriesCodec` as the existing blob tests there do:

```dart
test('each dive gets its own figure', () { /* d1 to 20 m -> 20; d2 0,30,12,18,0 -> 36 */ });
test('a stream stored as two series rows is interleaved, not counted twice', () {
  // d1/c1 in two blobs: t 0..60 descending to 20, t 70..130 ascending to 0.
  expect(verticalDistanceByDiveFromBlobs(twoPieces), {'d1': 20.0});
});
test('a dive whose only blob is corrupt is absent', () { /* Uint8List of junk */ });
```

- [ ] **Step 2: Write the failing repository tests**, with the setup helpers of `insights_repository_ascent_descent_test.dart` plus an in-memory `LocalCacheDatabase` set on `LocalCacheDatabaseService` and reset in `tearDown`:

  - a profile dive and a max-depth-only dive, in date order: totals, `estimatedDives == 1`, and `crossingAt` returns each;
  - a dive with neither a profile nor a max depth adds nothing and is not counted;
  - the max depth floor: a profile reaching 12 m on a dive whose `max_depth` is 18 gives 18, not estimated;
  - a second call computes nothing: assert by replacing the dive's series blob bytes directly in the table without touching `updated_at`, and checking the figure is unchanged (served from cache);
  - a changed fingerprint recomputes: insert a new primary series for the dive, expect the new figure;
  - a non-primary series is ignored;
  - the diver filter and a `DiveFilterState` date range each narrow the timeline;
  - a dive excluded from statistics and a planned dive are left out (use the columns `dive_stats_scope_behavior_test.dart` sets);
  - dives sharing a start time are ordered by id;
  - a cache that throws on read and on write (a subclass overriding both) still returns the right timeline.

- [ ] **Step 3: Run** both test files. Expected: fail to compile.
- [ ] **Step 4: Implement.** Changing `_forEachStream`'s callback to `(StreamKey key, List<ProfileSample> samples)` touches its two existing callers; both ignore the key.
- [ ] **Step 5: Run** both test files, plus `insights_repository_ascent_descent_test.dart`, `insights_repository_time_at_depth_test.dart`, `series_profile_aggregates_streaming_test.dart` and `insights_repository_series_chunking_test.dart` (the callers of the changed helper). Expected: all pass.
- [ ] **Step 6: Commit** `feat(insights): per-dive vertical distance timeline from the repository`.

---

### Task 7: Strings, units and landmark names

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart` (one method)
- Modify: `lib/l10n/arb/app_en.arb` (new keys beside `insights_profile_ascentDescent_*` and beside `info_insights_ascentDescent_summary`)
- Create: `lib/features/insights/presentation/formatters/vertical_landmark_labels.dart`
- Test: `test/core/utils/unit_formatter_depth_whole_test.dart`
- Test: `test/features/insights/presentation/formatters/vertical_landmark_labels_test.dart`

**Interfaces:**
- Produces:

```dart
// UnitFormatter
/// A long vertical distance in whole display units with grouped digits:
/// "6,380 m" or "20,932 ft". Modelled on formatAltitude.
String formatDepthWhole(double? meters);

// vertical_landmark_labels.dart
String verticalLandmarkName(AppLocalizations l10n, VerticalLandmark landmark);
```

Strings, English. Landmark names are bare nouns with no article, and every sentence that carries one puts it where no language has to inflect it:

| Key | English |
| --- | --- |
| `insights_profile_verticalDistance_title` | Total Ascent & Descent |
| `insights_profile_verticalDistance_subtitle` | Every dive added up, against mountains and ocean depths |
| `insights_profile_verticalDistance_totalAscent` | total ascent |
| `insights_profile_verticalDistance_totalDescent` | total descent |
| `insights_profile_verticalDistance_seaLevel` | Sea level |
| `insights_profile_verticalDistance_next` | Next: {landmark}, {distance} to go |
| `insights_profile_verticalDistance_landmarkLabel` | {landmark} {height} |
| `insights_profile_verticalDistance_multiple` | {count} x {landmark} |
| `insights_profile_verticalDistance_stripIdle` | Point at a bar to see when you got there |
| `insights_profile_verticalDistance_stripAscent` | {level} of ascent, reached {date} |
| `insights_profile_verticalDistance_stripDescent` | {level} of descent, reached {date} |
| `insights_profile_verticalDistance_stripPassed` | {landmark}: passed {date} |
| `insights_profile_verticalDistance_stripAhead` | {landmark}: {distance} to go |
| `insights_profile_verticalDistance_openDive` | Open dive |
| `insights_profile_verticalDistance_pinned` | Pinned |
| `insights_profile_verticalDistance_estimated` | {estimated} of {total} dives counted from max depth (plural on `total`, `int`) |
| `insights_profile_verticalDistance_empty` | No dives with a depth yet |
| `insights_profile_verticalDistance_error` | Failed to load ascent and descent totals |
| `insights_profile_verticalDistance_semantics` | Total ascent and descent {total}. Next up: {up}, {upDistance} to go. Next down: {down}, {downDistance} to go. |
| `info_insights_verticalDistance_summary` | Each dive is counted from the surface down and back, ignoring wobble under {deadband}. A dive with no profile counts once down to its max depth and once back up. |
| `insights_landmark_<id>` | one per `VerticalLandmarkId`, for example "Mount Everest", "Titanic", "Challenger Deep" |

`{deadband}` is the deadband formatted in the diver's unit, so the info text never states metres to a diver on feet.

- [ ] **Step 1: Write the failing formatter tests:** `formatDepthWhole(6380)` is `6,380 m` on metres and `20,932 ft` on feet (6380 x 3.28084 = 20,931.8); `formatDepthWhole(0.4)` is `0 m`; null is `--`; 100,000 m is `100,000 m`. Match the spacing `formatAltitude` uses between number and symbol.
- [ ] **Step 2: Write the failing landmark name tests** in English: Everest reads `Mount Everest`; a `multiple: 3` Everest reads `3 x Mount Everest`; every `VerticalLandmarkId` value yields a non-empty name (loop over `values`, so a landmark added without a string fails here).
- [ ] **Step 3: Run** both. Expected: fail to compile.
- [ ] **Step 4: Implement:** add the English keys, run `flutter gen-l10n`, add the formatter method and the name resolver (an exhaustive `switch` on the id, no default).
- [ ] **Step 5: Run both test files.** Expected: all pass.
- [ ] **Step 6: Commit** `feat(insights): strings and formatting for ascent and descent totals`.

---

### Task 8: The card

**Files:**
- Create: `lib/features/insights/presentation/providers/vertical_distance_providers.dart`
- Create: the four files under `lib/features/insights/presentation/widgets/vertical_distance/`
- Test: `test/features/insights/presentation/widgets/vertical_distance/vertical_distance_card_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:

```dart
final verticalDistanceTimelineProvider =
    FutureProvider<VerticalDistanceTimeline>(...);

class VerticalDistanceCard extends ConsumerWidget { const VerticalDistanceCard({super.key}); }
```

The provider follows `conditionsRowsProvider`: watch the repository, the Insights filter and the current diver, `ref.invalidateSelfWhen(repository.watchInsightsChanges(filter: filter))`, `await awaitInsightsFilterCaches(ref)`, then call the repository.

Structure and fixed values:

- `VerticalDistanceCard`: a `StatSectionCard` with the title, subtitle and an `info:` built with `termsInfo` (title and `info_insights_verticalDistance_summary`). Loading is a centred spinner in a box as tall as the scale; error is `StatEmptyState` with `Icons.error_outline`; an empty timeline is `StatEmptyState` with `Icons.height`. Otherwise the scale, the strip, and the estimated note when `estimatedDives > 0`.
- `VerticalDistanceScale` (stateful): total height 480, sea level at the middle, so `halfHeightPx` is 240 less 8 of padding at each end. A `LayoutBuilder` caps the scale at 440 wide and centres it. Columns, in reading direction: labels (flexible, text aligned to the bar, one line, ellipsis), a 36 wide bar column, headlines (flexible). `Directionality` decides which side is which; nothing is hard-coded left or right.
- Keys the tests use: `Key('verticalScale')` on the gesture area, `Key('verticalStrip')` on the strip, `Key('verticalOpenDive')` on the action.
- Gestures on the bar column plus 12 px either side: `MouseRegion` `onHover` and `onExit`; `GestureDetector` `onTapUp`, `onLongPressStart`, `onLongPressMoveUpdate`, `onLongPressEnd`. A tap outside the bar column but inside the card unpins. No vertical drag recognizer anywhere: a swipe must reach the page's scroll view.
- Probe: vertical distance from sea level, direction by side, `layout.snap` first, then `layout.metersAt`. Within 6 px of the next unpassed mark's tick or on its label, the probe is that landmark with `ahead: true`. Elsewhere beyond the bar there is no probe.
- Strip: 44 high, always present. Idle: the idle string. Selected: the text for the probe, and the Open dive action when `timeline.crossingAt(meters)` is not null; an `ahead` probe has no action. Pinned shows the pinned label as a small chip. Open dive calls `context.push('/dives/$diveId')`.
- Dates: `units.formatDate(wallClockUtcFromMillis(crossing.startMillis))`.
- Painter: bars in `Colors.green` (ascent) and `Colors.blue` (descent), as the rates card on this page; ticks and sea level in `colorScheme.outline`; the next landmark dashed; the hairline in `colorScheme.onSurface`, 2 px, across the bar column.
- Semantics: the scale is one node labelled with `insights_profile_verticalDistance_semantics`, its drawn children excluded; then one node per passed landmark, labelled with the `stripPassed` text and carrying `onTap` to open its dive. These nodes take no layout space.

- [ ] **Step 1: Write the failing widget tests.** Pump the card in a `ProviderScope` overriding `verticalDistanceTimelineProvider`, settings and the current diver, as `insights_profile_ascent_descent_test.dart` does. Fixture timeline: 58 dives 30 days apart from 2021-01-10, 110 m each (total 6,380 m exactly), 5 of them estimated.

  - headlines read `6,380 m` twice, with `total ascent` and `total descent`;
  - on feet they read `20,932 ft` (6,380 x 3.28084 = 20,931.8), and a landmark label reads in feet;
  - the estimated note reads `5 of 58 dives counted from max depth`; with none estimated it is absent;
  - the strip starts idle; hovering the descent bar at a known offset (a `TestGesture` of `PointerDeviceKind.mouse`) shows a `reached` text with the date of the dive `crossingAt` returns, and the Open dive action;
  - moving off the bar returns the strip to idle;
  - a click pins: after it, moving off the bar leaves the text and shows `Pinned`; a tap on the card away from the bars unpins;
  - a touch tap on a bar pins that level;
  - a long press then a move changes the level, and it stays pinned on release;
  - a touch drag starting on a bar scrolls an enclosing `SingleChildScrollView` (assert the scroll offset changed and the strip stayed idle);
  - hovering within 4 px of a passed landmark's tick shows the `passed` text naming it;
  - on the dashed next landmark the strip shows `to go` and no Open dive action;
  - Open dive pushes `/dives/<id>` (a `GoRouter` with a stub route, or a mock observer, whichever the existing chart link tests use);
  - an empty timeline shows the empty message and no scale;
  - at 320 px wide, and again under `Locale('ar')`, pumping reports no overflow (`tester.takeException()` is null) and the bar is still found;
  - the semantics summary is found by label, and a passed landmark node exists with a tap action.

- [ ] **Step 2: Run** the test file. Expected: fails to compile.
- [ ] **Step 3: Implement** the provider and the four widget files. Keep each file under 400 lines; if the scale passes that, move the probe function to its own file.
- [ ] **Step 4: Run the test file.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(insights): total ascent and descent card with a date readout`.

---

### Task 9: On the page

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_profile_page.dart` (the card after `_buildAscentDescentSection`, with a 16 px gap)
- Modify: every existing test that pumps `InsightsProfilePage` (`insights_profile_ascent_descent_test.dart`, `insights_profile_deco_legend_test.dart`, `insights_profile_deco_links_test.dart`, `insights_profile_deco_progress_test.dart`, and any other found with `grep -rl InsightsProfilePage test/`): override `verticalDistanceTimelineProvider` with an empty timeline
- Test: `test/features/insights/presentation/pages/insights_profile_vertical_distance_test.dart`
- Test: `test/features/insights/presentation/pages/insights_info_sheets_test.dart` (cover the new sheet, following its existing cases)

- [ ] **Step 1: Write the failing page test:** with a non-empty timeline override, the card's title is on the page and sits below the rates card's title and above the time-at-depth title (compare `tester.getTopLeft(...).dy`).
- [ ] **Step 2: Run it.** Expected: fails, title not found.
- [ ] **Step 3: Add the card to the page and the override to the existing page tests.**
- [ ] **Step 4: Run** every test file under `test/features/insights/presentation/pages/` whose name starts `insights_profile_`, plus `insights_info_sheets_test.dart` and `insights_filter_bar_pages_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(insights): show total ascent and descent on the Profile page`.

---

### Task 10: Translations

**Files:**
- Modify: the ten locale ARBs under `lib/l10n/arb/` (ar, de, es, fr, he, hu, it, nl, pt, zh) and the generated `app_localizations*.dart`

- [ ] **Step 1: Translate every key from Task 7 into each locale.** Insert each line textually after the locale's own `insights_profile_ascentDescent_title` line (and the info key after `info_insights_ascentDescent_summary`), built as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))` with `python3.14`. No `@` metadata in locale files. Keep ICU placeholders verbatim. Use each locale's existing nouns for dive, profile, ascent, descent and max depth (read the neighbouring keys first). Landmark names use the name the language itself uses (for example de "Zugspitze" is not in the list, but "Mount Everest" stays "Mount Everest" in de and is "Everest" in es).
- [ ] **Step 2: Check the info text against the sentence cap** the info sheet tests enforce, in every locale.
- [ ] **Step 3: Prove each ARB still parses** (`json.loads`) and that `git diff --numstat lib/l10n/arb/*.arb` shows the same added count for all ten locales and zero deletions.
- [ ] **Step 4: Run `flutter gen-l10n`.** It must report no untranslated messages for the new keys. Spot-check: `grep -A1 "get insights_profile_verticalDistance_title" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 5: Run** `test/l10n/` (the ARB guards) and `insights_info_sheets_test.dart`. Expected: all pass.
- [ ] **Step 6: Commit** `i18n(insights): translate the ascent and descent card`.

---

### Task 11: Checks and after screenshots

- [ ] **Step 1:** `dart format .`
- [ ] **Step 2:** `flutter analyze` over the whole repository. Expected: no issues.
- [ ] **Step 3:** Run `test/architecture/`, `test/shared/`, `test/features/insights/`, `test/core/database/` (local cache files), `test/core/services/storage/local_cache_sweep_test.dart` and `test/core/utils/unit_formatter_depth_whole_test.dart`. Expected: all pass.
- [ ] **Step 4:** Launch the app against a copy of a real logbook and check by hand: the card on Insights > Profile, hover and click-to-pin on desktop, Open dive lands on the right dive, the Insights filter changes the bars, feet and metres, light and dark.
- [ ] **Step 5:** Capture the after screenshots of the same page as Task 0, plus the card itself with a level pinned, in light and dark, at desktop and phone widths. Name them `02-insights-profile-after[-dark][-phone].png` and `03-ascent-descent-card-pinned[-dark].png`.
- [ ] **Step 6:** Commit anything the format or analyze steps changed as `chore(insights): format`.
