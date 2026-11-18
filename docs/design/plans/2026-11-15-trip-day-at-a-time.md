# Trip Page: One Day at a Time Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From a trip's first day onward, the Overview tab shows a fixed strip of dive profiles (one tile per day plus a leading Trip tile) over one scrolling page that is either the whole trip or a single day.

**Architecture:** `TripStoryView` becomes a `Column` of a `TripDayPicker` and one page (`TripStoryTripPage` or `TripStoryDayPage`). The picker draws from a pure `TripPickerModel` built from the story's days, the app's shared mini-profile cache, and one new query that names the trip's undived plans. The selected page is held by `TripDetailTabs`, above the tab view, so it survives a tab change.

**Tech Stack:** Flutter, Riverpod, Drift (`customSelect`), `CustomPainter`, `flutter_map` (existing day map), `intl`.

**Spec:** `docs/design/specs/2026-11-15-trip-day-at-a-time-design.md`. Read it before any task. The mockups it refers to were reviewed in chat and are not in the repo; the spec's sketches and tables stand in for them.

## Global Constraints

- **The story read stays sample-free.** Do not change `divesForTripProvider`, `getDivesByIdsWithoutSamples` or `_diveIdsNeedingSamples`. `test/features/dive_log/data/repositories/dive_repository_without_samples_test.dart` must pass unchanged.
- **Profiles come only from the shared cache:** `diveProfileBatcherProvider.load(ids)` into `batchProfileCacheProvider`, at the reader's default resolution (120 samples). Never call `getBatchProfileSummaries` with another `maxSamples`.
- **"Has not happened" is `dive.isDraft || undivedPlanIds.contains(dive.id)`**, where the ids come from `diveUndivedSql`. Never test `isPlanned` alone (issue #3924).
- **Units:** every depth or temperature shown as text goes through `ref.watch(unitFormatterProvider)`. The picker's drawing carries no numbers.
- **Colours** come from `Theme.of(context).colorScheme`. No hex literals in `lib/`.
- **Strings:** every new string is added to all 11 ARB files under `lib/l10n/arb/` with a real translation, inserted beside `trips_story_surfaceDay` (the files are grouped by feature), then `flutter gen-l10n`. `test/l10n/` must pass.
- **Paths** in tests use `p.join` and `Directory.systemTemp`. A test that replaces process-wide state restores it in `addTearDown`.
- **Files:** 200 to 400 lines typical, 800 at most. No emojis. No em-dashes anywhere, including comments and commit messages.
- **Commits and PR text never mention the AI tool or its vendor.** No co-author trailer.
- **Tests:** run only the files named in a step, plus `test/architecture/` and `test/shared/` where a step says so. Never run the whole suite locally.
- **Out of scope:** `TripPrepareOverview`, the other five tabs, the trip list, `DiveListItem`, the schema, sync.
- After the last task: `dart format .` and a whole-repo `flutter analyze` with no issues.

## Review Focus

The inputs the spec implies but does not spell out, most likely first. Each has a test in the task named.

1. **A crowded day in a narrow tile** (eight dives in a 38 point tile): every shape stays inside its tile; shapes shrink together instead of overflowing into the next day. Task 3.
2. **A trip with nothing to scale by** (no dive has a depth or a profile, or the trip has no dives): the picker draws empty water for every day and nothing divides by zero. Tasks 2 and 3.
3. **The selected day disappears** while the page is open (its last dive is moved, the trip's dates shrink): the page falls back to the Trip page; it does not show a stale or blank day. Task 10.
4. **Text scale 2.0:** tile labels and the day head grow; nothing clips or overflows. Tasks 4 and 6.
5. **A right-to-left locale** (`ar`, `he`): tiles run in reading order with the Trip tile at the start edge; a dive's profile still runs left to right in time, as every other chart in the app does. Task 4.

---

## File Map

Create:

| File | Responsibility |
| --- | --- |
| `lib/features/trips/data/repositories/trip_undived_plan_queries.dart` | One query: the trip's undived plan ids |
| `lib/features/trips/presentation/providers/trip_day_picker_providers.dart` | Providers for that query |
| `lib/features/trips/domain/services/trip_picker_model.dart` | Pure model: what each tile draws, and the two shared scales |
| `lib/features/trips/presentation/widgets/story/trip_day_picker_painter.dart` | Tile layout maths and the painter |
| `lib/features/trips/presentation/widgets/story/trip_day_picker.dart` | The strip: tiles, selection, scrolling, semantics, keys |
| `lib/features/trips/presentation/widgets/story/trip_day_sections.dart` | Photo strip, species chips, section caption (moved out of the day card) |
| `lib/features/trips/presentation/widgets/story/trip_story_empty_state.dart` | The empty state (moved out of the hero) |
| `lib/features/trips/presentation/widgets/story/trip_under_way_cards.dart` | Cylinders summary plus flight countdown, shared by two pages |
| `lib/features/trips/presentation/widgets/day/day_subtitle.dart` | The day type, port and sites parts (moved out of the day header) |
| `lib/features/trips/presentation/widgets/story/trip_story_day_head.dart` | A day page's head |
| `lib/features/trips/presentation/widgets/story/trip_story_day_page.dart` | A day's page, one or two columns |
| `lib/features/trips/presentation/widgets/story/trip_story_day_line.dart` | One day's line on the Trip page |
| `lib/features/trips/presentation/widgets/story/trip_story_trip_page.dart` | The Trip page |

Rewrite: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`.

Modify: `trip_detail_tabs.dart`, `trip_overview_tab.dart`, `story/trip_story_hero.dart`, the 11 ARB files.

Delete in Task 10, with their tests: `story/trip_story_day_card.dart`, `story/trip_story_day_header.dart`, `story/trip_stat_strip.dart`.

Keep: `TodayAnchoredScrollView` (the Itinerary tab uses it), `TripStoryHero` (the Prepare page uses it), `today_card_shape.dart` (the Itinerary day card uses it).

Tests mirror the source path under `test/`. Widget tests reuse the harness in `test/features/trips/presentation/widgets/story/trip_story_view_test.dart` (`getBaseOverrides`, `buildTripStory`, the `GoRouter` with a `/dives/:id` route).

---

### Task 1: The trip's undived plan ids

**Files:**
- Create: `lib/features/trips/data/repositories/trip_undived_plan_queries.dart`
- Create: `lib/features/trips/presentation/providers/trip_day_picker_providers.dart`
- Test: `test/features/trips/data/repositories/trip_undived_plan_queries_test.dart`

**Interfaces:**
- Consumes: `diveUndivedSql(String alias)` from `lib/features/dive_log/data/repositories/dive_times_sql.dart`; `tripDivesScopeSql(String diveAlias, String tripRef)` from `lib/features/trips/data/side_trip_sql.dart`.
- Produces:

```dart
class TripUndivedPlanQueries {
  /// Ids of the dives on [tripId], its side trips' included, that are plans
  /// nobody has dived. Logs and returns an empty set when the read fails.
  Future<Set<String>> undivedPlanIds(String tripId);
}

final tripUndivedPlanQueriesProvider = Provider<TripUndivedPlanQueries>(...);

/// Re-reads on any dive or trip write.
final tripUndivedPlanIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>(...);
```

- [ ] **Step 1: Write the failing test.** Follow the setup of `test/features/trips/data/repositories/trip_country_queries_test.dart` (`setUpTestDatabase`, direct inserts). Seed trip `t1`, a side trip `t1s` of it, and an unrelated trip `t2`:

| dive id | trip | `is_planned` | `is_draft` | `outing_id` |
| --- | --- | --- | --- | --- |
| `logged` | t1 | 0 | 0 | null |
| `plan` | t1 | 1 | 0 | null |
| `draft` | t1 | 0 | 1 | null |
| `mirror` | t1 | 1 | 0 | `o1` |
| `source` | t2 | 0 | 0 | `o1` |
| `lonely` | t1 | 1 | 0 | `o2` |
| `sidePlan` | t1s | 1 | 0 | null |

```dart
test('names the plans nobody has dived, side trips included', () async {
  expect(await queries.undivedPlanIds('t1'), {'plan', 'lonely', 'sidePlan'});
});

test('a trip with no plans has none', () async {
  expect(await queries.undivedPlanIds('t2'), isEmpty);
});
```

- [ ] **Step 2: Run it.** `flutter test test/features/trips/data/repositories/trip_undived_plan_queries_test.dart`. Expected: fails to compile, `TripUndivedPlanQueries` undefined.

- [ ] **Step 3: Implement** `TripUndivedPlanQueries` on the pattern of `TripCountryQueries` (`DatabaseService.instance.database`, `LoggerService.forClass`). One statement:

```sql
-- stats-scope-exempt: names plans for the trip's day picker; plans are
-- outside the statistics scope by definition
SELECT id FROM dives
WHERE <tripDivesScopeSql('dives', '?1')> AND <diveUndivedSql('dives')>
```

Add both providers. `tripUndivedPlanIdsProvider` calls `ref.invalidateSelfWhen` on `diveRepositoryProvider.watchDivesChanges()` and `tripRepositoryProvider.watchTripsChanges()`, as `diveIdsForTripProvider` does.

- [ ] **Step 4: Run the test, then the census.** The test file above, then `flutter test test/core/database/dive_stats_scope_census_test.dart`. Expected: both pass.

- [ ] **Step 5: Commit.** `feat(trips): read which of a trip's dives are plans nobody has dived`

---

### Task 2: The picker model

**Files:**
- Create: `lib/features/trips/domain/services/trip_picker_model.dart`
- Test: `test/features/trips/domain/services/trip_picker_model_test.dart`

**Interfaces:**
- Consumes: `TripStoryDay`, `Dive`, `DiveProfilePoint` (`timestamp` is seconds from dive start, `depth` is meters), `EstimatedProfile.estimate({required double? maxDepth, Duration? runtime, Duration? bottomTime})`.
- Produces:

```dart
class TripPickerPoint extends Equatable {
  const TripPickerPoint(this.seconds, this.depth); // seconds from the shape's start, meters
  final double seconds;
  final double depth;
}

class TripPickerDive extends Equatable {
  final String diveId;
  final List<TripPickerPoint> points; // at least two
  final bool dashed;                  // an estimate, or a dive that has not happened
  double get spanSeconds;             // points.last.seconds
  double get maxDepth;
}

class TripPickerDay extends Equatable {
  final DateTime date;
  final List<TripPickerDive> dives;   // in entry-time order
  double get spanSeconds;             // sum of its dives' spans
}

class TripPickerModel extends Equatable {
  final List<TripPickerDay> days;     // one per story day, same order
  final double maxDepth;              // 0 when nothing is drawn
  final double widestDaySeconds;      // 0 when nothing is drawn
}

TripPickerModel buildTripPickerModel({
  required List<TripStoryDay> days,
  required Map<String, List<DiveProfilePoint>> profiles,
  required Set<String> undivedPlanIds,
});
```

The rule per dive, in order:

1. `notHappened = dive.isDraft || undivedPlanIds.contains(dive.id)`.
2. `profiles[dive.id]` has points: a shape from them, `seconds` measured from the first sample; `dashed = notHappened`.
3. `profiles[dive.id]` is an empty list (the dive has no samples): a shape from `EstimatedProfile.estimate(maxDepth: dive.maxDepth, runtime: dive.measuredRuntime, bottomTime: dive.bottomTime)`, `dashed = true`; no shape when that returns null.
4. No entry for the dive (not known yet, or unreadable): no shape.

A shape with fewer than two points or a zero span is dropped.

- [ ] **Step 1: Write the failing tests.**

```dart
TripStoryDay day(DateTime date, List<Dive> dives) => TripStoryDay(/* date, dayNumber: 1, dives, kind: past, rest empty */);
List<DiveProfilePoint> pts(List<(int, double)> p) =>
    [for (final (t, d) in p) DiveProfilePoint(timestamp: t, depth: d)];

test('a recorded profile is a solid shape of its own span', () {
  final model = buildTripPickerModel(
    days: [day(d1, [Dive(id: 'a', dateTime: d1)])],
    profiles: {'a': pts([(10, 0), (600, 30), (3010, 0)])},
    undivedPlanIds: const {},
  );
  final shape = model.days.single.dives.single;
  expect(shape.dashed, isFalse);
  expect(shape.points.first.seconds, 0);
  expect(shape.spanSeconds, 3000);
  expect(shape.maxDepth, 30);
});

test('a dive with no samples draws its estimate, dashed', () {
  final dive = Dive(id: 'a', dateTime: d1, maxDepth: 20, runtime: const Duration(minutes: 40));
  final model = buildTripPickerModel(
    days: [day(d1, [dive])], profiles: {'a': const []}, undivedPlanIds: const {});
  final shape = model.days.single.dives.single;
  expect(shape.dashed, isTrue);
  expect(shape.spanSeconds, 2400);
  expect(shape.maxDepth, 20);
});

test('a plan nobody has dived and a draft draw dashed even with a stored profile', () {
  final profile = pts([(0, 0), (300, 18), (2400, 0)]);
  final model = buildTripPickerModel(
    days: [day(d1, [
      Dive(id: 'plan', dateTime: d1, isPlanned: true),
      Dive(id: 'draft', dateTime: d1.add(const Duration(hours: 2)), isDraft: true),
      Dive(id: 'mirror', dateTime: d1.add(const Duration(hours: 4)), isPlanned: true),
    ])],
    profiles: {'plan': profile, 'draft': profile, 'mirror': profile},
    undivedPlanIds: const {'plan'},
  );
  expect([for (final s in model.days.single.dives) s.dashed], [true, true, false]);
});
```

Also, one test each, same style:
- `'a dive with no cache entry draws nothing'`: `profiles: {}` gives `days.single.dives` empty.
- `'a dive with no samples and nothing to estimate from draws nothing'`: empty entry, no depth.
- `'dives are in entry-time order'`: two dives passed latest first come out earliest first (use `effectiveEntryTime`).
- `'both scales cover every shape, dashed ones included'`: two days; `maxDepth` is the deepest of all shapes and `widestDaySeconds` is the larger day's summed span.
- `'a trip that draws nothing has zero scales'` (Review Focus 2): every day present with no dives, `maxDepth == 0`, `widestDaySeconds == 0`.
- `'a day with no dives keeps its place'`: `model.days.length == days.length`.

- [ ] **Step 2: Run them.** `flutter test test/features/trips/domain/services/trip_picker_model_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** the classes and `buildTripPickerModel`.
- [ ] **Step 4: Run them.** Expected: pass.
- [ ] **Step 5: Commit.** `feat(trips): model what each day draws in the trip day picker`

---

### Task 3: Tile layout and painter

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_day_picker_painter.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_day_picker_painter_test.dart`

**Interfaces:**
- Consumes: `TripPickerDay`, `TripPickerDive` (Task 2).
- Produces:

```dart
const double kTripPickerSurfaceY = 4;     // the surface line, from the tile's top
const double kTripPickerBottomInset = 2;
const double kTripPickerSideInset = 3;
const double kTripPickerDiveGap = 2;
const double kTripPickerMinDiveWidth = 3;

class TripPickerShape {
  final Path path;    // closed along the surface line
  final Rect bounds;
  final bool dashed;
}

/// Lays [day]'s dives out inside a tile of [size], on the trip's scales.
List<TripPickerShape> layoutTripPickerDay(
  TripPickerDay day, {
  required Size size,
  required double maxDepth,
  required double widestDaySeconds,
});

class TripDayPickerPainter extends CustomPainter {
  TripDayPickerPainter({
    required this.day,
    required this.maxDepth,
    required this.widestDaySeconds,
    required this.surfaceColor,
    required this.shapeColor,
    required this.fillOpacity,
  });
}
```

Layout rules:
- Depth: `(size.height - kTripPickerSurfaceY - kTripPickerBottomInset) / maxDepth` points per meter, from `kTripPickerSurfaceY` down.
- Width: `usable = size.width - 2 * kTripPickerSideInset`. Points per second is `usable / widestDaySeconds`, the same for every tile. A dive's width is `max(kTripPickerMinDiveWidth, span * pointsPerSecond)`.
- When a day's widths plus gaps exceed `usable` (the widest day's own gaps, or minimum widths on a crowded day), scale that day's widths and gaps down together so it fits exactly.
- The day's run of shapes is centred in the tile.
- `maxDepth <= 0` or `widestDaySeconds <= 0` returns no shapes.
- Time always runs left to right, in every text direction.

Painting: the surface line across the full width at `kTripPickerSurfaceY`, 1.5 wide, in `surfaceColor`. A solid shape is filled with `shapeColor` at `fillOpacity` and outlined in `shapeColor`, 1 wide, round joins. A dashed shape has no fill and a dashed outline, 3 on and 3 off, built with `PathMetric.extractPath` (the repo has no dash helper).

- [ ] **Step 1: Write the failing tests** on `layoutTripPickerDay`, tile `Size(40, 60)`:

```dart
test('the deepest dive of the trip reaches the bottom; a half-depth dive goes half way', () {
  final shapes = layoutTripPickerDay(dayOf([dive(span: 3000, depth: 40), dive(span: 3000, depth: 20)]),
      size: const Size(40, 60), maxDepth: 40, widestDaySeconds: 6000);
  expect(shapes[0].bounds.bottom, closeTo(58, 0.01)); // 60 - bottom inset
  expect(shapes[1].bounds.bottom, closeTo(31, 0.01)); // 4 + (58 - 4) / 2
  expect(shapes[0].bounds.top, closeTo(4, 0.01));
});

test('widths follow span on the trip scale, and the run is centred', () {
  final shapes = layoutTripPickerDay(dayOf([dive(span: 1500, depth: 20)]),
      size: const Size(40, 60), maxDepth: 40, widestDaySeconds: 6000);
  expect(shapes.single.bounds.width, closeTo(34 * 1500 / 6000, 0.01));
  expect(shapes.single.bounds.center.dx, closeTo(20, 0.01));
});

test('eight dives in a narrow tile stay inside it', () { // Review Focus 1
  final shapes = layoutTripPickerDay(dayOf([for (var i = 0; i < 8; i++) dive(span: 60, depth: 10)]),
      size: const Size(38, 60), maxDepth: 40, widestDaySeconds: 20000);
  expect(shapes, hasLength(8));
  expect(shapes.first.bounds.left, greaterThanOrEqualTo(3));
  expect(shapes.last.bounds.right, lessThanOrEqualTo(35));
});

test('zero scales lay out nothing', () { // Review Focus 2
  expect(layoutTripPickerDay(dayOf([dive(span: 60, depth: 10)]),
      size: const Size(40, 60), maxDepth: 0, widestDaySeconds: 0), isEmpty);
});
```

Also: `'a very short dive keeps the minimum width'` (width `>= 3`), `'dashed carries through'`, and a painter test that `shouldRepaint` is true when `day`, a scale or a colour changes and false otherwise.

- [ ] **Step 2: Run.** `flutter test test/features/trips/presentation/widgets/story/trip_day_picker_painter_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** the layout function and the painter.
- [ ] **Step 4: Run.** Expected: pass.
- [ ] **Step 5: Commit.** `feat(trips): lay out and paint a day's dives as hanging profiles`

---

### Task 4: The day picker and its strings

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_day_picker.dart`
- Modify: `lib/l10n/arb/app_*.arb` (all 11)
- Test: `test/features/trips/presentation/widgets/story/trip_day_picker_test.dart`

**Interfaces:**
- Consumes: `TripPickerModel` (Task 2), `TripDayPickerPainter` (Task 3), `TripStoryDay`.
- Produces:

```dart
class TripDayPicker extends ConsumerStatefulWidget {
  const TripDayPicker({
    super.key,
    required this.days,          // List<TripStoryDay>, story order
    required this.model,         // TripPickerModel, same length as days
    required this.selectedDate,  // DateTime?; null is the Trip tile
    required this.onSelect,      // ValueChanged<DateTime?>; null is the Trip tile
    this.chartHeight = 60,
  });

  static const double tripTileWidth = 40;
  static const double minDayTileWidth = 38;
  static const tripTileKey = Key('trip-picker-tile-trip');
  static Key dayTileKey(int dayNumber) => Key('trip-picker-tile-$dayNumber');
}
```

New strings, English values (`app_en.arb`, with `@` metadata; placeholders declared in the order shown):

| Key | Value |
| --- | --- |
| `trips_story_tripTile` | `Trip` |
| `trips_story_tripTileAll` | `All` |
| `trips_story_tripTile_semantics` | `Whole trip` |
| `trips_story_dayTile_semantics` | `{date}, day {number}` |
| `trips_story_dayTile_deepest` | `deepest {depth}` |
| `trips_story_noDivesThisDay` | `No dives this day` |
| `trips_story_dayMaxDepth` | `{depth} max` |

Behaviour:
- A `Row`: the Trip tile at fixed `tripTileWidth`, a 1 point rule in `outlineVariant`, then the day tiles.
- `dayTileWidth = max(minDayTileWidth, availableWidth / days.length)`. When the tiles are wider than the space, they sit in a horizontal scroll view with its own controller; the Trip tile is outside it.
- On first build and whenever `selectedDate` changes, the selected tile is scrolled into view after the frame.
- A day tile: weekday abbreviation over day of month (`DateFormat.E` and `DateFormat.d` for the context's locale; check `UnitFormatter` first for an existing equivalent and use it if there is one), then a `CustomPaint` of `chartHeight` with `TripDayPickerPainter`.
- The Trip tile: `trips_story_tripTile` over `trips_story_tripTileAll`, with `Icons.view_agenda_outlined` centred in the chart area.
- Colours: surface line `primary`; selected column `primaryContainer`; selected shapes `onPrimaryContainer` at fill opacity 0.55; other shapes `primary` at 0.45 with the outline at 0.6 alpha.
- Today's tile (`day.kind == TripStoryDayKind.today`): label in `primary`, bold.
- Each tile is one semantics node: `Semantics(button: true, selected: isSelected, label: ..., excludeSemantics: true)` wrapping the `InkWell`. The day label is `trips_story_dayTile_semantics(formatWeekdayMonthDay(date), dayNumber)`, then `diveLog_listPage_tripGroupDiveCount(count)` when the day has dives, then `trips_story_dayTile_deepest(units.formatDepth(day.maxDepth))` when it has a depth, then `trips_story_today` on today, joined with `, `.
- With the strip focused, the left and right arrow keys move the selection one tile along the order Trip, day 1, day 2, and so on, following the text direction.

- [ ] **Step 1: Add the seven strings** to all 11 ARB files with real translations, then `flutter gen-l10n`. Run `flutter test test/l10n`. Expected: pass.

- [ ] **Step 2: Write the failing tests.** A `pumpPicker(tester, {days, model, selectedDate, width = 360, textScale = 1, locale = 'en'})` helper pumps the picker in a `SizedBox(width: width)` and records `onSelect` calls.

```dart
testWidgets('tapping a day tile selects its date; the Trip tile selects null', (tester) async {
  await pumpPicker(tester, days: sixDays, model: sixDayModel, selectedDate: null);
  await tester.tap(find.byKey(TripDayPicker.dayTileKey(2)));
  await tester.tap(find.byKey(TripDayPicker.tripTileKey));
  expect(selections, [sixDays[1].date, null]);
});

testWidgets('six days fit a phone without scrolling', (tester) async {
  await pumpPicker(tester, days: sixDays, model: sixDayModel, selectedDate: null);
  expect(tester.getSize(find.byKey(TripDayPicker.dayTileKey(1))).width, closeTo((360 - 41) / 6, 0.5));
});

testWidgets('fourteen days scroll, the Trip tile stays put, the selected day is in view', (tester) async {
  await pumpPicker(tester, days: fourteenDays, model: fourteenDayModel, selectedDate: fourteenDays[11].date);
  await tester.pumpAndSettle();
  final tripLeft = tester.getTopLeft(find.byKey(TripDayPicker.tripTileKey)).dx;
  final selected = tester.getRect(find.byKey(TripDayPicker.dayTileKey(12)));
  expect(selected.left, greaterThanOrEqualTo(tripLeft + TripDayPicker.tripTileWidth));
  expect(selected.right, lessThanOrEqualTo(360));
  await tester.drag(find.byKey(TripDayPicker.dayTileKey(12)), const Offset(200, 0));
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(find.byKey(TripDayPicker.tripTileKey)).dx, tripLeft);
});

testWidgets('a day tile says what it draws and whether it is selected', (tester) async {
  await pumpPicker(tester, days: sixDays, model: sixDayModel, selectedDate: sixDays[1].date);
  expect(
    tester.getSemantics(find.byKey(TripDayPicker.dayTileKey(2))),
    containsSemantics(
      label: 'Thu, Oct 29, day 2, 3 dives, deepest 30.2m', // match UnitFormatter's own output
      isButton: true,
      isSelected: true,
    ),
  );
});
```

Also:
- `'a one-day trip has a Trip tile and one day tile'`.
- `'at text scale 2.0 nothing overflows'` (Review Focus 4): pump with `textScale: 2`, expect `tester.takeException()` is null.
- `'in a right-to-left locale the Trip tile is at the start edge and days follow in reading order'` (Review Focus 5): locale `ar`; the Trip tile's right edge is at the strip's right; day 1 is right of day 2.
- `'the right arrow moves the selection to the next tile'`.
- `'a day with no dives says only its date and number'`.
- `'today\'s tile says Today'`: on a story under way, today's tile label ends with `Today`.

- [ ] **Step 3: Run.** `flutter test test/features/trips/presentation/widgets/story/trip_day_picker_test.dart`. Expected: compile failure.
- [ ] **Step 4: Implement** `TripDayPicker`.
- [ ] **Step 5: Run.** The picker test, then `flutter test test/architecture test/shared`. Expected: pass.
- [ ] **Step 6: Commit.** `feat(trips): add the day picker strip`

---

### Task 5: Lift the shared pieces out

A move with no behaviour change. The existing tests are the proof.

**Files:**
- Create: `story/trip_day_sections.dart`, `story/trip_story_empty_state.dart`, `story/trip_under_way_cards.dart`, `day/day_subtitle.dart` (all under `lib/features/trips/presentation/widgets/`)
- Modify: `story/trip_story_day_card.dart`, `story/trip_story_day_header.dart`, `story/trip_story_hero.dart`, `story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_under_way_cards_test.dart`, `test/features/trips/presentation/widgets/day/day_subtitle_test.dart`

**Interfaces:**
- Produces:

```dart
// trip_day_sections.dart, bodies moved unchanged from trip_story_day_card.dart
class TripDaySectionCaption extends StatelessWidget { const TripDaySectionCaption({super.key, required this.text}); }
class TripDayPhotoStrip extends StatelessWidget {
  const TripDayPhotoStrip({super.key, required this.tripId, required this.media, required this.totalCount});
}
class TripDaySightingChips extends StatelessWidget { const TripDaySightingChips({super.key, required this.day}); }

// trip_story_empty_state.dart, body moved unchanged from TripStoryHero's _EmptyState
class TripStoryEmptyState extends StatelessWidget { const TripStoryEmptyState({super.key, required this.onScanForDives}); }

// trip_under_way_cards.dart
/// The cylinders summary, then the return flight countdown while the trip is
/// in progress and has a return flight. Each still hides itself as it does now.
class TripUnderWayCards extends StatelessWidget { const TripUnderWayCards({super.key, required this.trip}); }

// day_subtitle.dart, logic moved unchanged from TripStoryDayHeader.build
/// "Surface day" or the shown day type, then the port, then the site names;
/// trimmed, blanks dropped.
List<String> tripDaySubtitleParts(TripStoryDay day, AppLocalizations l10n);
```

- [ ] **Step 1: Write the failing tests.** `day_subtitle_test.dart`: `'a blank port leaves no doubled separator'` (port `'  '`, one site: parts are `['Dive Day', 'Reef']`), `'a surface day leads with Surface day'`, `'a rest day with a dive logged reads as a dive day'`. `trip_under_way_cards_test.dart`: `'a finished trip shows neither card'` and `'a trip under way with a return flight shows the countdown'` (find `TripFlightCountdownCard`).
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Move the code** and point the old call sites at the new names. `TripStoryView` builds `TripUnderWayCards` where it built the two cards.
- [ ] **Step 4: Run.** `flutter test test/features/trips/presentation/widgets`. Expected: everything passes, the existing story tests included, unchanged.
- [ ] **Step 5: Commit.** `refactor(trips): lift the story's shared parts into their own widgets`

---

### Task 6: A day's head

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_head.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_head_test.dart`

**Interfaces:**
- Consumes: `tripDaySubtitleParts` (Task 5); `DayWeatherBadge`, `TodayChip`, `TripStoryDayWeather.resolve`; `formatDayRuntime`; strings from Task 4.
- Produces:

```dart
class TripStoryDayHead extends ConsumerWidget {
  const TripStoryDayHead({super.key, required this.day, required this.dayCount, this.storedWeather});
  final TripStoryDay day;
  final int dayCount;                        // the trip's number of days
  final TripStoryDayWeather? storedWeather;
}
```

Content:
- Title: `units.formatWeekdayMonthDay(day.date)`, `titleLarge`, bold.
- Line 1: `trips_story_dayOfTrip(day.dayNumber, dayCount)` followed by `tripDaySubtitleParts`, joined with ` · `, `bodySmall` in `onSurfaceVariant`, wrapping to a second line when long.
- Line 2, only when `day.dives.isNotEmpty`: `diveLog_listPage_tripGroupDiveCount(day.diveCount)`, `formatDayRuntime(day.totalRuntime)`, and `trips_story_dayMaxDepth(units.formatDepth(day.maxDepth))` when `day.maxDepth != null`, joined with ` · `, `bodyMedium`, weight 600.
- Trailing: the weather badge when `DayWeatherBadge.rendersAnything`, then `TodayChip` on today, or the `trips_story_planned` chip on a day ahead.
- No background, no band, no number badge.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('says where the day sits and what it added up to', (tester) async {
  await pumpHead(tester, day: thursdayWithThreeDives, dayCount: 6);
  expect(find.text('Thu, Oct 29'), findsOneWidget);
  expect(find.text('Day 2 of 6 · Dive Day · Big Brother'), findsOneWidget);
  expect(find.text('3 dives · 2h 31m · 30.2m max'), findsOneWidget); // match UnitFormatter's own output
});

testWidgets('max depth follows the diver\'s unit', (tester) async {
  await pumpHead(tester, day: thursdayWithThreeDives, dayCount: 6, imperial: true);
  expect(find.textContaining('ft max'), findsOneWidget);
});

testWidgets('a day with no dives has no totals line', (tester) async {
  await pumpHead(tester, day: surfaceDay, dayCount: 6);
  expect(find.text('Day 6 of 6 · Surface day'), findsOneWidget);
  expect(find.textContaining(' max'), findsNothing);
});
```

Also: `'today carries the Today chip'`, `'a day ahead carries the Planned chip'`, `'weather shows when there is any'`, and `'at text scale 2.0 nothing overflows at 320 wide'` (Review Focus 4).

- [ ] **Step 2: Run.** Expected: compile failure.
- [ ] **Step 3: Implement** `TripStoryDayHead`.
- [ ] **Step 4: Run.** Expected: pass.
- [ ] **Step 5: Commit.** `feat(trips): add the day page's head`

---

### Task 7: A day's page, single column

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_page.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_page_test.dart`

**Interfaces:**
- Consumes: `TripStoryDayHead` (Task 6); `TripUnderWayCards`, `TripDayPhotoStrip`, `TripDaySightingChips`, `TripDaySectionCaption` (Task 5); `TripDayMap`, `TripStoryDayPlan`, `DayRhythmBar`, `DayConditionsLine`, `DiveListItem`, `showTripDayMapPage`, `siteHistoryByNameProvider`; `trips_story_noDivesThisDay`.
- Produces:

```dart
class TripStoryDayPage extends ConsumerStatefulWidget {
  const TripStoryDayPage({
    super.key,
    required this.story,
    required this.day,
    required this.mapPoints,    // story.mapGeometry.pointsForDay(index)
    this.storedWeather,
  });
  static const double twoColumnMinWidth = 600;   // used from Task 8
  static const noDivesKey = Key('trip-day-no-dives');
}
```

The page is one vertical scroll view with 16 points of side padding. In order, each only when it has content:

1. `TripUnderWayCards(trip: story.trip)`, only when `day.kind == TripStoryDayKind.today && story.trip.isInProgress`.
2. `TripStoryDayHead`.
3. The map: `TripDayMap` at 180 high in a `ClipRRect` of radius 8, `interactive: false`, `onExpand` opening `showTripDayMapPage`, `onDiveTap` setting the highlighted dive.
4. `TripStoryDayPlan`, with `hasHistory` worked out as `TripStoryDayCard` works it out now.
5. `DayRhythmBar` then `DayConditionsLine`, when the day has dives. No tinted container.
6. One `DiveListItem` per dive, built exactly as `TripStoryDayCard` builds them now (resolvers, `fullDive`, `diveNumber`, `isHighlighted`, `onTap` pushing `/dives/<id>`).
7. `TripDaySectionCaption` and `TripDayPhotoStrip`, when the day has media.
8. `TripDaySectionCaption` and `TripDaySightingChips`, when it has sightings.
9. When the day has no dives and no plan content: `Text(trips_story_noDivesThisDay)` keyed `noDivesKey`, `bodyMedium` in `onSurfaceVariant`.

The pin-tap behaviour moves here from `_TripStoryDayCardState._onPinTap` unchanged: highlight the dive, and call `Scrollable.ensureVisible` with `keepVisibleAtEnd` only when its card is off screen. There is no `Card` and no `Opacity` around the day.

- [ ] **Step 1: Write the failing tests.** Use `tester.getTopLeft(...).dy` to assert order.

```dart
testWidgets('a dive day runs head, map, timeline, dives, photos, species', (tester) async {
  await pumpDayPage(tester, story: finishedStory, dayIndex: 1);
  final ys = [
    find.byType(TripStoryDayHead), find.byType(TripDayMap), find.byType(DayRhythmBar),
    find.byType(DiveListItem).first, find.byType(TripDayPhotoStrip), find.byType(TripDaySightingChips),
  ].map((f) => tester.getTopLeft(f).dy).toList();
  expect(ys, orderedEquals([...ys]..sort()));
  expect(find.byType(DiveListItem), findsNWidgets(3));
});

testWidgets('today leads with the under-way cards while the trip is under way; other days do not', (tester) async {
  await pumpDayPage(tester, story: underWayStory, dayIndex: underWayStory.todayIndex!);
  expect(find.byType(TripUnderWayCards), findsOneWidget);
  expect(tester.getTopLeft(find.byType(TripUnderWayCards)).dy,
      lessThan(tester.getTopLeft(find.byType(TripStoryDayHead)).dy));
  await pumpDayPage(tester, story: underWayStory, dayIndex: 0);
  expect(find.byType(TripUnderWayCards), findsNothing);
});

testWidgets('a surface day shows its head and one quiet line', (tester) async {
  await pumpDayPage(tester, story: finishedStory, dayIndex: 5);
  expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
  expect(find.byType(DiveListItem), findsNothing);
  expect(find.byType(TripDayMap), findsNothing);
});
```

Also: `'a day ahead shows its plan and the cards of dives planned for it'`, `'tapping a pin highlights that dive\'s card'` (port from `trip_story_day_card_test.dart`), `'tapping a card opens the dive'`, `'no card wraps the day'` (`find.ancestor(of: find.byType(DiveListItem), matching: find.byType(Card))` finds nothing), and `'the timeline has no tinted box'` (`find.byKey(const Key('day-summary-band'))` finds nothing).

- [ ] **Step 2: Run.** Expected: compile failure.
- [ ] **Step 3: Implement** the single-column page.
- [ ] **Step 4: Run.** Expected: pass.
- [ ] **Step 5: Commit.** `feat(trips): add the day page`

---

### Task 8: The day page's two columns

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_page.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_page_test.dart`

**Interfaces:**
- Produces: `static const twoColumnsKey = Key('trip-day-two-columns')` on `TripStoryDayPage`.

A `LayoutBuilder` around the page. When the width is at least `twoColumnMinWidth` and `mapPoints` is not empty, the items after the head become a `Row` keyed `twoColumnsKey`, `crossAxisAlignment: start`, with a 16 point gap and two `Expanded` columns:
- Left: map (230 high), plan, timeline and conditions, photos, species.
- Right: the dive cards.

The under-way cards and the head stay full width above the row. It is still one scroll view. Otherwise the page is Task 7's column.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('at 640 wide the map sits beside the dives', (tester) async {
  await pumpDayPage(tester, story: finishedStory, dayIndex: 1, width: 640);
  expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsOneWidget);
  final map = tester.getRect(find.byType(TripDayMap));
  final card = tester.getRect(find.byType(DiveListItem).first);
  expect(card.left, greaterThan(map.right));
  expect((card.top - map.top).abs(), lessThan(40));
  expect(tester.getSize(find.byType(TripDayMap)).height, 230);
});

testWidgets('at 599 wide it is one column', (tester) async {
  await pumpDayPage(tester, story: finishedStory, dayIndex: 1, width: 599);
  expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
});

testWidgets('a day with no map points is one column at any width', (tester) async {
  await pumpDayPage(tester, story: storyWithoutLocations, dayIndex: 1, width: 900);
  expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
});
```

Also `'photos and species sit under the map, not under the dives'` at 640.

- [ ] **Step 2: Run.** Expected: the three new tests fail.
- [ ] **Step 3: Implement** the two-column branch. Check it by eye at half a desktop pane: each column is about phone width.
- [ ] **Step 4: Run.** Expected: the whole file passes.
- [ ] **Step 5: Commit.** `feat(trips): put the day's map beside its dives on a wide pane`

---

### Task 9: The Trip page

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_line.dart`, `lib/features/trips/presentation/widgets/story/trip_story_trip_page.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_trip_page_test.dart`

**Interfaces:**
- Consumes: `tripDaySubtitleParts`, `TripUnderWayCards`, `TripStoryEmptyState` (Task 5); `TripCountryFlags`, `tripHasFlags`, `TripVesselSection`, `MarkdownNotesView`, `DocumentsSection`, `TodayChip`.
- Produces:

```dart
class TripStoryDayLine extends ConsumerWidget {
  const TripStoryDayLine({super.key, required this.day, required this.onTap});
  static Key keyFor(int dayNumber) => Key('trip-day-line-$dayNumber');
}

class TripStoryTripPage extends ConsumerWidget {
  const TripStoryTripPage({
    super.key,
    required this.story,
    required this.stats,          // TripWithStats
    required this.onSelectDay,    // ValueChanged<DateTime>
    this.onScanForDives,
  });
  static const totalsKey = Key('trip-page-totals');
}
```

The page is one vertical scroll view, one column at every width. In order:

1. The dates line: `formatDate(start)`, `formatDate(end)` and `trips_detail_durationDays(trip.durationDays)` as `TripStoryHero` writes them now, with `TripCountryFlags(tripId:, flagHeight: 14)` after it when `tripHasFlags`. When `trip.isInProgress`, `trips_story_dayOfTrip(todayIndex + 1, days.length)` under it in `primary`, bold.
2. The totals, keyed `totalsKey`: the same entries and labels `TripStatStrip` builds now (dives, runtime, max depth when known, sites visited when above zero), values in `titleLarge` bold, labels in `labelSmall`, no background colour. Sites visited is the count of distinct `dive.site?.id` across `story.days`.
3. `TripUnderWayCards(trip: trip)`.
4. One `TripStoryDayLine` per day, with a 1 point `outlineVariant` rule between lines.
5. `TripVesselSection(tripId:)` when `trip.isLiveaboard`.
6. The notes card, as `TripStoryView` builds it now, when `trip.notes.isNotEmpty`.
7. `DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.trip, trip.id))`.

When `story.isEmpty`, items 2 to 4 are replaced by `TripStoryEmptyState(onScanForDives: onScanForDives)`.

`TripStoryDayLine`: a 28 point round number badge (`primaryContainer`; `surfaceContainerHighest` on a surface day), `formatWeekdayMonthDay(day.date)` in `titleSmall` over `tripDaySubtitleParts` joined with ` · ` in `bodySmall`, then at the right the dive count over the max depth when the day has dives, `TodayChip` on today, and a chevron. A surface day (`day.isSurface || day.isPlannedRest`) is drawn in `onSurfaceVariant`. The whole line is one `InkWell` with `Semantics(button: true)`; its label is the date followed by the subtitle parts.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('a finished trip lists dates, totals, a line per day, notes and documents, in that order', (tester) async {
  await pumpTripPage(tester, story: finishedStory, stats: finishedStats);
  expect(find.byType(TripStoryDayLine), findsNWidgets(6));
  expect(tester.getTopLeft(find.byKey(TripStoryTripPage.totalsKey)).dy,
      lessThan(tester.getTopLeft(find.byKey(TripStoryDayLine.keyFor(1))).dy));
  expect(tester.getTopLeft(find.byKey(TripStoryDayLine.keyFor(6))).dy,
      lessThan(tester.getTopLeft(find.byType(DocumentsSection)).dy));
  expect(find.byType(TripFlightCountdownCard), findsNothing);
});

testWidgets('tapping a day line selects that day', (tester) async {
  await pumpTripPage(tester, story: finishedStory, stats: finishedStats);
  await tester.tap(find.byKey(TripStoryDayLine.keyFor(3)));
  expect(selected, [finishedStory.days[2].date]);
});

testWidgets('an empty trip shows the empty state in place of totals and day lines', (tester) async {
  await pumpTripPage(tester, story: emptyStory, stats: emptyStats);
  expect(find.byType(TripStoryEmptyState), findsOneWidget);
  expect(find.byKey(TripStoryTripPage.totalsKey), findsNothing);
  expect(find.byType(TripStoryDayLine), findsNothing);
});
```

Also: `'a trip under way says Day N of M and shows the under-way cards above the day lines'`, `'a liveaboard shows its vessel after the day lines'`, `'a surface day\'s line shows no dive count'`, `'today\'s line carries the Today chip'`, and `'the trip name is not on the page'` (`find.text(trip.name)` finds nothing).

- [ ] **Step 2: Run.** Expected: compile failure.
- [ ] **Step 3: Implement** both widgets.
- [ ] **Step 4: Run.** Expected: pass.
- [ ] **Step 5: Commit.** `feat(trips): add the whole-trip page`

---

### Task 10: Put it together

This is the first task that changes what a diver sees.

**Files:**
- Rewrite: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_detail_tabs.dart`, `lib/features/trips/presentation/widgets/trip_overview_tab.dart`
- Delete: `story/trip_story_day_card.dart`, `story/trip_story_day_header.dart`, `story/trip_stat_strip.dart`, and `trip_story_day_card_test.dart`, `trip_story_day_header_test.dart`, `trip_stat_strip_test.dart`
- Test: rewrite `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`; update `trip_overview_tab_test.dart`, `trip_detail_tabs_test.dart`, `test/features/trips/presentation/pages/trip_detail_page_test.dart`, `test/features/trips/presentation/providers/trip_providers_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1 to 9; `diveProfileBatcherProvider`, `batchProfileCacheProvider`; `tripDayWeatherProvider`, `tripDayWeatherBackfillProvider`, `tripDayMillis`.
- Produces:

```dart
/// Which page of the story shows. A null date is the Trip page.
class TripStorySelection extends Equatable {
  const TripStorySelection.trip() : date = null;
  const TripStorySelection.day(DateTime this.date);
  final DateTime? date;
}

class TripStoryView extends ConsumerStatefulWidget {
  const TripStoryView({
    super.key,
    required this.story,
    required this.stats,
    this.selection,       // ValueNotifier<TripStorySelection?>?; the view owns one when null
    this.onScanForDives,
  });
}
```

`TripOverviewTab` gains `final ValueNotifier<TripStorySelection?>? selection` and passes it through. `TripDetailTabs` becomes a `StatefulWidget` whose state owns one `ValueNotifier<TripStorySelection?>(null)`, sets it back to null in `didUpdateWidget` when `tripWithStats.trip.id` changes, and disposes it.

`TripStoryView` behaviour:
- **The page shown** is `selection.value`, or the opening rule while that is null: `TripStorySelection.day(today's date)` when `story.todayIndex != null && story.trip.isInProgress`, otherwise `TripStorySelection.trip()`. The opening rule is computed, never written into the notifier during build.
- A selected date that is no longer one of `story.days` shows the Trip page.
- Layout: a `Column` of `TripDayPicker` and `Expanded(page)`, inside a `LayoutBuilder`. `chartHeight` is 76 when the width is at least `TripStoryDayPage.twoColumnMinWidth`, otherwise 60.
- The day page is built with `key: ValueKey(day.date)` so a new day starts scrolled to the top.
- `onSelect` and `onSelectDay` write the notifier.
- **Profiles:** in `initState`, and in `didUpdateWidget` when the story's set of dive ids changes, schedule `ref.read(diveProfileBatcherProvider).load(ids)` after the frame, with every dive id in the story. The picker is wrapped in a `Consumer` that watches `batchProfileCacheProvider` and `tripUndivedPlanIdsProvider(trip.id)` (an empty set until it resolves) and builds `buildTripPickerModel`, so a cache write rebuilds only the picker.
- The view still watches `tripDayWeatherProvider(tripId)` and `tripDayWeatherBackfillProvider(tripId)` and hands each day its stored weather, as it does now.

- [ ] **Step 1: Capture the "before" screenshots** of the current page for the PR: a finished trip, a trip under way, a surface day, in light and dark, at phone and desktop widths. Read `docs/contributing/pull-requests.md` first. Keep them outside the repo.

- [ ] **Step 2: Rewrite the story view tests** (failing). Keep the file's harness; `pumpView` gains an optional `selection`.

```dart
testWidgets('a finished trip opens on the Trip page', (tester) async {
  await pumpView(tester, finishedStory);
  expect(find.byType(TripStoryTripPage), findsOneWidget);
  expect(find.byType(TripStoryDayPage), findsNothing);
});

testWidgets('a trip under way opens on today', (tester) async {
  await pumpView(tester, underWayStory);
  expect(tester.widget<TripStoryDayPage>(find.byType(TripStoryDayPage)).day.kind, TripStoryDayKind.today);
});

testWidgets('a story that reaches today on a trip that has ended opens on the Trip page', (tester) async {
  await pumpView(tester, endedTripWithADiveToday);
  expect(find.byType(TripStoryTripPage), findsOneWidget);
});

testWidgets('a tile shows its day and only its day; the Trip tile comes back', (tester) async {
  await pumpView(tester, finishedStory);
  await tester.tap(find.byKey(TripDayPicker.dayTileKey(2)));
  await tester.pump();
  expect(tester.widget<TripStoryDayPage>(find.byType(TripStoryDayPage)).day.dayNumber, 2);
  expect(find.byType(TripStoryTripPage), findsNothing);
  await tester.tap(find.byKey(TripDayPicker.tripTileKey));
  await tester.pump();
  expect(find.byType(TripStoryTripPage), findsOneWidget);
});

testWidgets('the selected day vanishing falls back to the Trip page', (tester) async { // Review Focus 3
  final selection = ValueNotifier<TripStorySelection?>(TripStorySelection.day(DateTime(2026, 12, 25)));
  addTearDown(selection.dispose);
  await pumpView(tester, finishedStory, selection: selection);
  expect(find.byType(TripStoryTripPage), findsOneWidget);
  expect(tester.takeException(), isNull);
});

testWidgets('asks the batcher once for every dive on the trip', (tester) async {
  // Override diveRepositoryProvider with the mock from test/helpers/mock_providers.dart
  // and record getBatchProfileSummaries calls.
  await pumpView(tester, finishedStory);
  expect(batchCalls, hasLength(1));
  expect(batchCalls.single.toSet(), {for (final d in finishedStory.days) ...d.dives.map((x) => x.id)});
});
```

Also: `'a day line on the Trip page selects its day'`, `'the picker stays put while the page scrolls'` (drag the page; the picker's `getTopLeft` is unchanged), `'changing day starts at the top'`, `'the trip name is not repeated under the tabs'`, and `'a profile landing in the cache draws without rebuilding the page'` (write to `batchProfileCacheProvider`; the `TripStoryDayPage` element is the same instance).

In `trip_detail_tabs_test.dart`:

```dart
testWidgets('the chosen day survives a visit to another tab', (tester) async {
  await pumpTabs(tester, finishedTripWithStats);
  await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Itinerary'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Overview'));
  await tester.pumpAndSettle();
  expect(tester.widget<TripStoryDayPage>(find.byType(TripStoryDayPage)).day.dayNumber, 3);
});

testWidgets('a different trip starts from its own opening page', (tester) async {
  // pump with trip A, pick day 3, pump the same widget with trip B
  expect(find.byType(TripStoryTripPage), findsOneWidget);
});
```

- [ ] **Step 3: Run.** `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart test/features/trips/presentation/widgets/trip_detail_tabs_test.dart`. Expected: fail.

- [ ] **Step 4: Implement:** rewrite `TripStoryView`, thread `selection` through `TripOverviewTab`, make `TripDetailTabs` stateful, delete the three widgets and their three tests, and fix the references in `trip_overview_tab_test.dart`, `trip_detail_page_test.dart` and `trip_providers_test.dart` (each names a deleted widget in a finder or a comment).

- [ ] **Step 5: Run.** `flutter test test/features/trips`, then `flutter test test/architecture test/shared`, then `flutter test test/features/dive_log/data/repositories/dive_repository_without_samples_test.dart`. Expected: all pass, the last one with no change to the file.

- [ ] **Step 6: Commit.** `feat(trips): show a trip one day at a time, picked from its dive profiles`

---

### Task 11: Check it for real, and prepare the PR

**Files:** none in `lib/`, unless the checks find something.

- [ ] **Step 1: Format and analyze.** `dart format .` then `flutter analyze` over the whole repo. Expected: no changes left unformatted, no issues.
- [ ] **Step 2: Run the guards.** `flutter test test/architecture test/shared test/l10n test/core/database/dive_stats_scope_census_test.dart`. Expected: pass.
- [ ] **Step 3: Run the app on macOS** against a database of its own (`SUBMERSION_DB_PATH`), never the live one. Open a finished trip, a trip under way and a long trip. Check by hand: the opening page, each tile, the Trip tile, a day line, a pin tap in both layouts, the strip scrolling with the Trip tile fixed, a planned dive drawn dashed, the under-way cards on today and on the Trip page, dark mode, and a narrow window falling back to one column.
- [ ] **Step 4: Capture the "after" screenshots** to match the "before" set from Task 10.
- [ ] **Step 5: Stop and ask the maintainer** before anything leaves the machine. With their go-ahead: rewrite the "Approved design" section of issue #4106 to this design and set its Release field to `v1.8.5` on the Submersion Release Tracker; open the PR with `Closes #4106`, the screenshots attached through the project's secret gist, and the Summary following `.github/` PR template.
