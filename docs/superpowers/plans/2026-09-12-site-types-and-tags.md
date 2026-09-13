# Dive Site Types and Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver give every dive site any number of types (built-in or custom) and any number of tags (from the shared tag list, scoped per tag to dives, sites or both), visible and editable everywhere a site appears, and carried through sync, UDDF and imports (issue #1765).

**Architecture:** Schema rung v214 adds a `site_types` vocabulary (a twin of `dive_types`), two clockless site-child junctions (`site_site_types`, `site_tags`), and two scope flags on `tags`. One new `SiteClassificationRepository` owns both junctions. Site types and tags never live on the `DiveSite` entity (the #1187 partial-entity wipe); they reach the UI through providers and `SiteWithDiveCount`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, go_router, `xml` builder, `flutter gen-l10n` (11 ARB locales).

**Spec:** `docs/superpowers/specs/2026-09-12-site-types-and-tags-design.md`

## Global Constraints

- Schema: `currentSchemaVersion` becomes 214 (drafted as 212; renumbered when main shipped v213 and #1639 kept 212); `minimumCompatibleSchemaVersion` stays 210.
- Built-in site type slugs, in sort order: `reef`, `wall`, `wreck`, `artificial_reef`, `cave`, `cavern`, `cenote`, `blue_hole`, `lake`, `quarry`, `river`, `spring`, `pool`, `pier`, `muck`, `kelp_forest`. Never synced, never editable.
- Existing tags migrate to `applies_to_dives = 1`, `applies_to_sites = 0`. A tag must apply to at least one of the two.
- Junction writers are conflict-safe (`DoNothing`), mark only the junction row pending, and never mark the parent site pending.
- `DiveSite` gains no type or tag fields. `SiteRepository.updateSite` without a classification never touches the junctions.
- Sync entity keys: `siteTypes`, `siteSiteTypes`, `siteTags`.
- No em-dashes anywhere (code, comments, commits). No emojis. No mention of Claude, Claude Code or Anthropic in commits or files.
- Every user-facing string goes through `context.l10n`. English keys are added in the task that uses them; the other 10 locales are translated in Task 14. `app_en.arb` is alphabetical: insert new keys at their sorted position. In the 10 other ARB files, insert each key next to a neighbouring existing key of the same prefix.
- After any ARB edit run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart`.
- Run `dart format .` before every commit. Stage explicit paths only, never `git add -A`.
- Run test files individually while iterating (`flutter test <file>`). Do not start overlapping `flutter test` runs. One full-suite run happens in Task 15 only.

## File Map

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/core/database/database.dart` | modify | Tables, tag columns, v214 rung, onCreate, beforeOpen |
| `lib/core/database/site_type_seed.dart` | create | Built-in site type list and seed SQL |
| `lib/core/database/site_classification_uniqueness.dart` | create | Unique indexes on both junctions |
| `lib/core/database/tag_uniqueness.dart` | modify | Duplicate-tag repair repoints `site_tags`, ORs scopes |
| `lib/core/data/repositories/sync_repository.dart` | modify | `hlcTargets` |
| `lib/core/services/sync/sync_data_serializer.dart` | modify | Entity registration, tag fold repoints `site_tags` |
| `lib/core/services/sync/sync_service.dart` | modify | Merge order, `entityHasUpdatedAt`, `parentRefs` |
| `lib/core/services/sync/conflict_reference.dart` | modify | `siteTypeId` target |
| `lib/features/settings/presentation/widgets/conflict_reference_labels.dart` | modify | `siteTypes` label |
| `lib/features/site_types/domain/entities/site_type_entity.dart` | create | `SiteTypeEntity` |
| `lib/features/site_types/data/mappers/site_type_row_mapper.dart` | create | Drift row to entity |
| `lib/features/site_types/data/repositories/site_type_repository.dart` | create | Vocabulary CRUD and statistics |
| `lib/features/site_types/presentation/site_type_display.dart` | create | Translated built-in names |
| `lib/features/site_types/presentation/providers/site_type_providers.dart` | create | Providers and list notifier |
| `lib/features/site_types/presentation/pages/site_types_page.dart` | create | Settings > Manage page |
| `lib/features/divers/data/repositories/diver_repository.dart` | modify | Delete a diver's custom site types |
| `lib/features/tags/domain/entities/tag.dart` | modify | `TagScope`, scope flags |
| `lib/features/tags/data/mappers/tag_row_mapper.dart` | create | Shared Drift row to `Tag` |
| `lib/features/tags/data/repositories/tag_repository.dart` | modify | Scope rules, merge, statistics |
| `lib/features/tags/presentation/providers/tag_providers.dart` | modify | Scope-aware create |
| `lib/features/tags/presentation/widgets/tag_input_widget.dart` | modify | `scope` parameter |
| `lib/features/tags/presentation/widgets/tag_picker_sheet.dart` | modify | Dive-scoped tags only |
| `lib/features/tags/presentation/pages/tag_manage_page.dart` | modify | Scope editor, usage |
| `lib/features/dive_sites/domain/entities/site_classification.dart` | create | `SiteClassification` value |
| `lib/features/dive_sites/data/repositories/site_classification_repository.dart` | create | Both junctions |
| `lib/features/dive_sites/data/repositories/site_repository_impl.dart` | modify | Transactional save, merge, undo, list batch |
| `lib/features/dive_sites/domain/entities/site_with_dive_count.dart` | modify | `siteTypes`, `tags` |
| `lib/features/dive_sites/presentation/providers/site_providers.dart` | modify | Filter state, notifier, per-site providers |
| `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart` | create | Edit page section |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | modify | Section wiring and save |
| `lib/features/dive_sites/presentation/widgets/site_classification_chips.dart` | create | Detail page chip row |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | modify | Chip row |
| `lib/features/dive_sites/presentation/widgets/site_list_tile.dart` | modify | Card chips |
| `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart` | modify | Type and tag filters |
| `lib/features/dive_sites/domain/constants/site_field.dart` | modify | `siteTypes`, `tags` columns |
| `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` | modify | Dive-scoped tags only |
| `lib/features/statistics/data/repositories/statistics_repository.dart` | modify | `getSiteTypeDistribution` |
| `lib/features/statistics/presentation/providers/statistics_providers.dart` | modify | Provider |
| `lib/features/statistics/presentation/widgets/horizontal_category_bar_chart.dart` | create | New chart |
| `lib/features/statistics/presentation/pages/statistics_conditions_page.dart` | modify | Section |
| `lib/core/services/export/uddf/uddf_site_classification_writers.dart` | create | Shared UDDF writers |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | modify | Site refs, definitions, tag scope |
| `lib/core/services/export/uddf/uddf_export_service.dart` | modify | Dives-only site block and definitions |
| `lib/core/services/export/uddf/uddf_full_export_service.dart` | modify | Pass-through |
| `lib/core/services/export/uddf/uddf_dives_extras.dart` | modify | Classification extras |
| `lib/features/settings/presentation/providers/export_providers.dart` | modify | Load classification for export |
| `lib/core/services/export/uddf/uddf_import_parsers.dart` | modify | Site refs, tag scope |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | modify | `<sitetypes>` definitions |
| `lib/core/services/export/models/uddf_import_result.dart` | modify | `customSiteTypes` |
| `lib/features/universal_import/data/models/import_payload.dart` | modify | `customSiteTypesKey` |
| `lib/features/universal_import/data/parsers/uddf_import_parser.dart` | modify | Metadata |
| `lib/features/universal_import/data/services/payload_merger.dart` | modify | Merge definitions, namespace site `tagRefs` |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | modify | Result and repositories |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | modify | Resolve and apply; tag color fix |
| `lib/features/universal_import/data/services/shearwater_value_mapper.dart` | modify | Environment to site type |
| `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` | modify | `suggestedSiteTypeRefs` |
| `lib/features/dive_sites/data/services/dive_site_api_service.dart` | modify | Read `features`, map types |
| `lib/features/dive_sites/data/services/site_matching_service.dart` | modify | Apply mapped types |
| `lib/features/dive_sites/presentation/pages/site_map_page.dart` | modify | Apply mapped types |
| `lib/features/dive_sites/presentation/widgets/site_map_content.dart` | modify | Apply mapped types |
| `lib/core/router/app_router.dart` | modify | `/site-types` |
| `lib/features/settings/presentation/pages/settings_page.dart` | modify | Manage entry |
| `lib/l10n/arb/app_*.arb` | modify | Strings |

---

### Task 1: Schema v214

**Files:**
- Create: `lib/core/database/site_type_seed.dart`
- Create: `lib/core/database/site_classification_uniqueness.dart`
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/database/tag_uniqueness.dart`
- Modify: `test/core/database/migration_v211_auto_tag_imports_test.dart:7-12`
- Test: `test/core/database/migration_v214_site_classification_test.dart`

**Interfaces:**
- Produces: Drift tables `siteTypes` (data class `SiteType`, companion `SiteTypesCompanion`), `siteSiteTypes` (`SiteSiteType`, `SiteSiteTypesCompanion`), `siteTags` (`SiteTag`, `SiteTagsCompanion`); `Tags.appliesToDives` / `Tags.appliesToSites` (`bool`); `const List<({String id, String name})> kBuiltInSiteTypes`; `final String kSeedBuiltInSiteTypesSql`; `Future<void> assertSiteClassificationUniqueness(DatabaseConnectionUser db)`; index name constants `kSiteSiteTypesUniqueIndexName`, `kSiteTagsUniqueIndexName`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v214_site_classification_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/site_classification_uniqueness.dart';
import 'package:submersion/core/database/site_type_seed.dart';

void main() {
  /// A pre-v214 database: `tags` without the scope flags, no site tables.
  NativeDatabase setupDb({int userVersion = 211}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tags (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO tags (id, name, created_at, updated_at) "
          "VALUES ('t1', 'Night', 0, 0)",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v214 is the current schema version and is in the ladder', () {
    // This is the newest rung, so it owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 214);
    expect(AppDatabase.migrationVersions, contains(214));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('creates the three site classification tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'site_types'),
      containsAll(<String>[
        'id',
        'diver_id',
        'name',
        'is_built_in',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'site_site_types'),
      containsAll(<String>['id', 'site_id', 'site_type_id', 'created_at', 'hlc']),
    );
    expect(
      await columnsOf(db, 'site_tags'),
      containsAll(<String>['id', 'site_id', 'tag_id', 'created_at', 'hlc']),
    );
  });

  test('existing tags become dives-only', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT applies_to_dives, applies_to_sites FROM tags WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('applies_to_dives'), 1);
    expect(row.read<int>('applies_to_sites'), 0);
  });

  test('seeds every built-in site type with its stable slug', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, is_built_in FROM site_types ORDER BY sort_order',
        )
        .get();
    expect(
      rows.map((r) => r.read<String>('id')).toList(),
      kBuiltInSiteTypes.map((t) => t.id).toList(),
    );
    expect(rows.every((r) => r.read<int>('is_built_in') == 1), isTrue);
  });

  test('creates both junction unique indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await indexNames(db),
      containsAll(<String>[
        kSiteSiteTypesUniqueIndexName,
        kSiteTagsUniqueIndexName,
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    final rows = await fresh
        .customSelect('SELECT COUNT(*) AS n FROM site_types')
        .getSingle();
    expect(rows.read<int>('n'), kBuiltInSiteTypes.length);
    expect(
      await indexNames(fresh),
      containsAll(<String>[
        kSiteSiteTypesUniqueIndexName,
        kSiteTagsUniqueIndexName,
      ]),
    );
    expect(
      await columnsOf(fresh, 'tags'),
      containsAll(<String>['applies_to_dives', 'applies_to_sites']),
    );
  });

  test('a duplicate junction pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('a', 's1', 'wreck', 0)",
    );

    expect(
      () => db.customStatement(
        "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
        "VALUES ('b', 's1', 'wreck', 0)",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
```

Also add a test to `test/core/database/migration_v149_tag_uniqueness_test.dart`'s neighbour, a new file `test/core/database/tag_uniqueness_site_tags_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

void main() {
  test(
    'collapsing duplicate tags repoints site_tags and ORs the scopes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // A database that lost the tag index (restore of an old file).
      await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Site', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites) "
        "VALUES ('a', 'To try', 0, 0, 1, 0), ('b', 'to try', 0, 0, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st1', 's1', 'b', 0)",
      );

      await collapseDuplicateTags(db);

      final tags = await db
          .customSelect(
            'SELECT id, applies_to_dives, applies_to_sites FROM tags',
          )
          .get();
      expect(tags, hasLength(1));
      expect(tags.single.read<String>('id'), 'a');
      expect(tags.single.read<int>('applies_to_dives'), 1);
      expect(tags.single.read<int>('applies_to_sites'), 1);

      final links = await db
          .customSelect('SELECT tag_id FROM site_tags')
          .get();
      expect(links.map((r) => r.read<String>('tag_id')).toList(), ['a']);
    },
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/database/migration_v214_site_classification_test.dart test/core/database/tag_uniqueness_site_tags_test.dart`
Expected: FAIL to compile (`site_classification_uniqueness.dart` and `site_type_seed.dart` do not exist).

- [ ] **Step 3: Create the seed file**

Create `lib/core/database/site_type_seed.dart`:

```dart
/// Built-in dive site types (v214, issue #1765).
///
/// The slug ids are the identity: every device seeds the same rows with
/// `INSERT OR IGNORE`, sync never exports them, and a `site_site_types` row
/// points at a built-in by slug. The names are English literals because the
/// stored `name` is what exports carry; the UI translates by id
/// (`builtInSiteTypeName`). This is the dive type arrangement, including the
/// lesson of #1360: a seed must never mint random ids.
library;

/// The built-in site types in display order. Append only; never rename a
/// slug, since junction rows, exports and saved filters reference it.
const List<({String id, String name})> kBuiltInSiteTypes = [
  (id: 'reef', name: 'Reef'),
  (id: 'wall', name: 'Wall'),
  (id: 'wreck', name: 'Wreck'),
  (id: 'artificial_reef', name: 'Artificial reef'),
  (id: 'cave', name: 'Cave'),
  (id: 'cavern', name: 'Cavern'),
  (id: 'cenote', name: 'Cenote'),
  (id: 'blue_hole', name: 'Blue hole'),
  (id: 'lake', name: 'Lake'),
  (id: 'quarry', name: 'Quarry'),
  (id: 'river', name: 'River'),
  (id: 'spring', name: 'Spring'),
  (id: 'pool', name: 'Pool'),
  (id: 'pier', name: 'Pier / jetty'),
  (id: 'muck', name: 'Muck'),
  (id: 'kelp_forest', name: 'Kelp forest'),
];

/// The set of built-in slugs, for importers that map external vocabularies.
final Set<String> kBuiltInSiteTypeIds = {
  for (final t in kBuiltInSiteTypes) t.id,
};

/// Idempotent seed of [kBuiltInSiteTypes]. Run by `onCreate`, the v214 rung
/// and the `beforeOpen` backstop.
final String kSeedBuiltInSiteTypesSql = _buildSeedSql();

String _buildSeedSql() {
  String quote(String s) => "'${s.replaceAll("'", "''")}'";
  final rows = <String>[];
  for (var i = 0; i < kBuiltInSiteTypes.length; i++) {
    final t = kBuiltInSiteTypes[i];
    rows.add(
      i == 0
          ? 'SELECT ${quote(t.id)} AS id, ${quote(t.name)} AS name, '
                '$i AS sort_order'
          : 'UNION ALL SELECT ${quote(t.id)}, ${quote(t.name)}, $i',
    );
  }
  return '''
  INSERT OR IGNORE INTO site_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    ${rows.join('\n    ')}
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
}
```

- [ ] **Step 4: Create the uniqueness file**

Create `lib/core/database/site_classification_uniqueness.dart`:

```dart
/// Site classification junction identity: one `site_site_types` row per
/// (site, type) and one `site_tags` row per (site, tag) (v214, issue #1765).
///
/// Both junctions follow `dive_dive_types` and `dive_tags`: a surrogate uuid
/// primary key, so a re-inserted row never collides with the tombstone of the
/// row it replaced (#347), plus a unique index over the pair the row means.
/// Unlike those two, these tables have the index from the day they exist, so
/// the collapse below only ever runs against a database whose index was lost
/// (a restore of a partially migrated file). It keeps the oldest row of each
/// pair, `id` breaking ties, so every device lands on the same survivor.
///
/// With the index in place an unguarded duplicate insert THROWS, so every
/// writer must use `DoNothing`.
library;

import 'package:drift/drift.dart';

const String kSiteSiteTypesUniqueIndexName =
    'idx_site_site_types_site_type_unique';

const String kSiteTagsUniqueIndexName = 'idx_site_tags_site_tag_unique';

const String _createSiteSiteTypesIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kSiteSiteTypesUniqueIndexName '
    'ON site_site_types(site_id, site_type_id)';

const String _createSiteTagsIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kSiteTagsUniqueIndexName '
    'ON site_tags(site_id, tag_id)';

String _collapseSql(String table, String pairColumn) =>
    '''
  DELETE FROM $table WHERE rowid IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY site_id, $pairColumn ORDER BY created_at ASC, id ASC
      ) AS rn FROM $table
    ) WHERE rn > 1
  )
''';

Future<bool> _exists(DatabaseConnectionUser db, String type, String name) async {
  final rows = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
        variables: [Variable<String>(type), Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Asserts both junction unique indexes exist, collapsing duplicates first so
/// creating an index cannot abort. Costs two `sqlite_master` lookups when the
/// indexes are present. Self-guarding on the tables existing, so partial
/// migration-test fixtures pass through.
///
/// Called from `onCreate` (`createAll()` never builds raw-SQL indexes), the
/// v214 rung, and `beforeOpen`.
Future<void> assertSiteClassificationUniqueness(
  DatabaseConnectionUser db,
) async {
  for (final spec in const [
    (
      table: 'site_site_types',
      pair: 'site_type_id',
      index: kSiteSiteTypesUniqueIndexName,
      create: _createSiteSiteTypesIndexSql,
    ),
    (
      table: 'site_tags',
      pair: 'tag_id',
      index: kSiteTagsUniqueIndexName,
      create: _createSiteTagsIndexSql,
    ),
  ]) {
    if (!await _exists(db, 'table', spec.table)) continue;
    if (await _exists(db, 'index', spec.index)) continue;
    await db.customStatement(_collapseSql(spec.table, spec.pair));
    await db.customStatement(spec.create);
  }
}
```

- [ ] **Step 5: Add the tables and tag columns to `database.dart`**

Add two columns to `class Tags` (after `hlc`, before `primaryKey`, around line 2428):

```dart
  /// Whether the tag is offered on dives (v214, issue #1765). Every tag that
  /// existed before v214 is a dive tag.
  BoolColumn get appliesToDives =>
      boolean().withDefault(const Constant(true))();

  /// Whether the tag is offered on dive sites (v214, issue #1765). A tag
  /// always applies to at least one of the two; TagRepository enforces it.
  BoolColumn get appliesToSites =>
      boolean().withDefault(const Constant(false))();
```

Add three table classes directly after `class DiveDiveTypes` (after line 2509):

```dart
/// Dive site type vocabulary (v214, issue #1765). The twin of [DiveTypes]:
/// slug ids, built-ins (diverId null) seeded identically on every device by
/// `kSeedBuiltInSiteTypesSql` and never synced, custom types per diver.
class SiteTypes extends Table {
  TextColumn get id => text()(); // Unique identifier (slug)
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-ins
  TextColumn get name => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for a site's types (many-to-many, v214). Surrogate uuid
/// primary key, as [DiveDiveTypes]. `siteTypeId` has no foreign key for the
/// same reason as `DiveDiveTypes.diveTypeId`: a custom type can arrive by
/// sync after a junction row that references it.
class SiteSiteTypes extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get siteTypeId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Junction table for a site's tags (many-to-many, v214), the twin of
/// [DiveTags].
class SiteTags extends Table {
  TextColumn get id => text()();
  TextColumn get siteId =>
      text().references(DiveSites, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
```

In the `@DriftDatabase(tables: [...])` list, after `SiteFeatures,` (line ~4020) add:

```dart
    // Site classification (v214, issue #1765)
    SiteTypes,
    SiteSiteTypes,
    SiteTags,
```

Add imports at the top of `database.dart`, next to the existing `dive_type_uniqueness.dart` / `tag_uniqueness.dart` imports:

```dart
import 'package:submersion/core/database/site_classification_uniqueness.dart';
import 'package:submersion/core/database/site_type_seed.dart';
```

- [ ] **Step 6: Bump the version and add the rung**

Change line ~4083 to `static const int currentSchemaVersion = 214;`.

Append to `migrationVersions` after `211,`:

```dart
    // v214: dive site types and tags (issue #1765). Three new tables
    // (site_types, site_site_types, site_tags), the built-in site type seed,
    // both junction unique indexes, and tags.applies_to_dives /
    // applies_to_sites. Additive only, so the compatibility floor stays.
    214,
```

Add the helper next to `_assertDiveTypeVisibilityColumns` (~line 7956):

```dart
  /// Idempotent DDL for the tag scope flags (v214, issue #1765). Existing
  /// tags are dive tags; none applies to sites until the diver says so.
  Future<void> _assertTagScopeColumns() async {
    final cols = await customSelect("PRAGMA table_info('tags')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('applies_to_dives')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_dives '
        'INTEGER NOT NULL DEFAULT 1 CHECK (applies_to_dives IN (0, 1))',
      );
    }
    if (!names.contains('applies_to_sites')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_sites '
        'INTEGER NOT NULL DEFAULT 0 CHECK (applies_to_sites IN (0, 1))',
      );
    }
  }

  /// Idempotent creation of the v214 site classification schema: the three
  /// tables, the built-in seed, and the junction unique indexes. Called from
  /// the v214 rung and the beforeOpen backstop.
  Future<void> _assertSiteClassificationSchema() async {
    await createMigrator().createTable(siteTypes);
    await createMigrator().createTable(siteSiteTypes);
    await createMigrator().createTable(siteTags);
    await customStatement(kSeedBuiltInSiteTypesSql);
    await assertSiteClassificationUniqueness(this);
  }
```

At the end of `onUpgrade`, after the `if (from < 211) await reportProgress();` line:

```dart
        // v214: dive site types and tags (issue #1765). Table-and-column
        // rung, no backfill beyond the built-in seed.
        if (from < 214) {
          await _assertTagScopeColumns();
          await _assertSiteClassificationSchema();
        }
        if (from < 214) await reportProgress();
```

- [ ] **Step 7: onCreate and beforeOpen**

In `onCreate`, after `await assertDiveTypeUniqueness(this);` (line ~8267):

```dart
        // Built-in site types and the site junction unique indexes (v214,
        // issue #1765). createAll() builds the tables but never raw-SQL
        // indexes or seeds.
        await customStatement(kSeedBuiltInSiteTypesSql);
        await assertSiteClassificationUniqueness(this);
```

In `beforeOpen`, as the first lines (before the v211 backstop):

```dart
        // v214 backstop: the tag scope flags.
        await _assertTagScopeColumns();
```

In `beforeOpen`, directly after the v152 `createTable(siteFeatures)` backstop (~line 11974):

```dart
        // v214 backstop: site classification tables, seed and indexes
        // (parallel-branch version-collision self-heal; all idempotent).
        await _assertSiteClassificationSchema();
```

Add `'site_site_types',` and `'site_tags',` to the list in `_assertChildHlcColumns` (after `'site_species',`).

- [ ] **Step 8: Extend the duplicate-tag repair**

In `lib/core/database/tag_uniqueness.dart`, add after `_repointDiveTagsToSurvivorSql`:

```dart
/// Repoints `site_tags` at the surviving tag, like the dive junction above
/// (v214, issue #1765). `OR IGNORE` because the `site_tags` unique index can
/// already exist when this runs: a site holding both the loser and the
/// survivor keeps its survivor row, and the loser row is swept below.
const String _repointSiteTagsToSurvivorSql = '''
  UPDATE OR IGNORE site_tags SET tag_id = (
    SELECT MIN(survivor.id) FROM tags survivor, tags mine
    WHERE mine.id = site_tags.tag_id
      AND COALESCE(survivor.diver_id, '') = COALESCE(mine.diver_id, '')
      AND lower(trim(survivor.name)) = lower(trim(mine.name))
  )
  WHERE EXISTS (SELECT 1 FROM tags t WHERE t.id = site_tags.tag_id)
''';

/// Gives the surviving tag of each group the union of the group's scopes, so
/// collapsing a dive tag and a site tag of the same name keeps both uses.
const String _mergeScopesIntoSurvivorSql = '''
  UPDATE tags SET
    applies_to_dives = (
      SELECT MAX(o.applies_to_dives) FROM tags o
      WHERE COALESCE(o.diver_id, '') = COALESCE(tags.diver_id, '')
        AND lower(trim(o.name)) = lower(trim(tags.name))
    ),
    applies_to_sites = (
      SELECT MAX(o.applies_to_sites) FROM tags o
      WHERE COALESCE(o.diver_id, '') = COALESCE(tags.diver_id, '')
        AND lower(trim(o.name)) = lower(trim(tags.name))
    )
''';

/// Site links left pointing at a deleted losing tag (the `OR IGNORE` rows).
const String _deleteOrphanSiteTagsSql =
    'DELETE FROM site_tags WHERE tag_id NOT IN (SELECT id FROM tags)';

const String _collapseDuplicateSiteTagsSql = '''
  DELETE FROM site_tags WHERE rowid NOT IN (
    SELECT MIN(rowid) FROM site_tags GROUP BY site_id, tag_id
  )
''';

Future<bool> _columnExists(
  DatabaseConnectionUser db,
  String table,
  String column,
) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.any((c) => c.read<String>('name') == column);
}
```

Replace the body of `collapseDuplicateTags`:

```dart
Future<void> collapseDuplicateTags(DatabaseConnectionUser db) async {
  final hasSiteTags = await _tableExists(db, 'site_tags');
  await db.customStatement(_normalizeTagNamesSql);
  if (await _columnExists(db, 'tags', 'applies_to_sites')) {
    await db.customStatement(_mergeScopesIntoSurvivorSql);
  }
  await db.customStatement(_repointDiveTagsToSurvivorSql);
  if (hasSiteTags) await db.customStatement(_repointSiteTagsToSurvivorSql);
  await db.customStatement(_deleteLosingTagsSql);
  await db.customStatement(_collapseDuplicateDiveTagsSql);
  if (hasSiteTags) {
    await db.customStatement(_deleteOrphanSiteTagsSql);
    await db.customStatement(_collapseDuplicateSiteTagsSql);
  }
}
```

Update its doc comment's first sentence to say it repoints both junctions.

- [ ] **Step 9: Relax the v211 exact assertion**

In `test/core/database/migration_v211_auto_tag_imports_test.dart` lines 7-12, replace the test with:

```dart
  test('v211 is in the ladder', () {
    // Relaxed once v214 (site types and tags) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(211));
    expect(AppDatabase.migrationVersions, contains(211));
  });
```

- [ ] **Step 10: Regenerate Drift code and run the tests**

Run: `bash scripts/setup.sh` (runs `build_runner`; a bare `dart run build_runner build` may be refused by a permission rule)
Then: `flutter test test/core/database/migration_v214_site_classification_test.dart test/core/database/tag_uniqueness_site_tags_test.dart test/core/database/migration_v211_auto_tag_imports_test.dart test/core/database/migration_v149_tag_uniqueness_test.dart test/core/database/migration_v178_dive_type_uniqueness_test.dart`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database/database.dart lib/core/database/site_type_seed.dart lib/core/database/site_classification_uniqueness.dart lib/core/database/tag_uniqueness.dart test/core/database/migration_v214_site_classification_test.dart test/core/database/tag_uniqueness_site_tags_test.dart test/core/database/migration_v211_auto_tag_imports_test.dart
git commit -m "feat(sites): schema v214 for site types and site tags (#1765)"
```

### Task 2: Sync registration

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:71-146`
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (locations listed per step)
- Modify: `lib/core/services/sync/sync_service.dart:1395-1523, 2280-2366, 2411-2532`
- Modify: `lib/core/services/sync/conflict_reference.dart:82`
- Modify: `lib/features/settings/presentation/widgets/conflict_reference_labels.dart:36`
- Modify tests: `test/core/services/sync/sync_builtin_reference_data_test.dart`, `test/core/services/sync/sync_parent_refs_completeness_test.dart`, plus any registry test that fails in Step 9
- Test: `test/core/services/sync/site_classification_sync_test.dart`

**Interfaces:**
- Consumes: Task 1 tables.
- Produces: sync entity keys `siteTypes`, `siteSiteTypes`, `siteTags` accepted by `SyncRepository.markRecordPending` / `logDeletion`, exported and applied by `SyncDataSerializer`.

The three entities mirror existing ones exactly:

| New | Mirrors | Why |
| --- | --- | --- |
| `siteTypes` | `diveTypes` | slug vocabulary, custom rows only exported, `hasUpdatedAt: true` |
| `siteSiteTypes` | `siteSpecies` (site-parent export) + `diveDiveTypes` (apply) | clockless child of `diveSites`, no FK on the type id |
| `siteTags` | `siteSpecies` (site-parent export) + `diveTags` (apply with `_withTagAlias`) | clockless child of `diveSites`, FK to `tags` |

- [ ] **Step 1: Write the failing sync tests**

Create `test/core/services/sync/site_classification_sync_test.dart`. Reuse the serializer-level harness from `test/core/services/sync/site_features_sync_test.dart` (read its `setUp`/`tearDown` and copy them verbatim; they build a `SyncDataSerializer` over `setUpTestDatabase()`), then add:

```dart
  Future<void> seedSite(AppDatabase db, String id) => db.customStatement(
    "INSERT INTO dive_sites (id, name, created_at, updated_at) "
    "VALUES ('$id', 'Site $id', 0, 0)",
  );

  test('custom site types export; built-ins never do', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO site_types (id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES ('mine', 'Mine', 0, 100, 1, 1)",
    );

    final ids = await serializer.recordIdsFor('siteTypes');
    expect(ids, contains('mine'));
    expect(ids, isNot(contains('wreck')));
  });

  test('a site junction row round-trips through fetch and upsert', () async {
    final db = DatabaseService.instance.database;
    await seedSite(db, 's1');
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('j1', 's1', 'wreck', 5)",
    );
    final json = await serializer.fetchRecord('siteSiteTypes', 'j1');
    expect(json, isNotNull);

    await serializer.deleteRecord('siteSiteTypes', 'j1');
    await serializer.upsertRecord('siteSiteTypes', json!);

    final rows = await db.select(db.siteSiteTypes).get();
    expect(rows.single.siteTypeId, 'wreck');
  });

  test('a duplicate junction pair from a peer applies without throwing', () async {
    final db = DatabaseService.instance.database;
    await seedSite(db, 's1');
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('local', 's1', 'lake', 1)",
    );

    await serializer.upsertRecords('siteSiteTypes', [
      {
        'id': 'peer',
        'siteId': 's1',
        'siteTypeId': 'lake',
        'createdAt': 2,
        'hlc': null,
      },
    ]);

    final rows = await db.select(db.siteSiteTypes).get();
    expect(rows.map((r) => r.id), ['local']);
  });

  test('site tag rows are rewritten onto a folded tag', () async {
    final db = DatabaseService.instance.database;
    await seedSite(db, 's1');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('aaa', 'To try', 1, 1)",
    );
    // A peer's tag of the same name folds into the local survivor 'aaa'.
    await serializer.upsertRecord('tags', {
      'id': 'zzz',
      'diverId': null,
      'name': 'to try',
      'color': null,
      'createdAt': 2,
      'updatedAt': 2,
      'hlc': null,
      'appliesToDives': false,
      'appliesToSites': true,
    });
    await serializer.upsertRecord('siteTags', {
      'id': 'st1',
      'siteId': 's1',
      'tagId': 'zzz',
      'createdAt': 3,
      'hlc': null,
    });

    final links = await db.select(db.siteTags).get();
    expect(links.single.tagId, 'aaa');
    final tag = await (db.select(db.tags)..where((t) => t.id.equals('aaa')))
        .getSingle();
    expect(tag.appliesToSites, isTrue, reason: 'the fold keeps both scopes');
  });
```

Also add a test for the older-peer overlay to the same file. It goes through `SyncService`, so copy the one-database fake-cloud harness from `test/core/services/sync/sync_dive_dive_types_test.dart` lines 1-96 (its imports, `setUp`, `tearDown`, and the peer-payload seeding helper) and write:

```dart
  test(
    'a tag row from an older peer (no scope keys) keeps the local scope',
    () async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites, hlc) "
        "VALUES ('t1', 'To try', 1, 1, 0, 1, '0000000000001:0000:dev-a')",
      );

      // The peer renamed the tag on a v211 build: its row has no
      // appliesTo* keys and a newer clock, so it wins the merge.
      final olderPeerRow = <String, dynamic>{
        'id': 't1',
        'diverId': null,
        'name': 'To try soon',
        'color': null,
        'createdAt': 1,
        'updatedAt': 9,
        'hlc': '9999999999999:0000:dev-b',
      };
      // Seed and sync with the harness copied from
      // sync_dive_dive_types_test.dart, passing a payload whose `tags`
      // list is [olderPeerRow].

      final tag = await (db.select(db.tags)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(tag.name, 'To try soon');
      expect(tag.appliesToSites, isTrue);
      expect(tag.appliesToDives, isFalse);
    },
  );
```

When copying the harness, replace the comment above with the harness's real seed-and-sync calls (the file seeds a peer payload map and calls `performSync()`); the assertions stay as written.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/sync/site_classification_sync_test.dart`
Expected: FAIL (`recordIdsFor` throws "unknown entity type siteTypes"; `fetchRecord` returns null).

- [ ] **Step 3: `hlcTargets`**

In `lib/core/data/repositories/sync_repository.dart`, after `'diveTypes': (table: 'dive_types', pk: 'id'),` (line 86):

```dart
    'siteTypes': (table: 'site_types', pk: 'id'),
```

After `'siteSpecies': (table: 'site_species', pk: 'id'),` (line 146):

```dart
    'siteSiteTypes': (table: 'site_site_types', pk: 'id'),
    'siteTags': (table: 'site_tags', pk: 'id'),
```

- [ ] **Step 4: `SyncData` fields**

In `sync_data_serializer.dart`, add next to the `siteSpecies` field, constructor parameter, `toJson` entry and `fromJson` entry (the four places `siteSpecies` appears in `SyncData`):

```dart
  final List<Map<String, dynamic>> siteTypes;
  final List<Map<String, dynamic>> siteSiteTypes;
  final List<Map<String, dynamic>> siteTags;
```
```dart
    this.siteTypes = const [],
    this.siteSiteTypes = const [],
    this.siteTags = const [],
```
```dart
    'siteTypes': siteTypes,
    'siteSiteTypes': siteSiteTypes,
    'siteTags': siteTags,
```
```dart
      siteTypes: _parseList(json['siteTypes']),
      siteSiteTypes: _parseList(json['siteSiteTypes']),
      siteTags: _parseList(json['siteTags']),
```

- [ ] **Step 5: Export**

In `_baseTables`, after the `siteSpecies` entry (line 1048):

```dart
    (key: 'siteSiteTypes', table: _db.siteSiteTypes, blob: false, full: null),
    (key: 'siteTags', table: _db.siteTags, blob: false, full: null),
    (
      key: 'siteTypes',
      table: null,
      blob: false,
      full: () => _exportSiteTypes(null),
    ),
```

In `_buildSyncData`, after the `siteSpecies` entry (lines 1942-1949):

```dart
      siteSiteTypes: await _safeExport(
        'siteSiteTypes',
        () async => _withPendingChildren(
          'siteSiteTypes',
          await _exportSiteSiteTypes(hlcSince),
          pendingChildren,
        ),
      ),
      siteTags: await _safeExport(
        'siteTags',
        () async => _withPendingChildren(
          'siteTags',
          await _exportSiteTags(hlcSince),
          pendingChildren,
        ),
      ),
      siteTypes: await _safeExport(
        'siteTypes',
        () => _exportSiteTypes(hlcSince),
      ),
```

Add the exporters after `_exportSiteSpecies` (line ~6700):

```dart
  Future<List<Map<String, dynamic>>> _exportSiteTypes(String? hlcSince) async {
    // Built-in site types are seeded identically on every device and cannot
    // be edited; export custom types only, as _exportDiveTypes does.
    final query = _db.select(_db.siteTypes)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSiteSiteTypes(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedSites = await (_db.select(
        _db.diveSites,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final siteIds = modifiedSites.map((s) => s.id).toSet();
      if (siteIds.isEmpty) return [];

      return _childRowsOf(
        siteIds,
        (chunk) => (_db.select(
          _db.siteSiteTypes,
        )..where((t) => t.siteId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.siteSiteTypes).get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSiteTags(String? hlcSince) async {
    if (hlcSince != null) {
      final modifiedSites = await (_db.select(
        _db.diveSites,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final siteIds = modifiedSites.map((s) => s.id).toSet();
      if (siteIds.isEmpty) return [];

      return _childRowsOf(
        siteIds,
        (chunk) => (_db.select(
          _db.siteTags,
        )..where((t) => t.siteId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.siteTags).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

Add `'siteSiteTypes',` and `'siteTags',` to `parentGatedChildEntities` (after `'siteSpecies',`, line 1427) and to `parentGatedTables`:

```dart
    'siteSiteTypes': 'site_site_types',
    'siteTags': 'site_tags',
```

- [ ] **Step 6: Fetch, apply, lookups, delete**

`fetchRecord` (near the `diveTypes` case, line 2379):

```dart
      case 'siteTypes':
        final row = await (_db.select(
          _db.siteTypes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'siteSiteTypes':
        final row = await (_db.select(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'siteTags':
        final row = await (_db.select(
          _db.siteTags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`fetchRecords` (after the `diveTypes` case, line 2735):

```dart
      case 'siteTypes':
        final rows = await (_db.select(
          _db.siteTypes,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

Add apply helpers after `_applyDiveDiveTypeRecord` (line 3035):

```dart
  /// DoNothing, not insertOnConflictUpdate: `site_site_types` is uniquely
  /// indexed on (site_id, site_type_id), so a peer's copy of a pair this
  /// device already holds under another id must be skipped, not thrown on.
  Future<void> _applySiteSiteTypeRecord(SiteSiteType record) async {
    await _db
        .into(_db.siteSiteTypes)
        .insert(
          record,
          onConflict: DoNothing<$SiteSiteTypesTable, SiteSiteType>(
            target: const [],
          ),
        );
  }

  /// As [_applyDiveTagRecord]: the (site_id, tag_id) unique index makes a
  /// peer's duplicate pair a no-op.
  Future<void> _applySiteTagRecord(SiteTag record) async {
    await _db
        .into(_db.siteTags)
        .insert(
          record,
          onConflict: DoNothing<$SiteTagsTable, SiteTag>(target: const []),
        );
  }
```

`upsertRecord` (after the `diveTypes` case, line 3411):

```dart
      case 'siteTypes':
        await _db
            .into(_db.siteTypes)
            .insertOnConflictUpdate(SiteType.fromJson(data).toCompanion(false));
        return;
      case 'siteSiteTypes':
        await _applySiteSiteTypeRecord(SiteSiteType.fromJson(data));
        return;
      case 'siteTags':
        await _applySiteTagRecord(SiteTag.fromJson(_withTagAlias(data)));
        return;
```

`upsertRecords` (after the `diveTypes` case, line 4339):

```dart
      case 'siteTypes':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.siteTypes,
            records
                .map((r) => SiteType.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
      case 'siteSiteTypes':
        await _db.batch(
          (b) => b.insertAll(
            _db.siteSiteTypes,
            records.map((r) => SiteSiteType.fromJson(r)).toList(),
            onConflict: DoNothing<$SiteSiteTypesTable, SiteSiteType>(
              target: const [],
            ),
          ),
        );
        return;
      case 'siteTags':
        await _db.batch(
          (b) => b.insertAll(
            _db.siteTags,
            records.map((r) => SiteTag.fromJson(_withTagAlias(r))).toList(),
            onConflict: DoNothing<$SiteTagsTable, SiteTag>(target: const []),
          ),
        );
        return;
```

`recordIdsFor` (after the `diveDiveTypes` case, line 4834):

```dart
      case 'siteTypes':
        return plain(_db.siteTypes, _db.siteTypes.id);
      case 'siteSiteTypes':
        return plain(_db.siteSiteTypes, _db.siteSiteTypes.id);
      case 'siteTags':
        return plain(_db.siteTags, _db.siteTags.id);
```

Check the `plain` helper for `siteTypes`: `diveTypes` uses `plain` too, so if `recordIdsFor('diveTypes')` includes built-ins, change the test in Step 1 to assert via `_exportSiteTypes` indirectly instead: read the `diveTypes` case first and mirror whatever it does for built-ins.

`deleteAllRecords` (after the `diveTypes` case, line 4929):

```dart
      case 'siteTypes':
        await (_db.delete(
          _db.siteTypes,
        )..where((t) => t.isBuiltIn.equals(false))).go();
        return;
```

and, if the switch lists `diveDiveTypes`/`diveTags` explicitly, add matching `siteSiteTypes` / `siteTags` cases that delete all rows.

`_syncTableFor` (after the `diveDiveTypes` case, line 5196):

```dart
      case 'siteTypes':
        return _db.siteTypes;
      case 'siteSiteTypes':
        return _db.siteSiteTypes;
      case 'siteTags':
        return _db.siteTags;
```

`deleteRecord` (after the `diveTypes` case, line 5545):

```dart
      case 'siteTypes':
        await (_db.delete(
          _db.siteTypes,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'siteSiteTypes':
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'siteTags':
        await (_db.delete(
          _db.siteTags,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 7: Tag folding keeps site links and scopes**

In `_foldTagInto` (line 2955), directly after the block that repoints `diveTags` rows onto the survivor and marks them pending (lines ~2960-2985), add the same for `siteTags`:

```dart
    // Site links follow the survivor too (v214, issue #1765); without this a
    // folded tag would lose every site it was on.
    final siteLinks = await (_db.select(
      _db.siteTags,
    )..where((t) => t.tagId.equals(loserId))).get();
    for (final link in siteLinks) {
      await (_db.update(_db.siteTags)..where((t) => t.id.equals(link.id)))
          .write(SiteTagsCompanion(tagId: Value(survivorId)));
      await _syncRepository.markRecordPending(
        entityType: 'siteTags',
        recordId: link.id,
        localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
```

Use the loser/survivor variable names `_foldTagInto` already uses (read the method; if its dive-tag repoint uses `insert ... DoNothing` plus delete rather than update, mirror that shape exactly instead, so a site holding both tags does not hit the unique index).

Then make the fold OR the scopes: where `_foldTagInto` / `_applyTagRecord` writes the surviving tag row, write `appliesToDives` and `appliesToSites` as the OR of the survivor's and the folded row's flags (`Tag` data class fields `appliesToDives`, `appliesToSites`).

- [ ] **Step 8: `sync_service.dart`, conflict references**

Merge order: after `(type: 'diveTypes', records: data.diveTypes, hasUpdatedAt: true),` (line 1395):

```dart
          (type: 'siteTypes', records: data.siteTypes, hasUpdatedAt: true),
```

After the `siteSpecies` entry (line 1513):

```dart
          (
            type: 'siteSiteTypes',
            records: data.siteSiteTypes,
            hasUpdatedAt: false,
          ),
          (type: 'siteTags', records: data.siteTags, hasUpdatedAt: false),
```

`entityHasUpdatedAt`:

```dart
    'siteTypes': true,
    'siteSiteTypes': false,
    'siteTags': false,
```

`parentRefs`:

```dart
    'siteSiteTypes': [(field: 'siteId', parent: 'diveSites', nullable: false)],
    'siteTags': [
      (field: 'siteId', parent: 'diveSites', nullable: false),
      (field: 'tagId', parent: 'tags', nullable: false),
    ],
```

`conflict_reference.dart` `_defaultTargets`, after `'diveTypeId': 'diveTypes',`:

```dart
    'siteTypeId': 'siteTypes',
```

and add `SiteSiteTypes.siteTypeId` to the doc comment's list of undeclared-reference columns.

`conflict_reference_labels.dart`, after the `diveTypes` case:

```dart
    case 'siteTypes':
      return l10n.settings_conflict_ref_siteType;
```

Add to `lib/l10n/arb/app_en.arb` at its sorted position (after `settings_conflict_ref_signer` or wherever alphabetical order puts it):

```json
  "settings_conflict_ref_siteType": "Site type",
```

Run `flutter gen-l10n`.

- [ ] **Step 9: Update the registry tests**

Run: `flutter test test/core/services/sync`
Expected failures and fixes:
- `sync_builtin_reference_data_test.dart`: add `site_types` to `_entityForTable` (`'site_types' => 'siteTypes'`) and to its insert-SQL switch, mirroring `dive_types`.
- `sync_parent_refs_completeness_test.dart`: add `'siteSiteTypes'` and `'siteTags'` to `syncedTables` as the file lists other junctions; `site_types` is not a deletable parent (no FK points at it).
- Any other failure names a registry that enumerates entity types (`sync_base_streaming_parity_test.dart`, `sync_data_serializer_record_ids_test.dart`, `pending_child_export_test.dart`, `sync_data_serializer_batch_coverage_test.dart`, `sync_serializer_fetch_record_test.dart`): add the three keys the way `diveTypes`, `diveDiveTypes` and `diveTags` appear there.

Re-run until green, including the new file.

- [ ] **Step 10: Commit**

```bash
dart format lib/core test/core lib/features/settings
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/core/services/sync/conflict_reference.dart lib/features/settings/presentation/widgets/conflict_reference_labels.dart lib/l10n/arb test/core/services/sync
git commit -m "feat(sync): sync site types and site classification junctions (#1765)"
```

### Task 3: Site type vocabulary

**Files:**
- Create: `lib/features/site_types/domain/entities/site_type_entity.dart`
- Create: `lib/features/site_types/data/mappers/site_type_row_mapper.dart`
- Create: `lib/features/site_types/data/repositories/site_type_repository.dart`
- Create: `lib/features/site_types/presentation/site_type_display.dart`
- Create: `lib/features/site_types/presentation/providers/site_type_providers.dart`
- Modify: `lib/features/divers/data/repositories/diver_repository.dart:594-597`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/site_types/data/repositories/site_type_repository_test.dart`
- Test: `test/features/site_types/presentation/site_type_display_test.dart`

**Interfaces:**
- Consumes: Task 1 `siteTypes` table, Task 2 sync keys.
- Produces:
  - `class SiteTypeEntity extends Equatable { String id; String? diverId; String name; bool isBuiltIn; int sortOrder; DateTime createdAt; DateTime updatedAt; }` with `SiteTypeEntity.create({required String id, required String name, String? diverId, int sortOrder = 0})`, `static String generateSlug(String name)`, `copyWith(...)`.
  - `SiteTypeEntity mapSiteTypeRow(SiteType row)`.
  - `class SiteTypeRepository` with `Stream<void> watchSiteTypesChanges()`, `Future<List<SiteTypeEntity>> getAllSiteTypes({String? diverId})`, `Future<SiteTypeEntity?> getSiteTypeById(String id)`, `Future<SiteTypeEntity?> getCustomSiteTypeByName(String name, {required String diverId})`, `Future<SiteTypeEntity> createSiteType(SiteTypeEntity type)`, `Future<void> updateSiteType(SiteTypeEntity type)`, `Future<void> deleteSiteType(String id)`, `Future<List<SiteTypeStatistic>> getSiteTypeStatistics({String? diverId})`; `class SiteTypeStatistic { SiteTypeEntity siteType; int siteCount; }`.
  - `String? builtInSiteTypeName(AppLocalizations l10n, String id)`; `extension SiteTypeDisplay on SiteTypeEntity { String localizedName(AppLocalizations l10n) }`.
  - Providers: `siteTypeRepositoryProvider`, `siteTypesProvider` (`FutureProvider<List<SiteTypeEntity>>`), `siteTypesByIdProvider` (`FutureProvider<Map<String, SiteTypeEntity>>`), `siteTypeStatisticsProvider`, `siteTypeListNotifierProvider` (`StateNotifierProvider.autoDispose<SiteTypeListNotifier, AsyncValue<List<SiteTypeEntity>>>`) with `addSiteTypeByName(String name)`, `updateSiteType(SiteTypeEntity)`, `deleteSiteType(String id)`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/site_types/data/repositories/site_type_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteTypeRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteTypeRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000), "
      "('diver-2', 'Other Diver', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  SiteTypeEntity custom(String name, {String diverId = 'diver-1'}) =>
      SiteTypeEntity.create(
        id: SiteTypeEntity.generateSlug(name),
        name: name,
        diverId: diverId,
      );

  test('lists built-ins in seed order, then the diver\'s custom types', () async {
    await repository.createSiteType(custom('Mine'));
    await repository.createSiteType(custom('Fjord', diverId: 'diver-2'));

    final types = await repository.getAllSiteTypes(diverId: 'diver-1');

    expect(
      types.take(kBuiltInSiteTypes.length).map((t) => t.id).toList(),
      kBuiltInSiteTypes.map((t) => t.id).toList(),
    );
    expect(types.last.name, 'Mine');
    expect(types.any((t) => t.name == 'Fjord'), isFalse);
  });

  test('a custom type colliding with a built-in slug gets a unique id', () async {
    final created = await repository.createSiteType(custom('Wreck'));
    expect(created.id, isNot('wreck'));
    expect(created.id, startsWith('wreck_'));
  });

  test('built-ins refuse update and delete', () async {
    final wreck = (await repository.getSiteTypeById('wreck'))!;
    expect(
      () => repository.updateSiteType(wreck.copyWith(name: 'Shipwreck')),
      throwsException,
    );
    expect(() => repository.deleteSiteType('wreck'), throwsException);
  });

  test('deleting a custom type removes its site links', () async {
    final db = DatabaseService.instance.database;
    final mine = await repository.createSiteType(custom('Mine'));
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('j1', 's1', '${mine.id}', 0)",
    );

    await repository.deleteSiteType(mine.id);

    expect(await db.select(db.siteSiteTypes).get(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'siteSiteTypes'",
        )
        .get();
    expect(tombstones.map((r) => r.read<String>('record_id')), ['j1']);
  });

  test('matches a custom type by case-insensitive name', () async {
    await repository.createSiteType(custom('Mine'));
    final found = await repository.getCustomSiteTypeByName(
      ' mine ',
      diverId: 'diver-1',
    );
    expect(found?.name, 'Mine');
  });

  test('statistics count sites per type', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0), ('s2', 'B', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('a', 's1', 'lake', 0), ('b', 's2', 'lake', 0), "
      "('c', 's2', 'wreck', 0)",
    );

    final stats = await repository.getSiteTypeStatistics(diverId: 'diver-1');
    final byId = {for (final s in stats) s.siteType.id: s.siteCount};
    expect(byId['lake'], 2);
    expect(byId['wreck'], 1);
    expect(byId['reef'], 0);
  });
}
```

If `deletion_log`'s column names differ (read `class DeletionLog` in `database.dart`), use the real ones.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/site_types/data/repositories/site_type_repository_test.dart`
Expected: FAIL to compile (files missing).

- [ ] **Step 3: Entity and mapper**

Create `lib/features/site_types/domain/entities/site_type_entity.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A dive site type (issue #1765): a built-in (reef, wall, wreck, ...) or a
/// custom type a diver created. Named `SiteTypeEntity` because Drift already
/// generates `SiteType` for the table row.
class SiteTypeEntity extends Equatable {
  final String id; // Slug
  final String? diverId; // null for built-ins
  final String name;
  final bool isBuiltIn;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteTypeEntity({
    required this.id,
    this.diverId,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteTypeEntity.create({
    required String id,
    required String name,
    String? diverId,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return SiteTypeEntity(
      id: id,
      diverId: diverId,
      name: name,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Same slug rules as `DiveTypeEntity.generateSlug`.
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  SiteTypeEntity copyWith({
    String? id,
    String? diverId,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SiteTypeEntity(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    isBuiltIn,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
```

Create `lib/features/site_types/data/mappers/site_type_row_mapper.dart`:

```dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

SiteTypeEntity mapSiteTypeRow(SiteType row) {
  return SiteTypeEntity(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    isBuiltIn: row.isBuiltIn,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
```

- [ ] **Step 4: Repository**

Create `lib/features/site_types/data/repositories/site_type_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/site_types/data/mappers/site_type_row_mapper.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// The site type vocabulary (issue #1765). The twin of DiveTypeRepository:
/// built-ins are read-only, custom types belong to one diver.
class SiteTypeRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SiteTypeRepository);

  Stream<void> watchSiteTypesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.siteTypes));

  /// Built-ins, then [diverId]'s custom types, each in sort order.
  Future<List<SiteTypeEntity>> getAllSiteTypes({String? diverId}) async {
    try {
      final query = _db.select(_db.siteTypes)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isBuiltIn),
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);
      if (diverId != null) {
        query.where(
          (t) =>
              t.isBuiltIn.equals(true) |
              (t.isBuiltIn.equals(false) & t.diverId.equals(diverId)),
        );
      } else {
        query.where((t) => t.isBuiltIn.equals(true));
      }
      final rows = await query.get();
      return rows.map(mapSiteTypeRow).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get site types', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<SiteTypeEntity?> getSiteTypeById(String id) async {
    final row = await (_db.select(
      _db.siteTypes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapSiteTypeRow(row);
  }

  /// [diverId]'s custom type whose trimmed name matches [name] ignoring case.
  /// Importers use it so a re-import reuses the type instead of minting a
  /// near-duplicate.
  Future<SiteTypeEntity?> getCustomSiteTypeByName(
    String name, {
    required String diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM site_types WHERE is_built_in = 0 AND diver_id = ? '
          'AND lower(trim(name)) = lower(trim(?)) ORDER BY id LIMIT 1',
          variables: [Variable.withString(diverId), Variable.withString(name)],
          readsFrom: {_db.siteTypes},
        )
        .get();
    if (rows.isEmpty) return null;
    return mapSiteTypeRow(_db.siteTypes.map(rows.single.data));
  }

  Future<SiteTypeEntity> createSiteType(SiteTypeEntity type) async {
    try {
      if (type.diverId == null) {
        throw Exception(
          'Cannot create a custom site type without a diver ID.',
        );
      }
      final slug = type.id.isEmpty
          ? SiteTypeEntity.generateSlug(type.name)
          : type.id;
      final uniqueId = await getSiteTypeById(slug) != null
          ? '${slug}_${_uuid.v4().substring(0, 8)}'
          : slug;
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSort = await _getMaxSortOrder();
      final sortOrder = type.sortOrder > 0 ? type.sortOrder : maxSort + 1;

      await _db
          .into(_db.siteTypes)
          .insert(
            SiteTypesCompanion(
              id: Value(uniqueId),
              diverId: Value(type.diverId),
              name: Value(type.name.trim()),
              isBuiltIn: const Value(false),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'siteTypes',
        recordId: uniqueId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return type.copyWith(
        id: uniqueId,
        name: type.name.trim(),
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to create site type', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateSiteType(SiteTypeEntity type) async {
    final existing = await getSiteTypeById(type.id);
    if (existing != null && existing.isBuiltIn) {
      throw Exception('Cannot update built-in site types');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.siteTypes,
    )..where((t) => t.id.equals(type.id))).write(
      SiteTypesCompanion(
        name: Value(type.name.trim()),
        sortOrder: Value(type.sortOrder),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'siteTypes',
      recordId: type.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a custom type and every site link to it. The junction has no
  /// foreign key to cascade through, so the links are deleted and tombstoned
  /// here, in the same transaction.
  Future<void> deleteSiteType(String id) async {
    final existing = await getSiteTypeById(id);
    if (existing != null && existing.isBuiltIn) {
      throw Exception('Cannot delete built-in site types');
    }
    await _db.transaction(() async {
      final links = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteTypeId.equals(id))).get();
      for (final link in links) {
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(link.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: link.id,
        );
      }
      await (_db.delete(_db.siteTypes)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'siteTypes', recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Every type [diverId] can see, with the number of sites using it.
  Future<List<SiteTypeStatistic>> getSiteTypeStatistics({
    String? diverId,
  }) async {
    final where = diverId != null
        ? 'WHERE st.is_built_in = 1 OR (st.is_built_in = 0 AND st.diver_id = ?)'
        : 'WHERE st.is_built_in = 1';
    final rows = await _db
        .customSelect(
          '''
      SELECT st.*, COUNT(sst.id) AS site_count
      FROM site_types st
      LEFT JOIN site_site_types sst ON sst.site_type_id = st.id
      $where
      GROUP BY st.id
      ORDER BY st.is_built_in DESC, st.sort_order, st.name
    ''',
          variables: [if (diverId != null) Variable.withString(diverId)],
          readsFrom: {_db.siteTypes, _db.siteSiteTypes},
        )
        .get();
    return [
      for (final row in rows)
        SiteTypeStatistic(
          siteType: mapSiteTypeRow(_db.siteTypes.map(row.data)),
          siteCount: row.read<int>('site_count'),
        ),
    ];
  }

  Future<int> _getMaxSortOrder() async {
    final result = await _db
        .customSelect('SELECT MAX(sort_order) AS max_order FROM site_types')
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }
}

class SiteTypeStatistic {
  final SiteTypeEntity siteType;
  final int siteCount;

  const SiteTypeStatistic({required this.siteType, required this.siteCount});
}
```

- [ ] **Step 5: Run the repository test**

Run: `flutter test test/features/site_types/data/repositories/site_type_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Display names (test first)**

Create `test/features/site_types/presentation/site_type_display_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('every built-in slug has a translated name', () {
    final l10n = AppLocalizationsEn();
    for (final t in kBuiltInSiteTypes) {
      expect(builtInSiteTypeName(l10n, t.id), t.name, reason: t.id);
    }
    expect(builtInSiteTypeName(l10n, 'mine'), isNull);
  });
}
```

Add to `app_en.arb` at the sorted position (the `siteType_builtin_*` block):

```json
  "siteType_builtin_artificial_reef": "Artificial reef",
  "siteType_builtin_blue_hole": "Blue hole",
  "siteType_builtin_cave": "Cave",
  "siteType_builtin_cavern": "Cavern",
  "siteType_builtin_cenote": "Cenote",
  "siteType_builtin_kelp_forest": "Kelp forest",
  "siteType_builtin_lake": "Lake",
  "siteType_builtin_muck": "Muck",
  "siteType_builtin_pier": "Pier / jetty",
  "siteType_builtin_pool": "Pool",
  "siteType_builtin_quarry": "Quarry",
  "siteType_builtin_reef": "Reef",
  "siteType_builtin_river": "River",
  "siteType_builtin_spring": "Spring",
  "siteType_builtin_wall": "Wall",
  "siteType_builtin_wreck": "Wreck",
```

Run `flutter gen-l10n`.

Create `lib/features/site_types/presentation/site_type_display.dart`:

```dart
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized names for the built-in site types, keyed on the stable slug.
///
/// Built-ins are stored with English names because exports carry the stored
/// name; on-screen callers resolve through here (the #643 lesson from dive
/// types). Returns null for anything that is not a built-in slug.
String? builtInSiteTypeName(AppLocalizations l10n, String id) => switch (id) {
  'reef' => l10n.siteType_builtin_reef,
  'wall' => l10n.siteType_builtin_wall,
  'wreck' => l10n.siteType_builtin_wreck,
  'artificial_reef' => l10n.siteType_builtin_artificial_reef,
  'cave' => l10n.siteType_builtin_cave,
  'cavern' => l10n.siteType_builtin_cavern,
  'cenote' => l10n.siteType_builtin_cenote,
  'blue_hole' => l10n.siteType_builtin_blue_hole,
  'lake' => l10n.siteType_builtin_lake,
  'quarry' => l10n.siteType_builtin_quarry,
  'river' => l10n.siteType_builtin_river,
  'spring' => l10n.siteType_builtin_spring,
  'pool' => l10n.siteType_builtin_pool,
  'pier' => l10n.siteType_builtin_pier,
  'muck' => l10n.siteType_builtin_muck,
  'kelp_forest' => l10n.siteType_builtin_kelp_forest,
  _ => null,
};

extension SiteTypeDisplay on SiteTypeEntity {
  /// The translated name for a built-in, the diver's own name otherwise.
  String localizedName(AppLocalizations l10n) =>
      isBuiltIn ? (builtInSiteTypeName(l10n, id) ?? name) : name;
}
```

Run: `flutter test test/features/site_types/presentation/site_type_display_test.dart`
Expected: PASS.

- [ ] **Step 7: Providers**

Create `lib/features/site_types/presentation/providers/site_type_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

final siteTypeRepositoryProvider = Provider<SiteTypeRepository>((ref) {
  return SiteTypeRepository();
});

/// Built-ins plus the current diver's custom types.
final siteTypesProvider = FutureProvider<List<SiteTypeEntity>>((ref) async {
  final repository = ref.watch(siteTypeRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSiteTypesChanges());
  return repository.getAllSiteTypes(diverId: diverId);
});

/// [siteTypesProvider] keyed by id, for resolving stored type ids.
final siteTypesByIdProvider = FutureProvider<Map<String, SiteTypeEntity>>((
  ref,
) async {
  final types = await ref.watch(siteTypesProvider.future);
  return {for (final t in types) t.id: t};
});

final siteTypeStatisticsProvider = FutureProvider<List<SiteTypeStatistic>>((
  ref,
) async {
  final repository = ref.watch(siteTypeRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSiteTypesChanges());
  return repository.getSiteTypeStatistics(diverId: diverId);
});

class SiteTypeListNotifier
    extends StateNotifier<AsyncValue<List<SiteTypeEntity>>> {
  final SiteTypeRepository _repository;
  final Ref _ref;

  SiteTypeListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(_load(), SiteTypeListNotifier, 'load');
    final sub = _repository.watchSiteTypesChanges().listen(
      (_) => logFailure(_load(), SiteTypeListNotifier, 'reload'),
    );
    _ref.onDispose(sub.cancel);
  }

  Future<void> _load() async {
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final types = await _repository.getAllSiteTypes(diverId: diverId);
      if (mounted) state = AsyncValue.data(types);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _invalidate() {
    _ref.invalidate(siteTypesProvider);
    _ref.invalidate(siteTypeStatisticsProvider);
  }

  Future<SiteTypeEntity> addSiteTypeByName(String name) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) {
      throw Exception('Cannot create a custom site type without a diver');
    }
    final created = await _repository.createSiteType(
      SiteTypeEntity.create(
        id: SiteTypeEntity.generateSlug(name),
        name: name.trim(),
        diverId: diverId,
      ),
    );
    await _load();
    _invalidate();
    return created;
  }

  Future<void> updateSiteType(SiteTypeEntity type) async {
    await _repository.updateSiteType(type);
    await _load();
    _invalidate();
  }

  Future<void> deleteSiteType(String id) async {
    await _repository.deleteSiteType(id);
    await _load();
    _invalidate();
  }
}

final siteTypeListNotifierProvider =
    StateNotifierProvider.autoDispose<
      SiteTypeListNotifier,
      AsyncValue<List<SiteTypeEntity>>
    >((ref) {
      final repository = ref.watch(siteTypeRepositoryProvider);
      ref.watch(currentDiverIdProvider);
      return SiteTypeListNotifier(repository, ref);
    });
```

- [ ] **Step 8: Diver deletion**

In `diver_repository.dart`, after the `DELETE FROM dive_types WHERE diver_id = ? AND is_built_in = 0` statement (line ~597), add:

```dart
        await _db.customStatement(
          'DELETE FROM site_types WHERE diver_id = ? AND is_built_in = 0',
          [id],
        );
```

Add a test to the existing diver deletion test file (find it with `grep -rln "DELETE FROM dive_types\|deleteDiver" test/features/divers`): insert a custom site type for the diver, delete the diver, assert `site_types` holds only built-ins.

- [ ] **Step 9: Run and commit**

Run: `flutter test test/features/site_types test/features/divers`
Expected: PASS.

```bash
dart format lib/features/site_types lib/features/divers test/features/site_types test/features/divers
git add lib/features/site_types lib/features/divers/data/repositories/diver_repository.dart lib/l10n/arb test/features/site_types test/features/divers
git commit -m "feat(sites): site type vocabulary with built-in and custom types (#1765)"
```

---

### Task 4: Tag scope

**Files:**
- Modify: `lib/features/tags/domain/entities/tag.dart`
- Create: `lib/features/tags/data/mappers/tag_row_mapper.dart`
- Modify: `lib/features/tags/data/repositories/tag_repository.dart`
- Modify: `lib/features/tags/presentation/providers/tag_providers.dart`
- Test: `test/features/tags/data/repositories/tag_scope_test.dart`

**Interfaces:**
- Consumes: Task 1 `Tags.appliesToDives` / `appliesToSites`, `siteTags` table.
- Produces:
  - `enum TagScope { dives, sites }`.
  - `Tag` fields `bool appliesToDives` (default `true`), `bool appliesToSites` (default `false`); `bool appliesTo(TagScope scope)`; `Tag.create(..., TagScope scope = TagScope.dives)`; `copyWith(appliesToDives:, appliesToSites:)`.
  - `domain.Tag mapTagRow(Tag row)`.
  - `TagRepository.getOrCreateTag(String name, {String? colorHex, String? diverId, TagScope scope = TagScope.dives})` widens an existing tag to [scope].
  - `TagRepository.getTagUsage(String tagId)` returns `({int dives, int sites})`.
  - `TagStatistic.siteCount` (int).
  - `TagListNotifier.getOrCreateTag(String name, {String? colorHex, TagScope scope = TagScope.dives})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/tags/data/repositories/tag_scope_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> linkSite(String siteId, String tagId) =>
      DatabaseService.instance.database.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st-$siteId-$tagId', '$siteId', '$tagId', 0)",
      );

  test('a tag created from the site picker applies to sites only', () async {
    final tag = await repository.getOrCreateTag('To try', scope: TagScope.sites);
    expect(tag.appliesToSites, isTrue);
    expect(tag.appliesToDives, isFalse);
  });

  test('a name collision widens the existing tag instead of failing', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final widened = await repository.getOrCreateTag(
      'night',
      scope: TagScope.sites,
    );

    expect(widened.id, diveTag.id);
    expect(widened.appliesToDives, isTrue);
    expect(widened.appliesToSites, isTrue);
    final stored = await repository.getTagById(diveTag.id);
    expect(stored!.appliesToSites, isTrue);
  });

  test('scope-filtered listing', () async {
    await repository.getOrCreateTag('Night');
    await repository.getOrCreateTag('To try', scope: TagScope.sites);

    final siteTags = await repository.getAllTags(scope: TagScope.sites);
    final diveTags = await repository.getAllTags(scope: TagScope.dives);
    expect(siteTags.map((t) => t.name), ['To try']);
    expect(diveTags.map((t) => t.name), ['Night']);
  });

  test('a tag must apply to at least one of dives and sites', () async {
    final tag = await repository.getOrCreateTag('Night');
    expect(
      () => repository.updateTag(
        tag.copyWith(appliesToDives: false, appliesToSites: false),
      ),
      throwsArgumentError,
    );
  });

  test('turning off sites removes and tombstones the site links', () async {
    final tag = await repository.getOrCreateTag('To try', scope: TagScope.sites);
    await repository.updateTag(tag.copyWith(appliesToDives: true));
    await linkSite('s1', tag.id);

    await repository.updateTag(
      tag.copyWith(appliesToDives: true, appliesToSites: false),
    );

    final db = DatabaseService.instance.database;
    expect(await db.select(db.siteTags).get(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'siteTags'",
        )
        .get();
    expect(tombstones, hasLength(1));
  });

  test('usage and statistics count dives and sites separately', () async {
    final tag = await repository.getOrCreateTag('To try', scope: TagScope.sites);
    await linkSite('s1', tag.id);

    expect(await repository.getTagUsage(tag.id), (dives: 0, sites: 1));
    final stats = await repository.getTagStatistics();
    final stat = stats.singleWhere((s) => s.tag.id == tag.id);
    expect(stat.siteCount, 1);
    expect(stat.diveCount, 0);
  });

  test('merging ORs the scopes and relinks site tags', () async {
    final survivor = await repository.getOrCreateTag('Night');
    final source = await repository.getOrCreateTag(
      'Avoid',
      scope: TagScope.sites,
    );
    await linkSite('s1', source.id);

    await repository.mergeTags(
      sourceTagIds: [source.id],
      survivingTagId: survivor.id,
      name: 'Night',
      colorHex: null,
    );

    final merged = await repository.getTagById(survivor.id);
    expect(merged!.appliesToDives, isTrue);
    expect(merged.appliesToSites, isTrue);
    final db = DatabaseService.instance.database;
    final links = await db.select(db.siteTags).get();
    expect(links.single.tagId, survivor.id);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/tags/data/repositories/tag_scope_test.dart`
Expected: FAIL to compile (`TagScope`, `scope:` unknown).

- [ ] **Step 3: Entity**

In `lib/features/tags/domain/entities/tag.dart`, add above `class Tag`:

```dart
/// Where a tag is offered (issue #1765). A tag applies to at least one.
enum TagScope { dives, sites }
```

Add the fields, constructor parameters, `create` parameter, `copyWith` parameters and props:

```dart
  final bool appliesToDives;
  final bool appliesToSites;
```
```dart
    this.appliesToDives = true,
    this.appliesToSites = false,
```
```dart
  bool appliesTo(TagScope scope) => switch (scope) {
    TagScope.dives => appliesToDives,
    TagScope.sites => appliesToSites,
  };
```

`Tag.create` gains `TagScope scope = TagScope.dives` and passes `appliesToDives: scope == TagScope.dives, appliesToSites: scope == TagScope.sites`. `copyWith` gains `bool? appliesToDives, bool? appliesToSites` resolved with `??`. Append both to `props`.

- [ ] **Step 4: Shared row mapper**

Create `lib/features/tags/data/mappers/tag_row_mapper.dart`:

```dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

domain.Tag mapTagRow(Tag row) {
  return domain.Tag(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    colorHex: row.color,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    appliesToDives: row.appliesToDives,
    appliesToSites: row.appliesToSites,
  );
}
```

In `tag_repository.dart`, replace `_mapRowToTag`'s body with `=> mapTagRow(row)` (or replace its call sites). Every inline `domain.Tag(...)` built from a `customSelect` row (`getTagsForDive` ~291, `getTagsForDives` ~333, `getTagStatistics` ~559) becomes `mapTagRow(_db.tags.map(row.data))`, so the new flags (and the `diverId` those inline builders dropped) are always mapped. Where those queries select explicit columns rather than `t.*`, change them to `t.*` so `_db.tags.map` finds every column.

- [ ] **Step 5: Repository scope rules**

`getAllTags` gains `TagScope? scope`:

```dart
  Future<List<domain.Tag>> getAllTags({String? diverId, TagScope? scope}) async {
    try {
      final query = _db.select(_db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }
      switch (scope) {
        case TagScope.dives:
          query.where((t) => t.appliesToDives.equals(true));
        case TagScope.sites:
          query.where((t) => t.appliesToSites.equals(true));
        case null:
          break;
      }
      final rows = await query.get();
      return rows.map(mapTagRow).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get tags', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
```

(`TagScope` comes from the `domain` import alias: write `domain.TagScope` if the file imports `tag.dart` only as `domain`.)

Add a widening helper and use it in `createTag`:

```dart
  /// Adds [scope] to [tag] if it lacks it, returning the stored result.
  Future<domain.Tag> _widen(domain.Tag tag, domain.TagScope scope) async {
    if (tag.appliesTo(scope)) return tag;
    final widened = tag.copyWith(
      appliesToDives: tag.appliesToDives || scope == domain.TagScope.dives,
      appliesToSites: tag.appliesToSites || scope == domain.TagScope.sites,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
      TagsCompanion(
        appliesToDives: Value(widened.appliesToDives),
        appliesToSites: Value(widened.appliesToSites),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'tags',
      recordId: tag.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return widened;
  }
```

In `createTag`, the incumbent branch becomes: if the incoming tag applies to sites and the incumbent does not, return `_widen(incumbent, TagScope.sites)`; likewise for dives; otherwise return the incumbent. Do the same in the `created == null` race branch. The insert companion gains `appliesToDives: Value(tag.appliesToDives), appliesToSites: Value(tag.appliesToSites)`. Throw `ArgumentError('A tag must apply to dives, sites, or both')` at the top when both flags are false.

`getOrCreateTag` gains `domain.TagScope scope = domain.TagScope.dives`: when `getTagByName` finds a tag, return `_widen(existing, scope)`; otherwise create with `domain.Tag.create(id: _uuid.v4(), name: name, colorHex: colorHex, diverId: diverId, scope: scope)`.

`updateTag`: at the top, throw `ArgumentError` when both flags are false. Read the stored row first; the write companion gains both flags. Then, inside the same method, if the stored tag applied to sites and the new one does not, delete every `site_tags` row for the tag and `logDeletion(entityType: 'siteTags', ...)` each; if it applied to dives and the new one does not, do the same for `dive_tags` with entity type `diveTags`. Wrap the write and the link removal in `_db.transaction`, and call `SyncEventBus.notifyLocalChange()` after it. The existing merge-on-rename branch runs first and is unchanged.

Add:

```dart
  /// How many dives and sites carry [tagId]; the scope editor confirms with
  /// these before narrowing a tag.
  Future<({int dives, int sites})> getTagUsage(String tagId) async {
    final row = await _db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM dive_tags WHERE tag_id = ?) AS dives, '
          '(SELECT COUNT(*) FROM site_tags WHERE tag_id = ?) AS sites',
          variables: [Variable.withString(tagId), Variable.withString(tagId)],
        )
        .getSingle();
    return (dives: row.read<int>('dives'), sites: row.read<int>('sites'));
  }
```

`getTagStatistics`: change the query to

```sql
SELECT t.*,
  (SELECT COUNT(*) FROM dive_tags dt WHERE dt.tag_id = t.id) AS dive_count,
  (SELECT COUNT(*) FROM site_tags st WHERE st.tag_id = t.id) AS site_count
FROM tags t
$diverFilter
ORDER BY dive_count + site_count DESC, t.name
```

and build `TagStatistic(tag: mapTagRow(_db.tags.map(row.data)), diveCount: row.read<int>('dive_count'), siteCount: row.read<int>('site_count'))`. `TagStatistic` gains `final int siteCount;` with a constructor default of `0`.

`mergeTags`: before deleting each source tag, compute the OR of scopes. Inside the transaction, read the survivor and source rows first; write the survivor companion with `appliesToDives: Value(anyDives)` and `appliesToSites: Value(anySites)`. Then, in the per-source loop, mirror the dive-tag relink for site tags:

```dart
          final sourceSiteTags = await (_db.select(
            _db.siteTags,
          )..where((t) => t.tagId.equals(sourceId))).get();
          for (final siteTag in sourceSiteTags) {
            if (!existingSurvivingSiteIds.contains(siteTag.siteId)) {
              final newId = _uuid.v4();
              await _db
                  .into(_db.siteTags)
                  .insert(
                    SiteTagsCompanion(
                      id: Value(newId),
                      siteId: Value(siteTag.siteId),
                      tagId: Value(survivingTagId),
                      createdAt: Value(now),
                    ),
                  );
              await _syncRepository.markRecordPending(
                entityType: 'siteTags',
                recordId: newId,
                localUpdatedAt: now,
              );
              existingSurvivingSiteIds.add(siteTag.siteId);
            }
            await (_db.delete(
              _db.siteTags,
            )..where((t) => t.id.equals(siteTag.id))).go();
            await _syncRepository.logDeletion(
              entityType: 'siteTags',
              recordId: siteTag.id,
            );
          }
```

with `existingSurvivingSiteIds` pre-fetched like `existingSurvivingDiveIds`. Sites are not re-stamped (clockless child rule).

- [ ] **Step 6: Providers**

In `tag_providers.dart`, `TagListNotifier.getOrCreateTag` gains `TagScope scope = TagScope.dives` and passes it through. `tagsProvider` stays unscoped (exports and the Manage page need every tag).

- [ ] **Step 7: Run the tag tests**

Run: `flutter test test/features/tags test/core/services/sync/sync_tag_identity_test.dart`
Expected: PASS. Fix any existing test that constructs `TagStatistic` positionally or compares `Tag` props.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/tags test/features/tags
git add lib/features/tags test/features/tags
git commit -m "feat(tags): scope each tag to dives, sites, or both (#1765)"
```

### Task 5: Site classification repository and site save integration

**Files:**
- Create: `lib/features/dive_sites/domain/entities/site_classification.dart`
- Create: `lib/features/dive_sites/data/repositories/site_classification_repository.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (createSite ~95, updateSite/_writeSiteUpdate ~155-238, mergeSites ~521-668, undoMerge ~675, MergeSnapshot, getSitesWithDiveCounts ~955)
- Modify: `lib/features/dive_sites/domain/entities/site_with_dive_count.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart` (sitesWithCountsProvider ~197, SiteListNotifier.addSite/updateSite ~451-467)
- Test: `test/features/dive_sites/data/repositories/site_classification_repository_test.dart`
- Test: `test/features/dive_sites/data/repositories/site_repository_classification_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 3 `SiteTypeEntity`/`mapSiteTypeRow`, Task 4 `mapTagRow`.
- Produces:
  - `class SiteClassification { const SiteClassification({List<String> typeIds = const [], List<String> tagIds = const []}); final List<String> typeIds; final List<String> tagIds; }`
  - `class SiteClassificationRepository` with `Stream<void> watchChanges()`, `Future<List<SiteTypeEntity>> getTypesForSite(String siteId)`, `Future<List<domain.Tag>> getTagsForSite(String siteId)`, `Future<Map<String, List<SiteTypeEntity>>> getTypesBySite()`, `Future<Map<String, List<domain.Tag>>> getTagsBySite()`, `Future<Map<String, List<String>>> getTypeIdsBySite(List<String> siteIds)`, `Future<Map<String, List<String>>> getTagIdsBySite(List<String> siteIds)`, `Future<void> replaceTypes(String siteId, List<String> typeIds, {bool notify = true})`, `Future<void> replaceTags(String siteId, List<String> tagIds, {bool notify = true})`, `Future<void> addTypes(String siteId, List<String> typeIds, {bool notify = true})`, `Future<void> addTags(String siteId, List<String> tagIds, {bool notify = true})`, `Future<void> relinkForMerge(List<String> duplicateIds, String survivorId)`.
  - `SiteRepository.createSite(DiveSite site, {SiteClassification? classification})`, `SiteRepository.updateSite(DiveSite site, {SiteClassification? classification})`.
  - `SiteWithDiveCount.siteTypes` (`List<SiteTypeEntity>`), `SiteWithDiveCount.tags` (`List<Tag>`).
  - `SiteListNotifier.addSite(DiveSite site, {SiteClassification? classification})`, `SiteListNotifier.updateSite(DiveSite site, {SiteClassification? classification})`.
  - Providers `siteClassificationRepositoryProvider`, `siteTypesForSiteProvider` (`FutureProvider.family<List<SiteTypeEntity>, String>`), `tagsForSiteProvider` (`FutureProvider.family<List<Tag>, String>`).

- [ ] **Step 1: Write the failing junction tests**

Create `test/features/dive_sites/data/repositories/site_classification_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteClassificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteClassificationRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0), ('s2', 'B', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1), ('t2', 'Avoid', 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  test('replaceTypes keeps the chosen order and reads it back', () async {
    await repository.replaceTypes('s1', ['wreck', 'lake']);
    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id), ['wreck', 'lake']);
  });

  test('replaceTypes removes only what left the set and tombstones it', () async {
    await repository.replaceTypes('s1', ['wreck', 'lake']);
    final before = await DatabaseService.instance.database
        .select(DatabaseService.instance.database.siteSiteTypes)
        .get();
    final wreckRowId = before.firstWhere((r) => r.siteTypeId == 'wreck').id;

    await repository.replaceTypes('s1', ['wreck', 'reef']);

    final after = await DatabaseService.instance.database
        .select(DatabaseService.instance.database.siteSiteTypes)
        .get();
    expect(after.map((r) => r.siteTypeId).toSet(), {'wreck', 'reef'});
    expect(
      after.firstWhere((r) => r.siteTypeId == 'wreck').id,
      wreckRowId,
      reason: 'an unchanged pair keeps its row',
    );
    final tombstones = await DatabaseService.instance.database
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteSiteTypes'",
        )
        .getSingle();
    expect(tombstones.read<int>('n'), 1);
  });

  test('addTypes unions and never removes', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.addTypes('s1', ['wreck', 'lake']);
    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id), ['wreck', 'lake']);
  });

  test('a junction change never marks the parent site pending', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTags('s1', ['t1']);

    final sitePending = await DatabaseService.instance.database
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records "
          "WHERE entity_type = 'diveSites'",
        )
        .getSingle();
    expect(sitePending.read<int>('n'), 0);
  });

  test('batch reads group by site', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTypes('s2', ['lake', 'reef']);
    await repository.replaceTags('s2', ['t2', 't1']);

    final types = await repository.getTypesBySite();
    final tags = await repository.getTagsBySite();
    expect(types['s1']!.map((t) => t.id), ['wreck']);
    expect(types['s2']!.map((t) => t.id), ['lake', 'reef']);
    expect(tags['s2']!.map((t) => t.name), ['Avoid', 'To try']);
    expect(tags.containsKey('s1'), isFalse);
  });

  test('relinkForMerge moves links and drops duplicates', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTypes('s2', ['wreck', 'lake']);
    await repository.replaceTags('s2', ['t1']);

    await repository.relinkForMerge(['s2'], 's1');

    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id).toSet(), {'wreck', 'lake'});
    expect(await repository.getTypesForSite('s2'), isEmpty);
    expect((await repository.getTagsForSite('s1')).single.id, 't1');
  });
}
```

(The raw SQL uses the `sync_records` and `deletion_log` column names `entity_type`, `record_id`; confirm them against `class SyncRecords` and `class DeletionLog` in `database.dart`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/data/repositories/site_classification_repository_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Value class**

Create `lib/features/dive_sites/domain/entities/site_classification.dart`:

```dart
import 'package:equatable/equatable.dart';

/// The type and tag ids a site should carry after a save (issue #1765).
/// Passed alongside a `DiveSite` rather than stored on it: several paths
/// save partially loaded sites (the #1187 wipe), and a field on the entity
/// would let each of them clear a site's types and tags.
class SiteClassification extends Equatable {
  final List<String> typeIds;
  final List<String> tagIds;

  const SiteClassification({this.typeIds = const [], this.tagIds = const []});

  @override
  List<Object?> get props => [typeIds, tagIds];
}
```

- [ ] **Step 4: Repository**

Create `lib/features/dive_sites/data/repositories/site_classification_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/site_types/data/mappers/site_type_row_mapper.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Reads and writes a site's types and tags (issue #1765): the
/// `site_site_types` and `site_tags` junctions.
///
/// Both are clockless children of the site. A change marks only the changed
/// junction rows pending and tombstones removed rows. It never marks the
/// parent site pending: a stale whole-row site snapshot from a peer must not
/// be able to overwrite a newer site edit (#1769).
///
/// Writers pass `notify: false` when they run inside a caller's transaction
/// and notify once themselves afterwards.
class SiteClassificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.siteSiteTypes,
      _db.siteTags,
      _db.siteTypes,
      _db.tags,
    ]),
  );

  Future<List<SiteTypeEntity>> getTypesForSite(String siteId) async {
    final rows = await _db
        .customSelect(
          'SELECT st.* FROM site_site_types sst '
          'JOIN site_types st ON st.id = sst.site_type_id '
          'WHERE sst.site_id = ? ORDER BY sst.created_at, sst.id',
          variables: [Variable.withString(siteId)],
          readsFrom: {_db.siteSiteTypes, _db.siteTypes},
        )
        .get();
    return [for (final r in rows) mapSiteTypeRow(_db.siteTypes.map(r.data))];
  }

  Future<List<domain.Tag>> getTagsForSite(String siteId) async {
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM site_tags stg JOIN tags t ON t.id = stg.tag_id '
          'WHERE stg.site_id = ? ORDER BY t.name',
          variables: [Variable.withString(siteId)],
          readsFrom: {_db.siteTags, _db.tags},
        )
        .get();
    return [for (final r in rows) mapTagRow(_db.tags.map(r.data))];
  }

  /// Every site's types, in each site's own order. A row pointing at a
  /// custom type that has not arrived by sync yet is skipped by the join.
  Future<Map<String, List<SiteTypeEntity>>> getTypesBySite() async {
    final rows = await _db
        .customSelect(
          'SELECT sst.site_id AS link_site_id, st.* FROM site_site_types sst '
          'JOIN site_types st ON st.id = sst.site_type_id '
          'ORDER BY sst.site_id, sst.created_at, sst.id',
          readsFrom: {_db.siteSiteTypes, _db.siteTypes},
        )
        .get();
    final bySite = <String, List<SiteTypeEntity>>{};
    for (final r in rows) {
      bySite
          .putIfAbsent(r.read<String>('link_site_id'), () => [])
          .add(mapSiteTypeRow(_db.siteTypes.map(r.data)));
    }
    return bySite;
  }

  Future<Map<String, List<domain.Tag>>> getTagsBySite() async {
    final rows = await _db
        .customSelect(
          'SELECT stg.site_id AS link_site_id, t.* FROM site_tags stg '
          'JOIN tags t ON t.id = stg.tag_id ORDER BY stg.site_id, t.name',
          readsFrom: {_db.siteTags, _db.tags},
        )
        .get();
    final bySite = <String, List<domain.Tag>>{};
    for (final r in rows) {
      bySite
          .putIfAbsent(r.read<String>('link_site_id'), () => [])
          .add(mapTagRow(_db.tags.map(r.data)));
    }
    return bySite;
  }

  /// Type ids per site for [siteIds], raw (no join), for merge snapshots and
  /// exports.
  Future<Map<String, List<String>>> getTypeIdsBySite(
    List<String> siteIds,
  ) async {
    final rows =
        await (_db.select(_db.siteSiteTypes)
              ..where((t) => t.siteId.isIn(siteIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final bySite = <String, List<String>>{};
    for (final r in rows) {
      bySite.putIfAbsent(r.siteId, () => []).add(r.siteTypeId);
    }
    return bySite;
  }

  Future<Map<String, List<String>>> getTagIdsBySite(
    List<String> siteIds,
  ) async {
    final rows = await (_db.select(
      _db.siteTags,
    )..where((t) => t.siteId.isIn(siteIds))).get();
    final bySite = <String, List<String>>{};
    for (final r in rows) {
      bySite.putIfAbsent(r.siteId, () => []).add(r.tagId);
    }
    return bySite;
  }

  /// Makes [siteId]'s types exactly [typeIds]. Rows for types that stay are
  /// left alone, so their ids, clocks and order survive the save.
  Future<void> replaceTypes(
    String siteId,
    List<String> typeIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = typeIds.toSet();
      final existing = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(siteId))).get();
      for (final row in existing) {
        if (wanted.contains(row.siteTypeId)) continue;
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: row.id,
        );
      }
      final have = {for (final r in existing) r.siteTypeId};
      await _insertTypes(siteId, [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Adds [typeIds] to [siteId]'s types; never removes one.
  Future<void> addTypes(
    String siteId,
    List<String> typeIds, {
    bool notify = true,
  }) async {
    if (typeIds.isEmpty) return;
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(siteId))).get();
      final have = {for (final r in existing) r.siteTypeId};
      await _insertTypes(siteId, [
        for (final id in typeIds.toSet())
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  Future<void> replaceTags(
    String siteId,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = tagIds.toSet();
      final existing = await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(siteId))).get();
      for (final row in existing) {
        if (wanted.contains(row.tagId)) continue;
        await (_db.delete(_db.siteTags)..where((t) => t.id.equals(row.id)))
            .go();
        await _syncRepository.logDeletion(
          entityType: 'siteTags',
          recordId: row.id,
        );
      }
      final have = {for (final r in existing) r.tagId};
      await _insertTags(siteId, [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  Future<void> addTags(
    String siteId,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    if (tagIds.isEmpty) return;
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(siteId))).get();
      final have = {for (final r in existing) r.tagId};
      await _insertTags(siteId, [
        for (final id in tagIds.toSet())
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Moves the duplicates' links onto [survivorId] during a site merge.
  /// Runs inside the merge transaction, so it does not notify. A pair the
  /// survivor already holds is deleted and tombstoned instead of moved.
  Future<void> relinkForMerge(
    List<String> duplicateIds,
    String survivorId,
  ) async {
    if (duplicateIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    final haveTypes = {
      for (final r in await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(survivorId))).get())
        r.siteTypeId,
    };
    final dupTypes = await (_db.select(
      _db.siteSiteTypes,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();
    for (final row in dupTypes) {
      if (haveTypes.add(row.siteTypeId)) {
        await (_db.update(_db.siteSiteTypes)..where((t) => t.id.equals(row.id)))
            .write(SiteSiteTypesCompanion(siteId: Value(survivorId)));
        await _syncRepository.markRecordPending(
          entityType: 'siteSiteTypes',
          recordId: row.id,
          localUpdatedAt: now,
        );
      } else {
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: row.id,
        );
      }
    }

    final haveTags = {
      for (final r in await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(survivorId))).get())
        r.tagId,
    };
    final dupTags = await (_db.select(
      _db.siteTags,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();
    for (final row in dupTags) {
      if (haveTags.add(row.tagId)) {
        await (_db.update(_db.siteTags)..where((t) => t.id.equals(row.id)))
            .write(SiteTagsCompanion(siteId: Value(survivorId)));
        await _syncRepository.markRecordPending(
          entityType: 'siteTags',
          recordId: row.id,
          localUpdatedAt: now,
        );
      } else {
        await (_db.delete(_db.siteTags)..where((t) => t.id.equals(row.id)))
            .go();
        await _syncRepository.logDeletion(
          entityType: 'siteTags',
          recordId: row.id,
        );
      }
    }
  }

  /// Inserts in the given order: `created_at` is `now + index`, because the
  /// read order is `created_at, id` and a shared timestamp would leave the
  /// order to random uuids.
  Future<void> _insertTypes(String siteId, List<String> typeIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < typeIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.siteSiteTypes)
          .insertReturningOrNull(
            SiteSiteTypesCompanion.insert(
              id: id,
              siteId: siteId,
              siteTypeId: typeIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$SiteSiteTypesTable, SiteSiteType>(
              target: const [],
            ),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: 'siteSiteTypes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _insertTags(String siteId, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < tagIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.siteTags)
          .insertReturningOrNull(
            SiteTagsCompanion.insert(
              id: id,
              siteId: siteId,
              tagId: tagIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$SiteTagsTable, SiteTag>(target: const []),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: 'siteTags',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
}
```

Run: `flutter test test/features/dive_sites/data/repositories/site_classification_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing site repository tests**

Create `test/features/dive_sites/data/repositories/site_repository_classification_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository sites;
  late SiteClassificationRepository classification;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
    classification = SiteClassificationRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  test('createSite writes the classification with the row', () async {
    final site = await sites.createSite(
      const DiveSite(id: '', name: 'Lake wreck'),
      classification: const SiteClassification(
        typeIds: ['wreck', 'lake'],
        tagIds: ['t1'],
      ),
    );

    expect(
      (await classification.getTypesForSite(site.id)).map((t) => t.id),
      ['wreck', 'lake'],
    );
    expect((await classification.getTagsForSite(site.id)).single.id, 't1');
  });

  test('updateSite without a classification leaves the junctions (#1187)', () async {
    final site = await sites.createSite(
      const DiveSite(id: '', name: 'Reef'),
      classification: const SiteClassification(typeIds: ['reef']),
    );

    // A partially loaded entity, as the dive hydration and importers build.
    await sites.updateSite(DiveSite(id: site.id, name: 'Reef renamed'));

    expect(
      (await classification.getTypesForSite(site.id)).map((t) => t.id),
      ['reef'],
    );
  });

  test('a failing classification write rolls back the site row', () async {
    await expectLater(
      sites.createSite(
        const DiveSite(id: 'fixed', name: 'Doomed'),
        // A tag id with no tags row violates the site_tags foreign key.
        classification: const SiteClassification(tagIds: ['missing']),
      ),
      throwsA(anything),
    );
    expect(await sites.getSiteById('fixed'), isNull);
  });

  test('mergeSites unions types and tags; undo restores each site', () async {
    final a = await sites.createSite(
      const DiveSite(id: '', name: 'A'),
      classification: const SiteClassification(typeIds: ['wreck']),
    );
    final b = await sites.createSite(
      const DiveSite(id: '', name: 'B'),
      classification: const SiteClassification(
        typeIds: ['lake'],
        tagIds: ['t1'],
      ),
    );

    final snapshot = await sites.mergeSites(a, [a.id, b.id]);

    expect(
      (await classification.getTypesForSite(a.id)).map((t) => t.id).toSet(),
      {'wreck', 'lake'},
    );
    expect((await classification.getTagsForSite(a.id)).single.id, 't1');

    await sites.undoMerge(snapshot!);

    expect(
      (await classification.getTypesForSite(a.id)).map((t) => t.id),
      ['wreck'],
    );
    expect(
      (await classification.getTypesForSite(b.id)).map((t) => t.id),
      ['lake'],
    );
    expect((await classification.getTagsForSite(b.id)).single.id, 't1');
  });

  test('the site list carries types and tags', () async {
    await sites.createSite(
      const DiveSite(id: '', name: 'Typed'),
      classification: const SiteClassification(
        typeIds: ['cave'],
        tagIds: ['t1'],
      ),
    );

    final list = await sites.getSitesWithDiveCounts();
    final entry = list.single;
    expect(entry.siteTypes.map((t) => t.id), ['cave']);
    expect(entry.tags.map((t) => t.name), ['To try']);
  });

  test('the site list statement count does not grow with the site count', () async {
    Future<int> countStatements() async {
      var count = 0;
      await runZoned(
        () => sites.getSitesWithDiveCounts(),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            if (line.startsWith('Drift: Sent')) count++;
          },
        ),
      );
      return count;
    }

    // Switch to a statement-logging database (see the `count-sql` recipe:
    // NativeDatabase.memory(logStatements: true) prints each statement).
    await tearDownTestDatabase();
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase.memory(logStatements: true)),
    );
    sites = SiteRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1)",
    );

    await sites.createSite(
      const DiveSite(id: '', name: 'One'),
      classification: const SiteClassification(typeIds: ['cave'], tagIds: ['t1']),
    );
    final one = await countStatements();
    for (var i = 0; i < 5; i++) {
      await sites.createSite(
        DiveSite(id: '', name: 'More $i'),
        classification: const SiteClassification(
          typeIds: ['wreck'],
          tagIds: ['t1'],
        ),
      );
    }
    final six = await countStatements();
    expect(six, one);
  });
}
```

Add `import 'dart:async';` and `import 'package:submersion/core/database/database.dart';` for `runZoned` and `AppDatabase`. Read an existing Drift statement log line to confirm the `Drift: Sent` prefix before relying on it. If `getSiteById` has another name in `SiteRepository`, use it. If the `DiveSite` constructor requires other arguments, pass them.

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_classification_test.dart`
Expected: FAIL (no `classification:` parameter; `siteTypes` unknown on `SiteWithDiveCount`).

- [ ] **Step 7: `SiteWithDiveCount`**

Add to `site_with_dive_count.dart` (imports for `SiteTypeEntity` and `Tag`):

```dart
  /// The site's types in the diver's chosen order (issue #1765).
  final List<SiteTypeEntity> siteTypes;

  /// The site's tags, by name (issue #1765).
  final List<Tag> tags;
```

Constructor defaults `this.siteTypes = const []`, `this.tags = const []`; `copyWith` parameters `List<SiteTypeEntity>? siteTypes, List<Tag>? tags`; append both to `props`.

- [ ] **Step 8: `SiteRepository`**

Add a field (next to `_syncRepository`):

```dart
  final SiteClassificationRepository _classification =
      SiteClassificationRepository();
```

`createSite(domain.DiveSite site, {SiteClassification? classification})`: wrap the existing insert and `markRecordPending` in `await _db.transaction(() async { ... });`, and inside it, after `markRecordPending`:

```dart
        if (classification != null) {
          await _classification.replaceTypes(
            id,
            classification.typeIds,
            notify: false,
          );
          await _classification.replaceTags(
            id,
            classification.tagIds,
            notify: false,
          );
        }
```

`SyncEventBus.notifyLocalChange()` stays after the transaction.

`updateSite(domain.DiveSite site, {SiteClassification? classification}) => _writeSiteUpdate(site, classification: classification);`. `_writeSiteUpdate` gains `SiteClassification? classification`, wraps its update and `markRecordPending` in a transaction, and writes the classification the same way when it is non-null. `updateSiteWithImportedMetadata` passes no classification.

`MergeSnapshot` gains:

```dart
  /// Each merged site's type ids and tag ids before the merge (issue #1765),
  /// so undo can put every site's classification back.
  final Map<String, List<String>> siteTypeIdsBySite;
  final Map<String, List<String>> siteTagIdsBySite;
```

(constructor defaults `const {}`).

In `mergeSites`, before the transaction, next to the other snapshots:

```dart
      final typeIdsBySite = await _classification.getTypeIdsBySite(orderedIds);
      final tagIdsBySite = await _classification.getTagIdsBySite(orderedIds);
```

pass them into the `MergeSnapshot`, and inside the transaction, after `_mergeExpectedSpecies(...)` and before the duplicate-site delete loop:

```dart
        await _classification.relinkForMerge(duplicateIds, survivorId);
```

In `undoMerge`, inside its transaction after the deleted sites are re-inserted, restore every site's sets (sites with no entry get an empty set):

```dart
        final restoredIds = {
          snapshot.originalSurvivor.id,
          for (final s in snapshot.deletedSites) s.id,
        };
        for (final siteId in restoredIds) {
          await _classification.replaceTypes(
            siteId,
            snapshot.siteTypeIdsBySite[siteId] ?? const [],
            notify: false,
          );
          await _classification.replaceTags(
            siteId,
            snapshot.siteTagIdsBySite[siteId] ?? const [],
            notify: false,
          );
        }
```

In `getSitesWithDiveCounts`, next to `getFeatureTypesBySite()`:

```dart
        final typesBySite = await _classification.getTypesBySite();
        final tagsBySite = await _classification.getTagsBySite();
```

and pass `siteTypes: typesBySite[site.id] ?? const [], tags: tagsBySite[site.id] ?? const [],` to `SiteWithDiveCount`.

- [ ] **Step 9: Providers**

In `site_providers.dart`:

```dart
final siteClassificationRepositoryProvider =
    Provider<SiteClassificationRepository>((ref) {
      return SiteClassificationRepository();
    });

final siteTypesForSiteProvider =
    FutureProvider.family<List<SiteTypeEntity>, String>((ref, siteId) async {
      final repository = ref.watch(siteClassificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getTypesForSite(siteId);
    });

final tagsForSiteProvider = FutureProvider.family<List<Tag>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(siteClassificationRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getTagsForSite(siteId);
});
```

In `sitesWithCountsProvider` (~204-210), add `ref.invalidateSelfWhen(ref.read(siteClassificationRepositoryProvider).watchChanges());` next to the feature-change invalidation.

`SiteListNotifier.addSite(domain.DiveSite site, {SiteClassification? classification})` passes `classification` to `_repository.createSite`; `updateSite` likewise to `_repository.updateSite`.

- [ ] **Step 10: Run and commit**

Run: `flutter test test/features/dive_sites/data/repositories`
Expected: PASS (including the existing merge tests).

```bash
dart format lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites/domain/entities/site_classification.dart lib/features/dive_sites/data/repositories/site_classification_repository.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart lib/features/dive_sites/domain/entities/site_with_dive_count.dart lib/features/dive_sites/presentation/providers/site_providers.dart test/features/dive_sites/data/repositories
git commit -m "feat(sites): read and write site types and tags with the site (#1765)"
```

---

### Task 6: Site edit page Type & Tags section

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (state fields, initState loading, `_buildForm` ~960-1093, `_saveSite` ~1637-1831)
- Modify: `lib/features/tags/presentation/widgets/tag_input_widget.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart`
- Test: `test/features/tags/presentation/widgets/tag_input_widget_scope_test.dart`

**Interfaces:**
- Consumes: Task 3 `siteTypesProvider`, `SiteTypeDisplay.localizedName`; Task 4 `TagScope`, `TagListNotifier.getOrCreateTag(scope:)`; Task 5 `SiteClassification`, `siteTypesForSiteProvider`, `tagsForSiteProvider`, `SiteListNotifier.addSite/updateSite(classification:)`.
- Produces: `TagInputWidget({required selectedTags, required onTagsChanged, bool enabled = true, TagScope scope = TagScope.dives})`; `TypeTagsSection({required List<SiteTypeEntity> allTypes, required Set<String> selectedTypeIds, required ValueChanged<Set<String>> onTypesChanged, required List<Tag> selectedTags, required ValueChanged<List<Tag>> onTagsChanged, VoidCallback? onManageTypes})`.

- [ ] **Step 1: English strings**

Add to `app_en.arb` at sorted positions:

```json
  "diveSites_edit_group_typeTags": "Type & Tags",
  "diveSites_edit_typeTags_manageTypes": "Manage types",
  "diveSites_edit_typeTags_tagsLabel": "Tags",
  "diveSites_edit_typeTags_typesLabel": "Site types",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget tests**

Create `test/features/tags/presentation/widgets/tag_input_widget_scope_test.dart`. Copy the `ProviderScope` + `MaterialApp` pumping pattern and database setup from `test/features/dive_types/presentation/pages/dive_types_page_test.dart` (lines 11-51), then:

```dart
  testWidgets('site scope lists only site tags and creates site tags', (
    tester,
  ) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO tags (id, diver_id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) VALUES "
      "('d', 'diver-1', 'Night', 0, 0, 1, 0), "
      "('s', 'diver-1', 'To try', 0, 0, 0, 1)",
    );
    var picked = <Tag>[];

    await tester.pumpWidget(
      buildHarness(
        TagInputWidget(
          selectedTags: const [],
          onTagsChanged: (tags) => picked = tags,
          scope: TagScope.sites,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'T');
    await tester.pumpAndSettle();
    expect(find.text('To try'), findsOneWidget);
    expect(find.text('Night'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Avoid');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked.single.name, 'Avoid');
    expect(picked.single.appliesToSites, isTrue);
    expect(picked.single.appliesToDives, isFalse);
  });
```

`buildHarness` is the file's version of `_buildPage` with the widget in a `Scaffold` body. If `TagInputWidget` submits a new tag through a "Create" suggestion tile rather than the keyboard action, tap that tile instead (read the widget's build method).

Create `test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart` with the same harness:

```dart
  testWidgets('toggling a type chip reports the new selection', (tester) async {
    Set<String>? reported;
    final now = DateTime(2026);
    final types = [
      SiteTypeEntity(id: 'wreck', name: 'Wreck', isBuiltIn: true, createdAt: now, updatedAt: now),
      SiteTypeEntity(id: 'lake', name: 'Lake', isBuiltIn: true, createdAt: now, updatedAt: now),
    ];

    await tester.pumpWidget(
      buildHarness(
        TypeTagsSection(
          allTypes: types,
          selectedTypeIds: const {'wreck'},
          onTypesChanged: (ids) => reported = ids,
          selectedTags: const [],
          onTagsChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Lake'));
    await tester.pump();
    expect(reported, {'wreck', 'lake'});

    await tester.tap(find.widgetWithText(FilterChip, 'Wreck'));
    await tester.pump();
    expect(reported, isNot(contains('wreck')));
  });
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/tags/presentation/widgets/tag_input_widget_scope_test.dart test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: `TagInputWidget` scope**

Add `final TagScope scope;` with constructor default `this.scope = TagScope.dives`. In `_createAndAddTag`, pass `scope: widget.scope` to `getOrCreateTag`. In the suggestion builder (lines ~141-154), filter the source list first:

```dart
              data: (unscoped) {
                final allTags = unscoped
                    .where((tag) => tag.appliesTo(widget.scope))
                    .toList();
```

Keep the rest of the builder unchanged: `exactMatch` over the scoped list means typing a dive-only tag's name from the site picker still offers "create", and `getOrCreateTag` widens that tag instead of duplicating it.

- [ ] **Step 5: `TypeTagsSection`**

Create `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site types (multi-select chips) and site tags (issue #1765).
class TypeTagsSection extends StatelessWidget {
  const TypeTagsSection({
    super.key,
    required this.allTypes,
    required this.selectedTypeIds,
    required this.onTypesChanged,
    required this.selectedTags,
    required this.onTagsChanged,
    this.onManageTypes,
  });

  final List<SiteTypeEntity> allTypes;
  final Set<String> selectedTypeIds;
  final ValueChanged<Set<String>> onTypesChanged;
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;
  final VoidCallback? onManageTypes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FormSection(
      label: l10n.diveSites_edit_group_typeTags,
      icon: Icons.category_outlined,
      expanded: true,
      onToggle: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.diveSites_edit_typeTags_typesLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final type in allTypes)
                FilterChip(
                  label: Text(type.localizedName(l10n)),
                  selected: selectedTypeIds.contains(type.id),
                  onSelected: (selected) {
                    final next = {...selectedTypeIds};
                    selected ? next.add(type.id) : next.remove(type.id);
                    onTypesChanged(next);
                  },
                ),
              if (onManageTypes != null)
                TextButton.icon(
                  onPressed: onManageTypes,
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l10n.diveSites_edit_typeTags_manageTypes),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.diveSites_edit_typeTags_tagsLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TagInputWidget(
            selectedTags: selectedTags,
            onTagsChanged: onTagsChanged,
            scope: TagScope.sites,
          ),
        ],
      ),
    );
  }
}
```

Check `FormSection`'s real import path and parameter names against `identity_section.dart` (it passes `label`, `icon`, `expanded`, `onToggle`, `errorCount` and a child). Adjust the parameter name for the body (`child` vs `children`) to match.

- [ ] **Step 6: Wire the edit page**

In `_SiteEditPageState`, add state:

```dart
  Set<String> _selectedTypeIds = {};
  List<Tag> _selectedTags = [];
  Set<String> _originalTypeIds = {};
  Set<String> _originalTagIds = {};
```

Where the page loads the existing site for editing (the code that fills the controllers from `_originalSite`), also load:

```dart
      final types = await ref.read(siteTypesForSiteProvider(siteId).future);
      final tags = await ref.read(tagsForSiteProvider(siteId).future);
      if (!mounted) return;
      setState(() {
        _selectedTypeIds = {for (final t in types) t.id};
        _originalTypeIds = {..._selectedTypeIds};
        _selectedTags = tags;
        _originalTagIds = {for (final t in tags) t.id};
      });
```

In `_buildForm`, insert after `IdentitySection(...)`, only when not merging:

```dart
                if (!widget.isMerging)
                  TypeTagsSection(
                    allTypes: ref.watch(siteTypesProvider).valueOrNull ?? const [],
                    selectedTypeIds: _selectedTypeIds,
                    onTypesChanged: (ids) => setState(() {
                      _selectedTypeIds = ids;
                      _hasChanges = true;
                    }),
                    selectedTags: _selectedTags,
                    onTagsChanged: (tags) => setState(() {
                      _selectedTags = tags;
                      _hasChanges = true;
                    }),
                    onManageTypes: () => context.push('/site-types'),
                  ),
```

and change `ResponsiveFormColumns(splitIndex: 2, ...)` to `splitIndex: widget.isMerging ? 2 : 3` so Location stays in the left column. Use whatever change-tracking the page already uses in place of `_hasChanges = true` if it differs.

In `_saveSite`, build the classification once (after `site` is built):

```dart
      final classificationChanged =
          !widget.isEditing ||
          !setEquals(_selectedTypeIds, _originalTypeIds) ||
          !setEquals({for (final t in _selectedTags) t.id}, _originalTagIds);
      final classification = classificationChanged
          ? SiteClassification(
              typeIds: _selectedTypeIds.toList(),
              tagIds: [for (final t in _selectedTags) t.id],
            )
          : null;
```

(`setEquals` from `package:flutter/foundation.dart`.) Pass `classification: classification` to `notifier.updateSite(site, ...)` and `notifier.addSite(site, ...)`. The merge branch is unchanged. After the save, next to the other invalidations, add `ref.invalidate(siteTypesForSiteProvider(savedId)); ref.invalidate(tagsForSiteProvider(savedId));`.

`_selectedTypeIds` is a `Set` literal built in chip order of taps; the repository preserves the list order, so types read back in the order the diver picked them.

- [ ] **Step 7: Run and commit**

Run: `flutter test test/features/tags/presentation test/features/dive_sites/presentation`
Expected: PASS. If an existing site edit page test fails because the page now watches `siteTypesProvider`, add the database-backed provider setup or an override (`siteTypesProvider.overrideWith((ref) async => const [])`) to that test.

```bash
dart format lib/features test/features
git add lib/features/dive_sites/presentation lib/features/tags/presentation/widgets/tag_input_widget.dart lib/l10n/arb test/features/dive_sites/presentation test/features/tags/presentation
git commit -m "feat(sites): edit site types and tags on the site edit page (#1765)"
```

### Task 7: Site filters and detail page chips

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart:35-165` (`SiteFilterState`)
- Modify: `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_classification_chips.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:175-204, 364-383`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_classification_chips_test.dart`

**Interfaces:**
- Consumes: Task 5 `SiteWithDiveCount.siteTypes/tags`, `siteTypesForSiteProvider`, `tagsForSiteProvider`; Task 3 `siteTypesProvider`; Task 4 `TagScope`.
- Produces: `SiteFilterState.siteTypeIds` (`Set<String>`, default `const {}`), `SiteFilterState.tagIds` (`Set<String>`, default `const {}`); `SiteClassificationChips({required String siteId})`.

- [ ] **Step 1: Write the failing filter test**

Create `test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  final now = DateTime(2026);
  SiteTypeEntity type(String id) => SiteTypeEntity(
    id: id,
    name: id,
    isBuiltIn: true,
    createdAt: now,
    updatedAt: now,
  );
  Tag tag(String id) =>
      Tag(id: id, name: id, createdAt: now, updatedAt: now, appliesToSites: true);
  SiteWithDiveCount site(String id, {List<String> types = const [], List<String> tags = const []}) =>
      SiteWithDiveCount(
        site: DiveSite(id: id, name: id),
        diveCount: 0,
        siteTypes: [for (final t in types) type(t)],
        tags: [for (final t in tags) tag(t)],
      );

  final sites = [
    site('lakeWreck', types: ['lake', 'wreck'], tags: ['try']),
    site('reef', types: ['reef'], tags: ['avoid']),
    site('bare'),
  ];

  List<String> ids(SiteFilterState f) =>
      f.apply(sites).map((s) => s.site.id).toList();

  test('type filter matches any of the chosen types', () {
    expect(ids(const SiteFilterState(siteTypeIds: {'wreck', 'reef'})), [
      'lakeWreck',
      'reef',
    ]);
  });

  test('tag filter matches any of the chosen tags', () {
    expect(ids(const SiteFilterState(tagIds: {'try'})), ['lakeWreck']);
  });

  test('type and tag filters combine with AND', () {
    expect(
      ids(const SiteFilterState(siteTypeIds: {'reef'}, tagIds: {'try'})),
      isEmpty,
    );
  });

  test('empty sets are inactive and copyWith can clear them', () {
    expect(const SiteFilterState().hasActiveFilters, isFalse);
    const f = SiteFilterState(siteTypeIds: {'lake'});
    expect(f.hasActiveFilters, isTrue);
    expect(f.copyWith(siteTypeIds: const {}).hasActiveFilters, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart`
Expected: FAIL (no `siteTypeIds` parameter).

- [ ] **Step 3: `SiteFilterState`**

Add fields `final Set<String> siteTypeIds;` and `final Set<String> tagIds;`, constructor defaults `this.siteTypeIds = const {}`, `this.tagIds = const {}`. Append to `hasActiveFilters`: `|| siteTypeIds.isNotEmpty || tagIds.isNotEmpty`. In `apply`, before `return true;`:

```dart
      // Site type and tag filters (issue #1765): any-of within each set.
      if (siteTypeIds.isNotEmpty &&
          !siteWithCount.siteTypes.any((t) => siteTypeIds.contains(t.id))) {
        return false;
      }
      if (tagIds.isNotEmpty &&
          !siteWithCount.tags.any((t) => tagIds.contains(t.id))) {
        return false;
      }
```

`copyWith` gains `Set<String>? siteTypeIds, Set<String>? tagIds` (a non-null value replaces, so `const {}` clears) and passes `siteTypeIds: siteTypeIds ?? this.siteTypeIds, tagIds: tagIds ?? this.tagIds`.

Run the test: PASS.

- [ ] **Step 4: Filter sheet**

Add English strings (sorted positions):

```json
  "diveSites_filter_section_siteTypes": "Site type",
  "diveSites_filter_section_tags": "Tags",
```

Run `flutter gen-l10n`.

In `site_filter_sheet.dart`: state fields `Set<String> _siteTypeIds = {};` and `Set<String> _tagIds = {};` initialized from `widget.ref.read(siteFilterProvider)` in `initState`; add `_buildSiteTypeSection()` and `_buildTagSection()` to the section list after `_buildDifficultySection()` (each followed by `const SizedBox(height: 24)`); include both in `_clearAll` (reset to `{}`) and `_applyFilters` (`siteTypeIds: _siteTypeIds, tagIds: _tagIds`).

```dart
  Widget _buildSiteTypeSection() {
    final types = widget.ref.watch(siteTypesProvider).valueOrNull ?? const [];
    if (types.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_siteTypes,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in types)
              FilterChip(
                label: Text(type.localizedName(context.l10n)),
                selected: _siteTypeIds.contains(type.id),
                onSelected: (selected) => setState(() {
                  _siteTypeIds = {..._siteTypeIds};
                  selected
                      ? _siteTypeIds.add(type.id)
                      : _siteTypeIds.remove(type.id);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagSection() {
    final tags = (widget.ref.watch(tagsProvider).valueOrNull ?? const <Tag>[])
        .where((t) => t.appliesToSites)
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_tags,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: tag.color, radius: 6),
                label: Text(tag.name),
                selected: _tagIds.contains(tag.id),
                onSelected: (selected) => setState(() {
                  _tagIds = {..._tagIds};
                  selected ? _tagIds.add(tag.id) : _tagIds.remove(tag.id);
                }),
              ),
          ],
        ),
      ],
    );
  }
```

The sheet holds a `WidgetRef` (`widget.ref`); if `watch` through it does not rebuild the sheet's own state, switch the sheet state class to `ConsumerState` and use `ref.watch` (read the class declaration first). The site list's active-filter bar (`_buildActiveFiltersBar` in `site_list_content.dart`) gets one chip per active type and tag, following how it renders the difficulty chip, each clearing its id with `copyWith`.

- [ ] **Step 5: Detail chips (test first)**

Create `test/features/dive_sites/presentation/widgets/site_classification_chips_test.dart`, using the `ProviderScope` harness pattern and overrides:

```dart
  testWidgets('shows types then tags; tapping filters the site list', (
    tester,
  ) async {
    final now = DateTime(2026);
    final container = ProviderContainer(
      overrides: [
        siteTypesForSiteProvider('s1').overrideWith(
          (ref) async => [
            SiteTypeEntity(id: 'wreck', name: 'Wreck', isBuiltIn: true, createdAt: now, updatedAt: now),
          ],
        ),
        tagsForSiteProvider('s1').overrideWith(
          (ref) async => [
            Tag(id: 't1', name: 'To try', createdAt: now, updatedAt: now, appliesToSites: true),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/sites/s1',
      routes: [
        GoRoute(path: '/sites', builder: (_, _) => const Text('site list')),
        GoRoute(
          path: '/sites/:id',
          builder: (_, _) => const Scaffold(body: SiteClassificationChips(siteId: 's1')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('To try'), findsOneWidget);

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();

    expect(find.text('site list'), findsOneWidget);
    expect(container.read(siteFilterProvider).tagIds, {'t1'});
  });
```

- [ ] **Step 6: Detail chips implementation**

Add `"diveSites_detail_showSitesWith": "Show sites with {name}"` (with an `@` entry declaring `name` as String) to `app_en.arb`; run `flutter gen-l10n`.

Create `lib/features/dive_sites/presentation/widgets/site_classification_chips.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A site's types (neutral) then its tags (colored), issue #1765. Tapping a
/// chip opens the site list filtered to it. Renders nothing when the site
/// has neither.
class SiteClassificationChips extends ConsumerWidget {
  const SiteClassificationChips({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(siteTypesForSiteProvider(siteId)).valueOrNull ?? const [];
    final tags = ref.watch(tagsForSiteProvider(siteId)).valueOrNull ?? const [];
    if (types.isEmpty && tags.isEmpty) return const SizedBox.shrink();

    void filterBy(SiteFilterState filter) {
      ref.read(siteFilterProvider.notifier).state = filter;
      context.go('/sites');
    }

    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in types)
          ActionChip(
            avatar: const Icon(Icons.category_outlined, size: 16),
            label: Text(type.localizedName(l10n)),
            tooltip: l10n.diveSites_detail_showSitesWith(type.localizedName(l10n)),
            onPressed: () => filterBy(SiteFilterState(siteTypeIds: {type.id})),
          ),
        for (final tag in tags)
          ActionChip(
            avatar: CircleAvatar(backgroundColor: tag.color, radius: 6),
            label: Text(tag.name),
            tooltip: l10n.diveSites_detail_showSitesWith(tag.name),
            onPressed: () => filterBy(SiteFilterState(tagIds: {tag.id})),
          ),
      ],
    );
  }
}
```

Use the site list route's real path (check `app_router.dart` for the sites list `GoRoute`; it is `/sites` if the router uses the path the test assumes).

In `site_detail_page.dart`: in the embedded header's title `Column` (after the `locationString` text, ~line 381) add `const SizedBox(height: 4), SiteClassificationChips(siteId: site.id),`; in the non-embedded body `Column` (~line 196), add `Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: SiteClassificationChips(siteId: site.id))` as the first child, only when not embedded.

- [ ] **Step 7: Run and commit**

Run: `flutter test test/features/dive_sites/presentation`
Expected: PASS.

```bash
dart format lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites/presentation lib/l10n/arb test/features/dive_sites/presentation
git commit -m "feat(sites): filter by site type and tag, show them on site detail (#1765)"
```

---

### Task 8: Site list chips and layout columns

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_tile.dart:137-160`
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_sites/presentation/widgets/site_list_tile_classification_test.dart`
- Test: `test/features/dive_sites/domain/constants/site_field_classification_test.dart`

**Interfaces:**
- Consumes: Task 5 `SiteWithDiveCount.siteTypes/tags`; Task 3 `localizedName`.
- Produces: `SiteField.siteTypes`, `SiteField.tags` (appended last).

- [ ] **Step 1: English strings**

```json
  "diveSites_list_moreTags": "+{count}",
  "enum_siteField_siteTypes": "Site Types",
  "enum_siteField_siteTypes_short": "Types",
  "enum_siteField_tags": "Tags",
  "enum_siteField_tags_short": "Tags",
```

(`diveSites_list_moreTags` gets an `@` entry with `count` as `int`.) Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

`test/features/dive_sites/domain/constants/site_field_classification_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  test('the new fields are appended after every existing member', () {
    final values = SiteField.values;
    expect(values[values.length - 2], SiteField.siteTypes);
    expect(values.last, SiteField.tags);
    expect(SiteField.siteTypes.categoryName, 'details');
  });

  test('cells render comma lists', () {
    final now = DateTime(2026);
    final entry = SiteWithDiveCount(
      site: const DiveSite(id: 's', name: 's'),
      diveCount: 0,
      siteTypes: [
        SiteTypeEntity(id: 'lake', name: 'Lake', isBuiltIn: true, createdAt: now, updatedAt: now),
        SiteTypeEntity(id: 'wreck', name: 'Wreck', isBuiltIn: true, createdAt: now, updatedAt: now),
      ],
      tags: [Tag(id: 't', name: 'To try', createdAt: now, updatedAt: now)],
    );
    final adapter = SiteFieldAdapter.instance;
    final units = UnitFormatter.metric();

    expect(
      adapter.formatValue(
        SiteField.siteTypes,
        adapter.extractValue(SiteField.siteTypes, entry),
        units,
      ),
      'Lake, Wreck',
    );
    expect(
      adapter.formatValue(
        SiteField.tags,
        adapter.extractValue(SiteField.tags, entry),
        units,
      ),
      'To try',
    );
  });
}
```

Read how existing `SiteField` tests obtain the adapter and a units object (`grep -rn "SiteFieldAdapter" test | head`) and use the same construction in place of `SiteFieldAdapter.instance` / `UnitFormatter.metric()` if those names differ.

`test/features/dive_sites/presentation/widgets/site_list_tile_classification_test.dart`: pump a `SiteListTile` the way the existing `site_list_tile` test does, with an entry whose `siteTypes` is `[wreck]`, `featureTypes` is `['wreck', 'mooring']`, and five site tags. Assert: `find.text('Wreck')` finds exactly one widget (the feature chip is hidden behind the type), `find.text('Mooring')` finds one, three tag names render, and `find.text('+2')` finds one.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_classification_test.dart test/features/dive_sites/presentation/widgets/site_list_tile_classification_test.dart`
Expected: FAIL.

- [ ] **Step 4: Tile chips**

In `site_list_tile.dart`, replace the `chips` list (lines 138-160):

```dart
    final typeIds = {for (final t in entry.siteTypes) t.id};
    final shownTags = entry.tags.take(3).toList();
    final hiddenTagCount = entry.tags.length - shownTags.length;
    final chips = <Widget>[
      if (site.difficulty != null)
        _SiteChip(
          icon: Icons.signal_cellular_alt,
          label: site.difficulty!.localizedName(l10n),
          color: statColor,
          textColor: chipTextColor,
        ),
      if (site.waterType != null)
        _SiteChip(
          icon: Icons.water_drop,
          label: site.waterType!.localizedName(l10n),
          color: statColor,
          textColor: chipTextColor,
        ),
      // Site types (issue #1765) before feature pins.
      for (final type in entry.siteTypes)
        _SiteChip(
          icon: Icons.category_outlined,
          label: type.localizedName(l10n),
          color: statColor,
          textColor: chipTextColor,
        ),
      // A wreck pin on a site typed wreck would read "Wreck Wreck".
      for (final typeName in entry.featureTypes)
        if (!(typeName == 'wreck' && typeIds.contains('wreck')))
          _SiteChip(
            icon: SiteFeatureGlyph.styleFor(typeName).$1,
            label: siteFeatureTypeLabel(l10n, typeName),
            color: SiteFeatureGlyph.styleFor(typeName).$2,
            textColor: chipTextColor,
          ),
      for (final tag in shownTags)
        _SiteChip(
          icon: Icons.sell_outlined,
          label: tag.name,
          color: tag.color,
          textColor: chipTextColor,
        ),
      if (hiddenTagCount > 0)
        _SiteChip(
          icon: Icons.sell_outlined,
          label: l10n.diveSites_list_moreTags(hiddenTagCount),
          color: statColor,
          textColor: chipTextColor,
        ),
    ];
```

Import `site_type_display.dart`.

- [ ] **Step 5: `SiteField` members**

Append after `averageDuration` (change its `;` to `,`):

```dart
  // Classification (issue #1765). Appended, never reordered.
  siteTypes,
  tags;
```

Add a case for both members to every exhaustive switch getter in the file:

| Getter | `siteTypes` | `tags` |
| --- | --- | --- |
| `displayName` | `'Site Types'` | `'Tags'` |
| `shortLabel` | `'Types'` | `'Tags'` |
| `localizedDisplayName` | `l10n.enum_siteField_siteTypes` | `l10n.enum_siteField_tags` |
| `localizedShortLabel` | `l10n.enum_siteField_siteTypes_short` | `l10n.enum_siteField_tags_short` |
| `icon` | `Icons.category_outlined` | `Icons.sell_outlined` |
| `defaultWidth` | `160` | `160` |
| `minWidth` | `80` | `80` |
| `sortable` | `false` | `false` |
| `categoryName` | `SiteFieldCategory.details.name` | `SiteFieldCategory.details.name` |
| `isRightAligned` | `false` | `false` |

In `SiteFieldAdapter.extractValue`:

```dart
      case SiteField.siteTypes:
        return [for (final t in entity.siteTypes) t.name];
      case SiteField.tags:
        return [for (final t in entity.tags) t.name];
```

In `formatValue`:

```dart
      case SiteField.siteTypes:
      case SiteField.tags:
        return value is List && value.isNotEmpty
            ? value.join(', ')
            : '--';
```

Table cells use the stored type name, matching how the table already renders difficulty and water type through `displayName` rather than a translation. Use whatever placeholder the adapter returns for other empty values in place of `'--'`.

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/dive_sites test/features/settings`
Expected: PASS. A test that asserts the exact `SiteField.values` length or a column-picker count fails here; update its expected number by two.

```bash
dart format lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites lib/l10n/arb test/features/dive_sites test/features/settings
git commit -m "feat(sites): site type and tag chips on cards, table and card columns (#1765)"
```

---

### Task 9: Manage pages and dive-side tag pickers

**Files:**
- Create: `lib/features/site_types/presentation/pages/site_types_page.dart`
- Modify: `lib/core/router/app_router.dart:1334-1339`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:2437-2446`
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart` (`_buildTagRow` 216-238, `_showCreateDialog` 241-296, `_showEditDialog` 298-352)
- Modify: `lib/features/tags/presentation/widgets/tag_picker_sheet.dart:59-70`
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart:~753`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/site_types/presentation/pages/site_types_page_test.dart`
- Test: `test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`

**Interfaces:**
- Consumes: Task 3 providers and notifier; Task 4 `TagRepository.getTagUsage`, `TagStatistic.siteCount`, `Tag.appliesTo*`.
- Produces: route `/site-types` (name `siteTypes`).

- [ ] **Step 1: English strings**

```json
  "settings_manage_siteTypes": "Site Types",
  "settings_manage_siteTypes_subtitle": "Built-in and custom dive site types",
  "siteTypes_addTooltip": "Add Site Type",
  "siteTypes_builtIn": "Built-in",
  "siteTypes_custom": "Custom",
  "siteTypes_deleteDialog_content": "Delete \"{name}\"?",
  "siteTypes_deleteDialog_inUse": "{count, plural, =1{\"{name}\" is used by 1 site. Deleting it removes it from that site.} other{\"{name}\" is used by {count} sites. Deleting it removes it from those sites.}}",
  "siteTypes_deleteDialog_title": "Delete Site Type?",
  "siteTypes_deleteTooltip": "Delete site type",
  "siteTypes_dialog_addTitle": "Add Site Type",
  "siteTypes_dialog_editTitle": "Edit Site Type",
  "siteTypes_dialog_nameLabel": "Name",
  "siteTypes_dialog_nameRequired": "Please enter a name",
  "siteTypes_editTooltip": "Edit site type",
  "siteTypes_siteCount": "{count, plural, =0{No sites} =1{1 site} other{{count} sites}}",
  "siteTypes_snackbar_error": "Could not save the site type: {error}",
  "siteTypes_title": "Site Types",
  "tags_manage_narrowDialog_confirm": "Remove",
  "tags_manage_narrowDialog_dives": "{count, plural, =1{This tag is on 1 dive. Turning off \"Use for dives\" removes it from that dive.} other{This tag is on {count} dives. Turning off \"Use for dives\" removes it from those dives.}}",
  "tags_manage_narrowDialog_sites": "{count, plural, =1{This tag is on 1 site. Turning off \"Use for sites\" removes it from that site.} other{This tag is on {count} sites. Turning off \"Use for sites\" removes it from those sites.}}",
  "tags_manage_narrowDialog_title": "Remove tag from existing items?",
  "tags_manage_scope_dives": "Dives",
  "tags_manage_scope_sites": "Sites",
  "tags_manage_scopeRequired": "Choose dives, sites, or both",
  "tags_manage_siteCount": "{count, plural, =0{0 sites} =1{1 site} other{{count} sites}}",
  "tags_manage_useForDives": "Use for dives",
  "tags_manage_useForSites": "Use for sites",
```

Give every placeholder an `@` entry (`name`/`error` String, `count` int), copying the `@tags_manage_diveCount` shape. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing page tests**

`test/features/site_types/presentation/pages/site_types_page_test.dart`: copy the harness from `test/features/dive_types/presentation/pages/dive_types_page_test.dart` lines 1-51, replacing `DiveTypesPage` with `SiteTypesPage`, then:

```dart
  testWidgets('lists translated built-ins and adds a custom type', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('Kelp forest'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Mine');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('deleting a type in use confirms with the site count', (tester) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 100, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('j', 's1', 'mine', 0)",
    );

    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('used by 1 site'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Mine'), findsNothing);
  });
```

`test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`: copy the harness from `test/features/tags/presentation/pages/tag_manage_page_test.dart`, then seed a tag with `applies_to_dives = 1, applies_to_sites = 1` linked to one site, pump, and assert the row shows `Dives · Sites` and `1 site`; tap the row, untick `Use for sites`, tap Save, assert the narrow dialog text containing `on 1 site` appears, tap `Remove`, and assert `site_tags` is empty. Add a second test that unticks both boxes and asserts `Choose dives, sites, or both` shows and Save does nothing.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/site_types/presentation/pages/site_types_page_test.dart test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`
Expected: FAIL.

- [ ] **Step 4: Site Types page**

Create `lib/features/site_types/presentation/pages/site_types_page.dart`, built from `dive_types_page.dart` but following the Manage-page convention (lower-right extended FAB; each custom row has inline edit and delete icon buttons; built-in rows have no actions):

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class SiteTypesPage extends ConsumerWidget {
  const SiteTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typesAsync = ref.watch(siteTypeListNotifierProvider);
    final stats = ref.watch(siteTypeStatisticsProvider).valueOrNull ?? const [];
    final siteCounts = {for (final s in stats) s.siteType.id: s.siteCount};

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.siteTypes_title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNameDialog(context, ref),
        tooltip: l10n.siteTypes_addTooltip,
        icon: const Icon(Icons.add),
        label: Text(l10n.siteTypes_addTooltip),
      ),
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (types) {
          final custom = types.where((t) => !t.isBuiltIn).toList();
          final builtIn = types.where((t) => t.isBuiltIn).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (custom.isNotEmpty) ...[
                _header(context, l10n.siteTypes_custom),
                for (final type in custom)
                  _tile(context, ref, type, siteCounts[type.id] ?? 0),
                const Divider(),
              ],
              _header(context, l10n.siteTypes_builtIn),
              for (final type in builtIn)
                _tile(context, ref, type, siteCounts[type.id] ?? 0),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    SiteTypeEntity type,
    int siteCount,
  ) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(
        type.isBuiltIn ? Icons.category : Icons.category_outlined,
        color: type.isBuiltIn
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary,
      ),
      title: Text(type.localizedName(l10n)),
      subtitle: Text(l10n.siteTypes_siteCount(siteCount)),
      trailing: type.isBuiltIn
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.siteTypes_editTooltip,
                  onPressed: () => _showNameDialog(context, ref, existing: type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.siteTypes_deleteTooltip,
                  onPressed: () => _confirmDelete(context, ref, type, siteCount),
                ),
              ],
            ),
    );
  }

  Future<void> _showNameDialog(
    BuildContext context,
    WidgetRef ref, {
    SiteTypeEntity? existing,
  }) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null
              ? l10n.siteTypes_dialog_addTitle
              : l10n.siteTypes_dialog_editTitle,
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.siteTypes_dialog_nameLabel),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.siteTypes_dialog_nameRequired
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: Text(existing == null ? l10n.common_action_add : l10n.common_action_save),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    final notifier = ref.read(siteTypeListNotifierProvider.notifier);
    try {
      if (existing == null) {
        await notifier.addSiteTypeByName(name);
      } else {
        await notifier.updateSiteType(existing.copyWith(name: name));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.siteTypes_snackbar_error('$e'))),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SiteTypeEntity type,
    int siteCount,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.siteTypes_deleteDialog_title),
        content: Text(
          siteCount > 0
              ? l10n.siteTypes_deleteDialog_inUse(siteCount, type.name)
              : l10n.siteTypes_deleteDialog_content(type.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(siteTypeListNotifierProvider.notifier).deleteSiteType(type.id);
  }
}
```

The `SiteTypeRepository` import is for `SiteTypeStatistic`; drop it if the analyzer reports it unused. Confirm the common action keys (`common_action_add`, `common_action_save`) exist in `app_en.arb`; the dive types page uses the literal `'Add'` button text in its test, so check which key it uses. The plural placeholder order for `siteTypes_deleteDialog_inUse` is whatever gen-l10n generates (usually alphabetical: `count`, `name`).

Route in `app_router.dart` after the dive types route:

```dart
          // Site Types Management (issue #1765)
          GoRoute(
            path: '/site-types',
            name: 'siteTypes',
            builder: (context, state) => const SiteTypesPage(),
          ),
```

Settings entry after the Dive Types tile and its divider:

```dart
                ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(context.l10n.settings_manage_siteTypes),
                  subtitle: Text(
                    context.l10n.settings_manage_siteTypes_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/site-types'),
                ),
                const Divider(height: 1),
```

- [ ] **Step 5: Tags page scope editor**

In `tag_manage_page.dart`:

- `_buildTagRow`: add a `subtitle` built from the scope, e.g. `Text([if (tag.appliesToDives) l10n.tags_manage_scope_dives, if (tag.appliesToSites) l10n.tags_manage_scope_sites].join(' · '))`, and make the trailing usage `Text([l10n.tags_manage_diveCount(stat.diveCount), if (stat.siteCount > 0) l10n.tags_manage_siteCount(stat.siteCount)].join(', '))`.
- `_showCreateDialog` and `_showEditDialog`: add two `CheckboxListTile`s (`tags_manage_useForDives`, `tags_manage_useForSites`) under the color picker, held in dialog state (`bool forDives`, `bool forSites`, initialized from the tag or to dives-only for a new tag). When both are unticked, show `tags_manage_scopeRequired` in the error color under them and make Save a no-op.
- Edit Save: if the edit turns off sites and `getTagUsage(tag.id)` reports `sites > 0` (or turns off dives with `dives > 0`), show an `AlertDialog` titled `tags_manage_narrowDialog_title` with the matching `tags_manage_narrowDialog_sites` / `_dives` text and buttons Cancel and `tags_manage_narrowDialog_confirm`; only on confirm call `updateTag(tag.copyWith(name:, colorHex:, appliesToDives: forDives, appliesToSites: forSites, updatedAt: DateTime.now()))`. Read usage through `ref.read(tagRepositoryProvider).getTagUsage(...)`.
- Create Save passes `appliesToDives: forDives, appliesToSites: forSites` into `Tag.create(...).copyWith(...)`.
- After `updateTag`, also `ref.invalidate(sitesWithCountsProvider)` so site cards drop removed tags.

- [ ] **Step 6: Dive-side pickers list dive tags only**

`tag_picker_sheet.dart` `_pickedFrom(stats)` / the stats list: filter `stats.where((s) => s.tag.appliesToDives)` before building. In `dive_filter_sheet.dart` (~line 753) filter the tag chip source with `.where((t) => t.appliesToDives)`. Every pre-v214 tag applies to dives, so the dive side shows exactly what it showed before; add one assertion to the existing `tag_picker_sheet_test.dart` that a sites-only tag is not listed.

- [ ] **Step 7: Run and commit**

Run: `flutter test test/features/site_types test/features/tags test/features/settings test/features/dive_log/presentation/widgets`
Expected: PASS.

```bash
dart format lib test
git add lib/features/site_types/presentation/pages lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/tags/presentation lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/l10n/arb test/features/site_types test/features/tags
git commit -m "feat(sites): manage site types and tag scope in settings (#1765)"
```

### Task 10: Site type statistics

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (after `getWaterTypeDistribution`, ~1263)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart` (after `waterTypeDistributionProvider`, ~282)
- Create: `lib/features/statistics/presentation/widgets/horizontal_category_bar_chart.dart`
- Modify: `lib/features/statistics/presentation/pages/statistics_conditions_page.dart` (~36, ~157)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/statistics/data/repositories/site_type_distribution_test.dart`
- Test: `test/features/statistics/presentation/widgets/horizontal_category_bar_chart_test.dart`

**Interfaces:**
- Consumes: Task 1 tables; Task 3 `siteTypesByIdProvider`, `localizedName`.
- Produces: `StatisticsRepository.getSiteTypeDistribution({String? diverId, DiveFilterState filter})` returning `List<DistributionSegment>` (label = site type id); `siteTypeDistributionProvider`; `HorizontalCategoryBarChart({required List<({String label, int count})> data, Color? barColor})`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/statistics/data/repositories/site_type_distribution_test.dart`, copying the setup and the `insertSite` / `insertDive` helpers from `test/features/statistics/data/repositories/water_type_distribution_test.dart` (lines 1-60), then:

```dart
  Future<void> linkType(String siteId, String typeId) => db.customStatement(
    "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
    "VALUES ('$siteId-$typeId', '$siteId', '$typeId', 0)",
  );

  Future<Map<String, int>> counts() async {
    final dist = await repository.getSiteTypeDistribution();
    return {for (final s in dist) s.label: s.count};
  }

  test('a dive counts once under each of its site\'s types', () async {
    await insertSite(id: 'lakeWreck');
    await insertSite(id: 'reef');
    await linkType('lakeWreck', 'lake');
    await linkType('lakeWreck', 'wreck');
    await linkType('reef', 'reef');
    await insertDive(id: 'd1', siteId: 'lakeWreck');
    await insertDive(id: 'd2', siteId: 'lakeWreck');
    await insertDive(id: 'd3', siteId: 'reef');

    expect(await counts(), {'lake': 2, 'wreck': 2, 'reef': 1});
  });

  test('dives at untyped sites and without a site are not counted', () async {
    await insertSite(id: 'bare');
    await insertDive(id: 'd1', siteId: 'bare');
    await insertDive(id: 'd2');

    expect(await counts(), isEmpty);
  });

  test('the view filter applies', () async {
    await insertSite(id: 'reef');
    await linkType('reef', 'reef');
    await insertDive(id: 'd1', siteId: 'reef');

    final dist = await repository.getSiteTypeDistribution(
      filter: const DiveFilterState(siteIds: ['somewhere-else']),
    );
    expect(dist, isEmpty);
  });
```

If `DiveFilterState` has no `siteIds` field, use any filter field the water-type test file exercises that excludes the dive (read it).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/statistics/data/repositories/site_type_distribution_test.dart`
Expected: FAIL (method missing).

- [ ] **Step 3: Repository**

Add after `getWaterTypeDistribution`:

```dart
  /// Dives per site type (issue #1765). A dive at a site with several types
  /// counts once under each, as [getDiveTypeDistribution] does for a dive's
  /// own types, so the counts can sum past the dive total. Dives without a
  /// site, or at a site without types, are not counted.
  Future<List<DistributionSegment>> getSiteTypeDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT sst.site_type_id AS site_type, COUNT(*) AS count
        FROM dives d
        JOIN site_site_types sst ON sst.site_id = d.site_id
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY sst.site_type_id
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final total = results.fold<int>(
        0,
        (sum, row) => sum + row.read<int>('count'),
      );
      if (total == 0) return [];

      return results.map((row) {
        final count = row.read<int>('count');
        return DistributionSegment(
          label: row.read<String>('site_type'),
          count: count,
          percentage: count / total * 100,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get site type distribution',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

Run the test: PASS.

- [ ] **Step 4: Chart widget (test first)**

Create `test/features/statistics/presentation/widgets/horizontal_category_bar_chart_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

void main() {
  testWidgets('one row per category with proportional bars', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HorizontalCategoryBarChart(
          data: [(label: 'Wreck', count: 10), (label: 'Lake', count: 5)],
        ),
      ),
    );

    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Lake'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    final bars = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.widthFactor)
        .toList();
    expect(bars, [1.0, 0.5]);
  });

  testWidgets('empty data shows the shared empty state', (tester) async {
    await tester.pumpWidget(_wrap(const HorizontalCategoryBarChart(data: [])));
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
  });
}
```

Create `lib/features/statistics/presentation/widgets/horizontal_category_bar_chart.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Horizontal bars of counts, one row per category (issue #1765).
///
/// For distributions whose categories overlap (a dive counted under every
/// type of its site), where a pie's shares would misread. A plain widget
/// rather than a rotated fl_chart `BarChart`, whose axis labels rotate with
/// the bars.
class HorizontalCategoryBarChart extends StatelessWidget {
  const HorizontalCategoryBarChart({
    super.key,
    required this.data,
    this.barColor,
  });

  final List<({String label, int count})> data;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.statistics_chart_noBarData,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = barColor ?? theme.colorScheme.primary;
    final maxCount = data
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b);

    return Semantics(
      label: context.l10n.statistics_chart_barSemanticLabel(data.length),
      child: Column(
        children: [
          for (final item in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxCount == 0 ? 0 : item.count / maxCount,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${item.count}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

Run the widget test: PASS.

- [ ] **Step 5: Provider and page section**

Add after `waterTypeDistributionProvider`:

```dart
final siteTypeDistributionProvider = FutureProvider<List<DistributionSegment>>(
  (ref) async {
    _keepAliveWithExpiry(ref);
    final repository = ref.watch(statisticsRepositoryProvider);
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final filter = ref.watch(statisticsFilterProvider);
    return repository.getSiteTypeDistribution(
      diverId: currentDiverId,
      filter: filter,
    );
  },
);
```

English strings:

```json
  "statistics_conditions_siteType_error": "Could not load site types",
  "statistics_conditions_siteType_semanticLabel": "Dives per site type: {description}",
  "statistics_conditions_siteType_subtitle": "Dives per site type. A dive at a site with several types counts toward each; sites without a type are not shown.",
  "statistics_conditions_siteType_title": "Site Types",
```

(`description` String placeholder.) Run `flutter gen-l10n`.

In `statistics_conditions_page.dart`, add `_buildSiteTypeSection(context, ref),` to the column right after `_buildWaterTypeSection(context, ref),` (with the same spacing the column uses between sections), and:

```dart
  Widget _buildSiteTypeSection(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(siteTypeDistributionProvider);
    final typesById =
        ref.watch(siteTypesByIdProvider).valueOrNull ?? const {};

    return StatSectionCard(
      title: context.l10n.statistics_conditions_siteType_title,
      subtitle: context.l10n.statistics_conditions_siteType_subtitle,
      child: distAsync.when(
        data: (raw) {
          // The repository emits type ids; names resolve here so custom
          // types show the diver's name and built-ins translate.
          final data = [
            for (final s in raw)
              (
                label:
                    typesById[s.label]?.localizedName(context.l10n) ?? s.label,
                count: s.count,
              ),
          ];
          final description = data
              .map((d) => '${d.label}: ${d.count}')
              .join(', ');
          return Semantics(
            label: context.l10n.statistics_conditions_siteType_semanticLabel(
              description,
            ),
            child: HorizontalCategoryBarChart(
              data: data,
              barColor: Colors.teal.shade400,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_conditions_siteType_error,
        ),
      ),
    );
  }
```

If a conditions page widget test renders the page, add `siteTypeDistributionProvider.overrideWith((ref) async => const [])` and `siteTypesByIdProvider.overrideWith((ref) async => const {})` to its overrides.

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/statistics`
Expected: PASS.

```bash
dart format lib/features/statistics test/features/statistics
git add lib/features/statistics lib/l10n/arb test/features/statistics
git commit -m "feat(stats): dives per site type on the conditions page (#1765)"
```

---

### Task 11: UDDF export

**Files:**
- Create: `lib/core/services/export/uddf/uddf_site_classification_writers.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildSiteElement` 39-101, `buildApplicationData` 833-1275)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (`_generateAllDataXml` 48, sites 173-186, application data 354-365, public wrappers 398/426/491)
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart` (site block 160-223, application data 676-686)
- Modify: `lib/core/services/export/uddf/uddf_dives_extras.dart`
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (~572-691, ~1236-1328)
- Test: `test/core/services/export/uddf/uddf_site_classification_export_test.dart`

**Interfaces:**
- Consumes: Task 3 `SiteTypeEntity`; Task 4 `Tag.appliesTo*`; Task 5 `SiteClassificationRepository.getTypeIdsBySite/getTagIdsBySite`.
- Produces: XML shapes the import in Task 12 reads:
  - under `<applicationdata><submersion>`: `<sitetypes><sitetype id="SLUG"><name/><sortorder/></sitetype></sitetypes>`; each `<tag>` gains `<appliestodives>true|false</appliestodives><appliestosites>true|false</appliestosites>`.
  - inside `<site>`: `<sitetypes><sitetyperef>SLUG</sitetyperef></sitetypes>` and `<tags><tagref>tag_ID</tagref></tags>`.
  - New named parameters on both export entry points: `Map<String, List<String>> siteTypeIdsBySite`, `Map<String, List<String>> siteTagIdsBySite`, `List<SiteTypeEntity> customSiteTypes` (full export); `UddfDivesExtras` gains the same three plus `List<Tag> siteTags` (dives-only).

- [ ] **Step 1: Write the failing export test**

Create `test/core/services/export/uddf/uddf_site_classification_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:xml/xml.dart';

void main() {
  final now = DateTime(2026);
  const site = DiveSite(id: 's1', name: 'Lake wreck');
  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 1, 1, 10),
    bottomTime: const Duration(minutes: 30),
    maxDepth: 12,
    site: site,
  );
  final mine = SiteTypeEntity(id: 'mine', diverId: 'diver-1', name: 'Mine', sortOrder: 100, createdAt: now, updatedAt: now);
  final toTry = Tag(id: 't1', name: 'To try', createdAt: now, updatedAt: now, appliesToDives: false, appliesToSites: true);

  void expectSiteRefs(XmlDocument doc) {
    final siteEl = doc.findAllElements('site').single;
    expect(
      siteEl.findAllElements('sitetyperef').map((e) => e.innerText).toList(),
      ['wreck', 'mine'],
    );
    expect(
      siteEl.findAllElements('tagref').map((e) => e.innerText).toList(),
      ['tag_t1'],
    );
    final def = doc.findAllElements('sitetype').single;
    expect(def.getAttribute('id'), 'mine');
    expect(def.findElements('name').single.innerText, 'Mine');
    final tagDef = doc
        .findAllElements('tag')
        .firstWhere((e) => e.getAttribute('id') == 'tag_t1');
    expect(tagDef.findElements('appliestosites').single.innerText, 'true');
    expect(tagDef.findElements('appliestodives').single.innerText, 'false');
  }

  test('the full export writes site refs and definitions', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      sites: [site],
      tags: [toTry],
      customSiteTypes: [mine],
      siteTypeIdsBySite: const {'s1': ['wreck', 'mine']},
      siteTagIdsBySite: const {'s1': ['t1']},
    );
    expectSiteRefs(XmlDocument.parse(xml));
  });

  test('the dives-only export writes the same shapes', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      extras: UddfDivesExtras(
        customSiteTypes: [mine],
        siteTags: [toTry],
        siteTypeIdsBySite: const {'s1': ['wreck', 'mine']},
        siteTagIdsBySite: const {'s1': ['t1']},
      ),
    );
    expectSiteRefs(XmlDocument.parse(xml));
  });
}
```

Adjust the `Dive` constructor arguments to what it requires (see `universal_adapter_test.dart:2543` for a minimal dive).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/export/uddf/uddf_site_classification_export_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Shared writers**

Create `lib/core/services/export/uddf/uddf_site_classification_writers.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// UDDF writers for dive site types and site tags (issue #1765), shared by
/// the full backup and the dives-only export so the two `<site>` builders
/// cannot drift apart (the #1735 lesson). UDDF has no standard element for
/// either; both are Submersion extensions the full importer reads back.
class UddfSiteClassificationWriters {
  const UddfSiteClassificationWriters._();

  /// Inside a `<site>`: the site's type slugs and tag references.
  static void writeSiteRefs(
    XmlBuilder builder, {
    required List<String> siteTypeIds,
    required List<String> tagIds,
  }) {
    if (siteTypeIds.isNotEmpty) {
      builder.element(
        'sitetypes',
        nest: () {
          for (final id in siteTypeIds) {
            builder.element('sitetyperef', nest: id);
          }
        },
      );
    }
    if (tagIds.isNotEmpty) {
      builder.element(
        'tags',
        nest: () {
          for (final id in tagIds) {
            builder.element('tagref', nest: 'tag_$id');
          }
        },
      );
    }
  }

  /// Inside `<applicationdata><submersion>`: the custom site types. Built-ins
  /// are referenced by slug and never defined; every install seeds them.
  static void writeCustomSiteTypeDefinitions(
    XmlBuilder builder,
    List<SiteTypeEntity> types,
  ) {
    final custom = types.where((t) => !t.isBuiltIn).toList();
    if (custom.isEmpty) return;
    builder.element(
      'sitetypes',
      nest: () {
        for (final type in custom) {
          builder.element(
            'sitetype',
            attributes: {'id': type.id},
            nest: () {
              builder.element('name', nest: type.name);
              builder.element('sortorder', nest: type.sortOrder.toString());
            },
          );
        }
      },
    );
  }
}
```

- [ ] **Step 4: Builders**

`UddfExportBuilders.buildSiteElement(XmlBuilder builder, DiveSite site, {List<String> siteTypeIds = const [], List<String> tagIds = const []})`: as the last statement inside the `<site>` nest, call `UddfSiteClassificationWriters.writeSiteRefs(builder, siteTypeIds: siteTypeIds, tagIds: tagIds);`.

`buildApplicationData` gains `List<SiteTypeEntity>? customSiteTypes`; add `(customSiteTypes?.any((t) => !t.isBuiltIn) ?? false) ||` to the `hasData` guard; after the custom dive types block call `UddfSiteClassificationWriters.writeCustomSiteTypeDefinitions(builder, customSiteTypes ?? const []);`. In the tags block, after the color element:

```dart
                        builder.element(
                          'appliestodives',
                          nest: tag.appliesToDives.toString(),
                        );
                        builder.element(
                          'appliestosites',
                          nest: tag.appliesToSites.toString(),
                        );
```

- [ ] **Step 5: Full export service**

`_generateAllDataXml` and its three public wrappers gain `List<SiteTypeEntity>? customSiteTypes`, `Map<String, List<String>> siteTypeIdsBySite = const {}`, `Map<String, List<String>> siteTagIdsBySite = const {}`, threaded through. The site loop becomes:

```dart
              for (final site in allSites) {
                UddfExportBuilders.buildSiteElement(
                  builder,
                  site,
                  siteTypeIds: siteTypeIdsBySite[site.id] ?? const [],
                  tagIds: siteTagIdsBySite[site.id] ?? const [],
                );
              }
```

and `buildApplicationData(..., customSiteTypes: customSiteTypes)`.

- [ ] **Step 6: Dives-only export**

`UddfDivesExtras` gains:

```dart
  /// Site type slugs and tag ids per exported site (issue #1765).
  final Map<String, List<String>> siteTypeIdsBySite;
  final Map<String, List<String>> siteTagIdsBySite;

  /// Definitions the refs above need: the custom site types and the tags
  /// the exported sites carry.
  final List<SiteTypeEntity> customSiteTypes;
  final List<Tag> siteTags;
```

(constructor defaults `const {}` / `const []`). `resolveDivesExtras` loads them for the sites of the exported dives, always (site classification is not behind an options checkbox): it needs `SiteClassificationRepository` and `SiteTypeRepository` plus the dives' site ids. The loader receives dive ids, so resolve site ids with one query (`SELECT DISTINCT site_id FROM dives WHERE id IN (...) AND site_id IS NOT NULL`) through the repository layer. Add to `SiteClassificationRepository`:

```dart
  /// The distinct sites of [diveIds], for the dives-only export.
  Future<List<String>> getSiteIdsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final rows =
        await (_db.selectOnly(_db.dives, distinct: true)
              ..addColumns([_db.dives.siteId])
              ..where(
                _db.dives.id.isIn(diveIds) & _db.dives.siteId.isNotNull(),
              ))
            .get();
    return [for (final r in rows) r.read(_db.dives.siteId)!];
  }
``` Then `getTypeIdsBySite(siteIds)`, `getTagIdsBySite(siteIds)`, the site tags via `getTagsForSite` per site (or a batch filtered from `getTagsBySite()`), and `customSiteTypes` from `SiteTypeRepository.getAllSiteTypes(diverId:)` filtered to ids that appear. Add the two repository providers to `uddfDivesExtrasFetchProvider`'s closure.

In `generateDivesUddfContent`, the hand-written site nest gets, as its last statement:

```dart
                    UddfSiteClassificationWriters.writeSiteRefs(
                      builder,
                      siteTypeIds:
                          extras.siteTypeIdsBySite[site.id] ?? const [],
                      tagIds: extras.siteTagIdsBySite[site.id] ?? const [],
                    );
```

and its `buildApplicationData` call adds `tags: extras.siteTags, customSiteTypes: extras.customSiteTypes,`. If the dives-only `hasData` path would now emit an `<applicationdata>` for a file with only site tags, that is intended.

- [ ] **Step 7: Export providers**

In both full-export paths of `export_providers.dart` (~572-691 and ~1236-1328), next to `customDiveTypes`:

```dart
      final classification = _ref.read(siteClassificationRepositoryProvider);
      final siteIds = [for (final s in sites) s.id];
      final siteTypeIdsBySite = await classification.getTypeIdsBySite(siteIds);
      final siteTagIdsBySite = await classification.getTagIdsBySite(siteIds);
      final customSiteTypes = (await _ref.read(siteTypesProvider.future))
          .where((t) => !t.isBuiltIn)
          .toList();
```

and pass all three to `exportAllDataToUddf` / `saveAllDataToUddfFile`. `tagsProvider` is unscoped, so site-only tags are already in `tags`.

- [ ] **Step 8: Run and commit**

Run: `flutter test test/core/services/export test/features/settings/presentation/providers`
Expected: PASS.

```bash
dart format lib/core/services/export lib/features/settings lib/features/dive_sites test/core/services/export
git add lib/core/services/export lib/features/settings/presentation/providers/export_providers.dart lib/features/dive_sites/data/repositories/site_classification_repository.dart test/core/services/export
git commit -m "feat(uddf): export site types and site tags (#1765)"
```

---

### Task 12: UDDF import

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseTag` 567-578, `parseFullSite` 793-823)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (~235, ~347-371, result ~557)
- Modify: `lib/core/services/export/models/uddf_import_result.dart`
- Modify: `lib/features/universal_import/data/models/import_payload.dart:31`
- Modify: `lib/features/universal_import/data/parsers/uddf_import_parser.dart:73-78`
- Modify: `lib/features/universal_import/data/services/payload_merger.dart` (~100-110, ~185-190, `_namespaced`, `_rewriteAliases`)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (`_payloadToUddfResult` 1364-1383, `universalImportRepositories` 1391)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`ImportRepositories` 68-105, import order ~340-450, `_importTags` 953-1001, `_importSites` 1115-1341)
- Test: `test/core/services/export/uddf/uddf_site_classification_round_trip_test.dart`
- Test: `test/features/universal_import/data/services/payload_merger_site_refs_test.dart`

**Interfaces:**
- Consumes: Task 11 XML shapes; Task 3 `SiteTypeRepository.getCustomSiteTypeByName/createSiteType/getSiteTypeById`; Task 4 `TagRepository` scope; Task 5 `SiteClassificationRepository.addTypes/addTags`.
- Produces:
  - Site map keys: `siteTypeRefs` (`List<String>`, union on import), `suggestedSiteTypeRefs` (`List<String>`, applied only when the site has no types; Task 13 fills it), `tagRefs` (`List<String>`).
  - Tag map keys `appliesToDives` / `appliesToSites` (`bool?`).
  - `UddfImportResult.customSiteTypes` (`List<Map<String, dynamic>>` of `{id, name, sortOrder}`); `ImportPayload.customSiteTypesKey = 'customSiteTypes'`.
  - `ImportRepositories.siteTypeRepository` (`SiteTypeRepository?`), `ImportRepositories.siteClassificationRepository` (`SiteClassificationRepository?`); null skips classification restore.

- [ ] **Step 1: Write the failing round-trip test**

Create `test/core/services/export/uddf/uddf_site_classification_round_trip_test.dart`, copying the setup, `importResult`, `restoreThroughWizard`, `buildRepositories()` and `createTestDiver()` usage from `test/core/services/export/uddf/uddf_diver_role_round_trip_test.dart` (lines 1-64). Extend `restoreThroughWizard` so the rebuilt `UddfImportResult` also carries `sites: payload.entitiesOf(ImportEntityType.sites)`, `tags: payload.entitiesOf(ImportEntityType.tags)` and `customSiteTypes` from `payload.metadata[ImportPayload.customSiteTypesKey]`, exactly as `UniversalAdapter._payloadToUddfResult` will after this task. Make `buildRepositories()` pass `siteTypeRepository: SiteTypeRepository(), siteClassificationRepository: SiteClassificationRepository()` (edit the shared helper in `uddf_raw_data_round_trip_test.dart` if that is where it lives).

```dart
  test('site types, site tags and tag scope survive a backup and restore', () async {
    final diverId = await createTestDiver();
    final sites = SiteRepository();
    final types = SiteTypeRepository();
    final tags = TagRepository();
    final classification = SiteClassificationRepository();

    final mine = await types.createSiteType(
      SiteTypeEntity.create(id: 'mine', name: 'Mine', diverId: diverId),
    );
    final toTry = await tags.getOrCreateTag(
      'To try',
      diverId: diverId,
      colorHex: '#EF4444',
      scope: TagScope.sites,
    );
    final site = await sites.createSite(
      DiveSite(id: '', name: 'Lake wreck', diverId: diverId),
      classification: SiteClassification(
        typeIds: ['wreck', mine.id],
        tagIds: [toTry.id],
      ),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [site],
      tags: [toTry],
      customSiteTypes: [mine],
      siteTypeIdsBySite: {site.id: ['wreck', mine.id]},
      siteTagIdsBySite: {site.id: [toTry.id]},
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restoreThroughWizard(xml);

    final restored = (await SiteRepository().getAllSites()).single;
    final restoredTypes = await classification.getTypesForSite(restored.id);
    expect(restoredTypes.map((t) => t.name), ['Wreck', 'Mine']);
    expect(restoredTypes.last.isBuiltIn, isFalse);

    final restoredTags = await classification.getTagsForSite(restored.id);
    expect(restoredTags.single.name, 'To try');
    expect(restoredTags.single.appliesToSites, isTrue);
    expect(restoredTags.single.appliesToDives, isFalse);
    expect(restoredTags.single.colorHex, '#EF4444', reason: 'tag color bug');
  });

  test('re-importing onto an existing site unions, never removes', () async {
    final diverId = await createTestDiver();
    final exported = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Quarry wall', diverId: diverId),
      classification: const SiteClassification(typeIds: ['lake']),
    );
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      sites: [exported],
      siteTypeIdsBySite: {exported.id: ['lake']},
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final localDiver = await createTestDiver();
    final local = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Quarry wall', diverId: localDiver),
      classification: const SiteClassification(typeIds: ['wreck']),
    );

    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    await UddfEntityImporter().import(
      data: UddfImportResult(
        sites: payload.entitiesOf(ImportEntityType.sites),
      ),
      // Site 0 of the file overwrites the existing local site.
      selections: UddfImportSelections(siteOverrides: {0: local.id}),
      repositories: buildRepositories(),
      diverId: localDiver,
    );

    final types = await SiteClassificationRepository().getTypesForSite(
      local.id,
    );
    expect(types.map((t) => t.id).toSet(), {'wreck', 'lake'});
  });
```

`UddfImportSelections.siteOverrides` is the `Map<int, String>` (file site index to existing site id) that `_importSites` receives as `overrides`; if the constructor requires other fields, pass their empty values.

Create `test/features/universal_import/data/services/payload_merger_site_refs_test.dart`: merge two payloads (`fileId` `a` and `b`) whose site maps each carry `tagRefs: ['tag_1']` and `siteTypeRefs: ['mine']`, and whose metadata both carry `customSiteTypesKey: [{'id': 'mine', 'name': 'Mine'}]`. Assert the merged site maps' `tagRefs` are `['a:tag_1']` and `['b:tag_1']`, `siteTypeRefs` are unchanged `['mine']`, and the merged metadata has one `mine` definition. Read the existing payload merger test for how inputs are built.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/export/uddf/uddf_site_classification_round_trip_test.dart test/features/universal_import/data/services/payload_merger_site_refs_test.dart`
Expected: FAIL.

- [ ] **Step 3: Parsers**

`parseTag`, after the color line:

```dart
    tag['appliesToDives'] = _parseBool(getElementText(tagElement, 'appliestodives'));
    tag['appliesToSites'] = _parseBool(getElementText(tagElement, 'appliestosites'));
```

with a private helper in the same class:

```dart
  static bool? _parseBool(String? text) => switch (text?.trim().toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => null,
  };
```

`parseFullSite`, before `return site;`:

```dart
    // Site types and tags (issue #1765). Carried on the site map because the
    // import wizard keeps only entity lists.
    final typeRefs = [
      for (final e in siteElement.findElements('sitetypes').expand(
        (s) => s.findElements('sitetyperef'),
      ))
        if (e.innerText.trim().isNotEmpty) e.innerText.trim(),
    ];
    if (typeRefs.isNotEmpty) site['siteTypeRefs'] = typeRefs;
    final tagRefs = [
      for (final e in siteElement.findElements('tags').expand(
        (s) => s.findElements('tagref'),
      ))
        if (e.innerText.trim().isNotEmpty) e.innerText.trim(),
    ];
    if (tagRefs.isNotEmpty) site['tagRefs'] = tagRefs;
```

Add `parseSiteTypeElement`:

```dart
  static Map<String, dynamic> parseSiteTypeElement(XmlElement element) {
    final id = element.getAttribute('id');
    final name = getElementText(element, 'name');
    if (id == null || id.isEmpty || name == null || name.isEmpty) return {};
    return {
      'id': id,
      'name': name,
      'sortOrder': int.tryParse(getElementText(element, 'sortorder') ?? ''),
    };
  }
```

- [ ] **Step 4: Full import service and result**

In `uddf_full_import_service.dart` declare `final customSiteTypes = <Map<String, dynamic>>[];` next to `customDiveTypes` (~235); after the custom dive types section (~371):

```dart
        // Custom site types (issue #1765)
        final siteTypesSection = submersionElement
            .findElements('sitetypes')
            .firstOrNull;
        if (siteTypesSection != null) {
          for (final el in siteTypesSection.findElements('sitetype')) {
            final data = UddfImportParsers.parseSiteTypeElement(el);
            if (data.isNotEmpty) customSiteTypes.add(data);
          }
        }
```

and pass `customSiteTypes: customSiteTypes,` to the `UddfImportResult` (~557). `UddfImportResult` gains `final List<Map<String, dynamic>> customSiteTypes;` (constructor default `const []`), included in `isEmpty`.

- [ ] **Step 5: Payload plumbing**

`import_payload.dart`: `static const customSiteTypesKey = 'customSiteTypes';` next to `customDiveRolesKey`.

`uddf_import_parser.dart` metadata map:

```dart
          if (result.customSiteTypes.isNotEmpty)
            ImportPayload.customSiteTypesKey: result.customSiteTypes,
```

`payload_merger.dart`: collect `customSiteTypes` by `id` with `putIfAbsent` exactly as `customDiveRoles` (site type slugs are shared across files by design, like dive type slugs, so they are not namespaced), and emit them under `ImportPayload.customSiteTypesKey`. In `_namespaced`, add:

```dart
    if (type == ImportEntityType.sites) {
      final refs = item['tagRefs'];
      if (refs is List) {
        item['tagRefs'] = [
          for (final ref in refs)
            if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
        ];
      }
    }
```

In `_rewriteAliases`, apply the folded-tag alias rewrite that dives' `tagRefs` receive to site maps' `tagRefs` too (read the method: it walks dive maps' list-ref fields through `resolve`; add the same pass over `entities[ImportEntityType.sites]` for `tagRefs`).

`universal_adapter.dart` `_payloadToUddfResult`:

```dart
      customSiteTypes: [
        for (final type
            in (payload.metadata[ImportPayload.customSiteTypesKey] as List?) ??
                const [])
          if (type is Map<String, dynamic>) type,
      ],
```

and `universalImportRepositories` passes `siteTypeRepository: ref.read(siteTypeRepositoryProvider), siteClassificationRepository: ref.read(siteClassificationRepositoryProvider),`.

- [ ] **Step 6: Importer**

`ImportRepositories` gains two optional fields (constructor parameters `this.siteTypeRepository, this.siteClassificationRepository`):

```dart
  /// Optional; when null, site types are not restored (issue #1765).
  final SiteTypeRepository? siteTypeRepository;

  /// Optional; when null, site types and site tags are not linked.
  final SiteClassificationRepository? siteClassificationRepository;
```

Tag color fix in `_importTags`: `colorHex: tagData['colorHex'] as String? ?? tagData['color'] as String?,` (the parser writes `colorHex`; `color` stays as a fallback for maps built by other adapters). The new-tag `Tag(...)` gains `appliesToDives: tagData['appliesToDives'] as bool? ?? true, appliesToSites: tagData['appliesToSites'] as bool? ?? false,` and if both would be false, keep dives true. When the tag already exists by name and the incoming map says `appliesToSites == true`, widen it: `await repository.getOrCreateTag(name, diverId: diverId, scope: TagScope.sites);`.

Add `_importSiteTypes`, called right after `_importDiveTypes` (so sites can resolve against it):

```dart
  /// Resolves the file's custom site types to local ids (issue #1765): an
  /// existing custom type of the same name is reused, otherwise one is
  /// created. Returns file id -> local id.
  Future<Map<String, String>> _importSiteTypes(
    List<Map<String, dynamic>> items,
    SiteTypeRepository? repository,
    String diverId,
  ) async {
    final mapping = <String, String>{};
    if (repository == null) return mapping;
    for (final data in items) {
      final fileId = data['id'] as String?;
      final name = (data['name'] as String?)?.trim();
      if (fileId == null || name == null || name.isEmpty) continue;
      final existing = await repository.getCustomSiteTypeByName(
        name,
        diverId: diverId,
      );
      if (existing != null) {
        mapping[fileId] = existing.id;
        continue;
      }
      final created = await repository.createSiteType(
        SiteTypeEntity.create(
          id: SiteTypeEntity.generateSlug(name),
          name: name,
          diverId: diverId,
          sortOrder: data['sortOrder'] as int? ?? 0,
        ),
      );
      mapping[fileId] = created.id;
    }
    return mapping;
  }
```

Pass the mapping and `tagIdMapping` into `_importSites` (new parameters `Map<String, String> siteTypeIdMapping`, `Map<String, String> tagIdMapping`, `ImportRepositories repositories`). Add a helper and call it in both the overwrite branch (after `updateSiteWithImportedMetadata`, with `existingSite: true`) and the create branch (after `createSite` and `applyImportedMetadata`, with `existingSite: false`):

```dart
  /// Links an imported site's types and tags (issue #1765). Always a union:
  /// an import never removes a type or tag. `suggestedSiteTypeRefs` (from
  /// importers that infer a type, e.g. Shearwater's Environment) apply only
  /// when the site has no types yet, so they never override the diver.
  Future<void> _linkSiteClassification(
    Map<String, dynamic> siteData,
    String siteId,
    Map<String, String> siteTypeIdMapping,
    Map<String, String> tagIdMapping,
    ImportRepositories repos,
  ) async {
    final classification = repos.siteClassificationRepository;
    final types = repos.siteTypeRepository;
    if (classification == null) return;

    Future<List<String>> resolveTypes(Object? refs) async {
      final out = <String>[];
      for (final ref in refs is List ? refs.whereType<String>() : const <String>[]) {
        final local = siteTypeIdMapping[ref];
        if (local != null) {
          out.add(local);
        } else if (types != null && (await types.getSiteTypeById(ref))?.isBuiltIn == true) {
          out.add(ref);
        }
      }
      return out;
    }

    await classification.addTypes(siteId, await resolveTypes(siteData['siteTypeRefs']));

    final suggested = await resolveTypes(siteData['suggestedSiteTypeRefs']);
    if (suggested.isNotEmpty &&
        (await classification.getTypesForSite(siteId)).isEmpty) {
      await classification.addTypes(siteId, suggested);
    }

    final tagRefs = siteData['tagRefs'];
    final tagIds = [
      for (final ref in tagRefs is List ? tagRefs.whereType<String>() : const <String>[])
        if (tagIdMapping[ref] != null) tagIdMapping[ref]!,
    ];
    for (final tagId in tagIds) {
      final tag = await repos.tagRepository.getTagById(tagId);
      if (tag != null && !tag.appliesToSites) {
        await repos.tagRepository.getOrCreateTag(
          tag.name,
          diverId: tag.diverId,
          scope: TagScope.sites,
        );
      }
    }
    await classification.addTags(siteId, tagIds);
  }
```

(A tag referenced by a site is widened to sites, matching the spec: a tag with no scope elements keeps its old meaning, dives only, plus sites when a site references it.)

- [ ] **Step 7: Run and commit**

Run: `flutter test test/core/services/export test/features/universal_import test/features/import_wizard test/features/dive_import`
Expected: PASS. Existing tests that build `UddfImportResult` or `ImportRepositories` positionally keep compiling because every new field is optional.

```bash
dart format lib test
git add lib/core/services/export lib/features/universal_import lib/features/import_wizard/data/adapters/universal_adapter.dart lib/features/dive_import/data/services/uddf_entity_importer.dart test/core/services/export test/features/universal_import
git commit -m "feat(uddf): restore site types and site tags; keep imported tag colors (#1765)"
```

### Task 13: Import mappings (Shearwater and the bundled site database)

**Files:**
- Modify: `lib/features/universal_import/data/services/shearwater_value_mapper.dart`
- Modify: `lib/features/universal_import/data/services/shearwater_dive_mapper.dart:177-206`
- Modify: `lib/features/dive_sites/data/services/dive_site_api_service.dart` (`ExternalDiveSite` 10-65, `_loadBundledSites` 129-161)
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart:726-742` (`ExternalSiteSearchNotifier.importSite`)
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart:~616`
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart:~622`
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart:~458`
- Test: `test/features/universal_import/data/services/shearwater_value_mapper_test.dart` (extend)
- Test: `test/features/universal_import/data/services/shearwater_dive_mapper_metadata_test.dart` (extend)
- Test: `test/features/dive_sites/data/services/external_dive_site_types_test.dart`

**Interfaces:**
- Consumes: Task 1 `kBuiltInSiteTypeIds`; Task 5 `SiteClassification`, `SiteRepository.createSite(classification:)`, `SiteListNotifier.addSite(classification:)`; Task 12 `suggestedSiteTypeRefs` handling.
- Produces: `ShearwaterValueMapper.mapSiteType(String? environment)` returning `String?`; `ExternalDiveSite.features` populated from the asset; `ExternalDiveSite.siteTypeIds` (`List<String>`).

- [ ] **Step 1: Write the failing tests**

Add to `shearwater_value_mapper_test.dart`:

```dart
      test('maps environment to a built-in site type', () {
        expect(ShearwaterValueMapper.mapSiteType('Pool'), 'pool');
        expect(ShearwaterValueMapper.mapSiteType('Lake'), 'lake');
        expect(ShearwaterValueMapper.mapSiteType('Quarry'), 'quarry');
        expect(ShearwaterValueMapper.mapSiteType('River'), 'river');
        expect(ShearwaterValueMapper.mapSiteType('Ocean/Sea'), isNull);
        expect(ShearwaterValueMapper.mapSiteType('Brackish'), isNull);
        expect(ShearwaterValueMapper.mapSiteType(null), isNull);
      });
```

Add to `shearwater_dive_mapper_metadata_test.dart` (in the `mapSites` group):

```dart
      test('suggests a site type from the first dive\'s environment', () {
        const dives = [
          ShearwaterRawDive(diveId: 'a', site: 'Dutch Springs', environment: 'Quarry'),
          ShearwaterRawDive(diveId: 'b', site: 'Reef', environment: 'Ocean/Sea'),
        ];

        final sites = ShearwaterDiveMapper.mapSites(dives);

        expect(sites[0]['suggestedSiteTypeRefs'], ['quarry']);
        expect(sites[1].containsKey('suggestedSiteTypeRefs'), isFalse);
      });
```

Create `test/features/dive_sites/data/services/external_dive_site_types_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

void main() {
  ExternalDiveSite withFeatures(List<String> features) => ExternalDiveSite(
    externalId: 'x',
    name: 'x',
    features: features,
    source: 'test',
  );

  test('maps bundled features to built-in site types, exact matches only', () {
    expect(
      withFeatures(['wreck', 'sharks', 'wall', 'speleology', 'cave']).siteTypeIds,
      ['wreck', 'wall', 'cave'],
    );
    expect(withFeatures(['reef', 'lake', 'cavern']).siteTypeIds, [
      'reef',
      'lake',
      'cavern',
    ]);
    expect(withFeatures(['drift', 'training', 'sea']).siteTypeIds, isEmpty);
  });

  test('the bundled asset loader reads features', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sites = await DiveSiteApiService().allSitesWithCoordinates();
    expect(sites.any((s) => s.features.contains('wreck')), isTrue);
  });
}
```

Check `ExternalDiveSite`'s required constructor parameters and the name of the bundled-sites accessor against `dive_site_api_service_built_in_test.dart`, and adjust the two constructions.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/universal_import/data/services/shearwater_value_mapper_test.dart test/features/universal_import/data/services/shearwater_dive_mapper_metadata_test.dart test/features/dive_sites/data/services/external_dive_site_types_test.dart`
Expected: FAIL.

- [ ] **Step 3: Shearwater**

Add to `ShearwaterValueMapper`:

```dart
  /// Shearwater's Environment as a built-in site type slug (issue #1765).
  /// Ocean/Sea and Brackish describe the water, not the kind of place, so
  /// they map to no type.
  static String? mapSiteType(String? environment) {
    return switch (environment) {
      'Pool' => 'pool',
      'Lake' => 'lake',
      'Quarry' => 'quarry',
      'River' => 'river',
      _ => null,
    };
  }
```

In `mapSites`, inside the `putIfAbsent` builder before `return site;`:

```dart
        // A suggestion only: the importer applies it when the site has no
        // types yet, so it never overrides the diver's own choice.
        final siteType = ShearwaterValueMapper.mapSiteType(dive.environment);
        if (siteType != null) site['suggestedSiteTypeRefs'] = [siteType];
```

- [ ] **Step 4: Bundled database**

In `ExternalDiveSite`, add:

```dart
  /// Built-in site types for this site's bundled `features` (issue #1765).
  /// Exact matches only; the other features (drift, sharks, training...)
  /// describe the diving, not the place.
  List<String> get siteTypeIds {
    const featureToType = {
      'wreck': 'wreck',
      'wall': 'wall',
      'reef': 'reef',
      'lake': 'lake',
      'cave': 'cave',
      'speleology': 'cave',
      'cavern': 'cavern',
    };
    final ids = <String>{};
    for (final feature in features) {
      final type = featureToType[feature];
      if (type != null) ids.add(type);
    }
    return ids.toList();
  }
```

In `_loadBundledSites`, add to the `ExternalDiveSite(...)` construction:

```dart
          features: [
            for (final f in (site['features'] as List<dynamic>? ?? const []))
              if (f is String) f,
          ],
```

Reading `features` also makes `_buildDescription` add its "Features:" line for the 270 sites that have them, which the loader silently skipped until now.

- [ ] **Step 5: The three add paths**

- `ExternalSiteSearchNotifier.importSite` (site_providers.dart ~726-742): `await _siteListNotifier.addSite(site, classification: SiteClassification(typeIds: externalSite.siteTypeIds));`
- `site_map_page.dart` (~616) and `site_map_content.dart` (~622) `_addBuiltInSite`: `addSite(site.toDiveSite(), classification: SiteClassification(typeIds: site.siteTypeIds))`.
- `site_matching_service.dart` (~458): `_siteRepository.createSite(bundled.toDiveSite(diverId: diverId), classification: SiteClassification(typeIds: bundled.siteTypeIds))`.

Add a test beside the existing site matching service test: matching an import to a bundled wreck site creates the site with type `wreck` (read `site_matching_service_test.dart` for how it builds a bundled `ExternalDiveSite` and a repository).

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/universal_import test/features/dive_sites`
Expected: PASS.

```bash
dart format lib test
git add lib/features/universal_import/data/services/shearwater_value_mapper.dart lib/features/universal_import/data/services/shearwater_dive_mapper.dart lib/features/dive_sites test/features/universal_import test/features/dive_sites
git commit -m "feat(sites): infer site types from Shearwater and the bundled site database (#1765)"
```

---

### Task 14: Translations

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: List the new keys**

Run: `git diff main -- lib/l10n/arb/app_en.arb | grep '^+  "[a-zA-Z]' | sed 's/^+  "\([^"]*\)".*/\1/'`
Expected: every key added in Tasks 2 to 10 (about 70 keys: `settings_conflict_ref_siteType`, 16 `siteType_builtin_*`, the `diveSites_edit_*`, `diveSites_filter_section_*`, `diveSites_detail_showSitesWith`, `diveSites_list_moreTags`, 4 `enum_siteField_*`, the `siteTypes_*`, `settings_manage_siteTypes*`, the new `tags_manage_*`, and 4 `statistics_conditions_siteType_*`).

- [ ] **Step 2: Translate**

For each of the 10 locale files, add every key with a natural translation, inserted next to a neighbouring existing key of the same prefix (these files are grouped by feature, not alphabetical). Keep ICU plural and placeholder syntax exactly; translate only the text. Use the language's usual diving terms (for example German "Wrack", "Steilwand", "Riff"; French "Épave", "Tombant", "Récif"). Copy the `@key` metadata blocks only if that locale file carries `@` entries for its other keys.

- [ ] **Step 3: Regenerate and check**

Run: `flutter gen-l10n`
Expected: no "untranslated message" warnings for the new keys (run `flutter gen-l10n 2>&1 | grep -i untranslated` and confirm empty, or that the only entries predate this branch).

Run: `flutter test test/l10n` (if the directory exists) and `flutter test test/features/site_types/presentation/pages/site_types_page_test.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(l10n): translate site types and tags strings (#1765)"
```

---

### Task 15: Verification

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze`
Expected: no changes from format; analyze reports no issues (infos are fatal in CI). Do not pipe analyze output through `grep`/`tail` when checking the exit status.

- [ ] **Step 2: Em-dash and attribution scan**

Run: `git diff main --name-only | xargs grep -nP '\x{2014}' ; git log main..HEAD --format=%B | grep -niE 'claude|anthropic'`
Expected: no output from either.

- [ ] **Step 3: Full test suite, once**

Run: `flutter test` (the whole suite, a single run; do not start a second run in parallel)
Expected: PASS. A failure in a file this branch never touched on a clean main is inherited; check `main` before debugging.

- [ ] **Step 4: Manual smoke on macOS**

Run the app (`flutter run -d macos` from Ghostty or another terminal that holds the photo-library permission) and check:
- Settings > Manage Data > Site Types lists 16 translated built-ins; add, rename and delete a custom type.
- Edit a site: tick Wreck and Lake, add a new tag "To try"; save; the detail page shows both chips; tap "To try" and land on the filtered site list.
- The site card shows the type and tag chips; the dive edit page's tag field does not offer "To try".
- Settings > Tags shows "To try" as "Sites"; turning on Use for dives makes it appear on dives.
- Statistics > Conditions shows the Site Types bars.
- Export a full UDDF backup, then import it into a fresh library: types, tags and tag colors come back.

- [ ] **Step 5: Final commit (only if Steps 1 to 3 changed files)**

```bash
git add <the files the checks changed>
git commit -m "chore(sites): format and analyzer fixes (#1765)"
```
