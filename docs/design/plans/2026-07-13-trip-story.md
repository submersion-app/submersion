# Trip Story Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the trip detail Overview tab as a scroll-driven day-by-day "trip story" with a pinned map that follows the reader, working for past, planned, and in-progress trips (closes #166).

**Architecture:** A pure domain function `buildTripStory` composes dives, itinerary days, media, sightings, and checklist items into a `TripStory` (list of `TripStoryDay`). A thin `tripStoryProvider` feeds a `CustomScrollView` whose pinned `SliverPersistentHeader` hosts a flutter_map that animates to the day under the scroll position.

**Tech Stack:** Flutter 3 / Material 3, Riverpod (manual providers, no codegen for these files), flutter_map + latlong2, Drift (raw SQL via customSelect for aggregates), go_router.

**Spec:** `docs/superpowers/specs/2026-07-13-trip-story-design.md`

## Deviations from spec (agreed rationale, discovered during planning)

1. `divesForTripProvider` already hydrates `dive.profile` (see `_mapRowToDive`), so there is NO `diveProfileSparklineProvider`; sparklines downsample `dive.profile` directly via a pure function.
2. The sighting entity used is marine_life's `Sighting` (`lib/features/marine_life/domain/entities/species.dart:129`, has `diveId` + `speciesCategory`), not `MarineSighting` (which lives on `Dive` but is never hydrated by list queries).
3. `DiveListItem` is NOT modified; the sparkline renders beside it (`Row[Expanded(DiveListItem), sparkline]`) to avoid touching the shared widget.
4. "Dashed" planned-day styling is implemented as outlined + dimmed cards ("Planned" chip); Flutter has no native dashed border and a custom dash painter is YAGNI.
5. Site-history context pills resolve the site by exact case-insensitive name match against `itineraryDay.portName` (itinerary days have no site FK; coordinate-radius matching is out of scope).

## Global Constraints

- Working directory: worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/trip-story`, branch `feature/trip-story`. Never touch the main checkout.
- All displayed units via `UnitFormatter` (`lib/core/utils/unit_formatter.dart`): `formatDepth(double?)`, `formatTemperature(double?)`.
- Every new user-facing string goes in `lib/l10n/arb/app_en.arb` AND all 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n` (Task 7 adds them all up front).
- No emojis in code, comments, or docs. `dart format .` (whole project) before every commit. `flutter analyze` must stay clean (whole project, never pipe through tail/head).
- Run tests per-file (`flutter test <file>`), never the whole suite (it times out).
- Commit after each task with the message given in the task. Do not add Co-Authored-By lines.
- Test helpers that already exist: `test/helpers/mock_providers.dart` provides `getBaseOverrides()` (async) and `createTestDiveWithBottomTime(...)`. Widget tests wrap in `ProviderScope(overrides: [...].cast(), child: MaterialApp(...))` with `AppLocalizations.localizationsDelegates` / `supportedLocales` (see `test/features/trips/presentation/widgets/trip_overview_tab_test.dart` for the exact pattern).
- Date-only arithmetic uses `DateTime(y, m, d + i)` calendar math (DST-safe), same as `ItineraryDay.generateForTrip`.

---

### Task 1: Trip story domain entities

**Files:**
- Create: `lib/features/trips/domain/entities/trip_story_day.dart`
- Create: `lib/features/trips/domain/entities/trip_story.dart`
- Test: `test/features/trips/domain/entities/trip_story_day_test.dart`

**Interfaces:**
- Consumes: `Dive`, `DiveProfilePoint` (`lib/features/dive_log/domain/entities/dive.dart`), `ItineraryDay`, `MediaItem` (`lib/features/media/domain/entities/media_item.dart`), `Sighting` (`lib/features/marine_life/domain/entities/species.dart`), `TripChecklistItem` (`lib/features/checklists/domain/entities/trip_checklist_item.dart`), `Trip`.
- Produces (used by Tasks 2, 5, 8-12):
  - `enum TripStoryDayKind { past, today, future }`
  - `class TripStoryDay { DateTime date; int dayNumber; ItineraryDay? itineraryDay; List<Dive> dives; List<MediaItem> media; List<Sighting> sightings; TripStoryDayKind kind; }` with getters `diveCount`, `totalBottomTime` (Duration), `maxDepth` (double?), `siteNames` (List<String>, unique, dive order), `hasContent` (bool)
  - `class TripStoryMapPoint { double latitude; double longitude; int dayIndex; String? siteId; String label; }`
  - `class TripStoryMapGeometry { List<TripStoryMapPoint> points; bool hasPoints; List<TripStoryMapPoint> pointsForDay(int dayIndex); }`
  - `class TripStoryChecklistSummary { int done; int total; List<TripChecklistItem> nextDue; bool isEmpty; }`
  - `class TripStory { Trip trip; List<TripStoryDay> days; TripStoryChecklistSummary checklist; TripStoryMapGeometry mapGeometry; int? todayIndex; bool isEmpty; }`

- [ ] **Step 1: Write the failing test**

`test/features/trips/domain/entities/trip_story_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

Dive _dive({
  required String id,
  required DateTime dateTime,
  Duration? bottomTime,
  double? maxDepth,
  DiveSite? site,
}) {
  return Dive(
    id: id,
    dateTime: dateTime,
    bottomTime: bottomTime,
    maxDepth: maxDepth,
    site: site,
  );
}

void main() {
  final date = DateTime(2026, 3, 8);
  final siteA = DiveSite(id: 'site-a', name: 'Blue Corner');
  final siteB = DiveSite(id: 'site-b', name: 'Jetty');

  group('TripStoryDay derived getters', () {
    test('aggregates dive count, bottom time, and max depth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 8, 9),
            bottomTime: const Duration(minutes: 47),
            maxDepth: 28,
            site: siteA,
          ),
          _dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 8, 11),
            bottomTime: const Duration(minutes: 51),
            maxDepth: 24,
            site: siteA,
          ),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 19), site: siteB),
        ],
      );

      expect(day.diveCount, 3);
      expect(day.totalBottomTime, const Duration(minutes: 98));
      expect(day.maxDepth, 28);
      expect(day.siteNames, ['Blue Corner', 'Jetty']);
      expect(day.hasContent, isTrue);
    });

    test('empty day has no content and null maxDepth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 3,
        kind: TripStoryDayKind.future,
      );
      expect(day.diveCount, 0);
      expect(day.totalBottomTime, Duration.zero);
      expect(day.maxDepth, isNull);
      expect(day.siteNames, isEmpty);
      expect(day.hasContent, isFalse);
    });
  });

  group('TripStoryMapGeometry', () {
    test('pointsForDay filters by dayIndex', () {
      const geometry = TripStoryMapGeometry(
        points: [
          TripStoryMapPoint(
            latitude: 1,
            longitude: 2,
            dayIndex: 0,
            label: 'A',
          ),
          TripStoryMapPoint(
            latitude: 3,
            longitude: 4,
            dayIndex: 1,
            label: 'B',
          ),
        ],
      );
      expect(geometry.hasPoints, isTrue);
      expect(geometry.pointsForDay(1).single.label, 'B');
      expect(geometry.pointsForDay(9), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart`
Expected: FAIL (compile error, `trip_story_day.dart` does not exist).

- [ ] **Step 3: Write the entities**

`lib/features/trips/domain/entities/trip_story_day.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

/// Temporal position of a story day relative to "today" (date-only).
enum TripStoryDayKind { past, today, future }

/// One calendar day of a trip story: real dives when they exist, itinerary
/// metadata when it exists, or neither (a surface day).
class TripStoryDay extends Equatable {
  final DateTime date;
  final int dayNumber;
  final ItineraryDay? itineraryDay;
  final List<Dive> dives;
  final List<MediaItem> media;
  final List<Sighting> sightings;
  final TripStoryDayKind kind;

  const TripStoryDay({
    required this.date,
    required this.dayNumber,
    required this.kind,
    this.itineraryDay,
    this.dives = const [],
    this.media = const [],
    this.sightings = const [],
  });

  int get diveCount => dives.length;

  Duration get totalBottomTime => dives.fold(
    Duration.zero,
    (sum, dive) => sum + (dive.bottomTime ?? Duration.zero),
  );

  double? get maxDepth {
    double? max;
    for (final dive in dives) {
      final depth = dive.maxDepth;
      if (depth != null && (max == null || depth > max)) max = depth;
    }
    return max;
  }

  /// Unique site names in dive order.
  List<String> get siteNames {
    final seen = <String>{};
    final names = <String>[];
    for (final dive in dives) {
      final name = dive.site?.name;
      if (name != null && seen.add(name)) names.add(name);
    }
    return names;
  }

  bool get hasContent =>
      dives.isNotEmpty || media.isNotEmpty || itineraryDay != null;

  @override
  List<Object?> get props => [
    date,
    dayNumber,
    itineraryDay,
    dives,
    media,
    sightings,
    kind,
  ];
}

/// A mappable point contributed by a story day (dive site or itinerary port).
class TripStoryMapPoint extends Equatable {
  final double latitude;
  final double longitude;
  final int dayIndex;
  final String? siteId;
  final String label;

  const TripStoryMapPoint({
    required this.latitude,
    required this.longitude,
    required this.dayIndex,
    required this.label,
    this.siteId,
  });

  @override
  List<Object?> get props => [latitude, longitude, dayIndex, siteId, label];
}

/// Precomputed map geometry for the whole story, in day order. The point
/// sequence doubles as the route polyline.
class TripStoryMapGeometry extends Equatable {
  final List<TripStoryMapPoint> points;

  const TripStoryMapGeometry({required this.points});

  bool get hasPoints => points.isNotEmpty;

  List<TripStoryMapPoint> pointsForDay(int dayIndex) =>
      points.where((p) => p.dayIndex == dayIndex).toList();

  @override
  List<Object?> get props => [points];
}
```

`lib/features/trips/domain/entities/trip_story.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Done/total checklist progress plus the next few due items.
class TripStoryChecklistSummary extends Equatable {
  final int done;
  final int total;
  final List<TripChecklistItem> nextDue;

  const TripStoryChecklistSummary({
    required this.done,
    required this.total,
    this.nextDue = const [],
  });

  bool get isEmpty => total == 0;

  @override
  List<Object?> get props => [done, total, nextDue];
}

/// The complete composed story for one trip.
class TripStory extends Equatable {
  final Trip trip;
  final List<TripStoryDay> days;
  final TripStoryChecklistSummary checklist;
  final TripStoryMapGeometry mapGeometry;

  const TripStory({
    required this.trip,
    required this.days,
    required this.checklist,
    required this.mapGeometry,
  });

  /// Index of the day whose kind is [TripStoryDayKind.today], if any.
  int? get todayIndex {
    final index = days.indexWhere((d) => d.kind == TripStoryDayKind.today);
    return index == -1 ? null : index;
  }

  /// True when there is nothing to tell: no dives and no itinerary anywhere.
  bool get isEmpty => days.every(
    (d) => d.dives.isEmpty && d.itineraryDay == null,
  );

  @override
  List<Object?> get props => [trip, days, checklist, mapGeometry];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/trip_story_day_test.dart`
Expected: PASS (all tests green). If `Dive`/`DiveSite` constructors reject the minimal arguments used in the test helper, check their required params in `lib/features/dive_log/domain/entities/dive.dart` and `lib/features/dive_sites/domain/entities/dive_site.dart` and add only what is required (e.g. `createdAt`/`updatedAt`), keeping test intent unchanged.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/domain/entities/trip_story_day.dart lib/features/trips/domain/entities/trip_story.dart test/features/trips/domain/entities/trip_story_day_test.dart
git commit -m "feat(trips): add trip story domain entities"
```

---

### Task 2: buildTripStory pure function

**Files:**
- Create: `lib/features/trips/domain/services/trip_story_builder.dart`
- Test: `test/features/trips/domain/services/trip_story_builder_test.dart`

**Interfaces:**
- Consumes: everything from Task 1; `ItineraryDay`, `Trip`, `Dive`, `MediaItem`, `Sighting`, `TripChecklistItem`.
- Produces (used by Task 5):

```dart
TripStory buildTripStory({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
  required Map<String, List<MediaItem>> mediaByDiveId,
  required Map<String, List<Sighting>> sightingsByDiveId,
  required List<TripChecklistItem> checklistItems,
  required DateTime today,
})
```

- [ ] **Step 1: Write the failing tests**

`test/features/trips/domain/services/trip_story_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';

Trip _trip({DateTime? start, DateTime? end}) {
  return Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: start ?? DateTime(2026, 3, 7),
    endDate: end ?? DateTime(2026, 3, 10),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Dive _dive(String id, DateTime dateTime, {DiveSite? site}) {
  return Dive(id: id, dateTime: dateTime, site: site);
}

ItineraryDay _itin(int dayNumber, DateTime date, {String? port}) {
  return ItineraryDay(
    id: 'itin-$dayNumber',
    tripId: 'trip-1',
    dayNumber: dayNumber,
    date: date,
    dayType: DayType.diveDay,
    portName: port,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripChecklistItem _check(String id, {bool done = false, DateTime? due}) {
  return TripChecklistItem(
    id: id,
    tripId: 'trip-1',
    title: id,
    isDone: done,
    dueDate: due,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('buildTripStory day span', () {
    test('emits one day per calendar day of the trip range', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days.length, 4); // Mar 7,8,9,10
      expect(story.days.first.dayNumber, 1);
      expect(story.days.last.date, DateTime(2026, 3, 10));
    });

    test('extends span to cover dives outside nominal trip dates', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [_dive('d1', DateTime(2026, 3, 12, 10))],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days.length, 6); // Mar 7..12
      expect(story.days.last.dives, hasLength(1));
    });
  });

  group('buildTripStory grouping', () {
    test('groups dives by calendar day, time-sorted within a day', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive('late', DateTime(2026, 3, 8, 19)),
          _dive('early', DateTime(2026, 3, 8, 9)),
          _dive('other-day', DateTime(2026, 3, 9, 9)),
        ],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      final day2 = story.days[1]; // Mar 8
      expect(day2.dives.map((d) => d.id), ['early', 'late']);
      expect(story.days[2].dives.map((d) => d.id), ['other-day']);
    });

    test('attaches itinerary metadata, media, and sightings to the day', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [_dive('d1', DateTime(2026, 3, 8, 9))],
        itineraryDays: [_itin(2, DateTime(2026, 3, 8), port: 'Kralendijk')],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days[1].itineraryDay?.portName, 'Kralendijk');
    });
  });

  group('buildTripStory kind derivation', () {
    test('past, today, and future kinds split on the injected today', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 3, 8, 15, 30), // mid-trip, time ignored
      );
      expect(story.days[0].kind, TripStoryDayKind.past);
      expect(story.days[1].kind, TripStoryDayKind.today);
      expect(story.days[2].kind, TripStoryDayKind.future);
      expect(story.todayIndex, 1);
    });

    test('fully future trip has null todayIndex and isEmpty when bare', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 1, 1),
      );
      expect(story.todayIndex, isNull);
      expect(story.isEmpty, isTrue);
      expect(story.days.every((d) => d.kind == TripStoryDayKind.future), true);
    });
  });

  group('buildTripStory checklist summary', () {
    test('computes done/total and next due (undone, dated, soonest first)', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [
          _check('a', done: true),
          _check('b', due: DateTime(2026, 3, 1)),
          _check('c', due: DateTime(2026, 2, 1)),
          _check('d'),
        ],
        today: DateTime(2026, 1, 1),
      );
      expect(story.checklist.done, 1);
      expect(story.checklist.total, 4);
      expect(story.checklist.nextDue.map((i) => i.id), ['c', 'b']);
    });
  });

  group('buildTripStory map geometry', () {
    test('collects unique day site points and itinerary ports in order', () {
      final site = DiveSite(
        id: 'site-a',
        name: 'Blue Corner',
        location: const GeoPoint(latitude: 12.1, longitude: -68.2),
      );
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive('d1', DateTime(2026, 3, 8, 9), site: site),
          _dive('d2', DateTime(2026, 3, 8, 11), site: site), // same site
        ],
        itineraryDays: [
          ItineraryDay(
            id: 'itin-1',
            tripId: 'trip-1',
            dayNumber: 1,
            date: DateTime(2026, 3, 7),
            dayType: DayType.embark,
            portName: 'Kralendijk',
            latitude: 12.15,
            longitude: -68.27,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.mapGeometry.points, hasLength(2));
      expect(story.mapGeometry.points[0].label, 'Kralendijk');
      expect(story.mapGeometry.points[0].dayIndex, 0);
      expect(story.mapGeometry.points[1].siteId, 'site-a');
      expect(story.mapGeometry.points[1].dayIndex, 1);
    });
  });
}
```

Note: `GeoPoint` lives in the dive_sites/dive entities; check its import
(`grep -rn "class GeoPoint" lib/ --include="*.dart" | grep -v .g.dart`) and
its constructor (positional vs named) before running, and adjust the single
construction site in the test to match.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/domain/services/trip_story_builder_test.dart`
Expected: FAIL (compile error, `trip_story_builder.dart` does not exist).

- [ ] **Step 3: Implement buildTripStory**

`lib/features/trips/domain/services/trip_story_builder.dart`:

```dart
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Number of upcoming checklist items surfaced in the story hero.
const int _nextDueCount = 3;

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Compose the full trip story from already-loaded sources. Pure: no I/O,
/// no clock access ([today] is injected).
TripStory buildTripStory({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
  required Map<String, List<MediaItem>> mediaByDiveId,
  required Map<String, List<Sighting>> sightingsByDiveId,
  required List<TripChecklistItem> checklistItems,
  required DateTime today,
}) {
  final sortedDives = List<Dive>.of(dives)
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  // Day span: trip range, extended to cover any dive outside it.
  var start = _dateOnly(trip.startDate);
  var end = _dateOnly(trip.endDate);
  if (sortedDives.isNotEmpty) {
    final firstDive = _dateOnly(sortedDives.first.dateTime);
    final lastDive = _dateOnly(sortedDives.last.dateTime);
    if (firstDive.isBefore(start)) start = firstDive;
    if (lastDive.isAfter(end)) end = lastDive;
  }
  final totalDays = end.difference(start).inHours ~/ 24 + 1;

  final divesByDate = <DateTime, List<Dive>>{};
  for (final dive in sortedDives) {
    divesByDate.putIfAbsent(_dateOnly(dive.dateTime), () => []).add(dive);
  }
  final itineraryByDate = <DateTime, ItineraryDay>{
    for (final day in itineraryDays) _dateOnly(day.date): day,
  };

  final todayDate = _dateOnly(today);
  final days = <TripStoryDay>[];
  final mapPoints = <TripStoryMapPoint>[];

  for (var i = 0; i < totalDays; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    final dayDives = divesByDate[date] ?? const <Dive>[];
    final itineraryDay = itineraryByDate[date];

    final media = <MediaItem>[];
    final sightings = <Sighting>[];
    for (final dive in dayDives) {
      media.addAll(mediaByDiveId[dive.id] ?? const []);
      sightings.addAll(sightingsByDiveId[dive.id] ?? const []);
    }
    media.sort((a, b) => a.takenAt.compareTo(b.takenAt));

    final TripStoryDayKind kind;
    if (date.isBefore(todayDate)) {
      kind = TripStoryDayKind.past;
    } else if (date.isAfter(todayDate)) {
      kind = TripStoryDayKind.future;
    } else {
      kind = TripStoryDayKind.today;
    }

    days.add(
      TripStoryDay(
        date: date,
        dayNumber: i + 1,
        kind: kind,
        itineraryDay: itineraryDay,
        dives: dayDives,
        media: media,
        sightings: sightings,
      ),
    );

    // Map geometry: itinerary port first, then unique dive sites in order.
    if (itineraryDay != null && itineraryDay.hasCoordinates) {
      mapPoints.add(
        TripStoryMapPoint(
          latitude: itineraryDay.latitude!,
          longitude: itineraryDay.longitude!,
          dayIndex: i,
          label: itineraryDay.portName ?? '',
        ),
      );
    }
    final seenSiteIds = <String>{};
    for (final dive in dayDives) {
      final site = dive.site;
      final location = site?.location;
      if (site == null || location == null) continue;
      if (!seenSiteIds.add(site.id)) continue;
      mapPoints.add(
        TripStoryMapPoint(
          latitude: location.latitude,
          longitude: location.longitude,
          dayIndex: i,
          siteId: site.id,
          label: site.name,
        ),
      );
    }
  }

  final done = checklistItems.where((i) => i.isDone).length;
  final nextDue =
      checklistItems.where((i) => !i.isDone && i.dueDate != null).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  return TripStory(
    trip: trip,
    days: days,
    checklist: TripStoryChecklistSummary(
      done: done,
      total: checklistItems.length,
      nextDue: nextDue.take(_nextDueCount).toList(),
    ),
    mapGeometry: TripStoryMapGeometry(points: mapPoints),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/domain/services/trip_story_builder_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/domain/services/trip_story_builder.dart test/features/trips/domain/services/trip_story_builder_test.dart
git commit -m "feat(trips): add buildTripStory composition function"
```

---

### Task 3: Batched sightings query

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (add method after `getSightingsForDive`, around line 200)
- Test: `test/features/marine_life/data/repositories/species_repository_sightings_test.dart`

**Interfaces:**
- Consumes: existing `SpeciesRepository` (`_db` Drift database field), `domain.Sighting`, `SpeciesCategory`.
- Produces (used by Task 5): `Future<Map<String, List<domain.Sighting>>> getSightingsForDives(List<String> diveIds)` — keys are dive ids; dives with no sightings are absent from the map; empty input returns `{}` without querying.

- [ ] **Step 1: Study the existing per-dive query**

Read `getSightingsForDive` in `lib/features/marine_life/data/repositories/species_repository.dart` (around line 176). The batch method reuses its SQL and row mapping with an `IN` clause. Also check how existing repository tests construct an in-memory database: look at `test/features/marine_life/` (or, if empty, `grep -rln "AppDatabase(NativeDatabase.memory())\|constructDb\|createTestDatabase" test/ | head -5`) and follow that repo-test pattern exactly, including FK pragma setup.

- [ ] **Step 2: Write the failing test**

`test/features/marine_life/data/repositories/species_repository_sightings_test.dart` — follow the discovered repo-test pattern for database setup; the assertions are:

```dart
// Arrange: insert two dives (d1, d2), one species (sp1),
// two sightings on d1 and none on d2.
// (Use the same table companions as the existing repository tests.)

test('getSightingsForDives groups by dive id and skips empty dives', () async {
  final result = await repository.getSightingsForDives(['d1', 'd2']);
  expect(result.keys, ['d1']);
  expect(result['d1'], hasLength(2));
  expect(result['d1']!.first.speciesName, isNotEmpty);
});

test('getSightingsForDives returns empty map for empty input', () async {
  expect(await repository.getSightingsForDives([]), isEmpty);
});
```

Note: the dive rows must satisfy whatever FK/NOT NULL constraints the dives
table enforces in the test harness; copy the minimal dive-insert helper from
an existing repository test rather than writing one from scratch.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/marine_life/data/repositories/species_repository_sightings_test.dart`
Expected: FAIL (method not defined).

- [ ] **Step 4: Implement the batch method**

Add to `SpeciesRepository` directly below `getSightingsForDive`:

```dart
  /// Batched variant of [getSightingsForDive]: one query for many dives.
  /// Returns a map keyed by dive id; dives without sightings are absent.
  Future<Map<String, List<domain.Sighting>>> getSightingsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final placeholders = List.filled(diveIds.length, '?').join(', ');
    final results = await _db
        .customSelect(
          '''
      SELECT s.*, sp.common_name, sp.category
      FROM sightings s
      JOIN species sp ON s.species_id = sp.id
      WHERE s.dive_id IN ($placeholders)
      ORDER BY sp.category ASC, sp.common_name ASC
    ''',
          variables: [for (final id in diveIds) Variable.withString(id)],
        )
        .get();

    final byDive = <String, List<domain.Sighting>>{};
    for (final row in results) {
      final sighting = domain.Sighting(
        id: row.data['id'] as String,
        diveId: row.data['dive_id'] as String,
        speciesId: row.data['species_id'] as String,
        speciesName: row.data['common_name'] as String,
        speciesCategory: SpeciesCategory.values.firstWhere(
          (c) => c.name == row.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        count: (row.data['count'] as int?) ?? 1,
        notes: (row.data['notes'] as String?) ?? '',
      );
      byDive.putIfAbsent(sighting.diveId, () => []).add(sighting);
    }
    return byDive;
  }
```

Check the exact field mapping (`count`, `notes` column names and the
remaining constructor args) against the body of `getSightingsForDive` and
mirror it exactly — the per-dive method is the source of truth.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/marine_life/data/repositories/species_repository_sightings_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/marine_life/data/repositories/species_repository.dart test/features/marine_life/data/repositories/species_repository_sightings_test.dart
git commit -m "feat(marine-life): add batched getSightingsForDives query"
```

---

### Task 4: Site history aggregates

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (append method at end of class)
- Test: `test/features/statistics/data/repositories/site_history_test.dart`

**Interfaces:**
- Produces (used by Task 5):

```dart
/// Aggregates of the diver's history at one site.
typedef SiteHistory = ({int diveCount, double? avgWaterTemp, double? avgMaxDepth});

Future<SiteHistory> getSiteHistoryByName(
  String siteName, {
  required String diverId,
});
```

Name-based lookup (case-insensitive exact match) because itinerary days
carry `portName`, not a site FK (spec deviation 5).

- [ ] **Step 1: Write the failing test**

`test/features/statistics/data/repositories/site_history_test.dart` — reuse the same in-memory DB setup pattern as existing statistics repository tests (`ls test/features/statistics/data/` and copy the setup of one). Insert one site named `Blue Corner`, two dives at it for diver `diver-1` (waterTemp 26 and 28, maxDepth 20 and 30), one dive at it for `diver-2`. Assert:

```dart
test('aggregates only the requested diver history, case-insensitive', () async {
  final history = await repository.getSiteHistoryByName(
    'blue corner',
    diverId: 'diver-1',
  );
  expect(history.diveCount, 2);
  expect(history.avgWaterTemp, closeTo(27.0, 0.001));
  expect(history.avgMaxDepth, closeTo(25.0, 0.001));
});

test('unknown site returns zero count and null averages', () async {
  final history = await repository.getSiteHistoryByName(
    'Nowhere',
    diverId: 'diver-1',
  );
  expect(history.diveCount, 0);
  expect(history.avgWaterTemp, isNull);
  expect(history.avgMaxDepth, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/statistics/data/repositories/site_history_test.dart`
Expected: FAIL (method not defined).

- [ ] **Step 3: Implement**

Append to `StatisticsRepository` (match the class's existing `_db`/customSelect idioms; verify the dives column names against another query in this file — they are snake_case, e.g. `water_temp`, `max_depth`, `site_id`, `diver_id`):

```dart
  /// Aggregates of one diver's history at a site, matched by exact
  /// case-insensitive name (itinerary days have no site FK).
  Future<({int diveCount, double? avgWaterTemp, double? avgMaxDepth})>
  getSiteHistoryByName(String siteName, {required String diverId}) async {
    final row = await _db
        .customSelect(
          '''
      SELECT COUNT(d.id) AS dive_count,
             AVG(d.water_temp) AS avg_water_temp,
             AVG(d.max_depth) AS avg_max_depth
      FROM dives d
      JOIN dive_sites ds ON d.site_id = ds.id
      WHERE LOWER(ds.name) = LOWER(?) AND d.diver_id = ?
    ''',
          variables: [
            Variable.withString(siteName),
            Variable.withString(diverId),
          ],
        )
        .getSingle();

    return (
      diveCount: row.read<int>('dive_count'),
      avgWaterTemp: row.read<double?>('avg_water_temp'),
      avgMaxDepth: row.read<double?>('avg_max_depth'),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/statistics/data/repositories/site_history_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/data/repositories/statistics_repository.dart test/features/statistics/data/repositories/site_history_test.dart
git commit -m "feat(statistics): add per-site diver history aggregates"
```

---

### Task 5: Story providers

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_story_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_story_providers_test.dart`

**Interfaces:**
- Consumes: `tripWithStatsProvider`, `divesForTripProvider` (`trip_providers.dart`), `itineraryDaysProvider` (`liveaboard_providers.dart`), `mediaForTripProvider` (`trip_media_providers.dart`, returns `Map<Dive, List<MediaItem>>`), `tripChecklistProvider` (`checklist_providers.dart`), `SpeciesRepository.getSightingsForDives` (Task 3), `StatisticsRepository.getSiteHistoryByName` (Task 4), `buildTripStory` (Task 2), `validatedCurrentDiverIdProvider`.
- Produces (used by Tasks 9-13):
  - `final tripStoryProvider = FutureProvider.family<TripStory, String>(...)`
  - `final siteHistoryByNameProvider = FutureProvider.family<SiteHistory, String>(...)` (autoDispose; returns the Task 4 record type)

- [ ] **Step 1: Write the failing test**

`test/features/trips/presentation/providers/trip_story_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('tripStoryProvider composes sources into a TripStory', () async {
    final trip = Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 7),
      endDate: DateTime(2026, 3, 10),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 1,
      bottomTime: const Duration(minutes: 45),
      maxDepth: 25.0,
    );

    final container = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        tripByIdProvider('trip-1').overrideWith((ref) async => trip),
        divesForTripProvider('trip-1').overrideWith((ref) async => [dive]),
        itineraryDaysProvider('trip-1').overrideWith((ref) async => []),
        mediaForTripProvider('trip-1').overrideWith((ref) async => {}),
        tripChecklistProvider('trip-1').overrideWith((ref) async => []),
        tripSightingsByDiveProvider('trip-1').overrideWith((ref) async => {}),
      ].cast(),
    );
    addTearDown(container.dispose);

    final story = await container.read(tripStoryProvider('trip-1').future);
    expect(story.trip.id, 'trip-1');
    expect(story.days, isNotEmpty);
    expect(story.days.expand((d) => d.dives).single.id, 'd1');
  });
}
```

Adjust the `createTestDiveWithBottomTime` dive so its `dateTime` falls inside
the trip range if the helper defaults elsewhere (check the helper in
`test/helpers/mock_providers.dart`; if `dateTime` is not settable there,
build the `Dive` directly as in Task 2's test helper).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/providers/trip_story_providers_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the providers**

`lib/features/trips/presentation/providers/trip_story_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Sightings for every dive in a trip, keyed by dive id (batched query).
final tripSightingsByDiveProvider =
    FutureProvider.family<Map<String, List<Sighting>>, String>((
      ref,
      tripId,
    ) async {
      final diveIds = await ref.watch(diveIdsForTripProvider(tripId).future);
      if (diveIds.isEmpty) return {};
      final repository = ref.watch(speciesRepositoryProvider);
      return repository.getSightingsForDives(diveIds);
    });

/// The composed story for a trip. Watches all source providers so sync
/// invalidations cascade.
final tripStoryProvider = FutureProvider.family<TripStory, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripByIdProvider(tripId).future);
  if (trip == null) {
    throw StateError('Trip not found: $tripId');
  }
  final dives = await ref.watch(divesForTripProvider(tripId).future);
  final itineraryDays = await ref.watch(
    itineraryDaysProvider(tripId).future,
  );
  final mediaByDive = await ref.watch(mediaForTripProvider(tripId).future);
  final checklistItems = await ref.watch(tripChecklistProvider(tripId).future);
  final sightingsByDiveId = await ref.watch(
    tripSightingsByDiveProvider(tripId).future,
  );

  final mediaByDiveId = <String, List<MediaItem>>{
    for (final entry in mediaByDive.entries) entry.key.id: entry.value,
  };

  return buildTripStory(
    trip: trip,
    dives: dives,
    itineraryDays: itineraryDays,
    mediaByDiveId: mediaByDiveId,
    sightingsByDiveId: sightingsByDiveId,
    checklistItems: checklistItems,
    today: DateTime.now(),
  );
});

/// Diver history at a site, matched by name (for planned-day context pills).
final siteHistoryByNameProvider = FutureProvider.autoDispose
    .family<({int diveCount, double? avgWaterTemp, double? avgMaxDepth}),
        String>((ref, siteName) async {
      final diverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      final repository = ref.watch(statisticsRepositoryProvider);
      return repository.getSiteHistoryByName(siteName, diverId: diverId);
    });
```

Verify the exact names of `speciesRepositoryProvider`,
`statisticsRepositoryProvider`, and `validatedCurrentDiverIdProvider`
(`grep -n "RepositoryProvider = Provider" lib/features/marine_life/presentation/providers/species_providers.dart lib/features/statistics/presentation/providers/statistics_providers.dart`
and `grep -rn "validatedCurrentDiverIdProvider =" lib/`) and fix imports if
they live elsewhere. If `divesForTripProvider`'s import of
`dive_providers.dart` is unused, drop it.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/providers/trip_story_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/providers/trip_story_providers.dart test/features/trips/presentation/providers/trip_story_providers_test.dart
git commit -m "feat(trips): add tripStoryProvider composing story sources"
```

---

### Task 6: Pure visualization math (sparkline + rhythm)

**Files:**
- Create: `lib/features/dive_log/domain/services/profile_sparkline.dart`
- Create: `lib/features/trips/domain/services/day_rhythm_layout.dart`
- Test: `test/features/dive_log/domain/services/profile_sparkline_test.dart`
- Test: `test/features/trips/domain/services/day_rhythm_layout_test.dart`

**Interfaces:**
- Produces (used by Task 8):
  - `List<({double t, double depth})> sparklinePoints(List<DiveProfilePoint> profile, {int targetCount = 40})` — normalized: `t` in [0,1] by timestamp, `depth` in [0,1] where 1 = deepest. Empty/single-point profiles return `[]`.
  - `class RhythmBlock { final double startFraction; final double widthFraction; final bool isNight; }`
  - `List<RhythmBlock> computeRhythmBlocks(List<Dive> dives, DateTime dayDate)` — fractions of a 24h day, clamped to [0,1]; duration = `runtime ?? bottomTime ?? 45min`; minimum width 0.02; `isNight` when entry hour >= 18 or < 6.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_log/domain/services/profile_sparkline_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sparkline.dart';

void main() {
  test('downsamples to at most targetCount, keeping bucket max depth', () {
    final profile = List.generate(
      400,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: i == 200 ? 30.0 : 10.0),
    );
    final points = sparklinePoints(profile, targetCount: 40);
    expect(points.length, lessThanOrEqualTo(40));
    // The 30m spike must survive downsampling (bucket max).
    expect(points.map((p) => p.depth).reduce((a, b) => a > b ? a : b), 1.0);
    expect(points.first.t, 0.0);
    expect(points.last.t, 1.0);
  });

  test('short profiles pass through unchanged in count', () {
    final profile = [
      const DiveProfilePoint(timestamp: 0, depth: 0),
      const DiveProfilePoint(timestamp: 60, depth: 18),
      const DiveProfilePoint(timestamp: 120, depth: 0),
    ];
    expect(sparklinePoints(profile).length, 3);
  });

  test('empty and single-point profiles return empty', () {
    expect(sparklinePoints(const []), isEmpty);
    expect(
      sparklinePoints(const [DiveProfilePoint(timestamp: 0, depth: 5)]),
      isEmpty,
    );
  });
}
```

`test/features/trips/domain/services/day_rhythm_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';

void main() {
  final day = DateTime(2026, 3, 8);

  Dive dive(DateTime dt, {Duration? bottomTime}) =>
      Dive(id: dt.toIso8601String(), dateTime: dt, bottomTime: bottomTime);

  test('positions a morning dive at its fraction of the day', () {
    final blocks = computeRhythmBlocks(
      [dive(DateTime(2026, 3, 8, 6), bottomTime: const Duration(hours: 2, minutes: 24))],
      day,
    );
    expect(blocks.single.startFraction, closeTo(0.25, 0.001)); // 06:00
    expect(blocks.single.widthFraction, closeTo(0.1, 0.001)); // 2.4h/24h
    expect(blocks.single.isNight, isFalse);
  });

  test('marks night dives and enforces minimum width', () {
    final blocks = computeRhythmBlocks(
      [dive(DateTime(2026, 3, 8, 19, 30), bottomTime: const Duration(minutes: 5))],
      day,
    );
    expect(blocks.single.isNight, isTrue);
    expect(blocks.single.widthFraction, 0.02); // clamped up
  });

  test('clamps blocks that run past midnight', () {
    final blocks = computeRhythmBlocks(
      [dive(DateTime(2026, 3, 8, 23, 30))], // default 45min crosses midnight
      day,
    );
    expect(
      blocks.single.startFraction + blocks.single.widthFraction,
      lessThanOrEqualTo(1.0),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/profile_sparkline_test.dart test/features/trips/domain/services/day_rhythm_layout_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement both functions**

`lib/features/dive_log/domain/services/profile_sparkline.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Downsample a dive profile to a normalized polyline for tiny sparklines.
///
/// Buckets by time and keeps each bucket's maximum depth so short deep
/// excursions stay visible. Returns points with `t` in [0,1] (time) and
/// `depth` in [0,1] (1 = deepest sample). Profiles with fewer than two
/// samples return an empty list.
List<({double t, double depth})> sparklinePoints(
  List<DiveProfilePoint> profile, {
  int targetCount = 40,
}) {
  if (profile.length < 2) return const [];

  final first = profile.first.timestamp;
  final last = profile.last.timestamp;
  final span = last - first;
  if (span <= 0) return const [];

  double maxDepth = 0;
  for (final p in profile) {
    if (p.depth > maxDepth) maxDepth = p.depth;
  }
  if (maxDepth <= 0) return const [];

  final source = profile.length <= targetCount
      ? profile
      : _bucketMax(profile, targetCount);

  return [
    for (final p in source)
      (t: (p.timestamp - first) / span, depth: p.depth / maxDepth),
  ];
}

List<DiveProfilePoint> _bucketMax(
  List<DiveProfilePoint> profile,
  int targetCount,
) {
  final first = profile.first.timestamp;
  final span = profile.last.timestamp - first;
  final result = <DiveProfilePoint>[];
  var bucketIndex = -1;
  DiveProfilePoint? bucketBest;
  for (final p in profile) {
    final index = (((p.timestamp - first) / span) * (targetCount - 1)).floor();
    if (index != bucketIndex) {
      if (bucketBest != null) result.add(bucketBest);
      bucketIndex = index;
      bucketBest = p;
    } else if (p.depth > bucketBest!.depth) {
      bucketBest = p;
    }
  }
  if (bucketBest != null) result.add(bucketBest);
  return result;
}
```

`lib/features/trips/domain/services/day_rhythm_layout.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Assumed duration when a dive has neither runtime nor bottom time.
const Duration _fallbackDuration = Duration(minutes: 45);

/// Minimum visual width so very short dives stay tappable/visible.
const double _minWidthFraction = 0.02;

/// One dive rendered as a block on a 24h day axis.
class RhythmBlock extends Equatable {
  final double startFraction;
  final double widthFraction;
  final bool isNight;

  const RhythmBlock({
    required this.startFraction,
    required this.widthFraction,
    required this.isNight,
  });

  @override
  List<Object?> get props => [startFraction, widthFraction, isNight];
}

/// Lay out one day's dives on a 24h axis as fractions of the day.
List<RhythmBlock> computeRhythmBlocks(List<Dive> dives, DateTime dayDate) {
  const daySeconds = 24 * 3600;
  final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);

  return dives.map((dive) {
    final entry = dive.entryTime ?? dive.dateTime;
    final duration = dive.runtime ?? dive.bottomTime ?? _fallbackDuration;

    final startSeconds = entry.difference(dayStart).inSeconds;
    var start = (startSeconds / daySeconds).clamp(0.0, 1.0);
    var width = (duration.inSeconds / daySeconds).clamp(
      _minWidthFraction,
      1.0,
    );
    if (start + width > 1.0) {
      width = 1.0 - start;
      if (width < _minWidthFraction) {
        start = 1.0 - _minWidthFraction;
        width = _minWidthFraction;
      }
    }

    final hour = entry.hour;
    return RhythmBlock(
      startFraction: start,
      widthFraction: width,
      isNight: hour >= 18 || hour < 6,
    );
  }).toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/profile_sparkline_test.dart test/features/trips/domain/services/day_rhythm_layout_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/profile_sparkline.dart lib/features/trips/domain/services/day_rhythm_layout.dart test/features/dive_log/domain/services/profile_sparkline_test.dart test/features/trips/domain/services/day_rhythm_layout_test.dart
git commit -m "feat(trips): add sparkline downsampling and day rhythm layout math"
```

---

### Task 7: Localization strings (all locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerates: `lib/l10n/arb/app_localizations*.dart` (checked in)

**Interfaces:**
- Produces (used by Tasks 8-13): `context.l10n.<key>` getters listed below. Reused existing keys (do NOT re-add): `trips_detail_stat_totalDives`, `trips_detail_stat_totalBottomTime`, `trips_detail_stat_maxDepth`, `trips_breakdown_column_sites`, `trips_detail_dives_unknownSite`, `trips_photos_viewAll`, `trips_detail_sectionTitle_notes`, `trips_detail_dives_empty`, `trips_diveScan_findButton`, `trips_detail_durationDays`.

- [ ] **Step 1: Add the English strings**

Insert into `lib/l10n/arb/app_en.arb` next to the other `trips_` keys (keep alphabetical-ish grouping with the trips block):

```json
"trips_story_dayLabel": "Day {number}",
"@trips_story_dayLabel": {"placeholders": {"number": {"type": "int"}}},
"trips_story_surfaceDay": "Surface day",
"trips_story_today": "Today",
"trips_story_dayOfTrip": "Day {current} of {total}",
"@trips_story_dayOfTrip": {"placeholders": {"current": {"type": "int"}, "total": {"type": "int"}}},
"trips_story_daysUntil": "{days, plural, =1{1 day until departure} other{{days} days until departure}}",
"@trips_story_daysUntil": {"placeholders": {"days": {"type": "int"}}},
"trips_story_checklistProgress": "{done} of {total} done",
"@trips_story_checklistProgress": {"placeholders": {"done": {"type": "int"}, "total": {"type": "int"}}},
"trips_story_generateItinerary": "Generate itinerary",
"trips_story_planned": "Planned",
"trips_story_empty_title": "No dives or itinerary yet",
"trips_story_empty_subtitle": "Add dives to this trip or plan its days to see the story.",
"trips_story_history_dives": "{count, plural, =1{1 past dive here} other{{count} past dives here}}",
"@trips_story_history_dives": {"placeholders": {"count": {"type": "int"}}},
"trips_story_history_avgTemp": "avg {value}",
"@trips_story_history_avgTemp": {"placeholders": {"value": {"type": "String"}}},
"trips_story_history_avgDepth": "avg depth {value}",
"@trips_story_history_avgDepth": {"placeholders": {"value": {"type": "String"}}},
"trips_story_rhythm_semantics": "Dive times during this day",
"trips_story_map_semantics": "Trip map. Sites for the day in view are highlighted."
```

- [ ] **Step 2: Add translations to the other ten locales**

Add the same keys (with `@`-metadata only in `app_en.arb`; the other files carry values only, matching existing file style — verify by looking at how `trips_breakdown_column_day` appears in `app_de.arb`). Translations:

| key | de | es | fr | it | nl | pt |
|---|---|---|---|---|---|---|
| dayLabel | `Tag {number}` | `Dia {number}` | `Jour {number}` | `Giorno {number}` | `Dag {number}` | `Dia {number}` |
| surfaceDay | `Oberflaechentag` -> use `Oberflächentag` | `Día de superficie` | `Journée en surface` | `Giorno di superficie` | `Oppervlaktedag` | `Dia de superfície` |
| today | `Heute` | `Hoy` | `Aujourd'hui` | `Oggi` | `Vandaag` | `Hoje` |
| dayOfTrip | `Tag {current} von {total}` | `Día {current} de {total}` | `Jour {current} sur {total}` | `Giorno {current} di {total}` | `Dag {current} van {total}` | `Dia {current} de {total}` |
| daysUntil | `{days, plural, =1{Noch 1 Tag bis zur Abreise} other{Noch {days} Tage bis zur Abreise}}` | `{days, plural, =1{1 día para la salida} other{{days} días para la salida}}` | `{days, plural, =1{1 jour avant le départ} other{{days} jours avant le départ}}` | `{days, plural, =1{1 giorno alla partenza} other{{days} giorni alla partenza}}` | `{days, plural, =1{Nog 1 dag tot vertrek} other{Nog {days} dagen tot vertrek}}` | `{days, plural, =1{1 dia até a partida} other{{days} dias até a partida}}` |
| checklistProgress | `{done} von {total} erledigt` | `{done} de {total} completado` | `{done} sur {total} fait` | `{done} di {total} completati` | `{done} van {total} klaar` | `{done} de {total} concluído` |
| generateItinerary | `Reiseplan erstellen` | `Generar itinerario` | `Générer l'itinéraire` | `Genera itinerario` | `Reisplan genereren` | `Gerar itinerário` |
| planned | `Geplant` | `Planificado` | `Prévu` | `Pianificato` | `Gepland` | `Planejado` |
| empty_title | `Noch keine Tauchgänge oder Reiseplan` | `Aún no hay inmersiones ni itinerario` | `Pas encore de plongées ni d'itinéraire` | `Nessuna immersione o itinerario` | `Nog geen duiken of reisplan` | `Ainda sem mergulhos ou itinerário` |
| empty_subtitle | `Füge Tauchgänge hinzu oder plane die Tage, um die Story zu sehen.` | `Añade inmersiones o planifica los días para ver la historia.` | `Ajoutez des plongées ou planifiez les jours pour voir le récit.` | `Aggiungi immersioni o pianifica i giorni per vedere la storia.` | `Voeg duiken toe of plan de dagen om het verhaal te zien.` | `Adicione mergulhos ou planeje os dias para ver a história.` |
| history_dives | `{count, plural, =1{1 früherer Tauchgang hier} other{{count} frühere Tauchgänge hier}}` | `{count, plural, =1{1 inmersión previa aquí} other{{count} inmersiones previas aquí}}` | `{count, plural, =1{1 plongée passée ici} other{{count} plongées passées ici}}` | `{count, plural, =1{1 immersione passata qui} other{{count} immersioni passate qui}}` | `{count, plural, =1{1 eerdere duik hier} other{{count} eerdere duiken hier}}` | `{count, plural, =1{1 mergulho anterior aqui} other{{count} mergulhos anteriores aqui}}` |
| history_avgTemp | `Ø {value}` | `media {value}` | `moy. {value}` | `media {value}` | `gem. {value}` | `média {value}` |
| history_avgDepth | `Ø Tiefe {value}` | `prof. media {value}` | `prof. moy. {value}` | `prof. media {value}` | `gem. diepte {value}` | `prof. média {value}` |
| rhythm_semantics | `Tauchzeiten an diesem Tag` | `Horarios de inmersión de este día` | `Heures de plongée de cette journée` | `Orari delle immersioni del giorno` | `Duiktijden van deze dag` | `Horários de mergulho deste dia` |
| map_semantics | `Reisekarte. Die Tauchplätze des sichtbaren Tages sind hervorgehoben.` | `Mapa del viaje. Los puntos del día visible están resaltados.` | `Carte du voyage. Les sites du jour affiché sont mis en évidence.` | `Mappa del viaggio. I siti del giorno visibile sono evidenziati.` | `Reiskaart. De stekken van de zichtbare dag zijn gemarkeerd.` | `Mapa da viagem. Os pontos do dia visível estão destacados.` |

| key | ar | he | hu | zh |
|---|---|---|---|---|
| dayLabel | `اليوم {number}` | `יום {number}` | `{number}. nap` | `第 {number} 天` |
| surfaceDay | `يوم سطح` | `יום פני השטח` | `Felszíni nap` | `水面日` |
| today | `اليوم` | `היום` | `Ma` | `今天` |
| dayOfTrip | `اليوم {current} من {total}` | `יום {current} מתוך {total}` | `{current}. nap a(z) {total} napból` | `第 {current} 天，共 {total} 天` |
| daysUntil | `{days, plural, =1{يوم واحد حتى المغادرة} other{{days} أيام حتى المغادرة}}` | `{days, plural, =1{יום אחד עד היציאה} other{{days} ימים עד היציאה}}` | `{days, plural, =1{1 nap az indulásig} other{{days} nap az indulásig}}` | `{days, plural, other{距出发还有 {days} 天}}` |
| checklistProgress | `اكتمل {done} من {total}` | `{done} מתוך {total} הושלמו` | `{done}/{total} kész` | `已完成 {done}/{total}` |
| generateItinerary | `إنشاء خط سير` | `צור מסלול` | `Útiterv létrehozása` | `生成行程` |
| planned | `مخطط` | `מתוכנן` | `Tervezett` | `已计划` |
| empty_title | `لا توجد غطسات أو خط سير بعد` | `אין עדיין צלילות או מסלול` | `Még nincs merülés vagy útiterv` | `还没有潜水或行程` |
| empty_subtitle | `أضف غطسات إلى هذه الرحلة أو خطط أيامها لرؤية القصة.` | `הוסף צלילות לטיול או תכנן את הימים כדי לראות את הסיפור.` | `Adj hozzá merüléseket vagy tervezd meg a napokat a történethez.` | `为此旅行添加潜水或规划行程以查看故事。` |
| history_dives | `{count, plural, =1{غطسة سابقة واحدة هنا} other{{count} غطسات سابقة هنا}}` | `{count, plural, =1{צלילה קודמת אחת כאן} other{{count} צלילות קודמות כאן}}` | `{count, plural, =1{1 korábbi merülés itt} other{{count} korábbi merülés itt}}` | `{count, plural, other{此处有 {count} 次过往潜水}}` |
| history_avgTemp | `متوسط {value}` | `ממוצע {value}` | `átlag {value}` | `平均 {value}` |
| history_avgDepth | `متوسط العمق {value}` | `עומק ממוצע {value}` | `átl. mélység {value}` | `平均深度 {value}` |
| rhythm_semantics | `أوقات الغطس في هذا اليوم` | `זמני הצלילה ביום זה` | `A nap merülési idői` | `当天的潜水时间` |
| map_semantics | `خريطة الرحلة. مواقع اليوم المعروض مميزة.` | `מפת הטיול. אתרי היום המוצג מודגשים.` | `Úti térkép. A látható nap helyszínei kiemelve.` | `旅行地图。当前日期的潜点已高亮。` |

Note: Arabic plural rules also require `=2`/`few`/`many` categories in some
existing keys; check how an existing `{days, plural, ...}` key is written in
`app_ar.arb` and mirror that structure (add `=0{...} =2{...} few{...} many{...}`
variants following the file's own precedent) if `flutter gen-l10n` complains.

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: exits 0.
Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/l10n/
git commit -m "feat(l10n): add trip story strings in all locales"
```

---

### Task 8: Sparkline and rhythm bar widgets

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/dive_sparkline.dart`
- Create: `lib/features/trips/presentation/widgets/story/day_rhythm_bar.dart`
- Test: `test/features/trips/presentation/widgets/story/dive_sparkline_test.dart`
- Test: `test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`

**Interfaces:**
- Consumes: `sparklinePoints` and `computeRhythmBlocks`/`RhythmBlock` (Task 6), l10n key `trips_story_rhythm_semantics` (Task 7).
- Produces (used by Task 9):
  - `class DiveSparkline extends StatelessWidget { const DiveSparkline({required List<DiveProfilePoint> profile, double width = 60, double height = 20}); }` — renders `SizedBox.shrink` when `sparklinePoints` returns empty.
  - `class DayRhythmBar extends StatelessWidget { const DayRhythmBar({required List<Dive> dives, required DateTime dayDate, double height = 28}); }`

- [ ] **Step 1: Write the failing widget tests**

`test/features/trips/presentation/widgets/story/dive_sparkline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/presentation/widgets/story/dive_sparkline.dart';

void main() {
  testWidgets('renders a CustomPaint for a real profile', (tester) async {
    final profile = List.generate(
      50,
      (i) => DiveProfilePoint(timestamp: i * 30, depth: (i % 10) + 5.0),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DiveSparkline(profile: profile))),
    );
    expect(
      find.descendant(
        of: find.byType(DiveSparkline),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing for an empty profile', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DiveSparkline(profile: []))),
    );
    expect(
      find.descendant(
        of: find.byType(DiveSparkline),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
```

`test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('renders with a semantics label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayRhythmBar(
            dives: [
              Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9)),
            ],
            dayDate: DateTime(2026, 3, 8),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Dive times during this day'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/dive_sparkline_test.dart test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement the widgets**

`lib/features/trips/presentation/widgets/story/dive_sparkline.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sparkline.dart';

/// Tiny depth-vs-time curve for a dive row. Renders nothing when the dive
/// has no usable profile.
class DiveSparkline extends StatelessWidget {
  final List<DiveProfilePoint> profile;
  final double width;
  final double height;

  const DiveSparkline({
    super.key,
    required this.profile,
    this.width = 60,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    final points = sparklinePoints(profile);
    if (points.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _SparklinePainter(
            points: points,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<({double t, double depth})> points;
  final Color color;

  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points[i].t * size.width;
      final y = points[i].depth * (size.height - 2) + 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
```

`lib/features/trips/presentation/widgets/story/day_rhythm_bar.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day's dives plotted as blocks on a 24h axis. Night dives are tinted
/// with the tertiary color; surface intervals appear as gaps.
class DayRhythmBar extends StatelessWidget {
  final List<Dive> dives;
  final DateTime dayDate;
  final double height;

  const DayRhythmBar({
    super.key,
    required this.dives,
    required this.dayDate,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = computeRhythmBlocks(dives, dayDate);
    if (blocks.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: context.l10n.trips_story_rhythm_semantics,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _RhythmPainter(
            blocks: blocks,
            trackColor: colorScheme.surfaceContainerHighest,
            dayColor: colorScheme.primary,
            nightColor: colorScheme.tertiary,
            tickTextStyle: labelStyle,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  final List<RhythmBlock> blocks;
  final Color trackColor;
  final Color dayColor;
  final Color nightColor;
  final TextStyle? tickTextStyle;
  final TextDirection textDirection;

  const _RhythmPainter({
    required this.blocks,
    required this.trackColor,
    required this.dayColor,
    required this.nightColor,
    required this.tickTextStyle,
    required this.textDirection,
  });

  static const _tickHours = [6, 12, 18];

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 12.0;
    final trackHeight = size.height - labelHeight;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, trackHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, Paint()..color = trackColor);

    for (final block in blocks) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          block.startFraction * size.width,
          2,
          block.widthFraction * size.width,
          trackHeight - 4,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = block.isNight ? nightColor : dayColor,
      );
    }

    for (final hour in _tickHours) {
      final x = hour / 24 * size.width;
      final painter = TextPainter(
        text: TextSpan(text: '$hour:00', style: tickTextStyle),
        textDirection: textDirection,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          trackHeight + 1,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter oldDelegate) =>
      oldDelegate.blocks != blocks ||
      oldDelegate.dayColor != dayColor ||
      oldDelegate.nightColor != nightColor ||
      oldDelegate.trackColor != trackColor;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/dive_sparkline_test.dart test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/story/
git commit -m "feat(trips): add dive sparkline and day rhythm bar widgets"
```

---

### Task 9: TripStoryDayCard

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`

**Interfaces:**
- Consumes: `TripStoryDay`/`TripStoryDayKind` (Task 1), `DiveSparkline`, `DayRhythmBar` (Task 8), `DiveListItem` + `DiveSummary.fromDive` (`lib/features/dive_log/presentation/widgets/dive_list_item.dart`, `lib/features/dive_log/domain/entities/dive_summary.dart`), `MediaItemView` (`lib/features/media/presentation/widgets/media_item_view.dart` — verify path with `grep -rln "class MediaItemView" lib/`), `siteHistoryByNameProvider` (Task 5), `UnitFormatter`, l10n keys (Task 7).
- Produces (used by Task 12): `class TripStoryDayCard extends ConsumerWidget { const TripStoryDayCard({required TripStoryDay day, required String tripId}); }` — navigates with `context.push('/dives/<id>')` and `context.push('/trips/<tripId>/gallery')`.

- [ ] **Step 1: Write the failing widget tests**

`test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart` (uses the ProviderScope + router pattern from `trip_overview_tab_test.dart`; abbreviated setup shown once, reuse for each case):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Future<void> pumpCard(WidgetTester tester, TripStoryDay day) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: TripStoryDayCard(day: day, tripId: 'trip-1'),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('past day with dives shows stats, rhythm, and dive rows', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 42,
      bottomTime: const Duration(minutes: 47),
      maxDepth: 28.0,
    );
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [dive],
    );
    await pumpCard(tester, day);

    expect(find.text('Day 2'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsOneWidget);
    expect(find.byType(DiveListItem), findsOneWidget);
  });

  testWidgets('surface day renders the slim variant', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 9),
      dayNumber: 3,
      kind: TripStoryDayKind.past,
    );
    await pumpCard(tester, day);
    expect(find.text('Surface day'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsNothing);
  });

  testWidgets('future day shows the planned chip', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpCard(tester, day);
    expect(find.text('Planned'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the day card**

`lib/features/trips/presentation/widgets/story/trip_story_day_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/dive_sparkline.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const int _maxPhotoThumbnails = 6;

/// One day chapter of the trip story.
class TripStoryDayCard extends ConsumerWidget {
  final TripStoryDay day;
  final String tripId;

  const TripStoryDayCard({super.key, required this.day, required this.tripId});

  bool get _isPlanned => day.kind == TripStoryDayKind.future;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    if (!day.hasContent && day.kind != TripStoryDayKind.future) {
      return _SurfaceDayRow(day: day);
    }

    final card = Card(
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
              _buildHeader(context, theme),
              if (day.dives.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DayStatStrip(day: day, units: units),
                const SizedBox(height: 12),
                DayRhythmBar(dives: day.dives, dayDate: day.date),
                const SizedBox(height: 8),
                ...day.dives.mapIndexed(
                  (index, dive) => Row(
                    children: [
                      Expanded(
                        child: DiveListItem(
                          summary: DiveSummary.fromDive(dive),
                          diveNumber: dive.diveNumber ?? index + 1,
                          onTap: () => context.push('/dives/${dive.id}'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: DiveSparkline(profile: dive.profile),
                      ),
                    ],
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
    return card;
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final dateFormat = DateFormat.MMMEd();
    final itinerary = day.itineraryDay;
    final subtitleParts = <String>[
      if (itinerary != null) itinerary.dayType.displayName,
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
                ' - ${dateFormat.format(day.date)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
        if (_isPlanned)
          Chip(
            label: Text(context.l10n.trips_story_planned),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Slim row for a day with no dives, media, or itinerary entry.
class _SurfaceDayRow extends StatelessWidget {
  final TripStoryDay day;

  const _SurfaceDayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMEd();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.waves,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
            ' - ${dateFormat.format(day.date)}'
            ' - ${context.l10n.trips_story_surfaceDay}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStatStrip extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _DayStatStrip({required this.day, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = day.totalBottomTime;
    final bottomLabel = bottom.inHours > 0
        ? '${bottom.inHours}h ${bottom.inMinutes % 60}m'
        : '${bottom.inMinutes}m';
    final stats = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${day.diveCount}'),
      (l10n.trips_detail_stat_totalBottomTime, bottomLabel),
      if (day.maxDepth != null)
        (l10n.trips_detail_stat_maxDepth, units.formatDepth(day.maxDepth)),
      (l10n.trips_breakdown_column_sites, '${day.siteNames.length}'),
    ];

    return Row(
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: Semantics(
              label: '$label: $value',
              child: Column(
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final String tripId;
  final List<dynamic> media;

  const _PhotoStrip({required this.tripId, required this.media});

  @override
  Widget build(BuildContext context) {
    final visible = media.take(_maxPhotoThumbnails).toList();
    final remaining = media.length - visible.length;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length + (remaining > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return _MoreThumbnail(count: remaining, tripId: tripId);
          }
          return GestureDetector(
            onTap: () => context.push('/trips/$tripId/gallery'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 64,
                height: 64,
                child: MediaItemView(
                  item: visible[index],
                  thumbnail: true,
                  targetSize: const Size(128, 128),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreThumbnail extends StatelessWidget {
  final int count;
  final String tripId;

  const _MoreThumbnail({required this.count, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/trips/$tripId/gallery'),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text('+$count', style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _SightingChips extends StatelessWidget {
  final TripStoryDay day;

  const _SightingChips({required this.day});

  @override
  Widget build(BuildContext context) {
    // Merge duplicate species across the day's dives.
    final counts = <String, int>{};
    for (final sighting in day.sightings) {
      counts[sighting.speciesName] =
          (counts[sighting.speciesName] ?? 0) + sighting.count;
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final entry in counts.entries)
          Chip(
            label: Text(
              entry.value > 1 ? '${entry.key} x${entry.value}' : entry.key,
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Itinerary notes and site-history context pills for planned days.
class _PlannedExtras extends ConsumerWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _PlannedExtras({required this.day, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itinerary = day.itineraryDay;
    final notes = itinerary?.notes ?? '';
    final portName = itinerary?.portName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (portName != null) _HistoryPills(siteName: portName, units: units),
      ],
    );
  }
}

class _HistoryPills extends ConsumerWidget {
  final String siteName;
  final UnitFormatter units;

  const _HistoryPills({required this.siteName, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(siteHistoryByNameProvider(siteName));
    final history = historyAsync.valueOrNull;
    if (history == null || history.diveCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Chip(
            label: Text(l10n.trips_story_history_dives(history.diveCount)),
            visualDensity: VisualDensity.compact,
          ),
          if (history.avgWaterTemp != null)
            Chip(
              label: Text(
                l10n.trips_story_history_avgTemp(
                  units.formatTemperature(history.avgWaterTemp),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          if (history.avgMaxDepth != null)
            Chip(
              label: Text(
                l10n.trips_story_history_avgDepth(
                  units.formatDepth(history.avgMaxDepth),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
```

Notes for the implementer:
- `mapIndexed` comes from `package:collection/collection.dart` (already a
  dependency); add the import.
- `_PhotoStrip.media` is typed `List<dynamic>` above only to avoid a
  duplicated import list in this plan; type it `List<MediaItem>` in the
  real file.
- If `MediaItemView`'s constructor differs (check the actual class), match
  the usage in `trip_photo_section.dart` lines 240-256 exactly.
- `Dive.profile` may be large; `DiveSummary.fromDive` and `sparklinePoints`
  both run in build. If a trip day has 10+ dives this is still fine (one
  pass per dive), but do NOT sort or copy profiles here.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_day_card.dart test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart
git commit -m "feat(trips): add trip story day chapter card"
```

---

### Task 10: TripStoryHero (countdown, checklist, empty state)

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_hero.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`

**Interfaces:**
- Consumes: `TripStory` (Task 1), `Trip.daysUntilStart`/`isInProgress`/`isUpcoming` (existing), `ItineraryDay.generateForTrip` + `ItineraryDayRepository.saveAll` (via `itineraryDayRepositoryProvider` — verify name with `grep -n "RepositoryProvider" lib/features/trips/presentation/providers/liveaboard_providers.dart`), `itineraryDaysProvider`, l10n keys (Task 7).
- Produces (used by Task 12): `class TripStoryHero extends ConsumerWidget { const TripStoryHero({required TripStory story, required VoidCallback? onScanForDives}); }`
  - Future trip: countdown text + checklist progress card (progress bar, next-due items) + "Generate itinerary" button when `story.trip` has no itinerary days anywhere in `story.days`.
  - In-progress trip: `trips_story_dayOfTrip` line.
  - Empty story (`story.isEmpty`): empty-state column with scan-for-dives button (calls `onScanForDives`) and generate-itinerary button.
  - Past trip with content: renders only name/dates row.

- [ ] **Step 1: Write the failing widget tests**

`test/features/trips/presentation/widgets/story/trip_story_hero_test.dart` (same pump pattern as Task 9; build `TripStory` values directly with `buildTripStory` from Task 2 for convenience):

```dart
// Case 1: planned trip (today before startDate), checklist 1/2 done
//   -> expect countdown text visible: find.textContaining('until departure')
//   -> expect '1 of 2 done'
//   -> expect 'Generate itinerary' button (no itinerary days)
// Case 2: in-progress trip (today == startDate + 1)
//   -> expect 'Day 2 of 4'
// Case 3: empty past trip
//   -> expect 'No dives or itinerary yet'
//   -> tapping 'Scan for dives' invokes the callback (use a bool flag)
```

Write the three cases in full using `buildTripStory` with an injected `today` to construct each story, and the Task 9 pump pattern. For case 1 the checklist list is `[_check('a', done: true), _check('b')]` (copy the `_check` helper from Task 2's test).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the hero**

`lib/features/trips/presentation/widgets/story/trip_story_hero.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Story header: trip identity plus mode-specific extras (countdown and
/// checklist for planned trips, progress line for in-progress trips, empty
/// state with CTAs for bare trips).
class TripStoryHero extends ConsumerWidget {
  final TripStory story;
  final VoidCallback? onScanForDives;

  const TripStoryHero({
    super.key,
    required this.story,
    this.onScanForDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = story.trip;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final hasItinerary = story.days.any((d) => d.itineraryDay != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trip.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${dateFormat.format(trip.startDate)}'
          ' - ${dateFormat.format(trip.endDate)}'
          ' (${context.l10n.trips_detail_durationDays(trip.durationDays)})',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (trip.isInProgress) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_dayOfTrip(
              (story.todayIndex ?? 0) + 1,
              story.days.length,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else if (trip.isUpcoming) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_daysUntil(trip.daysUntilStart),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (trip.isUpcoming && !story.checklist.isEmpty) ...[
          const SizedBox(height: 12),
          _ChecklistCard(story: story),
        ],
        if (trip.isUpcoming && !hasItinerary) ...[
          const SizedBox(height: 8),
          _GenerateItineraryButton(story: story),
        ],
        if (story.isEmpty) ...[
          const SizedBox(height: 16),
          _EmptyState(
            story: story,
            onScanForDives: onScanForDives,
            hasItinerary: hasItinerary,
          ),
        ],
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final TripStory story;

  const _ChecklistCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklist = story.checklist;
    final progress = checklist.total == 0
        ? 0.0
        : checklist.done / checklist.total;
    final dateFormat = DateFormat.MMMd();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trips_story_checklistProgress(
                checklist.done,
                checklist.total,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            for (final item in checklist.nextDue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.dueDate != null)
                      Text(
                        dateFormat.format(item.dueDate!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GenerateItineraryButton extends ConsumerWidget {
  final TripStory story;

  const _GenerateItineraryButton({required this.story});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.event_note, size: 18),
      label: Text(context.l10n.trips_story_generateItinerary),
      onPressed: () async {
        final days = ItineraryDay.generateForTrip(
          tripId: story.trip.id,
          startDate: story.trip.startDate,
          endDate: story.trip.endDate,
        );
        await ref.read(itineraryDayRepositoryProvider).saveAll(days);
        ref.invalidate(itineraryDaysProvider(story.trip.id));
        ref.invalidate(tripStoryProvider(story.trip.id));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TripStory story;
  final VoidCallback? onScanForDives;
  final bool hasItinerary;

  const _EmptyState({
    required this.story,
    required this.onScanForDives,
    required this.hasItinerary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.auto_stories,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_empty_title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.trips_story_empty_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (onScanForDives != null)
            FilledButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(context.l10n.trips_diveScan_findButton),
              onPressed: onScanForDives,
            ),
        ],
      ),
    );
  }
}
```

Verify `itineraryDayRepositoryProvider` exists under that name in
`liveaboard_providers.dart`; if it is named differently (e.g.
`itineraryRepositoryProvider`), use the actual name.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_hero_test.dart`
Expected: PASS (3 cases).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_hero.dart test/features/trips/presentation/widgets/story/trip_story_hero_test.dart
git commit -m "feat(trips): add trip story hero with planned-trip extras"
```

---

### Task 11: Pinned map header

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart`

**Interfaces:**
- Consumes: `TripStoryMapGeometry`/`TripStoryMapPoint` (Task 1), `TripWithStats`, `TrackpadZoomMap`, `MapAttribution`, `mapTileUrlProvider`, `mapTileMaxZoomProvider`, `TileCacheService`, `calculateZoomForBounds` (`lib/features/maps/domain/map_utils.dart`), `UnitFormatter`, l10n (Task 7).
- Produces (used by Task 12):
  - `class TripStoryMapHeaderDelegate extends SliverPersistentHeaderDelegate` with constructor `({required TripStoryMapGeometry geometry, required TripWithStats stats, required int activeDayIndex, required MapController mapController, required ValueChanged<int> onDaySelected, required double maxExtentValue, double minExtentValue = 120})`. Dimmed pins for inactive days; tapping a pin calls `onDaySelected(point.dayIndex)`. When `geometry.hasPoints` is false renders the gradient fallback card (no map).
  - `class MapCameraAnimator { MapCameraAnimator({required TickerProvider vsync, required MapController controller}); void animateTo({required LatLng center, required double zoom}); void dispose(); }`
  - `class TripStatStrip extends ConsumerWidget { const TripStatStrip({required TripWithStats stats}); }` (dives / bottom time / max depth count strip shown along the header bottom)

- [ ] **Step 1: Write the failing widget test**

`test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart` — pump a `CustomScrollView` with the delegate inside `SliverPersistentHeader(pinned: true, delegate: ...)` using the Task 9 pump pattern (base overrides include tile URL overrides; confirm by reading `test/helpers/mock_providers.dart`, and follow `test/features/trips/presentation/widgets/trip_voyage_map_test.dart` for any map-specific test setup such as network-image stubbing):

```dart
// Case 1: geometry with 2 points -> FlutterMap present, 2 Markers rendered.
// Case 2: empty geometry -> no FlutterMap; fallback shows trip stat strip only.
// Case 3: stat strip shows '14' for diveCount 14.
```

Write all three cases in full following those patterns.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

`lib/features/trips/presentation/widgets/story/trip_story_map_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Eases the flutter_map camera between positions (flutter_map has no
/// built-in animated move).
class MapCameraAnimator {
  final TickerProvider vsync;
  final MapController controller;
  AnimationController? _animation;

  MapCameraAnimator({required this.vsync, required this.controller});

  void animateTo({required LatLng center, required double zoom}) {
    _animation?.dispose();
    final camera = controller.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: center.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: center.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final animation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 450),
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    );
    animation.addListener(() {
      controller.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });
    animation.forward();
    _animation = animation;
  }

  void dispose() {
    _animation?.dispose();
    _animation = null;
  }
}

/// Pinned header hosting the story map and the trip-level stat strip.
class TripStoryMapHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TripStoryMapGeometry geometry;
  final TripWithStats stats;
  final int activeDayIndex;
  final MapController mapController;
  final ValueChanged<int> onDaySelected;
  final double maxExtentValue;
  final double minExtentValue;

  const TripStoryMapHeaderDelegate({
    required this.geometry,
    required this.stats,
    required this.activeDayIndex,
    required this.mapController,
    required this.onDaySelected,
    required this.maxExtentValue,
    this.minExtentValue = 120,
  });

  @override
  double get maxExtent => maxExtentValue;

  @override
  double get minExtent => minExtentValue;

  @override
  bool shouldRebuild(TripStoryMapHeaderDelegate oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.stats != stats ||
      oldDelegate.activeDayIndex != activeDayIndex;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      child: Column(
        children: [
          Expanded(
            child: geometry.hasPoints
                ? _StoryMap(
                    geometry: geometry,
                    activeDayIndex: activeDayIndex,
                    mapController: mapController,
                    onDaySelected: onDaySelected,
                  )
                : const _MapFallback(),
          ),
          TripStatStrip(stats: stats),
        ],
      ),
    );
  }
}

class _StoryMap extends ConsumerWidget {
  final TripStoryMapGeometry geometry;
  final int activeDayIndex;
  final MapController mapController;
  final ValueChanged<int> onDaySelected;

  const _StoryMap({
    required this.geometry,
    required this.activeDayIndex,
    required this.mapController,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final points = geometry.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    final zoom = calculateZoomForBounds(points, bounds);

    return Semantics(
      label: context.l10n.trips_story_map_semantics,
      child: TrackpadZoomMap(
        controller: mapController,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: bounds.center,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: ref.watch(mapTileUrlProvider),
              userAgentPackageName: 'app.submersion',
              maxZoom: ref.watch(mapTileMaxZoomProvider),
              tileProvider: TileCacheService.instance.isInitialized
                  ? TileCacheService.instance.getTileProvider()
                  : null,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 2,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  pattern: const StrokePattern.dotted(),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final point in geometry.points)
                  Marker(
                    point: LatLng(point.latitude, point.longitude),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => onDaySelected(point.dayIndex),
                      child: Opacity(
                        opacity: point.dayIndex == activeDayIndex ? 1 : 0.45,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.scuba_diving,
                            size: 14,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Gradient card shown when the trip has no mappable points.
class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primaryContainer, colorScheme.surface],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.scuba_diving,
        size: 48,
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Horizontal trip-level stat strip pinned under the map.
class TripStatStrip extends ConsumerWidget {
  final TripWithStats stats;

  const TripStatStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final entries = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${stats.diveCount}'),
      (l10n.trips_detail_stat_totalBottomTime, stats.formattedBottomTime),
      if (stats.maxDepth != null)
        (l10n.trips_detail_stat_maxDepth, units.formatDepth(stats.maxDepth)),
    ];

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final (label, value) in entries)
            Expanded(
              child: Semantics(
                label: '$label: $value',
                child: Column(
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

If `StrokePattern.dotted()` does not exist in the pinned flutter_map 8.3.0
API, drop the `pattern:` argument (solid polyline) rather than upgrading the
package.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_map_header.dart test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart
git commit -m "feat(trips): add pinned story map header with camera animator"
```

---

### Task 12: TripStoryView assembly

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Create: `lib/features/trips/presentation/widgets/story/trip_vessel_section.dart` (public move of `_VesselSection` + `_VesselDetailRow` from `trip_overview_tab.dart`, renamed `TripVesselSection`; copy the code verbatim, only renaming the classes)
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1, 9, 10, 11; `TripChecklistSection` (`lib/features/checklists/presentation/widgets/trip_checklist_section.dart`).
- Produces (used by Task 13): `class TripStoryView extends ConsumerStatefulWidget { const TripStoryView({required TripStory story, required TripWithStats stats, VoidCallback? onScanForDives}); }`

Behavior contract:
- Narrow layout: `CustomScrollView` with `SliverPersistentHeader(pinned: true)` (map header, maxExtent 260), hero sliver, vessel section (liveaboard only), day cards, a "Today" divider row before the first `future` day when `story.todayIndex != null`, notes section (when `trip.notes` non-empty), collapsed `ExpansionTile` checklist at the end for non-upcoming non-liveaboard trips with a non-empty checklist.
- Wide layout (`LayoutBuilder` width >= 900): `Row[ SizedBox(width: 380, child: docked map column), Expanded(story scroll without the map header) ]`.
- Scroll listener: `NotificationListener<ScrollUpdateNotification>`; resolves the active day via per-day `GlobalKey`s (first day whose RenderBox top, in the scroll view's coordinate space, is below `viewportHeight / 3`), throttled to one resolution per 100ms; on change, `setState` + `MapCameraAnimator.animateTo` centered on the day's first map point (skip when the day has none).

- [ ] **Step 1: Write the failing widget test**

`test/features/trips/presentation/widgets/story/trip_story_view_test.dart` (Task 9 pump pattern; construct stories via `buildTripStory`):

```dart
// Case 1: past trip with 2 dive days -> expect 2 TripStoryDayCard, 1 TripStoryHero,
//         a pinned header (find.byType(TripStatStrip)), and no 'Today' text.
// Case 2: in-progress trip (today mid-range) -> expect 'Today' divider text once.
// Case 3: liveaboard trip -> expect TripVesselSection present
//         (override liveaboardDetailsProvider with null; section renders shrink,
//          so assert find.byType(TripVesselSection) instead of visible content).
// Case 4: wide layout: set tester.view.physicalSize = Size(1400, 900) (and
//         addTearDown(tester.view.reset)); expect FlutterMap/fallback and the
//         scroll content side by side: find.byType(Row) ancestor check via
//         find.byKey(const Key('trip-story-wide-layout')).
```

Write the four cases in full. For deterministic stories, pass explicit `today` values into `buildTripStory` when building fixtures (the provider is not involved; `TripStoryView` receives the story as a parameter).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement**

`lib/features/trips/presentation/widgets/story/trip_story_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _wideBreakpoint = 900;
const double _mapHeaderMaxExtent = 260;
const Duration _scrollThrottle = Duration(milliseconds: 100);

/// The assembled trip story: pinned map + hero + day chapters.
class TripStoryView extends ConsumerStatefulWidget {
  final TripStory story;
  final TripWithStats stats;
  final VoidCallback? onScanForDives;

  const TripStoryView({
    super.key,
    required this.story,
    required this.stats,
    this.onScanForDives,
  });

  @override
  ConsumerState<TripStoryView> createState() => _TripStoryViewState();
}

class _TripStoryViewState extends ConsumerState<TripStoryView>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late MapCameraAnimator _cameraAnimator;
  late List<GlobalKey> _dayKeys;
  int _activeDayIndex = 0;
  DateTime _lastResolve = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _cameraAnimator = MapCameraAnimator(
      vsync: this,
      controller: _mapController,
    );
    _buildKeys();
  }

  @override
  void didUpdateWidget(TripStoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.days.length != widget.story.days.length) _buildKeys();
  }

  void _buildKeys() {
    _dayKeys = List.generate(widget.story.days.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _cameraAnimator.dispose();
    super.dispose();
  }

  void _selectDay(int index, {bool animateMap = true}) {
    if (index == _activeDayIndex) return;
    setState(() => _activeDayIndex = index);
    if (!animateMap) return;
    final points = widget.story.mapGeometry.pointsForDay(index);
    if (points.isEmpty) return;
    _cameraAnimator.animateTo(
      center: LatLng(points.first.latitude, points.first.longitude),
      zoom: _mapController.camera.zoom,
    );
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    final now = DateTime.now();
    if (now.difference(_lastResolve) < _scrollThrottle) return false;
    _lastResolve = now;

    final viewportHeight = notification.metrics.viewportDimension;
    final threshold = viewportHeight / 3;
    for (var i = _dayKeys.length - 1; i >= 0; i--) {
      final keyContext = _dayKeys[i].currentContext;
      if (keyContext == null) continue;
      final box = keyContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        _selectDay(i);
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (!wide) {
          return NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: TripStoryMapHeaderDelegate(
                    geometry: widget.story.mapGeometry,
                    stats: widget.stats,
                    activeDayIndex: _activeDayIndex,
                    mapController: _mapController,
                    onDaySelected: (i) => _selectDay(i, animateMap: false),
                    maxExtentValue: _mapHeaderMaxExtent,
                  ),
                ),
                ..._contentSlivers(),
              ],
            ),
          );
        }
        return Row(
          key: const Key('trip-story-wide-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 380,
              child: Column(
                children: [
                  Expanded(
                    child: TripStoryMapHeaderDelegate(
                      geometry: widget.story.mapGeometry,
                      stats: widget.stats,
                      activeDayIndex: _activeDayIndex,
                      mapController: _mapController,
                      onDaySelected: (i) => _selectDay(i, animateMap: false),
                      maxExtentValue: _mapHeaderMaxExtent,
                    ).build(context, 0, false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: _onScroll,
                child: CustomScrollView(slivers: _contentSlivers()),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _contentSlivers() {
    final story = widget.story;
    final trip = story.trip;
    final todayIndex = story.todayIndex;
    final showChecklistAtEnd =
        !trip.isUpcoming && !trip.isLiveaboard && !story.checklist.isEmpty;

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: TripStoryHero(
            story: story,
            onScanForDives: widget.onScanForDives,
          ),
        ),
      ),
      if (trip.isLiveaboard)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: TripVesselSection(tripId: trip.id),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        sliver: SliverList.builder(
          itemCount: story.days.length,
          itemBuilder: (context, index) {
            final day = story.days[index];
            final showTodayDivider = todayIndex != null && index == todayIndex;
            return Column(
              key: _dayKeys[index],
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTodayDivider) const _TodayDivider(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TripStoryDayCard(day: day, tripId: trip.id),
                ),
              ],
            );
          },
        ),
      ),
      if (trip.notes.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.trips_detail_sectionTitle_notes,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (showChecklistAtEnd)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(
                  context.l10n.trips_story_checklistProgress(
                    story.checklist.done,
                    story.checklist.total,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TripChecklistSection(trip: trip),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.primary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              context.l10n.trips_story_today,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.primary)),
        ],
      ),
    );
  }
}
```

Notes:
- The wide layout reuses the delegate's `build` directly as a plain widget;
  if that reads awkwardly during implementation, extract the delegate's
  body into a shared private widget `_MapHeaderContent` used by both paths
  (equivalent outcome, implementer's choice).
- `TripChecklistSection(trip: trip)` — verify the constructor (it may take
  `trip:` or `tripId:`; check `lib/features/checklists/presentation/widgets/trip_checklist_section.dart`).

Create `trip_vessel_section.dart` by copying `_VesselSection` and
`_VesselDetailRow` out of `trip_overview_tab.dart` verbatim, renaming to
`TripVesselSection` / `_VesselDetailRow` (keep the second private), keeping
the same imports (`liveaboard_providers.dart`, l10n).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: PASS (4 cases).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/story/
git commit -m "feat(trips): assemble trip story view with scroll-linked map"
```

---

### Task 13: Integration — rebuild Overview tab, retire old widgets

**Files:**
- Create: `lib/features/trips/presentation/helpers/trip_scan_actions.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (full rewrite)
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (`_buildAppBarActions`)
- Delete: `lib/features/trips/presentation/widgets/trip_daily_breakdown.dart`, `lib/features/trips/presentation/widgets/trip_voyage_map.dart`, `lib/features/trips/presentation/widgets/trip_enhanced_stats.dart`
- Delete: `test/features/trips/presentation/widgets/trip_daily_breakdown_test.dart`, `test/features/trips/presentation/widgets/trip_voyage_map_test.dart`
- Modify: `test/features/trips/presentation/widgets/trip_overview_tab_test.dart` (full rewrite)

**Interfaces:**
- Consumes: `TripStoryView` (Task 12), `tripStoryProvider` (Task 5).
- Produces: `TripOverviewTab` keeps its existing public constructor `TripOverviewTab({required TripWithStats tripWithStats})` so `trip_detail_page.dart` call sites do not change. New helper functions:

```dart
Future<void> scanForTripDives(BuildContext context, WidgetRef ref, Trip trip);
Future<void> scanGalleryForTripPhotos(BuildContext context, WidgetRef ref, String tripId, Trip trip);
Future<void> scanLightroomForTrip(BuildContext context, WidgetRef ref, String tripId);
```

- [ ] **Step 1: Extract scan actions**

Create `lib/features/trips/presentation/helpers/trip_scan_actions.dart` by moving the bodies of `_scanForDives`, `_showScanDialog`, `_importPhotos`, and `_scanLightroom` out of `trip_overview_tab.dart` into the three top-level functions named above (`_importPhotos` stays a private helper of the file). The code moves verbatim except: `widget.tripWithStats.trip` becomes the `trip` parameter, and `ref`/`context` come from parameters. Keep all imports the move requires.

- [ ] **Step 2: Rewrite TripOverviewTab**

Replace the entire body of `trip_overview_tab.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overview tab for a trip: the interactive day-by-day trip story.
class TripOverviewTab extends ConsumerWidget {
  final TripWithStats tripWithStats;

  const TripOverviewTab({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final storyAsync = ref.watch(tripStoryProvider(trip.id));
    // Render last-known data during reloads to avoid loading flashes on
    // sync invalidations.
    final story = storyAsync.valueOrNull;

    if (story == null) {
      if (storyAsync.hasError) {
        return Center(
          child: Text(
            '${context.l10n.common_label_error}: ${storyAsync.error}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return TripStoryView(
      story: story,
      stats: tripWithStats,
      onScanForDives: () => scanForTripDives(context, ref, trip),
    );
  }
}
```

Verify `common_label_error` is the existing error-label key (it is used in
`trip_daily_breakdown.dart` today).

`StatRow` currently lives in this file and is imported by
`trip_enhanced_stats.dart` (being deleted). Before deleting, confirm no other
importers: `grep -rn "trip_overview_tab.dart" lib/ --include="*.dart" | grep -v "\.g\.dart"`.
Expected remaining importers: `trip_detail_page.dart` only. If anything else
imports `StatRow` from here, move `StatRow` to
`lib/features/trips/presentation/widgets/story/trip_stat_row.dart` and update
those imports instead of deleting it.

- [ ] **Step 3: Add overflow menu to trip detail page**

In `trip_detail_page.dart`, `_buildAppBarActions` (line ~191), append a
`PopupMenuButton<String>` after the existing actions:

```dart
      PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'scan-dives':
              await scanForTripDives(context, ref, trip);
            case 'scan-photos':
              await scanGalleryForTripPhotos(context, ref, trip.id, trip);
            case 'scan-lightroom':
              await scanLightroomForTrip(context, ref, trip.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'scan-dives',
            child: Text(context.l10n.trips_diveScan_findButton),
          ),
          PopupMenuItem(
            value: 'scan-photos',
            child: Text(context.l10n.trips_detail_photos_scanGallery),
          ),
          if (ref.watch(lightroomAccountProvider).value != null)
            PopupMenuItem(
              value: 'scan-lightroom',
              child: Text(context.l10n.trips_detail_photos_scanLightroom),
            ),
        ],
      ),
```

The two `trips_detail_photos_*` keys: find the actual existing key names used
by `TripPhotoSection` for its scan buttons
(`grep -n "onScanPressed\|scanGallery\|scanLightroom\|l10n\." lib/features/trips/presentation/widgets/trip_photo_section.dart | head -20`)
and reuse those; only if the buttons were icon-only with tooltips, reuse the
tooltip keys. Do not invent new keys.

- [ ] **Step 4: Delete retired widgets and their tests**

```bash
git rm lib/features/trips/presentation/widgets/trip_daily_breakdown.dart \
       lib/features/trips/presentation/widgets/trip_voyage_map.dart \
       lib/features/trips/presentation/widgets/trip_enhanced_stats.dart \
       test/features/trips/presentation/widgets/trip_daily_breakdown_test.dart \
       test/features/trips/presentation/widgets/trip_voyage_map_test.dart
```

Then fix any dangling imports: `grep -rn "trip_daily_breakdown\|trip_voyage_map\|trip_enhanced_stats" lib/ test/ --include="*.dart"` must return nothing.

- [ ] **Step 5: Rewrite the overview tab test**

Replace `test/features/trips/presentation/widgets/trip_overview_tab_test.dart` with story-based assertions (same pump pattern; override `tripByIdProvider`, `divesForTripProvider`, `itineraryDaysProvider`, `mediaForTripProvider`, `tripChecklistProvider`, `tripSightingsByDiveProvider` for the trip):

```dart
// Case 1 (the #166 acceptance test): resort trip, two dives on different
// days -> two TripStoryDayCard chapters with 'Day 1' and 'Day 2' labels.
// Case 2: dives render inside chapters (find.byType(DiveListItem) x2) and
// tapping one navigates to /dives/:id (assert via captured route).
// Case 3: provider error -> error text shown.
```

Write the three cases in full.

- [ ] **Step 6: Verify everything**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/trips/`
Expected: ALL PASS (the suite previously passed 428 tests; new total will be higher; zero failures).
Run: `flutter test test/features/dive_log/domain/services/profile_sparkline_test.dart test/features/marine_life/ test/features/statistics/data/repositories/site_history_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A lib/features/trips lib/features/marine_life test/features
git commit -m "feat(trips): rebuild Overview tab as interactive trip story (closes #166)"
```

---

### Task 14: Final verification and close-out

**Files:**
- Modify: `docs/superpowers/specs/2026-07-13-trip-story-design.md` (append implementation-deviation notes if any accumulated beyond the five listed in this plan)

- [ ] **Step 1: Whole-project gates**

```bash
dart format .          # must produce no changes
flutter analyze        # No issues found!
```

Run the touched feature test suites one final time:

```bash
flutter test test/features/trips/
flutter test test/features/marine_life/ test/features/statistics/
flutter test test/features/dive_log/domain/services/profile_sparkline_test.dart
```

Expected: zero failures.

- [ ] **Step 2: Spec conformance skim**

Re-read the spec's "Mode behavior" and "Disposition of existing Overview content" tables and verify each row is implemented or documented as a deviation. Append any new deviations to the spec's deviation list, commit docs change if any:

```bash
git add docs/superpowers/specs/2026-07-13-trip-story-design.md
git commit -m "docs(trips): record trip story implementation deviations"
```

- [ ] **Step 3: Manual smoke checklist (report to user; do not mark done without running the app)**

Run `flutter run -d macos` (check first that the user does not already have a session running; two concurrent macOS runs kill each other) and verify by hand:

1. Past resort trip with dives on 2+ days: chapters render, map follows scroll, tapping a pin scrolls the story, dive tap opens dive detail.
2. Liveaboard trip: vessel section renders; itinerary metadata appears in chapter headers.
3. Planned trip: countdown, checklist card, generate-itinerary CTA, planned chips.
4. Trip with no site GPS anywhere: gradient fallback header.
5. Wide window: side-docked map column.
6. Overflow menu: all three scan actions reachable.

This step is a checkpoint for the human partner: report findings, do not self-certify.

---

## Self-Review Results

- Spec coverage: day span rule (T2), kind derivation (T2), batched sightings (T3), site history pills (T4, T9), providers/invalidations (T5), sparkline + rhythm (T6, T8), l10n all locales (T7), day chapters incl. surface days and planned styling (T9), countdown/checklist/generate-itinerary/empty state (T10), pinned map + fallback + stat strip + pin tap (T11), scroll linkage + today divider + wide layout + notes + collapsed checklist + vessel (T12), full absorption incl. overflow actions and widget retirement + #166 acceptance test (T13), gates + manual smoke (T14). "TripEnhancedStats content folds into stat strips" is realized as: trip-level strip (T11) + per-day strips (T9).
- Placeholders: none; every step either contains the code or names the exact discovery command and the single decision it feeds.
- Type consistency: `TripStoryDay`/`TripStory` fields match between T1, T2, T5, T9-12; `getSightingsForDives` map keyed by dive id consumed identically in T5; `SiteHistory` record shape identical in T4/T5/T9; `TripStatStrip` produced in T11, asserted in T12 tests.
