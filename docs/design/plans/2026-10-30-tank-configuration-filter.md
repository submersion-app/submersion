# Tank Configuration Filter Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans, in one
> session, with no subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver tap any bar on the Tank configuration card and see exactly
the dives it counted, and filter by configuration in Refine and typed search.

**Architecture:** The existing Dart classifier is registered as two SQL functions,
fed per dive by correlated subqueries. The chart and every filter read that one
expression, so they cannot disagree. New query fields sit on it, two new
`DiveFilterState` axes lower to those fields, and a tapped bar adds query
conditions through `_withConditions`.

**Tech Stack:** Flutter, Riverpod, Drift, SQLite/SQLCipher, the #2365 query engine.

**Spec:** [docs/design/specs/2026-10-30-tank-configuration-filter-design.md](../specs/2026-10-30-tank-configuration-filter-design.md)

> **Changed during the build:** `tank_config_extras` became `tank_config_summary`
> (`tankConfigSummarySql`, `decodeTankConfigSummary`), one value holding the base
> and extras. With two functions the chart classified each dive at least twice,
> about 340 ms over 10,000 dives on the Gas page; the summary takes about 110 ms.

## Global Constraints

- No em-dashes anywhere. No mention of any AI tool in commits, code or docs.
- Paths through `p.join`. A test that changes process-wide state restores it.
- `dart format .` after each task. Stage explicit paths, never a directory.
- Every test that compiles these fields needs a connection with
  `registerAppSqlFunctions`; `setUpTestDatabase` already passes it.
- RED checks run one file per run; a non-compiling file hangs a multi-file run.
- Log test runs to the scratchpad, never to a shared `$TMPDIR` name.
- A full count over 10,000 dives on a real database taking more than 250 ms means
  stop and raise it.
- `.arb` edits anchor on a neighbouring key of the same group, in all 11 locales:
  en, ar, de, es, fr, he, hu, it, nl, pt, zh. Then `flutter gen-l10n`.

## Review Focus

1. **Bad stored values.** A role or mode from a newer peer, a NULL `dive_mode`, or
   corrupt `shared_computer_ids` must fall back as the classifier does today. A
   throw inside a SQL function fails the whole dive list, not one row. Test in
   Task 1.
2. **Text that needs JSON escaping.** A tank name with quotes, a backslash or
   non-ASCII text (`Doppel "12"`, `Tauchgerät\2x12`) must still classify. Test in
   Task 1.
3. **Dives reached from another entity.** `{r}` is the dive's alias at any depth, so
   a site or trip query that reaches dives through a relation must compile and
   match. Test in Task 3.
4. **Rows in a right-to-left locale at large text scale.** A tappable row must not
   overflow and the whole row must take the tap. Test in Task 5.
5. **A gas switch on a cylinder the primary does not own.** It must be ignored as
   it is today, since `_breathed` only keeps switches naming kept tanks. Test in
   Task 1.

---

### Task 1: The classifier as SQL functions, and the index

**Files:**
- Modify: `lib/core/database/performance_indexes.dart` (after `idx_dive_tanks_*`)
- Create: `lib/features/insights/data/tank_configuration_sql.dart`
- Modify: `lib/core/database/app_sql_functions.dart`
- Test: `test/core/database/performance_indexes_test.dart`
- Test: `test/features/insights/data/tank_configuration_sql_test.dart`

**Interfaces:**
- Produces, all in `tank_configuration_sql.dart`:
  - `const kTankConfigBaseFunction = 'tank_config_base'`
  - `const kTankConfigExtrasFunction = 'tank_config_extras'`
  - `const List<String> kTankConfigurationTables = ['dive_tanks', 'gas_switches', 'dive_data_sources', 'dive_profile_series']`
  - `String tankConfigBaseSql(String dive)`: the base's name as text, `dive` being a
    column reference such as `{r}` or `d`
  - `String tankConfigExtrasSql(String dive)`: extras as text, comma-wrapped
    (`,stages,multiGas,`, or `,` for none)
  - `String tankConfigHasExtraSql(String dive, TankConfigurationExtra extra)`
  - `void registerTankConfigurationFunctions(CommonDatabase db)`
  - `Set<TankConfigurationExtra> decodeTankConfigExtras(String value)`

- [ ] **Step 1: Write the failing index test**

In `performance_indexes_test.dart`:
`test('gas_switches is indexed by dive', ...)` asserts `kPerformanceIndexes` holds
an entry named `idx_gas_switches_dive_id`, and that on a fresh test database
`sqlite_master` holds that index on `gas_switches`.

- [ ] **Step 2: Add the index and see it pass**

Add `idx_gas_switches_dive_id` as
`CREATE INDEX IF NOT EXISTS idx_gas_switches_dive_id ON gas_switches(dive_id)`.
Run: `flutter test test/core/database/performance_indexes_test.dart`
Expected: all pass.

- [ ] **Step 3: Write the failing classifier parity test**

`tank_configuration_sql_test.dart` uses `setUpTestDatabase`, seeds dives and calls
`SELECT ${tankConfigBaseSql('d')} AS base, ${tankConfigExtrasSql('d')} AS extras
FROM dives d WHERE d.id = ?`. Cases, each asserting the SQL result equals
`classifyTankConfiguration` of the same data built by hand:

- Every base: rebreather by mode, rebreather by diluent role, sidemount, twin by
  matched pair, twin by 22 L, twin by `D12`, single, other (only a stage role), no
  tanks.
- Every extra: stages, deco gas, multi-gas by pressure drop, multi-gas by switch, a
  hand-logged dive with no profile, and a recorded dive on one gas with a second
  unused gas (not multi-gas).
- `unknown role reads as back gas` and `unknown mode reads as open circuit`.
- `corrupt shared_computer_ids does not throw`.
- `tank names needing JSON escaping still classify`: `Doppel "12"`,
  `Tauchgerät\2x12`.
- `a primary owning none keeps every cylinder`, and a consolidated dive where only
  the primary's cylinders count.
- `a gas switch on a cylinder the primary does not own is ignored`.
- `tanks are read in tank_order`: insert out of order, and assert the starting
  cylinder is the lowest order.
- `decodeTankConfigExtras(',') == {}`, and `(',stages,multiGas,')` gives both.

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/features/insights/data/tank_configuration_sql_test.dart`
Expected: compile failure on the missing file.

- [ ] **Step 5: Implement `tank_configuration_sql.dart`**

The six arguments, in this order, for both functions:

```dart
String _argsSql(String dive) =>
    '$dive.dive_mode, '
    'EXISTS (SELECT 1 FROM dive_profile_series s '
    'WHERE s.dive_id = $dive.id AND s.is_primary = 1), '
    '(SELECT id FROM dive_data_sources '
    'WHERE dive_id = $dive.id AND is_primary = 1 LIMIT 1), '
    '(SELECT computer_id FROM dive_data_sources '
    'WHERE dive_id = $dive.id AND is_primary = 1 LIMIT 1), '
    '(SELECT json_group_array(json_array(t.id, t.tank_role, t.volume, '
    't.start_pressure, t.end_pressure, t.o2_percent, t.he_percent, t.tank_order, '
    't.tank_name, t.preset_name, t.computer_id, t.shared_computer_ids, '
    't.source_id)) FROM dive_tanks t WHERE t.dive_id = $dive.id), '
    '(SELECT json_group_array(json_array(g.tank_id, g.timestamp)) '
    'FROM gas_switches g WHERE g.dive_id = $dive.id)';
```

Decode in Dart and sort tanks by `order` there (stable, using `sortedBy`), so no
SQL ordering is relied on. Numbers go through `(x as num?)?.toDouble()`, since JSON
can hand back an int for a REAL column. Copy `_ownedByPrimary`, the "primary owns
none keeps every cylinder" rule and both name maps from
`insights_repository_tank_configuration.dart` into this file with their doc
comments; the repository keeps compiling on its own copies until Task 2 deletes
them. A NULL mode reads as open circuit.

Register both with `argumentCount: AllowedArgumentCount(6)` and
`deterministic: true`. `tankConfigHasExtraSql` is
`instr(<extras sql>, ',${extra.name},') > 0`.

- [ ] **Step 6: Register from `registerAppSqlFunctions`**

Call `registerTankConfigurationFunctions(db)` there. Rewrite the "No Flutter
imports" line of the library comment: the classifier's imports reach `dart:ui`, so
this file now needs the Flutter engine's libraries, which the drift worker isolate
has because it runs in the app's process.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/insights/data/tank_configuration_sql_test.dart`
Expected: all pass. `json_group_array` passing here proves the SQLCipher build
selected in `pubspec.yaml` has JSON, since tests load the same library.

- [ ] **Step 8: Commit**

```bash
git add lib/core/database/performance_indexes.dart lib/core/database/app_sql_functions.dart lib/features/insights/data/tank_configuration_sql.dart test/core/database/performance_indexes_test.dart test/features/insights/data/tank_configuration_sql_test.dart
git commit -m "feat(insights): classify tank configuration in SQL"
```

### Task 2: The chart reads through the same expression

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository_tank_configuration.dart`
- Modify: `lib/features/insights/domain/tank_configuration/tank_configuration.dart`
- Modify: `test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`

**Interfaces:**
- Consumes: `tankConfigBaseSql`, `tankConfigExtrasSql`, `decodeTankConfigExtras`.
- Produces: `factory TankConfigurationStats.fromGroups(Iterable<TankConfigurationGroup> groups)`
  and `typedef TankConfigurationGroup = ({TankConfigurationResult result, int dives})`.
  `TankConfigurationStats.fromDives` is removed.

- [ ] **Step 1: Swap the domain test onto `fromGroups`**

In the classifier test add a local `statsOf(dives)` that maps each dive to a group
of 1, and replace `fromDives` calls with it. Add
`test('fromGroups adds each group under its base and every extra')`: groups of 3
and 2 sharing a base give `totalDives == 5`, that base `5` and each extra its own
group's count.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`
Expected: compile failure on `fromGroups`.

- [ ] **Step 3: Implement `fromGroups`, then replace the repository body**

One query, keeping `_diveFilter(filter, alias: 'd')`:

```sql
SELECT ${tankConfigBaseSql('d')} AS base, ${tankConfigExtrasSql('d')} AS extras,
  COUNT(*) AS dives
FROM dives d WHERE 1=1 $diverFilter ${df.clause}
GROUP BY base, extras
```

Base names decode through `TankBaseConfiguration.values.byName`. Delete
`_tankConfigurationDive`, `_ownedByPrimary` and both name maps from the part file.

- [ ] **Step 4: Run the unchanged repository tests**

Run: `flutter test test/features/insights/data/repositories/insights_repository_tank_configuration_test.dart`
Expected: all pass with no edit to that file. `git diff --stat` must not list it.

- [ ] **Step 5: Run the classifier test**

Run: `flutter test test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/data/repositories/insights_repository_tank_configuration.dart lib/features/insights/domain/tank_configuration/tank_configuration.dart test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart
git commit -m "feat(insights): count tank configurations through the SQL classifier"
```

### Task 3: Typed search fields

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart`
- Modify: `lib/features/query/presentation/query_label_lookup.dart`
- Modify: `lib/features/query/presentation/app_query_labels.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, plus generated `app_localizations*.dart`
- Test: `test/features/dive_log/query/dive_query_tank_configuration_test.dart`

**Interfaces:**
- Consumes: `tankConfigBaseSql('{r}')`, `tankConfigHasExtraSql('{r}', extra)`,
  `kTankConfigurationTables`.
- Produces: query field keys `tankConfig`, `stages`, `decoGas`, `multiGas`. Enum
  values are `TankBaseConfiguration.values` names; boolean field keys equal
  `TankConfigurationExtra` names, which Task 5 relies on.

- [ ] **Step 1: Write the failing test**

Using `setUpTestDatabase` and the parser, seed one dive per configuration and
assert the matching ids for:

- `tankConfig:sidemount` parsed from text, and a `QueryOp.inList` condition on
  sidemount and rebreather built as a node.
- `tankConfig:none` finds the no-tanks dive and not a rebreather dive with no tank
  rows; `gasCount:none` finds both.
- `tankConfig:any` is the exact complement of `tankConfig:none`.
- `stages:true`, `stages:false`, `decoGas:true`, `multiGas:true`, and `deco:true`
  stays a different field from `decoGas:true`.
- `a site query reaching dives through a relation compiles and matches`: use the
  site entity's dive relation, so `{r}` is not the root alias.
- `tankConfig` declares every table in `kTankConfigurationTables`, through
  `diveFilterTablesTouched`.
- `enumValue` gives `Single backmount` for `singleBackmount` (read
  `app_query_labels.dart` `enumValue` through an `AppLocalizations` of `en`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_query_tank_configuration_test.dart`
Expected: FAIL on unknown field `tankConfig`.

- [ ] **Step 3: Add the fields**

`tankConfig` beside `gasCount`: `FieldType.enumName`, `sql` from
`tankConfigBaseSql('{r}')`, `emptySql` is that plus ` = 'noTanks'`, `enumValues:
_names(TankBaseConfiguration.values)`, `tables: kTankConfigurationTables`.
A private `_tankExtra(String key, TankConfigurationExtra extra)` builds the three
booleans in the shape of `deco`, with `whenFalse` being `NOT (...)`.

- [ ] **Step 4: Add labels**

ARB keys beside `query_dives_gasCount`: `query_dives_tankConfig` "Tank
configuration", `query_dives_stages` "Stage(s)", `query_dives_decoGas` "Deco gas",
`query_dives_multiGas` "Multi-gas", translated per locale. Add the four cases to
`query_label_lookup.dart`, and a `query_dives_tankConfig` arm to `enumValue` using
`tankBaseConfigurationLabel`. Run `flutter gen-l10n`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/query/dive_query_tank_configuration_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/query/dive_query_entity.dart lib/features/query/presentation/query_label_lookup.dart lib/features/query/presentation/app_query_labels.dart lib/l10n/arb test/features/dive_log/query/dive_query_tank_configuration_test.dart
git commit -m "feat(dive-log): search dives by tank configuration"
```

### Task 4: Filter axes, Refine rows and active chips

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/dive_log/query/dive_filter_query.dart`
- Modify: `lib/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart`
- Modify: `lib/features/dive_log/presentation/widgets/active_filter_chip_labels.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, plus generated `app_localizations*.dart`
- Test: `test/features/dive_log/domain/models/dive_filter_state_test.dart`
- Test: `test/features/dive_log/query/dive_filter_query_test.dart`
- Test: `test/features/dive_log/query/dive_filter_save_census_test.dart`
- Test: `test/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group_test.dart`
- Test: `test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`

**Interfaces:**
- Consumes: query fields from Task 3; `tankBaseConfigurationLabel`,
  `tankConfigurationExtraLabel`.
- Produces: `DiveFilterState.tankConfigurations` (`List<TankBaseConfiguration>`,
  default empty), `DiveFilterState.tankExtras` (`List<TankConfigurationExtra>`,
  default empty), `copyWith` flags `clearTankConfigurations`, `clearTankExtras`.

- [ ] **Step 1: Write the failing tests**

- State: equality and `hashCode` differ on each new list, `copyWith` and both clear
  flags, `activeAxisCount` counts each axis once.
- Query: one configuration lowers to `tankConfig inList [sidemount]`; extras
  `[stages]` to a lone `stages eq true`; extras `[stages, decoGas]` to an `OrNode`;
  both axes set are ANDed.
- Save census: add `'tankConfigurations'` and `'tankExtras'` samples to `samples`,
  including two values each.
- Refine: both labelled rows show every option with nothing selected; tapping
  Sidemount then Rebreather holds both; tapping again removes; `activeCount` counts
  each axis once.
- Active chips: one value shows its label, two show the count text, and removing
  the chip clears that axis.

- [ ] **Step 2: Run them to verify they fail**

Run each file alone, for example:
`flutter test test/features/dive_log/domain/models/dive_filter_state_test.dart`
Expected: compile failure on `tankConfigurations`.

- [ ] **Step 3: Add the fields and lowering**

Follow `waterTypes` through the constructor, `activeAxisCount`, `==`, `hashCode`
and `copyWith`. Lower as the spec's Filter axes section says, placing it next to
the water types block.

- [ ] **Step 4: Add the Refine rows**

After the Gas mix `Wrap`, add a `RefineSubLabel` and a `Wrap` of `FilterChip`s for
each axis, in this order, not enum order: Single backmount, Twin backmount,
Sidemount, Rebreather, Other, No tanks logged; then Stage(s), Deco gas, Multi-gas.
Add both names to `fields` and two entries to `activeCount`.

- [ ] **Step 5: Add the active chips and strings**

Following the water types block. ARB keys: `diveLog_filter_sectionTankConfiguration`
"Tank configuration", `diveLog_filter_sectionTankExtras` "Tank extras",
`diveLog_filterChip_tankConfigCount` "{count} tank configurations",
`diveLog_filterChip_tankExtrasCount` "{count} tank extras". Run `flutter gen-l10n`.

- [ ] **Step 6: Run the tests and guards**

Run each test file above alone, then:
`flutter test test/features/dive_log/query/dive_filter_query_census_test.dart`
and `flutter test test/features/dive_log/presentation/widgets/refine/refine_axis_guard_test.dart`
Expected: all pass.

- [ ] **Step 7: Commit**

Stage each path above explicitly, then:

```bash
git commit -m "feat(dive-log): filter dives by tank configuration in Refine"
```

### Task 5: Tappable bars

**Files:**
- Modify: `lib/features/insights/presentation/insights_place_dives.dart`
- Modify: `lib/features/insights/presentation/widgets/horizontal_category_bar_chart.dart`
- Modify: `lib/features/insights/presentation/widgets/tank_configuration_card.dart`
- Test: `test/features/insights/presentation/insights_place_dives_test.dart`
- Test: `test/features/insights/presentation/widgets/horizontal_category_bar_chart_test.dart`
- Test: `test/features/insights/presentation/widgets/tank_configuration_card_test.dart`

**Interfaces:**
- Consumes: query field keys from Task 3.
- Produces: `DiveFilterState tankConfigDivesFilter(DiveFilterState scope, TankBaseConfiguration configuration)`,
  `DiveFilterState tankExtraDivesFilter(DiveFilterState scope, TankConfigurationExtra extra)`,
  and `final void Function(int index)? onRowTap` on `HorizontalCategoryBarChart`.

- [ ] **Step 1: Write the failing tests**

- Filters: `tankConfigDivesFilter` keeps the scope and its query becomes an
  `AndNode` of `tankConfig eq sidemount`, `planned eq false`,
  `excludedFromStats eq false`, after any query the scope already had. The extra
  version uses the boolean field set true. A scope with `tankExtras: [stages]`
  stays on the axis while the tapped extra is ANDed.
- Chart: with no `onRowTap` there is no `InkWell` and no button semantics. With one,
  tapping a row reports its index, each row is at least `kMinInteractiveDimension`
  tall, and the row reads as a button labelled `Sidemount, 6 · 60%`.
- Chart: `in Arabic at 2x text scale a row does not overflow and takes the tap`.
- Card: copy the `GoRouter` host from `calendar_day_matrix_card_test.dart`, tap a
  bar whose count sort moved it (Sidemount above Single backmount) and assert
  `container.read(diveFilterProvider)` carries `tankConfig eq sidemount`, so the
  mapping survived the sort. The same for an extra.

- [ ] **Step 2: Run them to verify they fail**

Run each file alone. Expected: compile failure on the new names.

- [ ] **Step 3: Implement the filters**

Both built on `_withConditions`. One private `_countedByStats` list holds the two
false conditions, with a doc comment naming `DiveStatsScope.predicate`. Reword the
existing comment that says lists keep excluded dives, so it is scoped to the place
and calendar rows.

- [ ] **Step 4: Implement the chart row**

Wrap a row in `InkWell` plus `Semantics(button: true, label: '<label>, <count text>',
excludeSemantics: true, onTap: ...)` only when `onRowTap` is set, inside a
`ConstrainedBox` with `minHeight: kMinInteractiveDimension`. Read `_RankingTile` in
`ranking_list.dart` first and match its tappable look, including any chevron. A row
without `onRowTap` keeps today's exact layout.

- [ ] **Step 5: Wire up the card**

Give `_content` the `WidgetRef`. Have `rows()` keep the enum on each sorted entry,
derive `data` from those entries, and in `onRowTap` call `openInsightsDives` with
`ref.read(insightsFilterProvider)` through the matching filter function.

- [ ] **Step 6: Run the tests**

Run each file alone. Expected: all pass, including existing cases. The other chart
callers are untouched, so their tests need no edit.

- [ ] **Step 7: Commit**

Stage each path above explicitly, then:

```bash
git commit -m "feat(insights): open the dives behind a tank configuration bar"
```

### Task 6: Parity, freshness and the final checks

**Files:**
- Test: `test/features/insights/data/tank_configuration_parity_test.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_tank_configuration_filter_test.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the parity test**

Seed every configuration and extra, a consolidated dive with a non-primary
recording's cylinders, a primary owning none, one planned dive and one dive
excluded from statistics, reusing the seed helpers' shape from
`insights_repository_tank_configuration_test.dart`. For every bucket, unscoped and
under `DiveFilterState(minDepth: ...)` scope, `stats` count equals the filtered id
set from `buildFilteredDiveIdSubquery(tap filter)`, `DiveRepository.getDiveCount`
and `getDiveSummaries`. Then assert the Refine axis on the dive list returns those
ids plus the planned and excluded dives of that configuration.

- [ ] **Step 2: Write the tick test**

Following `dive_repository_explore_axes_filter_test.dart`, a list filtered to
`tankConfigurations: [singleBackmount]` drops a dive after a real `dive_tanks` write
turns it sidemount. Writes must go through the path that fires a change tick, not
`customStatement`, or the test passes vacuously.

- [ ] **Step 3: Run both**

Run each file alone. Expected: all pass. These cover behaviour built in Tasks 1 to
5, so a failure here is a bug to fix in that task's code, not in the test.

- [ ] **Step 4: Measure on the real schema**

A throwaway `test/zz_tank_config_bench_test.dart` on an on-disk test database with
the real schema: 10,000 dives, 2.5 tanks each, 10,000 switches, one primary source
each. Report the full count, the chart query and a page of 50 for the PR. Over
250 ms for the full count: stop and raise it. Delete the file.

- [ ] **Step 5: Confirm on the real app**

Run a macOS build from Ghostty or `open -n`, since a launch from this harness dies
on TCC. Open Insights > Gas, tap a bar, and confirm the list opens with no
`no such function` on the database worker isolate.

- [ ] **Step 6: Whole-branch checks**

Run: `dart format .`, then `flutter analyze`, then
`flutter test test/architecture/`, `flutter test test/shared/`,
`flutter test test/core/database`, `flutter test test/features/insights` and
`flutter test test/features/dive_log/query`, logging each to the scratchpad.
Expected: no analyzer output, all pass.

- [ ] **Step 7: After screenshots**

Restore `zz_tank_shots_test.dart.keep` from the scratchpad's `shots` folder to
`test/zz_tank_shots_test.dart`, run it with `--update-goldens`, copy the PNGs out
as `*-after.png`, and delete the test, `test/goldens` and `test/failures`. Add a
capture of Refine with a chip selected and of the active-filter bar.

- [ ] **Step 8: Commit**

```bash
git add test/features/insights/data/tank_configuration_parity_test.dart test/features/dive_log/data/repositories/dive_repository_tank_configuration_filter_test.dart
git commit -m "test(insights): prove tank configuration bars match their dives"
```
