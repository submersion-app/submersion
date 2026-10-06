# Trip Story Scroll Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the trip story view: keep the pinned map usable when collapsed (180px, map-only), make each day's title a sticky header that the next day pushes out, and remove the redundant right-side dive profile sparkline.

**Architecture:** The pinned `SliverPersistentHeader` map delegate becomes map-only with a taller `minExtent`; the trip stat strip moves into scrollable content. Each day becomes a `SliverMainAxisGroup` containing a pinned fixed-extent day header sliver plus the day card body — group semantics bound the pin to the day, giving "sticky until the next day arrives" natively. Spec: `docs/superpowers/specs/2026-07-23-trip-story-scroll-polish-design.md`.

**Tech Stack:** Flutter (Material 3), `SliverMainAxisGroup` (Flutter 3.13+, available — Dart SDK floor is ^3.10), flutter_map, Riverpod, flutter_test widget tests.

## Global Constraints

- Work in a dedicated git worktree (create via superpowers:using-git-worktrees), branch name `worktree-trip-story-scroll-polish`. After creating the worktree run `git submodule update --init --recursive` and `flutter pub get` before anything else.
- Run `dart format .` before every commit; CI fails on unformatted code.
- `flutter analyze` must report zero issues project-wide — info-level lints are fatal in CI. Never pipe analyze output through `tail`/`head` (it masks the exit code).
- No new l10n keys — every string used already exists (`trips_story_dayLabel`, `trips_story_planned`, day-type names via `day_type_l10n.dart`).
- No emojis in code, comments, or docs. Commit messages: conventional style (`feat(trips): ...`), no Co-Authored-By line.
- The wide (>= 900px) layout must keep the stat strip visible under the side-panel map (nothing scrolls in the panel).
- `flutter test` commands can take 1-3 minutes; use generous timeouts (>= 300000 ms) and never kill a run early.

---

### Task 1: Remove the redundant story DiveSparkline

The day card renders each dive row as `Row(DiveListItem, DiveSparkline)`. The shared `DiveListItem` card already renders its own configurable profile minimap, so the right-side sparkline is redundant. Note there are TWO `DiveSparkline` widgets in the repo — only the trips-story one is removed; `lib/core/presentation/widgets/dive_sparkline.dart` (used by the combine-dives dialog and import wizard) must NOT be touched.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`
- Delete: `lib/features/trips/presentation/widgets/story/dive_sparkline.dart`
- Delete: `test/features/trips/presentation/widgets/story/dive_sparkline_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: dive rows in `TripStoryDayCard` are bare `DiveListItem`s filling the card width (Task 5 reuses this block verbatim when it slims the card).

- [ ] **Step 1: Unwrap the dive rows in the day card**

In `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`, replace the `Row`-wrapped dive rows (currently around lines 67-88):

```dart
                ...day.dives.mapIndexed(
                  (index, dive) => Row(
                    children: [
                      Expanded(
                        child: DiveListItem(
                          summary: DiveSummary.fromDive(dive),
                          diveTypeLabelResolver: diveTypeLabelResolver,
                          // The story already holds the full Dive; pass it so the
                          // configurable card can resolve fields absent from the
                          // summary (tanks, SAC, buddies, weights).
                          fullDive: dive,
                          diveNumber: dive.diveNumber ?? index + 1,
                          onTap: () => context.push('/dives/${dive.id}'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: DiveSparkline(diveId: dive.id),
                      ),
                    ],
                  ),
                ),
```

with:

```dart
                ...day.dives.mapIndexed(
                  (index, dive) => DiveListItem(
                    summary: DiveSummary.fromDive(dive),
                    diveTypeLabelResolver: diveTypeLabelResolver,
                    // The story already holds the full Dive; pass it so the
                    // configurable card can resolve fields absent from the
                    // summary (tanks, SAC, buddies, weights).
                    fullDive: dive,
                    diveNumber: dive.diveNumber ?? index + 1,
                    onTap: () => context.push('/dives/${dive.id}'),
                  ),
                ),
```

Then delete the now-unused import near the top of the file:

```dart
import 'package:submersion/features/trips/presentation/widgets/story/dive_sparkline.dart';
```

- [ ] **Step 2: Delete the story sparkline widget and its test**

```bash
git rm lib/features/trips/presentation/widgets/story/dive_sparkline.dart
git rm test/features/trips/presentation/widgets/story/dive_sparkline_test.dart
```

- [ ] **Step 3: Verify nothing else references the deleted file**

Run: `rg -n "story/dive_sparkline" lib test`
Expected: no matches. (Matches for `core/presentation/widgets/dive_sparkline.dart` elsewhere are fine and untouched.)

- [ ] **Step 4: Run the story widget tests**

Run: `flutter test test/features/trips/presentation/widgets/story/ -r compact`
Expected: all tests pass (the deleted test file no longer runs).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "refactor(trips): drop redundant story dive sparkline"
```

---

### Task 2: Map-only pinned header with 180px floor; stat strip scrolls away

The pinned header currently hosts the map AND the stat strip, shrinking 260 -> 120 total (map ends up ~70px tall). Make the delegate map-only with `minExtent` 180, and relocate `TripStatStrip`: a normal scrollable sliver in the narrow layout, a fixed row under the map in the wide side panel.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `TripStoryMapHeaderDelegate({required geometry, required activeDayIndex, required mapController, required onDaySelected, required maxExtentValue, minExtentValue = 180})` — NO `stats`/`siteCount` params. `TripStatStrip` is unchanged and constructed by `TripStoryView` directly. Task 5's view tests rely on the collapsed map height being exactly 180.

- [ ] **Step 1: Update the map header tests to the map-only contract**

Rewrite `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart` with these changes (leave the `_AnimatorHarness`, `_trip`, imports, and the animator test untouched):

Replace `pumpHeader` with a stats-free version, and add a `pumpStrip` helper for the relocated stat strip tests:

```dart
Future<void> pumpHeader(
  WidgetTester tester,
  TripStoryMapGeometry geometry,
) async {
  final overrides = await getBaseOverrides();
  final controller = MapController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: TripStoryMapHeaderDelegate(
                  geometry: geometry,
                  activeDayIndex: 0,
                  mapController: controller,
                  onDaySelected: (_) {},
                  maxExtentValue: 260,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> pumpStrip(
  WidgetTester tester,
  TripWithStats stats, {
  int siteCount = 0,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripStatStrip(stats: stats, siteCount: siteCount),
        ),
      ),
    ),
  );
  await tester.pump();
}
```

Update the individual tests:

- `'renders a FlutterMap when geometry has points'`: drop the `stats` argument and the `expect(find.byType(TripStatStrip), findsOneWidget);` line.
- `'draws a route polyline only with 2+ points'`: drop the `stats` argument.
- `'renders fallback (no map) when geometry is empty'`: drop the `stats` argument and the `TripStatStrip` expect.
- `'stat strip shows the dive count'`, `'stat strip shows sites visited when siteCount > 0'`, `'stat strip hides sites visited when siteCount is 0'`: switch from `pumpHeader(tester, geometry, stats, ...)` to `pumpStrip(tester, stats, ...)` (geometry no longer needed).
- `'map markers expose a 48x48 button with a semantics label'`: drop the `stats` argument.
- `shouldRebuild` test: remove `stats` and `siteCount` from the `make(...)` helper and delete the `siteCount` assertion. Add a `minExtent` assertion:

```dart
  test(
    'shouldRebuild is false for equal inputs, true when a field changes',
    () {
      final controller = MapController();
      addTearDown(controller.dispose);
      void onDay(int _) {}
      const geometry = TripStoryMapGeometry(points: []);

      TripStoryMapHeaderDelegate make({int activeDayIndex = 0}) =>
          TripStoryMapHeaderDelegate(
            geometry: geometry,
            activeDayIndex: activeDayIndex,
            mapController: controller,
            onDaySelected: onDay, // same callback identity across instances
            maxExtentValue: 260,
          );

      // Same inputs (including the shared callback) => no rebuild.
      expect(make().shouldRebuild(make()), isFalse);
      // A changed input => rebuild.
      expect(make(activeDayIndex: 1).shouldRebuild(make()), isTrue);
      // The collapsed map keeps a usable height.
      expect(make().minExtent, 180);
    },
  );
```

Add one new pinned-collapse test after the marker test:

```dart
  testWidgets('collapsed header keeps the map 180 tall', (tester) async {
    const geometry = TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.1,
          longitude: -68.2,
          dayIndex: 0,
          label: 'A',
        ),
      ],
    );
    await pumpHeader(tester, geometry);

    // Fully expanded: the map fills the whole 260px header.
    expect(tester.getSize(find.byType(FlutterMap).first).height, 260);

    // Scroll far enough to fully collapse the pinned header.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    expect(tester.getSize(find.byType(FlutterMap).first).height, 180);
  });
```

- [ ] **Step 2: Run the map header tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart -r compact`
Expected: FAIL — compile errors (`stats`/`siteCount` are still required parameters on the delegate).

- [ ] **Step 3: Make the delegate map-only**

In `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart`, replace the `TripStoryMapHeaderDelegate` class (fields, constructor, extents, `shouldRebuild`, `build`) with:

```dart
/// Pinned header hosting the story map.
class TripStoryMapHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TripStoryMapGeometry geometry;
  final int activeDayIndex;
  final MapController mapController;
  final ValueChanged<int> onDaySelected;
  final double maxExtentValue;
  final double minExtentValue;

  const TripStoryMapHeaderDelegate({
    required this.geometry,
    required this.activeDayIndex,
    required this.mapController,
    required this.onDaySelected,
    required this.maxExtentValue,
    this.minExtentValue = 180,
  });

  @override
  double get maxExtent => maxExtentValue;

  @override
  double get minExtent => minExtentValue;

  @override
  bool shouldRebuild(TripStoryMapHeaderDelegate oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.activeDayIndex != activeDayIndex ||
      oldDelegate.mapController != mapController ||
      oldDelegate.onDaySelected != onDaySelected ||
      oldDelegate.maxExtentValue != maxExtentValue ||
      oldDelegate.minExtentValue != minExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      child: geometry.hasPoints
          ? _StoryMap(
              geometry: geometry,
              activeDayIndex: activeDayIndex,
              mapController: mapController,
              onDaySelected: onDaySelected,
            )
          : const _MapFallback(),
    );
  }
}
```

Leave `TripStatStrip`, `_StoryMap`, `_MapFallback`, and `MapCameraAnimator` in the file unchanged. Remove the `TripWithStats` doc reference in the header comment if any, but keep the `trip.dart` import — `TripStatStrip` still uses `TripWithStats`.

- [ ] **Step 4: Relocate the stat strip in the view**

In `lib/features/trips/presentation/widgets/story/trip_story_view.dart`:

(a) `_mapHeaderDelegate()` loses the stats arguments:

```dart
  TripStoryMapHeaderDelegate _mapHeaderDelegate() {
    return TripStoryMapHeaderDelegate(
      geometry: widget.story.mapGeometry,
      activeDayIndex: _activeDayIndex,
      mapController: _mapController,
      onDaySelected: _onPinSelected,
      maxExtentValue: _mapHeaderMaxExtent,
    );
  }
```

(b) In the narrow branch of `build`, insert the strip as the first content sliver:

```dart
          return NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _mapHeaderDelegate(),
                ),
                SliverToBoxAdapter(
                  child: TripStatStrip(
                    stats: widget.stats,
                    siteCount: _siteCount,
                  ),
                ),
                ..._contentSlivers(),
              ],
            ),
          );
```

(c) In the wide branch, keep the strip fixed under the side-panel map:

```dart
            SizedBox(
              width: 380,
              child: Column(
                children: [
                  Expanded(
                    child: _mapHeaderDelegate().build(context, 0, false),
                  ),
                  TripStatStrip(stats: widget.stats, siteCount: _siteCount),
                ],
              ),
            ),
```

- [ ] **Step 5: Update the view test for the scrolled-away strip**

In `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`:

(a) Rename the first test and keep its assertions (the strip is still on screen at the top in the 2600px-tall harness):

```dart
  testWidgets('past trip renders day chapters, hero, and stat strip', (
```

(b) Add a new test after the wide-layout test:

```dart
  testWidgets('stat strip and wide panel placement', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    // Wide layout keeps the strip fixed in the side panel.
    expect(find.byType(TripStatStrip), findsOneWidget);
  });

  testWidgets('stat strip scrolls away in the narrow layout', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++)
          _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    expect(find.byType(TripStatStrip), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();

    // The strip is ordinary scroll content now, not pinned under the map.
    expect(find.byType(TripStatStrip), findsNothing);
  });
```

- [ ] **Step 6: Run both test files**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart -r compact`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): map-only pinned story header with 180px floor"
```

---

### Task 3: `isSurface` getter on TripStoryDay

The "surface day" decision (`!hasContent && kind != future`) currently lives inside `TripStoryDayCard`. Task 5 needs the same decision in `TripStoryView` (surface days get no sticky header), so hoist it onto the entity to avoid divergent copies.

**Files:**
- Modify: `lib/features/trips/domain/entities/trip_story_day.dart`
- Test: `test/features/trips/domain/entities/trip_story_day_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `bool get isSurface` on `TripStoryDay` — true when the day has no dives, media, or itinerary AND is not a future (planned) day. Tasks 4/5 read it.

- [ ] **Step 1: Write the failing test**

Append to the existing group in `test/features/trips/domain/entities/trip_story_day_test.dart`:

```dart
    test('isSurface is true only for contentless non-future days', () {
      TripStoryDay make({
        TripStoryDayKind kind = TripStoryDayKind.past,
        List<Dive> dives = const [],
      }) => TripStoryDay(date: date, dayNumber: 1, kind: kind, dives: dives);

      expect(make().isSurface, isTrue);
      expect(make(kind: TripStoryDayKind.today).isSurface, isTrue);
      // Planned days render a chapter even without content.
      expect(make(kind: TripStoryDayKind.future).isSurface, isFalse);
      expect(
        make(
          dives: [_dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        ).isSurface,
        isFalse,
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart -r compact`
Expected: FAIL — `isSurface` isn't defined.

- [ ] **Step 3: Implement the getter**

In `lib/features/trips/domain/entities/trip_story_day.dart`, directly below `hasContent`:

```dart
  /// A day with nothing to show: no dives, media, or itinerary entry, and not
  /// a planned (future) day. Rendered as a slim row with no sticky header.
  bool get isSurface => !hasContent && kind != TripStoryDayKind.future;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart -r compact`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): add TripStoryDay.isSurface"
```

---

### Task 4: TripStoryDayHeader widget and sliver delegate

New widget file: the sticky per-day header (two compact lines plus the Planned chip for future days) and its fixed-extent `SliverPersistentHeaderDelegate`. Pure presentation, no providers.

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`
- Create: `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`

**Interfaces:**
- Consumes: `TripStoryDay` (incl. `isSurface` from Task 3 — not used here, but the delegate pairs with it in Task 5).
- Produces: `TripStoryDayHeader({required TripStoryDay day})` widget; `TripStoryDayHeaderDelegate({required TripStoryDay day})` with `static const double extent = 52` and `minExtent == maxExtent == extent`. Task 5 mounts it via `SliverPersistentHeader(pinned: true, delegate: TripStoryDayHeaderDelegate(day: day))`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

ItineraryDay _itin({String? port}) => ItineraryDay(
  id: 'itin-1',
  tripId: 'trip-1',
  dayNumber: 2,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  portName: port,
  notes: '',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> pumpHeader(WidgetTester tester, TripStoryDay day) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TripStoryDayHeader(day: day)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the day number and date', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    expect(find.textContaining('Day 2'), findsOneWidget);
    // MMMEd for en locale: "Sun, Mar 8".
    expect(find.textContaining('Mar 8'), findsOneWidget);
  });

  testWidgets('subtitle joins day type, port, and site names', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      itineraryDay: _itin(port: 'Kralendijk'),
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime(2026, 3, 8, 9),
          site: const DiveSite(id: 'site-a', name: 'Blue Corner'),
        ),
      ],
    );
    await pumpHeader(tester, day);

    final subtitle = find.textContaining('Kralendijk');
    expect(subtitle, findsOneWidget);
    expect(find.textContaining('Blue Corner'), findsOneWidget);
  });

  testWidgets('no subtitle line when there is nothing to say', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    // Only the title line renders.
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('future day shows the planned chip', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpHeader(tester, day);

    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('header is exactly the delegate extent tall', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
    );
    await pumpHeader(tester, day);

    expect(
      tester.getSize(find.byType(TripStoryDayHeader)).height,
      TripStoryDayHeaderDelegate.extent,
    );
  });

  test('delegate rebuilds only when the day value changes', () {
    TripStoryDay make({int dayNumber = 2}) => TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: dayNumber,
      kind: TripStoryDayKind.past,
    );

    final delegate = TripStoryDayHeaderDelegate(day: make());
    // TripStoryDay is Equatable: equal values => no rebuild.
    expect(
      delegate.shouldRebuild(TripStoryDayHeaderDelegate(day: make())),
      isFalse,
    );
    expect(
      delegate.shouldRebuild(
        TripStoryDayHeaderDelegate(day: make(dayNumber: 3)),
      ),
      isTrue,
    );
    expect(delegate.minExtent, delegate.maxExtent);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart -r compact`
Expected: FAIL — the widget file does not exist.

- [ ] **Step 3: Create the header widget and delegate**

Create `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fixed-extent sliver delegate for one day's sticky header. Mounted pinned
/// inside a SliverMainAxisGroup, so it stays at the top of its day chapter
/// until the next day's header pushes it out.
class TripStoryDayHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double extent = 52;

  final TripStoryDay day;

  const TripStoryDayHeaderDelegate({required this.day});

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return TripStoryDayHeader(day: day);
  }

  // TripStoryDay is Equatable, so this compares day content, not identity.
  @override
  bool shouldRebuild(TripStoryDayHeaderDelegate oldDelegate) =>
      oldDelegate.day != day;
}

/// Two compact lines - "Day 3 - Wed, Jul 8" plus the day-type/port/sites
/// subtitle - on an opaque surface so day cards scroll underneath cleanly.
class TripStoryDayHeader extends StatelessWidget {
  final TripStoryDay day;

  const TripStoryDayHeader({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itinerary = day.itineraryDay;
    final subtitleParts = <String>[
      if (itinerary != null) itinerary.dayType.localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: TripStoryDayHeaderDelegate.extent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
                      ' - ${DateFormat.MMMEd().format(day.date)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (day.kind == TripStoryDayKind.future)
                Chip(
                  label: Text(context.l10n.trips_story_planned),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart -r compact`
Expected: PASS. If the Planned-chip test overflows the 52px `SizedBox` (RenderFlex overflow exception), wrap the `Chip` in a `FittedBox(fit: BoxFit.scaleDown)` — do not raise the extent.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): sticky day header widget for the trip story"
```

---

### Task 5: Wire sticky day headers into the view; slim the day card

Restructure the story's day list from one `SliverList.builder` into one `SliverMainAxisGroup` per day (pinned header + card body), and remove the now-duplicated header from inside `TripStoryDayCard`.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`

**Interfaces:**
- Consumes: `TripStoryDay.isSurface` (Task 3), `TripStoryDayHeader`/`TripStoryDayHeaderDelegate` (Task 4), collapsed map height 180 (Task 2).
- Produces: `TripStoryDayCard` renders body-only (stats, rhythm, dives, photos, sightings, planned extras); day titles/subtitles/Planned chip live exclusively in the sticky header. Surface days keep the slim row, no header.

- [ ] **Step 1: Update the day card tests (title/chip move out of the card)**

In `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`:

(a) `'past day with dives shows rhythm and dive rows'`: replace

```dart
    expect(find.textContaining('Day 2'), findsOneWidget);
```

with

```dart
    // The day title lives in the sticky header now, not the card.
    expect(find.textContaining('Day 2'), findsNothing);
```

(b) `'future day shows the planned chip'`: the chip moved to the header, and a contentless planned day renders nothing. Replace the whole test with:

```dart
  testWidgets('planned day without content renders no card', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpCard(tester, day);
    // Title and chip live in the sticky header; with no notes, port, dives,
    // media, or sightings there is nothing left for the card to show.
    expect(find.byType(Card), findsNothing);
    expect(find.text('Planned'), findsNothing);
  });
```

(c) `'past day renders photo strip with a more-indicator'`: replace

```dart
    // Itinerary header contributes the port name to the subtitle.
    expect(find.textContaining('Kralendijk'), findsOneWidget);
```

with

```dart
    // The port subtitle moved to the sticky header.
    expect(find.textContaining('Kralendijk'), findsNothing);
```

(d) The surface-day, sightings, and planned-notes tests are unchanged — the slim surface row keeps its inline title, and the planned-notes test day has notes and a port, so its card still renders.

- [ ] **Step 2: Run the card tests to verify the new expectations fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart -r compact`
Expected: FAIL — the card still renders 'Day 2', the planned chip, and 'Kralendijk'.

- [ ] **Step 3: Slim the day card to body-only**

In `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`:

(a) Replace the `build` method of `TripStoryDayCard` with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Built once for the day's dives rather than per row.
    final diveTypeLabelResolver = watchDiveTypeLabelResolver(ref, context.l10n);

    if (day.isSurface) {
      return _SurfaceDayRow(day: day);
    }

    // The day title, subtitle, and Planned chip live in the sticky
    // TripStoryDayHeader above this card; the card is body-only. A planned
    // day whose itinerary has nothing to show would produce an empty card,
    // so skip it entirely.
    final itinerary = day.itineraryDay;
    final hasPlannedExtras =
        _isPlanned &&
        ((itinerary?.notes.isNotEmpty ?? false) || itinerary?.portName != null);
    final hasBody =
        day.dives.isNotEmpty ||
        day.media.isNotEmpty ||
        day.sightings.isNotEmpty ||
        hasPlannedExtras;
    if (!hasBody) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: _isPlanned
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            )
          : null,
      child: Opacity(
        opacity: _isPlanned ? 0.85 : 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.dives.isNotEmpty) ...[
                _DayStatStrip(day: day, units: units),
                const SizedBox(height: 12),
                DayRhythmBar(dives: day.dives),
                const SizedBox(height: 8),
                ...day.dives.mapIndexed(
                  (index, dive) => DiveListItem(
                    summary: DiveSummary.fromDive(dive),
                    diveTypeLabelResolver: diveTypeLabelResolver,
                    // The story already holds the full Dive; pass it so the
                    // configurable card can resolve fields absent from the
                    // summary (tanks, SAC, buddies, weights).
                    fullDive: dive,
                    diveNumber: dive.diveNumber ?? index + 1,
                    onTap: () => context.push('/dives/${dive.id}'),
                  ),
                ),
              ],
              if (day.media.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PhotoStrip(tripId: tripId, media: day.media),
              ],
              if (day.sightings.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SightingChips(day: day),
              ],
              if (_isPlanned) _PlannedExtras(day: day, units: units),
            ],
          ),
        ),
      ),
    );
  }
```

(b) Delete the entire `_buildHeader` method.

(c) Remove now-unused imports if the analyzer flags them (`intl` stays — `_SurfaceDayRow` uses `DateFormat`; `day_type_l10n.dart` becomes unused and must be removed).

- [ ] **Step 4: Run the card tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart -r compact`
Expected: PASS.

- [ ] **Step 5: Add the sticky-header view tests**

In `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`, add the import:

```dart
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
```

and add two tests at the end of `main`:

```dart
  testWidgets('day header sticks below the collapsed map while scrolling', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final labels = ['a', 'b', 'c', 'd', 'e', 'f'];
    final story = buildTripStory(
      trip: trip,
      dives: [
        for (var i = 0; i < labels.length; i++)
          _diveAt(
            labels[i],
            DateTime(2026, 3, 25 + i, 9),
            12.10 + i * 0.002,
            -68.20 + i * 0.002,
          ),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    // Scroll deep into the story so the map is fully collapsed and a later
    // day's chapter is under the headers.
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }

    // Exactly one day header is pinned directly below the 180px map header;
    // the first day's header has been pushed out by a later one.
    final pinnedTops = [
      for (final element in find.byType(TripStoryDayHeader).evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ];
    expect(pinnedTops, anyElement(closeTo(180.0, 1.0)));
    expect(find.textContaining('Day 1 -'), findsNothing);
  });

  testWidgets('surface days get no sticky header', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 27),
    );
    // Dives on days 1 and 3; day 2 is a surface day.
    final story = _story(
      trip,
      dives: [
        _dive('d1', DateTime(2026, 3, 25, 9)),
        _dive('d3', DateTime(2026, 3, 27, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);

    // Tall harness viewport: all three days are mounted, but only the two
    // dive days contribute sticky headers.
    expect(find.byType(TripStoryDayHeader), findsNWidgets(2));
    expect(find.textContaining('Surface day'), findsOneWidget);
  });
```

- [ ] **Step 6: Run the view tests to verify the new ones fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart -r compact`
Expected: the two new tests FAIL (no `TripStoryDayHeader` in the tree yet); pre-existing tests still pass.

- [ ] **Step 7: Restructure the view's day slivers**

In `lib/features/trips/presentation/widgets/story/trip_story_view.dart`:

(a) Add the import:

```dart
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
```

(b) In `_contentSlivers()`, replace the day-list sliver (the `SliverPadding` wrapping `SliverList.builder`, currently lines 237-257) with:

```dart
      for (var index = 0; index < story.days.length; index++)
        _daySliver(story, index, todayIndex),
```

(c) Add the builder method to `_TripStoryViewState`:

```dart
  /// One day chapter: a SliverMainAxisGroup whose pinned header sticks below
  /// the map until the next day's group pushes it out. Surface days render
  /// their slim row with no header.
  Widget _daySliver(TripStory story, int index, int? todayIndex) {
    final day = story.days[index];
    final showTodayDivider = todayIndex != null && index == todayIndex;
    const divider = SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(child: _TodayDivider()),
    );
    final body = SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          key: _dayKeys[index],
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [TripStoryDayCard(day: day, tripId: story.trip.id)],
        ),
      ),
    );

    if (day.isSurface) {
      return SliverMainAxisGroup(
        slivers: [if (showTodayDivider) divider, body],
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (showTodayDivider) divider,
        SliverPersistentHeader(
          pinned: true,
          delegate: TripStoryDayHeaderDelegate(day: day),
        ),
        body,
      ],
    );
  }
```

Note the `GlobalKey` stays on the card-body `Column` (a box widget), exactly as before — `Scrollable.ensureVisible` and the `_onScroll` active-day resolution both need a box render object, and keying the pinned header instead would break position math while it is stuck.

(d) The unused local in `_contentSlivers` cleanup: `todayIndex` is now passed to `_daySliver`; delete the `showTodayDivider` logic from the old builder if any remnant remains.

- [ ] **Step 8: Run the full story test directory**

Run: `flutter test test/features/trips/presentation/widgets/story/ -r compact`
Expected: PASS — including the pre-existing `'scrolling resolves the active day and animates the map'` (key-based tracking unchanged) and `'in-progress trip shows a Today divider'` (divider now inside the day's group).

- [ ] **Step 9: Run the neighboring consumers of the story view**

Run: `flutter test test/features/trips/presentation/widgets/trip_overview_tab_test.dart test/features/trips/presentation/pages/trip_detail_page_test.dart -r compact`
Expected: PASS (`TripStoryDayCard` is still mounted for content days).

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): sticky per-day headers in the trip story"
```

---

### Task 6: Full verification

**Files:** none new — verification only.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: a branch ready for review/PR.

- [ ] **Step 1: Format check**

Run: `dart format .`
Expected: "0 changed" (formatted files count unchanged). If anything changed, commit it as `style: format`.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!" — info-level lints are CI-fatal; fix any before proceeding. Do not pipe through `tail`.

- [ ] **Step 3: Run the full trips test suite**

Run: `flutter test test/features/trips/ -r compact`
Expected: all tests pass.

- [ ] **Step 4: Commit any stragglers and stop**

```bash
git status
```

Expected: clean tree. Do not push or open a PR — report completion and wait for direction (per repo convention, pushes go to `origin` = submersion-app/submersion with `env -u GITHUB_TOKEN` if the keyring token is needed).
