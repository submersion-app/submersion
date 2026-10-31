# Insights links to dives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task, inline in one session. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** Every Insights chart that counts dives by category opens exactly the
dives behind each number (#3805).

**Architecture:** Every link resolves the dives a number counted to a list of ids
at tap time and opens the dive list with `diveIds` plus a chip label. Categories an
existing filter can state go through one repository method; the rest take ids from
the chart's own classifier or binning. Bars and slices mark first and open from a
strip; rows open with one tap.

**Tech Stack:** Flutter, Riverpod, Drift, fl_chart 1.1.1, ARB localization.

**Spec:** [docs/design/specs/2026-10-30-insights-links-to-dives-design.md](../specs/2026-10-30-insights-links-to-dives-design.md)

## Global Constraints

- The list opened holds exactly the dives the number counted, under the Insights
  filter at the moment of the tap. Excluded and planned dives are out.
- Ids come from the chart's own rule, never a second copy of it.
- A row carries the stable key the count was grouped on, not its display label.
- Tests that touch paths use `p.join`. Strings go in all 11 ARB files, translated.
- No file passes 800 lines. `stat_charts.dart` is at 786.
- After each task: `dart format .`, `flutter analyze`, the task's tests. After any
  task adding files under `lib/`: `flutter test test/architecture test/shared`.

## Review Focus

Each line's test lives in the task named.

- A chart's data changes while a row is marked, leaving the index past the end:
  the mark and strip clear, with no range error (Task 3).
- The Overview depth pie drops empty buckets from its sections, so a slice index
  is not a bucket index: tapping a slice opens that slice's bucket (Task 6).
- Tapping after the dives are gone (deleted in another tab) yields no ids: a
  message shows, and no empty list opens (Task 2).
- The page closes during the load: nothing throws and nothing is pushed (Task 2).
- Two divers share the database: the ids hold only the current diver's dives
  (Task 2).

---

### Task 1: Name the list of dives on its chip

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/dive_log/query/dive_filter_query.dart`
- Modify: `lib/features/dive_log/presentation/widgets/active_filter_chips.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files) and generated localizations
- Test: `test/features/dive_log/domain/models/dive_filter_state_test.dart`,
  `test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`,
  `test/features/dive_log/data/repositories/dive_repository_dive_ids_filter_test.dart`
  (create; first find each existing test file's real name with `git ls-files`)

**Interfaces:**
- Produces: `DiveFilterState.diveIdsLabel` (`String?`), and
  `copyWith(String? diveIdsLabel, ...)`, where `clearDiveIds: true` clears it too.

- [ ] **Step 1: Write failing tests**
  - `diveIdsLabel takes part in equality`: two states with the same ids and
    different labels are not equal, and hash differently.
  - `clearing the dive ids clears the label`.
  - `a label alone is no axis`: `DiveFilterState(diveIdsLabel: 'x').hasActiveFilters`
    is false.
  - `a named list of dives shows its label and count`: the chip for
    `diveIds: ['a', 'b'], diveIdsLabel: 'Cloud cover: Clear'` reads
    `Cloud cover: Clear (2)`; removing it leaves both fields empty.
  - `an unnamed list keeps its chip`: reads `2 dives`.
  - `a row of 5,000 dive ids reaches the list and its count`: insert 5,000 dives,
    filter on all ids, expect `getDiveCount` 5,000 and `getDiveSummaries` a full
    first page.
- [ ] **Step 2: Run them and see them fail**

Run: `flutter test` on the three files. Expected: compile failure on
`diveIdsLabel`.

- [ ] **Step 3: Add the field**

Doc comment says it names [diveIds] on the chip and filters nothing. Add it to the
constructor, `==`, `hashCode` and `copyWith`. In `dive_filter_query.dart`, beside the
`diveIds` lowering, add a comment naming `diveIdsLabel` as chip-only, because
`dive_filter_query_census_test` requires every field's name in that file.

- [ ] **Step 4: Add the string and the chip**

`diveLog_filterChip_namedDives`, placeholders `label` (String), `count` (int):
`{label} ({count})` in every locale, `{label}（{count}）` in zh. Run
`flutter gen-l10n`. In `active_filter_chips.dart`, the `diveIds` chip uses it when
`diveIdsLabel` is set.

- [ ] **Step 5: Run the tests, then the census**

Run: the three files plus `test/features/dive_log/query/`. Expected: PASS.

- [ ] **Step 6: Commit**

`feat(dive-log): name a list of dives on its filter chip`

---

### Task 2: One way to open a chart's dives

**Files:**
- Rename: `lib/features/insights/presentation/insights_place_dives.dart` to
  `lib/features/insights/presentation/insights_dive_filters.dart`, and its test to
  `test/features/insights/presentation/insights_dive_filters_test.dart`
- Create: `lib/features/insights/presentation/open_chart_dives.dart`
- Create: `lib/features/insights/data/repositories/insights_repository_chart_dives.dart`
  (a `part` of `insights_repository.dart`)
- Modify: `lib/features/insights/presentation/pages/insights_geographic_page.dart`,
  `lib/features/insights/presentation/widgets/calendar_day_matrix_card.dart`
- Modify: `lib/l10n/arb/app_*.arb` and generated localizations
- Test: `test/features/insights/data/repositories/insights_repository_chart_dives_test.dart`
  (create), `test/features/insights/presentation/open_chart_dives_test.dart`
  (create), and the existing geographic page and calendar card tests

**Interfaces:**
- Produces, in the repository part:
  `Future<List<String>> getCountedDiveIds({String? diverId, DiveFilterState filter = const DiveFilterState(), bool gas = false})`
- Produces, in `open_chart_dives.dart`:

```dart
typedef ChartDiveIdsLoader = Future<List<String>> Function(
  InsightsRepository repository,
  String? diverId,
  DiveFilterState scope,
);

Future<void> openChartDives(
  BuildContext context,
  WidgetRef ref, {
  required String chart,
  required String row,
  required ChartDiveIdsLoader load,
});
```

- [ ] **Step 1: Write failing tests**

Repository, using `setUpTestDatabase` as `insights_place_dives_test.dart` does:
  - `counted ids leave out excluded and planned dives`.
  - `counted ids hold only the current diver's dives`.
  - `counted ids follow the Insights filter`.
  - `a gas count also leaves out gauge dives and dives excluded from gas stats`.
  - Rewrite the existing country and region parity test so it compares each row's
    `count` with `getCountedDiveIds(filter: countryDivesFilter(...)).length`, with
    an excluded dive and a planned dive at that country.

`openChartDives`, with a fake repository through the provider override:
  - `opens the list with the ids and a named label`: `diveFilterProvider` holds
    `diveIds` from `load` and `diveIdsLabel` `Water type: Salt`, and no other axis.
  - `an empty result shows a message and opens nothing`.
  - `a failed load shows a message and opens nothing`.
  - `a page closed during the load pushes nothing`: complete `load` after the
    widget is disposed; no exception and no push.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Add `getCountedDiveIds`**

`SELECT d.id FROM dives d WHERE 1=1 <diver> <_diveFilter(filter, alias: 'd', gas: gas)>`.
Add the `part` directive. Mark nothing `stats-scope-exempt`: it applies the scope.

- [ ] **Step 4: Add strings**

`insights_chart_linkLabel`, placeholders `chart`, `row` (String): `{chart}: {row}`,
in fr `{chart} : {row}`, in zh `{chart}：{row}`.

`insights_chart_openDivesFailed`: en `Could not open these dives`, de
`Diese Tauchgänge konnten nicht geöffnet werden`, es
`No se pudieron abrir estas inmersiones`, fr `Impossible d'ouvrir ces plongées`,
it `Impossibile aprire queste immersioni`, nl `Deze duiken konden niet worden
geopend`, pt `Não foi possível abrir estes mergulhos`, hu
`Nem sikerült megnyitni ezeket a merüléseket`, ar `تعذر فتح هذه الغطسات`, he
`לא ניתן לפתוח צלילות אלה`, zh `无法打开这些潜水记录`. Check ar, he and zh against the
words those ARBs already use for "dive".

- [ ] **Step 5: Implement `openChartDives`**

Read `insightsRepositoryProvider`, `currentDiverIdProvider` and
`insightsFilterProvider` before the await. Await `load` in try/catch. Bail on
`!context.mounted`. Empty or failed: a plain SnackBar with
`insights_chart_openDivesFailed`. Otherwise call
`openDiveList(context, ref, DiveFilterState(diveIds: ids, diveIdsLabel: l10n.insights_chart_linkLabel(chart, row)))`.

- [ ] **Step 6: Convert countries, regions and calendar days**

Delete `openInsightsDives`. Each caller becomes `openChartDives` with `chart` set to
the card's title, `row` to the row's name or formatted date, and `load` calling
`repo.getCountedDiveIds(diverId: id, filter: countryDivesFilter(scope, name))`.
Rewrite the doc comments in `insights_dive_filters.dart` that say the list also
shows excluded dives.

- [ ] **Step 7: Run all affected tests**

Run: `flutter test test/features/insights/presentation test/features/insights/data`.
Expected: PASS.

- [ ] **Step 8: Commit**

`feat(insights): open a chart's dives from a resolved list of ids`

---

### Task 3: Charts that mark a bar or slice, then open it

**Files:**
- Create: `lib/features/insights/presentation/widgets/category_bar_chart.dart`
  (moved from `stat_charts.dart`)
- Create: `lib/features/insights/presentation/widgets/distribution_pie_chart.dart`
  (moved from `stat_charts.dart`)
- Create: `lib/features/insights/presentation/widgets/chart_selection_strip.dart`
- Modify: `lib/features/insights/presentation/widgets/stat_charts.dart` (add
  `export` lines for both moved widgets, so importers do not change)
- Modify: `lib/features/insights/presentation/widgets/horizontal_category_bar_chart.dart`
- Modify: `lib/l10n/arb/app_*.arb` and generated localizations
- Test: `test/features/insights/presentation/widgets/chart_selection_test.dart`
  (create), `horizontal_category_bar_chart_test.dart`

**Interfaces:**
- Produces: `CategoryBarChart.onOpenBar`, `DistributionPieChart.onOpenSegment`,
  `HorizontalCategoryBarChart.onOpenRow`, each
  `Future<void> Function(int index)?`. Null keeps today's behaviour exactly.
- Produces: `ChartSelectionStrip({required String label, required String countText, Future<void> Function()? onOpen})`.
  Shows `label · countText`, and `View dives` with a chevron when `onOpen` is
  non-null. While `onOpen` runs it shows a small spinner in place of the chevron and
  ignores further taps.

- [ ] **Step 1: Move the two charts, unchanged**

Move the code and add the exports. Run
`flutter test test/features/insights/presentation/widgets`. Expected: PASS with no
test edited. Commit as `refactor(insights): move the bar and pie charts to their own files`.

- [ ] **Step 2: Write failing tests**
  - `a tap marks a bar and shows its number and View dives`.
  - `a tap on the empty space above a short bar marks it`: bars of 1 and 300, tap
    high in the first column.
  - `tapping the marked bar clears it`, `tapping another bar moves the mark`.
  - `View dives opens the marked bar`: `onOpenBar` receives its index.
  - `a bar with no dives shows its number and no View dives`.
  - `new data clears the mark`, and
    `data shorter than the marked index clears the mark without an error`.
  - `with no callback a tap shows no strip`.
  - `a screen reader can open a non-zero bar`: a `CustomSemanticsAction` exists for
    each non-zero bar and none for a zero bar; performing it calls `onOpenBar`.
  - Pie: `a tap on a slice marks it and View dives opens it`,
    `a legend row opens in one tap and has a chevron`,
    `with no callback a legend row has no chevron`.
  - Horizontal: `a row opens in one tap and has a chevron`.

- [ ] **Step 3: Run them and see them fail**

- [ ] **Step 4: Add the strip string**

`insights_chart_viewDives`: en `View dives`, de `Tauchgänge ansehen`, es
`Ver inmersiones`, fr `Voir les plongées`, it `Vedi immersioni`, nl
`Duiken bekijken`, pt `Ver mergulhos`, hu `Merülések megtekintése`, ar
`عرض الغطسات`, he `הצגת צלילות`, zh `查看潜水记录`.

- [ ] **Step 5: Implement**

`CategoryBarChart` and `DistributionPieChart` become stateful, holding `int? _marked`
and clearing it in `didUpdateWidget` when `data` differs by `listEquals`.

- Bars: `touchCallback` on `FlTapUpEvent`. Work out the column from
  `event.localPosition.dx`, not `response.spot`, which misses empty space:
  `((dx - 44) / (width - 44) * data.length).floor()`, clamped. 44 is the reserved
  left axis already subtracted in `build`; name it. Keep `handleBuiltInTouches`, so
  hover tooltips stay. The marked bar uses the chart colour and the rest
  `withValues(alpha: 0.35)`. Set a click cursor when `onOpenBar` is set.
- Slices: `PieTouchData.touchCallback` on `FlTapUpEvent`, reading
  `response.touchedSection?.touchedSectionIndex`; ignore -1. The marked slice grows
  from radius 60 to 68.
- Strip count text: `valueFormatter?.call(count)` if given, else
  `insights_filterBar_diveCount(count)`.
- Legend and horizontal rows: `InkWell` plus `Icons.chevron_right`, inside a button
  `Semantics` whose label is the row's.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/insights/presentation/widgets`, then
`test/architecture test/shared`. Expected: PASS.

- [ ] **Step 7: Commit**

`feat(insights): mark a bar or slice and open its dives`

---

### Task 4: Charts an existing filter can state

**Files:**
- Modify: `lib/features/insights/presentation/insights_dive_filters.dart`
- Modify: `lib/features/insights/presentation/pages/insights_time_patterns_page.dart`,
  `insights_progression_page.dart`, `insights_conditions_page.dart`
- Create: `lib/features/insights/presentation/widgets/distribution_bar_row.dart`
  (`_DistributionBarRow` moved out of `insights_overview_page.dart`, public, gaining
  `VoidCallback? onTap`)
- Modify: `lib/features/insights/presentation/pages/insights_overview_page.dart`
- Test: `test/features/insights/data/repositories/insights_repository_chart_dives_test.dart`,
  and each page's test file

**Interfaces:**
- Consumes: `getCountedDiveIds`, `openChartDives`, `onOpenBar`, `onOpenSegment`.
- Produces, each returning a `DiveFilterState` built with `_withConditions`:
  `weekdayDivesFilter(scope, int dayOfWeek)` (0 is Sunday, as the chart),
  `monthDivesFilter(scope, int month)`, `yearDivesFilter(scope, int year)`,
  `diveTypeDivesFilter(scope, String typeId)`,
  `waterTypeDivesFilter(scope, String key)` and
  `entryMethodDivesFilter(scope, String key)`, where `key` is an enum name or
  `kNotRecordedDistributionKey`, which lowers to `QueryOp.isEmpty`.

- [ ] **Step 1: Write failing parity tests**

One table-driven test per chart: seed dives across categories plus one excluded and
one planned dive, read the chart's repository method, and assert
`getCountedDiveIds(filter: <builder>(scope, key)).length == row.count` for every row.
For water type and entry method include a site-inherited value and Not recorded. For
dive type include a dive with two types while the scope holds one of them, and assert
the ids are the intersection.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Implement the builders**

Condition nodes on `weekday`, `month`, `year`, `types`, `waterType`, `entryMethod`.
Always AND onto the scope: the chips do not matter here, because the ids are what
reach the list.

- [ ] **Step 4: Wire the pages and write widget tests**

Time Patterns (`onOpenBar` on Day of week and Month), Progression (Dives per year),
Conditions (`onOpenSegment` on Water type, `onOpenBar` on Entry method), Overview
(dive type rows through `DistributionBarRow.onTap`). A row's key is the value the
repository emitted (`raw[i].label`), never the localized text. One widget test per
page: tap to open, assert `diveFilterProvider` holds the ids and label.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights`. Expected: PASS.

- [ ] **Step 6: Commit**

`feat(insights): open the dives behind date, type, water and entry charts`

---

### Task 5: Conditions cards and the coverage line

**Files:**
- Modify: `lib/features/insights/domain/conditions/conditions_stats.dart`,
  `condition_bands.dart`
- Modify: `lib/features/insights/presentation/widgets/conditions/conditions_card_parts.dart`,
  `conditions_category_card.dart`, `conditions_band_card.dart`,
  `surface_weather_group.dart`, `water_movement_group.dart`,
  `site_access_condition_cards.dart`
- Modify: `lib/features/insights/presentation/pages/insights_conditions_page.dart`
  (water temperature bands)
- Test: `test/features/insights/domain/conditions/conditions_stats_test.dart`,
  `test/features/insights/presentation/widgets/conditions/`

**Interfaces:**
- Produces: `CategoryStat.counts` records gain `List<String> diveIds`;
  `BandStat.diveIdsByBand` (`List<List<String>>`, parallel to `bands`); both gain
  `List<String> unrecordedDiveIds`.
- Produces: `int bandIndexOf(double value, List<double> edges, {required int decimals})`,
  extracted from `countIntoBands`, so counting and ids share the rounding.
- Produces: `ConditionsCoverageLine.onOpenUnrecorded` (`Future<void> Function()?`)
  and the same on `ConditionsChartCard`.

- [ ] **Step 1: Write failing tests**
  - `each category holds the ids of the dives it counted`, and for bands, with a
    reading of 19.96 landing in the band displayed as 20.0.
  - `unrecorded ids are the dives with no value`.
  - `the coverage line opens the unrecorded dives`: chip label
    `Cloud cover: Not recorded`.
  - `a fully recorded card's coverage line is plain text`: no chevron, no tap.
  - `a band card marks a band and opens it`, `a category card opens a row`.
  - `a water temperature band holds the dives its bar counted`, using
    `getWaterTempBandPerDive`, in Fahrenheit and Celsius.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Implement**

`category()` and `band()` in `fromRows` build ids as they count; keep `count`
derived from the same pass. Cards take the card's `title` as the chart name and
build rows with `openChartDives(load: (_, _, _) async => ids)`. A band's row label
is the label already drawn. Water temperature bands load
`getWaterTempBandPerDive` at tap and keep the ids whose band is the tapped index.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/insights`. Expected: PASS.

- [ ] **Step 5: Commit**

`feat(insights): open the dives behind Conditions cards and their coverage`

---

### Task 6: Charts that need their own id query

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository_chart_dives.dart`,
  `insights_repository.dart` (add `DistributionSegment.key`, share each chart's
  bucketing expression)
- Create: `lib/features/dive_log/data/repositories/depth_bucket_sql.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Create: `lib/features/insights/presentation/widgets/depth_pie_card.dart`
  (`_DepthPieCard` moved out of the Overview page)
- Modify: pages `insights_overview_page.dart`, `insights_conditions_page.dart`,
  `insights_gas_page.dart`, `insights_progression_page.dart`,
  `insights_social_page.dart`
- Test: `insights_repository_chart_dives_test.dart`, page tests,
  `test/features/insights/presentation/widgets/depth_pie_card_test.dart` (create)

**Interfaces:**
- Produces: `DistributionSegment.key` (`String?`), set by
  `getSiteTypeDistribution` to `sst.site_type_id`.
- Produces in the part, each taking `String? diverId` and
  `DiveFilterState filter`:
  - `getVisibilityDiveIds({required VisibilityScale scale, required String bucket, ...})`
  - `getSiteTypeDiveIds({required String siteTypeId, ...})`
  - `getGasMixDiveIds({required String gasType, ...})`
  - `getSuitThicknessDiveIds({double? mm, required String bucket, ...})` with
    `bucket` one of `mm`, `unknown`, `drysuit`
  - `getSoloVsBuddyDiveIds({...})` returning
    `({List<String> solo, List<String> buddy, List<String> notRecorded})`
  - `getDepthBucketDiveIds({required int bucket, ...})`

- [ ] **Step 1: Write failing parity tests**

As Task 4: for each method and every row, the length equals the chart's count, with
an excluded and a planned dive present. Also:
  - Visibility: a range spanning two bands, and a legacy bucket.
  - Site type: two custom types with the same name stay separate.
  - Gas mix: a dive with an air back gas and a nitrox deco tank is in both; a gauge
    dive and a dive excluded from gas stats are in neither.
  - Suit thickness: a wetsuit with no thickness and a drysuit.
  - Solo: a legacy free-text buddy counts as buddy; a Solo role with no buddy as
    solo.
  - Depth: 9.99 m in the first bucket, 10 m in the second, 131 m in the open one.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Implement, sharing each rule**

- Visibility: extract the `SELECT CASE ...` inner query, used by the count and the
  ids.
- Gas mix: extract the `CASE` as a const; the ids query selects `DISTINCT d.id`
  under `_diveFilter(gas: true)`.
- Suit thickness: extract the join and `CASE`.
- Solo: extract the per-dive inner query and classify with `_focusBuddyKey`.
- Depth: move `depthBucketSizeMeters`, `depthBucketCount` and the bucket expression
  to `depth_bucket_sql.dart`. The ids query uses `d.max_depth IS NOT NULL` and
  `_diveFilter`. First confirm from the parity test that the scope of
  `getStatistics` matches `_diveFilter`; if it does not, resolve the ids from that
  method's scope.

- [ ] **Step 4: Wire the pages**

Site type and gas mix rows use `onOpenRow`; visibility and solo vs buddy
`onOpenSegment`; suit thickness `onOpenBar`. Solo vs buddy builds its segments
conditionally, so the index maps through the same conditional list.

Move `_DepthPieCard` to its own file and give it marking and the strip. Its sections
drop empty buckets, so keep a parallel list of bucket indexes. Test
`a slice opens its own bucket when an earlier bucket is empty`. Depth legend rows and
`DistributionBarRow` rows open in one tap.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights test/features/dive_log/data`, then
`test/core/database/dive_stats_scope_census_test.dart` and `test/architecture`.
Expected: PASS.

- [ ] **Step 6: Commit**

`feat(insights): open the dives behind depth, gas, suit, site and buddy charts`

---

### Task 7: Tank configuration and time of day

**Files:**
- Modify: `lib/features/insights/domain/tank_configuration/tank_configuration.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository_tank_configuration.dart`,
  `insights_repository_time_of_day.dart`
- Modify: `lib/features/insights/presentation/widgets/tank_configuration_card.dart`,
  `lib/features/insights/presentation/pages/insights_time_patterns_page.dart`
- Test: `test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`,
  the repository's tank and time of day tests, card and page tests

**Interfaces:**
- Produces: `TankConfigurationDive.diveId` (required `String`);
  `TankConfigurationStats.baseDiveIds` (`Map<TankBaseConfiguration, List<String>>`)
  and `extraDiveIds` (`Map<TankConfigurationExtra, List<String>>`).
- Produces: `TimeOfDayDistribution.diveIdsByBucket` (`Map<String, List<String>>`,
  keyed like `DistributionSegment.label`). `empty` holds `const {}`.

- [ ] **Step 1: Write failing tests**
  - `each configuration holds the ids it counted`; `a dive with two extras is in
    both`; the counts stay the ones the card shows.
  - `each time of day holds the ids it counted`.
  - `a tank row opens its dives`, labelled `<card title>: <row>`.
  - `a time of day slice marks, then opens`.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Implement**

`TankConfigurationStats.fromDives` and `getDivesByTimeOfDay` add each dive's id as
they classify it, so the ids cannot drift from the counts. Include the new fields in
the stats class's `props`. Sort rows as today; keep a parallel key list so a row's
index finds its key after the sort.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/insights`. Expected: PASS.

- [ ] **Step 5: Commit**

`feat(insights): open the dives behind tank configuration and time of day`

---

### Task 8: Deco tiles

**Files:**
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart`
- Modify: `lib/features/insights/presentation/pages/insights_profile_page.dart`
- Test: `test/features/insights/presentation/pages/insights_profile_deco_legend_test.dart`
  or a new `insights_profile_deco_links_test.dart`

**Interfaces:**
- Produces: `decoDiveIdsProvider`, a `FutureProvider` of
  `({List<String> deco, List<String> noDeco, List<String> unknown})`, holding the
  loop now in `decoObligationStatsProvider`, which becomes the three lengths of it.

- [ ] **Step 1: Write failing tests**
  - `the deco counts are the lengths of the deco ids`, with a computed-fallback dive
    in the mix.
  - `the Deco tile opens its dives`, `the No deco tile opens its dives`,
    `the not recorded hint opens its dives`, each with a one-tap chevron.
  - `the deco rate tile opens nothing`.

- [ ] **Step 2: Run them and see them fail**

- [ ] **Step 3: Implement**

Split the provider. Tiles and the hint use `InkWell` with button `Semantics`, and
`openChartDives` with `load` reading `ref.read(decoDiveIdsProvider.future)`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/insights`. Expected: PASS.

- [ ] **Step 5: Commit**

`feat(insights): open the dives behind the deco tiles`

---

### Task 9: User docs and the full check

**Files:**
- Modify: `docs/user/statistics.md`

- [ ] **Step 1: Update the docs**

Remove the statement near line 201 that excluded dives appear in the list a cell
opens. Add a short section on opening a chart's dives: a tap marks a bar or slice,
`View dives` opens it, rows open at once, the coverage line opens the unrecorded
dives, and the list is a snapshot of the dives counted.

- [ ] **Step 2: Run the docs check**

Run: `python3.14 scripts/check_docs_links.py`. Expected: no findings.

- [ ] **Step 3: Run the wide checks**

Run: `dart format .`, `flutter analyze`,
`flutter test test/features/insights test/features/dive_log test/architecture test/shared test/l10n`.
Expected: analyze clean, tests PASS.

- [ ] **Step 4: Commit**

`docs(user): opening the dives behind a chart`
