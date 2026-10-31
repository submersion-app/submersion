# Tank configuration filter

Issue: #3804 (release v1.8.4). Builds on the Tank configuration card from #3421.

## Why

A diver looked at the Tank configuration card on Insights > Gas, did not believe
the figures, and asked for filters on them ("I am quite surprised by the figures
I have"). They have no way to see which dives sit behind a bar.

The surprise is reasonable. Those figures are not stored: a classifier works them
out per dive from tank roles, matched pairs on one gas, a 20 L volume rule and
name patterns such as `D12` or `2x12`. A single 22 L cylinder counts as a twin
set, and two tanks on the same gas count as doubles. The only way to judge those
calls is to look at the dives, so the point of this feature is **inspecting the
classification**, and filtering by configuration comes with it.

## Goals

1. From the card, tap any bar and see exactly the dives it counted.
2. Filter by configuration in Refine, wherever Refine is used: dive list, table,
   Insights, Connections.
3. Search for it in the typed query field, and keep it in saved searches.
4. Cover both groups on the card: the six configurations and the three extras.

## Non-goals

- Changing the classification rules.
- Correcting a misclassified dive from the list, or showing on a dive why it was
  classified the way it was.
- Statistics per configuration (the reporter hinted at a further request).
- A tank configuration column in the dive table, or teaching the Ask search about
  it.

## Anti-goals

This fails, even if it technically works, if:

- **A filter and its bar ever disagree on a dive's configuration, or a tapped bar
  opens a list that differs from its count.** A diver who distrusts a number and
  then gets a list that does not match it trusts the app less. This is why a
  simpler filter such as "has two tanks" was rejected.
- **The filtered list goes stale** after a tank is edited.
- **It slows the list for divers not using it.** The cost must exist only while
  the filter is active.

## What the diver gets

### Tap a bar

Each row in both groups on the Tank configuration card becomes tappable and opens
the dive list with those dives, within the current Insights filter. The back
arrow returns to Insights. This is how the country, region and calendar-day cards
already behave.

The list shows the filter as typed conditions in the search row, as those cards
do, and holds exactly the dives the bar counted. The chart leaves out planned
dives and dives excluded from statistics, so a tap adds `planned:false` and
`excludedFromStats:false` as well, for example
`tankConfig:sidemount planned:false excludedFromStats:false`. This is a deliberate
difference from the country, region and calendar-day cards, whose lists keep those
dives: here the list exists to check the number, so it has to equal the number.
The diver can see the two extra conditions and remove them.

### Refine

The Gas and equipment group gains two rows of `FilterChip`s after Gas mix, always
showing every option:

- **Tank configuration:** Single backmount, Twin backmount, Sidemount, Rebreather,
  Other, No tanks logged.
- **Tank extras:** Stage(s), Deco gas, Multi-gas.

Several chips in one row match any of them. The two rows combine with AND, like
every other pair of axes, so Sidemount plus Stage(s) means sidemount dives with a
stage. The dive list's active-filter bar shows them, following the water types
pattern (a single value shows its label, several show a count).

The chips and typed search select by configuration alone, so on the dive list they
also find planned and excluded dives of that configuration. Inside Insights the
page leaves those dives out as it does for every other filter. Only a tap on a bar
adds the two extra conditions.

### Typed search

- `tankConfig:sidemount`, with values `rebreather`, `sidemount`, `twinBackmount`,
  `singleBackmount`, `other`, `noTanks`.
- `tankConfig:none` means the classifier's `noTanks`, so it always matches the No
  tanks logged bar and chip. It differs from `gasCount:none` on one case: a
  rebreather dive with no tank rows is Rebreather, so `tankConfig:none` leaves it
  out while `gasCount:none` finds it. `tankConfig:any` is the exact complement.
- Three boolean fields, `stages`, `decoGas` and `multiGas`, as predicates in the
  shape of `deco`. `decoGas` must stay distinct from the existing `deco` field,
  which asks about decompression obligation.

## How it works

### One classifier, evaluated inside SQL

The filter engine compiles everything to a single SQL tree (#2365), while the
classifier is Dart (regexes, matched pairs, breathed-tank logic). Translating it
to SQL would create a second implementation that drifts, and multi-gas in
particular does not translate. Materialising it into `dive_derived_metrics` would
need a schema rung, and that table refreshes on profile changes, not tank edits,
so it could go stale.

Instead, register the existing classifier as SQL functions through
`registerAppSqlFunctions`, as `unicode_lower` is. There is no new table or column,
no version bump and no sync change. It does need one new index; see Performance.

Inputs per dive, gathered by correlated subqueries against `{r}`: dive mode,
whether a primary profile exists, the primary data source's id and computer id,
the tanks as JSON ordered by `tank_order`, and the gas switches as JSON.
`_ownedByPrimary`, the "primary owns none keeps every cylinder" rule, and the
unknown-name defaults (role reads as back gas, mode as open circuit) move out of
the repository part file so both callers share them.

Put the SQL fragment and the Dart function in
`lib/features/insights/data/tank_configuration_sql.dart`, beside
`dive_filter_sql.dart`. The enums stay where they are.

### The chart reads through the same expression

`getTankConfigurationStats` changes to select from the same SQL fragment instead
of loading rows and classifying them itself. There is then one evaluation path
and the anti-goal cannot be hit by the two drifting apart. Existing tests for that
method must pass unchanged.

### Filter axes

`DiveFilterState` gains `List<TankBaseConfiguration> tankConfigurations` and
`List<TankConfigurationExtra> tankExtras`, threaded through `activeAxisCount`,
equality, `hashCode` and `copyWith`, with `clear` flags. `toQuery()` lowers them
to an `inList` on `tankConfig`, and to an `OrNode` of the boolean fields (a lone
condition when one is picked). Because every path compiles this tree, the list,
its count, Insights and entity views all follow.

### Tap-through uses query conditions, not the axes

Add `tankConfigDivesFilter` and `tankExtraDivesFilter` to
`insights_place_dives.dart`, built on `_withConditions`. Setting the axis would be
wrong: tapping Deco gas while Insights is scoped to Stage(s) needs AND, but the
axis is OR, so the list would not match the bar. Navigation goes through
`openInsightsDives`; `dive_filter_navigation_single_source_test` enforces that.

Both functions also add `planned` and `excludedFromStats` conditions set to false,
the two parts of `DiveStatsScope.predicate` that apply to this card. The existing
boolean fields carry them, so nothing new is needed. Share them in one small helper
beside the two functions, and update the doc comment that says these lists keep
excluded dives, so it no longer reads as true of every Insights list.

### The chart widget

`HorizontalCategoryBarChart` gains an optional row-tap callback. Its other callers
stay as they are. A tappable row is a button to screen readers, carrying its label
and count, and meets the minimum touch target even though that makes this card's
rows taller than the bars need. `rows()` in the card sorts by count, so the
mapping from row back to enum must survive the sort.

### Freshness

The new fields declare `tables` of `dive_tanks`, `gas_switches`,
`dive_data_sources` and `dive_profile_series`, so `diveFilterTablesTouched` ticks
on any write they read.

## Performance

Measured with the real classifier in a registered function, on a spawned isolate
as the database runs, using an in-memory SQLite database with a reduced schema:

| Dives | Full count | Page of 50, common value | Page of 50, no matches |
| --- | --- | --- | --- |
| 2,000 | 30 ms | under 1 ms | 16 ms |
| 10,000 | 50 ms | under 1 ms | 50 ms |
| 50,000 | 210 ms | under 1 ms | 195 ms |

That is about 4 microseconds per dive on the background isolate. These figures
assume an index on `gas_switches(dive_id)`, which the benchmark's reduced schema
had and **the real database does not**. Without it, the switches subquery scans
the whole table once per dive. Measured for that subquery alone, on an on-disk
file:

| Dives | Switches | No index | With index |
| --- | --- | --- | --- |
| 2,000 | 1,000 | 63 ms | 1 ms |
| 10,000 | 2,500 | 747 ms | 3 ms |
| 10,000 | 10,000 | 2,928 ms | 8 ms |
| 10,000 | 20,000 | 9,781 ms | 20 ms |

So the index is required, and is the first task. Today's chart scans `gas_switches`
once with `IN`, so moving it onto a per-dive expression without the index would
slow the Gas page for every diver, filtering or not.

Add `idx_gas_switches_dive_id` to `kPerformanceIndexes`.
`ensurePerformanceIndexes` asserts that list on every open, so it needs no version
bump or migration rung and has no sync effect. Existing databases build it once at
their next open.

The benchmark also left out the primary source lookup and the ownership fields, and
a file on disk will be slower. Re-measure on the real schema and report it in the
PR. If a full count over 10,000 dives on a real database takes more than 250 ms,
stop and raise it rather than optimising silently.

## Constraints

- A SQL function lives on the connection. Any connection without it fails loudly
  with "no such function", so the registration must reach every opener, and tests
  that use the filter must pass `registerAppSqlFunctions`.
- The doc comment in `app_sql_functions.dart` says "No Flutter imports". That stops
  being true: the classifier's import closure reaches `dart:ui` and
  `package:flutter/material.dart` through `Color` on `Tag` and certification
  types. The benchmark ran on a spawned isolate under `flutter test`, but a real
  app run on macOS must confirm the filter works on the database worker isolate.
  Correct the comment.
- Units: nothing here displays a measured value.
- Eleven ARB locales need the new strings. Reuse the existing
  `insights_gas_tankConfig_*` labels for chips and enum values through
  `tankBaseConfigurationLabel` and `tankConfigurationExtraLabel`.
- Filter guards that will fire and must be satisfied, not bypassed:
  `dive_filter_query_census_test`, `dive_filter_save_census_test`,
  `refine_axis_guard_test` (`RefineGasEquipmentGroup.fields` and `activeCount`).
- `test/architecture/` and `test/shared/` run after adding files under `lib/`.

## Tests that matter

- **Parity, the most important one.** Seed dives in every configuration and extra,
  including a consolidated dive with a non-primary recording's cylinders, a primary
  that owns none, a planned dive and a dive excluded from statistics. For each
  bucket, the stats count equals `getDiveCount`, `getDiveSummaries` and the filtered
  id set for the tap filter, under an Insights scope as well. The same bucket's
  Refine axis on the dive list finds those dives plus the planned and excluded ones.
- The SQL function against the classifier for every category, including unknown
  role and mode names.
- A tick test: editing a tank refreshes a filtered list.
- Saved search round trip through the census tests.
- Refine chips, active-filter chips, and tapping a row on the card opens the
  matching filter. The chart's other callers are not tappable.

## Left to the builder

- The exact function signatures and how extras are returned.
- The affordance that tells a diver a row is tappable, matching the country rows.
- Wording of any new strings.

## Calls made during design

These were chosen, not asked for:

- SQL function over a stored column or a SQL translation.
- The chart moves onto the same SQL expression.
- Add one index on `gas_switches(dive_id)`, which the approach needs.
- Tap-through uses query conditions rather than the axes.
- Only a tap adds the planned and excluded conditions. Refine and typed search stay
  plain, so a Refine chip on the dive list can find more dives than the bar shows,
  all of them planned or excluded.
- Extras are three boolean fields, because the compiler's enum handling (`IN`)
  cannot express a multi-valued field.
- `tankConfig:none` means the classifier's `noTanks`, not "no tank rows".
- The enums stay in `features/insights`, keeping the diff small even though
  `DiveFilterState` now imports them.
- The new Refine label is "Tank extras", since "Extras" alone is unclear away from
  the card.
