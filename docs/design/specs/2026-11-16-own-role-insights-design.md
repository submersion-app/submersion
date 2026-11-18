# My role in Insights and the dive filter (issue #4409)

## Intent

A diver can give themselves roles on each dive (Buddy, Dive Guide,
Instructor, Student, Divemaster, Solo, Rear Guard, Support Diver, Safety
Diver, plus custom roles). Insights shows only one of them, Solo, inside the
Solo vs Buddy chart. The issue asks for a statistic per role, the ability to
narrow dives to one role "like for other statistics", and the role
unspecified (no role set) handled as its own case.

Divers who guide or teach want to know how many dives they led, how much
time they spent instructing, and to look at any Insights page (depth, gas,
sites) for just those dives.

## Goals

1. A **My role** card on Insights > Social: one bar per role the diver held,
   plus a **Not set** bar, each with its dive count and summed dive time,
   each opening its dives.
2. A **My role** filter in the shared dive filter (Refine > People), so the
   dive list and every Insights page can be scoped to chosen roles, with
   **Not set** as one of the choices.
3. The query language understands the diver's own roles by name:
   `myRole = Instructor`, `myRole in [Instructor, "Safety Diver"]`,
   `myRole is empty`, custom roles by their names, built-ins by their
   localized names.
4. Explore (plain-language queries) understands it too: "dives where I was
   the instructor" lowers to `myRole` by role name.

## Non-goals

- Buddies' roles (`dive_buddies.role`, `dive_buddy_roles`). This is only the
  diver's own role.
- A dive table column for role, or a column header filter.
- Changing Solo vs Buddy. It stays as it is; Solo also appears as a bar in
  the new card.
- A pie chart. Counts do not sum to the dive total (see Counting).

## Anti-goals

- The chart and the filter disagreeing. A bar's count must equal the number
  of dives the filter returns for that role under the same scope.
- Breaking saved filters, saved searches or rules that use the existing
  `noRoleOnly` setting or the `role` query field.
- Matching only the primary role. A dive logged as Instructor + Safety Diver
  is a Safety Diver dive too.

## How the role set is read today

`dives.diver_role` holds the primary role; `dive_diver_roles` (v272, #1221)
holds the full set. `DiveRoleSet.resolve` reconciles them:

- a null or blank `diver_role` means no role, whatever the junction holds;
- the junction is current only when its normalized primary (canonical order:
  built-in ids in `DiveRole.builtInIds` order, then other ids ascending,
  Buddy last; Solo dropped when beside another role) equals `diver_role`;
- otherwise the set is just `[diver_role]` (an older app version changed the
  scalar after the junction was written).

Every new SQL path in this design applies exactly this rule.

## Approaches considered

1. **A `myRole` relation in the query language (chosen).** Roles become a
   query subject like dive types; the dive entity gets a relation to it whose
   join applies the resolution rule. The filter lowers to it; the chart's
   drill-in narrows through it. Most work, but queries read naturally, custom
   roles print by name, secondary roles match, and chart and filter share one
   definition.
2. Widen the existing `role` text field to match role ids. Cheaper, but only
   the primary role matches and custom roles print as UUIDs in query text.
3. A filter-only SQL clause outside the query language. Smallest, but every
   filter axis must round-trip through a query (saved searches, rules, the
   query editor), so this would be an axis those cannot express.

The maintainer chose approach 1.

## Design

### Counting

A dive with several roles counts once under each of them, as the Dive types
list already does (#3048, `DiveTerm.diveTypeCounting`). The card says so in
its info sheet. A dive with no role counts once under Not set. Each bar also
shows summed dive time using `measuredRuntimeSecondsSql`, as the dive types
rows do (#641).

### Query language

- New `QuerySubject.diveRoles` and a `diveRoleQueryEntity` over the
  `dive_roles` table, patterned on `diveTypeQueryEntity`: fields `name`
  (text) and `builtIn` (bool), diver scope column `diver_id` (built-ins have
  a null `diver_id`, as built-in dive types do).
- Name index: `name_index_loader.dart` loads dive roles and gives built-ins
  their localized names via `builtInDiveRoleName`, as dive types use
  `builtInDiveTypeName`; `name_index.dart` maps the subject to a role-id
  name target.
- New relation on the dive entity, key `myRole`, alias `myRoles`, target
  `QuerySubject.diveRoles`, many-valued, with a custom join that yields the
  resolved role set (rule above). Its empty form is the same as the existing
  `role` field's: `diver_role` null or blank.
- The existing `role` field keeps its key and its `isEmpty` / `isSet`
  operators, but loses its `myRole` alias (added in #3703): fields resolve
  before relations in `resolvePath`, and keys and aliases must be unique per
  entity, so the alias would shadow the new relation. Saved trees store the
  canonical key `role`, so nothing stored changes, and because the relation's
  empty form equals the field's, a typed `myRole:none` / `myRole:any` still
  means exactly what it meant before. (Builder-check finding; my call.)
- Only role ids with a visible `dive_roles` row count, in the chart as in the
  relation (which matches through the row under diver scope). A role id with
  no row (a custom role not synced yet) is rare; dropping it from the chart
  keeps every bar equal to the dives its filter returns. (My call.)
- One shared SQL fragment produces the resolved (dive id, role id) pairs, used
  by both the relation join and the chart query, so the two cannot drift.
- Rules: `rule_labels.dart` needs a label for the new subject if it lists
  every subject (follow what the compiler and the existing exhaustive
  switches demand).

### Filter

- `DiveFilterState` gains `diverRoleIds` (`List<String>`, default empty),
  with `copyWith`, equality, hash, `isEmpty`-style checks and active-axis
  counting updated the way `waterTypes` is.
- Lowering (`dive_filter_query.dart`): role ids lower to
  `myRole in [refs]`; `noRoleOnly` keeps lowering as today. When both are
  set they OR, exactly as `waterTypes` and `noWaterType` do.
- Refine > People: the "No Role Assigned" switch becomes a **My role** chip
  row, one `FilterChip` per role from `allDiveRolesProvider` (built-ins and
  the diver's custom roles, localized names) plus a **Not set** chip bound to
  `noRoleOnly`, matching the Water type chips in Refine > Conditions.
- Active filter chips show the chosen roles (and Not set as today).
- Anywhere that enumerates filter axes (save census tests, column filter
  edits, axis lists in the refine group) is updated so the new field is
  saved, restored and counted.

### Insights card

- Repository: `getDiverRoleDistribution({diverId, filter})` returns
  `List<DistributionSegment>` keyed by role id, plus a Not set segment keyed
  `kNotRecordedDistributionKey`, ordered by count descending, using the
  shared resolution fragment and `_diveFilter`.
- Provider `diverRoleDistributionProvider`, watched like
  `diveTypeDistributionProvider`.
- Social page: a **My role** `StatSectionCard` after Solo vs Buddy, with a
  `DistributionBarRow` per segment (label = localized role name or "Not set";
  count; summed time; bar sized against the largest count). Empty, loading
  and error states as the other Social cards.
- Drill-in: tapping a bar calls `openFilteredChartDives` with a new
  `diverRoleDivesFilter(scope, key)` in `insights_dive_filters.dart`, which
  ANDs `myRole = <id>` (or `myRole is empty` for Not set) onto the scope, as
  `diveTypeDivesFilter` and `_recordedOrEmpty` do.

### Explore

The maintainer chose to include Explore.

- New `ExploreField('myRole', ['myRole', 'name'], ExploreValueKind.typeName)`
  in `explore_fields.dart`, lowered by the existing `_typeName` path (exact,
  case-insensitive name match through the relation), as `diveType` is.
- `nl_engine.dart` prompt text gains a `myRole` line ("the name of the
  diver's own role on the dive, such as Instructor or Dive Guide"); the
  existing `noRole` flag stays.
- `kQuerySchemaVersion` goes from 5 to 6 (`query_model.dart`), as #3703 did
  when it added `noRole`, with the version-pinned tests and fixtures
  updated.
- Explore subject switches that enumerate name targets (`ownsTarget`,
  `rootOf`, the explore repository) gain the new subject where the compiler
  requires it.

### Strings

New ARB strings in `app_en.arb` (card title, subtitle, empty and error
messages, the Not set label, the filter group label, query labels for the
new subject, relation and fields), translated into every shipped locale.

## Constraints

- Units: counts and times only; time uses the existing duration formatting.
- Diver scope: everything respects the active diver, as the other Insights
  queries do.
- Files stay under 800 lines; `insights_repository.dart` is already large, so
  the new query goes in its own part or extension file like
  `insights_repository_focus.dart`.
- No schema change and no migration.

## Left to the builder

- The exact SQL of the resolution fragment (a canonical-rank `CASE` over the
  built-in ids is one way), as long as it matches `DiveRoleSet.resolve` and a
  test proves it on the tricky cases: scalar blank with junction rows, stale
  junction, Solo beside another role, custom role ids, duplicate rows.
- Bar colours, ordering ties, and widget keys.
- Whether the drill-in narrows with a condition node or a filter field, as
  long as it ANDs onto an existing role choice in the scope.
