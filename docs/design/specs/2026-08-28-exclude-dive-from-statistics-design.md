# Exclude a Dive from Statistics

Design document, 2026-08-28.

Issues: [#526](https://github.com/submersion-app/submersion/issues/526)
(exclude shallow or short dives from overall statistics),
[#1272](https://github.com/submersion-app/submersion/issues/1272)
(exclude a dive from SAC and RMV calculations).

Branch: `worktree-issue-526-exclude-from-stats`.

## Problem

Divers keep dives in their logbook that they do not want counted. Two distinct
cases arrived as separate issues:

- **#526.** A 90 minute dive at 12 ft is not an official dive by most agency
  standards. The diver wants to keep the entry and view it, but wants it out of
  the totals, the averages, and the records.
- **#1272.** An otherwise ordinary dive where the diver purged the tank down to
  500 psi at the end for a weight check. Only the gas number is wrong. Throwing
  away the whole dive to fix one metric is a bad trade.

The app has no concept of an excluded dive today. There is no `excluded`,
`hidden`, or `archived` column on `dives`, and no soft-delete. The only
exclusion rule that exists is `AND d.dive_mode <> 'gauge'`, hand copied into
seven gas queries in `StatisticsRepository` and centralized nowhere.

## Decisions

| Question | Decision |
| --- | --- |
| Granularity | Two flags: exclude from all statistics, and exclude from gas statistics only. |
| Does an excluded dive still count in Total Dives? | No. Excluded means every descriptive aggregate, count included. |
| Blast radius | Descriptive aggregates yes, operational numbers no. |
| Enforcement mechanism | Shared SQL predicate helper plus a behavioral guard suite. Not a SQL view, and not a `DiveFilterState` axis. A separate opt-in filter axis is added for *finding* excluded dives, but it plays no part in enforcement. |
| Visibility | Checkbox, bulk edit, list badge, statistics footnote, and a filter axis. |
| `is_planned` | Fixed in the same change. Planned dives stop counting toward statistics. |

### Why two flags

A single master flag forces #1272's diver to discard a good dive to correct one
metric. Per category flags (depth, duration, gas, records, count) were rejected
as YAGNI: no fourth axis has been requested, and a per dive checkbox grid ages
badly.

The master flag implies the gas flag. The gas predicate is therefore
`excluded_from_stats = 0 AND excluded_from_gas_stats = 0`.

### Why the count is excluded too

#526 is explicit that the dive "does not count as an official dive." A flag
labelled "exclude from statistics" that still increments the total is dishonest
and has to be explained. The dive remains fully present and editable in the
logbook, so nothing is destroyed and the decision is reversible.

Records (deepest, longest, coldest) follow the same rule. A flooded pool
session appearing as "longest dive: 90 min" is the original complaint.

### Descriptive versus operational

Not every count of dives is a statistic. Two categories are load bearing in a
way that makes suppression actively wrong:

- **Equipment service intervals.** `ServiceDueEngine` derives "dives since last
  service" and "hours since last service" from
  `EquipmentRepository.getUsageSamplesForEquipment`. A practice dive still
  cycled the regulator and still put hours on it. Excluding it would push a real
  service interval later than it should be.
- **Course requirement progress.** `CourseRequirementRepository.getCourseProgress`
  counts dives the diver deliberately linked to a requirement. Excluding one
  would silently un-credit work they did on purpose.

The logbook list header ("N dives") is also excluded from the rule. The dive is
still in the logbook, so the list still counts it.

This produces one deliberate asymmetry worth stating plainly: a regulator's
service clock still counts an excluded dive, while the Statistics tab's "most
used gear" card does not. The first measures wear that physically happened; the
second is a descriptive summary of the diver's diving.

## Section 1: Schema and entity

Two boolean columns on `Dives` (`lib/core/database/database.dart:647`),
following the `isFavorite` pattern at line 731:

```dart
// Statistics exclusion (schema v178)
BoolColumn get excludedFromStats =>
    boolean().withDefault(const Constant(false))();
BoolColumn get excludedFromGasStats =>
    boolean().withDefault(const Constant(false))();
```

**Schema version 178.** Main is at 175. Version 176 is claimed by open PR #1328
and 177 by open PR #1361. Both claim scans (open PR diffs and every worktree's
working tree scalar) must be re-run immediately before pushing, because a rung
claimed below main's scalar merges with no conflict marker and its migration
step then never runs.

Migration follows the established three part shape:

1. An idempotent `_assertDiveStatsExclusionColumns()` guarded by
   `PRAGMA table_info('dives')`, including the `if (cols.isEmpty) return;`
   self-guard that minimal schema fixtures depend on. Two statements of the form
   `ALTER TABLE dives ADD COLUMN excluded_from_stats INTEGER NOT NULL DEFAULT 0`.
2. An `onUpgrade` rung at `if (from < 178)`.
3. A `beforeOpen` backstop calling the same helper, because a database arriving
   via restore or sync adopt never runs `onUpgrade`. There is no backfill, so
   both paths are safe to re-run.

**Sync.** No hand edits. `_exportDives`
(`lib/core/services/sync/sync_data_serializer.dart:4487`) serializes via the
generated `row.toJson()`, so both columns ride along.

**UDDF.** Explicit plumbing required in
`lib/core/services/export/uddf/uddf_export_builders.dart` and
`uddf_full_import_service.dart`, mirroring `isFavorite`, so a round trip through
the app's own export format does not drop the flags.

**Entity plumbing.** Mirrors `isFavorite` across
`lib/features/dive_log/domain/entities/dive.dart`,
`domain/entities/dive_summary.dart`, `domain/services/dive_merge_builder.dart`,
the two mapper sites (`dive_repository_impl.dart:3562`, `:3944`) and two
companion sites (`:1409`, `:1664`), and `bulk_edit_field_set.dart`.

## Section 2: Enforcement

New file `lib/core/database/dive_stats_scope.dart`:

```dart
class DiveStatsScope {
  /// Bare predicate: which dives contribute to descriptive statistics.
  static String predicate({String alias = 'd', bool gas = false});

  /// The same, prefixed with ' AND ' for appending into an existing WHERE.
  static String and({String alias = 'd', bool gas = false});
}
```

`predicate()` yields `d.excluded_from_stats = 0 AND d.is_planned = 0`. With
`gas: true` it additionally yields
`AND d.excluded_from_gas_stats = 0 AND d.dive_mode <> 'gauge'`. The `alias`
parameter is required because several queries apply the scope to a second alias
inside a self join.

### The scope is orthogonal to the user filter

This is the central structural decision. The scope is applied alongside
`buildFilteredDiveIdSubquery` (`lib/features/statistics/data/dive_filter_sql.dart:12`),
never inside it.

`buildFilteredDiveIdSubquery` implements the user's transient view filter and
correctly returns an empty no-op when no axis is active. The scope is a
persistent property of the dive. Merging the two would mean one of:

- the exclusion evaporates for every user who never opens the filter sheet, or
- the no-op early return is deleted, and every deliberately unfiltered call site
  (dashboard quick stats, dive log summary, species detail page) silently
  becomes filtered.

The second is a repeat of a bug this codebase already shipped and caught in
review. Keeping them separate lets `StatisticsRepository._diveFilter`
(`statistics_repository.dart:190`) append the scope unconditionally and the user
filter conditionally, which fixes 37 query sites in a single edit.

For the same reason, modelling the exclusion as a `DiveFilterState` axis was
rejected outright.

### Tier 1: statistics feature

- One edit to `_diveFilter` (line 190) covers the 37 filter aware methods.
- Four hand patches: `getYearStats` (line 973),
  `getEntryExitMethodPairsForSite` (line 1298), `getSiteHistoryByName`
  (line 2501), and the nested `FROM dives d2` self join inside
  `getSurfaceIntervalStats` (line 2025), which the user filter clause already
  misses today.
- The seven gas queries (lines 234, 376, 423, 483, 615, 678, 759) drop their
  hand copied `AND d.dive_mode <> 'gauge'` in favor of
  `DiveStatsScope.and(gas: true)`.

### Tier 2: dive log repository

Each builds its own WHERE fragments and gets the scope by hand:

- `getStatistics()` (`dive_repository_impl.dart:2816`), four statements.
- `getRecords()` (line 2984), six superlative statements.
- `getPersonalRecordIds()` (line 3224), six statements.
- `countDivesSince()` (line 3137).
- `getOnThisDayDiveIds()` (line 3155).

Deliberately **not** touched: `getDiveCount()` (line 2190), the logbook list
header. Gets a doc comment naming the decision.

### Tier 3: per entity descriptive counts

| Feature | Sites |
| --- | --- |
| Buddies | `getAllBuddies` inline joins (`buddy_repository.dart:793`, `:811`), `getDiveCountForBuddy` (`:947`), `getDiveIdsForBuddy` (`:971`), `getBuddyStats` (`:997`, `:1031`) |
| Dive sites | `getDiveAggregatesBySite` (`site_repository_impl.dart:863`) |
| Trips | `getTripWithStats` (`trip_repository.dart:505`), `getAllTripsWithStats` (`:598`), `getDiveCountForTrip` (`:322`) |
| Dive centers | `getDiveCountForCenter` (`dive_center_repository.dart:238`) |
| Tags | `tag_repository.dart:548`, `:590`, `:612` |
| Dive types | `dive_type_repository.dart:365`, `:414` |
| Dive roles | `dive_role_repository.dart:240` |
| Divers | `getDiveCountForDiver` (`diver_repository.dart:573`), `getTotalBottomTimeForDiver` (`:593`) |
| Marine life | `seen_species_repository.dart:27`, `:58`; `species_repository.dart:598`, `:627` |
| Dive computers | `dive_repository_impl.dart:6239` |

Several of these count junction table rows without joining `dives` at all
(`getDiveCountForBuddy`, and the tag and dive type counts). Those need a join
added, not just a predicate.

### Deliberately untouched: operational

Each gets a doc comment naming the decision so a future reader does not "fix"
it:

- `EquipmentRepository.getUsageSamplesForEquipment`
  (`equipment_repository_impl.dart:606`), `getDiveCountForEquipment` (`:582`),
  `getTripCountForEquipment` (`:658`), and `ServiceDueEngine`
  (`service_due_engine.dart:12`).
- `CourseRepository.getDiveCountForCourse` (`course_repository.dart:201`),
  `CourseRequirementRepository.getCourseProgress`
  (`course_requirement_repository.dart:56`), and `getSuggestedDives` (`:440`).
- `DiveRepository.getDiveCount()` (`dive_repository_impl.dart:2190`).

Note that `StatisticsRepository.getMostUsedGear` (line 2063) **does** get the
scope. It lives on the Statistics tab and is descriptive.

### The `is_planned` fix

`Dives.isPlanned` (`database.dart:776`) is set by the dive planner for dives
that have not happened. No statistics or aggregate query filters on it today, so
planned dives currently inflate every total. Folding `is_planned = 0` into the
scope predicate fixes this in one line.

This changes existing users' numbers on upgrade with no action on their part and
requires an explicit release note.

## Section 3: UI and localization

**Dive edit form.** A collapsible "Statistics" group at the bottom of the
form (`_buildStatisticsSection`, rendered after the contextual groups and
before the AddSectionRow), holding the two toggles.

The toggles first shipped as two rows at the end of `_buildTheDiveSection`,
on the reasoning that the group holding dive number, date, site and depth is
where a flag about how the dive is counted belongs. In practice they read as
clutter inside an always-expanded group of core facts, so they moved into
their own collapsible group instead, matching the other expandable ones. The
group is collapsed unless the dive is already excluded, and its header carries
the state: an "Excluded" or "Gas excluded" summary, or the fainter "Counted in
every statistic" hint. Nothing in the group is a validated field, so it does
not join the sections `_saveDive` force-expands before `Form.validate()`.

The gas checkbox renders disabled and checked while the master flag is on, so
the implication is visible rather than surprising.

Note that `isFavorite` is only a partial precedent. It is read in the edit page
at line 4961 but never edited there; favoriting happens from the list item and
detail app bar. There is no existing dive level boolean checkbox in the edit
form to copy.

**Bulk edit.** Two new `BulkField` entries alongside `BulkField.isFavorite`
(`dive_edit_page.dart:1056`), wrapped in the same gate widget so an untouched
field stays untouched rather than writing `false` over every selected dive.
This is what makes #526 practical: thirty pool sessions get excluded in one
operation.

**Badges.** A marker on the dive list item and the dive detail page. Icon plus
tooltip rather than a text chip, because list rows are dense and the Ahem test
font overflows unconstrained `Row` plus `Text` at narrow widths.

**Statistics footnote.** A line in the Statistics tab reading "N dives excluded
from statistics", backed by a count query that inverts the scope predicate.
Renders only when N is nonzero. This is what prevents a "247 here, 248 there"
support ticket months later.

**Filter axis.** `DiveFilterState` gains `excludedFromStatsOnly` as a `bool?`,
mirroring `favoritesOnly` (`dive_filter_state.dart:18`): null means no
filtering, true means only excluded dives. Three implementations must stay in
sync:

1. `buildFilteredDiveIdSubquery` (`dive_filter_sql.dart:12`)
2. `DiveRepository._buildFilterWhereClauses` (`dive_repository_impl.dart:2293`)
3. `DiveFilterState.apply()` (`dive_filter_state.dart:263`)

**Localization.** New keys for both checkbox labels, their help text, the badge
tooltip, the bulk edit field labels, the filter axis label, and the statistics
footnote. Translated across all eleven locales: `ar de en es fr he hu it nl pt
zh`. English only would fail `arb_parity_test` against every other locale.

## Section 4: Testing

TDD, tests first. Two layers, because correctness and completeness are separate
problems.

### Layer 1: behavioral guard suite

`test/features/statistics/dive_stats_scope_test.dart`. One fixture seeds five
dives: normal, `excludedFromStats`, `excludedFromGasStats`, planned, and gauge
mode. A table driven list calls every descriptive aggregate from section 2 and
asserts the right dives are absent. This proves the roughly 45 edits work.

### Layer 2: source census

`test/core/database/dive_stats_scope_census_test.dart`. Reads the repository
sources and asserts that every `customSelect` referencing `FROM dives` either
contains `excluded_from_stats` or appears in an explicit, commented exemption
list.

Layer 1 alone cannot prevent rot, because it only tests the queries someone
remembered to add to the list. The census test catches the next engineer adding
a 46th aggregate: their query fails a test that names the decision they have to
make. This is exactly the failure mode `dive_mode <> 'gauge'` already
demonstrates, with seven hand copied predicates and no mechanism ensuring an
eighth query would get it.

### Migration tests

- v177 to v178 adds both columns defaulting to 0.
- The `beforeOpen` backstop is idempotent across two consecutive opens.
- A minimal schema fixture with no `dives` table returns early instead of
  throwing.

### Filter parity

The three implementations of `excludedFromStatsOnly` agree on one fixture set.
The repo has precedent for an axis only some paths can evaluate (`decoOnly` is
SQL only and skipped by `apply()`); this axis is evaluable everywhere, so no
exemption is needed.

### Round trips

- Sync export and adopt preserve both flags. Generated serializer, so this is a
  regression guard.
- UDDF export and import preserve both flags. Hand plumbed, so this test earns
  its place.

### Widget tests

- Edit form toggles persist.
- The gas checkbox disables when the master flag is on.
- The bulk edit gate leaves untouched fields untouched.
- The badge renders on list item and detail page.
- The statistics footnote appears and hides correctly.

## Risks

**Existing tests will break, by design.** Any test seeding a planned dive and
expecting it in statistics now fails. Those failures are the `is_planned` fix
working. Each needs individual review rather than a blanket update, because a
genuine regression could hide among them.

**Schema rung collision.** A rung claimed below main's scalar merges with no
conflict marker and its step silently never runs. Re-run both claim scans
immediately before pushing.

**Release note required.** The `is_planned` fix changes existing users' totals
on upgrade with no action on their part.

## Verification before the PR

- `dart format .`
- `flutter analyze` across the whole project, infos treated as fatal
- One full test suite run
