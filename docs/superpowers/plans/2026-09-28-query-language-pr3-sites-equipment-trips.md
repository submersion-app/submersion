# Query Language PR 3: Sites, Equipment and Trips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the site, equipment and trip lists on the one query engine PR 1 built: complete their registries, lower `SiteFilterState`, `EquipmentFilterState` and `TripFilterState` to a query tree, filter each list in SQL through a compiled id set, delete their Dart `apply()` methods, make equipment service due a queryable field backed by the service engine, and put the query editor and Saved row inside the site and equipment filter sheets.

**Architecture:** Each filter state gains `query: QueryNode?` and an extension `toQuery()` beside its entity file, exactly like `DiveFilterQuery`. A shared `QueryIdSetRunner` runs any `CompiledQuery.idSubquery()` (plus an optional caller-applied scope) and watches its `tablesTouched`; each list provider narrows its already-hydrated rows to that id set, so loading, sorting, grouping and the table view are untouched. Service due stays computed by `ServiceDueEngine`; a provider writes each active item's worst severity into a local, never-synced cache table, and the equipment registry's `serviceDue` field reads it.

**Tech Stack:** Flutter, Riverpod 3 (hand-written providers, legacy `StateProvider`), Drift (split database layout: `lib/core/database/tables/*`, `lib/core/database/migrations/*`), the ARB pipeline (`flutter gen-l10n`, generated Dart committed), `scripts/gen_query_label_lookup.py`.

**Spec:** `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`, Units 3, 5 ("Other entities") and 6 ("Placement"), plus "Amendments recorded while planning PR 1" and the two "Deviations recorded during implementation" sections, which are authoritative where the body differs. Program issue #2365 (`Refs #2365`; PR 5 closes it).

## Decisions settled for this plan

Settled with Eric on 2026-09-28, or ruled here where the code forced a choice. Each costs little if wrong and is recorded in the spec in Task 15.

- **Trips get the engine only** (Eric). Registry, `toQuery()`, SQL filtering and the id-set list path; no editor, Saved row or filter button in this PR. Trips have no filter sheet today; `equipmentId`, set from the equipment detail page, is its one axis.
- **Service due is a query field backed by a cache table** (Eric). `ServiceDueEngine` stays the only evaluator. A local table `equipment_service_status` holds each active item's worst severity for the active diver; the `serviceDue` field reads it with `COALESCE(..., 'ok')`. No `hlc` column, so sync never sees it.
- **The cache holds the active diver's view only.** Severity depends on that diver's settings (due-soon window, exposure thresholds) and visibility; one diver is active on a device at a time, so a diver switch re-evaluates and rewrites the table.
- **The equipment owner axis is a caller-applied scope, not a field.** Like visibility, it compares rows with the active diver, which a saved query cannot name. `EquipmentFilterQuery.ownerScope(activeDiverId)` returns a bound clause the runner ANDs with the compiled query.
- **The status axis is always lowered.** The default view (status null) is `active = true AND status != retired AND status != sold`, the Retired view is `(status = retired OR active = false) AND status != sold`, any other status is `status = X`, and service due adds `serviceDue` on top of the default view. One list source (`allEquipmentProvider`) replaces the three-provider switch.
- **Site `country` and `region` compare trimmed.** Their `sql` becomes `TRIM({r}.country)` / `TRIM({r}.region)`; the compiler's text `=` is already case-insensitive. The old Dart key also collapsed internal runs of whitespace, which SQLite cannot do in one expression; a stored country with a doubled inner space now needs the doubled space. Cost if wrong: one mistyped country string stops matching its chip.
- **Site "has dives" keeps the list's count rule.** It lowers to `dives[planned = false AND excludedFromStats = false]`, because the site list's `diveCount` comes from `DiveStatsScope` (neither planned nor excluded) over every diver's dives.
- **Trips by equipment use the dive `gear` relation**, which also counts cylinders the transmitter registry matched through `dive_tanks.equipment_id`. The old `getTripIdsForEquipment` read only `dive_equipment`, so a trip whose only link to a cylinder was that match was missing from "trips with this gear". The equivalence test pins the one new row.
- **Site types become a query subject** (`QuerySubject.siteTypes`, table `site_types`), so `types = "Wreck"` resolves by name through the name index.
- **The site map stays unfiltered**, as today; only the list and table views read the filter.

## Global Constraints

- Branch `ericgriffin/query-lang-pr3-sites-equipment-trips` in worktree `.claude/worktrees/query-lang-pr3-sites-equipment-trips`, off `origin/main` at `47676e0b086`. Run every command from that directory. It is initialised (submodules, `flutter pub get`, codegen).
- No em-dashes anywhere (code, comments, docs, commits, PR text). No emojis. No mention of the tool or its vendor in anything written to the repository or GitHub.
- TDD: each task writes its failing test first, runs it red, then implements.
- Values reach SQL only as bound parameters. The one new raw clause (the owner scope) binds the diver id; the cache table is written through Drift companions.
- Anything showing a number with a unit uses the active diver's unit settings (`queryUnitPrefsProvider`); stored values stay metric.
- Schema: `currentSchemaVersion` becomes **242**. Main is at 240 (237 shipped); 241 is held by open PR #2493, 235 by #2454, 236 by #2407, 229 by #2409, 225 by #1978. Re-scan open PR diffs and every worktree scalar right before each push (`scratchpad/scan_rungs.py` pattern: REST `pulls?state=open`, then each PR's `database.dart` patch) and renumber if 242 was taken.
- The database is split: tables live in `lib/core/database/tables/*.dart`, migration helpers in `lib/core/database/migrations/helpers/*.dart` (parts of `app_database_migrations.dart`), steps in `migrations/ladder/rungs_v231_onward.dart`, backstops in `migrations/before_open.dart`; `database.dart` keeps only `migrationVersions`, `currentSchemaVersion` and the `@DriftDatabase` table list. `test/core/database/database_table_libraries_test.dart` enforces this and an 800-line cap.
- New ARB keys go in `app_en.arb` (with `@` metadata) and all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), translated. `app_de.arb` must not contain "SAC". After editing ARBs run `flutter gen-l10n` and commit the generated `lib/l10n/arb/app_localizations*.dart`. After adding any `query_*` key run `python3.14 scripts/gen_query_label_lookup.py`.
- Files stay under 800 lines; split by responsibility. Imports grouped dart, flutter, packages, local; package imports in `lib/`.
- After each task: `dart format .`, `flutter analyze --fatal-infos` clean, the task's tests green. Run `flutter test test/architecture/ test/l10n/` after any new `lib/` file, ARB change or main merge.
- Local `flutter test`: never pipe it into `grep` without checking the tail (the pipe hides the status); never run two suites at once. Check `df -h /Volumes/fltmp` before a long run.
- Commit only at the plan's commit steps, staging explicit paths. Push with hooks (`git push -u origin HEAD` the first time); if the hook's affected-test run hangs over 15 minutes, kill only that tree, run the flagged files alone, then `SKIP_TESTS=1 git push`. After merging main, `SKIP_TESTS=1` is fine once the merge-affected suites and `test/architecture/` pass.
- The PR touches `presentation/`, so its description needs screenshots (Task 15). Open it with `Refs #2365`, then `gh pr edit <n> --add-reviewer "@copilot"`.

## Review Focus

Inputs the spec implies that a person would hit first, each pinned by a test in the owning task.

1. **A stray space in a stored country** (`"Bonaire "`) still matches the Bonaire chip after the move to SQL. (Task 7, "a trimmed country matches".)
2. **A site with only planned or stats-excluded dives** is not "has dives", matching its zero count on the card. (Task 7, "planned and excluded dives do not count".)
3. **The unfiltered equipment list** shows exactly today's active items: never retired or sold gear, and a legacy `status = retired, is_active = 1` row stays hidden. (Task 9, "the default view hides retired and sold gear".)
4. **Switching diver never shows the previous diver's service verdicts**: the cache is rewritten from the new diver's evaluation before the service-due id set is read. (Task 5, "a diver switch rewrites the cache".)
5. **A broken advanced query on a list** (a saved query naming a field this build lacks) shows the list's error state rather than an empty list or a crash. (Task 8, "an invalid query surfaces as the list error".)

## File structure

Created:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_sites/query/site_type_query_entity.dart` | `siteTypeQueryEntity` (`site_types`, `name`) |
| `lib/features/dive_sites/query/site_filter_query.dart` | `SiteFilterQuery.toQuery()`, `compileSiteFilter`, `siteFilterTablesTouched` |
| `lib/features/equipment/query/equipment_attr_condition_query.dart` | `equipmentAttrConditionNode`: one attribute condition at equipment level, shared by the dive and equipment lowerings |
| `lib/features/equipment/query/equipment_filter_query.dart` | `EquipmentFilterQuery.toQuery()`, `.ownerScope()`, `compileEquipmentFilter` |
| `lib/features/trips/query/trip_filter_query.dart` | `TripFilterQuery.toQuery()`, `compileTripFilter` |
| `lib/features/query/data/query_id_set_runner.dart` | `QueryScope`, `QueryIdSetRunner` (ids for a compiled query, table ticks) |
| `lib/features/query/presentation/providers/query_id_set_providers.dart` | `queryIdSetRunnerProvider` |
| `lib/features/equipment/data/repositories/equipment_service_status_repository.dart` | read and diff-write the service cache |
| `lib/features/equipment/presentation/providers/equipment_service_status_providers.dart` | repository provider, `equipmentServiceStatusCacheProvider` |
| `lib/features/equipment/presentation/providers/equipment_query_providers.dart` | `queryFilteredEquipmentIdsProvider`, `filteredEquipmentProvider`, `equipmentTagsEmptiedProvider` |
| `lib/features/query/presentation/widgets/save_query_flow.dart` | `saveQueryFromEditor`, moved out of the dive search page |
| `lib/core/database/tables/equipment_service_status_tables.dart` | the `EquipmentServiceStatus` cache table |

Modified (main ones): `query_subject.dart`, the three entity files, `dive_filter_query.dart` (shared attribute helper), `app_query_registry.dart`, `app_query_labels.dart`, `query_name_index.dart`, `database.dart`, `app_database_migrations.dart`, `service_migrations.dart`, `rungs_v231_onward.dart`, `before_open.dart`, `site_providers.dart`, `equipment_filter_state.dart`, `equipment_providers.dart`, `equipment_list_content.dart`, `trip_providers.dart`, `dive_query_editor.dart`, `dive_query_chips.dart`, `dive_search_page.dart`, `site_filter_sheet.dart`, `site_list_content.dart`, `equipment_filter_sheet.dart`, the ARB files and the spec.

---

### Task 1: Site registry: difficulty, coordinates, dives, tags and site types

**Files:**
- Modify: `lib/core/query/domain/query_subject.dart`
- Create: `lib/features/dive_sites/query/site_type_query_entity.dart`
- Modify: `lib/features/dive_sites/query/site_query_entity.dart`
- Modify: `lib/features/query/app_query_registry.dart`, `lib/features/query/presentation/app_query_labels.dart`, `lib/features/query/data/query_name_index.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files), then regenerate
- Test: `test/features/dive_sites/query/site_query_entity_test.dart`; update `test/features/query/data/query_name_index_test.dart`

**Interfaces:**
- Produces: `QuerySubject.siteTypes`; `siteTypeQueryEntity`; site fields `difficulty` (enumName over `SiteDifficulty` names, compared lower-cased), `coordinates` (bool), `notes` (text); site relations `dives` (child to dives), `tags` (junction `site_tags`), `types` (junction `site_site_types`); site text search over name, country, region, city, island.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_sites/query/site_query_entity_test.dart
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000; // 2025-01-01

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', $now, $now)",
    );
    Future<void> site(String id, String extra, String values) =>
        db.customStatement(
          'INSERT INTO dive_sites (id, name, created_at, updated_at$extra) '
          "VALUES ('$id', '$id', $now, $now$values)",
        );
    await site('reef', ', difficulty, latitude, longitude',
        ", 'Advanced', 12.1, -68.2");
    await site('cave', ', difficulty', ", 'technical'");
    await site('bare', '', '');
    await db.customStatement(
      "INSERT INTO site_types (id, name, is_built_in, sort_order, created_at, "
      "updated_at) VALUES ('wreck', 'Wreck', 1, 0, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (site_id, site_type_id) "
      "VALUES ('cave', 'wreck')",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, site_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', 'me', 'reef', $now, $now, $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(String text) async {
    final parsed = QueryParser(
      appQueryRegistry,
      siteQueryEntity,
      ParseContext(prefs: kMetricPrefs, now: DateTime(2026), names: const MapNameResolver({
        QuerySubject.siteTypes: {'Wreck': 'wreck'},
      })),
    ).parse(text);
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, siteQueryEntity, appQueryRegistry), isEmpty);
    final c = compileQuery(node, siteQueryEntity, appQueryRegistry);
    final rows = await db
        .customSelect(
          c.idSubquery(),
          variables: [for (final p in c.params) Variable<Object>(p as Object)],
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  test('difficulty matches whatever case it was stored in', () async {
    expect(await ids('difficulty = advanced'), {'reef'});
    expect(await ids('difficulty in [advanced, technical]'), {'reef', 'cave'});
  });

  test('coordinates:any needs both halves of the position', () async {
    expect(await ids('coordinates:any'), {'reef'});
    expect(await ids('coordinates:none'), {'cave', 'bare'});
  });

  test('dives, types and text search reach the related rows', () async {
    expect(await ids('dives:any'), {'reef'});
    expect(await ids('types = "Wreck"'), {'cave'});
    expect(await ids('"cav"'), {'cave'});
  });
}
```

Before writing it, read the parser's constructor and `ParseContext` in `lib/core/query/syntax/query_parser.dart` and adjust the `QueryParser(...)` call to its real signature (the dive semantics test `test/features/dive_log/query/dive_query_semantics_test.dart` shows a working call); the three test bodies stay as written.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/query/site_query_entity_test.dart`
Expected: FAIL to compile (`QuerySubject.siteTypes` is not defined).

- [ ] **Step 3: Add the subject and the site type entity**

In `lib/core/query/domain/query_subject.dart` add `siteTypes` as the LAST enum value, with a one-line doc comment: `/// Site classification types (#1765), a relation target of sites.`

```dart
// lib/features/dive_sites/query/site_type_query_entity.dart
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// A site classification type (issue #1765), the target of the site
/// `types` relation. Built-ins carry a null diver id.
const siteTypeQueryEntity = QueryEntity(
  subject: QuerySubject.siteTypes,
  table: 'site_types',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_siteTypes_name',
    ),
  ],
);
```

Register it in `app_query_registry.dart` beside `siteQueryEntity`.

- [ ] **Step 4: Complete the site entity**

Replace `lib/features/dive_sites/query/site_query_entity.dart` with the version below. It becomes `final` (the enum list is not const), so update any `const` use of `siteQueryEntity` the analyzer reports.

```dart
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Every field and relation a site query can name (#2365). The site list's
/// filter lowers to these (`SiteFilterQuery`), and dive paths such as
/// `site.country` walk them.

QueryField _text(String key, String sql, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: sql,
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_sites_$key',
);

/// Site to one side of a site junction table.
QueryRelation _junction(
  String key,
  QuerySubject target,
  String junction,
  String targetColumn,
) => QueryRelation(
  key: key,
  target: target,
  shape: RelationShape.junction,
  joinSql:
      '{to}.id IN (SELECT j.$targetColumn FROM $junction j '
      'WHERE j.site_id = {from}.id)',
  isMany: true,
  labelKey: 'query_sites_$key',
  tables: [junction],
);

final siteQueryEntity = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.country LIKE ? ESCAPE '\\'",
    "{r}.region LIKE ? ESCAPE '\\'",
    "{r}.city LIKE ? ESCAPE '\\'",
    "{r}.island LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', '{r}.name', 'name'),
    // Trimmed: the location chips offer the trimmed spelling, and a stored
    // value with a stray space must still match it.
    _text('country', 'TRIM({r}.country)', 'country'),
    _text('region', 'TRIM({r}.region)', 'region'),
    _text('city', '{r}.city', 'city'),
    _text('island', '{r}.island', 'island'),
    _text('notes', '{r}.notes', 'notes'),
    const QueryField(
      key: 'rating',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'query_sites_rating',
      sanity: (min: 0, max: 5),
    ),
    const QueryField(
      key: 'maxDepth',
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'query_sites_maxDepth',
    ),
    // Stored as free text in any case ('Advanced', 'advanced'); the app
    // reads it case-insensitively, so the query does too.
    QueryField(
      key: 'difficulty',
      type: FieldType.enumName,
      sql: 'LOWER({r}.difficulty)',
      emptySql: "({r}.difficulty IS NULL OR TRIM({r}.difficulty) = '')",
      labelKey: 'query_sites_difficulty',
      enumValues: [for (final d in SiteDifficulty.values) d.name],
    ),
    // A position needs both halves, like `DiveSite.hasCoordinates`.
    const QueryField(
      key: 'coordinates',
      type: FieldType.bool,
      sql: '({r}.latitude IS NOT NULL AND {r}.longitude IS NOT NULL)',
      emptySql: '({r}.latitude IS NULL OR {r}.longitude IS NULL)',
      labelKey: 'query_sites_coordinates',
    ),
  ],
  relations: [
    const QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.site_id = {from}.id',
      isMany: true,
      labelKey: 'query_sites_dives',
    ),
    _junction('tags', QuerySubject.tags, 'site_tags', 'tag_id'),
    _junction('types', QuerySubject.siteTypes, 'site_site_types', 'site_type_id'),
  ],
);
```

If `validateQuery` refuses `:none`/`:any` on a bool field, rule it in the ledger and make `coordinates` a `FieldType.number` over `CASE WHEN ... THEN 1 END` with the same `emptySql`; the test stays as written.

- [ ] **Step 5: Name index, labels, ARB**

1. `query_name_index.dart`: add `QuerySubject.siteTypes` to `QueryNameIndexLoader.refSubjects` (after `sites`). In `query_name_index_test.dart` add `'site_types'` to the expected `tables` set and rename that test to "the tables it reads are the eleven ref tables and the share table".
2. `app_query_labels.dart`: in `enumValue`, add
   ```dart
   case 'query_sites_difficulty':
     return byName(SiteDifficulty.values)?.localizedName(_l10n) ?? value;
   ```
   importing `dive_site.dart` and `site_difficulty_display.dart`.
3. ARB keys (English below; translate for the ten other locales):
   `query_entity_siteTypes` "Site types", `query_siteTypes_name` "Name", `query_sites_notes` "Notes", `query_sites_difficulty` "Difficulty", `query_sites_coordinates` "Coordinates", `query_sites_dives` "Dives", `query_sites_tags` "Tags", `query_sites_types` "Site types". Each `@` entry has a `description` naming the query builder.
4. Run `flutter gen-l10n` and `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_sites/query/ test/features/query/ test/core/query/`
Expected: PASS, including `query_registry_guards_test.dart` (every new fragment compiles, tables declared, labels in every locale) and `app_query_registry_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/core/query/domain/query_subject.dart lib/features/dive_sites/query/ lib/features/query/app_query_registry.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/features/query/data/query_name_index.dart lib/l10n/arb/ test/features/dive_sites/query/site_query_entity_test.dart test/features/query/data/query_name_index_test.dart
git commit -m "feat(query): the site registry names difficulty, coordinates, dives, tags and site types"
```

### Task 2: Trip registry: type, resort, liveaboard, notes, sharing and dives

**Files:**
- Modify: `lib/features/trips/query/trip_query_entity.dart`, `app_query_labels.dart`, ARB files
- Test: `test/features/trips/query/trip_query_entity_test.dart`

**Interfaces:**
- Produces: trip fields `tripType` (enumName over `TripType`), `resortName`, `liveaboardName`, `notes` (text), `shared` (bool `is_shared`); relation `dives` (child to dives, `{to}.trip_id = {from}.id`); text search over name, location, resort, liveaboard.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/trips/query/trip_query_entity_test.dart
// Same harness as Task 1's test (setUp seeds divers 'me'; an `ids(text)`
// helper parses against tripQueryEntity with an empty name resolver,
// validates, compiles and runs idSubquery()).
// Seed:
//   trips: ('boat', trip_type 'liveaboard', liveaboard_name 'Aurora'),
//          ('beach', trip_type 'shore', is_shared 1), ('home', no dives)
//   dives: d1 on 'boat', d2 on 'beach' (both diver 'me').
test('trip type, sharing and dives are queryable', () async {
  expect(await ids('tripType = liveaboard'), {'boat'});
  expect(await ids('shared = true'), {'beach'});
  expect(await ids('dives:none'), {'home'});
  expect(await ids('"auro"'), {'boat'});
});
```

Write it out in full following Task 1's file (imports, `setUp` inserting `trips` rows with `id, name, start_date, end_date, created_at, updated_at` plus the listed columns, and dives with `trip_id`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/trips/query/trip_query_entity_test.dart`
Expected: FAIL (the parser reports unknown field `tripType`).

- [ ] **Step 3: Complete the trip entity**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_trips_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_trips_$key',
);

/// Every field and relation a trip query can name (#2365). The trip list's
/// filter lowers to these (`TripFilterQuery`); dive paths such as
/// `trip.tripType` walk them.
final tripQueryEntity = QueryEntity(
  subject: QuerySubject.trips,
  table: 'trips',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.location LIKE ? ESCAPE '\\'",
    "{r}.resort_name LIKE ? ESCAPE '\\'",
    "{r}.liveaboard_name LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    _text('location', 'location'),
    _date('startDate', 'start_date'),
    _date('endDate', 'end_date'),
    QueryField(
      key: 'tripType',
      type: FieldType.enumName,
      sql: '{r}.trip_type',
      emptySql: '{r}.trip_type IS NULL',
      labelKey: 'query_trips_tripType',
      enumValues: [for (final t in TripType.values) t.name],
    ),
    _text('resortName', 'resort_name'),
    _text('liveaboardName', 'liveaboard_name'),
    _text('notes', 'notes'),
    const QueryField(
      key: 'shared',
      type: FieldType.bool,
      sql: '{r}.is_shared',
      emptySql: '0',
      labelKey: 'query_trips_shared',
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.trip_id = {from}.id',
      isMany: true,
      labelKey: 'query_trips_dives',
    ),
  ],
);
```

Fix any `const` use of `tripQueryEntity` the analyzer reports.

- [ ] **Step 4: Labels and ARB**

`app_query_labels.dart` `enumValue`:

```dart
case 'query_trips_tripType':
  return switch (byName(TripType.values)) {
    TripType.shore => _l10n.trips_type_shore,
    TripType.liveaboard => _l10n.trips_type_liveaboard,
    TripType.resort => _l10n.trips_type_resort,
    TripType.dayTrip => _l10n.trips_type_dayTrip,
    null => value,
  };
```

ARB (translate for all locales): `query_trips_tripType` "Trip type", `query_trips_resortName` "Resort", `query_trips_liveaboardName` "Liveaboard", `query_trips_notes` "Notes", `query_trips_shared` "Shared", `query_trips_dives` "Dives". Then `flutter gen-l10n` and the label lookup script.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/trips/query/ test/features/query/ test/core/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/query/trip_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb/ test/features/trips/query/trip_query_entity_test.dart
git commit -m "feat(query): the trip registry names trip type, resort, liveaboard, notes, sharing and dives"
```

### Task 3: Equipment registry: tags, dives, and one attribute-condition lowering

**Files:**
- Create: `lib/features/equipment/query/equipment_attr_condition_query.dart`
- Modify: `lib/features/equipment/query/equipment_query_entity.dart`, `lib/features/dive_log/query/dive_filter_query.dart`, ARB files
- Test: `test/features/equipment/query/equipment_query_entity_test.dart`; the existing `test/features/dive_log/query/dive_filter_query_test.dart` must stay green unchanged.

**Interfaces:**
- Produces: `QueryNode equipmentAttrConditionNode(EquipmentAttrCondition cond)` (an `AndNode` at equipment level: optional `type in [...]`, then `attributes[...]`); equipment relations `tags` (junction `equipment_tags`) and `dives` (custom: the dive gear union reversed).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/query/equipment_query_entity_test.dart
// Harness as Task 1 (parse against equipmentQueryEntity, run idSubquery()).
// Seed: equipment ('suit', type wetsuit), ('reg', type regulator),
//       ('tank', type cylinder); tags ('t1', 'Travel') with
//       equipment_tags ('suit' -> 't1'); dive d1 with dive_equipment
//       (d1, 'reg') and dive_tanks (d1, equipment_id 'tank');
//       equipment_attributes ('suit', attr_key 'thickness_mm',
//       is_custom 0, value_num 5).
test('tags, dives and attributes reach the related rows', () async {
  expect(await ids('tags:any'), {'suit'});
  // The gear union: a cylinder matched through dive_tanks counts too.
  expect(await ids('dives:any'), {'reg', 'tank'});
  expect(
    await ids('attributes[key = thickness_mm AND valueNum >= 5]'),
    {'suit'},
  );
});

test('equipmentAttrConditionNode keeps the dive lowering unchanged', () {
  final cond = EquipmentAttrCondition.suitThickness(min: 5);
  final node = equipmentAttrConditionNode(cond);
  expect(node, isA<AndNode>());
  expect((node as AndNode).children, hasLength(2));
});
```

Write it in full with Task 1's harness. `ids` for `tags:any` needs `QuerySubject.tags` in the resolver only for ref values; `:any` needs none.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/query/equipment_query_entity_test.dart`
Expected: FAIL to compile (`equipmentAttrConditionNode` undefined).

- [ ] **Step 3: Extract the attribute lowering**

```dart
// lib/features/equipment/query/equipment_attr_condition_query.dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

/// One curated attribute condition at equipment level: an item of one of
/// [EquipmentAttrCondition.types] carrying a curated row for the key whose
/// text is one of the choices and whose number is in range. The ONE
/// lowering of [EquipmentAttrCondition.matches]: the dive filter wraps it
/// in `gear[...]`, the equipment filter uses it at the root.
QueryNode equipmentAttrConditionNode(EquipmentAttrCondition cond) {
  QueryNode c(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);
  final types = cond.types.map((t) => t.name).toList()..sort();
  final choices = cond.choices.toList()..sort();
  return AndNode([
    if (types.isNotEmpty)
      c('type', QueryOp.inList, ListValue([for (final t in types) EnumValue(t)])),
    ScopedNode(
      FieldPath(['attributes']),
      AndNode([
        c('key', QueryOp.eq, StringValue(cond.key)),
        c('custom', QueryOp.eq, const BoolValue(false)),
        if (choices.isNotEmpty)
          c(
            'valueText',
            QueryOp.inList,
            ListValue([for (final ch in choices) StringValue(ch)]),
          ),
        if (cond.min != null)
          c('valueNum', QueryOp.gte, NumberValue(cond.min!, null)),
        if (cond.max != null)
          c('valueNum', QueryOp.lte, NumberValue(cond.max!, null)),
      ]),
    ),
  ]);
}
```

In `dive_filter_query.dart`, replace the body of `_attrCondition` with

```dart
QueryNode _attrCondition(EquipmentAttrCondition cond) =>
    ScopedNode(FieldPath(['gear']), equipmentAttrConditionNode(cond));
```

and update its doc comment to point at the shared helper. The produced tree is identical, so `dive_filter_query_test.dart` needs no change.

- [ ] **Step 4: Add the relations**

In `equipment_query_entity.dart` add to `relations`:

```dart
QueryRelation(
  key: 'tags',
  target: QuerySubject.tags,
  shape: RelationShape.junction,
  joinSql:
      '{to}.id IN (SELECT j.tag_id FROM equipment_tags j '
      'WHERE j.equipment_id = {from}.id)',
  isMany: true,
  labelKey: 'query_equipment_tags',
  tables: ['equipment_tags'],
),
// The dive gear union (`kDiveGearJoinSql`) read from the item's side:
// linked through dive_equipment, or a cylinder matched through dive_tanks.
QueryRelation(
  key: 'dives',
  target: QuerySubject.dives,
  shape: RelationShape.custom,
  joinSql:
      '{to}.id IN (SELECT de.dive_id FROM dive_equipment de '
      'WHERE de.equipment_id = {from}.id '
      'UNION SELECT dt.dive_id FROM dive_tanks dt '
      'WHERE dt.equipment_id = {from}.id)',
  isMany: true,
  labelKey: 'query_equipment_dives',
  tables: ['dive_equipment', 'dive_tanks'],
),
```

ARB (all locales): `query_equipment_tags` "Tags", `query_equipment_dives` "Dives". Run `flutter gen-l10n` and the label lookup script.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/query/ test/features/dive_log/query/ test/features/query/ test/core/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/query/ lib/features/dive_log/query/dive_filter_query.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb/ test/features/equipment/query/equipment_query_entity_test.dart
git commit -m "feat(query): the equipment registry names tags and dives; one attribute-condition lowering for dives and gear"
```

### Task 4: The service status cache table (schema 242)

**Files:**
- Create: `lib/core/database/tables/equipment_service_status_tables.dart`
- Modify: `lib/core/database/database.dart`, `lib/core/database/migrations/helpers/service_migrations.dart`, `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/before_open.dart`
- Test: `test/core/database/migration_v242_equipment_service_status_test.dart`; relax `test/core/database/migration_v240_profile_events_dive_index_test.dart`

**Interfaces:**
- Produces: Drift table `equipmentServiceStatus` (`equipment_service_status`: `equipment_id` PK FK cascade, `severity`, `due_date` nullable, `computed_at`), data class `EquipmentServiceStatusRow`; helper `_assertEquipmentServiceStatusTable()`; `currentSchemaVersion = 242`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/migration_v242_equipment_service_status_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

Future<Set<String>> _tables(AppDatabase db) async => {
  for (final r in await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get())
    r.read<String>('name'),
};

void main() {
  test('v242 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 242);
    expect(AppDatabase.migrationVersions, contains(242));
    expect(AppDatabase.migrationStepCount(240), 1);
    // A local cache: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the cache table and no hlc column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _tables(db), contains('equipment_service_status'));
    final cols = await db
        .customSelect("PRAGMA table_info('equipment_service_status')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), isNot(contains('hlc')));
  });

  test('a database already at the current version gains the table', () async {
    // Only the beforeOpen backstop can add it there.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(await _tables(db), contains('equipment_service_status'));
  });
}
```

Check `minimumCompatibleSchemaVersion` on main before running (it was raised to 240 by #2445); assert whatever value main has, unchanged.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v242_equipment_service_status_test.dart`
Expected: FAIL (`currentSchemaVersion` is 240).

- [ ] **Step 3: Add the table**

```dart
// lib/core/database/tables/equipment_service_status_tables.dart
/// The equipment service cache the query language filters on.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Each active item's worst service severity for the ACTIVE diver, as
/// `ServiceDueEngine` last evaluated it (#2365 PR 3). A local cache: no
/// hlc column, so sync never reads or writes it, and a diver switch
/// rewrites it. The `serviceDue` query field reads it; an item with no
/// row reads as ok.
@DataClassName('EquipmentServiceStatusRow')
class EquipmentServiceStatus extends Table {
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// A `ServiceClockSeverity` name: ok, dueSoon or overdue.
  TextColumn get severity => text()();

  /// The worst clock's date trigger, epoch ms, when it has one.
  IntColumn get dueDate => integer().nullable()();
  IntColumn get computedAt => integer()();

  @override
  Set<Column> get primaryKey => {equipmentId};
}
```

In `database.dart`: import and export the new library (alphabetical among the table imports/exports), add `EquipmentServiceStatus` to the `@DriftDatabase` table list after `EquipmentOwnershipEvents` with the comment `// Equipment service cache for the query language (v242, issue #2365), local`, append to `migrationVersions`

```dart
    // v242: equipment_service_status, the local service-due cache the
    // query language's serviceDue field reads (issue #2365, PR 3). A table
    // with no hlc, never synced, so the floor does not move. 241 was held
    // by #2493 when this was taken.
    242,
```

and set `currentSchemaVersion = 242`.

- [ ] **Step 4: Helper, step and backstop**

In `migrations/helpers/service_migrations.dart` add to its extension:

```dart
  /// v242: the local service-due cache (issue #2365). Idempotent; skipped
  /// on a partial fixture with no equipment table to reference.
  Future<void> _assertEquipmentServiceStatusTable() async {
    if (!await _tableExists('equipment')) return;
    await Migrator(this).createTable(equipmentServiceStatus);
  }
```

In `rungs_v231_onward.dart` after the v240 block:

```dart
    // v242: the equipment service cache (issue #2365). Table-only rung;
    // re-asserted in beforeOpen.
    if (from < 242) {
      await _assertEquipmentServiceStatusTable();
    }
    if (from < 242) await reportProgress();
```

In `before_open.dart`, next to the v238 saved queries backstop:

```dart
    // v242 backstop: the equipment service cache (local, idempotent).
    await _assertEquipmentServiceStatusTable();
```

Relax the v240 test's exact-version test the way the earlier rungs were: rename it to "v240 is at or below the current schema version and in the ladder", assert `greaterThanOrEqualTo(240)` and `migrationStepCount(239)` `greaterThanOrEqualTo(1)`, with the comment `// Relaxed once v242 (equipment service cache) landed on top; the newest rung owns the exact assertion.`

- [ ] **Step 5: Codegen and run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs` (through a two-line script in the scratchpad that `cd`s to the worktree, since a bare `build` token is refused), then
`flutter test test/core/database/ test/core/services/sync/ test/architecture/`
Expected: PASS, including `database_table_libraries_test.dart` and `sync_hlc_target_registration_test.dart` (no hlc, so no registration).

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/tables/equipment_service_status_tables.dart lib/core/database/database.dart lib/core/database/migrations/ test/core/database/migration_v242_equipment_service_status_test.dart test/core/database/migration_v240_profile_events_dive_index_test.dart
git commit -m "feat(db): v242 equipment_service_status, the local service-due cache"
```

### Task 5: Write the cache from the engine; the `serviceDue` field

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_service_status_repository.dart`, `lib/features/equipment/presentation/providers/equipment_service_status_providers.dart`
- Modify: `lib/features/equipment/query/equipment_query_entity.dart`, `app_query_labels.dart`, ARB files
- Test: `test/features/equipment/data/equipment_service_status_repository_test.dart`, `test/features/equipment/presentation/providers/equipment_service_status_cache_test.dart`

**Interfaces:**
- Produces: `EquipmentServiceStatusRepository` with `Future<void> replaceAll(Map<String, ServiceStatusEntry> byId, {required int computedAt})` and `Future<Map<String, String>> severities()`; typedef `ServiceStatusEntry = ({String severity, int? dueDate})`; `equipmentServiceStatusRepositoryProvider`; `equipmentServiceStatusCacheProvider` (`FutureProvider<void>`); equipment field `serviceDue` (enumName `ok`, `dueSoon`, `overdue`).

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/equipment/data/equipment_service_status_repository_test.dart
// setUpTestDatabase(); seed equipment rows 'a', 'b', 'c'.
test('replaceAll writes the map exactly and leaves unchanged rows alone', () async {
  final repo = EquipmentServiceStatusRepository();
  await repo.replaceAll({
    'a': (severity: 'overdue', dueDate: 1),
    'b': (severity: 'ok', dueDate: null),
  }, computedAt: 10);
  expect(await repo.severities(), {'a': 'overdue', 'b': 'ok'});

  var ticks = 0;
  final sub = db.tableUpdates(TableUpdateQuery.onTable(db.equipmentServiceStatus))
      .listen((_) => ticks++);
  addTearDown(sub.cancel);
  // Same verdicts, later clock: no write, so no list re-query.
  await repo.replaceAll({
    'a': (severity: 'overdue', dueDate: 1),
    'b': (severity: 'ok', dueDate: null),
  }, computedAt: 20);
  await pumpEventQueue();
  expect(ticks, 0);

  // 'b' goes, 'c' arrives, 'a' changes.
  await repo.replaceAll({
    'a': (severity: 'dueSoon', dueDate: 2),
    'c': (severity: 'ok', dueDate: null),
  }, computedAt: 30);
  expect(await repo.severities(), {'a': 'dueSoon', 'c': 'ok'});
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/equipment_service_status_repository_test.dart`
Expected: FAIL to compile (repository undefined).

- [ ] **Step 3: Implement the repository**

```dart
// lib/features/equipment/data/repositories/equipment_service_status_repository.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

typedef ServiceStatusEntry = ({String severity, int? dueDate});

/// The local service-due cache (`equipment_service_status`, v242): each
/// active item's worst severity for the active diver, as the engine last
/// evaluated it. Written only through [replaceAll], which writes nothing
/// when nothing changed so a steady list does not re-query.
class EquipmentServiceStatusRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(EquipmentServiceStatusRepository);

  Future<Map<String, String>> severities() async => {
    for (final r in await _db.select(_db.equipmentServiceStatus).get())
      r.equipmentId: r.severity,
  };

  Future<void> replaceAll(
    Map<String, ServiceStatusEntry> byId, {
    required int computedAt,
  }) async {
    try {
      final existing = {
        for (final r in await _db.select(_db.equipmentServiceStatus).get())
          r.equipmentId: r,
      };
      final stale = existing.keys.where((id) => !byId.containsKey(id)).toList();
      final changed = {
        for (final e in byId.entries)
          if (existing[e.key]?.severity != e.value.severity ||
              existing[e.key]?.dueDate != e.value.dueDate)
            e.key: e.value,
      };
      if (stale.isEmpty && changed.isEmpty) return;
      await _db.batch((b) {
        if (stale.isNotEmpty) {
          b.deleteWhere(
            _db.equipmentServiceStatus,
            (t) => t.equipmentId.isIn(stale),
          );
        }
        for (final e in changed.entries) {
          b.insert(
            _db.equipmentServiceStatus,
            EquipmentServiceStatusCompanion.insert(
              equipmentId: e.key,
              severity: e.value.severity,
              dueDate: Value(e.value.dueDate),
              computedAt: computedAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } catch (e, st) {
      _log.error('Failed to write the service status cache', error: e, stackTrace: st);
      rethrow;
    }
  }
}
```

Run the test: PASS.

- [ ] **Step 4: Write the failing cache provider test**

```dart
// test/features/equipment/presentation/providers/equipment_service_status_cache_test.dart
// A ProviderContainer over the real test database with diver 'me' current
// (use the seedCurrentDiver helper equipment_providers_test.dart uses).
// Seed three active items owned by 'me':
//   'late'  : a service_schedules row (interval_days 30, enabled 1) of a
//             service kind, with anchor_date 400 days ago  -> overdue
//   'soon'  : interval_days 30, anchor 25 days ago           -> dueSoon
//   'fresh' : interval_days 365, anchor 1 day ago            -> ok
test('the cache holds each active item\'s worst severity', () async {
  await container.read(equipmentServiceStatusCacheProvider.future);
  expect(
    await EquipmentServiceStatusRepository().severities(),
    {'late': 'overdue', 'soon': 'dueSoon', 'fresh': 'ok'},
  );
});

test('the serviceDue field matches the engine\'s worst clocks', () async {
  await container.read(equipmentServiceStatusCacheProvider.future);
  // equipmentWorstClockProvider is what the row badges read; it stays
  // when Task 10 retires the service-due list provider.
  final worst = await container.read(equipmentWorstClockProvider.future);
  Set<String> having(bool Function(ServiceClockSeverity) keep) => {
    for (final e in worst.entries)
      if (keep(e.value.status.severity)) e.key,
  };
  expect(
    await sqlIds('serviceDue in [dueSoon, overdue]'),
    having((s) => s != ServiceClockSeverity.ok),
  );
  expect(
    await sqlIds('serviceDue = overdue'),
    having((s) => s == ServiceClockSeverity.overdue),
  );
  expect(
    await sqlIds('serviceDue = dueSoon'),
    having((s) => s == ServiceClockSeverity.dueSoon),
  );
});

test('a diver switch rewrites the cache', () async {
  await container.read(equipmentServiceStatusCacheProvider.future);
  // 'other' owns no gear and nothing is shared with them.
  await container.read(currentDiverIdProvider.notifier).setCurrentDiver('other');
  await container.read(equipmentServiceStatusCacheProvider.future);
  expect(await EquipmentServiceStatusRepository().severities(), isEmpty);
});
```

`sqlIds(text)` is Task 1's `ids` helper against `equipmentQueryEntity`. Read `service_clock_baseline_test.dart` for the exact rows a schedule and kind need, and put the seeding in a local helper.

- [ ] **Step 5: Implement the provider and the field**

```dart
// lib/features/equipment/presentation/providers/equipment_service_status_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_service_status_repository.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final equipmentServiceStatusRepositoryProvider =
    Provider<EquipmentServiceStatusRepository>(
      (ref) => EquipmentServiceStatusRepository(),
    );

/// Mirrors [activeEquipmentClocksProvider] into the local cache the
/// `serviceDue` query field reads. The engine lists statuses worst first,
/// so the first is the item's verdict, the same one
/// [equipmentWorstClockProvider] and the row badges show. Re-runs whenever
/// the clocks do (a ledger write, a share, a diver switch). Read it before
/// running a query whose `tablesTouched` names `equipment_service_status`.
final equipmentServiceStatusCacheProvider = FutureProvider<void>((ref) async {
  final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
  await ref.read(equipmentServiceStatusRepositoryProvider).replaceAll({
    for (final e in evaluated)
      e.item.id: e.statuses.isEmpty
          ? (severity: ServiceClockSeverity.ok.name, dueDate: null)
          : (
              severity: e.statuses.first.severity.name,
              dueDate: e.statuses.first.dueDate?.millisecondsSinceEpoch,
            ),
  }, computedAt: DateTime.now().millisecondsSinceEpoch);
});
```

Confirm `ServiceClockSeverity`'s value names are exactly `ok`, `dueSoon`, `overdue` (grep its enum); if they differ, store its names and use them in the field below.

Add to `equipmentQueryEntity.fields`:

```dart
// The service engine's verdict for the active diver (#2365 PR 3), read
// from the local cache the engine writes; an item it never evaluated
// (retired, sold, not visible) reads as ok.
const QueryField(
  key: 'serviceDue',
  type: FieldType.enumName,
  sql:
      "COALESCE((SELECT s.severity FROM equipment_service_status s "
      "WHERE s.equipment_id = {r}.id), 'ok')",
  emptySql: '0',
  labelKey: 'query_equipment_serviceDue',
  enumValues: ['ok', 'dueSoon', 'overdue'],
  tables: ['equipment_service_status'],
),
```

`app_query_labels.dart` `enumValue`:

```dart
case 'query_equipment_serviceDue':
  return queryLabelForKey(_l10n, 'query_equipment_serviceDue_$value');
```

ARB (all locales): `query_equipment_serviceDue` "Service due", `query_equipment_serviceDue_ok` "Up to date", `query_equipment_serviceDue_dueSoon` "Due soon", `query_equipment_serviceDue_overdue` "Overdue". `flutter gen-l10n`, label lookup script.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/ test/features/query/ test/architecture/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_service_status_repository.dart lib/features/equipment/presentation/providers/equipment_service_status_providers.dart lib/features/equipment/query/equipment_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb/ test/features/equipment/data/equipment_service_status_repository_test.dart test/features/equipment/presentation/providers/equipment_service_status_cache_test.dart
git commit -m "feat(query): serviceDue is a query field, read from a cache the service engine writes"
```

### Task 6: One id-set runner for every list

**Files:**
- Create: `lib/features/query/data/query_id_set_runner.dart`, `lib/features/query/presentation/providers/query_id_set_providers.dart`
- Test: `test/features/query/data/query_id_set_runner_test.dart`

**Interfaces:**
- Produces: `typedef QueryScope = ({String sql, List<Object> params})` (a clause over the compiled query's root alias); `QueryIdSetRunner(AppDatabase)` with `Future<Set<String>> ids(CompiledQuery compiled, {QueryScope? scope})`, `Set<TableInfo> tablesNamed(Set<String>)`, `Stream<void> watchTables(Set<String>)`; `queryIdSetRunnerProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/query/data/query_id_set_runner_test.dart
// setUpTestDatabase(); two dive_sites: 'a' (diver 'me'), 'b' (no diver).
test('ids runs the compiled query and ANDs a scope', () async {
  final runner = QueryIdSetRunner(db);
  final all = compileQuery(null, siteQueryEntity, appQueryRegistry);
  expect(await runner.ids(all), {'a', 'b'});
  expect(
    await runner.ids(all, scope: (sql: 'r0.diver_id = ?', params: ['me'])),
    {'a'},
  );
});

test('watchTables ticks on a write to a named table', () async {
  final runner = QueryIdSetRunner(db);
  final ticks = <void>[];
  final sub = runner.watchTables({'site_tags'}).listen(ticks.add);
  addTearDown(sub.cancel);
  await db.customInsert(
    "INSERT INTO tags (id, name, created_at, updated_at) VALUES ('t', 't', 0, 0)",
    updates: {db.tags},
  );
  await db.customInsert(
    "INSERT INTO site_tags (site_id, tag_id) VALUES ('a', 't')",
    updates: {db.siteTags},
  );
  await Future<void>.delayed(const Duration(milliseconds: 400));
  expect(ticks, isNotEmpty);
});
```

Check `site_tags` and `tags` required columns in `tables/site_tables.dart` and `tables/tag_tables.dart` and adjust the two inserts.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/query/data/query_id_set_runner_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

```dart
// lib/features/query/data/query_id_set_runner.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/utils/stream_debounce.dart';

/// A clause the CALLER applies beside a compiled query, over its root alias
/// (`r0`): visibility-style narrowing that compares rows with the active
/// diver, which a saved query must not name. Values are bound.
typedef QueryScope = ({String sql, List<Object> params});

/// Runs any entity's [CompiledQuery] as an id set (#2365 PR 3). The site,
/// equipment and trip lists narrow their hydrated rows to it, so loading,
/// sorting and grouping stay where they are.
class QueryIdSetRunner {
  QueryIdSetRunner(this._db);

  final AppDatabase _db;

  /// The same debounce the dive list's ticks use.
  static const changeTickDebounce = Duration(milliseconds: 300);

  Future<Set<String>> ids(CompiledQuery compiled, {QueryScope? scope}) async {
    final a = compiled.rootAlias;
    final clauses = [
      if (!compiled.isEmpty) compiled.where,
      if (scope != null) scope.sql,
    ];
    final rows = await _db
        .customSelect(
          'SELECT $a.${compiled.idColumn} AS id FROM ${compiled.table} $a'
          '${clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}'}',
          variables: [
            for (final p in compiled.params) Variable<Object>(p as Object),
            if (scope != null)
              for (final p in scope.params) Variable<Object>(p),
          ],
          readsFrom: tablesNamed(compiled.tablesTouched),
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  Set<TableInfo> tablesNamed(Set<String> names) => {
    for (final n in names)
      _db.allTables.firstWhere(
        (t) => t.actualTableName == n,
        orElse: () => throw ArgumentError.value(n, 'names', 'unknown table'),
      ),
  };

  Stream<void> watchTables(Set<String> names) => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          for (final t in tablesNamed(names)) TableUpdateQuery.onTable(t),
        ]),
      )
      .debounce(changeTickDebounce);
}
```

```dart
// lib/features/query/presentation/providers/query_id_set_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

final queryIdSetRunnerProvider = Provider<QueryIdSetRunner>(
  (ref) => QueryIdSetRunner(DatabaseService.instance.database),
);
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/query/data/query_id_set_runner_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/query/data/query_id_set_runner.dart lib/features/query/presentation/providers/query_id_set_providers.dart test/features/query/data/query_id_set_runner_test.dart
git commit -m "feat(query): one id-set runner for the site, equipment and trip lists"
```

### Task 7: `SiteFilterState` lowers to the query

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart` (`SiteFilterState`)
- Create: `lib/features/dive_sites/query/site_filter_query.dart`
- Test: `test/features/dive_sites/query/site_filter_query_census_test.dart`, `test/features/dive_sites/query/site_filter_apply_equivalence_test.dart`

**Interfaces:**
- Consumes: Task 1's site fields and relations; Task 6's runner.
- Produces: `SiteFilterState.query` (`QueryNode?`), `copyWith(query:, clearQuery:)`, value `==`/`hashCode`; `extension SiteFilterQuery on SiteFilterState { QueryNode? toQuery() }`; `CompiledQuery compileSiteFilter(SiteFilterState, {String rootAlias = 'r0'})`; `Set<String> siteFilterTablesTouched(SiteFilterState)`.

- [ ] **Step 1: Write the census test**

```dart
// test/features/dive_sites/query/site_filter_query_census_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every SiteFilterState field is lowered: a field added to the state and
/// not named in site_filter_query.dart fails here.
void main() {
  test('every SiteFilterState field is lowered', () {
    final state = File(p.join('lib', 'features', 'dive_sites', 'presentation',
            'providers', 'site_providers.dart'))
        .readAsStringSync();
    final start = state.indexOf('class SiteFilterState');
    final body = state.substring(start, state.indexOf('\n}\n', start));
    final fields = RegExp(r'^  final [\w<>?, .]+ (\w+);', multiLine: true)
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toList();
    expect(fields, contains('query'));
    final lowering = File(p.join('lib', 'features', 'dive_sites', 'query',
            'site_filter_query.dart'))
        .readAsStringSync();
    for (final f in fields) {
      expect(lowering, contains(RegExp('\\b$f\\b')), reason: f);
    }
  });
}
```

- [ ] **Step 2: Write the equivalence test**

```dart
// test/features/dive_sites/query/site_filter_apply_equivalence_test.dart
// Deleted in Task 8 together with apply(): it proves the deletion.
//
// setUpTestDatabase(); divers 'me' and 'other'. Sites:
//   'bon'  : country 'Bonaire ', region 'Klein', difficulty 'Advanced',
//            max_depth 30, rating 4, lat/long set, diver 'me'
//   'cur'  : country 'curacao', difficulty 'beginner', max_depth 12,
//            rating 2, diver 'me'
//   'shr'  : country 'Bonaire', is_shared 1, diver 'other'
//   'hid'  : country 'Bonaire', diver 'other' (not shared, not visible)
//   'plan' : diver 'me', only a planned dive and an excluded dive
// Dives: one counted dive at 'bon' (diver 'other', to prove the count is
// not diver-scoped), 'plan' has is_planned 1 and excluded_from_stats 1 dives.
// Site types: 'wreck' on 'cur'. Tags: 't1' on 'bon'.
Future<void> expectSame(SiteFilterState f) async {
  final visible = await SiteRepository().getSitesWithDiveCounts(diverId: 'me');
  final viaApply = {for (final s in f.apply(visible)) s.site.id};
  final ids = await QueryIdSetRunner(db).ids(compileSiteFilter(f));
  final viaSql = {
    for (final s in visible)
      if (ids.contains(s.site.id)) s.site.id,
  };
  expect(viaSql, viaApply, reason: '$f');
}

test('every axis selects what apply() selected', () async {
  for (final f in [
    const SiteFilterState(),
    const SiteFilterState(country: 'Bonaire'),
    const SiteFilterState(country: 'bonaire', region: 'Klein'),
    const SiteFilterState(difficulty: SiteDifficulty.advanced),
    const SiteFilterState(minDepth: 20),
    const SiteFilterState(maxDepth: 20),
    const SiteFilterState(minRating: 3),
    const SiteFilterState(hasCoordinates: true),
    const SiteFilterState(hasCoordinates: false),
    const SiteFilterState(hasDives: true),
    const SiteFilterState(hasDives: false),
    const SiteFilterState(siteTypeIds: {'wreck'}),
    const SiteFilterState(tagIds: {'t1'}),
    const SiteFilterState(country: 'Bonaire', hasDives: true, tagIds: {'t1'}),
  ]) {
    await expectSame(f);
  }
});

test('a trimmed country matches', () async {
  final ids = await QueryIdSetRunner(db)
      .ids(compileSiteFilter(const SiteFilterState(country: 'Bonaire')));
  expect(ids, containsAll(['bon', 'shr']));
});

test('planned and excluded dives do not count', () async {
  final ids = await QueryIdSetRunner(db)
      .ids(compileSiteFilter(const SiteFilterState(hasDives: true)));
  expect(ids, isNot(contains('plan')));
  expect(ids, contains('bon'));
});
```

Write the seeding in full with Drift companions (`DiveSitesCompanion.insert`, `DivesCompanion.insert`) or `customStatement`, following `site_repository_aggregates_test.dart`.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/dive_sites/query/`
Expected: FAIL (`site_filter_query.dart` missing; `compileSiteFilter` undefined).

- [ ] **Step 4: Give the state its query and value equality**

In `SiteFilterState`: add `final QueryNode? query;` and the `this.query` constructor parameter; include `query != null` in `hasActiveFilters`; add `QueryNode? query, bool clearQuery = false` to `copyWith` (`query: clearQuery ? null : (query ?? this.query)`); add `==` and `hashCode` over every field (use `setEquals` for the two sets and `Object.hash`), since the id-set family in Task 8 is keyed on the state (spec deviation "DiveFilterState has value equality").

- [ ] **Step 5: Write the lowering**

```dart
// lib/features/dive_sites/query/site_filter_query.dart
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Lowers the site filter sheet to the query tree (#2365). The ONLY
/// evaluator of a SiteFilterState: a field added to it and not named here
/// fails `site_filter_query_census_test`.
extension SiteFilterQuery on SiteFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    ListValue refs(Set<String> ids) => ListValue([
      for (final id in ids.toList()..sort()) RefValue(id, id),
    ]);

    if (country != null) {
      parts.add(c('country', QueryOp.eq, StringValue(country!.trim())));
    }
    if (region != null) {
      parts.add(c('region', QueryOp.eq, StringValue(region!.trim())));
    }
    if (difficulty != null) {
      parts.add(c('difficulty', QueryOp.eq, EnumValue(difficulty!.name)));
    }
    if (minDepth != null) {
      parts.add(c('maxDepth', QueryOp.gte, NumberValue(minDepth!, null)));
    }
    if (maxDepth != null) {
      parts.add(c('maxDepth', QueryOp.lte, NumberValue(maxDepth!, null)));
    }
    if (minRating != null) {
      parts.add(c('rating', QueryOp.gte, NumberValue(minRating!, null)));
    }
    if (hasCoordinates != null) {
      parts.add(
        c('coordinates', hasCoordinates! ? QueryOp.isSet : QueryOp.isEmpty, null),
      );
    }
    if (hasDives != null) {
      // The list's dive count: dives neither planned nor excluded from
      // stats (DiveStatsScope), from every diver.
      final counted = ScopedNode(
        FieldPath(['dives']),
        AndNode([
          c('planned', QueryOp.eq, const BoolValue(false)),
          c('excludedFromStats', QueryOp.eq, const BoolValue(false)),
        ]),
      );
      parts.add(hasDives! ? counted : NotNode(counted));
    }
    if (siteTypeIds.isNotEmpty) {
      parts.add(c('types', QueryOp.inList, refs(siteTypeIds)));
    }
    if (tagIds.isNotEmpty) parts.add(c('tags', QueryOp.inList, refs(tagIds)));
    if (query != null) parts.add(query!);
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

CompiledQuery compileSiteFilter(
  SiteFilterState filter, {
  String rootAlias = 'r0',
}) => compileQuery(
  filter.toQuery(),
  siteQueryEntity,
  appQueryRegistry,
  rootAlias: rootAlias,
);

/// The tables [filter] reads, for change ticks; never throws (an invalid
/// advanced query falls back to the root table and the SQL path reports
/// the error through its AsyncValue).
Set<String> siteFilterTablesTouched(SiteFilterState filter) {
  final tree = filter.toQuery();
  if (validateQuery(tree, siteQueryEntity, appQueryRegistry).isNotEmpty) {
    return const {'dive_sites'};
  }
  try {
    return compileQuery(tree, siteQueryEntity, appQueryRegistry).tablesTouched;
  } on QueryCompileError {
    return const {'dive_sites'};
  }
}
```

If `site_filter_query.dart` importing `site_providers.dart` closes an import cycle the analyzer or an architecture guard reports, move `SiteFilterState` into `lib/features/dive_sites/domain/models/site_filter_state.dart`, re-export it from `site_providers.dart`, point the census test at the new path, and ledger the move.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_sites/`
Expected: PASS, the census and every equivalence case.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/presentation/providers/site_providers.dart lib/features/dive_sites/query/site_filter_query.dart test/features/dive_sites/query/
git commit -m "feat(query): SiteFilterState lowers to the query tree, proven equal to apply()"
```

### Task 8: The site list filters in SQL; `apply()` goes

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart`
- Delete: `SiteFilterState.apply`, `test/features/dive_sites/query/site_filter_apply_equivalence_test.dart`, `test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart`, `site_filter_state_location_test.dart`
- Test: `test/features/dive_sites/query/site_filter_query_semantics_test.dart` (the equivalence cases, asserted against expected id sets), `test/features/dive_sites/presentation/providers/site_list_query_filter_test.dart`

**Interfaces:**
- Consumes: Task 6 runner, Task 7 lowering.
- Produces: `queryFilteredSiteIdsProvider` (`FutureProvider.autoDispose.family<Set<String>, SiteFilterState>`); `filteredSitesWithCountsProvider` narrowing by it.

- [ ] **Step 1: Move the equivalence cases to a semantics test**

Copy the Task 7 seeding into `site_filter_query_semantics_test.dart`, replace `expectSame` with explicit expected sets computed from the seed (for example `const SiteFilterState(country: 'Bonaire')` selects `{'bon', 'shr'}` among the visible sites), and keep "a trimmed country matches" and "planned and excluded dives do not count". Port any case from the two `site_filter_state_*` test files that the equivalence list does not already cover (their in-memory fixtures become rows). Then delete those two files and the equivalence test.

- [ ] **Step 2: Write the failing provider test**

```dart
// test/features/dive_sites/presentation/providers/site_list_query_filter_test.dart
// setUpTestDatabase(); diver 'me' current; sites 'deep' (max_depth 40) and
// 'shallow' (max_depth 8), both diver 'me'.
test('the filtered list narrows to the compiled id set', () async {
  container.read(siteFilterProvider.notifier).state =
      const SiteFilterState(minDepth: 20);
  final sites = await waitForData(container, filteredSitesWithCountsProvider);
  expect(sites.map((s) => s.site.id), ['deep']);
});

test('an invalid query surfaces as the list error', () async {
  container.read(siteFilterProvider.notifier).state = SiteFilterState(
    query: ConditionNode(FieldPath(['warpFactor']), QueryOp.gt, const NumberValue(9, null)),
  );
  final value = await waitForSettled(container, filteredSitesWithCountsProvider);
  expect(value.hasError, isTrue);
});
```

`waitForData`/`waitForSettled` poll the sync `Provider<AsyncValue<...>>` until it is not loading (see `_pollUntilSettled` in `trip_providers_test.dart`); write them in the file.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/providers/site_list_query_filter_test.dart`
Expected: FAIL to compile (`apply` still used, or the invalid-query case returns data).

- [ ] **Step 4: Implement**

In `site_providers.dart`, add

```dart
/// The ids the site filter selects, from the compiled query (#2365). Keyed
/// on the filter's value, so an equal filter reuses its instance; a write to
/// any table the query read refreshes it in place.
final queryFilteredSiteIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, SiteFilterState>((ref, filter) async {
      final runner = ref.watch(queryIdSetRunnerProvider);
      final compiled = compileSiteFilter(filter);
      ref.invalidateSelfWhen(runner.watchTables(compiled.tablesTouched));
      return runner.ids(compiled);
    });
```

and replace `filteredSitesWithCountsProvider`'s body with

```dart
      final sitesAsync = ref.watch(sitesWithCountsProvider);
      final filter = ref.watch(siteFilterProvider);
      if (!filter.hasActiveFilters) return sitesAsync;
      final idsAsync = ref.watch(queryFilteredSiteIdsProvider(filter));
      // A failed refresh is an error even with a previous set (PR 1); a
      // refresh in flight keeps the previous set.
      if (idsAsync.hasError) {
        return AsyncValue.error(idsAsync.error!, idsAsync.stackTrace!);
      }
      final ids = idsAsync.value;
      if (ids == null) return const AsyncValue.loading();
      return sitesAsync.whenData(
        (sites) => [
          for (final s in sites)
            if (ids.contains(s.site.id)) s,
        ],
      );
```

A `QueryCompileError` thrown inside the family reaches the list as `AsyncValue.error`. Delete `apply()` and its doc comment. Check `test/architecture/provider_tick_build_smoke_test.dart` for a site filter entry and update it if it calls `apply`.

- [ ] **Step 5: Run the site tests**

Run: `flutter test test/features/dive_sites/ test/architecture/`
Expected: PASS, including the widget tests that override `sortedSitesWithCountsProvider`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/providers/site_providers.dart test/features/dive_sites/
git commit -m "feat(sites): the site list filters through the compiled query; SiteFilterState.apply is gone"
```

### Task 9: `EquipmentFilterState` lowers to the query

**Files:**
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart`
- Create: `lib/features/equipment/query/equipment_filter_query.dart`
- Test: `test/features/equipment/query/equipment_filter_query_census_test.dart`, `test/features/equipment/query/equipment_filter_apply_equivalence_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6.
- Produces: `EquipmentFilterState.query`, `copyWith(query:, clearQuery:)`, `==` and `hashCode` including `query`; `extension EquipmentFilterQuery on EquipmentFilterState { QueryNode toQuery(); QueryScope? ownerScope(String? activeDiverId) }`; `CompiledQuery compileEquipmentFilter(EquipmentFilterState)` (root alias `r0`, which `ownerScope` assumes).

- [ ] **Step 1: Census test**

As Task 7 Step 1, reading `lib/features/equipment/domain/models/equipment_filter_state.dart` (class body of `EquipmentFilterState`) against `lib/features/equipment/query/equipment_filter_query.dart`.

- [ ] **Step 2: Equivalence test**

```dart
// test/features/equipment/query/equipment_filter_apply_equivalence_test.dart
// Deleted in Task 10 with apply(). setUpTestDatabase(); divers 'me' and
// 'other'; items:
//   'bcd'   : bcd, active, status active, diver 'me', tag 't1'
//   'suit'  : wetsuit, active, diver 'me', thickness_mm 7 (curated)
//   'old'   : regulator, status retired, is_active 1 (legacy), diver 'me'
//   'gone'  : regulator, status sold, is_active 0, diver 'me'
//   'lent'  : computer, active, diver 'other', shared with 'me'
//   'mine0' : fins, active, diver NULL
// The old pipeline: the provider selection (getActiveEquipment,
// getEquipmentByStatus) then apply() with the tag map and 'me'.
Future<Set<String>> oldPipeline(EquipmentFilterState f) async {
  final repo = EquipmentRepository();
  final base = f.status == null
      ? await repo.getActiveEquipment(diverId: 'me')
      : await repo.getEquipmentByStatus(f.status!, diverId: 'me');
  final tags = await EquipmentTagRepository().getTagIdsByEquipment();
  return {for (final e in f.apply(base, tags, activeDiverId: 'me')) e.id};
}

Future<Set<String>> newPipeline(EquipmentFilterState f) async {
  final visible = {
    for (final e in await EquipmentRepository().getAllEquipment(diverId: 'me')) e.id,
  };
  final ids = await QueryIdSetRunner(db).ids(
    compileEquipmentFilter(f),
    scope: f.ownerScope('me'),
  );
  return ids.intersection(visible);
}

test('the default view hides retired and sold gear', () async {
  expect(await newPipeline(const EquipmentFilterState()),
      await oldPipeline(const EquipmentFilterState()));
  expect(await newPipeline(const EquipmentFilterState()),
      isNot(contains('old')));
});

test('every non-service axis selects what the old pipeline did', () async {
  for (final f in [
    const EquipmentFilterState(status: EquipmentStatus.retired),
    const EquipmentFilterState(status: EquipmentStatus.sold),
    const EquipmentFilterState(type: EquipmentType.wetsuit),
    EquipmentFilterState(
      type: EquipmentType.wetsuit,
      attrConditions: [EquipmentAttrCondition.suitThickness(min: 5)],
    ),
    const EquipmentFilterState(tagIds: {'t1'}),
    const EquipmentFilterState(owner: EquipmentOwnerFilter.mine),
    const EquipmentFilterState(owner: EquipmentOwnerFilter.sharedWithMe),
  ]) {
    expect(await newPipeline(f), await oldPipeline(f), reason: '$f');
  }
});

test('with no active diver the owner axis narrows nothing', () {
  expect(
    const EquipmentFilterState(owner: EquipmentOwnerFilter.mine).ownerScope(null),
    isNull,
  );
});
```

Use the repository method names that exist (`getTagIdsByEquipment` is illustrative: read `equipment_tag_repository.dart` for the batch map method `tagsByEquipmentProvider` calls). The service-due equivalence is already pinned by Task 5.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/equipment/query/`
Expected: FAIL (`compileEquipmentFilter` undefined).

- [ ] **Step 4: State changes**

In `EquipmentFilterState`: add `final QueryNode? query;` and constructor parameter; `hasActiveFilters` also true when `query != null`; `copyWith` gains `QueryNode? query, bool clearQuery = false` (a type change still drops `attrConditions` and keeps `query`); `==`, `hashCode` and `toString` include `query`.

- [ ] **Step 5: Write the lowering**

```dart
// lib/features/equipment/query/equipment_filter_query.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// Lowers the equipment filter panel to the query tree (#2365). The ONLY
/// evaluator of an EquipmentFilterState: a field added to it and not named
/// here fails `equipment_filter_query_census_test`.
extension EquipmentFilterQuery on EquipmentFilterState {
  /// Never null: the status axis always narrows (the default view hides
  /// retired and sold gear, #636).
  QueryNode toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    EnumValue e(String name) => EnumValue(name);
    final s = status;
    if (s == null) {
      // getActiveEquipment: legacy rows can be retired with is_active still
      // set, and sold gear has left the kit.
      parts
        ..add(c('active', QueryOp.eq, const BoolValue(true)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.retired.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)));
    } else if (s == EquipmentStatus.retired) {
      // getEquipmentByStatus(retired): legacy rows that only flipped
      // is_active, but not sold gear.
      parts
        ..add(
          OrNode([
            c('status', QueryOp.eq, e(EquipmentStatus.retired.name)),
            c('active', QueryOp.eq, const BoolValue(false)),
          ]),
        )
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)));
    } else {
      parts.add(c('status', QueryOp.eq, e(s.name)));
    }
    final due = serviceDue;
    if (due != null) {
      parts.add(switch (due) {
        ServiceDueFilter.any => c(
          'serviceDue',
          QueryOp.inList,
          ListValue([e('dueSoon'), e('overdue')]),
        ),
        ServiceDueFilter.overdue => c('serviceDue', QueryOp.eq, e('overdue')),
        ServiceDueFilter.dueSoon => c('serviceDue', QueryOp.eq, e('dueSoon')),
      });
    }
    if (type != null) parts.add(c('type', QueryOp.eq, e(type!.name)));
    for (final cond in attrConditions) {
      parts.add(equipmentAttrConditionNode(cond));
    }
    if (tagIds.isNotEmpty) {
      parts.add(
        c(
          'tags',
          QueryOp.inList,
          ListValue([
            for (final id in tagIds.toList()..sort()) RefValue(id, id),
          ]),
        ),
      );
    }
    if (query != null) parts.add(query!);
    return parts.length == 1 ? parts.first : AndNode(parts);
  }

  /// The owner axis (issue #2046) as a caller-applied scope over `r0`. It
  /// compares rows with the active diver, which a saved query must not
  /// name, so it is not a query field. Null narrows nothing, as apply()
  /// did with no active diver.
  QueryScope? ownerScope(String? activeDiverId) {
    if (activeDiverId == null) return null;
    return switch (owner) {
      EquipmentOwnerFilter.all => null,
      EquipmentOwnerFilter.mine => (
        sql: '(r0.diver_id IS NULL OR r0.diver_id = ?)',
        params: [activeDiverId],
      ),
      EquipmentOwnerFilter.sharedWithMe => (
        sql: '(r0.diver_id IS NOT NULL AND r0.diver_id != ?)',
        params: [activeDiverId],
      ),
    };
  }
}

CompiledQuery compileEquipmentFilter(EquipmentFilterState filter) =>
    compileQuery(filter.toQuery(), equipmentQueryEntity, appQueryRegistry);
```

The census test must find `serviceDue`, `owner` and `query` in this file; it does.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/domain/models/equipment_filter_state.dart lib/features/equipment/query/equipment_filter_query.dart test/features/equipment/query/
git commit -m "feat(query): EquipmentFilterState lowers to the query tree, owner as a caller scope"
```

### Task 10: The equipment list filters in SQL; `apply()` goes

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_query_providers.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`, `equipment_filter_state.dart` (delete `apply`, `tagsEmptied`), `equipment_providers.dart`
- Delete: `test/features/equipment/query/equipment_filter_apply_equivalence_test.dart`; convert the `apply()` cases in `equipment_filter_state_test.dart`, `equipment_filter_state_tags_test.dart` and `equipment_filter_state_owner_test.dart` into `test/features/equipment/query/equipment_filter_query_semantics_test.dart` over rows (keep their `copyWith`/`hasActiveFilters` cases where they are).
- Test: `test/features/equipment/presentation/providers/equipment_query_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 6, 9.
- Produces: `queryFilteredEquipmentIdsProvider` (`FutureProvider.autoDispose.family<Set<String>, ({EquipmentFilterState filter, String? diverId})>`), `filteredEquipmentProvider` (`Provider<AsyncValue<List<EquipmentItem>>>`), `equipmentTagsEmptiedProvider` (`Provider<bool>`).

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/equipment/presentation/providers/equipment_query_providers_test.dart
// A container over the test DB, diver 'me' current. Items: 'bcd' (bcd,
// tag 't1'), 'reg' (regulator), 'old' (retired).
test('the filtered list is the visible gear the query selects', () async {
  container.read(equipmentFilterProvider.notifier).state =
      const EquipmentFilterState(type: EquipmentType.bcd);
  final items = await waitForData(container, filteredEquipmentProvider);
  expect(items.map((e) => e.id), ['bcd']);
});

test('a service-due filter reads a cache the engine has just written', () async {
  // 'reg' has an overdue schedule (Task 5 seeding helper).
  container.read(equipmentFilterProvider.notifier).state =
      const EquipmentFilterState(serviceDue: ServiceDueFilter.overdue);
  final items = await waitForData(container, filteredEquipmentProvider);
  expect(items.map((e) => e.id), ['reg']);
});

test('tagsEmptied blames the tags only when they emptied the list', () async {
  container.read(equipmentFilterProvider.notifier).state =
      const EquipmentFilterState(type: EquipmentType.regulator, tagIds: {'t1'});
  await waitForData(container, filteredEquipmentProvider);
  expect(container.read(equipmentTagsEmptiedProvider), isTrue);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/equipment/presentation/providers/equipment_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

/// The ids the equipment filter selects (#2365). A query naming
/// `serviceDue` waits for the service cache to mirror the engine first.
final queryFilteredEquipmentIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, ({EquipmentFilterState filter, String? diverId})>((
      ref,
      key,
    ) async {
      final runner = ref.watch(queryIdSetRunnerProvider);
      final compiled = compileEquipmentFilter(key.filter);
      if (compiled.tablesTouched.contains('equipment_service_status')) {
        await ref.watch(equipmentServiceStatusCacheProvider.future);
      }
      ref.invalidateSelfWhen(runner.watchTables(compiled.tablesTouched));
      return runner.ids(compiled, scope: key.filter.ownerScope(key.diverId));
    });

AsyncValue<List<EquipmentItem>> _narrow(
  AsyncValue<List<EquipmentItem>> items,
  AsyncValue<Set<String>> ids,
) {
  if (ids.hasError) return AsyncValue.error(ids.error!, ids.stackTrace!);
  final set = ids.value;
  if (set == null) return const AsyncValue.loading();
  return items.whenData(
    (all) => [
      for (final e in all)
        if (set.contains(e.id)) e,
    ],
  );
}

/// The equipment list: every visible item (in `getAllEquipment` order,
/// type then name) narrowed to the compiled query's ids. Replaces the
/// active / by-status / service-due provider switch and apply().
final filteredEquipmentProvider = Provider<AsyncValue<List<EquipmentItem>>>((
  ref,
) {
  final filter = ref.watch(effectiveEquipmentFilterProvider);
  final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
  return _narrow(
    ref.watch(allEquipmentProvider),
    ref.watch(
      queryFilteredEquipmentIdsProvider((filter: filter, diverId: diverId)),
    ),
  );
});

/// Whether the tag selection is what emptied the list (issue #1942): the
/// filter selects nothing, but the same filter without its tags selects
/// something.
final equipmentTagsEmptiedProvider = Provider<bool>((ref) {
  final filter = ref.watch(effectiveEquipmentFilterProvider);
  if (filter.tagIds.isEmpty) return false;
  final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
  final withTags = ref.watch(filteredEquipmentProvider).value;
  if (withTags == null || withTags.isNotEmpty) return false;
  final without = _narrow(
    ref.watch(allEquipmentProvider),
    ref.watch(
      queryFilteredEquipmentIdsProvider((
        filter: filter.copyWith(clearTagIds: true),
        diverId: diverId,
      )),
    ),
  ).value;
  return without != null && without.isNotEmpty;
});
```

Confirm `allEquipmentProvider`'s repository query orders by type then name like `getActiveEquipment`; if not, order it so (the page sort re-sorts anyway, but grouping assumes the same base order).

- [ ] **Step 4: Rewire the list**

In `equipment_list_content.dart`:
1. Replace the three-way `equipmentAsync` selection with `final equipmentAsync = ref.watch(filteredEquipmentProvider);`.
2. Replace `filter.tagsEmptied(...)` with `ref.watch(equipmentTagsEmptiedProvider)`.
3. Replace both `filter.apply(...)` calls with the list itself (`equipment` / `equipmentAsync.value ?? const []`).
4. `hadItemsBeforeTypeFilter` becomes `(ref.watch(allEquipmentProvider).value ?? const []).isNotEmpty`.
5. `_invalidateCurrentProvider` invalidates `allEquipmentProvider`, plus `activeEquipmentClocksProvider` when `filter.serviceDue != null`.
6. Remove the now-unused `tagIdsByEquipment` map if nothing else reads it (the detailed tiles' chips still read `tagsByEquipment`).

Delete `EquipmentFilterState.apply` and `tagsEmptied`. Keep `serviceDueEquipmentProvider` and `matchesServiceDue` only if something other than the list still reads them (grep `lib/`); otherwise delete them and their `service_due_severity_test.dart`, and say so in the commit body.

Update `equipment_list_content_test.dart` and the other widget tests that override `activeEquipmentProvider` / `equipmentByStatusProvider`: they now override `filteredEquipmentProvider` (and `allEquipmentProvider` for the empty-state wording).

- [ ] **Step 5: Run the equipment tests**

Run: `flutter test test/features/equipment/ test/architecture/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/ test/features/equipment/
git commit -m "feat(equipment): the gear list filters through the compiled query; EquipmentFilterState.apply is gone"
```

### Task 11: Trips: `TripFilterState` lowers to the query and the list filters in SQL

**Files:**
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`
- Create: `lib/features/trips/query/trip_filter_query.dart`
- Test: `test/features/trips/query/trip_filter_query_census_test.dart`, `test/features/trips/query/trip_filter_query_semantics_test.dart`; update `test/features/trips/presentation/providers/trip_providers_test.dart` (equipment branch group) and `test/architecture/provider_tick_build_smoke_test.dart` (`_readFilteredTrips`)

**Interfaces:**
- Produces: `TripFilterState.query`, `copyWith(query:, clearQuery:)`, `==`/`hashCode`; `extension TripFilterQuery on TripFilterState { QueryNode? toQuery() }`; `compileTripFilter`; `queryFilteredTripIdsProvider` (`FutureProvider.autoDispose.family<Set<String>, TripFilterState>`).

- [ ] **Step 1: Census and semantics tests**

Census as Task 7 Step 1 over `class TripFilterState` in `trip_providers.dart` and `trip_filter_query.dart`.

```dart
// test/features/trips/query/trip_filter_query_semantics_test.dart
// setUpTestDatabase(); trips 'a', 'b', 'c'; equipment 'reg', 'tank';
// dive d1 (trip 'a') with dive_equipment (d1, 'reg');
// dive d2 (trip 'b') with dive_tanks (d2, equipment_id 'tank').
test('equipment selects the trips whose dives used it', () async {
  Future<Set<String>> ids(String id) => QueryIdSetRunner(db)
      .ids(compileTripFilter(TripFilterState(equipmentId: id)));
  expect(await ids('reg'), {'a'});
  // Ruling: the dive gear union counts a transmitter-matched cylinder,
  // which getTripIdsForEquipment (dive_equipment only) missed.
  expect(await ids('tank'), {'b'});
  expect(
    (await EquipmentRepository().getTripIdsForEquipment('reg')).toSet(),
    {'a'},
  );
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/query/`
Expected: FAIL (`trip_filter_query.dart` missing).

- [ ] **Step 3: State, lowering and provider**

`TripFilterState`: add `final QueryNode? query;`, constructor parameter, `hasActiveFilters => equipmentId != null || query != null`, `copyWith(..., QueryNode? query, bool clearQuery = false)`, `==`/`hashCode`.

```dart
// lib/features/trips/query/trip_filter_query.dart
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Lowers the trip filter to the query tree (#2365). The ONLY evaluator of
/// a TripFilterState: a field added to it and not named here fails
/// `trip_filter_query_census_test`.
extension TripFilterQuery on TripFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[
      // Trips whose dives used the item: the dive gear union, which also
      // counts a transmitter-matched cylinder.
      if (equipmentId != null)
        ScopedNode(
          FieldPath(['dives']),
          ConditionNode(
            FieldPath(['gear']),
            QueryOp.eq,
            RefValue(equipmentId!, equipmentId!),
          ),
        ),
      ?query,
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

CompiledQuery compileTripFilter(TripFilterState filter) =>
    compileQuery(filter.toQuery(), tripQueryEntity, appQueryRegistry);
```

(`?query` is Dart's null-aware element; if the analyzer's language version refuses it, write `if (query != null) query!`.)

In `trip_providers.dart`: add

```dart
final queryFilteredTripIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, TripFilterState>((ref, filter) async {
      final runner = ref.watch(queryIdSetRunnerProvider);
      final compiled = compileTripFilter(filter);
      ref.invalidateSelfWhen(runner.watchTables(compiled.tablesTouched));
      return runner.ids(compiled);
    });
```

delete `_equipmentFilteredTripsProvider` and the direct `EquipmentRepository` import, and replace the equipment branch in `filteredTripsProvider` with the id-set narrowing of Task 8 Step 4 over `trips` (`t.trip.id`). If `getTripIdsForEquipment` has no caller left in `lib/`, delete it and move the semantics test's last assertion to a one-off check you then remove; ledger it.

- [ ] **Step 4: Run the trip tests**

Run: `flutter test test/features/trips/ test/architecture/`
Expected: PASS after updating the equipment-branch group in `trip_providers_test.dart` to seed dive links rather than a mocked repository call.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/ test/features/trips/ test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(trips): the trip list filters through the compiled query"
```

### Task 12: One editor, chip helper and save flow for every entity

**Files:**
- Modify: `lib/features/query/presentation/dive_query_editor.dart`, `lib/features/query/presentation/dive_query_chips.dart`, `lib/features/dive_log/presentation/pages/dive_search_page.dart`
- Create: `lib/features/query/presentation/widgets/save_query_flow.dart`
- Test: `test/features/query/presentation/entity_query_editor_test.dart`, `test/features/query/presentation/widgets/save_query_flow_test.dart`; the existing `dive_search_page_query_test.dart` and dive editor tests stay green unchanged

**Interfaces:**
- Produces: `EntityQueryEditor({required QueryEntity root, required QueryNode? value, required ValueChanged<QueryNode?> onChanged, VoidCallback? onSave})`; `DiveQueryEditor` delegating to it; `List<String> entityQueryChipLabels(QueryEntity root, QueryNode? query, UnitPrefs prefs)`; `Future<void> saveQueryFromEditor(BuildContext context, WidgetRef ref, {required QuerySubject subject, required QueryNode node})`.

- [ ] **Step 1: Failing tests**

```dart
// entity_query_editor_test.dart: pump EntityQueryEditor(root:
// siteQueryEntity) in the app harness the dive editor test uses; type
// `difficulty = advanced`; expect onChanged to receive the ConditionNode;
// type `depth > 30` (a dive field) and expect the unknown-field error text.

// save_query_flow_test.dart: with diver 'me' current, call
// saveQueryFromEditor(subject: QuerySubject.sites, node: ...), enter a
// name in the dialog, and expect a saved_queries row with subject 'sites'.
```

Write both in full, copying the harness from `test/features/query/presentation/dive_query_editor_test.dart` (or the closest existing test of `DiveQueryEditor`) and `dive_search_page_query_test.dart`.

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL to compile.

- [ ] **Step 3: Implement**

1. In `dive_query_editor.dart`, rename the widget's body into `EntityQueryEditor` with a `required QueryEntity root` field used for `QueryEditorContext.root`, and make `DiveQueryEditor` a `StatelessWidget` that returns `EntityQueryEditor(root: diveQueryEntity, value: value, onChanged: onChanged, onSave: onSave)`.
2. In `dive_query_chips.dart` add `entityQueryChipLabels(root, query, prefs)` (the current body with `root` in place of `diveQueryEntity`) and make `diveQueryChipLabels` call it.
3. Move the body of `_DiveSearchPageState._saveQuery` (the diver check, `showSaveQueryDialog`, `savedQueryRepositoryProvider.create`, the snackbars and the logged catch) into `saveQueryFromEditor`, with `subject` in place of `QuerySubject.dives` and `LoggerService.forClass(SavedQueryRepository)` for the log; `_saveQuery` becomes `if (node != null) await saveQueryFromEditor(context, ref, subject: QuerySubject.dives, node: node);`. It must keep checking `mounted`/`context.mounted` after each await.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/query/ test/features/dive_log/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/query/presentation/ lib/features/dive_log/presentation/pages/dive_search_page.dart test/features/query/presentation/
git commit -m "refactor(query): one editor, chip labeller and save flow for any entity"
```

### Task 13: The site filter sheet hosts the query editor and Saved row

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart`, ARB files
- Test: `test/features/dive_sites/presentation/widgets/site_filter_sheet_query_test.dart`; extend `site_list_content_test.dart`

**Interfaces:**
- Consumes: Task 12.
- Produces: the sheet's "Query" section; the site list's query chips.

- [ ] **Step 1: Failing widget tests**

```dart
// site_filter_sheet_query_test.dart
testWidgets('a typed query is applied with the other axes', ...);
//   open the sheet, enter `difficulty = advanced` in the query field,
//   tap Apply, expect siteFilterProvider.state.query to print as
//   'difficulty = advanced' and the country axis untouched.
testWidgets('a saved site query applies on tap', ...);
//   seed a saved_queries row (subject 'sites'), open the sheet, tap its
//   chip, Apply, expect state.query == the saved tree.
testWidgets('Clear all clears the query', ...);

// site_list_content_test.dart
testWidgets('each top-level query condition is a chip that removes itself', ...);
//   override siteFilterProvider with a query `rating >= 3 AND
//   difficulty = advanced`; expect two chips; delete the first; expect the
//   state's query to print as 'difficulty = advanced'.
```

Write them in full with the sheet harness in `site_filter_sheet_test.dart`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_filter_sheet_query_test.dart`
Expected: FAIL (no query field in the sheet).

- [ ] **Step 3: Implement the sheet section**

In `_SiteFilterSheetState`: add `QueryNode? _query;` seeded from `filter.query` in the same place the other locals are seeded; reset it in `_clearAll`; pass `query: _query` in `_applyFilters`. Add a first section, titled with the new ARB key `query_sheet_sectionTitle` ("Query"), containing:

```dart
SavedQueryChipRow(
  subject: QuerySubject.sites,
  onApply: (load) => setState(() => _query = load.node),
),
const SizedBox(height: 8),
EntityQueryEditor(
  root: siteQueryEntity,
  value: _query,
  onChanged: (node) => setState(() => _query = node),
  onSave: _query == null
      ? null
      : () => saveQueryFromEditor(
          context,
          widget.ref,
          subject: QuerySubject.sites,
          node: _query!,
        ),
),
```

ARB (all locales): `query_sheet_sectionTitle` "Query". `flutter gen-l10n`, label lookup script.

- [ ] **Step 4: Chips on the list**

In `site_list_content.dart` `_buildActiveFiltersBar`, after the tag chips add one `InputChip` per `entityQueryChipLabels(siteQueryEntity, filter.query, ref.watch(queryUnitPrefsProvider))` entry; `onDeleted` sets the filter to `copyWith(query: next)` or `copyWith(clearQuery: true)` where `next = removeTopLevelConjunct(filter.query, i)`.

- [ ] **Step 5: Run the site tests**

Run: `flutter test test/features/dive_sites/ test/l10n/ test/architecture/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/ lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb/ test/features/dive_sites/presentation/widgets/
git commit -m "feat(sites): the site filter sheet takes a typed or built query and saved queries"
```

### Task 14: The equipment filter sheet hosts the query editor and Saved row

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`, `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_filter_sheet_query_test.dart`; extend `equipment_list_content_test.dart`

**Interfaces:**
- Consumes: Task 12, `query_sheet_sectionTitle` from Task 13.

- [ ] **Step 1: Failing widget tests**

The same three sheet tests and the chip test as Task 13, against `EquipmentFilterSheet`, `QuerySubject.equipment` and `equipmentFilterProvider`, with the query `type = bcd` (sheet) and `type = bcd AND serviceDue = overdue` (chips). Write them in full with the harness in `equipment_filter_sheet_test.dart`.

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL (no query field in the sheet).

- [ ] **Step 3: Implement**

The sheet edits a local draft `EquipmentFilterState`: add the same section as Task 13 Step 3 with `subject: QuerySubject.equipment`, `root: equipmentQueryEntity`, `value: _draft.query`, and `onChanged: (node) => setState(() => _draft = node == null ? _draft.copyWith(clearQuery: true) : _draft.copyWith(query: node))`; Clear All resets the query with the rest. Add the query chips to `_buildActiveFiltersBar` in `equipment_list_content.dart` exactly as Task 13 Step 4, over `equipmentFilterProvider`.

- [ ] **Step 4: Run the equipment tests**

Run: `flutter test test/features/equipment/ test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/widgets/ test/features/equipment/presentation/widgets/
git commit -m "feat(equipment): the gear filter sheet takes a typed or built query and saved queries"
```

### Task 15: Spec record, full verification, screenshots and the PR

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-entity-query-language-design.md`

- [ ] **Step 1: Record the deviations**

Add a section "## Deviations recorded during implementation (PR 3)" after the PR 2 section, one bullet per item in this plan's "Decisions settled for this plan", plus any ledgered ruling from the tasks (worded as facts, no em-dashes).

- [ ] **Step 2: Full verification**

1. `git fetch origin main` and merge it (never rebase); resolve; run `flutter analyze --fatal-infos` and `flutter test test/architecture/ test/l10n/`.
2. Re-scan the schema ladder (open PR diffs and every worktree scalar). If 242 was taken, renumber the rung, its test, the ARB-free comments and the spec note.
3. Run the whole suite once: `flutter test --exclude-tags performance` (log to a file in `.dart_tool/` read with the Read tool, never piped). Every failure is either fixed or shown to pass alone and named in the PR.

- [ ] **Step 3: Screenshots**

Capture, with the throwaway-golden method (`matchesGoldenFile` plus `--update-goldens`, font loaded in `setUpAll`, then delete the test), the site and equipment filter sheets with a query and a Saved chip, and a site and an equipment list with query chips, each in light and dark at phone and desktop widths. Hand the image files to Eric; `gh` cannot upload them.

- [ ] **Step 4: Commit, push, open the PR**

```bash
git add docs/superpowers/specs/2026-09-25-entity-query-language-design.md
git commit -m "docs(query): record the PR 3 deviations"
git push -u origin HEAD
gh pr create --title "feat(query): entity query language, PR 3: sites, equipment and trips on the query engine" --body-file <body file>
gh pr edit <n> --add-reviewer "@copilot"
```

The body: summary of what moved to SQL, the service-due cache, the owner scope, the trips engine-only scope, `Refs #2365`, the Screenshots section listing the captured images, and the test plan. No attribution lines.
