# Design: Filterable Statistics

- **Issue:** [#453 — Ability to filter in Statistics](https://github.com/submersion-app/submersion/issues/453)
- **Date:** 2026-07-02
- **Branch/worktree:** `worktree-issue-453-statistics-filter`
- **Status:** Approved design, pending spec review

## 1. Problem

A diver wants to scope the Statistics tab to a subset of dives and see the aggregates for just that subset. The issue's concrete example:

> "I would like to tag all of my dry suit dives with 'Dive Suit' then go to the Statistics tab and filter on that tag so I can see how many dry suit dives I've done in the last year."

Today the Statistics tab has **no user-facing filter at all**. Every metric is a hand-written SQL aggregate over the `dives` table whose only `WHERE` axis is `diver_id`. Trend queries hardcode a 5-year cutoff; "dives by month" hardcodes 12 months. There is no date range, no tag filter, no type/site filter.

## 2. Goals / Non-goals

### Goals

- Let a diver filter the **entire** Statistics tab (Overview totals, Personal Records, and all 10 category pages) by the same axes the dive-list filter already supports (full parity).
- Reuse the existing `DiveFilterState` model and the existing filter-sheet UI rather than inventing a stats-specific filter.
- Keep the filter **independent** of the dive-list filter (its own instance) — filtering stats never changes the dive list and vice-versa.
- Add quick **date presets** (This year / Last 12 months / Last year / All time / Custom) that directly serve the issue's "in the last year" wording.
- Surface an active filter clearly (badged icon + summary bar) so scoped totals are never mysterious.

### Non-goals (YAGNI)

- No **new** filter axes beyond what `DiveFilterState` / the sheet already expose.
- No cross-restart **persistence** of the stats filter (in-memory only, matching the dive-list filter).
- No **per-chart** independent filters — one filter scopes the whole tab.
- No change to the dive-list filter's existing behavior (including its pre-existing "drops axes it doesn't render" quirk — see §8).

## 3. Decisions (locked)

| Decision | Choice |
| --- | --- |
| Filter axes | **Full dive-list parity** — reuse `DiveFilterState` in its entirety |
| Filter state | **Independent** — a new `statisticsFilterProvider`, not the shared `diveFilterProvider` |
| Injection mechanism | **One filtered-dive-id subquery** threaded uniformly into each stat query (Approach C, §5) |
| Date presets | **Included** — populate absolute start/end dates; no data-model change |
| Discoverability | **Summary bar + badged icon** |
| Persistence | In-memory only |

## 4. Current-state map (what already exists)

### 4.1 The filter model — reuse target

- `DiveFilterState` — `lib/features/dive_log/domain/models/dive_filter_state.dart`
  - Fields (all `final`): `startDate`, `endDate` (`DateTime?`); `diveTypeId`, `siteId`, `tripId`, `diveCenterId`, `buddyNameFilter`, `buddyId`, `computerSerial`, `customFieldKey`, `customFieldValue` (`String?`); `minDepth`, `maxDepth`, `minO2Percent`, `maxO2Percent` (`double?`); `favoritesOnly` (`bool?`); `minRating`, `minBottomTimeMinutes`, `maxBottomTimeMinutes` (`int?`); `tagIds`, `equipmentIds`, `diveIds` (`List<String>`, default `const []`).
  - `hasActiveFilters` getter (lines ~58–79): OR across all axes.
  - `apply(List<Dive>)` (lines ~177–272): the **canonical filtering semantics**, used today for non-paginated paths (e.g. export). The SQL builder (§5) must mirror it exactly.
- `diveFilterProvider` — `StateProvider<DiveFilterState>`, `lib/features/dive_log/presentation/providers/dive_providers.dart:28`. Written by the dive-list sheet **and** by site/trip/buddy detail pages.
- `DiveFilterSheet` — currently a ~600-line `ConsumerStatefulWidget` embedded in `lib/features/dive_log/presentation/pages/dive_list_page.dart:1054`, hardcoded to `diveFilterProvider`. Renders: Date Range, Dive Type (single-select), Dive Site, Dive Computer, Depth Range, Favorites, Tags (multi-select chips), Buddy, Gas Mix (O₂%), Minimum Rating, Duration.

### 4.2 The statistics feature — injection surface

- Entry: `lib/features/statistics/presentation/pages/statistics_page.dart` — master-detail (desktop ≥800px) vs mobile ListView.
- Overview totals: `diveStatisticsProvider` (`dive_providers.dart:198–203`) → `DiveRepositoryImpl.getStatistics({diverId})` (`dive_repository_impl.dart:1869–1888`), returning `DiveStatistics` (class at `dive_repository_impl.dart:4936–4994`).
  - **IMPORTANT:** `diveStatisticsProvider` is also consumed by the **home dashboard** (see memory `project_home_tab_stale_dives_217`). It must stay **unfiltered** (§6.3).
- Advanced metrics: ~30 `FutureProvider`s in `lib/features/statistics/presentation/providers/statistics_providers.dart`, each → a method on `StatisticsRepository` (`lib/features/statistics/data/repositories/statistics_repository.dart`, ~1842 lines). Return DTOs: `TrendDataPoint`, `RankingItem`, `DistributionSegment` (lines ~10–52). These providers are **statistics-feature-only** (safe to filter).
- Cache: `statisticsVersionProvider` (`StateProvider<int>`, `dive_providers.dart:186`) bumped on mutations; advanced providers call `_keepAliveWithExpiry(ref)` (`statistics_providers.dart:20–27`).
- Universal query idiom (~40×): interpolate a `diverFilter` SQL fragment (`AND d.diver_id = ?`) + append a positional `Variable`. This is exactly the seam the new filter clause slots into.

### 4.3 Schema facts the SQL builder depends on (`lib/core/database/database.dart`, schema v93)

| Concept | Table.column | Notes |
| --- | --- | --- |
| Dive timestamp | `dives.dive_date_time` (`IntColumn`, line 134) | Unix epoch **milliseconds**, confirmed: write path uses `dive.dateTime.millisecondsSinceEpoch` (`dive_repository_impl.dart:705`), reads use `DateTime.fromMillisecondsSinceEpoch(..., isUtc: true)`. Times are **wall-clock-as-UTC** (memory `project_dive_time_wallclock`) |
| Bottom time / runtime | `dives.bottom_time`, `dives.runtime` (int, **seconds**, lines 140–141) | |
| Max depth | `dives.max_depth` (real, nullable, line 142) | |
| Buddy (free text) | `dives.buddy` (text, nullable, line 149) | |
| Site / trip / center | `dives.site_id` (157), `dives.trip_id` (163), `dives.dive_center_id` (160) | |
| Rating | `dives.rating` (int, nullable, line 158) | |
| Computer serial | `dives.dive_computer_serial` (line 187) | |
| Favorite | `dives.is_favorite` (bool, line 193) | |
| Tags (M:N) | `dive_tags` junction (class line 1112): `dive_id`, `tag_id` | |
| Dive types (M:N) | `dive_dive_types` junction (class line 1129): `dive_id`, `dive_type_id` (text slug) | legacy single `dives.dive_type` (line 147) is superseded by the junction |
| Equipment (M:N) | `dive_equipment` junction (class line 447): `dive_id`, `equipment_id` (composite PK) | confirmed |
| Tank O₂ | `dive_tanks.o2_percent` (real, default 21.0, line 392) | |
| Custom fields | `dive_custom_fields` (class line 1377): **`field_key`, `field_value`** | not `key`/`value` |

## 5. Architecture

### 5.1 Approaches considered

| Approach | Mechanism | Verdict |
| --- | --- | --- |
| A — Recompute in Dart | Load all dives, `apply()` the filter, aggregate ~30 metrics in Dart | Rejected — rewrites the whole stats engine (SAC trends, profile/sighting JOINs); perf + memory regressions |
| B — Thread each axis into each query | Add date/tag/type/… clauses individually to all ~30 WHEREs | Rejected — heterogeneous edits, fragile positional params, large surface |
| **C — One filtered-dive-id subquery** | Build the filter **once** as a self-contained `SELECT id FROM dives WHERE …` predicate; each stat query appends one uniform clause `AND <alias>.id IN (<subquery>)` | **Chosen** — uniform per-call-site edit, testable, no 999-variable limit (junction axes use small `IN` lists inside the subquery) |

### 5.2 The `DiveFilterSql` helper (new)

Location: `lib/features/statistics/data/dive_filter_sql.dart` (pure, no I/O).

```dart
/// Translates a DiveFilterState into a self-contained SQL predicate over the
/// `dives` table, mirroring DiveFilterState.apply() exactly. Returns an empty
/// no-op ('' + []) when !filter.hasActiveFilters.
({String subquery, List<Variable<Object>> vars}) buildFilteredDiveIdSubquery(
  DiveFilterState filter,
);
```

- Emits `SELECT id FROM dives WHERE <conjunction of active axes>`.
- Many-to-many axes use sub-selects into the junctions (`dive_tags`, `dive_dive_types`, `dive_equipment`, `dive_tanks`, `dive_custom_fields`).
- **Diver scoping stays out of this subquery** — each outer stat query keeps its own `AND d.diver_id = ?`. Because `dives.id` is globally unique, `d.diver_id = ? AND d.id IN (SELECT id FROM dives WHERE …)` yields the correct per-diver intersection with no double scoping.
- Empty-filter no-op ⇒ unfiltered stats are byte-for-byte identical to today (existing tests unaffected, zero perf change on the common path).

### 5.3 Per-axis SQL mapping (must mirror `apply()`)

| Axis | `apply()` semantics | SQL fragment |
| --- | --- | --- |
| `startDate` | exclude if `dive < startDate` | `dive_date_time >= :startMs` |
| `endDate` | exclude if `dive > endDate + 1 day` | `dive_date_time <= :endPlus1DayMs` |
| `diveTypeId` | `dive.diveTypeIds.contains(id)` | `id IN (SELECT dive_id FROM dive_dive_types WHERE dive_type_id = ?)` |
| `siteId` | `dive.site?.id == id` | `site_id = ?` |
| `tripId` | `dive.tripId == id` | `trip_id = ?` |
| `diveCenterId` | `dive.diveCenter?.id == id` | `dive_center_id = ?` |
| `equipmentIds` (any) | intersect `dive.equipment` ids | `id IN (SELECT dive_id FROM dive_equipment WHERE equipment_id IN (?,…))` |
| `minDepth` | null depth excluded | `max_depth IS NOT NULL AND max_depth >= ?` |
| `maxDepth` | null depth excluded | `max_depth IS NOT NULL AND max_depth <= ?` |
| `favoritesOnly == true` | `dive.isFavorite` | `is_favorite = 1` |
| `tagIds` (any) | intersect `dive.tags` ids | `id IN (SELECT dive_id FROM dive_tags WHERE tag_id IN (?,…))` |
| `buddyNameFilter` | case-insensitive substring of `dive.buddy` | `buddy IS NOT NULL AND LOWER(buddy) LIKE '%'||LOWER(?)||'%'` |
| `diveIds` | `diveIds.contains(dive.id)` | `id IN (?,…)` |
| `minO2/maxO2` (any tank; empty tanks excluded) | tank o2 within present bounds | `id IN (SELECT dive_id FROM dive_tanks WHERE o2_percent >= ? [AND o2_percent <= ?])` |
| `minRating` | null rating excluded | `rating IS NOT NULL AND rating >= ?` |
| `minBottomTimeMinutes` | `dive.bottomTime.inMinutes >= n`, null excluded | `bottom_time IS NOT NULL AND bottom_time / 60 >= ?` |
| `maxBottomTimeMinutes` | `dive.bottomTime.inMinutes <= n`, null excluded | `bottom_time IS NOT NULL AND bottom_time / 60 <= ?` |
| `computerSerial` | `dive.diveComputerSerial == serial` | `dive_computer_serial = ?` |
| `customFieldKey/Value` | any custom field key match (+ optional value substring) | `id IN (SELECT dive_id FROM dive_custom_fields WHERE field_key = ? [AND LOWER(field_value) LIKE '%'||LOWER(?)||'%'])` |

**Subtlety — integer-minute truncation:** `apply()` uses `Duration.inMinutes` (truncating). The SQL therefore uses integer division `bottom_time / 60` (SQLite integer division truncates), **not** `bottom_time <= max*60`, which would disagree on dives with 121–179s of bottom time. The invariant test (§9) pins this.

**Subtlety — date conversion is wall-clock-as-UTC:** `startDate`/`endDate` (and the §7.2 presets) must convert to the stored int via `.millisecondsSinceEpoch` using the **same wall-clock-as-UTC convention** the write path uses (memory `project_dive_time_wallclock`) — i.e. do not shift into local time. Preset boundaries ("start of this year", "12 months ago") are computed in that same frame so the count matches what a diver sees on each dive's displayed date.

### 5.4 Threading into the queries — positional-param discipline

Each call site appends the clause to the end of its `WHERE` and appends `vars` to the **end** of its variable list, in the same order. Because the subquery's placeholders are all self-contained and appended last, the positional mapping stays correct as long as no other `?` follows the injection point (audit each query for trailing `LIMIT ?`/`HAVING ?` and insert at the correct index in the rare cases that have one). Every call site gets the **identical** two-line change:

```dart
final f = buildFilteredDiveIdSubquery(filter);
// ... in the query string:  $diverFilter ${f.subquery.isEmpty ? '' : 'AND d.id IN (${f.subquery})'}
// ... in the variables list: ...existingVars, ...f.vars
```

## 6. State & data flow

### 6.1 New provider

```dart
// lib/features/statistics/presentation/providers/statistics_filter_provider.dart
final statisticsFilterProvider =
    StateProvider<DiveFilterState>((ref) => const DiveFilterState());
```

### 6.2 Wiring the advanced providers

Each of the ~30 providers in `statistics_providers.dart` adds `final filter = ref.watch(statisticsFilterProvider);` and passes it to its repository method (new `DiveFilterState filter = const DiveFilterState()` parameter). Watching the provider makes each metric refetch when the filter changes; the filter joins `currentDiverId` as part of the effective cache key.

### 6.3 Overview totals — filtered sibling, shared provider untouched

Do **not** add the filter to `diveStatisticsProvider` (the home dashboard depends on it staying unfiltered). Instead:

```dart
final filteredDiveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repo = ref.watch(diveRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  ref.invalidateSelfWhen(repo.watchDivesChanges());
  return repo.getStatistics(diverId: diverId, filter: filter);
});
```

`getStatistics` gains `DiveFilterState filter = const DiveFilterState()`. The Statistics **Overview** page switches to `filteredDiveStatisticsProvider`; the home dashboard keeps `diveStatisticsProvider`.

### 6.4 Flow

```
DiveFilterSheet(statisticsFilterProvider)  --writes-->  statisticsFilterProvider
        ^                                                        |
        | opens                                                  | watched by
   [filter icon]                                                 v
                          filteredDiveStatisticsProvider + ~30 advanced providers
                                                                 |
                                                       ref.watch(filter) -> repo(filter)
                                                                 |
                                        buildFilteredDiveIdSubquery(filter) -> AND d.id IN (...)
                                                                 v
                                                           SQLite aggregate
```

## 7. UX

### 7.1 Extract & parameterize `DiveFilterSheet`

Move the sheet out of `dive_list_page.dart` into `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` and parameterize the target provider:

```dart
class DiveFilterSheet extends ConsumerStatefulWidget {
  final StateProvider<DiveFilterState> filterProvider; // default: diveFilterProvider
  const DiveFilterSheet({super.key, this.filterProvider = diveFilterProvider});
}
```

The dive list keeps its current call (default provider, behavior byte-for-byte unchanged). Statistics passes `filterProvider: statisticsFilterProvider`. Bonus: removes ~600 lines from the 2,000-line `dive_list_page.dart`.

### 7.2 Date presets

Add a preset row to the sheet's **Date Range** section: `All time` · `This year` · `Last 12 months` · `Last year` · `Custom`. Selecting a preset populates absolute `startDate`/`endDate` at tap time (no `DiveFilterState` change; presets are just a convenience over the existing pickers). `Custom` reveals the existing start/end pickers.

### 7.3 Entry points

- **Mobile:** a filter `IconButton` in `StatisticsMobileContent`'s `AppBar.actions` (beside the existing records button, `statistics_page.dart:88–95`), badged when `filter.hasActiveFilters`.
- **Desktop:** the same action in `StatisticsListContent`'s app-bar / compact header (`statistics_list_content.dart:148–197`).

### 7.4 Active-filter summary bar

When `hasActiveFilters`, a dismissible bar at the top of the stats content:

```
┌───────────────────────────────────────────────┐
│ 🔽 Dive Suit · Last 12 months   23 dives   ✕  │
└───────────────────────────────────────────────┘
```

- Compact human-readable description of active axes.
- **Matching dive count** (from `filteredDiveStatisticsProvider.totalDives`) so a dropped total is self-explanatory.
- `✕` clears the filter (`statisticsFilterProvider = const DiveFilterState()`).

## 8. Error handling & edge cases

- **Empty filter:** builder returns no-op; unfiltered path unchanged.
- **Null columns:** depth/rating/bottom-time bounds explicitly require `IS NOT NULL`, matching `apply()` (a null value fails a bound).
- **No matches:** aggregates return 0/empty; pages already render empty states. The summary bar's "0 dives" makes this explicit.
- **SQLite 999-variable limit:** not a practical concern — junction `IN` lists come from sheet multi-selects (a handful of ids), nested inside the subquery.
- **Positional params:** §5.4 discipline + round-trip tests.
- **Diver + filter interplay:** §5.2 — no double scoping.

## 9. Testing strategy

1. **`DiveFilterSql` unit tests** — each axis → expected fragment + vars; empty filter → `('', [])`; multi-axis conjunction.
2. **FK-ON round-trip tests** per representative stat method — seed dives with tags/types/sites/dates/tanks (foreign keys **ON**, per memory `project_fk_off_tests_mask_insert_order`), apply a filter, assert the filtered aggregate.
3. **Invariant test (key):** for randomized `DiveFilterState`s over a seeded dataset, assert `DiveFilterState.apply(dives).length == getStatistics(filter).totalDives`. Pins the SQL semantics to the canonical Dart `apply()` so the two paths cannot drift (guards the bottom-time truncation and date-inclusivity subtleties).
4. **Provider test** — changing `statisticsFilterProvider` refetches `filteredDiveStatisticsProvider` and an advanced provider; `diveStatisticsProvider` (home) is **unaffected**.
5. **Widget tests** — `DiveFilterSheet` writes the provider passed to it; the stats filter icon badges on active filter; the summary bar renders and clears.

## 10. Files

**Add:**
- `lib/features/statistics/data/dive_filter_sql.dart`
- `lib/features/statistics/presentation/providers/statistics_filter_provider.dart`
- `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (extracted)
- Widget(s) for the active-filter summary bar (e.g. `lib/features/statistics/presentation/widgets/statistics_filter_bar.dart`)
- Tests mirroring §9.

**Modify:**
- `lib/features/statistics/data/repositories/statistics_repository.dart` — `filter` param + subquery clause on each method.
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — `getStatistics` gains `filter`.
- `lib/features/statistics/presentation/providers/statistics_providers.dart` — watch + pass filter; add `filteredDiveStatisticsProvider`.
- `lib/features/statistics/presentation/pages/statistics_page.dart`, `statistics_overview_page.dart`, `statistics_list_content.dart` — filter action, summary bar, Overview → filtered provider.
- `lib/features/dive_log/presentation/pages/dive_list_page.dart` — use the extracted sheet.
- l10n ARB files — new strings (filter presets, summary-bar text) translated into all 10 non-en locales per memory `project_l10n_translate_all_locales`.

## 11. Rollout / phasing (for the implementation plan)

1. `DiveFilterSql` helper + unit tests (pure, no UI).
2. `filteredDiveStatisticsProvider` + `getStatistics(filter)` + Overview wiring + invariant test (smallest vertical slice that demonstrably works end-to-end).
3. Extract & parameterize `DiveFilterSheet`; add date presets; wire the stats entry point + summary bar.
4. Thread `filter` into the ~30 `StatisticsRepository` methods in batches by category page, each batch with round-trip tests.
5. l10n sweep; `dart format .`; whole-project `flutter analyze`.

## 12. Verify during implementation

Schema facts confirmed (§4.3): `dive_date_time` = ms wall-clock-as-UTC; `dive_equipment` = `dive_id`/`equipment_id`; `dive_custom_fields` = `field_key`/`field_value`. Remaining checks:

- Confirm **no non-statistics consumer** of the ~30 advanced providers before filtering them (grep usages; the home dashboard uses `diveStatisticsProvider`, handled by §6.3).
- Per §5.4, audit each `StatisticsRepository` query for any positional `?` **after** the `WHERE` (e.g. a trailing `LIMIT ?`) and insert the filter vars at the correct index rather than blindly appending.
