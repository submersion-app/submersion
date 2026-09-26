# Entity query language: one filter engine for every list

Date: 2026-09-25
Status: approved design, awaiting implementation plans

## Summary

A community request asked for "dives with no weight entry", "dives with no
exposure gear" and "dives with no bottom temp", noting that "no buddy" exists
but nothing else like it does. Today every dive filter axis is a hand-written
field on `DiveFilterState`, implemented three times (Dart `apply()`, the
paginated list SQL and the Statistics SQL), and the only "missing data" axis
is `noBuddyOnly`. Sites, equipment and trips each have their own unrelated
filter class; buddies, centers, certifications, courses and species have no
filter at all.

This program replaces those evaluators with one registry-driven query engine.
A query is an expression tree over `path op value`, written either as typed
text (`(weights:none OR temp:none) AND year = 2025`) or in a rule builder,
compiled to SQL for any registered entity, and saveable as a named, synced
smart list. The existing filter sheets keep their UI and lower into the same
tree, so a new axis is one registry line rather than three implementations.

## Decisions fixed in the brainstorm

Do not re-litigate these without Eric.

1. Both surfaces from day one: typed syntax and rule builder, two editors of
   one AST with lossless round-tripping.
2. All entities in the first release: dives, sites, equipment, trips, buddies,
   dive centers, certifications, courses, marine-life species. Media stays
   out; it already has a SQL filter and smart albums.
3. Full boolean logic: AND, OR, NOT, nested groups.
4. The query is the engine. `DiveFilterState`, `SiteFilterState`,
   `EquipmentFilterState` and `TripFilterState` gain `toQuery()`; their Dart
   `apply()` methods are deleted; every path evaluates one compiled query.
5. Saved queries ship in the first release, synced per diver.
6. Arbitrary path traversal (`buddies.certifications.level >= 3`) over a
   declared relation graph. No hand-written per-path SQL.
7. Approach A (registry + AST compiled to SQL). Approach B (Dart predicates
   over hydrated entities) was rejected because dives are paginated and
   Statistics is SQL, so two evaluators would recreate the parity problem.
   Approach C (a SQL engine beside the old filters, id-set intersection) was
   rejected because it keeps the three-path trap.

## Program shape

One spec, five PRs, one release. Each PR gets its own implementation plan.

| PR | Scope |
| --- | --- |
| 1 | Core engine and dives: AST, parser, printer, registry contract, validator, SQL compiler, dive registry, `DiveFilterState.toQuery()`, the three dive paths and Statistics on one compiled query, parity and census tests. |
| 2 | Surfaces: the shared `QueryEditor` (text and builder), chips, the `saved_queries` table and sync, Settings > Manage > Saved queries. |
| 3 | Sites, equipment, trips: registries, `toQuery()` on their filter states, list providers on SQL id subqueries. |
| 4 | Buddies, centers, certifications, courses, species: registries, a query state provider and a filter entry point per list. |
| 5 | Explore lowers to the AST instead of `DiveFilterState`; the shared registry replaces `ExploreDiveField`. After PR #2196 merges. |

PRs 3 and 4 depend on 1 and 2. PR 5 depends on 1 and on the Explore program.

## Architecture

New code lives under `lib/core/query/`:

```
lib/core/query/
  domain/        QueryNode, FieldPath, QueryOp, QueryValue, errors
  syntax/        QueryParser, QueryPrinter, tokenizer, suggestions
  registry/      QueryEntity, QueryField, QueryRelation, QueryRegistry
  compiler/      QueryValidator, QueryCompiler, CompiledQuery
  names/         NameIndex, NameIndexBuilder (moved from Explore in PR 5)
  units/         unit grounding for dimensioned values
  presentation/  QueryEditor, chips, saved-query widgets and providers
```

Each feature contributes its own registry file, for example
`lib/features/dive_log/query/dive_query_entity.dart`, and registers it in the
one `QueryRegistry` map keyed by `QuerySubject`. The core package never
imports a feature; features import the core.

Data flow for a list:

```
sheet edits           typed text / builder
   |                        |
DiveFilterState.toQuery()   QueryNode
   \______________  ________/
                  AND
                   |
             QueryValidator  -> positioned errors to the editor
                   |
             QueryCompiler   -> CompiledQuery { where, params, tablesTouched }
                   |
   +---------------+------------------+
   |               |                  |
paginated list   Statistics      table / map / export
(where + params) (idSubquery)    (getDivesMatching)
```

## Unit 1: the query model

Pure Dart in `lib/core/query/domain/`, no Flutter imports.

```dart
sealed class QueryNode {}
class And extends QueryNode { final List<QueryNode> children; }
class Or extends QueryNode { final List<QueryNode> children; }
class Not extends QueryNode { final QueryNode child; }
class Condition extends QueryNode {
  final FieldPath path;      // one or more segments: [site, country]
  final QueryOp op;
  final QueryValue? value;   // null for isEmpty / isSet
}
class Text extends QueryNode { final List<String> words; }

enum QueryOp { eq, neq, lt, lte, gt, gte, contains, inList, between,
               isEmpty, isSet }

sealed class QueryValue {}
  NumberValue(num value, QueryUnit? unit)   // unit null = diver's unit
  StringValue(String)
  BoolValue(bool)
  EnumValue(String storedName)
  DateValue(DateTime)                        // a day, wall clock
  DateRangeValue(DateTime start, DateTime endExclusive)
  ListValue(List<QueryValue>)
  RefValue(String id, String label)
```

All nodes are immutable with value equality and a `copyWith`. `Text` lowers
to the entity's declared text-search columns, so today's search bar behaviour
is expressible inside the language. `RefValue` carries the id the compiler
binds and the label the printer shows; a saved query stores the id and the
label is refreshed from the current name on load.

JSON: `QueryNode.toJson()` / `fromJson()` with a top-level `version: 1`.
`fromJson` validates shape and throws `QueryJsonException` on a mismatch;
nothing guesses.

## Unit 2: the typed syntax

Case-insensitive keywords. Whitespace-separated terms are ANDed. Precedence:
NOT binds tightest, then AND, then OR; parentheses group.

```
query      := or
or         := and ( 'OR' and )*          '|' is an alias for OR
and        := not ( 'AND'? not )*        '&' is an alias for AND
not        := ( 'NOT' | '-' ) not | primary
primary    := '(' or ')' | condition | text
condition  := path op value
            | path ':' ( 'none' | 'any' | value )
            | path 'in' '[' value ( ',' value )* ']'
            | path 'in' daterange                     date in 2025
            | path 'between' value 'and' value
path       := ident ( '.' ident )*
op         := '=' | '!=' | '<' | '<=' | '>' | '>=' | '~'
value      := number unit? | quoted | word | date | daterange
text       := quoted | word                (a bare term that is not a path)
```

Semantics of the shorthand `:`: `field:none` is `isEmpty`, `field:any` is
`isSet`, `field:value` is `eq` for enum, ref, bool, number and date fields
and `contains` for text fields. `~` is always `contains`.

Numbers: a bare number on a dimensioned field takes the diver's unit setting
for that dimension; an explicit unit suffix (`m`, `ft`, `c`, `f`, `bar`,
`psi`, `kg`, `lb`, `min`) converts to the storage unit. A unit on a unitless
field is a validation error.

Dates: `2025` (a year), `2025-03` (a month), `2025-03-14`, and the phrases
`last N days|weeks|months|years`, `this year`, `last year`, `since 2024`.
`date in 2025` and `date = 2025` both mean the year range. The grammar is
Explore's `time_grammar`, moved to core.

Examples from the request:

```
weights:none                              dives with no weight entry
NOT gear.type in [wetsuit, drysuit]       dives with no exposure gear
temp:none                                 dives with no water temperature
buddies:none                              today's "no buddy"
(weights:none OR temp:none) AND year = 2025
site.country = Mexico AND depth > 30
buddies.certifications.level >= 3
"night dive"                              free text over the search columns
```

Identifiers are canonical lowerCamel keys (`waterTemp`, `bottomTime`) with
registry-declared aliases (`temp`, `time`). Parse keywords and keys are
English in this program; localized typed aliases are a later phase.

### Printer

`QueryPrinter.print(QueryNode, PrintContext)` emits exactly one canonical
string per tree: the diver's units with no suffix, explicit units only when
the value was typed with one, refs quoted by label, explicit `AND`, minimal
parentheses, `:none` and `:any` for the presence ops, `in [...]` for lists.
`parse(print(ast)) == ast` is a property test. Refs round-trip by id because
the printer emits the label and the parser resolves it through the
`NameIndex`; the test seeds the index with the labels it prints.

### Errors and suggestions

The parser never throws to the UI. It returns a `QueryNode` or a
`ParseFailure(offset, length, message, suggestions)`. Suggestions are up to
five field, relation, enum or ref candidates ranked by the Dice similarity in
`lib/core/text/fuzzy_match.dart`. An empty or whitespace-only string parses to
an empty query (no conditions), which the compiler treats as "match all".

## Unit 3: the registry

```dart
class QueryEntity {
  final QuerySubject subject;          // dives, sites, equipment, trips,
                                       // buddies, centers, certifications,
                                       // courses, species
  final String table;                  // 'dives'
  final String idColumn;               // 'id'
  final String? diverScopeColumn;      // 'diver_id' where per diver
  final List<QueryField> fields;
  final List<QueryRelation> relations;
  final List<String> textSearchColumns;
}

class QueryField {
  final String key;                    // 'waterTemp'
  final List<String> aliases;          // ['temp']
  final FieldType type;                // number, text, bool, enumName,
                                       // date, ref
  final FieldDimension dimension;      // depth, temperature, pressure,
                                       // weight, volume, minutes, percent,
                                       // count, none
  final String sql;                    // column or expression on the alias
  final String emptySql;               // what :none means for this field
  final List<String>? enumValues;      // stored strings
  final QuerySubject? refTarget;       // NameIndex kind for ref fields
  final String labelKey;               // ARB key for the builder
  final Set<QueryOp> ops;              // allowed operators
  final ({num min, num max})? sanity;  // validation range, storage units
}

class QueryRelation {
  final String key;                    // 'buddies', 'site', 'gear'
  final QuerySubject target;
  final RelationShape shape;           // fk, child, junction
  final String joinSql;                // parameterised on {from} and {to}
                                       // aliases; junction includes its
                                       // junction table alias
  final bool isMany;
  final String labelKey;
  final String? emptySql;              // overrides NOT EXISTS for :none
                                       // when a legacy scalar also counts
}
```

`sql` and `emptySql` are written against a root alias placeholder `{r}` that
the compiler substitutes, so one field definition works at any nesting depth.

### Emptiness is per field

The registry, not the UI, decides what "missing" means, and it says so once:

| Field | `emptySql` |
| --- | --- |
| `weight` | `{r}.weight_amount IS NULL AND NOT EXISTS (SELECT 1 FROM dive_weights w WHERE w.dive_id = {r}.id)` |
| `visibility` | `{r}.visibility_meters IS NULL AND ({r}.visibility IS NULL OR TRIM({r}.visibility) = '')` |
| `buddies` (relation) | `({r}.buddy IS NULL OR {r}.buddy = '') AND NOT EXISTS (SELECT 1 FROM dive_buddies b WHERE b.dive_id = {r}.id)` |
| `notes` | `{r}.notes IS NULL OR TRIM({r}.notes) = ''` |
| `waterTemp`, `rating`, `site`, and other scalars | `{r}.<column> IS NULL` |
| any `child` or `junction` relation | `NOT EXISTS` over the relation |

The legacy-plus-table pairs (weight, visibility, buddy) are the reason
emptiness is declared per field rather than derived from the column type.
`noBuddyOnly` lowers to `buddies:none` and inherits this rule, so the dive
registry's `buddies` relation carries the legacy text in its `emptySql`.

### Derived fields

Plain fields whose `sql` is an expression: `year` and `weekday` from
`dive_date_time` (wall clock as UTC, matching `DiveFilterState`'s date
bounds), `durationMinutes`, `hasProfile` (EXISTS on `dive_profile_series`),
`gasCount`, `diveNumber`. No Dart computation. Explore's profile-derived
predicates (`sacTrend`, `sacRoseAfter`, `finalStopUnstable`,
`finalStopDuration`, `safetyFinding`) register in PR 5 as fields whose `sql`
is the output of the existing `derivedPredicateCondition` builder.

### Relations, phase 1 (dives)

fk: `site`, `trip`, `center`, `computer`, `course`.
child: `buddies` (via `dive_buddies` junction to `buddies`), `tanks`,
`weights`, `gear` (via `dive_equipment` to `equipment`), `customFields`,
`sightings` (to `species`), `media`.
junction: `tags`, `types`.

Each target entity contributes its own relations in its own PR, so
`buddies.certifications.level` works as soon as buddies and certifications
each have a registry, with no dive-side change. `equipmentAttrConditions`
lower to `gear.attributes.<key>` paths on the equipment registry's
`attributes` child relation, reusing the semantics of
`equipmentAttrConditionSql`.

### Units

Every dimensioned field declares its storage unit (metric). Weight has its
own dimension because `dive_weights.amount_kg` is stored in kg and shown in
lb for imperial divers. The parser converts explicit units to storage; bare
numbers take the diver's unit for that dimension; the printer converts back.
Anything displaying a value respects the active diver's unit settings.

### "Bottom temp"

There is no bottom-temperature column. `waterTemp` (alias `temp`) is the
synced `dives.water_temp`. `dive_sensor_summaries.min_temperature` is
device-local and never synced, so it is not in the registry; if that table
gains an `hlc` column later, `minTemp` becomes one derived-field line.

### Guards

A registry test suite asserts, for every entity: each `fk` and `child`
relation matches Drift's foreign-key metadata for the named columns; each
`sql` and `emptySql` compiles inside `SELECT 1 FROM <table> r0 WHERE ...`
against a fresh in-memory database; each `refTarget` has a `NameIndex` kind;
each `labelKey` exists in `app_en.arb`; keys and aliases are unique within
the entity.

## Unit 4: the validator and compiler

`QueryValidator.validate(QueryNode, QueryEntity, ValidationContext) ->
List<QueryError>` walks the tree against the registry and returns every
positioned error at once: unknown field or relation (with suggestions), an
operator the field does not allow, a unit on a unitless field, a value
outside the field's `sanity` range (negative depth, temperature outside -5 to
45 C, Explore's rules), an unresolved ref (with candidates), a `between` with
reversed bounds (auto-swapped, reported as a warning), and a path deeper than
**4 hops** (a hard cap so `site.dives.site.dives` cannot fan out).

`QueryCompiler.compile(QueryNode, QueryEntity, CompileContext) ->
CompiledQuery` assumes a validated tree and throws `QueryCompileError` on
anything else; that is a programming error, surfaced through `AsyncValue`
at the provider boundary, never swallowed.

```dart
class CompiledQuery {
  final String where;               // boolean expression over alias r0
  final List<Object?> params;       // bind values in `?` order
  final Set<String> tablesTouched;  // root, every join and EXISTS table
  String idSubquery();              // SELECT r0.<id> FROM <table> r0
                                    // WHERE <where>
}
```

The `where` form splices into `_buildFilterWhereClauses` for the paginated
list, ordered ids and count; the `idSubquery` form serves Statistics and
every id-set consumer. Same object, two spellings.

### Path lowering

A condition on `[a, b, c] op v` compiles inside-out with one nested `EXISTS`
per relation hop, aliases numbered by depth; a `fk` hop uses a `JOIN` (one
row, cheaper) instead of `EXISTS`:

```sql
-- buddies.certifications.level >= 3
EXISTS (SELECT 1 FROM dive_buddies j0
        JOIN buddies r1 ON r1.id = j0.buddy_id
        WHERE j0.dive_id = r0.id
          AND EXISTS (SELECT 1 FROM certifications r2
                      WHERE r2.buddy_id = r1.id AND r2.level >= ?))
```

Every value is a bind parameter; the compiler never interpolates a value.

### Quantifier semantics

A collection path is existential: `tanks.o2 > 32` means some tank. `NOT`
wraps the whole `EXISTS`, so `NOT gear.type in [wetsuit, drysuit]` means "no
linked gear of those types". `path:none` on a relation is `NOT EXISTS` with
no inner condition; on a field it is the field's `emptySql`. A universal
quantifier ("all tanks over 32") is out of scope.

### Text and diver scope

A `Text` node lowers to the entity's `textSearchColumns` ORed with
`LIKE '%word%'`; multiple words AND their per-word ORs, matching today's
`searchDiveSummaries`. The diver scope (`diver_id = ?`) is applied by the
caller as today, so the compiled string composes with existing queries.

### Performance

Nested `EXISTS` over the existing foreign-key indexes is what the deco and
attribute id-set providers already do, so no new index in PR 1. PR 1 includes
a measured test using the `logStatements` pattern that a three-hop query over
a 5,000-dive fixture runs as one statement, and an `EXPLAIN QUERY PLAN`
assertion that no hop is a full scan on an unindexed column. If a later
registry adds a relation on an unindexed column, that test names it.

## Unit 5: lowering the existing filters

`DiveFilterState` keeps every field and the sheet keeps its UI. It gains
`query: QueryNode?` (the advanced part) and `toQuery()`, which ANDs each set
axis, lowered to a `Condition`, with `query`:

| Axis | Lowers to |
| --- | --- |
| `startDate` / `endDate` | `date >= ...` / `date < ...` using the existing ms bounds |
| `weekdays` | `weekday in [...]` |
| `diveTypeId`, `siteId`, `tripId`, `diveCenterId`, `computerId` | `types = ref`, `site = ref`, ... |
| `minDepth` .. `maxBottomTimeMinutes` | ordering conditions in storage units |
| `favoritesOnly`, `excludedFromStatsOnly`, `decoOnly` | `favorite = true`, `excludedFromStats = true`, `deco = true` |
| `noBuddyOnly` | `buddies:none` |
| `tagIds`, `equipmentIds` | `tags in [...]`, `gear in [...]` |
| `diveIds` (the Statistics seam) | `id in [...]` |
| `equipmentAttrConditions` | `gear.attributes.<key> op value` |
| `buddyNameFilter` | one `buddies.name ~ part` per comma part, ANDed, ORed with the legacy `buddy ~ part` |
| `buddyId` | `buddies = ref` |
| `customFieldKey` / `customFieldValue` | `customFields.key = k` AND `customFields.value ~ v` on one row |

`apply()` is deleted. `_buildFilterWhereClauses` returns the compiled `where`
and params; `buildFilteredDiveIdSubquery` becomes a wrapper over
`idSubquery()` so its ~40 Statistics callers are untouched;
`filteredDivesProvider` calls a new `getDivesMatching(CompiledQuery)` instead
of filtering in Dart; `decoFilteredDiveIdsProvider` and
`equipmentAttrFilteredDiveIdsProvider` are removed because deco and
attributes are ordinary fields now.

A census test asserts every `DiveFilterState` field appears in `toQuery()`,
so an axis can no longer be added without being lowered. The existing parity
test ("Statistics, the list and the id query select the same dives") guards
the single compiler.

### Change ticks

Today a path that joins a new table must also watch it or go stale.
`CompiledQuery.tablesTouched` replaces the hand-maintained list: the
paginator, Statistics and each list provider subscribe to exactly those
tables, conditionally on a non-empty set, so the many test fakes that
`implements DiveRepository` are unaffected. `watchEquipmentAttrFilterChanges`
is retired.

### Chips

Axis chips keep their labels. The `query` part adds one chip per top-level
`AND` child, labelled by the printer in the diver's units; removing the chip
removes that child. A chip must never claim a strictness the filter does not
apply; printing from the AST the compiler consumes guarantees that.

### Other entities

`SiteFilterState`, `EquipmentFilterState` and `TripFilterState` gain the same
`query` field and `toQuery()`; their `apply()` methods go; each list
provider filters in SQL via `WHERE id IN (<idSubquery>)`. `hasCoordinates`
and `hasDives` become `coordinates:any` and `dives:any`. Lists with no filter
today (buddies, centers, certifications, courses, species) get one
`StateProvider<QueryNode?>` each, wired the same way, with their existing
`LIKE` search expressed as a `Text` node. The species manage page keeps its
catalog load and filters the 685 rows through the same subquery. The dive
center list's per-row dive count (an N+1) is unchanged by this program.

### Explore

`CompiledQuery.filter` (a `DiveFilterState`) becomes a `QueryNode`;
`ExploreDiveField` and `DiveFieldCatalog` are replaced by the dive registry;
`NameIndex`, `NameIndexBuilder`, `unit_grounding` and `time_grammar` move to
`lib/core/query/`. The on-device model's vocabulary and the typed language
then share one source. This is PR 5, after #2196 merges.

## Unit 6: the surfaces

One shared widget, `QueryEditor`, in `lib/core/query/presentation/`,
parameterised by a `QueryEntity` and bound to a `QueryNode?` notifier. Two
tabs over the same AST:

**Text.** A single-line field with live validation. Errors underline the
offending span and show the message and suggestions below; a valid parse
re-renders the chips. Autocomplete offers field keys at a word boundary,
relation keys after `.`, enum values and ref names after an operator, and
`none` / `any` after `:`.

**Builder.** A group is a card with an AND/OR toggle; rows are field picker,
operator picker, value editor; a row can be negated; "Add group" nests. The
field picker is a searchable tree that walks relations (Dives > Buddies >
Certifications > Level), which is how arbitrary paths are reachable without
typing. The value editor follows the field type: a unit-aware number field
showing the diver's unit, an enum dropdown with localized labels, a ref
type-ahead backed by the `NameIndex`, a date or range picker, or nothing for
`none` / `any`.

**Placement.** Dives: `DiveSearchPage` hosts the editor above its existing
sections, and the quick `DiveFilterSheet` gets a "Query" row that opens that
page. Sites, equipment, trips: inside their filter sheets. Buddies, centers,
certifications, courses, species: a new filter icon in the app bar. The
Settings > Manage page convention (lower-right FAB, inline icons) is
untouched.

## Unit 7: saved queries

```
saved_queries: id TEXT PK, diver_id TEXT, subject TEXT, name TEXT,
               query_json TEXT, sort_order INT, created_at INT,
               updated_at INT, hlc TEXT NULL
```

`query_json` is the versioned AST (ids for refs), not the printed text, so a
grammar change cannot break stored rows; the printer regenerates the text on
load. Registered in `sync_repository.dart` beside `mediaSmartAlbums`, per
diver, under the existing adopt/wipe rules. The schema rung is decided at
merge time: `currentSchemaVersion` was 226 on 2026-09-25 and PR #2331 holds
228, so re-grep before writing the migration. A default change is for fresh
databases only; the migration never rewrites existing rows.

Surfaces: "Save" in the editor (name prompt); a "Saved" chip row at the top
of each list's filter area that applies one on tap; Settings > Manage >
Saved queries for rename, reorder and delete. Applying a saved query whose
ref no longer resolves (a deleted site) opens it with that row flagged rather
than silently dropping the condition. An unreadable `query_json` (newer
version, corrupt) loads as a flagged row that can be deleted or opened with
its readable parts.

The universal importer's note that MacDive saved searches cannot be imported
stays true; importing them is a follow-up.

## Localisation

Every field label, relation label, operator label, enum value label and error
message is an ARB key in all locales. Parse keywords and canonical keys stay
English. New plural strings follow the `=1{{count} ...}` rule for fr and pt
and keep word forms for ar and he. `app_de.arb` must not contain "SAC".

## Error handling

- Parser: returns an AST or a `ParseFailure`; never throws to the UI.
- Validator: returns all positioned `QueryError`s; the compiler is called
  only on a clean tree.
- Compiler: throws `QueryCompileError` on an invalid tree (a bug), caught at
  the provider boundary and surfaced as `AsyncValue.error`.
- Repository: a SQL failure surfaces as the list's error state with the
  compiled statement logged, as today.
- Saved queries: unreadable rows are flagged, never skipped, never a crash.

## Testing

All pure-Dart layers use plain `test`, no widgets.

1. Parser and printer: table-driven cases for every operator, unit,
   shorthand and precedence rule; the `parse(print(ast)) == ast` property
   test over a generated AST; a positioned-error case per failure kind.
2. Registry guards (Unit 3).
3. Compiler goldens per condition shape: scalar, fk hop, child hop, junction
   hop, three-hop path, NOT over EXISTS, `:none` on fields and relations,
   Text over the search columns; a bind-count test that `params.length`
   equals the `?` count in every golden.
4. Semantics against a real in-memory database: a seeded fixture (dives with
   and without weights, suits, temperature, buddies with certifications) and
   id-set assertions for each request in the original ask; the `EXPLAIN
   QUERY PLAN` no-full-scan check; the one-statement count.
5. Parity: the three-path test driven through `toQuery()`; the census test
   that every `DiveFilterState` field is lowered; the same for sites,
   equipment and trips.
6. Lowering equivalence: for every axis, the old `apply()` result over the
   fixture equals the new SQL result, run before `apply()` is deleted so the
   deletion is proven.
7. Change ticks: a write to a table named only in `tablesTouched` refreshes
   the list.
8. Widgets: the text tab shows a positioned error; the builder round-trips a
   nested group; removing a chip removes exactly its AND child; saved-query
   save, apply and rename; all with the fake-repository pattern the dive list
   tests use.
9. Sync: `saved_queries` round-trips through the existing sync base tests and
   respects adopt/wipe.
10. Architecture guards in `test/architecture/` are run after every new
    `lib/` file.

## Out of scope

- Universal quantifiers ("all tanks over 32").
- Localized typed keywords and field aliases.
- Media library queries (it has its own filter and smart albums).
- `minTemp` until `dive_sensor_summaries` syncs.
- Importing MacDive saved searches.
- Aggregate conditions over the root set (`count(dives) > 10` on an
  equipment query); `dives:any` / `dives:none` cover the presence case.
- Cross-entity result handoffs (a dive query producing a site list).

## Amendments recorded while planning PR 1

Writing the PR 1 plan against the real code changed four points above.
The plan is authoritative where they differ.

- **Scoped groups.** The AST gains `ScopedNode(path, inner)`, written
  `path[inner]`, evaluating `inner` on ONE row of the relation. Without it
  `customFields.key = k AND customFields.value ~ v` tests two rows, and the
  lowering table in Unit 5 could not be expressed. The grammar gains
  `primary := path '[' or ']'`.
- **A relation is how a row is named.** There is no `ref` field type.
  `site = "Salt Pier"` is the relation `site` with `=` and a `RefValue`,
  compiled as the hop with `{to}.id = ?` inside; `site.country = x` is the
  same relation followed. Relations accept `=`, `!=`, `in`, `:none`, `:any`
  and `[...]`. `QueryRelation` gains an optional `emptySql` so `buddies:none`
  can count the legacy `dives.buddy` text.
- **Every hop is a correlated `EXISTS`**, including fk hops; no `JOIN`
  form. One shape keeps the compiler small and SQLite plans the primary-key
  lookup identically (an `EXPLAIN QUERY PLAN` test pins it).
- **Change ticks are declared, then derived.** `tablesTouched` is built
  from `tables` lists on fields, relations and the text search (SQL
  fragments are opaque strings), and a registry guard checks every declared
  table exists. The entity views take an id set (`getDiveIdsMatching`) and
  narrow the already-hydrated list rather than rehydrating.

## Deviations recorded during implementation (PR 1)

- `queryFilteredDiveIdsProvider` is an `autoDispose` family keyed on the
  `DiveFilterState` instance. A changed filter lands on a fresh instance
  that starts loading, so the table, maps and profile panel never show the
  previous filter's dives; a write to a table the query read invalidates
  the same instance and keeps its value, so the list never blanks.
- Each dive notifier keeps ONE debounced change tick, widened to the
  filter's extra tables (`_FilterAwareTick` over `watchTables`), never a
  second tick beside the first: a local buddy edit writes the junction and
  then the dive row, and two ticks reloaded the list twice.
- Junction hops compile as `{to}.id IN (SELECT j.x FROM junction j WHERE
  j.dive_id = {from}.id)` rather than a nested `EXISTS`: `EXPLAIN QUERY
  PLAN` showed SQLite scanning the target under the EXISTS form and probing
  its key under the IN form.
- `certifications.buddy_id` has no index, so `buddies.certifications.*`
  scans that (per-buddy, small) table; the query-plan test accepts that one
  scan and a follow-up rung adds the index.
- The parser stores canonical keys (`temp` becomes `waterTemp`), so a tree,
  its JSON and its printed text hold one spelling; an enum typo with no
  fuzzy match lists the field's values as suggestions.
- `media.type` is a text field (the row mapper accepts two spellings of the
  signature type); `equipment.status` is an enum over `EquipmentStatus`.
- `meta` became a direct dependency so `lib/core/query` can use
  `@immutable` without importing Flutter.
- `watchDiveListChangesWithBuddyLinks` and `watchDivesChangesWithBuddyLinks`
  remain (the buddy providers use one); only the dive-list notifiers moved
  off them.

Decided in the whole-branch review of PR 1:

- **NOT is two-valued.** `NOT x` compiles to `NOT COALESCE(x, 0)`, so a
  row whose operand is NULL (no notes under `NOT notes ~ shark`, no depth
  under `NOT depth > 30`) is KEPT: NOT is the exact complement of its
  operand. SQL's three-valued NOT dropped almost every dive from a negated
  text search, because the legacy `buddy` column is usually NULL. The
  scalar `!=` operator is unchanged and still excludes unrecorded values;
  `field:none` is how "unrecorded" is asked for.
- **`:any` is the exact complement of `:none`.** A relation with an
  `emptySql` (buddies, weights) counts its legacy scalar as present under
  `:any` too, so `buddies:any` and `NOT buddies:none` agree.
- **`weights:none` counts the legacy scalar as a weight entry** (the edit
  form migrates it into the table on load), so `weights:none` and
  `weight:none` select the same dives. The plan had pinned the opposite.
- **Date fields declare their frame.** `QueryField.dateFrame` is
  `wallClockUtc` (dives) or `localInstant` (trips, certifications,
  courses, which store `millisecondsSinceEpoch` of a local value); day
  bounds are computed per frame, so `trip.startDate = 2025-03-14` does not
  miss the trip by the diver's UTC offset (#1368's class).
- **A unit from another dimension is an error** (`depth > 100f`), never a
  silent fallback to the diver's unit.
- **Date shorthand and date lists parse**: `date:2025` is the year range,
  `date in [2025-01-05, 2025-03]` is an OR of day and period conditions.
- **Empty groups and empty text are errors** in the parser, the validator
  and the compiler, never SQL.
- **Relation `!=` needs a related row**, like scalar `!=`: `site != X`
  compiles to `EXISTS (... AND r1.id != ?)`, so a dive with no site is not
  "a site other than X"; `site:none` asks for that.
- **Nesting counts against the hop cap.** A scoped group's hops add to
  the depth of the paths inside it, in the parser, the validator and the
  compiler, so `site[dives[site[dives[...]]]]` cannot escape
  `kMaxPathHops`.
- **Date periods are only valid under `in`.** The validator rejects a
  `DateRangeValue` under any other operator (the parser already lowers a
  period to its edge day there), so a builder-made tree cannot reach the
  compiler's cast.
- **An unpadded date is one token** (`2025-3-1`), which the date grammar
  refuses, rather than a year followed by two negated terms.
- **A failed id-set refresh is an error**, even while a previous set
  exists (`narrowDivesByIds`); a refresh in flight keeps the previous set.
- **`last N days` and `last N weeks` use calendar arithmetic**, never a
  `Duration`, so a range typed after a spring-forward change starts on the
  right day.
- **`:none` is refused on an enum that stores a value named `none`**
  (`currentStrength`): the parser and validator name both spellings,
  `currentStrength = none` for the value and `NOT currentStrength:any` for
  unrecorded, rather than silently picking one.
- **`DiveFilterState` has value equality**, so an unchanged filter set
  again is no change to a listener and the id-set family reuses its
  instance for an equal filter.
- **The tick-table lookup never throws** (`diveFilterTablesTouched`
  validates first and falls back to `dives`), and the dive list's tick
  tables are named once, on the repository
  (`DiveRepository.diveListTickTables`).
- **List-bearing nodes copy their lists** (`AndNode`, `OrNode`, `TextNode`,
  `ListValue`, `FieldPath` hold `List.unmodifiable` copies), so a caller's
  later mutation cannot change a tree that `DiveFilterState` hashes; their
  constructors are therefore not `const`.
- **Open-ended date phrases** (`since 2024`, `before 2024`) lower to their
  one bound under `=` and `in`, to its complement under `!=`, and are
  refused under an ordering op with the day to write instead.
- **Reversed `between` bounds mean the range between them**: the parser
  orders them (canonical text) and the compiler orders them again for a
  tree the builder or JSON made.
- **Typed numbers are canonical at four decimals** in the typed unit, so
  the printer's four decimals lose nothing that was parsed.
- **Every malformed saved-query payload fails as `QueryJsonException`**,
  whatever the damage (a cast, a node's own argument check, a number).
- **`gasCount:none` is "no tanks"**: a count is never unrecorded.

## Open items for the implementation plans

- PR 1 must re-grep `currentSchemaVersion` only if it adds a table; it does
  not (saved queries are PR 2).
- PR 2's migration rung is chosen at merge time (see Unit 7).
- PR 5 waits for #2196 and the Explore phase 2 branch; its plan should be
  written after both land, against the merged registry.
- The equipment registry's `attributes` relation must reuse
  `equipmentAttrConditionSql` semantics exactly; the equivalence test in
  Testing item 6 covers it.
