# Dive List Scrubber Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Immich-style draggable scrubber on the right edge of the dive list (detailed and compact modes) whose track markers follow the active sort and whose bubble shows the sort value and the country, covering every dive the list shows, not only the loaded pages.

**Architecture:** A light repository query returns one small row per dive in exactly the list's order; a provider refreshes it whenever the paginated list reloads. Pure functions turn those rows into slots (collapsed trips fold to one slot), bubble labels and markers. A generic `ListScrubber` widget draws thumb, track, markers and bubble over any scroll view; a dive-specific `DiveListScrubber` wires it to the list, loading through a far target with one query (`loadThrough`) and landing on it with the keyboard navigator's existing reveal logic.

**Tech Stack:** Flutter, Riverpod (StateNotifier / FutureProvider), Drift custom SQL, intl `DateFormat`, flutter_test.

**Spec:** `docs/design/specs/2026-10-18-dive-list-scrubber-design.md`

## Global Constraints

- Branch: `feature-request-3456-dive-list-scrubber` in the main checkout (no worktree). Stage explicit paths only; the main checkout holds unrelated uncommitted files (`pubspec.lock` files, a submodule, `docs/superpowers/`, `.widget_preview/`, `test/dives/sanfran.ssrf`) that must never be staged.
- TDD: every task writes its failing test first.
- Anything showing a depth goes through `UnitFormatter` built from `settingsProvider`, so it follows the diver's unit settings.
- New strings go into all 11 ARB files under `lib/l10n/arb/` (ar, de, en, es, fr, he, hu, it, nl, pt, zh) in alphabetical key position, then `flutter gen-l10n`; generated files are committed.
- Code comments sparse: no rationale blocks in code; that belongs in the commit message.
- No emojis in code or docs. The star in rating labels is the text character `★` (U+2605), not an emoji.
- `dart format` on every touched Dart file before each commit.
- No commit or PR text may mention Claude, Claude Code or Anthropic; no `Co-Authored-By` trailer.
- Files stay under 800 lines; do not grow `dive_list_content.dart` beyond the small wiring in Task 9.
- Known Windows-only failure on `main`: `test/helpers/proxy_fakes_hang_up_test.dart`. It is not caused by this work; ignore it when it is the only failure.

## Review Focus

1. **The list reloads between scrubbing and landing** (sort change, sync tick, delete): the dropped target may no longer exist. Expect the list to stay where it is, no exception. Pinned in Task 2 (`loadThrough` returns false for a vanished id) and Task 9 (no reveal when `loadThrough` returns false).
2. **Dives with missing data**: no site, a site without a country, no dive number, no depth, no bottom time, no rating. Expect a sensible bubble ("Unknown Site", "--", "Unrated", no " · country") and no crash. Pinned in Task 5.
3. **Dropping on the very last dive of a large log**: one query must load everything through the end and leave `hasMore` false so no spinner row lingers. Pinned in Task 2.
4. **The index shrinks while the thumb is held** (a filter tick lands mid-drag): the held slot must be clamped, never index past the end. Pinned in Task 7.
5. **Landing inside a collapsed trip**: the list must land on the trip's pinned header without expanding it. Pinned in Task 9.

## As built

The tasks below are the plan as written; the spec describes the final design. Each line is a material departure, with its reason. Sources: the SDD ledger's rulings, the final review (C, I, M and R items), the user's decisions in the follow-up rounds, and the code review fixes R1-R10 (a bare R number below means one of these).

- **A1. Final review fixes.** The thumb rebuilds on every scroll tick so it follows ordinary scrolling (C1); the native scrollbar is hidden while the scrubber is wanted (I3); thumb and overlay mirror in RTL (M1); the thumb gets a 48 by 48 px touch target (M3); `DiveListScrubber` caches slots and markers (M4); the index reads the trip id through the `trips` join as the list does (M5); a page load queued behind `loadThrough` keeps its spinner (final review R1); one query is pinned by a test (final review R2).
- **A2. Panel while active.** The user found labels drawn over the cards ugly and chose a panel shown only while active (hovered, dragged or busy); idle shows just the thumb. The panel then became square with per-label backings (follow-up 2, U2) at 70% opacity (follow-up 5, D3), replacing the plan's marker pills (final review M2).
- **A3. No bubble, no country.** The user asked for the sort value alone: `siteCountry` and `diveLog_scrubber_bubble` are gone (follow-up 2, U1). The floating bubble was then replaced by a value band inside the panel (follow-up 5, D2); `diveScrubberBubble` became `diveScrubberValue` and `bubbleKey` became `currentValueKey`.
- **A4. Fixed panel, sticking-out band.** Follow-up 5 widened the panel to fit long values; the user rejected that, so the panel stays 64 px and only the band sticks out as a tab, up to 160 px and host width minus 16 (follow-up 6). The band then took the panel's colour and the value a bold marker style (follow-up 6b).
- **A5. Scrollbar-themed thumb.** The planned 36 by 48 px handle with an `unfold_more` icon, which the redesign kept while active, became a slim pill (user, follow-up 5, D1) whose thickness, colour, radius and edge gap come from `ScrollbarTheme` with Material's per-platform defaults (`ListScrubberThumbStyle`, thumb theme report). Length and hit area stay 48 px.
- **A6. Axis-tick markers.** The user saw markers one bucket off in descending order, so a marker now sits at its bucket's first slot ascending and its last slot descending, and the direction joins the marker cache key (markers fix, 0e8b1e5 before the rebase).
- **A7. Date preference.** The date value and month markers follow the diver's date-format preference instead of `DateFormat` by locale (redesign report; follow-up review Important: preference in the cache key). New `UnitFormatter.formatMonthOnly` gives numeric months under numeric preferences (follow-up 2, R4; follow-up 4, M5). The earliest month of each year carries the year (final review R4, then markers fix), a repeated month only once (follow-up 2, R6), and the unused `locale` parameter is gone (follow-up 2, R5).
- **A8. Marker hiding and thinning.** Markers level with the thumb are hidden; thinning runs once per marker set, and a marker freed by a hidden one returns only if it keeps its spacing, so markers away from the thumb never move (follow-up 2, R2; follow-up 4, M1). The panel caches the result per covered set (perf fix P2).
- **A9. Selected-dive dot.** Added at the user's request: a `primary` dot at the selected or highlighted dive's slot, also shown while idle (follow-up 7).
- **A10. Favourite ticks.** Follow-up 7's density bars for every sort were dropped for favourite ticks (user): the index and slots carry `isFavorite`, `ListScrubber` gains `highlightTicks`, and the dive card's heart and the ticks share the new `AppColors.favorite` (favourites report).
- **A11. Per-sort details.** The user chose one detail for three sorts, painted in a context column (`ScrubberSegment`, `ScrubberTick`): trip stripes in date sort with the trip name on the value (`tripName`, `diveLog_scrubber_valueWithTrip`), and gap ticks in dive-number sort (follow-up 8).
- **A12. Gas ticks instead of depth zones.** The user replaced follow-up 8's depth-zone stripes with ticks per dive in the chart's `GasColors` (follow-up 9). Air gets ticks too, thresholds match the chart (O2 above 22%), and a dive without tanks is unclassified (follow-up 11). Classification goes through `GasMix`, the same getters `GasColors.forMixPercent` now uses (R10).
- **A13. Month bars.** At the user's request, date sort shows a bar per calendar month beside the context column (`ScrubberDensityBin`, `diveScrubberMonthBins`); the panel grows 19 px in date sort so the bars clear the labels, and the bars leave out the value band (follow-up 10).
- **A14. Add-dive button hides.** The user asked for the button to hide while scrubbing (follow-up 3, U3): `ListScrubber.onActiveChanged` feeds `diveListScrubbingProvider`. `DiveListAddFab` watches it so the page does not rebuild (perf fix P1), and implements the new `MasterDetailCreateFab` so the scaffold re-targets it instead of wrapping it in a layer that kept absorbing taps and a create node while hidden; it also drops out of focus (follow-up 4, M2 and M3).
- **A15. Hover and switcher robustness.** A held mouse button sweeping across the strip no longer activates it (follow-up 4, I1); the panel's fade is unkeyed, fixing a duplicate-key crash when active flipped quickly (follow-up 3, X1); a drag whose thumb unmounts is dropped (ruling 4).
- **A16. Stale-index rule.** Ruling 5 accepted an empty index flash after a filter change; R1 first hid the index while it refetched, which cut off drags on every sync tick. Final rule: the provider returns `DiveScrubberIndex` with the diver, filter and sort it was built for, the scrubber uses it only when they match, and a same-query refetch keeps the old index, so a drag survives a sync tick.
- **A17. Index cost.** The index is fetched only for lists of 20 dives or more (`diveScrubberMinDives`, R6a), and the gas columns come from one aggregated `LEFT JOIN` on `dive_tanks` instead of two correlated subqueries (R6b).
- **A18. Profile batcher.** The plan preloaded profiles for every added row; the final review's chunked preload (I2, ruling 9) was replaced by R7: a jump preloads only its last 100 rows, and cards without a cached profile request it from `DiveProfileBatcher`, which batches one frame's requests into one deduplicated fetch.
- **A19. Other review fixes.** Overlapping drops: only the latest clears the busy state and lands, `_loading` resets in `finally`, load errors are logged (R2). A drag overshoot is clamped (R3). Site initials fold ASCII only, like `COLLATE NOCASE` (R4). The pinned trip header was checked by a test and needed no change (R5). `DiveScrubberEntry.copyWith` (R9). R8 (a far jump keeps every row loaded and silent reloads re-read them) was deliberately not done, at the user's request.
- **A20. History.** The branch was squashed into 10 self-contained commits: the units month format, the index query, `loadThrough`, the index provider, the generic list scrubber, `revealRow`, the master-detail create button, labels, slots and per-sort details, the dive list wiring, and this docs commit. Later fixes went in as fixups to those commits.

---

### Task 1: Scrubber index entity and repository query

> As built: the entry drops `siteCountry` and gains `tripName`, `isFavorite`, `gas` and `copyWith`; the query joins `trips` and aggregated `dive_tanks`. See A1, A3, A10 to A12, A17 and A19.

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_scrubber_entry.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add a method right after `getOrderedDiveIds`, around line 2775)
- Test: `test/features/dive_log/data/repositories/dive_scrubber_index_test.dart`

**Interfaces:**
- Produces: `class DiveScrubberEntry` with fields `id`, `tripId`, `sortTimestamp`, `diveNumber`, `siteName`, `siteCountry`, `maxDepth`, `bottomTime`, `rating` and getter `DateTime get dateTime`.
- Produces: `Future<List<DiveScrubberEntry>> DiveRepository.getDiveScrubberIndex({String? diverId, DiveFilterState filter = const DiveFilterState(), SortState<DiveSortField>? sort})`.

- [ ] **Step 1: Write the entity**

```dart
import 'package:equatable/equatable.dart';

/// One dive in the scrubber index: just what the scrubber's bubble and
/// markers read, in list order.
class DiveScrubberEntry extends Equatable {
  const DiveScrubberEntry({
    required this.id,
    required this.sortTimestamp,
    this.tripId,
    this.diveNumber,
    this.siteName,
    this.siteCountry,
    this.maxDepth,
    this.bottomTime,
    this.rating,
  });

  final String id;
  final String? tripId;

  /// Entry time, or dive time when there is none, as a wall clock in epoch
  /// milliseconds flagged UTC, like `DiveSummary.sortTimestamp`.
  final int sortTimestamp;
  final int? diveNumber;
  final String? siteName;
  final String? siteCountry;
  final double? maxDepth;
  final Duration? bottomTime;
  final int? rating;

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(sortTimestamp, isUtc: true);

  @override
  List<Object?> get props => [
    id,
    tripId,
    sortTimestamp,
    diveNumber,
    siteName,
    siteCountry,
    maxDepth,
    bottomTime,
    rating,
  ];
}
```

- [ ] **Step 2: Write the failing repository test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id, String name, String? country) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: name,
            country: Value(country),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    required int at,
    int? number,
    String? siteId,
    double? depth,
    int? bottomSeconds,
    int? rating,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            diveNumber: Value(number),
            siteId: Value(siteId),
            maxDepth: Value(depth),
            bottomTime: Value(bottomSeconds),
            rating: Value(rating),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  }

  Future<void> seed() async {
    await insertSite('s1', 'Blue Hole', 'Egypt');
    await insertSite('s2', 'arch', null);
    // Ties on every sort value, so the tiebreakers decide the order.
    await insertDive('a', at: 1000, number: 1, siteId: 's1', depth: 30, bottomSeconds: 2400, rating: 4);
    await insertDive('b', at: 1000, number: 1, siteId: 's2', depth: 30, bottomSeconds: 2400, rating: 4);
    await insertDive('c', at: 3000, number: 3, siteId: 's1', depth: 12, bottomSeconds: 3600, rating: 5);
    await insertDive('d', at: 2000, number: 2, depth: 45, rating: null);
    await insertDive('e', at: 2000, number: 7, siteId: 's2', depth: 18, bottomSeconds: 1800, rating: 2);
  }

  test('matches getDiveSummaries order for every sort and direction', () async {
    await seed();
    const filter = DiveFilterState(minDepth: 15);
    for (final field in DiveSortField.values) {
      for (final direction in SortDirection.values) {
        final sort = SortState(field: field, direction: direction);
        final index = await repository.getDiveScrubberIndex(
          filter: filter,
          sort: sort,
        );
        final summaries = await repository.getDiveSummaries(
          filter: filter,
          sort: sort,
          limit: 1000,
        );
        expect(
          index.map((e) => e.id).toList(),
          summaries.map((s) => s.id).toList(),
          reason: '$field $direction',
        );
      }
    }
  });

  test('carries the values the scrubber labels read', () async {
    await seed();
    final index = await repository.getDiveScrubberIndex(
      sort: const SortState(field: DiveSortField.date),
    );
    final c = index.firstWhere((e) => e.id == 'c');
    expect(c.siteName, 'Blue Hole');
    expect(c.siteCountry, 'Egypt');
    expect(c.diveNumber, 3);
    expect(c.maxDepth, 12);
    expect(c.bottomTime, const Duration(minutes: 60));
    expect(c.rating, 5);
    expect(c.sortTimestamp, 3000);

    final d = index.firstWhere((e) => e.id == 'd');
    expect(d.siteName, isNull);
    expect(d.siteCountry, isNull);
    expect(d.bottomTime, isNull);
    expect(d.rating, isNull);
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_scrubber_index_test.dart`
Expected: compile error, `getDiveScrubberIndex` is not defined.

- [ ] **Step 4: Implement the query** (import `dive_scrubber_entry.dart` at the top of the repository)

```dart
  /// One [DiveScrubberEntry] per dive [filter] keeps, in [sort] order: the
  /// order of [getDiveSummaries], unpaginated and with only the columns the
  /// list scrubber reads.
  // stats-scope-exempt: backs the dive list scrubber over the displayed list
  Future<List<DiveScrubberEntry>> getDiveScrubberIndex({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async {
    try {
      return await PerfTimer.measure('getDiveScrubberIndex', () async {
        final whereClauses = <String>[];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        final compiled = compileDiveFilter(filter, rootAlias: 'd');
        _buildFilterWhereClauses(compiled, whereClauses, args);

        final whereClause = whereClauses.isNotEmpty
            ? 'WHERE ${whereClauses.join(' AND ')}'
            : '';

        final sql =
            'SELECT d.id, d.trip_id, d.dive_number, d.max_depth, '
            'd.bottom_time, d.rating, '
            'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, '
            's.name AS site_name, s.country AS site_country '
            'FROM dives d '
            'LEFT JOIN dive_sites s ON d.site_id = s.id '
            '$whereClause '
            'ORDER BY ${_buildSortOrderBy(sort)}';

        final rows = await _db
            .customSelect(
              sql,
              variables: args,
              readsFrom: {
                _db.dives,
                _db.diveSites,
                ...tablesNamed(compiled.tablesTouched),
              },
            )
            .get();

        return [
          for (final row in rows)
            DiveScrubberEntry(
              id: row.read<String>('id'),
              tripId: row.readNullable<String>('trip_id'),
              sortTimestamp: row.read<int>('sort_timestamp'),
              diveNumber: row.readNullable<int>('dive_number'),
              siteName: row.readNullable<String>('site_name'),
              siteCountry: row.readNullable<String>('site_country'),
              maxDepth: row.readNullable<double>('max_depth'),
              bottomTime: switch (row.readNullable<int>('bottom_time')) {
                final s? => Duration(seconds: s),
                null => null,
              },
              rating: row.readNullable<int>('rating'),
            ),
        ];
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive scrubber index',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: Run the test to confirm it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_scrubber_index_test.dart`
Expected: All tests passed. If a repository-wide census test (for example one scanning for `stats-scope-exempt`) fails, run `flutter test test/architecture` and satisfy it the way `getOrderedDiveIds` does.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log/domain/entities/dive_scrubber_entry.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_scrubber_index_test.dart
git add lib/features/dive_log/domain/entities/dive_scrubber_entry.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_scrubber_index_test.dart
git commit -m "feat(dive-log): scrubber index query in list order (#3456)"
```

---

### Task 2: List revision and `loadThrough` on the paginated list

> As built: a jump keeps a queued page load's spinner and preloads profiles for its last 100 rows only, through `DiveProfileBatcher`. See A1 and A18.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart` (`PaginatedDiveListState`, line ~272)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (`PaginatedDiveListNotifier`, lines ~738-1130)
- Test: `test/features/dive_log/presentation/providers/paginated_dive_list_load_through_test.dart`

**Interfaces:**
- Produces: `int PaginatedDiveListState.revision` (default `0`), bumped by every first-page load and every silent reload of loaded pages, never by `loadNextPage` or `loadThrough`.
- Produces: `Future<bool> PaginatedDiveListNotifier.loadThrough(String diveId, {required int targetIndex})`; `targetIndex` is the dive's position in list order (its index in the scrubber index). Returns whether `diveId` is loaded afterwards.

- [ ] **Step 1: Write the failing test**

Copy the setup helpers (`makeContainer`, `setUpCurrentDiver`, `seedDives`, `loadPages`, the `_pageSize = 50` constant and the imports) from `test/features/dive_log/presentation/providers/paginated_dive_list_page_retention_test.dart` lines 1-25 and 157-226, then:

```dart
  group('PaginatedDiveListNotifier.loadThrough', () {
    test('loads through a far target in one query', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 180);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);

      final target = dives[130];
      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(target.id, targetIndex: 130);

      expect(loaded, isTrue);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives.map((d) => d.id), contains(target.id));
      expect(state.dives.length, greaterThanOrEqualTo(131));
      expect(state.hasMore, isTrue);
    });

    test('dropping on the last dive loads everything and ends paging', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 260);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(dives.last.id, targetIndex: 259);

      expect(loaded, isTrue);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives, hasLength(260));
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test('reports false and keeps the rows when the target is gone', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, 120);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await loadPages(container, 1);

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough('no-such-dive', targetIndex: 90);

      expect(loaded, isFalse);
      final after = container.read(paginatedDiveListProvider).value!;
      expect(after.dives.take(before.dives.length), before.dives);
    });

    test('revision bumps on reloads, not on page loads', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 120);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      final first = await loadPages(container, 1);
      expect(first.revision, greaterThan(0));

      final notifier = container.read(paginatedDiveListProvider.notifier);
      await notifier.loadNextPage();
      expect(container.read(paginatedDiveListProvider).value!.revision,
          first.revision);

      await notifier.loadThrough(dives[110].id, targetIndex: 110);
      expect(container.read(paginatedDiveListProvider).value!.revision,
          first.revision);

      await notifier.reloadLoadedPages();
      expect(container.read(paginatedDiveListProvider).value!.revision,
          greaterThan(first.revision));
    });
  });
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/presentation/providers/paginated_dive_list_load_through_test.dart`
Expected: compile errors, `loadThrough` and `revision` are not defined.

- [ ] **Step 3: Add `revision` to `PaginatedDiveListState`**

Add the field `final int revision;` with doc `/// Bumped each time the rows are reloaded from the top, not when a page is appended.`, constructor parameter `this.revision = 0`, `int? revision` in `copyWith` passed as `revision: revision ?? this.revision`, and `revision` in `props`.

- [ ] **Step 4: Bump it in the notifier**

In `PaginatedDiveListNotifier` add the field `int _revision = 0;`. In `_loadFirstPage`, pass `revision: ++_revision` to the `PaginatedDiveListState(...)` it builds. In `_silentReloadLoadedPagesNow`, pass `revision: ++_revision` to the state it writes (constructor or `copyWith`, whichever that method uses).

- [ ] **Step 5: Split `_loadNextPage` and add `loadThrough`**

Replace `_loadNextPage` with a guard that delegates to a shared append, and add `loadThrough`:

```dart
  Future<void> _loadNextPage() async {
    if (!mounted) return;
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.hasMore) {
      if (current.isLoadingMore) {
        state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      }
      return;
    }
    await _appendRows(current, limit: _pageSize);
  }

  /// Loads every row from the end of the list through the dive at
  /// [targetIndex] of the list order in one query, and reports whether
  /// [diveId] is loaded afterwards.
  Future<bool> loadThrough(String diveId, {required int targetIndex}) async {
    await _enqueuePaging(() async {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current == null || !current.hasMore) return;
      if (current.dives.any((d) => d.id == diveId)) return;
      final missing = targetIndex + 1 - current.dives.length;
      if (missing <= 0) return;
      await _appendRows(current, limit: missing + _pageSize);
    });
    return state.valueOrNull?.dives.any((d) => d.id == diveId) ?? false;
  }

  Future<void> _appendRows(
    PaginatedDiveListState current, {
    required int limit,
  }) async {
    try {
      final filter = _ref.read(diveFilterProvider);
      final sort = _ref.read(diveSortProvider);
      final newDives = await _repository.getDiveSummaries(
        diverId: _currentDiverId,
        filter: filter,
        sort: sort,
        cursor: _isDateSort ? current.nextCursor : null,
        offset: _isDateSort ? null : _currentOffset,
        limit: limit,
        disabledSafetyRules: _ref.read(safetyReviewDisabledRulesProvider),
      );
      _currentOffset += newDives.length;

      final loadedIds = current.dives.map((d) => d.id).toSet();
      final added = newDives
          .where((d) => !loadedIds.contains(d.id))
          .toList(growable: false);

      if (!mounted) return;
      state = AsyncValue.data(
        current.copyWith(
          dives: [...current.dives, ...added],
          isLoadingMore: false,
          hasMore: newDives.length >= limit,
          nextCursor: _isDateSort ? _cursorFromLastDive(newDives) : null,
          loadMoreFailed: false,
        ),
      );
      _loadBatchProfiles(added.map((d) => d.id).toList());
    } catch (_) {
      if (mounted) {
        state = AsyncValue.data(
          current.copyWith(isLoadingMore: false, loadMoreFailed: true),
        );
      }
    }
  }
```

Keep the existing explanatory comments of `_loadNextPage` (the dedupe-by-id and the #1610 failure note) on the moved lines in `_appendRows`.

- [ ] **Step 6: Run the new test and the existing notifier tests**

Run: `flutter test test/features/dive_log/presentation/providers/`
Expected: All tests passed.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_log/domain/entities/dive_summary.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/paginated_dive_list_load_through_test.dart
git add lib/features/dive_log/domain/entities/dive_summary.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/paginated_dive_list_load_through_test.dart
git commit -m "feat(dive-log): load the dive list through a far target in one query (#3456)"
```

---

### Task 3: Scrubber index provider

> As built: the provider returns a `DiveScrubberIndex` tagged with its inputs and is gated at 20 dives. See A16 and A17.

**Files:**
- Create: `lib/features/dive_log/presentation/providers/dive_scrubber_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_scrubber_index_provider_test.dart`

**Interfaces:**
- Consumes: `getDiveScrubberIndex` (Task 1), `PaginatedDiveListState.revision` (Task 2).
- Produces: `final diveScrubberIndexProvider = FutureProvider.autoDispose<List<DiveScrubberEntry>>(...)`.

- [ ] **Step 1: Write the failing test** (same helpers as Task 2's test file: copy `makeContainer`, `setUpCurrentDiver`, `seedDives`, `loadPages` and imports)

```dart
  test('holds every dive in list order and follows a filter change', () async {
    final diver = await setUpCurrentDiver();
    await seedDives(diver.id, 120);
    final container = makeContainer();
    addTearDown(container.dispose);
    final listSub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(listSub.close);
    final indexSub = container.listen(diveScrubberIndexProvider, (_, _) {});
    addTearDown(indexSub.close);

    final page = await loadPages(container, 1);
    final index = await container.read(diveScrubberIndexProvider.future);
    expect(index, hasLength(120));
    expect(
      index.take(page.dives.length).map((e) => e.id),
      page.dives.map((d) => d.id),
    );

    container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(minDepth: 1000);
    await loadPages(container, 1);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(diveScrubberIndexProvider.future), isEmpty);
  });
```

If `diveFilterProvider` is not a `StateProvider`, set the filter the way `test/features/dive_log/presentation/providers/paginated_dive_list_quiet_search_test.dart` does.

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/presentation/providers/dive_scrubber_index_provider_test.dart`
Expected: compile error, `diveScrubberIndexProvider` is not defined.

- [ ] **Step 3: Implement the provider**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Every dive the dive list shows, in its order, for the list scrubber.
///
/// Refetched whenever the list reloads from the top, which already covers
/// diver, filter and sort changes and the list's table ticks.
final diveScrubberIndexProvider =
    FutureProvider.autoDispose<List<DiveScrubberEntry>>((ref) async {
      final revision = ref.watch(
        paginatedDiveListProvider.select((s) => s.valueOrNull?.revision),
      );
      if (revision == null) return const [];
      return ref
          .read(diveRepositoryProvider)
          .getDiveScrubberIndex(
            diverId: ref.read(currentDiverIdProvider),
            filter: ref.read(diveFilterProvider),
            sort: ref.read(diveSortProvider),
          );
    });
```

Check the import paths with the analyzer: `diveFilterProvider` and `diveSortProvider` may live in a different providers file; use the files `dive_providers.dart` imports them from.

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/features/dive_log/presentation/providers/dive_scrubber_index_provider_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation/providers/dive_scrubber_providers.dart test/features/dive_log/presentation/providers/dive_scrubber_index_provider_test.dart
git add lib/features/dive_log/presentation/providers/dive_scrubber_providers.dart test/features/dive_log/presentation/providers/dive_scrubber_index_provider_test.dart
git commit -m "feat(dive-log): scrubber index provider following the list (#3456)"
```

---

### Task 4: Scrubber slots

**Files:**
- Create: `lib/features/dive_log/presentation/helpers/dive_scrubber_slots.dart`
- Test: `test/features/dive_log/presentation/helpers/dive_scrubber_slots_test.dart`

**Interfaces:**
- Consumes: `DiveScrubberEntry` (Task 1).
- Produces: `class DiveScrubberSlot { DiveScrubberEntry entry; int entryIndex; String? collapsedTripId; }` and `List<DiveScrubberSlot> buildDiveScrubberSlots({required List<DiveScrubberEntry> entries, required bool groupingEnabled, required Set<String> collapsedTripIds})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';

DiveScrubberEntry e(String id, [String? trip]) =>
    DiveScrubberEntry(id: id, sortTimestamp: 0, tripId: trip);

void main() {
  final entries = [e('a'), e('b', 't1'), e('c', 't1'), e('d'), e('f', 't1')];

  test('one slot per dive without grouping', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: false,
      collapsedTripIds: {'t1'},
    );
    expect(slots.map((s) => s.entry.id), ['a', 'b', 'c', 'd', 'f']);
    expect(slots.every((s) => s.collapsedTripId == null), isTrue);
  });

  test('a collapsed trip run folds into one slot', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: true,
      collapsedTripIds: {'t1'},
    );
    expect(slots.map((s) => s.entry.id), ['a', 'b', 'd', 'f']);
    expect(slots.map((s) => s.entryIndex), [0, 1, 3, 4]);
    expect(slots[1].collapsedTripId, 't1');
    expect(slots[3].collapsedTripId, 't1');
  });

  test('an expanded trip keeps a slot per dive', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: true,
      collapsedTripIds: const {},
    );
    expect(slots, hasLength(5));
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_scrubber_slots_test.dart`
Expected: compile error, `buildDiveScrubberSlots` is not defined.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';

/// One position on the scrubber track: a dive, or a collapsed trip run.
class DiveScrubberSlot {
  const DiveScrubberSlot({
    required this.entry,
    required this.entryIndex,
    this.collapsedTripId,
  });

  /// The slot's first dive.
  final DiveScrubberEntry entry;

  /// [entry]'s position in list order.
  final int entryIndex;

  /// Set when the slot stands for a collapsed trip's run of dives.
  final String? collapsedTripId;
}

/// Runs of the same trip are consecutive dives, as in `buildDiveListSections`.
List<DiveScrubberSlot> buildDiveScrubberSlots({
  required List<DiveScrubberEntry> entries,
  required bool groupingEnabled,
  required Set<String> collapsedTripIds,
}) {
  final slots = <DiveScrubberSlot>[];
  for (var i = 0; i < entries.length; i++) {
    final trip = entries[i].tripId;
    final folded =
        groupingEnabled && trip != null && collapsedTripIds.contains(trip);
    if (folded && i > 0 && entries[i - 1].tripId == trip) continue;
    slots.add(
      DiveScrubberSlot(
        entry: entries[i],
        entryIndex: i,
        collapsedTripId: folded ? trip : null,
      ),
    );
  }
  return slots;
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_scrubber_slots_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation/helpers/dive_scrubber_slots.dart test/features/dive_log/presentation/helpers/dive_scrubber_slots_test.dart
git add lib/features/dive_log/presentation/helpers/dive_scrubber_slots.dart test/features/dive_log/presentation/helpers/dive_scrubber_slots_test.dart
git commit -m "feat(dive-log): scrubber slots fold collapsed trips (#3456)"
```

---

### Task 5: Scrubber marker type, bubble labels, markers and strings

> As built: superseded in part. No bubble or country, markers at bucket boundaries in both directions, dates in the diver's preference. See A3, A6, A7 and A19.

**Files:**
- Create: `lib/shared/widgets/list_scrubber/scrubber_marker.dart`
- Create: `lib/features/dive_log/presentation/helpers/dive_scrubber_labels.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/dive_log/presentation/helpers/dive_scrubber_labels_test.dart`

**Interfaces:**
- Consumes: `DiveScrubberEntry` (Task 1), `DiveScrubberSlot` (Task 4).
- Produces: `class ScrubberMarker { int slot; String label; }` (Equatable).
- Produces: `String diveScrubberBubble(DiveScrubberEntry entry, DiveSortField field, {required UnitFormatter units, required AppLocalizations l10n, required String locale})`.
- Produces: `List<ScrubberMarker> diveScrubberMarkers(List<DiveScrubberSlot> slots, DiveSortField field, {required UnitFormatter units, required AppLocalizations l10n, required String locale})`.
- Produces: l10n keys `diveLog_scrubber_bubble(String value, String country)` and `diveLog_scrubber_unrated`.

- [ ] **Step 1: Add the strings**

In `app_en.arb`, at the alphabetical position for `diveLog_scrubber_*`:

```json
  "diveLog_scrubber_bubble": "{value} · {country}",
  "@diveLog_scrubber_bubble": {"description": "The dive list scrubber's bubble: the sort value at the thumb (a month, depth, site...) and the country of that dive's site", "placeholders": {"value": {"type": "String"}, "country": {"type": "String"}}},
  "diveLog_scrubber_unrated": "Unrated",
```

In the other ten files, add `diveLog_scrubber_bubble` with the same value `"{value} · {country}"` and `diveLog_scrubber_unrated` with:
ar `غير مقيّم`, de `Unbewertet`, es `Sin valorar`, fr `Non noté`, he `ללא דירוג`, hu `Nem értékelt`, it `Non valutato`, nl `Niet beoordeeld`, pt `Sem avaliação`, zh `未评分`.

Run: `flutter gen-l10n`
Then run: `flutter test test/l10n`
If `untranslated_english_values_test.dart` flags `diveLog_scrubber_bubble` (identical in every locale on purpose), add the key to `test/l10n/kept_english_values.dart` the way existing entries are listed there.

- [ ] **Step 2: Write the marker type**

```dart
import 'package:equatable/equatable.dart';

/// A label drawn on the scrubber track at [slot].
class ScrubberMarker extends Equatable {
  const ScrubberMarker({required this.slot, required this.label});

  final int slot;
  final String label;

  @override
  List<Object?> get props => [slot, label];
}
```

- [ ] **Step 3: Write the failing label test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_labels.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final metric = UnitFormatter(const AppSettings());
  final imperial = UnitFormatter(const AppSettings(depthUnit: DepthUnit.feet));

  int at(int y, int m) => DateTime.utc(y, m, 10).millisecondsSinceEpoch;

  DiveScrubberEntry dive({
    int ts = 0,
    int? number,
    String? site,
    String? country,
    double? depth,
    int? minutes,
    int? rating,
  }) => DiveScrubberEntry(
    id: 'x',
    sortTimestamp: ts,
    diveNumber: number,
    siteName: site,
    siteCountry: country,
    maxDepth: depth,
    bottomTime: minutes == null ? null : Duration(minutes: minutes),
    rating: rating,
  );

  String bubble(DiveScrubberEntry e, DiveSortField f, [UnitFormatter? u]) =>
      diveScrubberBubble(e, f, units: u ?? metric, l10n: l10n, locale: 'en');

  List<DiveScrubberSlot> slotsOf(List<DiveScrubberEntry> entries) => [
    for (final (i, e) in entries.indexed)
      DiveScrubberSlot(entry: e, entryIndex: i),
  ];

  group('bubble', () {
    test('sort value and country for every sort', () {
      final d = dive(
        ts: at(2024, 3),
        number: 412,
        site: 'Blue Hole',
        country: 'Egypt',
        depth: 32,
        minutes: 48,
        rating: 4,
      );
      expect(bubble(d, DiveSortField.date), 'Mar 2024 · Egypt');
      expect(bubble(d, DiveSortField.diveNumber), '#412 · Egypt');
      expect(bubble(d, DiveSortField.site), 'Blue Hole · Egypt');
      expect(bubble(d, DiveSortField.depth), '32m · Egypt');
      expect(bubble(d, DiveSortField.bottomTime), '48 min · Egypt');
      expect(bubble(d, DiveSortField.rating), '4★ · Egypt');
    });

    test('depth follows the diver unit', () {
      expect(
        bubble(dive(depth: 30), DiveSortField.depth, imperial),
        '98ft',
      );
    });

    test('missing values fall back without a country suffix', () {
      final d = dive(country: '  ');
      expect(bubble(d, DiveSortField.site), 'Unknown Site');
      expect(bubble(d, DiveSortField.diveNumber), '--');
      expect(bubble(d, DiveSortField.depth), '--');
      expect(bubble(d, DiveSortField.bottomTime), '--');
      expect(bubble(d, DiveSortField.rating), 'Unrated');
    });
  });

  group('markers', () {
    List<ScrubberMarker> markers(
      List<DiveScrubberEntry> entries,
      DiveSortField field, [
      UnitFormatter? units,
    ]) => diveScrubberMarkers(
      slotsOf(entries),
      field,
      units: units ?? metric,
      l10n: l10n,
      locale: 'en',
    );

    test('years for a long date span, at the first slot of each', () {
      final entries = [
        dive(ts: at(2025, 6)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2023, 9)),
      ];
      expect(markers(entries, DiveSortField.date), const [
        ScrubberMarker(slot: 0, label: '2025'),
        ScrubberMarker(slot: 2, label: '2023'),
      ]);
    });

    test('months when the dives span two calendar years or fewer', () {
      final entries = [
        dive(ts: at(2025, 2)),
        dive(ts: at(2025, 2)),
        dive(ts: at(2024, 11)),
      ];
      expect(markers(entries, DiveSortField.date), const [
        ScrubberMarker(slot: 0, label: 'Feb'),
        ScrubberMarker(slot: 2, label: 'Nov'),
      ]);
    });

    test('dive numbers in steps sized to the range', () {
      final entries = [for (var n = 300; n > 0; n -= 25) dive(number: n)];
      final labels = markers(entries, DiveSortField.diveNumber)
          .map((m) => m.label);
      expect(labels, ['300', '250', '200', '150', '100', '50', '0']);
    });

    test('first letters for sites, skipping unnamed ones', () {
      final entries = [
        dive(site: 'arch'),
        dive(site: 'Anemone'),
        dive(),
        dive(site: 'Blue Hole'),
      ];
      expect(markers(entries, DiveSortField.site), const [
        ScrubberMarker(slot: 0, label: 'A'),
        ScrubberMarker(slot: 3, label: 'B'),
      ]);
    });

    test('depth steps in feet', () {
      final entries = [dive(depth: 40), dive(depth: 33), dive(depth: 20)];
      expect(
        markers(entries, DiveSortField.depth, imperial).map((m) => m.label),
        ['120ft', '100ft', '60ft'],
      );
    });

    test('bottom time steps', () {
      final entries = [dive(minutes: 55), dive(minutes: 41), dive(minutes: 12)];
      expect(
        markers(entries, DiveSortField.bottomTime).map((m) => m.label),
        ['50 min', '40 min', '10 min'],
      );
    });

    test('ratings with unrated', () {
      final entries = [dive(rating: 5), dive(rating: 5), dive()];
      expect(markers(entries, DiveSortField.rating), const [
        ScrubberMarker(slot: 0, label: '5★'),
        ScrubberMarker(slot: 2, label: 'Unrated'),
      ]);
    });

    test('no slots, no markers', () {
      expect(markers(const [], DiveSortField.date), isEmpty);
    });
  });
}
```

Notes for the expected values: 30 m is 98.4 ft, formatted with 0 decimals as `98ft`. Feet depths 40/33/20 m are 131/108/66 ft; the range is 65 ft so the step is 20 ft, giving buckets 120, 100, 60. Bottom times 55/41/12 min span 43 min, so the step is 10. Dive numbers 300..25 span 275, so the step is 50 (300 down to 25 gives buckets 300, 250, ..., 0; 25 lands in bucket 0).

- [ ] **Step 4: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_scrubber_labels_test.dart`
Expected: compile error, `diveScrubberBubble` is not defined.

- [ ] **Step 5: Implement the labels**

```dart
import 'package:characters/characters.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

String diveScrubberBubble(
  DiveScrubberEntry entry,
  DiveSortField field, {
  required UnitFormatter units,
  required AppLocalizations l10n,
  required String locale,
}) {
  final value = _value(entry, field, units, l10n, locale);
  final country = entry.siteCountry?.trim();
  if (country == null || country.isEmpty) return value;
  return l10n.diveLog_scrubber_bubble(value, country);
}

String _value(
  DiveScrubberEntry e,
  DiveSortField field,
  UnitFormatter units,
  AppLocalizations l10n,
  String locale,
) {
  switch (field) {
    case DiveSortField.date:
      return DateFormat.yMMM(locale).format(e.dateTime);
    case DiveSortField.diveNumber:
      return e.diveNumber == null ? '--' : '#${e.diveNumber}';
    case DiveSortField.site:
      return e.siteName ?? l10n.diveLog_listPage_unknownSite;
    case DiveSortField.depth:
      return units.formatDepth(e.maxDepth, decimals: 0);
    case DiveSortField.bottomTime:
      final time = e.bottomTime;
      return time == null ? '--' : l10n.common_elapsed_minutes(time.inMinutes);
    case DiveSortField.rating:
      return _ratingLabel(e.rating, l10n);
  }
}

String _ratingLabel(int? rating, AppLocalizations l10n) =>
    (rating ?? 0) == 0 ? l10n.diveLog_scrubber_unrated : '$rating★';

typedef _Bucket = ({Object key, String label});

/// A marker at the first slot of each bucket of the active sort.
List<ScrubberMarker> diveScrubberMarkers(
  List<DiveScrubberSlot> slots,
  DiveSortField field, {
  required UnitFormatter units,
  required AppLocalizations l10n,
  required String locale,
}) {
  if (slots.isEmpty) return const [];
  final entries = [for (final s in slots) s.entry];
  final bucketOf = _bucketer(entries, field, units, l10n, locale);
  final markers = <ScrubberMarker>[];
  Object? previous;
  for (var i = 0; i < entries.length; i++) {
    final bucket = bucketOf(entries[i]);
    if (bucket == null || bucket.key == previous) continue;
    markers.add(ScrubberMarker(slot: i, label: bucket.label));
    previous = bucket.key;
  }
  return markers;
}

_Bucket? Function(DiveScrubberEntry) _bucketer(
  List<DiveScrubberEntry> entries,
  DiveSortField field,
  UnitFormatter units,
  AppLocalizations l10n,
  String locale,
) {
  switch (field) {
    case DiveSortField.date:
      final years = entries.map((e) => e.dateTime.year);
      final span = years.reduce(_max) - years.reduce(_min);
      if (span <= 1) {
        final month = DateFormat.MMM(locale);
        return (e) => (
          key: e.dateTime.year * 12 + e.dateTime.month,
          label: month.format(e.dateTime),
        );
      }
      return (e) => (key: e.dateTime.year, label: '${e.dateTime.year}');
    case DiveSortField.diveNumber:
      final step = _stepFor(
        entries.map((e) => e.diveNumber?.toDouble()),
        const [(100, 10), (500, 50), (5000, 100)],
        500,
      );
      return (e) => _stepBucket(e.diveNumber?.toDouble(), step, (v) => '$v');
    case DiveSortField.site:
      return (e) {
        final name = e.siteName?.trim();
        if (name == null || name.isEmpty) return null;
        final letter = name.characters.first.toUpperCase();
        return (key: letter, label: letter);
      };
    case DiveSortField.depth:
      final feet = units.settings.depthUnit == DepthUnit.feet;
      double? converted(DiveScrubberEntry e) =>
          e.maxDepth == null ? null : units.convertDepth(e.maxDepth!);
      final step = _stepFor(
        entries.map(converted),
        feet ? const [(60, 10), (200, 20)] : const [(40, 5)],
        feet ? 50 : 10,
      );
      return (e) =>
          _stepBucket(converted(e), step, (v) => '$v${units.depthSymbol}');
    case DiveSortField.bottomTime:
      double? minutes(DiveScrubberEntry e) =>
          e.bottomTime == null ? null : e.bottomTime!.inMinutes.toDouble();
      final step = _stepFor(
        entries.map(minutes),
        const [(60, 10), (120, 15)],
        30,
      );
      return (e) =>
          _stepBucket(minutes(e), step, l10n.common_elapsed_minutes);
    case DiveSortField.rating:
      return (e) =>
          (key: e.rating ?? 0, label: _ratingLabel(e.rating, l10n));
  }
}

int _stepFor(
  Iterable<double?> values,
  List<(num, int)> rangeSteps,
  int fallback,
) {
  final present = values.whereType<double>();
  if (present.isEmpty) return fallback;
  final range = present.reduce(_maxD) - present.reduce(_minD);
  for (final (limit, step) in rangeSteps) {
    if (range <= limit) return step;
  }
  return fallback;
}

_Bucket? _stepBucket(double? value, int step, String Function(int) label) {
  if (value == null) return null;
  final bucket = (value / step).floor();
  return (key: bucket, label: label(bucket * step));
}

int _max(int a, int b) => a > b ? a : b;
int _min(int a, int b) => a < b ? a : b;
double _maxD(double a, double b) => a > b ? a : b;
double _minD(double a, double b) => a < b ? a : b;
```

If `UnitFormatter` does not expose `settings` publicly, read `depthUnit` from the `AppSettings` the caller has instead: add a `required DepthUnit depthUnit` parameter is not needed; check `lib/core/utils/unit_formatter.dart` line 14-20 first (it is constructed as `UnitFormatter(settings)` and `depthSymbol` reads `settings.depthUnit`, so a public `settings` field is expected).

- [ ] **Step 6: Run the tests to confirm they pass**

Run: `flutter test test/features/dive_log/presentation/helpers/dive_scrubber_labels_test.dart test/l10n`
Expected: All tests passed.

- [ ] **Step 7: Commit**

```bash
dart format lib/shared/widgets/list_scrubber/scrubber_marker.dart lib/features/dive_log/presentation/helpers/dive_scrubber_labels.dart test/features/dive_log/presentation/helpers/dive_scrubber_labels_test.dart
git add lib/shared/widgets/list_scrubber/scrubber_marker.dart lib/features/dive_log/presentation/helpers/dive_scrubber_labels.dart test/features/dive_log/presentation/helpers/dive_scrubber_labels_test.dart lib/l10n/arb/
git add test/l10n/kept_english_values.dart  # only if Step 1 changed it
git commit -m "feat(dive-log): scrubber bubble labels and sort markers (#3456)"
```

---

### Task 6: Scrubber geometry

**Files:**
- Create: `lib/shared/widgets/list_scrubber/list_scrubber_geometry.dart`
- Test: `test/shared/widgets/list_scrubber/list_scrubber_geometry_test.dart`

**Interfaces:**
- Consumes: `ScrubberMarker` (Task 5).
- Produces: `int slotForScroll({required double pixels, required double maxScrollExtent, required int loadedSlotCount})`, `double scrollForSlot({required int slot, required double maxScrollExtent, required int loadedSlotCount})`, `int slotForTrack({required double dy, required double trackExtent, required int slotCount})`, `double trackForSlot({required int slot, required double trackExtent, required int slotCount})`, `bool scrubberWanted({required int slotCount, required int loadedSlotCount, required double maxScrollExtent, required double viewportDimension})`, `List<ScrubberMarker> thinMarkers(List<ScrubberMarker> markers, {required int slotCount, required double trackExtent, required double minSpacing})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  test('scroll and slot map onto each other over the loaded rows', () {
    expect(slotForScroll(pixels: 0, maxScrollExtent: 900, loadedSlotCount: 10), 0);
    expect(slotForScroll(pixels: 900, maxScrollExtent: 900, loadedSlotCount: 10), 9);
    expect(slotForScroll(pixels: 450, maxScrollExtent: 900, loadedSlotCount: 11), 5);
    expect(scrollForSlot(slot: 5, maxScrollExtent: 900, loadedSlotCount: 11), 450);
    expect(scrollForSlot(slot: 40, maxScrollExtent: 900, loadedSlotCount: 11), 900);
    expect(slotForScroll(pixels: 10, maxScrollExtent: 0, loadedSlotCount: 11), 0);
  });

  test('track position and slot map onto each other over all slots', () {
    expect(slotForTrack(dy: 0, trackExtent: 500, slotCount: 101), 0);
    expect(slotForTrack(dy: 250, trackExtent: 500, slotCount: 101), 50);
    expect(slotForTrack(dy: 900, trackExtent: 500, slotCount: 101), 100);
    expect(slotForTrack(dy: -20, trackExtent: 500, slotCount: 101), 0);
    expect(trackForSlot(slot: 50, trackExtent: 500, slotCount: 101), 250);
    expect(trackForSlot(slot: 0, trackExtent: 500, slotCount: 1), 0);
  });

  test('wanted only past three viewports of estimated content', () {
    // 10 loaded rows fill 1.5 viewports; 30 slots in all estimate 4.5.
    expect(
      scrubberWanted(slotCount: 30, loadedSlotCount: 10, maxScrollExtent: 300, viewportDimension: 600),
      isTrue,
    );
    expect(
      scrubberWanted(slotCount: 10, loadedSlotCount: 10, maxScrollExtent: 300, viewportDimension: 600),
      isFalse,
    );
    expect(
      scrubberWanted(slotCount: 0, loadedSlotCount: 0, maxScrollExtent: 0, viewportDimension: 600),
      isFalse,
    );
  });

  test('thinning keeps markers at least minSpacing apart', () {
    const markers = [
      ScrubberMarker(slot: 0, label: 'a'),
      ScrubberMarker(slot: 1, label: 'b'),
      ScrubberMarker(slot: 10, label: 'c'),
      ScrubberMarker(slot: 11, label: 'd'),
      ScrubberMarker(slot: 100, label: 'e'),
    ];
    final kept = thinMarkers(markers, slotCount: 101, trackExtent: 500, minSpacing: 28);
    expect(kept.map((m) => m.label), ['a', 'c', 'e']);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/shared/widgets/list_scrubber/list_scrubber_geometry_test.dart`
Expected: compile error, functions not defined.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

int slotForScroll({
  required double pixels,
  required double maxScrollExtent,
  required int loadedSlotCount,
}) {
  if (loadedSlotCount <= 1 || maxScrollExtent <= 0) return 0;
  final share = (pixels / maxScrollExtent).clamp(0.0, 1.0);
  return (share * (loadedSlotCount - 1)).round();
}

double scrollForSlot({
  required int slot,
  required double maxScrollExtent,
  required int loadedSlotCount,
}) {
  if (loadedSlotCount <= 1) return 0;
  final share = (slot / (loadedSlotCount - 1)).clamp(0.0, 1.0);
  return share * maxScrollExtent;
}

int slotForTrack({
  required double dy,
  required double trackExtent,
  required int slotCount,
}) {
  if (slotCount <= 1 || trackExtent <= 0) return 0;
  final share = (dy / trackExtent).clamp(0.0, 1.0);
  return (share * (slotCount - 1)).round();
}

double trackForSlot({
  required int slot,
  required double trackExtent,
  required int slotCount,
}) {
  if (slotCount <= 1) return 0;
  return (slot / (slotCount - 1)).clamp(0.0, 1.0) * trackExtent;
}

/// The loaded rows' height, scaled up to every slot, is over three viewports.
bool scrubberWanted({
  required int slotCount,
  required int loadedSlotCount,
  required double maxScrollExtent,
  required double viewportDimension,
}) {
  if (loadedSlotCount <= 0 || viewportDimension <= 0) return false;
  final loadedExtent = maxScrollExtent + viewportDimension;
  return loadedExtent * slotCount / loadedSlotCount > 3 * viewportDimension;
}

List<ScrubberMarker> thinMarkers(
  List<ScrubberMarker> markers, {
  required int slotCount,
  required double trackExtent,
  required double minSpacing,
}) {
  final kept = <ScrubberMarker>[];
  double? last;
  for (final marker in markers) {
    final y = trackForSlot(
      slot: marker.slot,
      trackExtent: trackExtent,
      slotCount: slotCount,
    );
    if (last != null && y - last < minSpacing) continue;
    kept.add(marker);
    last = y;
  }
  return kept;
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/shared/widgets/list_scrubber/list_scrubber_geometry_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/widgets/list_scrubber/list_scrubber_geometry.dart test/shared/widgets/list_scrubber/list_scrubber_geometry_test.dart
git add lib/shared/widgets/list_scrubber/list_scrubber_geometry.dart test/shared/widgets/list_scrubber/list_scrubber_geometry_test.dart
git commit -m "feat(ui): list scrubber geometry (#3456)"
```

---

### Task 7: `ListScrubber` widget

> As built: superseded in part. The bubble, pills and 36 px handle gave way to a themed thumb and a panel shown while active. See A1, A2, A4, A5, A8 to A15.

**Files:**
- Create: `lib/shared/widgets/list_scrubber/list_scrubber.dart`
- Test: `test/shared/widgets/list_scrubber/list_scrubber_test.dart`

**Interfaces:**
- Consumes: geometry functions (Task 6), `ScrubberMarker` (Task 5).
- Produces:

```dart
class ListScrubber extends StatefulWidget {
  const ListScrubber({
    super.key,
    required this.controller,
    required this.slotCount,
    required this.loadedSlotCount,
    required this.labelFor,
    required this.markers,
    required this.onScrubEnd,
    required this.child,
    this.busyLabel,
  });
  static const thumbKey = ValueKey('listScrubber.thumb');
  static const bubbleKey = ValueKey('listScrubber.bubble');
  static const idleHide = Duration(milliseconds: 1500);
}
```

Behaviour: returns `child` alone when `scrubberWanted` is false (or the controller has no clients). Otherwise stacks over `child`: a right-edge strip (48 px wide, `MouseRegion` with `hitTestBehavior: HitTestBehavior.translucent`) holding the thumb (36x48), and, while visible, an `IgnorePointer` layer with the thinned markers and the bubble to the left of the strip. Visible while scrolling (until `idleHide` after the last scroll), while hovered, while dragging, or while `busyLabel` is set; otherwise opacity 0 and pointer-ignoring. Dragging the thumb maps the thumb centre to a slot with `slotForTrack`, clamps it to `slotCount - 1` on every frame, jumps the controller with `scrollForSlot` while the slot is below `loadedSlotCount`, and calls `onScrubEnd(slot)` on release. The whole overlay is wrapped in `ExcludeSemantics`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget host({
    int rows = 200,
    int? slotCount,
    int? loadedSlotCount,
    void Function(int)? onEnd,
    String? busy,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: ListScrubber(
          controller: controller,
          slotCount: slotCount ?? rows,
          loadedSlotCount: loadedSlotCount ?? rows,
          labelFor: (slot) => 'Slot $slot',
          markers: const [
            ScrubberMarker(slot: 0, label: 'Top'),
            ScrubberMarker(slot: 150, label: 'Low'),
          ],
          onScrubEnd: onEnd ?? (_) {},
          busyLabel: busy,
          child: ListView.builder(
            controller: controller,
            itemCount: rows,
            itemExtent: 50,
            itemBuilder: (_, i) => Text('Row $i'),
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(ListScrubber.thumbKey),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('absent for a short list', (tester) async {
    await tester.pumpWidget(host(rows: 20));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(find.byKey(ListScrubber.thumbKey), findsNothing);
  });

  testWidgets('appears on scroll and fades out when idle', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(opacity(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(opacity(tester), 1);

    await tester.pump(ListScrubber.idleHide + const Duration(milliseconds: 100));
    expect(opacity(tester), 0);
  });

  testWidgets('dragging shows the bubble, follows live, reports the slot', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 276));
    await tester.pump();

    expect(find.byKey(ListScrubber.bubbleKey), findsOneWidget);
    expect(find.textContaining('Slot '), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    expect(controller.offset, greaterThan(1000));

    await gesture.up();
    await tester.pump();
    expect(ended, isNotNull);
    expect(ended, inInclusiveRange(90, 110));
  });

  testWidgets('beyond the loaded rows only the bubble moves', (tester) async {
    int? ended;
    await tester.pumpWidget(
      host(rows: 100, slotCount: 400, loadedSlotCount: 100, onEnd: (s) => ended = s),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final before = controller.offset;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 540));
    await tester.pump();
    expect(controller.offset, closeTo(before, 1));
    expect(find.text('Slot 399'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(ended, 399);
  });

  testWidgets('a held slot is clamped when the slots shrink mid-drag', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 540));
    await tester.pump();

    await tester.pumpWidget(host(slotCount: 40, onEnd: (s) => ended = s));
    expect(find.text('Slot 39'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(ended, 39);
  });

  testWidgets('a busy label keeps it visible and fills the bubble', (
    tester,
  ) async {
    await tester.pumpWidget(host(busy: 'Loading'));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump(ListScrubber.idleHide * 2);
    expect(opacity(tester), 1);
    expect(find.text('Loading'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/shared/widgets/list_scrubber/list_scrubber_test.dart`
Expected: compile error, `ListScrubber` is not defined.

- [ ] **Step 3: Implement**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// A draggable thumb over [child]'s right edge that scrubs through
/// [slotCount] positions, of which the first [loadedSlotCount] are rows
/// [child] already holds.
class ListScrubber extends StatefulWidget {
  const ListScrubber({
    super.key,
    required this.controller,
    required this.slotCount,
    required this.loadedSlotCount,
    required this.labelFor,
    required this.markers,
    required this.onScrubEnd,
    required this.child,
    this.busyLabel,
  });

  final ScrollController controller;
  final int slotCount;
  final int loadedSlotCount;
  final String Function(int slot) labelFor;
  final List<ScrubberMarker> markers;
  final void Function(int slot) onScrubEnd;

  /// Shown in the bubble, and keeps the scrubber visible, while the caller
  /// works toward a dropped slot.
  final String? busyLabel;
  final Widget child;

  static const thumbKey = ValueKey('listScrubber.thumb');
  static const bubbleKey = ValueKey('listScrubber.bubble');
  static const idleHide = Duration(milliseconds: 1500);

  @override
  State<ListScrubber> createState() => _ListScrubberState();
}

class _ListScrubberState extends State<ListScrubber> {
  static const _thumbHeight = 48.0;
  static const _thumbWidth = 36.0;
  static const _strip = 48.0;
  static const _markerSpacing = 28.0;

  bool _scrolling = false;
  bool _hovering = false;
  int? _dragSlot;
  int? _lastSlot;
  double _dragTop = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ListScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (oldWidget.busyLabel != null && widget.busyLabel == null) {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_dragSlot != null || !mounted) return;
    if (!_scrolling) setState(() => _scrolling = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(ListScrubber.idleHide, () {
      if (mounted) setState(() => _scrolling = false);
    });
  }

  int get _maxSlot => math.max(0, widget.slotCount - 1);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final ScrollPosition? position = controller.hasClients
            ? controller.position
            : null;
        final wanted =
            position != null &&
            position.hasContentDimensions &&
            scrubberWanted(
              slotCount: widget.slotCount,
              loadedSlotCount: widget.loadedSlotCount,
              maxScrollExtent: position.maxScrollExtent,
              viewportDimension: position.viewportDimension,
            );
        if (!wanted) {
          if (position == null || !position.hasContentDimensions) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && controller.hasClients) setState(() {});
            });
          }
          return widget.child;
        }

        final trackExtent = math.max(0.0, constraints.maxHeight - _thumbHeight);
        final dragSlot = _dragSlot == null
            ? null
            : math.min(_dragSlot!, _maxSlot);
        final slot =
            dragSlot ??
            (widget.busyLabel != null ? _lastSlot : null) ??
            slotForScroll(
              pixels: position.pixels,
              maxScrollExtent: position.maxScrollExtent,
              loadedSlotCount: widget.loadedSlotCount,
            );
        final thumbTop = trackForSlot(
          slot: math.min(slot, _maxSlot),
          trackExtent: trackExtent,
          slotCount: widget.slotCount,
        );
        final visible =
            _scrolling ||
            _hovering ||
            dragSlot != null ||
            widget.busyLabel != null;
        final bubbleText =
            widget.busyLabel ??
            (dragSlot == null ? null : widget.labelFor(dragSlot));
        final theme = Theme.of(context);

        return Stack(
          children: [
            widget.child,
            if (visible)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Stack(
                      children: [
                        for (final marker in thinMarkers(
                          widget.markers,
                          slotCount: widget.slotCount,
                          trackExtent: trackExtent,
                          minSpacing: _markerSpacing,
                        ))
                          Positioned(
                            right: _strip + 4,
                            top:
                                trackForSlot(
                                  slot: marker.slot,
                                  trackExtent: trackExtent,
                                  slotCount: widget.slotCount,
                                ) +
                                _thumbHeight / 2 -
                                8,
                            child: Text(
                              marker.label,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        if (bubbleText != null)
                          Positioned(
                            right: _strip + 48,
                            top: thumbTop + _thumbHeight / 2 - 18,
                            child: Material(
                              key: ListScrubber.bubbleKey,
                              elevation: 3,
                              borderRadius: BorderRadius.circular(18),
                              color: theme.colorScheme.inverseSurface,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Text(
                                  bubbleText,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onInverseSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _strip,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) {
                  setState(() => _hovering = false);
                  _scheduleHide();
                },
                child: ExcludeSemantics(
                  child: Stack(
                    children: [
                      Positioned(
                        top: thumbTop,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              key: ListScrubber.thumbKey,
                              onVerticalDragStart: (_) {
                                _hideTimer?.cancel();
                                _dragTop = thumbTop;
                                setState(() => _dragSlot = slot);
                              },
                              onVerticalDragUpdate: (details) =>
                                  _dragTo(details.delta.dy, trackExtent),
                              onVerticalDragEnd: (_) => _endDrag(),
                              onVerticalDragCancel: _endDrag,
                              child: Container(
                                width: _thumbWidth,
                                height: _thumbHeight,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(24),
                                  ),
                                  boxShadow: kElevationToShadow[2],
                                ),
                                child: Icon(
                                  Icons.unfold_more,
                                  size: 20,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _dragTo(double dy, double trackExtent) {
    _dragTop += dy;
    final slot = math.min(
      slotForTrack(
        dy: _dragTop,
        trackExtent: trackExtent,
        slotCount: widget.slotCount,
      ),
      _maxSlot,
    );
    if (slot != _dragSlot) setState(() => _dragSlot = slot);
    final controller = widget.controller;
    if (slot < widget.loadedSlotCount && controller.hasClients) {
      controller.jumpTo(
        scrollForSlot(
          slot: slot,
          maxScrollExtent: controller.position.maxScrollExtent,
          loadedSlotCount: widget.loadedSlotCount,
        ),
      );
    }
  }

  void _endDrag() {
    final slot = _dragSlot;
    if (slot == null) return;
    final clamped = math.min(slot, _maxSlot);
    setState(() {
      _dragSlot = null;
      _lastSlot = clamped;
    });
    _scheduleHide();
    widget.onScrubEnd(clamped);
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/shared/widgets/list_scrubber/`
Expected: All tests passed. If the "dragging" test's slot range misses, print the computed slot and adjust only the test's expected range to match `slotForTrack` for the dragged distance (the thumb starts at the slot for the current scroll offset).

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/widgets/list_scrubber/list_scrubber.dart test/shared/widgets/list_scrubber/list_scrubber_test.dart
git add lib/shared/widgets/list_scrubber/list_scrubber.dart test/shared/widgets/list_scrubber/list_scrubber_test.dart
git commit -m "feat(ui): generic list scrubber widget (#3456)"
```

---

### Task 8: `KeyboardListNavigator.revealRow`

**Files:**
- Modify: `lib/shared/widgets/master_detail/keyboard_list_navigator.dart` (`_reveal`, lines ~231-289; add a static method on `KeyboardListNavigator`)
- Test: `test/shared/widgets/master_detail/keyboard_list_navigator_test.dart` (append a group)

**Interfaces:**
- Produces: `static void KeyboardListNavigator.revealRow(BuildContext context, String key)`; `context` must be below the navigator. Scrolls the row registered under `key` to the top of the list, building it first when off screen. Moves neither the keyboard cursor nor the selection.

- [ ] **Step 1: Write the failing test** (append to the existing file's `main`; reuse its imports)

```dart
  group('revealRow', () {
    testWidgets('brings an unbuilt row to the top without moving the cursor', (
      tester,
    ) async {
      final keys = [for (var i = 0; i < 300; i++) 'row$i'];
      late BuildContext inside;
      String? moved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardListNavigator(
              keys: keys,
              currentKey: null,
              onMove: (key) => moved = key,
              onActivate: (_) {},
              child: Builder(
                builder: (context) {
                  inside = context;
                  return ListView.builder(
                    itemCount: keys.length,
                    itemBuilder: (_, i) => KeyboardListItem(
                      navigationKey: keys[i],
                      child: SizedBox(height: 40 + (i % 3) * 10.0, child: Text(keys[i])),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      KeyboardListNavigator.revealRow(inside, 'row250');
      await tester.pumpAndSettle();

      expect(find.text('row250'), findsOneWidget);
      final listTop = tester.getTopLeft(find.byType(ListView)).dy;
      expect(tester.getTopLeft(find.text('row250')).dy, closeTo(listTop, 1));
      expect(moved, isNull);
    });
  });
```

If the navigator's constructor requires further parameters, pass them the way the existing tests in this file do.

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/shared/widgets/master_detail/keyboard_list_navigator_test.dart --plain-name revealRow`
Expected: compile error, `revealRow` is not defined.

- [ ] **Step 3: Implement**

Add a `land` flag to `_reveal` and the static entry point:

```dart
  void _reveal(
    String key, {
    required bool forward,
    int attempt = 0,
    bool land = false,
  }) {
    if (!mounted || (!land && _cursor != key)) return;
    final row = _rows[key];
    if (row != null && row.mounted) {
      if (land) {
        Scrollable.ensureVisible(row);
      } else {
        Scrollable.ensureVisible(
          row,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: forward
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
      return;
    }
    // ... existing body unchanged, except the recursive call:
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(key, forward: forward, attempt: attempt + 1, land: land),
    );
    WidgetsBinding.instance.scheduleFrame();
  }
```

On `KeyboardListNavigator`:

```dart
  /// Scrolls the row registered under [key] to the top of the list, building
  /// it first when it is off screen. Moves neither the cursor nor the
  /// selection. [context] must sit below the navigator.
  static void revealRow(BuildContext context, String key) {
    context
        .getInheritedWidgetOfExactType<_KeyboardListScope>()
        ?.state
        ._reveal(key, forward: false, land: true);
  }
```

`Scrollable.ensureVisible` with its default `alignment: 0.0` puts the row's top at the viewport's top.

- [ ] **Step 4: Run the whole navigator test file**

Run: `flutter test test/shared/widgets/master_detail/keyboard_list_navigator_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/widgets/master_detail/keyboard_list_navigator.dart test/shared/widgets/master_detail/keyboard_list_navigator_test.dart
git add lib/shared/widgets/master_detail/keyboard_list_navigator.dart test/shared/widgets/master_detail/keyboard_list_navigator_test.dart
git commit -m "feat(ui): reveal a list row at the top without moving the cursor (#3456)"
```

---

### Task 9: `DiveListScrubber` and wiring into the dive list

> As built: adds caching, per-sort details, favourite ticks, the selected dot, the stale-index rule, latest-drop-wins and the scrubbing flag. See A1, A9 to A14, A16 and A19.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_list_scrubber.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildDiveList`, around lines 1993-2020, and a new `_landOnDive` method next to `_scrollToSelectedItem`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_scrubber_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:

```dart
class DiveListScrubber extends ConsumerStatefulWidget {
  const DiveListScrubber({
    super.key,
    required this.controller,
    required this.loadedDives,
    required this.groupingEnabled,
    required this.collapsedTripIds,
    required this.onLand,
    required this.child,
  });
  final ScrollController controller;
  final List<DiveSummary> loadedDives;
  final bool groupingEnabled;
  final Set<String> collapsedTripIds;
  final void Function(BuildContext context, String diveId) onLand;
  final Widget child;
}
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show makeDive;

class _ScrubNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _ScrubNotifier(this.all, int loaded)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: all.take(loaded).toList(),
            hasMore: true,
            totalCount: all.length,
            revision: 1,
          ),
        ),
      );

  final List<DiveSummary> all;
  final calls = <(String, int)>[];
  bool vanish = false;

  @override
  Future<bool> loadThrough(String diveId, {required int targetIndex}) async {
    calls.add((diveId, targetIndex));
    if (vanish) return false;
    final through = (targetIndex + 51).clamp(0, all.length);
    state = AsyncValue.data(
      state.value!.copyWith(
        dives: all.take(through).toList(),
        hasMore: through < all.length,
      ),
    );
    return true;
  }

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const tripFirst = 200;
  const tripLast = 220;

  List<DiveSummary> fixture({bool trip = false}) => [
    for (var i = 0; i < 300; i++)
      trip && i >= tripFirst && i <= tripLast
          ? makeDive('d$i', tripId: 't1', tripName: 'Red Sea')
          : makeDive('d$i'),
  ];

  List<DiveScrubberEntry> indexOf(List<DiveSummary> dives) => [
    for (final d in dives)
      DiveScrubberEntry(
        id: d.id,
        sortTimestamp: d.sortTimestamp,
        diveNumber: d.diveNumber,
        siteName: d.siteName,
        tripId: d.tripId,
      ),
  ];

  Future<_ScrubNotifier> pumpList(
    WidgetTester tester, {
    bool trip = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dives = fixture(trip: trip);
    final notifier = _ScrubNotifier(dives, 50);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      kCollapsedTripIdsPrefsKey,
      trip ? const ['t1'] : const [],
    );
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          diveListGroupTripsProvider.overrideWith((ref) => trip),
          tripDiveCountsProvider.overrideWith(
            (ref) async => trip ? const {'t1': 21} : const <String, int>{},
          ),
          collapsedTripIdsProvider.overrideWith(
            (ref) => CollapsedTripsNotifier(prefs, null),
          ),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
          diveScrubberIndexProvider.overrideWith(
            (ref) async => indexOf(dives),
          ),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  Finder row(String id) => find.byWidgetPredicate(
    (w) => w is KeyboardListItem && w.navigationKey == id,
  );

  Future<void> showThumb(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
    await tester.pump();
  }

  Future<void> dragThumb(WidgetTester tester, double dy) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(Offset(0, dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dropping past the loaded rows loads through and lands', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    await showThumb(tester);
    await dragThumb(tester, 2000);

    expect(notifier.calls, [('d299', 299)]);
    expect(row('d299'), findsOneWidget);
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(tester.getTopLeft(row('d299')).dy, lessThan(top + 400));
  });

  testWidgets('landing leaves the selection alone', (tester) async {
    final notifier = await pumpList(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CustomScrollView)),
    );
    await showThumb(tester);
    await dragThumb(tester, 2000);
    expect(notifier.calls, isNotEmpty);
    expect(container.read(highlightedDiveIdProvider), isNull);
  });

  testWidgets('a vanished target leaves the list where it is', (tester) async {
    final notifier = await pumpList(tester);
    notifier.vanish = true;
    await showThumb(tester);
    await dragThumb(tester, 2000);
    expect(notifier.calls, hasLength(1));
    expect(row('d299'), findsNothing);
  });

  testWidgets('a target in a collapsed trip lands on its header', (
    tester,
  ) async {
    final notifier = await pumpList(tester, trip: true);
    final slots = buildDiveScrubberSlots(
      entries: indexOf(fixture(trip: true)),
      groupingEnabled: true,
      collapsedTripIds: const {'t1'},
    );
    final tripSlot = slots.indexWhere((s) => s.collapsedTripId == 't1');

    await showThumb(tester);
    final listTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    final trackExtent =
        tester.getSize(find.byType(CustomScrollView)).height - 48;
    final thumbY =
        tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy - listTop;
    final target = trackForSlot(
      slot: tripSlot,
      trackExtent: trackExtent,
      slotCount: slots.length,
    );
    await dragThumb(tester, target - thumbY);

    expect(notifier.calls.single.$1, 'd$tripFirst');
    expect(find.text('Red Sea'), findsOneWidget);
    expect(row('d${tripFirst + 1}'), findsNothing);
  });
}
```

`kCollapsedTripIdsPrefsKey` and `CollapsedTripsNotifier` come from `trip_group_collapse_provider.dart`, used the same way in `test/features/dive_log/presentation/widgets/dive_list_grouping_scroll_test.dart`; `diveListGroupTripsProvider` lives in `settings_providers.dart`; `makeDive` is the fixture helper exported by `dive_list_trip_grouping_test.dart`. If the analyzer reports an unused import, remove it.

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_scrubber_test.dart`
Expected: FAIL, the thumb is never found (no scrubber in the list yet) or compile error for `DiveListScrubber`.

- [ ] **Step 3: Implement `DiveListScrubber`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_labels.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';

/// The dive list's scrubber: every dive the list shows, labelled by the
/// active sort and the country.
class DiveListScrubber extends ConsumerStatefulWidget {
  const DiveListScrubber({
    super.key,
    required this.controller,
    required this.loadedDives,
    required this.groupingEnabled,
    required this.collapsedTripIds,
    required this.onLand,
    required this.child,
  });

  final ScrollController controller;
  final List<DiveSummary> loadedDives;
  final bool groupingEnabled;
  final Set<String> collapsedTripIds;

  /// Brings [diveId], or the header of the collapsed trip holding it, to the
  /// top of the list. [context] sits below the list's keyboard navigator.
  final void Function(BuildContext context, String diveId) onLand;
  final Widget child;

  @override
  ConsumerState<DiveListScrubber> createState() => _DiveListScrubberState();
}

class _DiveListScrubberState extends ConsumerState<DiveListScrubber> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final entries =
        ref.watch(diveScrubberIndexProvider).valueOrNull ?? const [];
    if (entries.isEmpty) return widget.child;

    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: widget.groupingEnabled,
      collapsedTripIds: widget.collapsedTripIds,
    );
    final loadedCount = widget.loadedDives.length;
    final field = ref.watch(diveSortProvider).field;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    return ListScrubber(
      controller: widget.controller,
      slotCount: slots.length,
      loadedSlotCount: slots.where((s) => s.entryIndex < loadedCount).length,
      labelFor: (slot) => diveScrubberBubble(
        slots[slot].entry,
        field,
        units: units,
        l10n: l10n,
        locale: locale,
      ),
      markers: diveScrubberMarkers(
        slots,
        field,
        units: units,
        l10n: l10n,
        locale: locale,
      ),
      busyLabel: _loading ? l10n.common_label_loading : null,
      onScrubEnd: (slot) => _land(slots[slot]),
      child: widget.child,
    );
  }

  Future<void> _land(DiveScrubberSlot slot) async {
    final id = slot.entry.id;
    if (!widget.loadedDives.any((d) => d.id == id)) {
      setState(() => _loading = true);
      final loaded = await ref
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(id, targetIndex: slot.entryIndex);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!loaded) return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLand(context, id);
    });
  }
}
```

- [ ] **Step 4: Wire it into `dive_list_content.dart`**

In `_buildDiveList`, wrap the `CustomScrollView(...)` that is the `KeyboardListNavigator`'s `child`:

```dart
              child: DiveListScrubber(
                controller: _scrollController,
                loadedDives: dives,
                groupingEnabled: groupingEnabled,
                collapsedTripIds: collapsedTripIds,
                onLand: _landOnDive,
                child: CustomScrollView(
                  // unchanged
                ),
              ),
```

Add next to `_scrollToSelectedItem`:

```dart
  void _landOnDive(BuildContext context, String diveId) {
    for (final (index, section) in _lastSections.indexed) {
      if (!section.entries.any((e) => e.dive.id == diveId)) continue;
      final key = section is TripSection && section.collapsed
          ? diveListTripHeaderKey(index, section.tripId)
          : diveId;
      KeyboardListNavigator.revealRow(context, key);
      return;
    }
  }
```

Add the import for `dive_list_scrubber.dart`.

- [ ] **Step 5: Run the new test and the existing dive list tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_scrubber_test.dart test/features/dive_log/presentation/widgets/ test/features/dive_log/presentation/pages/`
Expected: All tests passed. Existing tests do not override `diveScrubberIndexProvider`; if one fails because the provider reads a real repository, make `DiveListScrubber` treat an errored index like an empty one (it already uses `valueOrNull`), and if the failure is a missing database, add `diveScrubberIndexProvider.overrideWith((ref) async => const [])` to `getBaseOverrides()` in `test/helpers/mock_providers.dart`.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_list_scrubber.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_scrubber_test.dart
git add lib/features/dive_log/presentation/widgets/dive_list_scrubber.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_scrubber_test.dart
git add test/helpers/mock_providers.dart  # only if Step 5 changed it
git commit -m "feat(dive-log): scrubber on the dive list (#3456)"
```

---

### Task 10: Verify the whole branch and try it in the app

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format --output=none --set-exit-if-changed lib test` then `flutter analyze`
Expected: no changes, "No issues found!".

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all pass except, on Windows, `test/helpers/proxy_fakes_hang_up_test.dart` (known, pre-existing).

- [ ] **Step 3: Run the app and check by hand**

Run: `flutter run -d windows`. With a log of a few hundred dives (or after importing a large sample), on the dive list in detailed and compact modes:
- the thumb appears on scroll and on hovering the right edge, and fades out;
- each of the six sorts shows its markers and bubble ("Mar 2024 · Egypt" and so on), depth in the diver's unit;
- dropping near the end jumps there after a short loading bubble, with the detail pane unchanged;
- with "group by trip" on and a trip collapsed, dropping on it lands on its header;
- a row's tap, swipe and context menu at the right edge still work when the thumb is hidden.

- [ ] **Step 4: Screenshots for the PR**

Capture before and after of the dive list (light and dark, phone and desktop width) while dragging the thumb, per `docs/contributing/pull-requests.md`.
