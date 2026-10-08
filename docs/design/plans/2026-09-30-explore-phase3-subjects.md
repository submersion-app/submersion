# Explore Phase 3: Other Subjects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an Explore sentence ask about sites, equipment, buddies, species, trips and dive centers, not only dives, with the same visible chips, ranked results, one count chart and a handoff to that subject's own list.

**Architecture:** Explore compiles a sentence to one query rooted at the subject's registry entity (#2365). The subject's own words lower onto its own fields; every other word (a dive field, a mention of another kind, a time phrase) lowers into a *dive scope* that the subject reaches through its `dives` relation. Dive counts, last-dived dates and the service due date become named derived fields in the shared registries, so the typed query language gains them too. Results reuse each list's own id-set provider and row tile, ranked by how many dives in the scope each row has.

**Tech Stack:** Flutter, Dart, Riverpod, Drift/SQLite, the entity query language under `lib/core/query/` and `lib/features/query/`.

**Spec:** `docs/design/specs/2026-09-19-explore-natural-language-search-design.md` (Phase 3 section). This plan deviates from the spec's phase 3 table on purpose; Task 9 records each deviation in the spec. The 2026-09-21 phase 3 plan (commit `098bb3f22be` on `ericgriffin/explore-phase2-derived-predicates`) is superseded: it predates the shared registries.

## Global Constraints

- Program issue #2195; this PR says `Closes #2195`.
- No new `DiveFilterState` axis. Everything is a registry field or a query node.
- Schema: `kQuerySchemaVersion` goes to 3; `kMinReadableQuerySchemaVersion` stays 1, so every stored recent query keeps parsing.
- The prompt stays under 7,000 characters (`test/features/explore/domain/nl_prompt_test.dart`). Measure after Task 8; if it passes 6,500, shorten the new lines, never raise the budget.
- A registry field's SQL takes no `?` bind (`query_registry_guards_test.dart`), declares every table it reads in `tables`, and has a label key present in all 11 ARB files.
- Dive counts and last-dived dates count only dives inside `DiveStatsScope` (not planned, not excluded from stats), as the site list's own dive count does (`site_filter_query.dart`, `hasDives`). Registry fields count every diver's dives (the site list's precedent); Explore's ranking counts the active diver's.
- Explore results reuse each list's own id-set provider (sites, trips, equipment keep shared and unowned rows that way), never `entityQueryIdsProvider` for those three.
- ARB edits: insert keys as text, never a JSON round trip; only `app_en.arb` is alphabetical, the other ten are grouped by feature, so anchor each insert on a neighbouring key present in all 11; translate into all ten other locales; run `flutter gen-l10n` last; generated methods take placeholders in alphabetical order. After adding any `query_*` key, run `python3.14 scripts/gen_query_label_lookup.py`.
- Explore strings: no em-dash, no " - " (`test/l10n/explore_strings_test.dart`). German says AMV, never SAC.
- A provider that reads a table carries a change tick or a `// no-tick:` marker (`test/architecture/provider_change_tick_test.dart`).
- Tests restore any process-wide state they change (`test/architecture/test_global_state_restored_test.dart`).
- Paths in tests are built with `p.join`, temporary space through `Directory.systemTemp`.
- Run `dart format .` before every commit. Commit messages carry no attribution lines.
- The trip list gains visible UI (query chips, a filter button): the PR shows before and after screenshots, phone and desktop widths.

## Decisions (from the planning conversation, 2026-09-30)

1. Aggregates are named derived fields in the shared registries: `diveCount` and `lastDived` on sites, equipment, buddies and centers; `diveCount` on trips; `diveCount`, `firstSeen` and `lastSeen` on species; `nextServiceDue` on equipment.
2. A mention of another kind, a dive field, or a time phrase under a non-dive subject lowers through the subject's dives ("sites where I saw turtles" is sites with a counted dive that has a turtle sighting). Under trips a time phrase is the trip's own dates overlapping the period.
3. Non-dive results are ordered by the number of dives in the scope each row has, then by name. The one chart for a non-dive subject is that count per row. No sort in the schema.
4. One PR for the whole phase.
5. "Due for service in N days" is a date bound the compiler computes (`nextServiceDue <= today + N`), since `equipment_service_status.due_date` stores the next due instant; no diver-chosen N reaches SQL.

Decisions this plan makes that the review should confirm:

- **A count with a dive scope is unplaced.** "Buddies I dived with more than 10 times this year" cannot say "10 dives this year" as a query node (count conditions over a scoped relation are out of the query language's scope), and the registry `diveCount` counts all time. The count words go to the Needs attention row with the reason "can't count within a period yet" rather than silently counting all time. The ranking still orders by the in-period count.
- **An own-kind mention matches by name.** Under buddies, "Ana" is `name in ["Ana"]` (the stored name), since no registry entity has an id field. Two rows with one name both match.
- **Own words win a name clash.** Under sites, `depth` is the site's `maxDepth` and `rating` is the site's rating; under buddies, `favorite` is the buddy's flag. A dive's depth under sites is reachable only through a dive mention or time, not by that word.
- **Species counts are global.** The species registry entity has no diver column, so `diveCount`, `firstSeen` and `lastSeen` on species count every diver's sightings. The seen-species list and Explore's ranking are per diver; they agree for a library with one diver.

## Review Focus

1. A subject with no conditions ("show me my buddies") compiles to a null query: the results are every row, ranked, and no handoff button shows. Tested in Task 5 and Task 6.
2. Shared sites, shared trips and shared or unowned equipment appear in Explore's results exactly as their lists show them. Tested in Task 5 through the lists' own id-set providers.
3. An imperial diver's "sites deeper than 100 ft" grounds 100 ft to metres on the site's `maxDepth`. Tested in Task 2.
4. A dive field under a non-dive subject ("buddies I dived with below 40 m") lowers into the dive scope, and its chip says it is about the dives. Tested in Task 3 and Task 6.
5. A never-dived row has a `diveCount` of 0, not an unrecorded one: `diveCount <= 2` includes it, while `diveCount >= 1` and `lastDived before 2022` exclude it. Tested in Task 1.

---

## File Structure

Create:
- `lib/features/dive_log/query/dive_aggregate_fields.dart`: the shared builders for `diveCount`, `lastDived`, `firstSeen`, `lastSeen` over a subject's dives.
- `lib/features/explore/domain/explore_subject_fields.dart`: each subject's Explore fields, the subject to registry root map, `exploreFieldFor`.
- `lib/features/explore/domain/explore_subject_lowering.dart`: own-kind mentions, trip dates, the counted-dives scope.
- `lib/features/explore/presentation/providers/explore_subject_providers.dart`: the subject's ranked rows and dive counts.
- `lib/features/explore/presentation/widgets/explore_subject_results_list.dart`: rows through each list's tile.
- `lib/features/explore/presentation/widgets/explore_handoff_bar.dart`: the handoff buttons per subject.
- Tests beside each (paths in the tasks).

Modify:
- The six entity files: `site_query_entity.dart`, `equipment_query_entity.dart`, `buddy_query_entity.dart`, `trip_query_entity.dart`, `dive_center_query_entity.dart`, `species_query_entity.dart`.
- `lib/features/explore/domain/`: `explore_fields.dart`, `explore_clause_lowering.dart`, `explore_compiler.dart`, `explore_compilation.dart`, `chart_selection.dart`, `nl_engine.dart`, `query_model.dart`.
- `lib/features/explore/data/explore_repository.dart`.
- `lib/features/explore/presentation/`: `providers/explore_providers.dart`, `pages/explore_page.dart`, `widgets/explore_chip_rows.dart`, `widgets/explore_results_list.dart`, `widgets/explore_charts.dart`, `chip_labeler.dart`.
- `lib/features/trips/presentation/widgets/trip_list_content.dart`, `lib/features/trips/presentation/pages/trip_list_page.dart`.
- The 11 ARB files, the generated l10n, `lib/features/query/presentation/query_label_lookup.dart` (regenerated).
- The spec (Task 9).

---

## Tasks

### Task 1: Dive aggregate fields in the shared registries

**Files:**
- Create: `lib/features/dive_log/query/dive_aggregate_fields.dart`
- Modify: `lib/features/dive_sites/query/site_query_entity.dart`, `lib/features/equipment/query/equipment_query_entity.dart`, `lib/features/buddies/query/buddy_query_entity.dart`, `lib/features/trips/query/trip_query_entity.dart`, `lib/features/dive_centers/query/dive_center_query_entity.dart`, `lib/features/marine_life/query/species_query_entity.dart`
- Modify: the 11 ARB files, `lib/features/query/presentation/query_label_lookup.dart` (regenerated)
- Test: `test/features/query/dive_aggregate_fields_test.dart`

**Interfaces:**
- Produces: registry field keys `diveCount` (number, `FieldDimension.count`), `lastDived` (date, wall clock UTC), species `firstSeen` and `lastSeen` (date), equipment `nextServiceDue` (date, `DateFrame.localInstant`). Label keys `query_<subject>_<key>` for each.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

import '../../helpers/test_database.dart';

/// The derived fields every non-dive subject gains (Explore phase 3): a
/// count and a last-dived date over the subject's dives, inside the stats
/// scope, as the site list's own dive count is.
void main() {
  late AppDatabase db;
  final day = DateTime.utc(2024, 6, 1).millisecondsSinceEpoch;
  const dayMs = 24 * 60 * 60 * 1000;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(QueryEntity root, QueryNode node) =>
      QueryIdSetRunner(db).ids(compileQuery(node, root, appQueryRegistry));

  ConditionNode c(String key, QueryOp op, [Object? v]) => ConditionNode(
    FieldPath([key]),
    op,
    switch (v) {
      final num n => NumberValue(n.toDouble(), null),
      final DateTime d => DateValue(d),
      _ => null,
    },
  );

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(day),
          updatedAt: Value(day),
        ),
      );

  Future<void> dive(
    String id, {
    String? siteId,
    String? centerId,
    String? tripId,
    int at = 0,
    bool planned = false,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(day + at * dayMs),
          createdAt: Value(day),
          updatedAt: Value(day),
          siteId: Value(siteId),
          diveCenterId: Value(centerId),
          tripId: Value(tripId),
          isPlanned: Value(planned),
          excludedFromStats: Value(excluded),
        ),
      );

  group('sites', () {
    setUp(() async {
      await site('busy');
      await site('once');
      await site('never');
      await dive('a', siteId: 'busy', at: 0);
      await dive('b', siteId: 'busy', at: 10);
      await dive('c', siteId: 'busy', at: 20);
      await dive('d', siteId: 'once', at: 5);
      // Neither counts: planned, and excluded from statistics.
      await dive('p', siteId: 'never', planned: true);
      await dive('x', siteId: 'never', excluded: true);
    });

    test('diveCount counts only dives in the stats scope', () async {
      expect(
        await ids(siteQueryEntity, c('diveCount', QueryOp.gte, 2)),
        {'busy'},
      );
      expect(
        await ids(siteQueryEntity, c('diveCount', QueryOp.eq, 1)),
        {'once'},
      );
    });

    test('a site with no counted dive has a count of 0, not none', () async {
      expect(
        await ids(siteQueryEntity, c('diveCount', QueryOp.lte, 1)),
        {'once', 'never'},
      );
      expect(
        await ids(siteQueryEntity, c('diveCount', QueryOp.isEmpty)),
        {'never'},
      );
    });

    test('lastDived is the newest counted dive', () async {
      expect(
        await ids(
          siteQueryEntity,
          c('lastDived', QueryOp.gt, DateTime.utc(2024, 6, 15)),
        ),
        {'busy'},
      );
      // Never dived: no date, so no bound matches it.
      expect(
        await ids(
          siteQueryEntity,
          c('lastDived', QueryOp.lt, DateTime.utc(2030)),
        ),
        {'busy', 'once'},
      );
    });
  });

  test('centers and trips count their dives', () async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion(
            id: const Value('c1'),
            name: const Value('Shop'),
            createdAt: Value(day),
            updatedAt: Value(day),
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Trip',
            startDate: day,
            endDate: day,
            createdAt: day,
            updatedAt: day,
          ),
        );
    await dive('a', centerId: 'c1', tripId: 't1');
    await dive('b', centerId: 'c1', tripId: 't1');
    expect(
      await ids(diveCenterQueryEntity, c('diveCount', QueryOp.gte, 2)),
      {'c1'},
    );
    expect(
      await ids(tripQueryEntity, c('diveCount', QueryOp.gte, 2)),
      {'t1'},
    );
  });

  test('a buddy counts the dives they are on', () async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value('ana'),
            name: const Value('Ana'),
            createdAt: Value(day),
            updatedAt: Value(day),
          ),
        );
    await dive('a');
    await dive('b', at: 3);
    for (final d in ['a', 'b']) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('j-$d'),
              diveId: Value(d),
              buddyId: const Value('ana'),
              createdAt: Value(day),
            ),
          );
    }
    expect(
      await ids(buddyQueryEntity, c('diveCount', QueryOp.eq, 2)),
      {'ana'},
    );
    expect(
      await ids(
        buddyQueryEntity,
        c('lastDived', QueryOp.gte, DateTime.utc(2024, 6, 4)),
      ),
      {'ana'},
    );
  });

  test('gear counts dives through the item and through a cylinder', () async {
    for (final id in ['reg', 'cyl']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: day,
              updatedAt: day,
            ),
          );
    }
    await dive('a');
    await db
        .into(db.diveEquipment)
        .insert(DiveEquipmentCompanion.insert(diveId: 'a', equipmentId: 'reg'));
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't',
            diveId: 'a',
          ).copyWith(equipmentId: const Value('cyl')),
        );
    expect(
      await ids(equipmentQueryEntity, c('diveCount', QueryOp.eq, 1)),
      {'reg', 'cyl'},
    );
  });

  test('species count dives with a sighting, first and last seen', () async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'turtle',
            commonName: 'Turtle',
            category: 'reptile',
          ),
        );
    await dive('a', at: 0);
    await dive('b', at: 30);
    for (final d in ['a', 'b']) {
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 's-$d',
              diveId: d,
              speciesId: 'turtle',
            ),
          );
    }
    expect(
      await ids(speciesQueryEntity, c('diveCount', QueryOp.eq, 2)),
      {'turtle'},
    );
    expect(
      await ids(
        speciesQueryEntity,
        c('firstSeen', QueryOp.lte, DateTime.utc(2024, 6, 1)),
      ),
      {'turtle'},
    );
    expect(
      await ids(
        speciesQueryEntity,
        c('lastSeen', QueryOp.gte, DateTime.utc(2024, 7, 1)),
      ),
      {'turtle'},
    );
  });

  test('nextServiceDue reads the service cache', () async {
    for (final id in ['soon', 'later', 'unknown']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: day,
              updatedAt: day,
            ),
          );
    }
    Future<void> due(String id, DateTime? at) => db
        .into(db.equipmentServiceStatus)
        .insert(
          EquipmentServiceStatusCompanion.insert(
            equipmentId: id,
            severity: 'ok',
            computedAt: day,
          ).copyWith(dueDate: Value(at?.millisecondsSinceEpoch)),
        );
    await due('soon', DateTime(2024, 6, 20));
    await due('later', DateTime(2025, 1, 1));
    await due('unknown', null);
    expect(
      await ids(
        equipmentQueryEntity,
        c('nextServiceDue', QueryOp.lte, DateTime(2024, 7, 1)),
      ),
      {'soon'},
    );
  });
}
```

The companion names above follow the generated Drift classes; if one differs (for example the service-status companion), use the generated name from `lib/core/database/database.g.dart` and keep the assertions.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/query/dive_aggregate_fields_test.dart`
Expected: FAIL, the compiler refuses `diveCount` (unknown field).

- [ ] **Step 3: Write the shared field builders**

`lib/features/dive_log/query/dive_aggregate_fields.dart`:

```dart
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// A subject's counted dives, as a FROM/WHERE fragment over the alias `ad`
/// (no other registry fragment uses it): the dives [linkSql] ties to the
/// row `{r}`, inside the stats scope, so a count is the one the list tiles
/// show. [linkSql] is written against `{r}` and `ad`.
String _counted(String linkSql) =>
    'FROM dives ad WHERE $linkSql${DiveStatsScope.and(alias: 'ad')}';

/// How many counted dives the row has. Never unrecorded: `:none` is none.
QueryField diveCountField(
  String subjectKey,
  String linkSql, {
  List<String> tables = const [],
}) => QueryField(
  key: 'diveCount',
  type: FieldType.number,
  dimension: FieldDimension.count,
  sql: '(SELECT COUNT(*) ${_counted(linkSql)})',
  emptySql: 'NOT EXISTS (SELECT 1 ${_counted(linkSql)})',
  labelKey: 'query_${subjectKey}_diveCount',
  tables: ['dives', ...tables],
);

/// The newest (or, with [first], the oldest) counted dive's date. Rows
/// with no counted dive have none, so no bound matches them.
QueryField diveDateField(
  String subjectKey,
  String key,
  String linkSql, {
  bool first = false,
  List<String> tables = const [],
}) => QueryField(
  key: key,
  type: FieldType.date,
  sql: '(SELECT ${first ? 'MIN' : 'MAX'}(ad.dive_date_time) '
      '${_counted(linkSql)})',
  emptySql: 'NOT EXISTS (SELECT 1 ${_counted(linkSql)})',
  labelKey: 'query_${subjectKey}_$key',
  tables: ['dives', ...tables],
);
```

- [ ] **Step 4: Add the fields to each entity**

In `site_query_entity.dart`, append to `fields` (the list is not `const` at the top level; drop `const` from any enclosing literal the new calls sit in):

```dart
    diveCountField('sites', 'ad.site_id = {r}.id'),
    diveDateField('sites', 'lastDived', 'ad.site_id = {r}.id'),
```

In `dive_center_query_entity.dart` (the entity is `const`; make it `final` and keep the inner literals `const` where they already are):

```dart
    diveCountField('centers', 'ad.dive_center_id = {r}.id'),
    diveDateField('centers', 'lastDived', 'ad.dive_center_id = {r}.id'),
```

In `trip_query_entity.dart`:

```dart
    diveCountField('trips', 'ad.trip_id = {r}.id'),
```

In `buddy_query_entity.dart` (make the entity `final`):

```dart
    diveCountField(
      'buddies',
      'ad.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {r}.id)',
      tables: const ['dive_buddies'],
    ),
    diveDateField(
      'buddies',
      'lastDived',
      'ad.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {r}.id)',
      tables: const ['dive_buddies'],
    ),
```

In `equipment_query_entity.dart`, define the gear link once beside `serviceStatusTable` and add three fields:

```dart
/// A counted dive this item was on: linked through dive_equipment, or a
/// cylinder matched through dive_tanks (the dive gear union).
const _gearDiveLink =
    'ad.id IN (SELECT de.dive_id FROM dive_equipment de '
    'WHERE de.equipment_id = {r}.id '
    'UNION SELECT dt.dive_id FROM dive_tanks dt '
    'WHERE dt.equipment_id = {r}.id)';
```

```dart
    diveCountField(
      'equipment',
      _gearDiveLink,
      tables: const ['dive_equipment', 'dive_tanks'],
    ),
    diveDateField(
      'equipment',
      'lastDived',
      _gearDiveLink,
      tables: const ['dive_equipment', 'dive_tanks'],
    ),
    // The worst service clock's next due instant, from the same cache
    // `serviceDue` reads: "due within 30 days" is a bound on this date.
    const QueryField(
      key: 'nextServiceDue',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql:
          '(SELECT s.due_date FROM $serviceStatusTable s '
          'WHERE s.equipment_id = {r}.id)',
      emptySql:
          'NOT EXISTS (SELECT 1 FROM $serviceStatusTable s '
          'WHERE s.equipment_id = {r}.id AND s.due_date IS NOT NULL)',
      labelKey: 'query_equipment_nextServiceDue',
      tables: [serviceStatusTable],
    ),
```

In `species_query_entity.dart`:

```dart
    diveCountField(
      'species',
      'ad.id IN (SELECT s.dive_id FROM sightings s '
          'WHERE s.species_id = {r}.id)',
      tables: const ['sightings'],
    ),
    diveDateField(
      'species',
      'firstSeen',
      'ad.id IN (SELECT s.dive_id FROM sightings s '
          'WHERE s.species_id = {r}.id)',
      first: true,
      tables: const ['sightings'],
    ),
    diveDateField(
      'species',
      'lastSeen',
      'ad.id IN (SELECT s.dive_id FROM sightings s '
          'WHERE s.species_id = {r}.id)',
      tables: const ['sightings'],
    ),
```

Each entity file imports `package:submersion/features/dive_log/query/dive_aggregate_fields.dart`. Where an entity changes from `const` to `final` (buddies, centers), its existing `QueryField(...)` and `QueryRelation(...)` literals lose the implicit `const`: add `const` in front of each, or `flutter analyze` reports `prefer_const_constructors`, and CI fails on infos.

- [ ] **Step 5: Add the 13 label keys**

English values (insert into `app_en.arb` alphabetically among the `query_<subject>_*` keys; into the other ten beside an existing `query_<subject>_*` key of the same subject):

| Key | English |
| --- | --- |
| `query_sites_diveCount` | Dive count |
| `query_sites_lastDived` | Last dived |
| `query_centers_diveCount` | Dive count |
| `query_centers_lastDived` | Last dived |
| `query_trips_diveCount` | Dive count |
| `query_buddies_diveCount` | Dives together |
| `query_buddies_lastDived` | Last dived together |
| `query_equipment_diveCount` | Dives used |
| `query_equipment_lastDived` | Last used |
| `query_equipment_nextServiceDue` | Next service due |
| `query_species_diveCount` | Dives seen on |
| `query_species_firstSeen` | First seen |
| `query_species_lastSeen` | Last seen |

Translate each into ar, de, es, fr, he, hu, it, nl, pt, zh. Then:

Run: `python3.14 scripts/gen_query_label_lookup.py && flutter gen-l10n`

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/query/dive_aggregate_fields_test.dart test/features/query/query_registry_guards_test.dart test/features/query/app_query_registry_test.dart test/l10n`
Expected: PASS. The guards confirm each new fragment compiles, declares its tables, binds nothing, and has its label in every locale.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/query/dive_aggregate_fields.dart lib/features/dive_sites/query/site_query_entity.dart lib/features/equipment/query/equipment_query_entity.dart lib/features/buddies/query/buddy_query_entity.dart lib/features/trips/query/trip_query_entity.dart lib/features/dive_centers/query/dive_center_query_entity.dart lib/features/marine_life/query/species_query_entity.dart lib/l10n lib/features/query/presentation/query_label_lookup.dart test/features/query/dive_aggregate_fields_test.dart
git commit -m "feat(query): dive count and last dived on every subject registry"
```

### Task 2: Each subject's Explore fields, and the date and days kinds

**Files:**
- Create: `lib/features/explore/domain/explore_subject_fields.dart`
- Modify: `lib/features/explore/domain/explore_fields.dart`, `lib/features/explore/domain/explore_clause_lowering.dart`
- Test: `test/features/explore/domain/explore_subject_fields_test.dart`, `test/features/explore/domain/explore_subject_clause_lowering_test.dart`

**Interfaces:**
- Consumes: Task 1's registry keys.
- Produces:
  - `ExploreValueKind.date`, `ExploreValueKind.days`.
  - `ExploreField(name, path, kind, {QuerySubject root = QuerySubject.dives, bool wholeNumbers, bounds, tokens, bool strictCount = false})`.
  - `QuerySubject rootOf(ParsedSubject subject)`.
  - `final Map<ParsedSubject, List<ExploreField>> kExploreSubjectFields`.
  - `({ExploreField field, bool viaDives})? exploreFieldFor(ParsedSubject subject, String name)`.
  - `List<String> exploreFieldNames()`: every field word, dive fields first, each once.
  - `LoweredClause lowerClause(QueryClause c, ExploreField? field, UnitPrefs units, {DateTime? now})`.

- [ ] **Step 1: Write the failing field tests**

`test/features/explore/domain/explore_subject_fields_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('every subject field resolves on its own registry root', () {
    for (final entry in kExploreSubjectFields.entries) {
      for (final f in entry.value) {
        expect(f.root, rootOf(entry.key), reason: f.name);
        expect(f.field, isNotNull, reason: '${entry.key.name}.${f.name}');
      }
    }
  });

  test('the kinds match the registry types', () {
    for (final f in kExploreSubjectFields.values.expand((l) => l)) {
      final type = f.field!.type;
      switch (f.kind) {
        case ExploreValueKind.number:
          expect(type, FieldType.number, reason: f.name);
        case ExploreValueKind.enumName:
          expect(type, FieldType.enumName, reason: f.name);
          expect(f.enumValues, isNotEmpty, reason: f.name);
        case ExploreValueKind.flag:
          expect(type, FieldType.bool, reason: f.name);
        case ExploreValueKind.date || ExploreValueKind.days:
          expect(type, FieldType.date, reason: f.name);
        case ExploreValueKind.typeName:
          fail('no subject field names a type: ${f.name}');
      }
    }
  });

  test("a subject's own word wins; any other dive word goes via dives", () {
    final rating = exploreFieldFor(ParsedSubject.sites, 'rating')!;
    expect(rating.viaDives, isFalse);
    expect(rating.field.root, QuerySubject.sites);

    final depth = exploreFieldFor(ParsedSubject.sites, 'depth')!;
    expect(depth.field.path, ['maxDepth']);
    expect(depth.field.dimension, FieldDimension.depth);

    final water = exploreFieldFor(ParsedSubject.sites, 'waterTemp')!;
    expect(water.viaDives, isTrue);
    expect(water.field.root, QuerySubject.dives);

    final diveRating = exploreFieldFor(ParsedSubject.dives, 'rating')!;
    expect(diveRating.viaDives, isFalse);
    expect(diveRating.field.root, QuerySubject.dives);

    expect(exploreFieldFor(ParsedSubject.buddies, 'nonsense'), isNull);
    // Another subject's own word is unknown here, not borrowed.
    expect(exploreFieldFor(ParsedSubject.buddies, 'gearType'), isNull);
  });

  test('the field words are every field once, dives first', () {
    final names = exploreFieldNames();
    expect(names.toSet().length, names.length);
    expect(names.take(kExploreFields.length), [
      for (final f in kExploreFields) f.name,
    ]);
    for (final f in kExploreSubjectFields.values.expand((l) => l)) {
      expect(names, contains(f.name));
    }
  });
}
```

- [ ] **Step 2: Write the failing lowering tests**

`test/features/explore/domain/explore_subject_clause_lowering_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/explore_clause_lowering.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  const metric = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );
  final now = DateTime(2026, 9, 30);

  LoweredClause lower(ParsedSubject s, String field, String op, Object value) {
    final c = QueryClause(
      field: field,
      op: ClauseOp.values.firstWhere((o) => o.jsonName == op),
      value: value,
      text: '$field $op $value',
    );
    return lowerClause(c, exploreFieldFor(s, field)!.field, metric, now: now);
  }

  ConditionNode cond(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);

  group('date fields take a time phrase', () {
    test('before a year is before its first day', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', '2022');
      expect(r.error, isNull);
      expect(r.nodes, [cond('lastDived', QueryOp.lt, DateValue(DateTime(2022)))]);
    });

    test('a bare number year reads as the year', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', 2022);
      expect(r.nodes, [cond('lastDived', QueryOp.lt, DateValue(DateTime(2022)))]);
    });

    test('after a year is after its last day', () {
      final r = lower(ParsedSubject.species, 'firstSeen', 'gt', '2023');
      expect(r.nodes, [
        cond('firstSeen', QueryOp.gt, DateValue(DateTime(2023, 12, 31))),
      ]);
    });

    test('eq is within the period', () {
      final r = lower(ParsedSubject.species, 'lastSeen', 'eq', 'last year');
      expect(r.nodes, [
        cond('lastSeen', QueryOp.gte, DateValue(DateTime(2025))),
        cond('lastSeen', QueryOp.lte, DateValue(DateTime(2025, 12, 31))),
      ]);
    });

    test('words the date grammar cannot read are unplaced', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', 'ages ago');
      expect(r.error, 'unknownTime');
    });
  });

  group('days count forward from today', () {
    test('within 30 days bounds the next due date', () {
      final r = lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', 30);
      expect(r.nodes, [
        cond('nextServiceDue', QueryOp.lte, DateValue(DateTime(2026, 10, 30))),
      ]);
      expect(r.chip!.value, 30);
    });

    test('a negative or huge number of days is out of range', () {
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', -3).error,
        'outOfRange',
      );
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', 5000).error,
        'outOfRange',
      );
    });

    test('more than N days is not a due window', () {
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'gt', 30).error,
        'invalid',
      );
    });
  });

  group('a dive count is strict', () {
    test('more than twice is at least three', () {
      final r = lower(ParsedSubject.centers, 'diveCount', 'gt', 2);
      expect(r.nodes, [cond('diveCount', QueryOp.gte, NumberValue(3, null))]);
      expect(r.chip!.op, ClauseOp.gte);
      expect(r.chip!.value, 3);
    });

    test('fewer than three is at most two', () {
      final r = lower(ParsedSubject.species, 'diveCount', 'lt', 3);
      expect(r.nodes, [cond('diveCount', QueryOp.lte, NumberValue(2, null))]);
    });

    test('exactly once stays exact', () {
      final r = lower(ParsedSubject.species, 'diveCount', 'eq', 1);
      expect(r.nodes, [
        cond('diveCount', QueryOp.gte, NumberValue(1, null)),
        cond('diveCount', QueryOp.lte, NumberValue(1, null)),
      ]);
    });
  });

  test('a site depth grounds the unit on the site max depth', () {
    final r = lowerClause(
      const QueryClause(
        field: 'depth',
        op: ClauseOp.gt,
        value: 100,
        unit: ClauseUnit.ft,
        text: 'deeper than 100 ft',
      ),
      exploreFieldFor(ParsedSubject.sites, 'depth')!.field,
      metric,
      now: now,
    );
    expect(r.nodes, [cond('maxDepth', QueryOp.gte, NumberValue(30.48, null))]);
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/explore/domain/explore_subject_fields_test.dart test/features/explore/domain/explore_subject_clause_lowering_test.dart`
Expected: FAIL, `explore_subject_fields.dart` does not exist.

- [ ] **Step 4: Extend ExploreField**

In `lib/features/explore/domain/explore_fields.dart`:

```dart
import 'package:submersion/core/query/domain/query_subject.dart';
```

```dart
enum ExploreValueKind { number, enumName, flag, typeName, date, days }
```

Replace the class head and `field` getter:

```dart
/// One field the model may name (#2365 PR 5): its word, the registry path
/// it lowers onto from [root], and everything else read from the registry.
class ExploreField {
  const ExploreField(
    this.name,
    this.path,
    this.kind, {
    this.root = QuerySubject.dives,
    this.wholeNumbers = false,
    this.bounds,
    this.tokens,
    this.strictCount = false,
  });

  /// The model's word: part of the stored JSON contract, never renamed.
  final String name;
  final List<String> path;
  final ExploreValueKind kind;

  /// The registry entity [path] starts from: dives, or a phase 3 subject.
  final QuerySubject root;

  /// Bounds round to whole numbers, as the filter axes they replace did.
  final bool wholeNumbers;

  /// Explore's own bounds where the registry declares no sanity.
  final ({double min, double max})? bounds;

  /// The model's tokens when they differ from the registry's enum names.
  final List<String>? tokens;

  /// A count said with a strict word: "more than twice" is at least three,
  /// where a measured value's "more than 20 m" stays at least 20.
  final bool strictCount;

  /// The registry field at [path], or null for a relation (noBuddy).
  QueryField? get field => _resolved.putIfAbsent(
    '${root.name}:${path.join('.')}',
    () => resolvePath(
      appQueryRegistry,
      appQueryRegistry.entityFor(root),
      FieldPath(path),
    ).field,
  );
```

Remove the now-unused `dive_query_entity.dart` import. Extend `ops`:

```dart
  Set<ClauseOp> get ops => switch (kind) {
    ExploreValueKind.number || ExploreValueKind.date => _ordering,
    ExploreValueKind.enumName => _membership,
    ExploreValueKind.flag => const {ClauseOp.eq},
    ExploreValueKind.typeName => const {ClauseOp.eq, ClauseOp.inList},
    ExploreValueKind.days => const {ClauseOp.lt, ClauseOp.lte, ClauseOp.eq},
  };
```

- [ ] **Step 5: Write the subject catalogs**

`lib/features/explore/domain/explore_subject_fields.dart`:

```dart
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// The registry entity a subject's query roots at.
QuerySubject rootOf(ParsedSubject subject) => switch (subject) {
  ParsedSubject.dives => QuerySubject.dives,
  ParsedSubject.sites => QuerySubject.sites,
  ParsedSubject.equipment => QuerySubject.equipment,
  ParsedSubject.buddies => QuerySubject.buddies,
  ParsedSubject.species => QuerySubject.species,
  ParsedSubject.trips => QuerySubject.trips,
  ParsedSubject.centers => QuerySubject.centers,
};

ExploreField _diveCount(QuerySubject root) => ExploreField(
  'diveCount',
  const ['diveCount'],
  ExploreValueKind.number,
  root: root,
  wholeNumbers: true,
  strictCount: true,
);

ExploreField _lastDived(QuerySubject root) => ExploreField(
  'lastDived',
  const ['lastDived'],
  ExploreValueKind.date,
  root: root,
);

/// Each non-dive subject's own fields, in the prompt's order (phase 3).
/// A word that is also a dive field (depth, rating, favorite) means the
/// subject's own field under that subject.
final Map<ParsedSubject, List<ExploreField>> kExploreSubjectFields = {
  ParsedSubject.sites: [
    const ExploreField(
      'depth',
      ['maxDepth'],
      ExploreValueKind.number,
      root: QuerySubject.sites,
    ),
    const ExploreField(
      'rating',
      ['rating'],
      ExploreValueKind.number,
      root: QuerySubject.sites,
      wholeNumbers: true,
    ),
    const ExploreField(
      'difficulty',
      ['difficulty'],
      ExploreValueKind.enumName,
      root: QuerySubject.sites,
    ),
    _diveCount(QuerySubject.sites),
    _lastDived(QuerySubject.sites),
  ],
  ParsedSubject.equipment: [
    const ExploreField(
      'gearType',
      ['type'],
      ExploreValueKind.enumName,
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'gearStatus',
      ['status'],
      ExploreValueKind.enumName,
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'serviceDue',
      ['serviceDue'],
      ExploreValueKind.enumName,
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'serviceDueWithin',
      ['nextServiceDue'],
      ExploreValueKind.days,
      root: QuerySubject.equipment,
    ),
    _diveCount(QuerySubject.equipment),
    _lastDived(QuerySubject.equipment),
  ],
  ParsedSubject.buddies: [
    const ExploreField(
      'favorite',
      ['favorite'],
      ExploreValueKind.flag,
      root: QuerySubject.buddies,
    ),
    _diveCount(QuerySubject.buddies),
    _lastDived(QuerySubject.buddies),
  ],
  ParsedSubject.species: [
    const ExploreField(
      'speciesCategory',
      ['category'],
      ExploreValueKind.enumName,
      root: QuerySubject.species,
    ),
    _diveCount(QuerySubject.species),
    const ExploreField(
      'firstSeen',
      ['firstSeen'],
      ExploreValueKind.date,
      root: QuerySubject.species,
    ),
    const ExploreField(
      'lastSeen',
      ['lastSeen'],
      ExploreValueKind.date,
      root: QuerySubject.species,
    ),
  ],
  ParsedSubject.trips: [
    const ExploreField(
      'tripType',
      ['tripType'],
      ExploreValueKind.enumName,
      root: QuerySubject.trips,
    ),
    _diveCount(QuerySubject.trips),
  ],
  ParsedSubject.centers: [
    const ExploreField(
      'rating',
      ['rating'],
      ExploreValueKind.number,
      root: QuerySubject.centers,
      wholeNumbers: true,
    ),
    _diveCount(QuerySubject.centers),
    _lastDived(QuerySubject.centers),
  ],
};

/// The field [name] means under [subject]: the subject's own field first,
/// else a dive field, which a non-dive subject reads through its dives.
/// Another subject's own word is unknown here.
({ExploreField field, bool viaDives})? exploreFieldFor(
  ParsedSubject subject,
  String name,
) {
  if (subject != ParsedSubject.dives) {
    for (final f in kExploreSubjectFields[subject]!) {
      if (f.name == name) return (field: f, viaDives: false);
    }
  }
  final dive = exploreField(name);
  if (dive == null) return null;
  return (field: dive, viaDives: subject != ParsedSubject.dives);
}

/// Every field word the model may write, dive fields first, each once.
List<String> exploreFieldNames() {
  final seen = <String>{};
  return [
    for (final f in kExploreFields)
      if (seen.add(f.name)) f.name,
    for (final list in kExploreSubjectFields.values)
      for (final f in list)
        if (seen.add(f.name)) f.name,
  ];
}
```

- [ ] **Step 6: Lower the new kinds**

In `lib/features/explore/domain/explore_clause_lowering.dart`, add the imports:

```dart
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
```

Change the entry point:

```dart
/// One model clause as query nodes on its registry path (#2365 PR 5). The
/// model chose the words; units, bounds and values are decided here. [now]
/// anchors the date and days kinds.
LoweredClause lowerClause(
  QueryClause c,
  ExploreField? field,
  UnitPrefs units, {
  DateTime? now,
}) {
  if (field == null) return _fail('unknownField');
  if (!field.ops.contains(c.op)) return _fail('invalid');
  return switch (field.kind) {
    ExploreValueKind.number => _number(c, field, units),
    ExploreValueKind.flag => _flag(c, field),
    ExploreValueKind.enumName => _enum(c, field),
    ExploreValueKind.typeName => _typeName(c, field),
    ExploreValueKind.date => _date(c, field, now ?? DateTime.now()),
    ExploreValueKind.days => _days(c, field, now ?? DateTime.now()),
  };
}
```

Add:

```dart
/// A date field compared with a time phrase: before the period is before
/// its first day, after it is after its last, and eq is within it. A bare
/// number is a year.
LoweredClause _date(QueryClause c, ExploreField field, DateTime now) {
  final text = switch (c.value) {
    final String s => s,
    final num n => '${n.toInt()}',
    _ => null,
  };
  if (text == null) return _fail('invalid');
  final range = parseDateText(text, now: now);
  if (range == null) return _fail('unknownTime');
  final key = field.path.last;
  ConditionNode at(QueryOp op, DateTime d) =>
      ConditionNode(FieldPath([key]), op, DateValue(d));
  final nodes = <QueryNode>[
    ...switch (c.op) {
      ClauseOp.lt || ClauseOp.lte => [
        if (range.start != null) at(QueryOp.lt, range.start!),
      ],
      ClauseOp.gt || ClauseOp.gte => [
        if (range.end != null) at(QueryOp.gt, range.end!),
      ],
      _ => [
        if (range.start != null) at(QueryOp.gte, range.start!),
        if (range.end != null) at(QueryOp.lte, range.end!),
      ],
    },
  ];
  if (nodes.isEmpty) return _fail('invalid');
  return (
    nodes: nodes,
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: (start: range.start, end: range.end),
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

/// "Within N days" from today, inclusive: the date field on or before
/// today plus N. An overdue date is already before it, so it matches.
LoweredClause _days(QueryClause c, ExploreField field, DateTime now) {
  final raw = c.value;
  if (raw is! num) return _fail('invalid');
  if (raw < 0 || raw > 3650) return _fail('outOfRange');
  final days = raw.round();
  final until = DateTime(now.year, now.month, now.day + days);
  return (
    nodes: [
      ConditionNode(
        FieldPath([field.path.last]),
        QueryOp.lte,
        DateValue(until),
      ),
    ],
    chip: ClauseChip(
      field: field,
      op: ClauseOp.lte,
      value: days,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}
```

`parseDateText` (`lib/core/query/syntax/date_grammar.dart`) returns a `DateRange?`, a record of nullable `start` and `end`.

In `_number`, make a strict count strict. Replace the single-value `switch (c.op)` arms for `lt`/`lte` and `gt`/`gte`:

```dart
      case ClauseOp.lt:
        hi = field.strictCount ? v.ceilToDouble() - 1 : v;
      case ClauseOp.lte:
        hi = v;
      case ClauseOp.gt:
        lo = field.strictCount ? v.floorToDouble() + 1 : v;
      case ClauseOp.gte:
        lo = v;
```

and report the applied bound on the chip, just before the final `return`:

```dart
  if (field.strictCount) {
    if (c.op == ClauseOp.gt) chipValue = lo!;
    if (c.op == ClauseOp.lt) chipValue = hi!;
  }
```

(`chipValue` must be declared with `var`-style reassignment: change `Object chipValue;` to a non-final `Object chipValue;` if the analyzer flags it; it is already assigned in both branches.)

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/explore/domain`
Expected: PASS, including the existing compiler, rating and fixture tests (the compiler still calls `lowerClause` without `now`, which defaults).

- [ ] **Step 8: Commit**

```bash
git add lib/features/explore/domain/explore_fields.dart lib/features/explore/domain/explore_subject_fields.dart lib/features/explore/domain/explore_clause_lowering.dart test/features/explore/domain/explore_subject_fields_test.dart test/features/explore/domain/explore_subject_clause_lowering_test.dart
git commit -m "feat(explore): each subject's own fields, date phrases and due windows"
```

### Task 3: The compiler's subject dispatch

**Files:**
- Create: `lib/features/explore/domain/explore_subject_lowering.dart`
- Modify: `lib/features/explore/domain/explore_compiler.dart`, `lib/features/explore/domain/explore_compilation.dart`, `lib/features/explore/domain/chart_selection.dart`
- Test: `test/features/explore/domain/explore_compiler_subjects_test.dart`; update `test/features/explore/domain/explore_compiler_test.dart` (the not-supported case)

**Interfaces:**
- Consumes: Task 2's `exploreFieldFor`, `rootOf`, `lowerClause(..., now:)`.
- Produces:
  - `ExploreCompilation({ParsedSubject subject = ParsedSubject.dives, required QueryNode? query, QueryNode? diveScope, required chips, required unresolved, required unplaced, required charts})`. `query` is rooted at `rootOf(subject)`; `diveScope` is the dive-level part a non-dive subject reaches through its dives (null for dives, or when there is none).
  - `QueryChip({..., bool viaDives = false})`.
  - Unplaced reason `countInPeriod`; the reason `subjectNotSupported` is gone.
  - `ChartKind.subjectCounts`.
  - `bool ownsTarget(ParsedSubject subject, NameTarget target)`, `List<QueryNode> lowerOwnMentions(ParsedSubject, List<NameEntry>, NameIndex)`, `List<QueryNode> lowerTripTime(DateTime? start, DateTime? end)`, `QueryNode countedDives(List<QueryNode> parts)`.

- [ ] **Step 1: Write the failing test**

`test/features/explore/domain/explore_compiler_subjects_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/explore_subject_lowering.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Phase 3: a sentence about sites, gear, buddies, species, trips or
/// centers roots at that subject. Its own words stay on it; everything
/// else is about its dives.
void main() {
  const names = NameIndex([
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Bonaire',
      ids: ['s1'],
      target: NameTarget.sitePlace,
      placeFields: ['island'],
    ),
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Mexico',
      ids: ['s2'],
      target: NameTarget.sitePlace,
      placeFields: ['country'],
    ),
    NameEntry(
      subject: QuerySubject.species,
      label: 'Turtle',
      ids: ['sp1'],
      target: NameTarget.speciesId,
      primary: true,
    ),
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: ['b1'],
      target: NameTarget.buddyId,
      primary: true,
    ),
  ]);

  ExploreCompilation compile(
    String subject, {
    List<Map<String, Object?>> clauses = const [],
    List<Map<String, Object?>> mentions = const [],
    String? time,
  }) => ExploreCompiler.compile(
    ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': subject,
      'clauses': clauses,
      'mentions': mentions,
      'time': time == null ? null : {'text': time},
      'unplaced': const <String>[],
    }),
    ExploreCompilerContext(
      units: const UnitPrefs(
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
      ),
      names: names,
      now: DateTime(2026, 9, 30),
    ),
  );

  Map<String, Object?> clause(String field, String op, Object value) => {
    'field': field,
    'op': op,
    'value': value,
    'text': '$field $op $value',
  };

  ConditionNode cond(List<String> path, QueryOp op, QueryValue? v) =>
      ConditionNode(FieldPath(path), op, v);

  QueryNode turtles() => cond(
    ['sightings', 'species'],
    QueryOp.inList,
    ListValue([const RefValue('sp1', 'Turtle')]),
  );

  test('sites in Bonaire I have not dived since 2022', () {
    final q = compile(
      'sites',
      clauses: [clause('lastDived', 'lt', '2022')],
      mentions: [
        {'kind': 'place', 'text': 'Bonaire'},
      ],
    );
    expect(q.subject, ParsedSubject.sites);
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(['lastDived'], QueryOp.lt, DateValue(DateTime(2022))),
        cond(['island'], QueryOp.eq, const StringValue('Bonaire')),
      ]),
    );
    expect(q.diveScope, isNull);
    expect(q.chips.every((c) => !c.viaDives), isTrue);
    expect(q.charts, [const ChartRequest(ChartKind.subjectCounts)]);
  });

  test('sites where I saw turtles reach the sightings through the dives', () {
    final q = compile(
      'sites',
      mentions: [
        {'kind': 'species', 'text': 'Turtle'},
      ],
    );
    expect(q.query, countedDives([turtles()]));
    expect(q.diveScope, turtles());
    expect(q.chips.single.viaDives, isTrue);
  });

  test('regulators due for service in 30 days', () {
    final q = compile(
      'equipment',
      clauses: [
        clause('gearType', 'eq', 'regulator'),
        clause('serviceDueWithin', 'lte', 30),
      ],
    );
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(
          ['type'],
          QueryOp.inList,
          ListValue(const [EnumValue('regulator')]),
        ),
        cond(['nextServiceDue'], QueryOp.lte, DateValue(DateTime(2026, 10, 30))),
      ]),
    );
  });

  test('who have I dived with most this year: the period is the dives', () {
    final q = compile('buddies', time: 'this year');
    final period = [
      cond(['date'], QueryOp.gte, DateValue(DateTime(2026))),
      cond(['date'], QueryOp.lte, DateValue(DateTime(2026, 12, 31))),
    ];
    expect(q.query, countedDives(period));
    expect(q.diveScope, AndNode(period));
    expect(q.chips.single.ref, ChipRef.time);
    expect(q.chips.single.viaDives, isTrue);
  });

  test('species I have only seen once', () {
    final q = compile('species', clauses: [clause('diveCount', 'eq', 1)]);
    expect(
      q.query,
      AndNode([
        cond(['diveCount'], QueryOp.gte, NumberValue(1, null)),
        cond(['diveCount'], QueryOp.lte, NumberValue(1, null)),
      ]),
    );
  });

  test("liveaboard trips in 2024: the period is the trip's own dates", () {
    final q = compile(
      'trips',
      clauses: [clause('tripType', 'eq', 'liveaboard')],
      time: '2024',
    );
    expect(
      q.query,
      AndNode([
        cond(
          ['tripType'],
          QueryOp.inList,
          ListValue(const [EnumValue('liveaboard')]),
        ),
        cond(['startDate'], QueryOp.lte, DateValue(DateTime(2024, 12, 31))),
        cond(['endDate'], QueryOp.gte, DateValue(DateTime(2024))),
      ]),
    );
    expect(q.diveScope, isNull);
    expect(q.chips.last.viaDives, isFalse);
  });

  test('centers in Mexico I have used more than twice', () {
    final q = compile(
      'centers',
      clauses: [clause('diveCount', 'gt', 2)],
      mentions: [
        {'kind': 'place', 'text': 'Mexico'},
      ],
    );
    expect(q.unplaced, isEmpty);
    expect(
      q.query,
      AndNode([
        cond(['diveCount'], QueryOp.gte, NumberValue(3, null)),
        OrNode([
          cond(['country'], QueryOp.eq, const StringValue('Mexico')),
          cond(['city'], QueryOp.eq, const StringValue('Mexico')),
          cond(['stateProvince'], QueryOp.eq, const StringValue('Mexico')),
        ]),
      ]),
    );
  });

  test('a count with a period is unplaced, not counted all time', () {
    final q = compile(
      'buddies',
      clauses: [clause('diveCount', 'gt', 10)],
      time: 'this year',
    );
    expect(q.unplaced.single.reason, 'countInPeriod');
    expect(q.chips.single.ref, ChipRef.time);
  });

  test('a dive field under buddies is about the dives', () {
    final q = compile('buddies', clauses: [clause('depth', 'gt', 40)]);
    expect(
      q.query,
      countedDives([cond(['depth'], QueryOp.gte, NumberValue(40, null))]),
    );
    expect(q.chips.single.viaDives, isTrue);
  });

  test("a buddy named under buddies is that buddy's row", () {
    final q = compile(
      'buddies',
      mentions: [
        {'kind': 'buddy', 'text': 'Ana'},
      ],
    );
    expect(
      q.query,
      cond(['name'], QueryOp.inList, ListValue(const [StringValue('Ana')])),
    );
    expect(q.chips.single.viaDives, isFalse);
  });

  test('a subject alone selects every row', () {
    final q = compile('sites');
    expect(q.query, isNull);
    expect(q.chips, isEmpty);
    expect(q.unplaced, isEmpty);
    expect(q.charts, [const ChartRequest(ChartKind.subjectCounts)]);
  });

  test("another subject's own word is unknown", () {
    final q = compile('buddies', clauses: [clause('gearType', 'eq', 'fins')]);
    expect(q.unplaced.single.reason, 'unknownField');
    expect(q.query, isNull);
  });
}
```

In `test/features/explore/domain/explore_compiler_test.dart`, delete the test that expects a non-dive subject to yield `subjectNotSupported` (search the file for `subjectNotSupported`); the subject tests above replace it.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/explore/domain/explore_compiler_subjects_test.dart`
Expected: FAIL, `explore_subject_lowering.dart` does not exist.

- [ ] **Step 3: Extend the compilation types**

In `lib/features/explore/domain/explore_compilation.dart`:

```dart
class QueryChip {
  final ChipRef ref;
  final int index;
  final ChipPayload payload;

  /// Whether this chip narrows the subject through its dives (a dive field,
  /// another kind's mention or a period under sites, say) rather than the
  /// subject's own rows. Always false for dives.
  final bool viaDives;
  const QueryChip({
    required this.ref,
    required this.index,
    required this.payload,
    this.viaDives = false,
  });
}
```

Update `UnplacedItem`'s doc: the reasons are `unknownField`, `invalid`, `outOfRange`, `noAxis`, `unknownTime`, `countInPeriod`, or null.

```dart
class ExploreCompilation {
  /// What the sentence asks for.
  final ParsedSubject subject;

  /// The sentence as one query rooted at [subject]'s registry entity; null
  /// when nothing was placed.
  final QueryNode? query;

  /// For a non-dive subject, the dive-level part it reaches through its
  /// dives (a dive field, another kind's mention, a period): the ranking
  /// counts these dives. Null for dives, or when the sentence has none.
  final QueryNode? diveScope;
  final List<QueryChip> chips;
  final List<UnresolvedMention> unresolved;
  final List<UnplacedItem> unplaced;
  final List<ChartRequest> charts;
  const ExploreCompilation({
    this.subject = ParsedSubject.dives,
    required this.query,
    this.diveScope,
    required this.chips,
    required this.unresolved,
    required this.unplaced,
    required this.charts,
  });
}
```

In `lib/features/explore/domain/chart_selection.dart`, add the kind (last, so existing names keep their meaning):

```dart
enum ChartKind {
  divesOverTime,
  depthTrend,
  waterTempTrend,
  bottomTimeTrend,
  sacTrend,
  entityCounts,

  /// A non-dive subject's one chart: dives in the scope per result row.
  subjectCounts,
}
```

- [ ] **Step 4: Write the subject lowering**

`lib/features/explore/domain/explore_subject_lowering.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Whether a mention resolved to [target] names the subject's own rows,
/// lowering onto the subject itself. Every other mention is about the
/// subject's dives. A place names a site's location under sites, and a
/// center's location under centers.
bool ownsTarget(ParsedSubject subject, NameTarget target) => switch (subject) {
  ParsedSubject.dives => false,
  ParsedSubject.sites =>
    target == NameTarget.siteId || target == NameTarget.sitePlace,
  ParsedSubject.equipment =>
    target == NameTarget.equipmentId || target == NameTarget.attrChoice,
  ParsedSubject.buddies => target == NameTarget.buddyId,
  ParsedSubject.species => target == NameTarget.speciesId,
  ParsedSubject.trips => target == NameTarget.tripId,
  ParsedSubject.centers =>
    target == NameTarget.centerId || target == NameTarget.sitePlace,
};

/// The subject's own mentions as conditions on its rows. A named row is
/// matched by its stored name (no registry entity has an id field), so two
/// rows sharing a name both match. Rows and places OR together, as a
/// dive's sites and places do; an attribute choice is its own condition.
List<QueryNode> lowerOwnMentions(
  ParsedSubject subject,
  List<NameEntry> entries,
  NameIndex names,
) {
  final out = <QueryNode>[];
  final rowNames = <String>{};
  final places = <QueryNode>[];
  for (final e in entries) {
    switch (e.target) {
      case NameTarget.sitePlace when subject == ParsedSubject.centers:
        for (final column in const ['country', 'city', 'stateProvince']) {
          places.add(
            ConditionNode(
              FieldPath([column]),
              QueryOp.eq,
              StringValue(e.label),
            ),
          );
        }
      case NameTarget.sitePlace when e.placeFields.isNotEmpty:
        for (final column in e.placeFields) {
          places.add(
            ConditionNode(
              FieldPath([column]),
              QueryOp.eq,
              StringValue(e.label),
            ),
          );
        }
      case NameTarget.attrChoice:
        out.add(
          equipmentAttrConditionNode(
            EquipmentAttrCondition(key: e.attrKey!, choices: {e.attrChoice!}),
          ),
        );
      default:
        // A row of the subject's kind, or a place with no recorded columns
        // (an index built by hand): its rows by their stored names.
        for (final id in e.ids) {
          rowNames.add(names.labelOf(e.subject, id) ?? e.label);
        }
    }
  }
  final parts = <QueryNode>[
    if (rowNames.isNotEmpty)
      ConditionNode(
        FieldPath(['name']),
        QueryOp.inList,
        ListValue([for (final n in rowNames) StringValue(n)]),
      ),
    ...places,
  ];
  if (parts.isNotEmpty) {
    out.add(parts.length == 1 ? parts.single : OrNode(parts));
  }
  return out;
}

/// The trips a period touches: starting on or before its last day and
/// ending on or after its first.
List<QueryNode> lowerTripTime(DateTime? start, DateTime? end) => [
  if (end != null)
    ConditionNode(FieldPath(['startDate']), QueryOp.lte, DateValue(end)),
  if (start != null)
    ConditionNode(FieldPath(['endDate']), QueryOp.gte, DateValue(start)),
];

/// The subject's counted dives matching [parts]: neither planned nor
/// excluded from statistics, as the dive counts and the site list's own
/// "has dives" are.
QueryNode countedDives(List<QueryNode> parts) => ScopedNode(
  FieldPath(['dives']),
  AndNode([
    ConditionNode(FieldPath(['planned']), QueryOp.eq, const BoolValue(false)),
    ConditionNode(
      FieldPath(['excludedFromStats']),
      QueryOp.eq,
      const BoolValue(false),
    ),
    ...parts,
  ]),
);
```

- [ ] **Step 5: Split the compiler**

In `lib/features/explore/domain/explore_compiler.dart`, add the imports:

```dart
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_lowering.dart';
```

Replace `compile` and add the helpers:

```dart
abstract final class ExploreCompiler {
  static ExploreCompilation compile(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) => query.subject == ParsedSubject.dives
      ? _dives(query, ctx)
      : _subject(query, ctx);

  static QueryNode? _and(List<QueryNode> nodes) => switch (nodes) {
    [] => null,
    [final only] => only,
    _ => AndNode(nodes),
  };

  /// Every mention resolved against the diver's names: the placed ones as
  /// (index, mention, entry), the rest added to [unresolved].
  static List<(int, QueryMention, NameEntry)> _resolve(
    ParsedQuery query,
    ExploreCompilerContext ctx,
    List<UnresolvedMention> unresolved,
  ) {
    final out = <(int, QueryMention, NameEntry)>[];
    for (var i = 0; i < query.mentions.length; i++) {
      final m = query.mentions[i];
      switch (resolveMention(m, ctx.names)) {
        case Resolved(:final entry):
          out.add((i, m, entry));
        case Ambiguous(:final candidates):
          unresolved.add(
            UnresolvedMention(index: i, mention: m, candidates: candidates),
          );
        case Unresolved():
          unresolved.add(
            UnresolvedMention(
              index: i,
              mention: m,
              candidates: _nearest(m, ctx.names),
            ),
          );
      }
    }
    return out;
  }
```

`_dives(query, ctx)` is the previous body of `compile` without the subject gate, with two changes: the clause call passes `now` (`lowerClause(c, exploreField(c.field), ctx.units, now: ctx.now)`), and the mention loop becomes:

```dart
    final resolved = <NameEntry>[];
    final entityIds = <MentionKind, Set<String>>{};
    for (final (i, m, entry) in _resolve(query, ctx, unresolved)) {
      resolved.add(entry);
      chips.add(
        QueryChip(
          ref: ChipRef.mention,
          index: i,
          payload: MentionChip(kind: m.kind, entry: entry),
        ),
      );
      entityIds.putIfAbsent(m.kind, () => {}).addAll(entry.ids);
    }
    nodes.addAll(lowerMentions(resolved, ctx.names));
```

and it returns `query: _and(nodes)`.

Add `_subject`:

```dart
  /// A sentence about another subject (phase 3). Its own fields, own-kind
  /// mentions and (for trips) its period lower onto the subject's rows;
  /// every other part is about its dives and lowers into [diveScope],
  /// reached through the subject's counted dives. A count cannot be said of
  /// a scope yet, so with one it is unplaced rather than counted all time.
  static ExploreCompilation _subject(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) {
    final subject = query.subject;
    final unresolved = <UnresolvedMention>[];
    final unplaced = <UnplacedItem>[];
    final chips = <QueryChip>[];
    final own = <QueryNode>[];
    final viaDives = <QueryNode>[];

    final resolved = _resolve(query, ctx, unresolved);
    final ownEntries = [
      for (final (_, _, e) in resolved)
        if (ownsTarget(subject, e.target)) e,
    ];
    final diveEntries = [
      for (final (_, _, e) in resolved)
        if (!ownsTarget(subject, e.target)) e,
    ];

    DateRange? range;
    if (query.time != null) {
      range = parseDateText(query.time!.text, now: ctx.now);
      if (range == null) {
        unplaced.add(UnplacedItem(query.time!.text, reason: 'unknownTime'));
      }
    }
    final timeViaDives = range != null && subject != ParsedSubject.trips;

    final clauses = <(int, bool, LoweredClause, QueryClause)>[];
    for (var i = 0; i < query.clauses.length; i++) {
      final c = query.clauses[i];
      final hit = exploreFieldFor(subject, c.field);
      if (hit == null) {
        unplaced.add(UnplacedItem(c.text, reason: 'unknownField'));
        continue;
      }
      final r = lowerClause(c, hit.field, ctx.units, now: ctx.now);
      if (r.error != null) {
        unplaced.add(UnplacedItem(c.text, reason: r.error));
        continue;
      }
      clauses.add((i, hit.viaDives, r, c));
    }
    final hasDivePart =
        diveEntries.isNotEmpty ||
        timeViaDives ||
        clauses.any((c) => c.$2);

    for (final (i, isViaDives, r, c) in clauses) {
      if (r.chip!.field.name == 'diveCount' && hasDivePart) {
        unplaced.add(UnplacedItem(c.text, reason: 'countInPeriod'));
        continue;
      }
      (isViaDives ? viaDives : own).addAll(r.nodes);
      chips.add(
        QueryChip(
          ref: ChipRef.clause,
          index: i,
          payload: r.chip!,
          viaDives: isViaDives,
        ),
      );
    }

    own.addAll(lowerOwnMentions(subject, ownEntries, ctx.names));
    viaDives.addAll(lowerMentions(diveEntries, ctx.names));
    for (final (i, m, e) in resolved) {
      chips.add(
        QueryChip(
          ref: ChipRef.mention,
          index: i,
          payload: MentionChip(kind: m.kind, entry: e),
          viaDives: !ownsTarget(subject, e.target),
        ),
      );
    }

    if (range != null) {
      if (timeViaDives) {
        viaDives.addAll(lowerTime(range.start, range.end));
      } else {
        own.addAll(lowerTripTime(range.start, range.end));
      }
      chips.add(
        QueryChip(
          ref: ChipRef.time,
          index: 0,
          payload: TimeChip(start: range.start, end: range.end),
          viaDives: timeViaDives,
        ),
      );
    }

    for (final w in query.unplaced) {
      unplaced.add(UnplacedItem(w));
    }
    if (viaDives.isNotEmpty) own.add(countedDives(viaDives));

    return ExploreCompilation(
      subject: subject,
      query: _and(own),
      diveScope: _and(viaDives),
      chips: chips,
      unresolved: unresolved,
      unplaced: unplaced,
      charts: const [ChartRequest(ChartKind.subjectCounts)],
    );
  }
```

`DateRange` comes from `date_grammar.dart`, already imported.

- [ ] **Step 6: Run the Explore domain tests**

Run: `flutter test test/features/explore/domain`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/explore/domain test/features/explore/domain
git commit -m "feat(explore): compile a sentence about any subject, its dives reached by relation"
```

### Task 4: Dives in the scope per row, for the ranking

**Files:**
- Modify: `lib/features/explore/data/explore_repository.dart`
- Test: `test/features/explore/data/explore_subject_counts_test.dart`

**Interfaces:**
- Consumes: Task 3's `ExploreCompilation.diveScope` shape (a dive-rooted `QueryNode?`).
- Produces:
  - `Future<Map<String, int>> ExploreRepository.diveCountsBySubject(ParsedSubject subject, QueryNode? diveScope, {String? diverId})`: for each row of [subject] with a counted dive of the diver matching [diveScope], how many. Rows with none are absent.
  - `static Set<String> ExploreRepository.subjectCountTables(ParsedSubject subject)`: the tables that query reads besides `dives`, for a change tick.

- [ ] **Step 1: Write the failing test**

`test/features/explore/data/explore_subject_counts_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ExploreRepository repo;
  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ExploreRepository(db: db);
  });
  tearDown(tearDownTestDatabase);

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: id,
          name: id,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> dive(
    String id, {
    String? siteId,
    String diverId = 'me',
    double depth = 10,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          siteId: Value(siteId),
          maxDepth: Value(depth),
          excludedFromStats: Value(excluded),
        ),
      );

  final deep = ConditionNode(
    FieldPath(const ['depth']),
    QueryOp.gte,
    const NumberValue(20, null),
  );

  setUp(() async {
    await diver('me');
    await diver('other');
  });

  test('counts the diver\'s counted dives per site in the scope', () async {
    await site('a');
    await site('b');
    await dive('1', siteId: 'a', depth: 30);
    await dive('2', siteId: 'a', depth: 25);
    await dive('3', siteId: 'a', depth: 5);
    await dive('4', siteId: 'b', depth: 40);
    // Excluded from statistics, and another diver's: neither counts.
    await dive('5', siteId: 'b', depth: 40, excluded: true);
    await dive('6', siteId: 'b', depth: 40, diverId: 'other');

    expect(
      await repo.diveCountsBySubject(ParsedSubject.sites, deep, diverId: 'me'),
      {'a': 2, 'b': 1},
    );
    expect(
      await repo.diveCountsBySubject(ParsedSubject.sites, null, diverId: 'me'),
      {'a': 3, 'b': 1},
    );
  });

  test('a buddy counts the dives they were on', () async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value('ana'),
            name: const Value('Ana'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await dive('1', depth: 30);
    await dive('2', depth: 5);
    for (final d in ['1', '2']) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('j$d'),
              diveId: Value(d),
              buddyId: const Value('ana'),
              createdAt: Value(now),
            ),
          );
    }
    expect(
      await repo.diveCountsBySubject(
        ParsedSubject.buddies,
        deep,
        diverId: 'me',
      ),
      {'ana': 1},
    );
  });

  test('an item linked twice on one dive counts that dive once', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'cyl',
            name: 'Cylinder',
            type: 'tank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('1');
    await db
        .into(db.diveEquipment)
        .insert(DiveEquipmentCompanion.insert(diveId: '1', equipmentId: 'cyl'));
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't',
            diveId: '1',
          ).copyWith(equipmentId: const Value('cyl')),
        );
    expect(
      await repo.diveCountsBySubject(
        ParsedSubject.equipment,
        null,
        diverId: 'me',
      ),
      {'cyl': 1},
    );
  });

  test('the tick tables name every table a count reads', () {
    expect(ExploreRepository.subjectCountTables(ParsedSubject.sites), isEmpty);
    expect(
      ExploreRepository.subjectCountTables(ParsedSubject.buddies),
      {'dive_buddies'},
    );
    expect(
      ExploreRepository.subjectCountTables(ParsedSubject.equipment),
      {'dive_equipment', 'dive_tanks'},
    );
    expect(
      ExploreRepository.subjectCountTables(ParsedSubject.species),
      {'sightings'},
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/explore/data/explore_subject_counts_test.dart`
Expected: FAIL, `diveCountsBySubject` is not defined.

- [ ] **Step 3: Implement the counts**

In `lib/features/explore/data/explore_repository.dart`, add the imports:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
```

and the methods:

```dart
  /// How a counted dive reaches a row of [subject]: a join (or none) and
  /// the row id it yields.
  static ({String join, String id}) _link(ParsedSubject subject) =>
      switch (subject) {
        ParsedSubject.sites => (join: '', id: 'd.site_id'),
        ParsedSubject.trips => (join: '', id: 'd.trip_id'),
        ParsedSubject.centers => (join: '', id: 'd.dive_center_id'),
        ParsedSubject.buddies => (
          join: 'JOIN dive_buddies j ON j.dive_id = d.id',
          id: 'j.buddy_id',
        ),
        ParsedSubject.species => (
          join: 'JOIN sightings s ON s.dive_id = d.id',
          id: 's.species_id',
        ),
        // The dive gear union: linked through dive_equipment, or a cylinder
        // matched through dive_tanks. UNION drops the pair both give.
        ParsedSubject.equipment => (
          join:
              'JOIN (SELECT dive_id, equipment_id FROM dive_equipment '
              'UNION SELECT dive_id, equipment_id FROM dive_tanks '
              'WHERE equipment_id IS NOT NULL) g ON g.dive_id = d.id',
          id: 'g.equipment_id',
        ),
        ParsedSubject.dives => throw ArgumentError.value(
          subject,
          'subject',
          'dives are counted by the dive queries',
        ),
      };

  /// The tables [diveCountsBySubject] reads besides `dives`.
  static Set<String> subjectCountTables(ParsedSubject subject) =>
      switch (subject) {
        ParsedSubject.buddies => const {'dive_buddies'},
        ParsedSubject.species => const {'sightings'},
        ParsedSubject.equipment => const {'dive_equipment', 'dive_tanks'},
        _ => const <String>{},
      };

  /// For each row of [subject] with a counted dive of [diverId] matching
  /// [diveScope], how many (descriptive, so the stats scope applies). The
  /// ranking and the one chart of a non-dive Explore answer read this.
  Future<Map<String, int>> diveCountsBySubject(
    ParsedSubject subject,
    QueryNode? diveScope, {
    String? diverId,
  }) async {
    final link = _link(subject);
    final f = buildFilteredDiveIdSubquery(DiveFilterState(query: diveScope));
    final params = <Object?>[];
    var where = '${link.id} IS NOT NULL ${DiveStatsScope.and(alias: 'd')}';
    if (diverId != null) {
      where += ' AND d.diver_id = ?';
      params.add(diverId);
    }
    if (f.subquery.isNotEmpty) {
      where += ' AND d.id IN (${f.subquery})';
      params.addAll(f.params);
    }
    final rows = await _db.customSelect('''
      SELECT ${link.id} AS id, COUNT(DISTINCT d.id) AS n
      FROM dives d ${link.join}
      WHERE $where
      GROUP BY ${link.id}
      ''', variables: params.map((p) => Variable(p)).toList()).get();
    return {for (final r in rows) r.read<String>('id'): r.read<int>('n')};
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/explore/data`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/explore/data/explore_repository.dart test/features/explore/data/explore_subject_counts_test.dart
git commit -m "feat(explore): count each row's dives in the scope, for ranking"
```

### Task 5: The subject's ranked rows

**Files:**
- Create: `lib/features/explore/presentation/providers/explore_subject_providers.dart`
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart`
- Test: `test/features/explore/presentation/providers/explore_subject_providers_test.dart`

**Interfaces:**
- Consumes: Task 3's `ExploreCompilation.subject`/`diveScope`; Task 4's `diveCountsBySubject`, `subjectCountTables`.
- Produces:
  - `exploreSubjectProvider = StateProvider<ParsedSubject>` (dives by default) and `exploreDiveScopeProvider = StateProvider<QueryNode?>`, both written by `ExploreQueryNotifier._publish` and reset by `_begin` and `clear`.
  - `exploreFilterProvider` yields `DiveFilterState(query: node)` only while the subject is dives, else an empty filter, so the dive results, count and charts stay empty for another subject.
  - `class ExploreSubjectRow { String id; String name; int dives; Object item; }`, `item` being the list's own row (`SiteWithDiveCount`, `EquipmentItem`, `BuddyWithDiveCount`, `SeenSpecies`, `TripWithStats` or `DiveCenter`).
  - `exploreSubjectCountsProvider = FutureProvider<Map<String, int>>`.
  - `exploreSubjectRowsProvider = Provider<AsyncValue<List<ExploreSubjectRow>>>`: the subject's rows the query selects, through each list's own id-set provider, ordered by dives in the scope (most first), then by name.

- [ ] **Step 1: Write the failing test**

`test/features/explore/presentation/providers/explore_subject_providers_test.dart`. Build the container exactly as `explore_providers_db_test.dart` does (`getBaseOverrides()`, `localeProvider` to `'en'`, `queryNameIndexProvider` to `NameIndex.empty`), plus `validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me')`.

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });
  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<void> site(
    String id, {
    String diverId = 'me',
    bool shared = false,
    double? rating,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          diverId: Value(diverId),
          isShared: Value(shared),
          rating: Value(rating),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> dive(String id, String siteId, {double depth = 10}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: const Value('me'),
          siteId: Value(siteId),
          maxDepth: Value(depth),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<ProviderContainer> container() async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...overrides,
        localeProvider.overrideWithValue('en'),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ].cast(),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<ExploreSubjectRow>> rows(ProviderContainer c) async {
    await c.read(exploreSubjectCountsProvider.future);
    for (var i = 0; i < 50; i++) {
      final v = c.read(exploreSubjectRowsProvider);
      if (v.hasValue) return v.value!;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('rows never loaded');
  }

  test('a subject alone ranks every row by its dives, then name', () async {
    await site('b');
    await site('a');
    await site('busy');
    await dive('1', 'busy');
    await dive('2', 'busy');
    await dive('3', 'b');
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;

    final r = await rows(c);
    expect(r.map((x) => x.id), ['busy', 'b', 'a']);
    expect(r.map((x) => x.dives), [2, 1, 0]);
  });

  test('the query narrows through the list and the scope ranks', () async {
    await site('good', rating: 5);
    await site('bad', rating: 1);
    await dive('1', 'good', depth: 30);
    await dive('2', 'good', depth: 5);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['rating']),
      QueryOp.gte,
      const NumberValue(4, null),
    );
    c.read(exploreDiveScopeProvider.notifier).state = ConditionNode(
      FieldPath(const ['depth']),
      QueryOp.gte,
      const NumberValue(20, null),
    );

    final r = await rows(c);
    expect(r.single.id, 'good');
    expect(r.single.dives, 1);
  });

  test("another diver's shared site is a result, as the list shows it", () async {
    await site('mine');
    await site('theirs', diverId: 'other', shared: true);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;

    expect((await rows(c)).map((x) => x.id).toSet(), {'mine', 'theirs'});
  });

  test('another subject leaves the dive providers empty', () async {
    await site('a');
    await dive('1', 'a', depth: 30);
    final c = await container();
    c.read(exploreSubjectProvider.notifier).state = ParsedSubject.sites;
    c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
      FieldPath(const ['maxDepth']),
      QueryOp.gte,
      const NumberValue(1, null),
    );
    expect(c.read(exploreFilterProvider).hasActiveFilters, isFalse);
    expect(await c.read(exploreResultsProvider.future), isEmpty);
  });

  test('publishing a parse sets the subject and the dive scope', () async {
    final c = await container();
    await c
        .read(exploreQueryProvider.notifier)
        .rerun(
          'buddies this year',
          const ParsedQuery(
            subject: ParsedSubject.buddies,
            time: QueryTime('this year'),
          ),
        );
    expect(c.read(exploreSubjectProvider), ParsedSubject.buddies);
    expect(c.read(exploreDiveScopeProvider), isA<AndNode>());

    c.read(exploreQueryProvider.notifier).clear();
    expect(c.read(exploreSubjectProvider), ParsedSubject.dives);
    expect(c.read(exploreDiveScopeProvider), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/explore/presentation/providers/explore_subject_providers_test.dart`
Expected: FAIL, `explore_subject_providers.dart` does not exist.

- [ ] **Step 3: Publish the subject and scope**

In `lib/features/explore/presentation/providers/explore_providers.dart`, beside `exploreQueryNodeProvider`:

```dart
/// What the published sentence asks for; dives until a sentence says
/// otherwise (phase 3).
final exploreSubjectProvider = StateProvider<ParsedSubject>(
  (ref) => ParsedSubject.dives,
);

/// For a non-dive subject, the dive-level part of the published sentence,
/// which its ranking counts.
final exploreDiveScopeProvider = StateProvider<QueryNode?>((ref) => null);

/// The scope as the dive repositories take it: the query alone, and only
/// while the subject is dives; another subject's query roots elsewhere.
final exploreFilterProvider = Provider<DiveFilterState>(
  (ref) => DiveFilterState(
    query: ref.watch(exploreSubjectProvider) == ParsedSubject.dives
        ? ref.watch(exploreQueryNodeProvider)
        : null,
  ),
);
```

(replacing the old `exploreFilterProvider`). In `ExploreQueryNotifier`, reset both in `_begin` and `clear` beside the query node:

```dart
    _ref.read(exploreQueryNodeProvider.notifier).state = null;
    _ref.read(exploreSubjectProvider.notifier).state = ParsedSubject.dives;
    _ref.read(exploreDiveScopeProvider.notifier).state = null;
```

and set them in `_publish`, before the query node so no listener sees a new node under the old subject:

```dart
    _ref.read(exploreSubjectProvider.notifier).state = compiled.subject;
    _ref.read(exploreDiveScopeProvider.notifier).state = compiled.diveScope;
    _ref.read(exploreQueryNodeProvider.notifier).state = compiled.query;
```

- [ ] **Step 4: Write the subject providers**

`lib/features/explore/presentation/providers/explore_subject_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// One row of a non-dive answer (phase 3): the list's own row [item], so
/// the list's own tile draws it, with its name and its dives in the scope.
class ExploreSubjectRow {
  final String id;
  final String name;
  final int dives;

  /// A `SiteWithDiveCount`, `EquipmentItem`, `BuddyWithDiveCount`,
  /// `SeenSpecies`, `TripWithStats` or `DiveCenter`, by the subject.
  final Object item;
  const ExploreSubjectRow({
    required this.id,
    required this.name,
    required this.dives,
    required this.item,
  });
}

/// Dives in the scope per row of the published subject, refreshed on a
/// write to any table the count reads.
final exploreSubjectCountsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final subject = ref.watch(exploreSubjectProvider);
  if (subject == ParsedSubject.dives) return const {};
  final scope = ref.watch(exploreDiveScopeProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final dives = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(
    dives.watchTables({
      'dives',
      ...diveFilterTablesTouched(DiveFilterState(query: scope)),
      ...ExploreRepository.subjectCountTables(subject),
    }),
  );
  return ref
      .watch(exploreRepositoryProvider)
      .diveCountsBySubject(subject, scope, diverId: diverId);
});

/// [items] as ranked rows: most dives in the scope first, then by name.
AsyncValue<List<ExploreSubjectRow>> _ranked<T extends Object>(
  AsyncValue<List<T>> items,
  AsyncValue<Map<String, int>> counts,
  String Function(T) idOf,
  String Function(T) nameOf,
) {
  if (items.hasError) {
    return AsyncValue.error(items.error!, items.stackTrace!);
  }
  if (counts.hasError) {
    return AsyncValue.error(counts.error!, counts.stackTrace!);
  }
  final list = items.value;
  final byId = counts.value;
  if (list == null || byId == null) return const AsyncValue.loading();
  final rows = [
    for (final t in list)
      ExploreSubjectRow(
        id: idOf(t),
        name: nameOf(t),
        dives: byId[idOf(t)] ?? 0,
        item: t,
      ),
  ];
  rows.sort((a, b) {
    final byDives = b.dives.compareTo(a.dives);
    return byDives != 0
        ? byDives
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return AsyncValue.data(rows);
}

/// The published subject's rows the query selects, ranked. Each subject is
/// narrowed the way its own list narrows it, so the rows are the ones a
/// handoff lands on: sites and trips keep shared and unowned rows,
/// equipment its owner scope and default status axis.
final exploreSubjectRowsProvider =
    Provider<AsyncValue<List<ExploreSubjectRow>>>((ref) {
      final subject = ref.watch(exploreSubjectProvider);
      final node = ref.watch(exploreQueryNodeProvider);
      final counts = ref.watch(exploreSubjectCountsProvider);
      switch (subject) {
        case ParsedSubject.dives:
          return const AsyncValue.data([]);
        case ParsedSubject.sites:
          return _ranked(
            narrowByIds(
              ref.watch(sitesWithCountsProvider),
              ref.watch(queryFilteredSiteIdsProvider(SiteFilterState(query: node))),
              (s) => s.site.id,
            ),
            counts,
            (s) => s.site.id,
            (s) => s.site.name,
          );
        case ParsedSubject.equipment:
          final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
          return _ranked(
            narrowByIds(
              ref.watch(allEquipmentProvider),
              ref.watch(
                queryFilteredEquipmentIdsProvider((
                  filter: EquipmentFilterState(query: node),
                  diverId: diverId,
                )),
              ),
              (e) => e.id,
            ),
            counts,
            (e) => e.id,
            (e) => e.name,
          );
        case ParsedSubject.trips:
          return _ranked(
            narrowByIds(
              ref.watch(allTripsWithStatsProvider),
              ref.watch(queryFilteredTripIdsProvider(TripFilterState(query: node))),
              (t) => t.trip.id,
            ),
            counts,
            (t) => t.trip.id,
            (t) => t.trip.name,
          );
        case ParsedSubject.buddies:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(allBuddiesWithDiveCountProvider),
              buddyQueryEntity,
              node,
              (b) => b.buddy.id,
            ),
            counts,
            (b) => b.buddy.id,
            (b) => b.buddy.name,
          );
        case ParsedSubject.centers:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(allDiveCentersProvider),
              diveCenterQueryEntity,
              node,
              (c) => c.id,
            ),
            counts,
            (c) => c.id,
            (c) => c.name,
          );
        case ParsedSubject.species:
          return _ranked(
            narrowByQuery(
              ref,
              ref.watch(seenSpeciesProvider),
              speciesQueryEntity,
              node,
              (s) => s.species.id,
            ),
            counts,
            (s) => s.species.id,
            (s) => s.species.commonName,
          );
      }
    });
```

`SiteFilterState` is declared in `site_providers.dart`, `TripFilterState` in `trip_providers.dart`, and `diveFilterTablesTouched` in `lib/features/dive_log/query/dive_filter_query.dart` (all imported above).

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/explore/presentation/providers test/architecture/provider_change_tick_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/explore/presentation/providers test/features/explore/presentation/providers/explore_subject_providers_test.dart
git commit -m "feat(explore): a non-dive subject's rows, narrowed by its own list and ranked"
```

### Task 6: The page for another subject

**Files:**
- Create: `lib/features/explore/presentation/widgets/explore_subject_results_list.dart`, `lib/features/explore/presentation/widgets/explore_handoff_bar.dart`
- Modify: `lib/features/explore/presentation/pages/explore_page.dart`, `lib/features/explore/presentation/widgets/explore_chip_rows.dart`, `lib/features/explore/presentation/widgets/explore_charts.dart`, `lib/features/explore/presentation/chip_labeler.dart`, `lib/features/explore/presentation/providers/explore_providers.dart` (the chart switch)
- Modify: the 11 ARB files and the generated l10n
- Test: `test/features/explore/presentation/pages/explore_page_subjects_test.dart`, `test/features/explore/presentation/chip_labeler_test.dart`

**Interfaces:**
- Consumes: Task 5's `exploreSubjectProvider`, `exploreQueryNodeProvider`, `exploreSubjectRowsProvider`, `ExploreSubjectRow`; Task 3's `QueryChip.viaDives`, `ChartKind.subjectCounts`, reason `countInPeriod`; Task 2's `rootOf`, `ExploreField.root`, `ExploreValueKind.days`.
- Produces:
  - `ChipLabeler(AppLocalizations l10n, UnitFormatter units, {QueryLabels? queryLabels})` and `String chipLabel(QueryChip chip)`.
  - `ExploreSubjectResultsList({required ParsedSubject subject})`, `ExploreHandoffBar({required ParsedSubject subject})`.
  - ARB keys: `explore_chip_viaDives(label)`, `explore_chip_withinDays(days, field)`, `explore_chip_fieldPeriod(field, period)`, `explore_unplaced_reason_countInPeriod`, `explore_results_count(count)`, `explore_handoff_list`. Removed: `explore_subjectNotSupported`.

- [ ] **Step 1: Add the strings**

| Key | English | Placeholders |
| --- | --- | --- |
| `explore_chip_viaDives` | `Dives: {label}` | `label` (String) |
| `explore_chip_withinDays` | `{days, plural, =1{{field} within 1 day} other{{field} within {days} days}}` | `days` (int), `field` (String) |
| `explore_chip_fieldPeriod` | `{field}: {period}` | `field`, `period` (String) |
| `explore_unplaced_reason_countInPeriod` | `Counting within a period is not supported yet` | none |
| `explore_results_count` | `{count, plural, =1{1 result} other{{count} results}}` | `count` (int) |
| `explore_handoff_list` | `Open in list` | none |

Insert beside the existing `explore_*` keys in all 11 files, translate into the ten other locales (no em-dash, no " - "; German keeps its own phrasing for "Dives"), and delete `explore_subjectNotSupported` from all 11. Run `flutter gen-l10n`. The generated methods take placeholders alphabetically: `explore_chip_withinDays(days, field)`, `explore_chip_fieldPeriod(field, period)`.

- [ ] **Step 2: Write the failing chip labeler tests**

Append to `test/features/explore/presentation/chip_labeler_test.dart` (it already builds a `ChipLabeler` from `AppLocalizationsEn` and a `UnitFormatter`; reuse its `labeler`):

```dart
  group('phase 3 subjects', () {
    test('every subject field has a registry label', () {
      for (final f in kExploreSubjectFields.values.expand((l) => l)) {
        final name = labeler.fieldName(f);
        expect(name, isNot(f.field!.labelKey), reason: f.name);
        expect(name, isNot(f.name), reason: f.name);
      }
    });

    test('a date field reads as a period', () {
      final f = exploreFieldFor(ParsedSubject.sites, 'lastDived')!.field;
      final label = labeler.label(
        ClauseChip(
          field: f,
          op: ClauseOp.lt,
          value: (start: DateTime(2022), end: DateTime(2022, 12, 31)),
          dimension: FieldDimension.none,
        ),
      );
      expect(label, startsWith('${labeler.fieldName(f)}: '));
      expect(label, contains('2022'));
    });

    test('a due window reads in days', () {
      final f = exploreFieldFor(ParsedSubject.equipment, 'serviceDueWithin')!
          .field;
      final label = labeler.label(
        ClauseChip(
          field: f,
          op: ClauseOp.lte,
          value: 30,
          dimension: FieldDimension.none,
        ),
      );
      expect(label, contains('30 days'));
    });

    test('a chip about the dives says so', () {
      final chip = QueryChip(
        ref: ChipRef.time,
        index: 0,
        payload: TimeChip(start: DateTime(2026)),
        viaDives: true,
      );
      expect(labeler.chipLabel(chip), startsWith('Dives: '));
    });
  });
```

- [ ] **Step 3: Write the failing page test**

`test/features/explore/presentation/pages/explore_page_subjects_test.dart`, using the same imports and helpers as `explore_page_test.dart` (`getBaseOverrides` from `helpers/mock_providers.dart`, `testAppRouter` from `helpers/test_app.dart`):

```dart
class _Engine implements NlEngine {
  _Engine(this.json);
  final String json;
  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;
  @override
  Future<void> prepare() async {}
  @override
  Stream<double> download() => const Stream.empty();
  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      json;
}

void main() {
  final t = DateTime(2026, 1, 1);
  final ana = ExploreSubjectRow(
    id: 'b1',
    name: 'Ana',
    dives: 3,
    item: BuddyWithDiveCount(
      buddy: Buddy(id: 'b1', name: 'Ana', createdAt: t, updatedAt: t),
      diveCount: 3,
    ),
  );

  String parse(String body) =>
      '{"schemaVersion":$kQuerySchemaVersion,"subject":"buddies",$body,'
      '"mentions":[],"unplaced":[]}';

  Future<ProviderContainer> pump(WidgetTester tester, String json) async {
    final router = GoRouter(
      initialLocation: '/dives/explore',
      routes: [
        GoRoute(path: '/dives/explore', builder: (_, _) => const ExplorePage()),
        GoRoute(path: '/buddies', builder: (_, _) => const Text('buddy list')),
        GoRoute(
          path: '/buddies/:id',
          builder: (_, s) => Text('buddy ${s.pathParameters['id']}'),
        ),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          nlEngineProvider.overrideWithValue(_Engine(json)),
          explorePlatformSupportedProvider.overrideWithValue(true),
          localeProvider.overrideWithValue('en'),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          recentQueryRecorderProvider.overrideWithValue((s, l, p) async {}),
          recentQueriesProvider.overrideWith((ref) async => const []),
          exploreSubjectCountsProvider.overrideWith((ref) async => const {}),
          exploreSubjectRowsProvider.overrideWithValue(AsyncValue.data([ana])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ExplorePage)));
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('explore-sentence')),
      'my favourite buddies',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('a buddies answer: subject chip, rows, count and handoff', (
    tester,
  ) async {
    final c = await pump(
      tester,
      parse(
        '"clauses":[{"field":"favorite","op":"eq","value":true,'
        '"text":"favourite"}],"time":null',
      ),
    );
    await ask(tester);

    expect(find.byKey(const ValueKey('explore-subject-chip')), findsOneWidget);
    expect(find.text('Buddies'), findsWidgets);
    expect(find.text('1 result'), findsOneWidget);
    expect(find.byKey(const ValueKey('explore-row-b1')), findsOneWidget);
    expect(find.text('Open in dive list'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('explore-handoff-list')));
    await tester.pumpAndSettle();
    expect(c.read(buddyQueryProvider), isNotNull);
    expect(find.text('buddy list'), findsOneWidget);
  });

  testWidgets('a period under buddies is a chip about the dives', (
    tester,
  ) async {
    await pump(tester, parse('"clauses":[],"time":{"text":"this year"}'));
    await ask(tester);
    expect(find.textContaining('Dives: '), findsOneWidget);
    expect(find.text('Dives per buddy'), findsOneWidget);
  });

  testWidgets('a subject alone offers no handoff', (tester) async {
    await pump(tester, parse('"clauses":[],"time":null'));
    await ask(tester);
    expect(find.byKey(const ValueKey('explore-handoff-list')), findsNothing);
    expect(find.byKey(const ValueKey('explore-row-b1')), findsOneWidget);
  });

  testWidgets('a row opens its detail page', (tester) async {
    await pump(tester, parse('"clauses":[],"time":null'));
    await ask(tester);
    await tester.tap(find.byKey(const ValueKey('explore-row-b1')));
    await tester.pumpAndSettle();
    expect(find.text('buddy b1'), findsOneWidget);
  });
}
```

`'Buddies'` is `query_entity_buddies` and `'Dives per buddy'` is `explore_chart_entityCounts` with `explore_kind_buddy`.

- [ ] **Step 4: Run both tests to verify they fail**

Run: `flutter test test/features/explore/presentation/chip_labeler_test.dart test/features/explore/presentation/pages/explore_page_subjects_test.dart`
Expected: FAIL, `chipLabel`, the new widgets and the ARB methods do not exist.

- [ ] **Step 5: Label the new chips**

In `lib/features/explore/presentation/chip_labeler.dart`, import `package:submersion/core/query/domain/query_subject.dart` and `package:submersion/core/query/presentation/query_labels.dart`, and:

```dart
class ChipLabeler {
  ChipLabeler(this.l10n, this.units, {this.queryLabels});
  final AppLocalizations l10n;
  final UnitFormatter units;

  /// The query language's labels, for another subject's enum values. The
  /// understood row passes `AppQueryLabels(context)`.
  final QueryLabels? queryLabels;

  /// A chip as the understood row shows it: a chip about the subject's
  /// dives says so.
  String chipLabel(QueryChip chip) {
    final text = label(chip.payload);
    return chip.viaDives ? l10n.explore_chip_viaDives(text) : text;
  }
```

At the top of `fieldName`, before the dive switch:

```dart
    // A phase 3 subject's own field reads as the registry labels it.
    if (f.root != QuerySubject.dives) {
      return queryLabelForKey(l10n, f.field!.labelKey);
    }
```

At the top of `_enumValue`:

```dart
    if (field.root != QuerySubject.dives) {
      return queryLabels?.enumValue(field.field!, v) ?? v;
    }
```

At the top of `_clause`, after `final name = fieldName(c.field);`:

```dart
    if (c.field.kind == ExploreValueKind.days) {
      return l10n.explore_chip_withinDays(c.value as int, name);
    }
    if (c.value case (start: final DateTime? start, end: final DateTime? end)) {
      final period = switch (c.op) {
        // Before the period: before its first day.
        ClauseOp.lt || ClauseOp.lte => l10n.explore_chip_timeBefore(
          units.formatDate(start!),
        ),
        // After the period: from the day after its last.
        ClauseOp.gt || ClauseOp.gte => l10n.explore_chip_timeSince(
          units.formatDate(DateTime(end!.year, end.month, end.day + 1)),
        ),
        _ => _time(start, end),
      };
      return l10n.explore_chip_fieldPeriod(name, period);
    }
```

- [ ] **Step 6: Show the subject chip and the dive-scope labels**

In `lib/features/explore/presentation/widgets/explore_chip_rows.dart`, import `app_query_labels.dart` and `explore_subject_fields.dart`. `ExploreUnderstoodRow.build`:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = AppQueryLabels(context);
    final labeler = ChipLabeler(
      context.l10n,
      UnitFormatter(ref.watch(settingsProvider)),
      queryLabels: labels,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.explore_understood_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // What the sentence asks for comes first, and stays: the model
            // chose it, and it is not a filter the diver can drop.
            Chip(
              key: const ValueKey('explore-subject-chip'),
              avatar: const Icon(Icons.search, size: 16),
              label: Text(labels.entity(rootOf(compiled.subject))),
            ),
            for (final chip in compiled.chips)
              InputChip(
                label: Text(labeler.chipLabel(chip)),
                onDeleted: () =>
                    ref.read(exploreQueryProvider.notifier).removeChip(chip),
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      ],
    );
  }
```

(The row is no longer hidden when there are no chips: the subject chip is always there.) In `ExploreAttentionRow._reason`, replace the `'subjectNotSupported'` arm with:

```dart
        'countInPeriod' => l10n.explore_unplaced_reason_countInPeriod,
```

- [ ] **Step 7: Write the subject results and the handoff bar**

`lib/features/explore/presentation/widgets/explore_subject_results_list.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A non-dive answer's rows, each drawn by its own list's tile and opening
/// its own detail page. Ranked by dives in the scope (the provider's order).
class ExploreSubjectResultsList extends ConsumerWidget {
  const ExploreSubjectResultsList({super.key, required this.subject});
  final ParsedSubject subject;

  /// As many rows as the dive results show.
  static const _shown = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(exploreSubjectRowsProvider);
    return rows.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      // The providers log the cause; the diver gets a sentence.
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.common_error_tryAgain),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.explore_results_title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final row in list.take(_shown))
            KeyedSubtree(
              key: ValueKey('explore-row-${row.id}'),
              child: _tile(context, ref, row),
            ),
          if (list.length > _shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.l10n.explore_results_truncated(_shown),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ExploreSubjectRow row) {
    void open(String route) => context.push('$route/${row.id}');
    return switch (subject) {
      ParsedSubject.sites => SiteListTile(
        entry: row.item as SiteWithDiveCount,
        onTap: () => open('/sites'),
      ),
      ParsedSubject.equipment => EquipmentListTile(
        item: row.item as EquipmentItem,
        onTap: () => open('/equipment'),
      ),
      ParsedSubject.buddies => BuddyListTile(
        entry: row.item as BuddyWithDiveCount,
        onTap: () => open('/buddies'),
      ),
      ParsedSubject.species => SeenSpeciesTile(
        entry: row.item as SeenSpecies,
        cover: ref.watch(speciesCoverMediaProvider).value?[row.id],
        onTap: () => open('/species'),
      ),
      ParsedSubject.trips => TripListTile(
        tripWithStats: row.item as TripWithStats,
        onTap: () => open('/trips'),
      ),
      ParsedSubject.centers => DiveCenterListTile(
        center: row.item as DiveCenter,
        onTap: () => open('/dive-centers'),
      ),
      ParsedSubject.dives => const SizedBox.shrink(),
    };
  }
}
```

`lib/features/explore/presentation/widgets/explore_handoff_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the answer goes next: the dive list or Statistics for dives, the
/// subject's own list otherwise, each shown the published query as its own
/// chips. Nothing to hand off when the sentence placed no condition.
class ExploreHandoffBar extends ConsumerWidget {
  const ExploreHandoffBar({super.key, required this.subject});
  final ParsedSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(exploreQueryNodeProvider);
    if (node == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    if (subject == ParsedSubject.dives) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // The published query alone, which the dive list shows as
                // query chips: the live scope, so the handoff stays right if
                // anything else ever writes it.
                ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                  query: ref.read(exploreQueryNodeProvider),
                );
                // go, not push: the handoff moves to a shell tab.
                context.go('/dives');
              },
              child: Text(l10n.explore_handoff_diveList),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                ref.read(insightsFilterProvider.notifier).state =
                    DiveFilterState(query: ref.read(exploreQueryNodeProvider));
                context.go('/insights');
              },
              child: Text(l10n.explore_handoff_insights),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('explore-handoff-list'),
        onPressed: () => context.go(_handoff(ref, node)),
        child: Text(l10n.explore_handoff_list),
      ),
    );
  }

  /// Writes [node] as the subject's list query and returns the list's
  /// route. The list's other axes start clear, so its chips show exactly
  /// what Explore understood.
  String _handoff(WidgetRef ref, QueryNode node) {
    switch (subject) {
      case ParsedSubject.sites:
        ref.read(siteFilterProvider.notifier).state = SiteFilterState(
          query: node,
        );
        return '/sites';
      case ParsedSubject.equipment:
        ref.read(equipmentFilterProvider.notifier).state = EquipmentFilterState(
          query: node,
        );
        return '/equipment';
      case ParsedSubject.buddies:
        ref.read(buddyQueryProvider.notifier).state = node;
        return '/buddies';
      case ParsedSubject.species:
        ref.read(seenSpeciesQueryProvider.notifier).state = node;
        return '/species';
      case ParsedSubject.trips:
        ref.read(tripFilterProvider.notifier).state = TripFilterState(
          query: node,
        );
        return '/trips';
      case ParsedSubject.centers:
        ref.read(diveCenterQueryProvider.notifier).state = node;
        return '/dive-centers';
      case ParsedSubject.dives:
        throw StateError('dives hand off through their own buttons');
    }
  }
}
```

- [ ] **Step 8: Wire the page and the chart**

In `lib/features/explore/presentation/pages/explore_page.dart`:
- The count line: `compiled.subject == ParsedSubject.dives ? l10n.explore_count(count.value ?? 0) : l10n.explore_results_count(ref.watch(exploreSubjectRowsProvider).value?.length ?? 0)`.
- The results: `compiled.subject == ParsedSubject.dives ? const ExploreResultsList() : ExploreSubjectResultsList(subject: compiled.subject)`.
- Replace the bottom `SafeArea(... Row(...))` block with `if (compiled != null) SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: ExploreHandoffBar(subject: compiled.subject)))`, removing the now-unused `DiveFilterState`/`diveFilterProvider`/`insightsFilterProvider` imports if the analyzer flags them.

In `lib/features/explore/presentation/providers/explore_providers.dart`, the chart switch gains:

```dart
          // Drawn from the ranked rows (explore_charts.dart), never here.
          case ChartKind.subjectCounts:
            return const ExploreChartData();
```

In `lib/features/explore/presentation/widgets/explore_charts.dart`, import `explore_subject_providers.dart` and `query_model.dart`. In `_ExploreChartCard.build`, before `final data = ...`:

```dart
    if (request.kind == ChartKind.subjectCounts) {
      final subject = ref.watch(exploreSubjectProvider);
      final rows = ref.watch(exploreSubjectRowsProvider).value ?? const [];
      final bars = [
        for (final r in rows.take(10))
          if (r.dives > 0) (label: r.name, count: r.dives),
      ];
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.explore_chart_entityCounts(_subjectKind(l10n, subject)),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              HorizontalCategoryBarChart(data: bars),
            ],
          ),
        ),
      );
    }
```

and the title switch gains `ChartKind.subjectCounts => ''` (unreachable). Add:

```dart
  static String _subjectKind(AppLocalizations l10n, ParsedSubject s) =>
      switch (s) {
        ParsedSubject.sites => l10n.explore_kind_site,
        ParsedSubject.equipment => l10n.explore_kind_gear,
        ParsedSubject.buddies => l10n.explore_kind_buddy,
        ParsedSubject.species => l10n.explore_kind_species,
        ParsedSubject.trips => l10n.explore_kind_trip,
        ParsedSubject.centers => l10n.explore_kind_center,
        ParsedSubject.dives => '',
      };
```

(`l10n` must be read before the new early return.)

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/explore test/l10n test/architecture`
Expected: PASS, including the existing `explore_page_test.dart` (the dive handoffs moved into `ExploreHandoffBar` unchanged).

- [ ] **Step 10: Commit**

```bash
git add lib/features/explore lib/l10n test/features/explore
git commit -m "feat(explore): show another subject's answer, ranked, with a handoff to its list"
```

### Task 7: A visible query filter on the trip list

The spec forbids a handoff to a list whose filter is invisible, and the trip list has a query slot (`TripFilterState.query`) but no chips and no filter button. This copies the courses list, which has the same shape (a filter state holding a `query`).

**Files:**
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`, `lib/features/trips/presentation/widgets/trip_list_content.dart`, `lib/features/trips/presentation/pages/trip_list_page.dart`
- Test: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Interfaces:**
- Produces: `void setTripQuery(WidgetRef ref, QueryNode? query)` beside `tripFilterProvider`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/trips/presentation/widgets/trip_list_content_test.dart` (it has `_buildOverrides`, table mode, and `_buildPhoneOverrides`, phone mode; add `tripFilterProvider.overrideWith((ref) => ...)` to a copy of the list they return):

```dart
  group('query filter (#2365, Explore phase 3)', () {
    final liveaboard = ConditionNode(
      FieldPath(const ['tripType']),
      QueryOp.inList,
      ListValue(const [EnumValue('liveaboard')]),
    );

    testWidgets('an active query shows its chips above the trips', (
      tester,
    ) async {
      final overrides = [
        ...await _buildOverrides(
          trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
        ),
        tripFilterProvider.overrideWith(
          (ref) => TripFilterState(query: liveaboard),
        ),
      ];
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();
      final frame = tester.widget<QueryChipsFrame>(
        find.byType(QueryChipsFrame),
      );
      expect(frame.query, liveaboard);
    });

    testWidgets('a query that keeps nothing blames the query', (tester) async {
      final overrides = [
        ...await _buildOverrides(trips: []),
        tripFilterProvider.overrideWith(
          (ref) => TripFilterState(query: liveaboard),
        ),
      ];
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });

    testWidgets('the phone app bar offers the query filter', (tester) async {
      final overrides = await _buildPhoneOverrides(
        trips: [_makeTrip(id: 't1', name: 'Bali Dive Trip')],
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const TripListContent(showAppBar: true),
        ),
      );
      await tester.pump();
      expect(find.byType(QueryFilterButton), findsOneWidget);
    });
  });
```

Imports to add: `query_node.dart`, `query_value.dart`, `package:submersion/features/query/presentation/widgets/query_chips_frame.dart`, `package:submersion/features/query/presentation/widgets/query_filter_sheet.dart`. If `_buildPhoneOverrides` already overrides `tripFilterProvider`, the third test needs nothing more.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart`
Expected: FAIL, no `QueryChipsFrame`, `QueryNoMatchState` or `QueryFilterButton` in the trip list.

- [ ] **Step 3: Add the setter**

In `lib/features/trips/presentation/providers/trip_providers.dart`, below `tripFilterProvider`:

```dart
/// Replaces the trip list's query (#2365), keeping its equipment axis.
void setTripQuery(WidgetRef ref, QueryNode? query) {
  final notifier = ref.read(tripFilterProvider.notifier);
  notifier.state = notifier.state.copyWith(
    query: query,
    clearQuery: query == null,
  );
}
```

- [ ] **Step 4: Wire the list**

In `lib/features/trips/presentation/widgets/trip_list_content.dart`, import `query_node.dart`, `query_subject.dart`, `package:submersion/features/trips/query/trip_query_entity.dart`, `query_chips_frame.dart` and `query_filter_sheet.dart`, and add to the state class:

```dart
  void _setQuery(QueryNode? query) => setTripQuery(ref, query);

  void _openQueryFilter() => showQueryFilterSheet(
    context,
    subject: QuerySubject.trips,
    root: tripQueryEntity,
    initial: ref.read(tripFilterProvider).query,
    onApply: setTripQuery,
  );

  /// The list body with the query's chips above it (#2365).
  Widget _withQueryChips(Widget child) => QueryChipsFrame(
    root: tripQueryEntity,
    query: ref.watch(tripFilterProvider).query,
    onChanged: _setQuery,
    child: child,
  );
```

Then:
- In `build`, wrap the list body: `Expanded(child: _withQueryChips(buildContent()))` in the compact branch, and `body: _withQueryChips(buildContent())` (or the body's existing wrapper) in the phone `Scaffold`.
- In `_buildTableModeScaffold`, wrap the table the same way: `_withQueryChips(_buildTableView(context, tripsAsync, filter))`.
- In the phone `AppBar.actions`, after the sort button: `QueryFilterButton(active: ref.watch(tripFilterProvider).query != null, onPressed: _openQueryFilter)`.
- In `_buildCompactAppBar`, after its sort button: `QueryFilterButton(active: ref.watch(tripFilterProvider).query != null, compact: true, onPressed: _openQueryFilter)`.
- The equipment bar shows only for the equipment axis now that the query has its own chips: call `_buildTripList(context, ref, trips, filter.equipmentId != null)` and, in `_buildTableView`, `if (filter.equipmentId != null) _buildActiveFiltersBar(context, ref)`.
- At the top of `_buildEmptyState`: `if (ref.watch(tripFilterProvider).query != null) return QueryNoMatchState(onClear: () => _setQuery(null));`.

In `lib/features/trips/presentation/pages/trip_list_page.dart`, the table mode's `appBarActions`, after the sort button, as the courses page does:

```dart
            Consumer(
              builder: (context, ref, _) => QueryFilterButton(
                active: ref.watch(tripFilterProvider).query != null,
                compact: true,
                onPressed: () => showQueryFilterSheet(
                  context,
                  subject: QuerySubject.trips,
                  root: tripQueryEntity,
                  initial: ref.read(tripFilterProvider).query,
                  onApply: setTripQuery,
                ),
              ),
            ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/trips`
Expected: PASS.

- [ ] **Step 6: Capture the screenshots**

Run the app (macOS desktop, then a phone-width window), open Trips, apply a query (Trip type is Liveaboard) through the new filter button, and capture: the trip list before this change (from `main`), after with the filter button, and after with a query's chips, at phone and desktop widths. Save them outside the repository for the PR description.

- [ ] **Step 7: Commit**

```bash
git add lib/features/trips test/features/trips
git commit -m "feat(trips): a visible query filter on the trip list"
```

### Task 8: The prompt, the vocabulary and schema version 3

**Files:**
- Modify: `lib/features/explore/domain/nl_engine.dart`, `lib/features/explore/domain/query_model.dart`
- Test: `test/features/explore/domain/nl_prompt_test.dart`, `test/features/explore/domain/query_model_test.dart`

**Interfaces:**
- Consumes: Task 2's `exploreFieldNames`, `exploreFieldFor`, `kExploreSubjectFields`.
- Produces: `kQuerySchemaVersion == 3` (`kMinReadableQuerySchemaVersion` stays 1); `NlPrompt.vocabulary()['fields'] == exploreFieldNames()`.

- [ ] **Step 1: Write the failing tests**

In `test/features/explore/domain/nl_prompt_test.dart`, change the vocabulary expectation and add:

```dart
    expect(v['fields'], exploreFieldNames());
```

```dart
  test('the prompt names every subject field and lists its values', () {
    final text = NlPrompt.instructions();
    for (final entry in kExploreSubjectFields.entries) {
      expect(text, contains('${entry.key.name}:'), reason: entry.key.name);
      for (final f in entry.value) {
        expect(text, contains(f.name), reason: f.name);
        for (final v in f.enumValues ?? const <String>[]) {
          expect(text, contains(v), reason: '${f.name} $v');
        }
      }
    }
  });

  test('every example compiles with nothing left over but its own words', () {
    final text = NlPrompt.instructions();
    // An example line starts `{"schemaVersion":3`; the shape line has a
    // space after the colon and `[...]` placeholders, so it never matches.
    final examples = RegExp(r'^\{"schemaVersion":\d.*\}$', multiLine: true)
        .allMatches(text)
        .map((m) => ParsedQuery.fromJson(jsonDecode(m[0]!) as Map<String, Object?>))
        .toList();
    expect(examples.map((e) => e.subject), contains(ParsedSubject.sites));
    expect(examples.map((e) => e.subject), contains(ParsedSubject.equipment));
    for (final e in examples) {
      for (final c in e.clauses) {
        expect(exploreFieldFor(e.subject, c.field), isNotNull, reason: c.field);
      }
    }
  });
```

(import `dart:convert` and `explore_subject_fields.dart`). The budget test stays as it is: under 7,000.

In `test/features/explore/domain/query_model_test.dart`, add:

```dart
  test('version 2 payloads still parse under version 3', () {
    final q = ParsedQuery.fromJson({
      'schemaVersion': 2,
      'subject': 'dives',
      'clauses': const [],
    });
    expect(q.subject, ParsedSubject.dives);
    expect(kQuerySchemaVersion, 3);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/explore/domain/nl_prompt_test.dart test/features/explore/domain/query_model_test.dart`
Expected: FAIL, the vocabulary lists dive fields only and the version is 2.

- [ ] **Step 3: Bump the schema**

In `lib/features/explore/domain/query_model.dart`:

```dart
const int kQuerySchemaVersion = 3;

/// The oldest schema version a stored or model-written parse may carry.
/// Versions 2 and 3 only added fields and units (3: each subject's own
/// fields, phase 3), so every older payload is a valid current one and a
/// diver's recent sentences survive the bumps.
const int kMinReadableQuerySchemaVersion = 1;
```

- [ ] **Step 4: Extend the prompt**

In `lib/features/explore/domain/nl_engine.dart`, import `explore_subject_fields.dart`. The vocabulary's fields:

```dart
    'fields': exploreFieldNames(),
```

Add a helper beside `_oneOf`:

```dart
  /// A subject field's values as prose, like [_oneOf].
  static String _oneOfFor(ParsedSubject subject, String name) {
    final values = exploreFieldFor(subject, name)!.field.enumValues!;
    return '${values.take(values.length - 1).join(', ')} or ${values.last}';
  }
```

In `instructions()`:
- The shape line's `"subject": "dives"` becomes `"subject": "..."`.
- The subject line becomes: `subject is one of: dives, equipment, sites, buddies, species, trips, centers. Use "dives" unless the sentence asks for the sites, gear, buddies, species, trips or dive centers themselves; "turtles in Bonaire" is still dives.`
- After the dive field glossary paragraph, insert:

```
Under another subject these are its own fields, and any dive field above describes its dives. A time field takes a time phrase from the shapes below as its value; lt means before, gt after.
sites: depth (the site's deepest point), rating, difficulty: ${_oneOfFor(ParsedSubject.sites, 'difficulty')}, diveCount (times dived there), lastDived (time field).
equipment: gearType: ${_oneOfFor(ParsedSubject.equipment, 'gearType')}. gearStatus: ${_oneOfFor(ParsedSubject.equipment, 'gearStatus')}. serviceDue: ${_oneOfFor(ParsedSubject.equipment, 'serviceDue')}. serviceDueWithin: days until service is due. diveCount (dives used on), lastDived (last used, time field).
buddies: favorite: true. diveCount (dives together), lastDived (time field).
species: speciesCategory: ${_oneOfFor(ParsedSubject.species, 'speciesCategory')}. diveCount (dives it was seen on), firstSeen and lastSeen (time fields).
trips: tripType: ${_oneOfFor(ParsedSubject.trips, 'tripType')}. diveCount. A time phrase is when the trip took place.
centers: rating, diveCount (dives with them), lastDived (time field).
```

- After Example 3, add:

```
Example 4
Sentence: Sites in Bonaire I have not dived since 2022
{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"lastDived","op":"lt","value":"2022","text":"not dived since 2022"}],"mentions":[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":[]}

Example 5
Sentence: Regulators due for service in the next 30 days
{"schemaVersion":$kQuerySchemaVersion,"subject":"equipment","clauses":[{"field":"gearType","op":"eq","value":"regulator","text":"Regulators"},{"field":"serviceDueWithin","op":"lte","value":30,"text":"due for service in the next 30 days"}],"mentions":[],"time":null,"unplaced":[]}
```

- [ ] **Step 5: Measure the prompt**

Run: `flutter test test/features/explore/domain/nl_prompt_test.dart` and, in a scratch test or `dart run`, print `NlPrompt.instructions().length`.
Expected: under 6,500. If it is over, shorten in this order: drop the parenthetical glosses on `diveCount`, then drop Example 5. Record the measured length in the Task 9 deviations note.

- [ ] **Step 6: Run the Explore tests**

Run: `flutter test test/features/explore`
Expected: PASS (`explore_page_subjects_test.dart` builds its JSON with `$kQuerySchemaVersion`, so the bump reaches it).

- [ ] **Step 7: Commit**

```bash
git add lib/features/explore/domain/nl_engine.dart lib/features/explore/domain/query_model.dart test/features/explore/domain/nl_prompt_test.dart test/features/explore/domain/query_model_test.dart
git commit -m "feat(explore): the prompt names every subject's fields; schema version 3"
```

### Task 9: Whole-project verification, the spec, and the pull request

**Files:**
- Modify: `docs/design/specs/2026-09-19-explore-natural-language-search-design.md`

- [ ] **Step 1: Record the phase 3 deviations in the spec**

Append a section `## Phase 3 deviations (2026-09-30)` after the phase 2 deviations, one bullet each:
- The subjects lower onto the shared query registries (#2365), not onto per-subject filter states: `EquipmentFilterState`, `SiteFilterState` and the rest already hold a query, and the new `BuddyFilterState`/`DiveCenterFilterState` the table named were never needed.
- Aggregates are registry fields (`diveCount`, `lastDived`, species `firstSeen`/`lastSeen`, equipment `nextServiceDue`), stats-scoped, across every diver, as the site list counts.
- Another kind's mention, a dive field or a period under a non-dive subject lowers through the subject's counted dives; trips read a period as their own dates.
- Results are ranked by the active diver's dives in the scope; "who have I dived with most" is answered by that order and the count chart, not by a sort in the schema.
- A count with a period is unplaced (`countInPeriod`), since a count over a scoped relation is out of the query language's scope.
- An own-kind mention matches by stored name; there is no id field.
- `dueWithinDays` is `serviceDueWithin`, a date bound from `equipment_service_status.due_date`; `lastUsedBefore/After` are `lastDived` with a time phrase; `favoritesOnly` is buddies' `favorite`; `roleId`, `firstSeenAfter` as a separate axis, `endBefore`/`startAfter`, `location`, and centers' `country`/`city` are reached through a place mention or omitted.
- The trip list gained a visible query filter so its handoff shows its chips.
- The schema went to version 3 with version 1 still readable; the prompt measured N characters (from Task 8).

- [ ] **Step 2: Format, analyze, and the full suite**

Run: `dart format .`
Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test test/architecture test/features/query test/features/explore test/features/trips test/l10n`
Then the full suite (one run, `scripts/run_all_tests.sh` or `flutter test`), checking `df -h /Volumes/fltmp` first if the local TMPDIR is the RAM disk.
Expected: all pass.

- [ ] **Step 3: Commit the spec**

```bash
git add docs/design/specs/2026-09-19-explore-natural-language-search-design.md
git commit -m "docs(explore): record the phase 3 deviations"
```

- [ ] **Step 4: Push and open the pull request**

The PR description says `Closes #2195`, lists the six subjects and their fields, explains the dive scope and the ranking, names the four "confirm in review" decisions from this plan, notes schema version 3 (older recent queries still parse), and carries the trip list screenshots from Task 7 (before and after, phone and desktop). It repeats that the on-device model's behaviour on real hardware (Apple Foundation Models, Gemini Nano) is an owed manual check, including that the model picks the right subject and the subject's own fields.

---

## Self-review notes

- **Spec coverage.** Each subject in the spec's phase 3 table has fields (Task 2), a lowering (Task 3), a result widget and a handoff (Task 6). Mentions reuse the one `NameIndex` (Task 3). The single count-per-entity chart is `ChartKind.subjectCounts` (Tasks 3 and 6). The sealed dispatch is `ExploreCompiler.compile`'s split plus exhaustive switches over `ParsedSubject` in Tasks 4, 5 and 6, so a new subject is a compile error. The spec's example sentences are the Task 3 tests. What the table named that this plan does not build is listed in Task 9's deviations.
- **Types.** `ExploreSubjectRow`, `exploreSubjectRowsProvider`, `exploreSubjectCountsProvider`, `exploreSubjectProvider`, `exploreDiveScopeProvider`, `diveCountsBySubject`, `subjectCountTables`, `exploreFieldFor`, `exploreFieldNames`, `rootOf`, `kExploreSubjectFields`, `ownsTarget`, `lowerOwnMentions`, `lowerTripTime`, `countedDives`, `ChartKind.subjectCounts`, `QueryChip.viaDives`, `ChipLabeler.chipLabel` are spelled the same in every task that uses them.
- **Known soft spots.** Drift companion names in Task 1's test (checked against `database.g.dart` there). The trip list's phone body wrapper in Task 7, which the implementer places around whatever `body:` holds today. The prompt length (Task 8, measured).
