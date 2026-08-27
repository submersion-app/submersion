# Upcoming Trips with To-Do Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement issue #164 — checklist templates, per-trip to-do lists with due dates, and an Upcoming section on the trips list — per the approved spec at `docs/superpowers/specs/2026-07-02-upcoming-trips-checklists-design.md`.

**Architecture:** Three new HLC-synced Drift tables (`checklist_templates`, `checklist_template_items`, `trip_checklist_items`) with copy-on-apply template semantics. Trip upcoming/completed status is derived from dates, never stored. New feature module `lib/features/checklists/` follows the itinerary-day/tank-preset repository and provider patterns.

**Tech Stack:** Flutter 3.x, Drift ORM (schema v94→v95), Riverpod (via `core/providers/provider.dart` barrel), go_router, Equatable, uuid.

## Global Constraints

- Schema migration is v94 → v95. `AppDatabase.currentSchemaVersion` becomes `95`.
- Sync entity type names (camelCase, used everywhere in the sync layer): `checklistTemplates`, `checklistTemplateItems`, `tripChecklistItems`. SQL table names: `checklist_templates`, `checklist_template_items`, `trip_checklist_items`.
- Drift generates row classes named `ChecklistTemplate`, `ChecklistTemplateItem`, `TripChecklistItem` — the SAME names as our domain entities. Repositories MUST import domain entities with `as domain` (established pattern, see `itinerary_day_repository.dart`).
- Every repository write calls `SyncRepository.markRecordPending(entityType: ..., recordId: ..., localUpdatedAt: ...)`; every delete reads rows first, deletes, then calls `logDeletion(entityType: ..., recordId: ...)` per row, then `SyncEventBus.notifyLocalChange()` once.
- All timestamps stored as `millisecondsSinceEpoch` ints. UUIDs via `final _uuid = const Uuid();` and `_uuid.v4()`; id resolution idiom: `entity.id.isEmpty ? _uuid.v4() : entity.id`.
- All new user-facing strings go in `lib/l10n/arb/app_en.arb` AND all 10 other locale files (ar, de, es, fr, he, hu, it, nl, pt, zh), then regenerate with `flutter gen-l10n`. Key naming: `feature_area_element` (e.g. `checklists_templates_pageTitle`).
- No emojis anywhere. Immutability always. Run `dart format .` (whole repo) before every commit. Never gate on `flutter analyze | tail` — run full `flutter analyze`.
- Run tests per-file or per-directory (e.g. `flutter test test/features/checklists/`), never the whole suite in one Bash call (timeout).
- Riverpod providers import `package:submersion/core/providers/provider.dart` (the barrel), never `flutter_riverpod` directly. Self-invalidation uses `ref.invalidateSelfWhen(stream)` — never hand-rolled `stream.listen(ref.invalidateSelf)`.
- Commit messages: conventional commits, no Co-Authored-By lines.

---

### Task 1: Drift tables + v95 migration

**Files:**
- Modify: `lib/core/database/database.dart` (table classes after `TripItineraryDays` ~line 127; `tables:` list ~line 1694; `currentSchemaVersion` line 1714; `migrationVersions` list ending ~line 1811; migration block after v94 block ~line 4336)
- Test: `test/core/database/migration_v95_checklists_test.dart`

**Interfaces:**
- Produces: Drift table getters `db.checklistTemplates`, `db.checklistTemplateItems`, `db.tripChecklistItems`; generated row classes `ChecklistTemplate`, `ChecklistTemplateItem`, `TripChecklistItem` and companions `ChecklistTemplatesCompanion`, `ChecklistTemplateItemsCompanion`, `TripChecklistItemsCompanion`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v95_checklists_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v95 creates the three checklist tables with hlc columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 94');
        // Minimal parents so FK references resolve.
        rawDb.execute('''
          CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)
        ''');
        rawDb.execute('''
          CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    for (final table in [
      'checklist_templates',
      'checklist_template_items',
      'trip_checklist_items',
    ]) {
      final cols = await db
          .customSelect("PRAGMA table_info('$table')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('id'), reason: '$table missing id');
      expect(names, contains('hlc'), reason: '$table missing hlc');
      expect(names, contains('created_at'), reason: '$table missing created_at');
    }

    final templateItemCols = await db
        .customSelect("PRAGMA table_info('checklist_template_items')")
        .get();
    final templateItemNames =
        templateItemCols.map((c) => c.read<String>('name')).toSet();
    expect(templateItemNames, contains('due_offset_days'));
    expect(templateItemNames, contains('sort_order'));

    final tripItemCols = await db
        .customSelect("PRAGMA table_info('trip_checklist_items')")
        .get();
    final tripItemNames =
        tripItemCols.map((c) => c.read<String>('name')).toSet();
    expect(tripItemNames, containsAll(['due_date', 'is_done', 'completed_at']));

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%checklist%'",
        )
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(indexNames, contains('idx_trip_checklist_items_trip_id'));
    expect(indexNames, contains('idx_checklist_template_items_template_id'));
  });

  test('schema version is 95 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, 95);
    expect(AppDatabase.migrationVersions, contains(95));
  });

  test('fresh database exposes the checklist tables via Drift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    expect(await db.select(db.checklistTemplates).get(), isEmpty);
    expect(await db.select(db.checklistTemplateItems).get(), isEmpty);
    expect(await db.select(db.tripChecklistItems).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v95_checklists_test.dart`
Expected: FAIL (compile error: `checklistTemplates` getter undefined, and/or version assertion fails with 94).

- [ ] **Step 3: Add the three table classes**

In `lib/core/database/database.dart`, immediately after the `TripItineraryDays` class (ends ~line 127), add:

```dart
/// Reusable checklist templates for trip planning (issue #164)
class ChecklistTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items belonging to a checklist template
class ChecklistTemplateItems extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text().references(ChecklistTemplates, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Days before trip start the item is due (14 = "two weeks out").
  IntColumn get dueOffsetDays => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-trip checklist items (copied from templates or added ad hoc)
class TripChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Absolute due date, resolved from the template offset at apply time.
  IntColumn get dueDate => integer().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Register tables, bump version, add migration block**

Still in `database.dart`:

(a) In the `@DriftDatabase(tables: [...])` list, after `TripItineraryDays,` (~line 1694), add:

```dart
    ChecklistTemplates,
    ChecklistTemplateItems,
    TripChecklistItems,
```

(b) Change line 1714 to `static const int currentSchemaVersion = 95;`

(c) In the `migrationVersions` list (ends with `94,` ~line 1811), append `95,`.

(d) After the `if (from < 94) await reportProgress();` line (~line 4336, just before the closing `},` of onUpgrade), add:

```dart
        if (from < 95) {
          // Checklist tables for trip planning (issue #164). Raw idempotent
          // DDL (matches the v84 idiom) so interrupted migrations are safe.
          await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_templates (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers (id),
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_template_items (
              id TEXT NOT NULL PRIMARY KEY,
              template_id TEXT NOT NULL REFERENCES checklist_templates (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_offset_days INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS trip_checklist_items (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL REFERENCES trips (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_date INTEGER,
              is_done INTEGER NOT NULL DEFAULT 0,
              completed_at INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id
            ON checklist_template_items(template_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_trip_id
            ON trip_checklist_items(trip_id)
          ''');
        }
        if (from < 95) await reportProgress();
```

Do NOT add the new tables to `_hlcTables` — that list is only for backfilling `hlc` onto tables that predate the HLC rollout; these tables are born with the column.

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes, writes `database.g.dart` with the new table getters.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v95_checklists_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(db): add checklist tables and v95 migration for trip planning (#164)"
```

---

### Task 2: Sync layer registration

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map, lines 29-54)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData fields ~line 233, constructor defaults ~line 275, toJson ~line 318, fromJson ~line 362, `_baseTables` ~line 548, `_buildSyncData` ~line 901, three `_export*` helpers ~line 2789, and the 7 entity switches: `fetchRecord` ~1084, `fetchRecords` ~1325, `upsertRecord` ~1449, `upsertRecords` ~1690, `recordIdsFor` ~2080, `_syncTableFor` ~2216, `deleteRecord` ~2307)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~line 829, `entityHasUpdatedAt` ~line 1451, `parentRefs` ~line 1522)
- Test: existing completeness tests in `test/core/services/sync/`

**Interfaces:**
- Consumes: Task 1's Drift tables/getters and generated row classes.
- Produces: sync entity types `checklistTemplates`, `checklistTemplateItems`, `tripChecklistItems` usable with `SyncRepository.markRecordPending` / `logDeletion` and included in base/changeset publish + merge.

The sync layer has completeness tests that assert every registration point stays in lockstep — they ARE the failing tests for this task.

- [ ] **Step 1: Run the completeness tests to capture the failing baseline**

Run: `flutter test test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart test/core/services/sync/sync_serializer_round_trip_test.dart`
Expected: FAIL — `sync_parent_refs_completeness_test.dart` detects the three new FK-bearing tables missing from `parentRefs` (the others may pass until SyncData gains the fields; note which fail).

- [ ] **Step 2: Register in `_hlcTargets`**

In `sync_repository.dart`, inside the `_hlcTargets` map after the `'itineraryDays'` entry, add:

```dart
    'checklistTemplates': (table: 'checklist_templates', pk: 'id'),
    'checklistTemplateItems': (table: 'checklist_template_items', pk: 'id'),
    'tripChecklistItems': (table: 'trip_checklist_items', pk: 'id'),
```

- [ ] **Step 3: Extend `SyncData` in `sync_data_serializer.dart`**

(a) Field declarations, after `itineraryDays` (~line 233):

```dart
  final List<Map<String, dynamic>> checklistTemplates;
  final List<Map<String, dynamic>> checklistTemplateItems;
  final List<Map<String, dynamic>> tripChecklistItems;
```

(b) Constructor defaults, after `this.itineraryDays = const [],`:

```dart
    this.checklistTemplates = const [],
    this.checklistTemplateItems = const [],
    this.tripChecklistItems = const [],
```

(c) `toJson`, after `'itineraryDays': itineraryDays,`:

```dart
      'checklistTemplates': checklistTemplates,
      'checklistTemplateItems': checklistTemplateItems,
      'tripChecklistItems': tripChecklistItems,
```

(d) `fromJson`, after the `itineraryDays:` line:

```dart
      checklistTemplates: _parseList(json['checklistTemplates']),
      checklistTemplateItems: _parseList(json['checklistTemplateItems']),
      tripChecklistItems: _parseList(json['tripChecklistItems']),
```

(e) `_baseTables` descriptor list, after the `itineraryDays` descriptor (keys MUST match toJson order — `debugBaseTableKeys` asserts this):

```dart
    (key: 'checklistTemplates', table: _db.checklistTemplates, blob: false, full: null),
    (key: 'checklistTemplateItems', table: _db.checklistTemplateItems, blob: false, full: null),
    (key: 'tripChecklistItems', table: _db.tripChecklistItems, blob: false, full: null),
```

(f) `_buildSyncData`, after the `itineraryDays:` export call:

```dart
      checklistTemplates: await _safeExport(
        'checklistTemplates',
        () => _exportChecklistTemplates(hlcSince),
      ),
      checklistTemplateItems: await _safeExport(
        'checklistTemplateItems',
        () => _exportChecklistTemplateItems(hlcSince),
      ),
      tripChecklistItems: await _safeExport(
        'tripChecklistItems',
        () => _exportTripChecklistItems(hlcSince),
      ),
```

(g) Export helpers, next to `_exportItineraryDays` (~line 2789):

```dart
  Future<List<Map<String, dynamic>>> _exportChecklistTemplates(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.checklistTemplates);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportChecklistTemplateItems(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.checklistTemplateItems);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTripChecklistItems(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tripChecklistItems);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

(h) Add a case to each of the 7 switches, modeled EXACTLY on the `itineraryDays` case in each (substituting table getter `_db.checklistTemplates` / `_db.checklistTemplateItems` / `_db.tripChecklistItems` and row class `ChecklistTemplate` / `ChecklistTemplateItem` / `TripChecklistItem`). For example, in `upsertRecords` (~line 1690):

```dart
      case 'checklistTemplates':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.checklistTemplates,
            records.map((r) => ChecklistTemplate.fromJson(r)).toList(),
          ),
        );
        return;
      case 'checklistTemplateItems':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.checklistTemplateItems,
            records.map((r) => ChecklistTemplateItem.fromJson(r)).toList(),
          ),
        );
        return;
      case 'tripChecklistItems':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tripChecklistItems,
            records.map((r) => TripChecklistItem.fromJson(r)).toList(),
          ),
        );
        return;
```

And in `fetchRecords` (~line 1325):

```dart
      case 'checklistTemplates':
        final rows = await (_db.select(_db.checklistTemplates)
              ..where((t) => t.id.isIn(idList)))
            .get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'checklistTemplateItems':
        final rows = await (_db.select(_db.checklistTemplateItems)
              ..where((t) => t.id.isIn(idList)))
            .get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'tripChecklistItems':
        final rows = await (_db.select(_db.tripChecklistItems)
              ..where((t) => t.id.isIn(idList)))
            .get();
        return {for (final r in rows) r.id: r.toJson()};
```

Repeat for `fetchRecord`, `upsertRecord`, `recordIdsFor` (`return plain(_db.checklistTemplates, _db.checklistTemplates.id);` etc.), `_syncTableFor` (`return _db.checklistTemplates;` etc.), and `deleteRecord` (`await (_db.delete(_db.checklistTemplates)..where((t) => t.id.equals(recordId))).go(); return;` etc.). No `_recordIdForEntity` case needed (all three use `id` PKs).

- [ ] **Step 4: Extend `sync_service.dart`**

(a) `mergeOrder`, after the `itineraryDays` entry (parents before children):

```dart
      (type: 'checklistTemplates', records: data.checklistTemplates, hasUpdatedAt: true),
      (type: 'checklistTemplateItems', records: data.checklistTemplateItems, hasUpdatedAt: true),
      (type: 'tripChecklistItems', records: data.tripChecklistItems, hasUpdatedAt: true),
```

(b) `entityHasUpdatedAt` map, matching entries:

```dart
    'checklistTemplates': true,
    'checklistTemplateItems': true,
    'tripChecklistItems': true,
```

(c) `parentRefs` map (mirror the nullable-vs-not conventions of the existing `trips` diverId entry — check how `'trips'` itself is declared and copy its diverId handling for `checklistTemplates`):

```dart
    'checklistTemplates': [(field: 'diverId', parent: 'divers', nullable: true)],
    'checklistTemplateItems': [
      (field: 'templateId', parent: 'checklistTemplates', nullable: false),
    ],
    'tripChecklistItems': [(field: 'tripId', parent: 'trips', nullable: false)],
```

If `trips` is NOT present in `parentRefs` with a diverId entry, match whatever the existing convention is for diver-owned tables (e.g. `tankPresets`) instead of inventing one.

- [ ] **Step 5: Run the completeness tests to verify they pass**

Run: `flutter test test/core/services/sync/`
Expected: PASS (all files, including `base_publish_streaming_parity_test.dart` and `sync_base_streaming_parity_test.dart`).

- [ ] **Step 6: Full analyze + commit**

```bash
flutter analyze
dart format .
git add -A
git commit -m "feat(sync): register checklist entities across the sync layer (#164)"
```

---

### Task 3: Domain entities + Trip derived status

**Files:**
- Create: `lib/features/checklists/domain/entities/checklist_template.dart`
- Create: `lib/features/checklists/domain/entities/trip_checklist_item.dart`
- Modify: `lib/features/trips/domain/entities/trip.dart` (add `isUpcoming`, `isInProgress`, `daysUntilStart` getters after `containsDate`, ~line 58)
- Test: `test/features/checklists/domain/entities/checklist_entities_test.dart`
- Test: `test/features/trips/domain/entities/trip_upcoming_test.dart`

**Interfaces:**
- Produces:
  - `domain.ChecklistTemplate({required String id, String? diverId, required String name, String description = '', required DateTime createdAt, required DateTime updatedAt})` with `copyWith` (sentinel for `diverId`).
  - `domain.ChecklistTemplateItem({required String id, required String templateId, required String title, String? category, String notes = '', int? dueOffsetDays, int sortOrder = 0, required DateTime createdAt, required DateTime updatedAt})` with `copyWith` (sentinel for `category`, `dueOffsetDays`).
  - `domain.TripChecklistItem({required String id, required String tripId, required String title, String? category, String notes = '', DateTime? dueDate, bool isDone = false, DateTime? completedAt, int sortOrder = 0, required DateTime createdAt, required DateTime updatedAt})` with `copyWith` (sentinel for `category`, `dueDate`, `completedAt`) and `bool isOverdue(DateTime now)`.
  - `Trip.isUpcoming` (bool getter), `Trip.isInProgress` (bool getter), `Trip.daysUntilStart` (int getter).

- [ ] **Step 1: Write the failing entity tests**

Create `test/features/trips/domain/entities/trip_upcoming_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

Trip _trip({required DateTime start, required DateTime end}) => Trip(
  id: 't1',
  name: 'Test',
  startDate: start,
  endDate: end,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('Trip.isUpcoming', () {
    test('trip ending in the future is upcoming', () {
      final t = _trip(
        start: today.add(const Duration(days: 10)),
        end: today.add(const Duration(days: 17)),
      );
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending today is still upcoming (date-only comparison)', () {
      // End set to 00:00 today: must count as upcoming even though the
      // instant is in the past — comparison is by calendar date.
      final t = _trip(start: today.subtract(const Duration(days: 5)), end: today);
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending yesterday is not upcoming', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 7)),
        end: today.subtract(const Duration(days: 1)),
      );
      expect(t.isUpcoming, isFalse);
    });
  });

  group('Trip.isInProgress and daysUntilStart', () {
    test('trip started but not ended is in progress', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 2)),
        end: today.add(const Duration(days: 3)),
      );
      expect(t.isInProgress, isTrue);
      expect(t.isUpcoming, isTrue);
    });

    test('trip starting today is in progress with zero days until start', () {
      final t = _trip(start: today, end: today.add(const Duration(days: 5)));
      expect(t.isInProgress, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('daysUntilStart counts calendar days for a future trip', () {
      final t = _trip(
        start: today.add(const Duration(days: 24)),
        end: today.add(const Duration(days: 31)),
      );
      expect(t.daysUntilStart, 24);
      expect(t.isInProgress, isFalse);
    });
  });
}
```

Create `test/features/checklists/domain/entities/checklist_entities_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';

void main() {
  final created = DateTime(2026, 1, 1);

  group('TripChecklistItem', () {
    TripChecklistItem item({DateTime? dueDate, bool isDone = false}) =>
        TripChecklistItem(
          id: 'i1',
          tripId: 't1',
          title: 'Service regulator',
          dueDate: dueDate,
          isDone: isDone,
          createdAt: created,
          updatedAt: created,
        );

    test('isOverdue when due date passed and not done', () {
      final it = item(dueDate: DateTime(2026, 6, 1));
      expect(it.isOverdue(DateTime(2026, 6, 2)), isTrue);
    });

    test('not overdue when done, when due today, or when dateless', () {
      expect(
        item(dueDate: DateTime(2026, 6, 1), isDone: true)
            .isOverdue(DateTime(2026, 6, 2)),
        isFalse,
      );
      expect(
        item(dueDate: DateTime(2026, 6, 2)).isOverdue(DateTime(2026, 6, 2, 18)),
        isFalse,
        reason: 'due today is not overdue (date-only comparison)',
      );
      expect(item().isOverdue(DateTime(2026, 6, 2)), isFalse);
    });

    test('copyWith can clear nullable fields via sentinel', () {
      final it = item(dueDate: DateTime(2026, 6, 1))
          .copyWith(category: 'Gear', notes: 'annual');
      expect(it.category, 'Gear');
      final cleared = it.copyWith(dueDate: null, category: null);
      expect(cleared.dueDate, isNull);
      expect(cleared.category, isNull);
      expect(cleared.title, 'Service regulator');
    });

    test('equatable includes isDone', () {
      expect(item(), isNot(equals(item(isDone: true))));
    });
  });

  group('ChecklistTemplateItem', () {
    test('copyWith clears dueOffsetDays via sentinel', () {
      final it = ChecklistTemplateItem(
        id: 'x1',
        templateId: 'tpl1',
        title: 'Book flights',
        dueOffsetDays: 60,
        createdAt: created,
        updatedAt: created,
      );
      expect(it.copyWith(dueOffsetDays: null).dueOffsetDays, isNull);
      expect(it.copyWith(title: 'Book hotel').dueOffsetDays, 60);
    });
  });

  group('ChecklistTemplate', () {
    test('equatable and copyWith', () {
      final a = ChecklistTemplate(
        id: 'tpl1',
        name: 'Liveaboard packing',
        createdAt: created,
        updatedAt: created,
      );
      expect(a.copyWith(name: 'Resort packing'), isNot(equals(a)));
      expect(a.copyWith(description: 'd').id, 'tpl1');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/checklists/domain/ test/features/trips/domain/entities/trip_upcoming_test.dart`
Expected: FAIL (missing files / missing getters).

- [ ] **Step 3: Add derived-status getters to Trip**

In `lib/features/trips/domain/entities/trip.dart`, after `containsDate` (~line 58), add:

```dart
  /// Whether this trip is upcoming or currently underway (date-only
  /// comparison, same normalization as [containsDate]).
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !end.isBefore(today);
  }

  /// Whether the trip has started but not yet ended (date-only).
  bool get isInProgress {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !start.isAfter(today) && !end.isBefore(today);
  }

  /// Calendar days until the trip starts (0 when started or starting today).
  int get daysUntilStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = start.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }
```

- [ ] **Step 4: Create the entity files**

Create `lib/features/checklists/domain/entities/checklist_template.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Reusable checklist template for trip planning
class ChecklistTemplate extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplate({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistTemplate copyWith({
    String? id,
    Object? diverId = _undefined,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplate(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    description,
    createdAt,
    updatedAt,
  ];
}

/// Item belonging to a checklist template
class ChecklistTemplateItem extends Equatable {
  final String id;
  final String templateId;
  final String title;
  final String? category;
  final String notes;

  /// Days before trip start the item is due (null = no due date).
  final int? dueOffsetDays;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplateItem({
    required this.id,
    required this.templateId,
    required this.title,
    this.category,
    this.notes = '',
    this.dueOffsetDays,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ChecklistTemplateItem copyWith({
    String? id,
    String? templateId,
    String? title,
    Object? category = _undefined,
    String? notes,
    Object? dueOffsetDays = _undefined,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      category: category == _undefined ? this.category : category as String?,
      notes: notes ?? this.notes,
      dueOffsetDays: dueOffsetDays == _undefined
          ? this.dueOffsetDays
          : dueOffsetDays as int?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    templateId,
    title,
    category,
    notes,
    dueOffsetDays,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

Create `lib/features/checklists/domain/entities/trip_checklist_item.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Per-trip checklist item (copied from a template or added ad hoc)
class TripChecklistItem extends Equatable {
  final String id;
  final String tripId;
  final String title;
  final String? category;
  final String notes;

  /// Absolute due date, resolved from the template offset at apply time.
  final DateTime? dueDate;
  final bool isDone;
  final DateTime? completedAt;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripChecklistItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.category,
    this.notes = '',
    this.dueDate,
    this.isDone = false,
    this.completedAt,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Overdue when the due date has passed (date-only) and the item is
  /// not done. Callers must additionally gate on Trip.isUpcoming so past
  /// trips never nag.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isDone) return false;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(today);
  }

  TripChecklistItem copyWith({
    String? id,
    String? tripId,
    String? title,
    Object? category = _undefined,
    String? notes,
    Object? dueDate = _undefined,
    bool? isDone,
    Object? completedAt = _undefined,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklistItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      category: category == _undefined ? this.category : category as String?,
      notes: notes ?? this.notes,
      dueDate: dueDate == _undefined ? this.dueDate : dueDate as DateTime?,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    title,
    category,
    notes,
    dueDate,
    isDone,
    completedAt,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/checklists/domain/ test/features/trips/domain/entities/trip_upcoming_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): domain entities and derived trip status (#164)"
```

---

### Task 4: ChecklistTemplateRepository

**Files:**
- Create: `lib/features/checklists/data/repositories/checklist_template_repository.dart`
- Test: `test/features/checklists/data/repositories/checklist_template_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 3 entities (`as domain`), `SyncRepository.markRecordPending`/`logDeletion`, `SyncEventBus.notifyLocalChange`.
- Produces:
  - `Stream<void> watchTemplatesChanges()` — watches BOTH template tables.
  - `Future<List<domain.ChecklistTemplate>> getAllTemplates({String? diverId})` — templates whose diverId matches or is null, ordered by name.
  - `Future<domain.ChecklistTemplate?> getTemplateById(String id)`
  - `Future<List<domain.ChecklistTemplateItem>> getItemsForTemplate(String templateId)` — ordered by sortOrder.
  - `Future<domain.ChecklistTemplate> createTemplate(domain.ChecklistTemplate template)` — returns entity with resolved id/timestamps.
  - `Future<void> updateTemplate(domain.ChecklistTemplate template)`
  - `Future<void> deleteTemplate(String id)` — deletes items first (tombstones each), then template.
  - `Future<void> saveItems(String templateId, List<domain.ChecklistTemplateItem> items)` — replace-all: deletes existing items (tombstoning removed ids), re-inserts with fresh sortOrder from list position.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/checklists/data/repositories/checklist_template_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ChecklistTemplateRepository repository;

  ChecklistTemplate template({String name = 'Packing'}) => ChecklistTemplate(
    id: '',
    name: name,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  ChecklistTemplateItem item(
    String templateId, {
    String title = 'Wetsuit',
    int? dueOffsetDays,
    String? category,
  }) => ChecklistTemplateItem(
    id: '',
    templateId: templateId,
    title: title,
    category: category,
    dueOffsetDays: dueOffsetDays,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = ChecklistTemplateRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('createTemplate / getAllTemplates / getTemplateById', () {
    test('creates with generated id and reads back', () async {
      final created = await repository.createTemplate(template());
      expect(created.id, isNotEmpty);
      final all = await repository.getAllTemplates();
      expect(all, hasLength(1));
      expect(all.first.name, 'Packing');
      final byId = await repository.getTemplateById(created.id);
      expect(byId, isNotNull);
    });

    test('orders templates by name', () async {
      await repository.createTemplate(template(name: 'Zeta'));
      await repository.createTemplate(template(name: 'Alpha'));
      final all = await repository.getAllTemplates();
      expect(all.map((t) => t.name).toList(), ['Alpha', 'Zeta']);
    });
  });

  group('saveItems / getItemsForTemplate', () {
    test('replace-all save assigns sortOrder from list position', () async {
      final tpl = await repository.createTemplate(template());
      await repository.saveItems(tpl.id, [
        item(tpl.id, title: 'B'),
        item(tpl.id, title: 'A', dueOffsetDays: 14, category: 'Gear'),
      ]);
      final items = await repository.getItemsForTemplate(tpl.id);
      expect(items.map((i) => i.title).toList(), ['B', 'A']);
      expect(items[1].dueOffsetDays, 14);
      expect(items[1].category, 'Gear');

      // Re-save with one item: the other is removed.
      await repository.saveItems(tpl.id, [item(tpl.id, title: 'A only')]);
      final after = await repository.getItemsForTemplate(tpl.id);
      expect(after, hasLength(1));
      expect(after.single.title, 'A only');
    });
  });

  group('updateTemplate / deleteTemplate', () {
    test('update changes name, delete removes template and items', () async {
      final tpl = await repository.createTemplate(template());
      await repository.updateTemplate(tpl.copyWith(name: 'Renamed'));
      expect((await repository.getTemplateById(tpl.id))!.name, 'Renamed');

      await repository.saveItems(tpl.id, [item(tpl.id)]);
      await repository.deleteTemplate(tpl.id);
      expect(await repository.getTemplateById(tpl.id), isNull);
      expect(await repository.getItemsForTemplate(tpl.id), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/data/repositories/checklist_template_repository_test.dart`
Expected: FAIL (repository file missing).

- [ ] **Step 3: Implement the repository**

Create `lib/features/checklists/data/repositories/checklist_template_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;

class ChecklistTemplateRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ChecklistTemplateRepository);

  Stream<void> watchTemplatesChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.checklistTemplates,
      _db.checklistTemplateItems,
    ]),
  );

  Future<List<domain.ChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.checklistTemplates)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
      }
      final rows = await query.get();
      return rows.map(_mapTemplate).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get checklist templates', e, stackTrace);
      rethrow;
    }
  }

  Future<domain.ChecklistTemplate?> getTemplateById(String id) async {
    try {
      final row = await (_db.select(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _mapTemplate(row);
    } catch (e, stackTrace) {
      _log.severe('Failed to get checklist template $id', e, stackTrace);
      rethrow;
    }
  }

  Future<List<domain.ChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.checklistTemplateItems)
                ..where((t) => t.templateId.equals(templateId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapItem).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get template items', e, stackTrace);
      rethrow;
    }
  }

  Future<domain.ChecklistTemplate> createTemplate(
    domain.ChecklistTemplate template,
  ) async {
    try {
      final id = template.id.isEmpty ? _uuid.v4() : template.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.checklistTemplates)
          .insert(
            ChecklistTemplatesCompanion(
              id: Value(id),
              diverId: Value(template.diverId),
              name: Value(template.name),
              description: Value(template.description),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'checklistTemplates',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return template.copyWith(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to create checklist template', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateTemplate(domain.ChecklistTemplate template) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        ChecklistTemplatesCompanion(
          name: Value(template.name),
          description: Value(template.description),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'checklistTemplates',
        recordId: template.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to update checklist template', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      final items = await getItemsForTemplate(id);
      await (_db.delete(
        _db.checklistTemplateItems,
      )..where((t) => t.templateId.equals(id))).go();
      for (final item in items) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateItems',
          recordId: item.id,
        );
      }
      await (_db.delete(
        _db.checklistTemplates,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'checklistTemplates',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to delete checklist template $id', e, stackTrace);
      rethrow;
    }
  }

  /// Replace-all save of a template's items. sortOrder is assigned from
  /// list position; removed items are tombstoned.
  Future<void> saveItems(
    String templateId,
    List<domain.ChecklistTemplateItem> items,
  ) async {
    try {
      final existing = await getItemsForTemplate(templateId);
      final now = DateTime.now().millisecondsSinceEpoch;
      final resolved = <({String id, domain.ChecklistTemplateItem item})>[];
      for (final item in items) {
        resolved.add((
          id: item.id.isEmpty ? _uuid.v4() : item.id,
          item: item,
        ));
      }
      final keptIds = resolved.map((r) => r.id).toSet();
      final removed = existing.where((e) => !keptIds.contains(e.id)).toList();

      await (_db.delete(
        _db.checklistTemplateItems,
      )..where((t) => t.templateId.equals(templateId))).go();
      await _db.batch((batch) {
        for (var i = 0; i < resolved.length; i++) {
          final entry = resolved[i];
          batch.insert(
            _db.checklistTemplateItems,
            ChecklistTemplateItemsCompanion(
              id: Value(entry.id),
              templateId: Value(templateId),
              title: Value(entry.item.title),
              category: Value(entry.item.category),
              notes: Value(entry.item.notes),
              dueOffsetDays: Value(entry.item.dueOffsetDays),
              sortOrder: Value(i),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      for (final entry in resolved) {
        await _syncRepository.markRecordPending(
          entityType: 'checklistTemplateItems',
          recordId: entry.id,
          localUpdatedAt: now,
        );
      }
      for (final item in removed) {
        await _syncRepository.logDeletion(
          entityType: 'checklistTemplateItems',
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to save template items', e, stackTrace);
      rethrow;
    }
  }

  domain.ChecklistTemplate _mapTemplate(ChecklistTemplate row) =>
      domain.ChecklistTemplate(
        id: row.id,
        diverId: row.diverId,
        name: row.name,
        description: row.description,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  domain.ChecklistTemplateItem _mapItem(ChecklistTemplateItem row) =>
      domain.ChecklistTemplateItem(
        id: row.id,
        templateId: row.templateId,
        title: row.title,
        category: row.category,
        notes: row.notes,
        dueOffsetDays: row.dueOffsetDays,
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
```

Note: if `TableUpdateQuery.onAllTables` does not exist in the project's Drift version, use `TableUpdateQuery.onAllTables([...])`'s actual equivalent — check how `watchDiveDetailChanges()` in `lib/features/dive_log/data/repositories/dive_repository_impl.dart:93` watches multiple tables and copy that exact API.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checklists/data/repositories/checklist_template_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): checklist template repository (#164)"
```

---

### Task 5: TripChecklistRepository (CRUD + applyTemplate + saveAsTemplate + progress)

**Files:**
- Create: `lib/features/checklists/data/repositories/trip_checklist_repository.dart`
- Test: `test/features/checklists/data/repositories/trip_checklist_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 3 entities (`as domain`), Task 4's `ChecklistTemplateRepository` (for `saveAsTemplate`), `Trip` entity.
- Produces:
  - `Stream<void> watchTripChecklistChanges()` — watches `trip_checklist_items`.
  - `Future<List<domain.TripChecklistItem>> getByTripId(String tripId)` — ordered by sortOrder.
  - `Future<domain.TripChecklistItem> createItem(domain.TripChecklistItem item)`
  - `Future<void> updateItem(domain.TripChecklistItem item)` — writes title/category/notes/dueDate/isDone/completedAt/sortOrder.
  - `Future<void> toggleDone(String id, {required bool isDone})` — sets isDone + completedAt (now when done, null when undone).
  - `Future<void> deleteItem(String id)`
  - `Future<void> deleteByTripId(String tripId)` — bulk cascade used by TripRepository.
  - `Future<({int added, int skipped})> applyTemplate({required String templateId, required Trip trip})` — copy-on-apply; throws `StateError` if template missing.
  - `Future<domain.ChecklistTemplate> saveAsTemplate({required String tripId, required DateTime tripStartDate, required String name, String? diverId})` — reverse copy (absolute dates → offsets).
  - `Future<({int done, int total})> getProgress(String tripId)`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/checklists/data/repositories/trip_checklist_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripChecklistRepository repository;
  late ChecklistTemplateRepository templateRepository;
  late TripRepository tripRepository;
  late Trip testTrip;

  final tripStart = DateTime(2026, 9, 10);

  TripChecklistItem item({
    String title = 'Service regulator',
    String? category,
    DateTime? dueDate,
  }) => TripChecklistItem(
    id: '',
    tripId: testTrip.id,
    title: title,
    category: category,
    dueDate: dueDate,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = TripChecklistRepository();
    templateRepository = ChecklistTemplateRepository();
    tripRepository = TripRepository();
    // Parent trip satisfies the FK constraint (foreign_keys = ON in tests).
    testTrip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: tripStart,
        endDate: tripStart.add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('CRUD', () {
    test('create, read ordered, update, toggle, delete', () async {
      final a = await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B', category: 'Gear'));
      var items = await repository.getByTripId(testTrip.id);
      expect(items.map((i) => i.title).toList(), ['A', 'B']);

      await repository.updateItem(a.copyWith(notes: 'annual service'));
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.notes, 'annual service');

      await repository.toggleDone(a.id, isDone: true);
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.isDone, isTrue);
      expect(items.first.completedAt, isNotNull);

      await repository.toggleDone(a.id, isDone: false);
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.isDone, isFalse);
      expect(items.first.completedAt, isNull);

      await repository.deleteItem(a.id);
      expect(await repository.getByTripId(testTrip.id), hasLength(1));
    });
  });

  group('applyTemplate', () {
    late ChecklistTemplate template;

    setUp(() async {
      template = await templateRepository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Prep',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await templateRepository.saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Book flights',
          category: 'Bookings',
          dueOffsetDays: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Pack wetsuit',
          category: 'Gear',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
    });

    test('copies items resolving offsets to absolute due dates', () async {
      final result = await repository.applyTemplate(
        templateId: template.id,
        trip: testTrip,
      );
      expect(result.added, 2);
      expect(result.skipped, 0);

      final items = await repository.getByTripId(testTrip.id);
      expect(items, hasLength(2));
      final flights = items.firstWhere((i) => i.title == 'Book flights');
      expect(flights.dueDate, tripStart.subtract(const Duration(days: 60)));
      final wetsuit = items.firstWhere((i) => i.title == 'Pack wetsuit');
      expect(wetsuit.dueDate, isNull);
      expect(items.every((i) => !i.isDone), isTrue);
    });

    test('re-apply skips items with matching title and category', () async {
      await repository.applyTemplate(templateId: template.id, trip: testTrip);
      final second = await repository.applyTemplate(
        templateId: template.id,
        trip: testTrip,
      );
      expect(second.added, 0);
      expect(second.skipped, 2);
      expect(await repository.getByTripId(testTrip.id), hasLength(2));
    });

    test('throws StateError when template does not exist', () async {
      await expectLater(
        repository.applyTemplate(templateId: 'missing', trip: testTrip),
        throwsStateError,
      );
      expect(await repository.getByTripId(testTrip.id), isEmpty);
    });
  });

  group('saveAsTemplate', () {
    test('converts absolute due dates back to offsets', () async {
      await repository.createItem(
        item(
          title: 'Book flights',
          category: 'Bookings',
          dueDate: tripStart.subtract(const Duration(days: 60)),
        ),
      );
      await repository.createItem(item(title: 'Pack wetsuit'));

      final tpl = await repository.saveAsTemplate(
        tripId: testTrip.id,
        tripStartDate: testTrip.startDate,
        name: 'My prep',
      );
      final items = await templateRepository.getItemsForTemplate(tpl.id);
      expect(items, hasLength(2));
      final flights = items.firstWhere((i) => i.title == 'Book flights');
      expect(flights.dueOffsetDays, 60);
      final wetsuit = items.firstWhere((i) => i.title == 'Pack wetsuit');
      expect(wetsuit.dueOffsetDays, isNull);
    });
  });

  group('progress and cascade', () {
    test('getProgress counts done vs total', () async {
      final a = await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B'));
      await repository.toggleDone(a.id, isDone: true);
      final progress = await repository.getProgress(testTrip.id);
      expect(progress.done, 1);
      expect(progress.total, 2);
    });

    test('deleteByTripId removes all items', () async {
      await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B'));
      await repository.deleteByTripId(testTrip.id);
      expect(await repository.getByTripId(testTrip.id), isEmpty);
    });
  });
}
```

Note: check `TripRepository.createTrip`'s exact signature before writing the test — if it takes a `Trip` and returns `Future<Trip>` this stands; if it differs (e.g. named params), adapt the setUp to the real API (see how `itinerary_day_repository_test.dart` creates its parent trip and copy that exactly).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/data/repositories/trip_checklist_repository_test.dart`
Expected: FAIL (repository file missing).

- [ ] **Step 3: Implement the repository**

Create `lib/features/checklists/data/repositories/trip_checklist_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip.dart';

class TripChecklistRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripChecklistRepository);

  Stream<void> watchTripChecklistChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripChecklistItems));

  Future<List<domain.TripChecklistItem>> getByTripId(String tripId) async {
    try {
      final rows =
          await (_db.select(_db.tripChecklistItems)
                ..where((t) => t.tripId.equals(tripId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      return rows.map(_mapRow).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get checklist for trip $tripId', e, stackTrace);
      rethrow;
    }
  }

  Future<domain.TripChecklistItem> createItem(
    domain.TripChecklistItem item,
  ) async {
    try {
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sortOrder = await _nextSortOrder(item.tripId);
      await _db
          .into(_db.tripChecklistItems)
          .insert(
            TripChecklistItemsCompanion(
              id: Value(id),
              tripId: Value(item.tripId),
              title: Value(item.title),
              category: Value(item.category),
              notes: Value(item.notes),
              dueDate: Value(item.dueDate?.millisecondsSinceEpoch),
              isDone: Value(item.isDone),
              completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return item.copyWith(
        id: id,
        sortOrder: sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to create checklist item', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateItem(domain.TripChecklistItem item) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(item.id))).write(
        TripChecklistItemsCompanion(
          title: Value(item.title),
          category: Value(item.category),
          notes: Value(item.notes),
          dueDate: Value(item.dueDate?.millisecondsSinceEpoch),
          isDone: Value(item.isDone),
          completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
          sortOrder: Value(item.sortOrder),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: item.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to update checklist item ${item.id}', e, stackTrace);
      rethrow;
    }
  }

  Future<void> toggleDone(String id, {required bool isDone}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(id))).write(
        TripChecklistItemsCompanion(
          isDone: Value(isDone),
          completedAt: Value(isDone ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripChecklistItems',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to toggle checklist item $id', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'tripChecklistItems',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to delete checklist item $id', e, stackTrace);
      rethrow;
    }
  }

  /// Bulk cascade used by TripRepository.deleteTrip.
  Future<void> deleteByTripId(String tripId) async {
    try {
      final existing = await getByTripId(tripId);
      if (existing.isEmpty) return;
      await (_db.delete(
        _db.tripChecklistItems,
      )..where((t) => t.tripId.equals(tripId))).go();
      for (final item in existing) {
        await _syncRepository.logDeletion(
          entityType: 'tripChecklistItems',
          recordId: item.id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.severe('Failed to delete checklist for trip $tripId', e, stackTrace);
      rethrow;
    }
  }

  /// Copy-on-apply: copies template items into the trip, resolving due
  /// offsets against the trip start date. Items whose title and category
  /// match an existing trip item are skipped so re-apply is idempotent.
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
    required Trip trip,
  }) async {
    try {
      final templateRepository = ChecklistTemplateRepository();
      return await _db.transaction(() async {
        final template = await templateRepository.getTemplateById(templateId);
        if (template == null) {
          throw StateError('Checklist template $templateId no longer exists');
        }
        final templateItems = await templateRepository.getItemsForTemplate(
          templateId,
        );
        final existing = await getByTripId(trip.id);
        final existingKeys = existing
            .map((i) => '${i.title} ${i.category ?? ''}')
            .toSet();
        final now = DateTime.now().millisecondsSinceEpoch;
        var sortOrder = await _nextSortOrder(trip.id);
        final pendingIds = <String>[];
        var added = 0;
        var skipped = 0;

        for (final item in templateItems) {
          final key = '${item.title} ${item.category ?? ''}';
          if (existingKeys.contains(key)) {
            skipped++;
            continue;
          }
          final id = _uuid.v4();
          final dueDate = item.dueOffsetDays == null
              ? null
              : trip.startDate
                    .subtract(Duration(days: item.dueOffsetDays!))
                    .millisecondsSinceEpoch;
          await _db
              .into(_db.tripChecklistItems)
              .insert(
                TripChecklistItemsCompanion(
                  id: Value(id),
                  tripId: Value(trip.id),
                  title: Value(item.title),
                  category: Value(item.category),
                  notes: Value(item.notes),
                  dueDate: Value(dueDate),
                  isDone: const Value(false),
                  sortOrder: Value(sortOrder++),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          pendingIds.add(id);
          added++;
        }

        for (final id in pendingIds) {
          await _syncRepository.markRecordPending(
            entityType: 'tripChecklistItems',
            recordId: id,
            localUpdatedAt: now,
          );
        }
        SyncEventBus.notifyLocalChange();
        return (added: added, skipped: skipped);
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to apply template $templateId', e, stackTrace);
      rethrow;
    }
  }

  /// Reverse copy: snapshot a trip's checklist as a reusable template.
  /// Absolute due dates convert back to offsets from the trip start date
  /// (only when the due date is on or before the start); dateless items
  /// stay dateless.
  Future<domain.ChecklistTemplate> saveAsTemplate({
    required String tripId,
    required DateTime tripStartDate,
    required String name,
    String? diverId,
  }) async {
    try {
      final templateRepository = ChecklistTemplateRepository();
      final items = await getByTripId(tripId);
      final template = await templateRepository.createTemplate(
        domain.ChecklistTemplate(
          id: '',
          diverId: diverId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final templateItems = items.map((item) {
        int? offset;
        final due = item.dueDate;
        if (due != null) {
          final days = tripStartDate.difference(due).inDays;
          offset = days >= 0 ? days : null;
        }
        return domain.ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: item.title,
          category: item.category,
          notes: item.notes,
          dueOffsetDays: offset,
          sortOrder: item.sortOrder,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
      await templateRepository.saveItems(template.id, templateItems);
      return template;
    } catch (e, stackTrace) {
      _log.severe('Failed to save trip $tripId checklist as template', e, stackTrace);
      rethrow;
    }
  }

  Future<({int done, int total})> getProgress(String tripId) async {
    try {
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS total, '
            'SUM(CASE WHEN is_done THEN 1 ELSE 0 END) AS done '
            'FROM trip_checklist_items WHERE trip_id = ?',
            variables: [Variable.withString(tripId)],
            readsFrom: {_db.tripChecklistItems},
          )
          .getSingle();
      return (
        done: row.read<int?>('done') ?? 0,
        total: row.read<int>('total'),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to get checklist progress', e, stackTrace);
      rethrow;
    }
  }

  Future<int> _nextSortOrder(String tripId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM trip_checklist_items WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  domain.TripChecklistItem _mapRow(TripChecklistItem row) =>
      domain.TripChecklistItem(
        id: row.id,
        tripId: row.tripId,
        title: row.title,
        category: row.category,
        notes: row.notes,
        dueDate: row.dueDate == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.dueDate!),
        isDone: row.isDone,
        completedAt: row.completedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
        sortOrder: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checklists/data/repositories/trip_checklist_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): trip checklist repository with copy-on-apply templates (#164)"
```

---

### Task 6: Trip delete cascade

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`deleteTrip`, lines 269-297)
- Test: `test/features/checklists/data/repositories/trip_checklist_cascade_test.dart`

**Interfaces:**
- Consumes: Task 5's `TripChecklistRepository.deleteByTripId`.

- [ ] **Step 1: Write the failing cascade test**

Create `test/features/checklists/data/repositories/trip_checklist_cascade_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('deleting a trip deletes its checklist items and tombstones them', () async {
    final tripRepository = TripRepository();
    final checklistRepository = TripChecklistRepository();

    final trip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Cascade',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final item = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Pack fins',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tripRepository.deleteTrip(trip.id);

    // Items gone (FK would also have blocked the trip delete otherwise).
    expect(await checklistRepository.getByTripId(trip.id), isEmpty);

    // Tombstone written for the checklist item.
    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'tripChecklistItems'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains(item.id),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/data/repositories/trip_checklist_cascade_test.dart`
Expected: FAIL — `deleteTrip` hits the FK constraint on `trip_checklist_items` (or the tombstone assertion fails).

- [ ] **Step 3: Add the cascade to `TripRepository.deleteTrip`**

In `lib/features/trips/data/repositories/trip_repository.dart`, add the import:

```dart
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
```

In `deleteTrip`, after the `ItineraryDayRepository().deleteByTripId(id);` line, add:

```dart
      await TripChecklistRepository().deleteByTripId(id);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checklists/data/repositories/trip_checklist_cascade_test.dart test/features/trips/data/`
Expected: PASS (cascade test and no regression in trip repository tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): cascade checklist items on trip delete (#164)"
```

---

### Task 7: Riverpod providers

**Files:**
- Create: `lib/features/checklists/presentation/providers/checklist_providers.dart`
- Test: `test/features/checklists/presentation/providers/checklist_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 4-5 repositories; `validatedCurrentDiverIdProvider` (same one `tank_preset_providers.dart:22` uses — copy its import).
- Produces:
  - `checklistTemplateRepositoryProvider` — `Provider<ChecklistTemplateRepository>`
  - `tripChecklistRepositoryProvider` — `Provider<TripChecklistRepository>`
  - `checklistTemplatesProvider` — `FutureProvider<List<domain.ChecklistTemplate>>`
  - `checklistTemplateProvider` — `FutureProvider.family<domain.ChecklistTemplate?, String>`
  - `checklistTemplateItemsProvider` — `FutureProvider.family<List<domain.ChecklistTemplateItem>, String>`
  - `tripChecklistProvider` — `FutureProvider.family<List<domain.TripChecklistItem>, String>` (by tripId)
  - `tripChecklistProgressProvider` — `FutureProvider.family<({int done, int total}), String>` (by tripId)

- [ ] **Step 1: Write the failing provider test**

Create `test/features/checklists/presentation/providers/checklist_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('tripChecklistProvider returns items and progress provider counts', () async {
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Providers',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(tripChecklistRepositoryProvider);
    final created = await repo.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Check insurance',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.toggleDone(created.id, isDone: true);
    await repo.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Book nitrox',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final items = await container.read(tripChecklistProvider(trip.id).future);
    expect(items, hasLength(2));

    final progress = await container.read(
      tripChecklistProgressProvider(trip.id).future,
    );
    expect(progress.done, 1);
    expect(progress.total, 2);
  });

  test('checklistTemplatesProvider starts empty', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final templates = await container.read(checklistTemplatesProvider.future);
    expect(templates, isEmpty);
  });
}
```

Note: if `checklistTemplatesProvider` depends on `validatedCurrentDiverIdProvider` and that provider needs overrides in a bare container, override it in the test the same way existing provider tests do — search `test/` for an existing test reading `tankPresetsProvider` and copy its override setup. If none exists, have `checklistTemplatesProvider` tolerate a null diver id (pass `diverId: null` through to the repository, which then returns all templates).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/presentation/providers/checklist_providers_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement the providers**

Create `lib/features/checklists/presentation/providers/checklist_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository singletons
final checklistTemplateRepositoryProvider =
    Provider<ChecklistTemplateRepository>(
      (ref) => ChecklistTemplateRepository(),
    );

final tripChecklistRepositoryProvider = Provider<TripChecklistRepository>(
  (ref) => TripChecklistRepository(),
);

/// All checklist templates for the active diver.
final checklistTemplatesProvider =
    FutureProvider<List<domain.ChecklistTemplate>>((ref) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getAllTemplates(diverId: diverId);
    });

/// Single template by id.
final checklistTemplateProvider =
    FutureProvider.family<domain.ChecklistTemplate?, String>((ref, id) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getTemplateById(id);
    });

/// Items of a template, ordered by sortOrder.
final checklistTemplateItemsProvider =
    FutureProvider.family<List<domain.ChecklistTemplateItem>, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getItemsForTemplate(templateId);
    });

/// A trip's checklist items, ordered by sortOrder. Self-invalidates on
/// table changes so sync-applied edits render live.
final tripChecklistProvider =
    FutureProvider.family<List<domain.TripChecklistItem>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getByTripId(tripId);
    });

/// Done/total progress for a trip's checklist.
final tripChecklistProgressProvider =
    FutureProvider.family<({int done, int total}), String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getProgress(tripId);
    });
```

Note: verify the import path for `validatedCurrentDiverIdProvider` — find its actual location by checking the imports at the top of `lib/features/tank_presets/presentation/providers/tank_preset_providers.dart` and use the same import.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checklists/presentation/providers/checklist_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): riverpod providers (#164)"
```

---

### Task 8: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (plus the 10 other locale files: `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`)

**Interfaces:**
- Produces: `context.l10n.*` getters used by Tasks 9-13. Later tasks reference exactly these keys.

- [ ] **Step 1: Add English strings**

Add to `lib/l10n/arb/app_en.arb` (alphabetical placement near other `checklists_`/`trips_` keys; placeholder metadata as sibling `@`-keys):

```json
"checklists_section_title": "Checklist",
"checklists_progress": "{done} of {total} to-dos done",
"@checklists_progress": { "placeholders": { "done": { "type": "int" }, "total": { "type": "int" } } },
"checklists_empty_upcoming": "Plan your trip - add to-dos or apply a template",
"checklists_empty_past": "No checklist items",
"checklists_addItem": "Add item",
"checklists_item_titleLabel": "Title",
"checklists_item_titleRequired": "Title is required",
"checklists_item_categoryLabel": "Category",
"checklists_item_notesLabel": "Notes",
"checklists_item_dueDateLabel": "Due date",
"checklists_item_dueOffsetLabel": "Days before trip start",
"checklists_item_overdue": "Overdue",
"checklists_item_edit": "Edit item",
"checklists_item_delete": "Delete item",
"checklists_menu_applyTemplate": "Apply template...",
"checklists_menu_saveAsTemplate": "Save as template...",
"checklists_applySheet_title": "Apply template",
"checklists_applySheet_empty": "No templates yet. Create them in Settings.",
"checklists_applySheet_itemCount": "{count, plural, =1{1 item} other{{count} items}}",
"@checklists_applySheet_itemCount": { "placeholders": { "count": { "type": "int" } } },
"checklists_applySheet_confirmAppend": "{added} items will be added, {skipped} duplicates skipped.",
"@checklists_applySheet_confirmAppend": { "placeholders": { "added": { "type": "int" }, "skipped": { "type": "int" } } },
"checklists_apply_success": "{count, plural, =0{No new items added} =1{1 item added} other{{count} items added}}",
"@checklists_apply_success": { "placeholders": { "count": { "type": "int" } } },
"checklists_apply_templateGone": "Template no longer exists",
"checklists_saveTemplate_title": "Save as template",
"checklists_saveTemplate_nameLabel": "Template name",
"checklists_saveTemplate_success": "Template saved",
"checklists_templates_pageTitle": "Checklist Templates",
"checklists_templates_addTemplate": "Add Template",
"checklists_templates_empty": "No templates yet",
"checklists_templates_deleteTitle": "Delete Template",
"checklists_templates_deleteContent": "Delete \"{name}\"? Trips that already applied it keep their items.",
"@checklists_templates_deleteContent": { "placeholders": { "name": { "type": "Object" } } },
"checklists_template_nameLabel": "Name",
"checklists_template_nameRequired": "Name is required",
"checklists_template_descriptionLabel": "Description",
"checklists_template_itemsHeader": "Items",
"checklists_template_addItem": "Add item",
"settings_manage_checklistTemplates": "Checklist Templates",
"settings_manage_checklistTemplates_subtitle": "Reusable to-do lists for trip planning",
"trips_detail_tab_checklist": "Checklist",
"trips_list_upcomingSection": "Upcoming",
"trips_list_pastSection": "Past Trips",
"trips_list_inProgress": "In progress",
"trips_list_countdown": "{days, plural, =0{Starting today} =1{In 1 day} other{In {days} days}}",
"@trips_list_countdown": { "placeholders": { "days": { "type": "int" } } }
```

- [ ] **Step 2: Translate into all 10 other locales**

Add the same keys with translated values to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Translate faithfully (these are real translations, not English copies); keep ICU plural structure per locale (e.g. Arabic and Hebrew have more plural categories — include at minimum `=0`/`=1`/`other` matching English structure; `other` is mandatory).

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: completes without "untranslated messages" errors for the new keys.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(l10n): checklist and upcoming-trip strings in all locales (#164)"
```

---

### Task 9: Checklist item tile + trip checklist section widgets

**Files:**
- Create: `lib/features/checklists/presentation/widgets/checklist_item_tile.dart`
- Create: `lib/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart`
- Create: `lib/features/checklists/presentation/widgets/trip_checklist_section.dart`
- Test: `test/features/checklists/presentation/widgets/trip_checklist_section_test.dart`

**Interfaces:**
- Consumes: Task 7 providers, Task 3 entities, l10n keys from Task 8.
- Produces:
  - `ChecklistItemTile({required TripChecklistItem item, required bool showOverdue, required ValueChanged<bool> onToggle, VoidCallback? onEdit, VoidCallback? onDelete})`
  - `showChecklistItemEditSheet({required BuildContext context, required String tripId, TripChecklistItem? item})` — create/edit bottom sheet.
  - `TripChecklistSection({required Trip trip})` — full checklist UI (grouped by category, add item, overflow menu with apply/save-as-template). Used by Task 11 in both the tab and the overview card.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/checklists/presentation/widgets/trip_checklist_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';

Trip _trip({required bool upcoming}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = upcoming
      ? today.add(const Duration(days: 10))
      : today.subtract(const Duration(days: 20));
  return Trip(
    id: 't1',
    name: 'Test',
    startDate: start,
    endDate: start.add(const Duration(days: 7)),
    createdAt: today,
    updatedAt: today,
  );
}

TripChecklistItem _item({
  String id = 'i1',
  String title = 'Service regulator',
  String? category,
  bool isDone = false,
  DateTime? dueDate,
}) => TripChecklistItem(
  id: id,
  tripId: 't1',
  title: title,
  category: category,
  isDone: isDone,
  dueDate: dueDate,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('groups items by category and shows checkboxes', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith(
            (ref) async => [
              _item(id: 'i1', title: 'Service regulator', category: 'Gear'),
              _item(id: 'i2', title: 'Book flights', category: 'Bookings'),
              _item(id: 'i3', title: 'Passport check'),
            ],
          ),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Service regulator'), findsOneWidget);
    expect(find.text('Passport check'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets('shows overdue chip only for upcoming trips', (tester) async {
    final overdue = _item(
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => [overdue]),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsOneWidget);

    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => [overdue]),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('empty upcoming trip shows planning invitation', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Plan your trip - add to-dos or apply a template'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/presentation/widgets/trip_checklist_section_test.dart`
Expected: FAIL (widget files missing).

- [ ] **Step 3: Implement `ChecklistItemTile`**

Create `lib/features/checklists/presentation/widgets/checklist_item_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A single checklist row: checkbox, title, optional due chip, edit/delete.
class ChecklistItemTile extends StatelessWidget {
  final TripChecklistItem item;

  /// Whether overdue styling applies (false for past trips - they never nag).
  final bool showOverdue;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.showOverdue,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = showOverdue && item.isOverdue(DateTime.now());
    final due = item.dueDate;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: Checkbox(
        value: item.isDone,
        onChanged: (value) => onToggle(value ?? false),
      ),
      title: Text(
        item.title,
        style: item.isDone
            ? theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : theme.textTheme.bodyMedium,
      ),
      subtitle: item.notes.isEmpty
          ? null
          : Text(item.notes, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (due != null)
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                isOverdue
                    ? context.l10n.checklists_item_overdue
                    : DateFormat.MMMd().format(due),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOverdue
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              backgroundColor: isOverdue
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHighest,
              side: BorderSide.none,
            ),
          PopupMenuButton<String>(
            iconSize: 20,
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(context.l10n.checklists_item_edit),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.checklists_item_delete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the item edit sheet**

Create `lib/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet for creating or editing a trip checklist item.
Future<void> showChecklistItemEditSheet({
  required BuildContext context,
  required String tripId,
  TripChecklistItem? item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ChecklistItemEditSheet(tripId: tripId, item: item),
  );
}

class _ChecklistItemEditSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripChecklistItem? item;

  const _ChecklistItemEditSheet({required this.tripId, this.item});

  @override
  ConsumerState<_ChecklistItemEditSheet> createState() =>
      _ChecklistItemEditSheetState();
}

class _ChecklistItemEditSheetState
    extends ConsumerState<_ChecklistItemEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _categoryController = TextEditingController(
      text: widget.item?.category ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _dueDate = widget.item?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(tripChecklistRepositoryProvider);
    final category = _categoryController.text.trim();
    final existing = widget.item;
    if (existing == null) {
      await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: widget.tripId,
          title: _titleController.text.trim(),
          category: category.isEmpty ? null : category,
          notes: _notesController.text.trim(),
          dueDate: _dueDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await repository.updateItem(
        existing.copyWith(
          title: _titleController.text.trim(),
          category: category.isEmpty ? null : category,
          notes: _notesController.text.trim(),
          dueDate: _dueDate,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: widget.item == null,
              decoration: InputDecoration(
                labelText: context.l10n.checklists_item_titleLabel,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.l10n.checklists_item_titleRequired
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: context.l10n.checklists_item_categoryLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.checklists_item_notesLabel,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.checklists_item_dueDateLabel),
              subtitle: Text(
                _dueDate == null
                    ? '-'
                    : DateFormat.yMMMd().format(_dueDate!),
              ),
              trailing: _dueDate == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `TripChecklistSection`**

Create `lib/features/checklists/presentation/widgets/trip_checklist_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_tile.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full checklist UI for a trip: items grouped by category, add-item
/// affordance, and an overflow menu with apply/save-as-template actions.
/// Embedded both as the Checklist tab (liveaboards) and as a card section
/// on the overview (simple trips).
class TripChecklistSection extends ConsumerWidget {
  final Trip trip;

  const TripChecklistSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tripChecklistProvider(trip.id));

    // Render from AsyncValue.value so reloads do not flash a spinner
    // (established pattern - see project memory on AsyncValue flicker).
    final items = itemsAsync.value;
    if (items == null) {
      if (itemsAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(itemsAsync.error.toString()),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, ref, items),
        if (items.isEmpty)
          _buildEmptyState(context)
        else
          ..._buildGroupedItems(context, ref, items),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.checklists_addItem),
            onPressed: () =>
                showChecklistItemEditSheet(context: context, tripId: trip.id),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
  ) {
    final theme = Theme.of(context);
    final done = items.where((i) => i.isDone).length;
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.checklists_section_title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (items.isNotEmpty)
          Text(
            context.l10n.checklists_progress(done, items.length),
            style: theme.textTheme.labelMedium,
          ),
        _buildOverflowMenu(context, ref, items),
      ],
    );
  }

  Widget _buildOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        // No-ops in this task; wired to the apply/save flows in the
        // apply-template task.
        if (value == 'apply') {}
        if (value == 'save') {}
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'apply',
          child: Text(context.l10n.checklists_menu_applyTemplate),
        ),
        PopupMenuItem(
          value: 'save',
          enabled: items.isNotEmpty,
          child: Text(context.l10n.checklists_menu_saveAsTemplate),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        trip.isUpcoming
            ? context.l10n.checklists_empty_upcoming
            : context.l10n.checklists_empty_past,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
  ) {
    final theme = Theme.of(context);
    final repository = ref.read(tripChecklistRepositoryProvider);
    // Group by category preserving first-seen order; null category last.
    final grouped = <String?, List<TripChecklistItem>>{};
    for (final item in items.where((i) => i.category != null)) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final uncategorized = items.where((i) => i.category == null).toList();
    if (uncategorized.isNotEmpty) grouped[null] = uncategorized;

    final widgets = <Widget>[];
    grouped.forEach((category, groupItems) {
      if (category != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              category,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      for (final item in groupItems) {
        widgets.add(
          ChecklistItemTile(
            item: item,
            showOverdue: trip.isUpcoming,
            onToggle: (value) => repository.toggleDone(item.id, isDone: value),
            onEdit: () => showChecklistItemEditSheet(
              context: context,
              tripId: trip.id,
              item: item,
            ),
            onDelete: () => repository.deleteItem(item.id),
          ),
        );
      }
    });
    return widgets;
  }
}
```

Category autocomplete (spec requirement): in `checklist_item_edit_sheet.dart`, the category field must suggest categories already used in this trip's checklist. Give `showChecklistItemEditSheet` an extra parameter `List<String> categorySuggestions = const []`, have `TripChecklistSection` pass `items.map((i) => i.category).whereType<String>().toSet().toList()` at both call sites, and replace the plain category `TextFormField` with:

```dart
            RawAutocomplete<String>(
              textEditingController: _categoryController,
              focusNode: _categoryFocusNode,
              optionsBuilder: (value) => widget.categorySuggestions.where(
                (c) => c.toLowerCase().contains(value.text.toLowerCase()),
              ),
              onSelected: (selection) => _categoryController.text = selection,
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: context.l10n.checklists_item_categoryLabel,
                        ),
                      ),
            ),
```

with `final _categoryFocusNode = FocusNode();` added as a State field (disposed in `dispose()`).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/checklists/presentation/widgets/trip_checklist_section_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): item tile, edit sheet, and trip checklist section (#164)"
```

---

### Task 10: Apply-template sheet + save-as-template dialog

**Files:**
- Create: `lib/features/checklists/presentation/widgets/apply_template_sheet.dart`
- Create: `lib/features/checklists/presentation/widgets/save_as_template_dialog.dart`
- Modify: `lib/features/checklists/presentation/widgets/trip_checklist_section.dart` (wire the overflow menu)
- Test: `test/features/checklists/presentation/widgets/apply_template_sheet_test.dart`

**Interfaces:**
- Consumes: Task 5 `applyTemplate`/`saveAsTemplate`, Task 7 providers.
- Produces:
  - `showApplyTemplateSheet({required BuildContext context, required Trip trip})`
  - `showSaveAsTemplateDialog({required BuildContext context, required Trip trip})`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/checklists/presentation/widgets/apply_template_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';

Trip _trip() => Trip(
  id: 't1',
  name: 'Test',
  startDate: DateTime.now().add(const Duration(days: 10)),
  endDate: DateTime.now().add(const Duration(days: 17)),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('lists templates with item counts', (tester) async {
    final template = ChecklistTemplate(
      id: 'tpl1',
      name: 'Liveaboard packing',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith((ref) async => [template]),
          checklistTemplateItemsProvider('tpl1').overrideWith(
            (ref) async => [
              ChecklistTemplateItem(
                id: 'x1',
                templateId: 'tpl1',
                title: 'Wetsuit',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showApplyTemplateSheet(context: context, trip: _trip()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Apply template'), findsOneWidget);
    expect(find.text('Liveaboard packing'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('shows empty state when no templates exist', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith((ref) async => []),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showApplyTemplateSheet(context: context, trip: _trip()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('No templates yet. Create them in Settings.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/presentation/widgets/apply_template_sheet_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement the apply sheet**

Create `lib/features/checklists/presentation/widgets/apply_template_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing templates; tapping one applies it to the trip.
Future<void> showApplyTemplateSheet({
  required BuildContext context,
  required Trip trip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ApplyTemplateSheet(trip: trip),
  );
}

class _ApplyTemplateSheet extends ConsumerWidget {
  final Trip trip;

  const _ApplyTemplateSheet({required this.trip});

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final repository = ref.read(tripChecklistRepositoryProvider);

    // Spec: confirm the append when the trip already has items, showing
    // add/skip counts computed with the same title+category key the
    // repository uses.
    final existing = await repository.getByTripId(trip.id);
    if (existing.isNotEmpty && context.mounted) {
      final templateItems = await ref.read(
        checklistTemplateItemsProvider(templateId).future,
      );
      final existingKeys = existing
          .map((i) => '${i.title} ${i.category ?? ''}')
          .toSet();
      final skipped = templateItems
          .where((i) => existingKeys.contains('${i.title} ${i.category ?? ''}'))
          .length;
      final added = templateItems.length - skipped;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.checklists_applySheet_title),
          content: Text(l10n.checklists_applySheet_confirmAppend(added, skipped)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final result = await repository.applyTemplate(
        templateId: templateId,
        trip: trip,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_success(result.added)),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on StateError {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_templateGone),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(checklistTemplatesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.checklists_applySheet_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            templatesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(error.toString()),
              data: (templates) {
                if (templates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.l10n.checklists_applySheet_empty),
                  );
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final template in templates)
                        _TemplateTile(
                          templateId: template.id,
                          name: template.name,
                          onTap: () => _apply(context, ref, template.id),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final String templateId;
  final String name;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.templateId,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistTemplateItemsProvider(templateId));
    final count = itemsAsync.value?.length;
    return ListTile(
      leading: const Icon(Icons.checklist),
      title: Text(name),
      subtitle: count == null
          ? null
          : Text(context.l10n.checklists_applySheet_itemCount(count)),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Implement the save-as-template dialog**

Create `lib/features/checklists/presentation/widgets/save_as_template_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Prompts for a name and snapshots the trip's checklist as a template.
Future<void> showSaveAsTemplateDialog({
  required BuildContext context,
  required Trip trip,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SaveAsTemplateDialog(trip: trip),
  );
}

class _SaveAsTemplateDialog extends ConsumerStatefulWidget {
  final Trip trip;

  const _SaveAsTemplateDialog({required this.trip});

  @override
  ConsumerState<_SaveAsTemplateDialog> createState() =>
      _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends ConsumerState<_SaveAsTemplateDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final repository = ref.read(tripChecklistRepositoryProvider);
    await repository.saveAsTemplate(
      tripId: widget.trip.id,
      tripStartDate: widget.trip.startDate,
      name: _controller.text.trim(),
      diverId: widget.trip.diverId,
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.checklists_saveTemplate_success),
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.checklists_saveTemplate_title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.checklists_saveTemplate_nameLabel,
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? context.l10n.checklists_template_nameRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Wire the overflow menu in `TripChecklistSection`**

In `trip_checklist_section.dart`, add imports for the two new files and replace the `onSelected` no-ops from Task 9:

```dart
      onSelected: (value) {
        if (value == 'apply') {
          showApplyTemplateSheet(context: context, trip: trip);
        }
        if (value == 'save') {
          showSaveAsTemplateDialog(context: context, trip: trip);
        }
      },
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/checklists/`
Expected: PASS (all checklist tests so far).

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): apply-template sheet and save-as-template dialog (#164)"
```

---

### Task 11: Trip detail integration (Checklist tab + overview card)

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (`_buildLiveaboardLayout`, ~line 132: `length: 4` → `5`, add Tab + TabBarView child)
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (add checklist card to the build Column, non-liveaboard only)
- Test: `test/features/trips/presentation/pages/trip_detail_checklist_test.dart`

**Interfaces:**
- Consumes: `TripChecklistSection` (Task 9), l10n key `trips_detail_tab_checklist` (Task 8).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/trips/presentation/pages/trip_detail_checklist_test.dart`. Model the scaffolding (provider overrides, router if needed) on the EXISTING `test/features/trips/presentation/pages/trip_detail_page_test.dart` — reuse its helper/mocks verbatim, then add two tests:

```dart
// Pseudocode contract - adapt the setup from trip_detail_page_test.dart:
testWidgets('liveaboard trip shows a Checklist tab', (tester) async {
  // build TripDetailPage with a liveaboard TripWithStats override
  // plus tripChecklistProvider(tripId).overrideWith((ref) async => [])
  expect(find.text('Checklist'), findsOneWidget); // the 5th tab
});

testWidgets('non-liveaboard trip shows the checklist card on overview', (tester) async {
  // build with a shore TripWithStats override
  // plus tripChecklistProvider + tripChecklistProgressProvider overrides
  expect(find.text('Checklist'), findsOneWidget); // the card header
});
```

Write these as real tests using the existing test file's exact override set (`tripWithStatsProvider(tripId)`, settings/diver mocks) — the existing file is the source of truth for what must be overridden; every trip-detail child provider that would touch the DB needs an override or `tester.takeException()` handling, matching how that file already deals with the Photos/Dives tabs.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/pages/trip_detail_checklist_test.dart`
Expected: FAIL (no Checklist tab/card exists).

- [ ] **Step 3: Add the 5th tab for liveaboards**

In `trip_detail_page.dart` `_buildLiveaboardLayout`:
- Add import: `import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';`
- Change `length: 4` to `length: 5`.
- Add after the dives Tab: `Tab(text: context.l10n.trips_detail_tab_checklist),`
- Add after `_buildDivesTab(...)` in the TabBarView children:

```dart
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: TripChecklistSection(trip: tripWithStats.trip),
                ),
```

- [ ] **Step 4: Add the checklist card to the overview (non-liveaboard only)**

In `trip_overview_tab.dart`, add the import for `TripChecklistSection`, and in the `build` Column insert a checklist card BEFORE the notes section, gated so liveaboards (which get the tab) don't render it twice:

```dart
            if (!trip.isLiveaboard) ...[
              _buildChecklistSection(context),
              const SizedBox(height: 24),
            ],
```

And add the section builder following the `_buildStatsSection` card idiom (Card > Padding(16) > Column with bold titleMedium header):

```dart
  Widget _buildChecklistSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TripChecklistSection(trip: widget.tripWithStats.trip),
      ),
    );
  }
```

(`TripChecklistSection` renders its own "Checklist" header, so the card adds no duplicate title. Check how `trip_overview_tab.dart` accesses the trip — `widget.tripWithStats.trip` in the State class or a local `trip` variable — and use the file's existing accessor.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/pages/trip_detail_checklist_test.dart test/features/trips/presentation/pages/trip_detail_page_test.dart`
Expected: PASS (new tests plus no regression).

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): checklist tab and overview card on trip detail (#164)"
```

---

### Task 12: Trip list Upcoming section

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (`_buildTripList`, ~line 389)
- Create: `lib/features/trips/presentation/widgets/upcoming_trip_banner.dart`
- Test: `test/features/trips/presentation/widgets/trip_list_upcoming_test.dart`

**Interfaces:**
- Consumes: `Trip.isUpcoming`/`isInProgress`/`daysUntilStart` (Task 3), `tripChecklistProgressProvider` (Task 7), l10n keys `trips_list_upcomingSection`, `trips_list_pastSection`, `trips_list_inProgress`, `trips_list_countdown`, `checklists_progress` (Task 8).
- Produces: `UpcomingTripBanner({required Trip trip})` — countdown line + checklist progress line, rendered above the regular tile content for upcoming trips.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/trips/presentation/widgets/trip_list_upcoming_test.dart`. Reuse the scaffolding from `test/features/trips/presentation/pages/trip_list_page_test.dart` (`_buildTestWidget`, `baseOverrides`, mobile viewport 400x800) with `sortedFilteredTripsProvider` overridden to return one upcoming trip (starts in 24 days), one in-progress trip (started 2 days ago, ends in 3), and one past trip:

```dart
// Contract (write as real tests with the copied scaffolding):
testWidgets('partitions trips into Upcoming and Past sections', (tester) async {
  // - 'Upcoming' header above the two future/in-progress trips
  // - 'Past Trips' header above the past trip
  // - upcoming sorted soonest-first: in-progress trip listed before the +24d trip
  expect(find.text('Upcoming'), findsOneWidget);
  expect(find.text('Past Trips'), findsOneWidget);
});

testWidgets('upcoming tiles show countdown and progress', (tester) async {
  // override tripChecklistProgressProvider(upcomingTripId)
  //   .overrideWith((ref) async => (done: 3, total: 12));
  expect(find.text('In 24 days'), findsOneWidget);
  expect(find.text('In progress'), findsOneWidget);
  expect(find.text('3 of 12 to-dos done'), findsOneWidget);
});

testWidgets('past-only list renders without an Upcoming header', (tester) async {
  expect(find.text('Upcoming'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_upcoming_test.dart`
Expected: FAIL (no sections exist).

- [ ] **Step 3: Implement `UpcomingTripBanner`**

Create `lib/features/trips/presentation/widgets/upcoming_trip_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Countdown + checklist progress line shown on upcoming trip tiles.
class UpcomingTripBanner extends ConsumerWidget {
  final Trip trip;

  const UpcomingTripBanner({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(tripChecklistProgressProvider(trip.id));
    final progress = progressAsync.value;

    final countdown = trip.isInProgress
        ? context.l10n.trips_list_inProgress
        : context.l10n.trips_list_countdown(trip.daysUntilStart);

    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          countdown,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (progress != null && progress.total > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.checklists_progress(progress.done, progress.total),
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Partition the list in `_buildTripList`**

In `trip_list_content.dart` `_buildTripList`, replace the flat `ListView.builder` over `trips` with a partitioned build. Before constructing the ListView:

```dart
    final upcoming =
        trips.where((t) => t.trip.isUpcoming).toList()
          ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));
    final past = trips.where((t) => !t.trip.isUpcoming).toList();
    // Flatten into one item list: header sentinels + trips, so the
    // existing ListView.builder/itemBuilder structure is preserved.
    final rows = <Object>[
      if (upcoming.isNotEmpty) _SectionHeader.upcoming,
      ...upcoming,
      if (upcoming.isNotEmpty && past.isNotEmpty) _SectionHeader.past,
      ...past,
    ];
```

with a private enum at the bottom of the file:

```dart
enum _SectionHeader { upcoming, past }
```

In the `itemBuilder`, handle the sentinel rows first:

```dart
        final row = rows[index];
        if (row is _SectionHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              row == _SectionHeader.upcoming
                  ? context.l10n.trips_list_upcomingSection
                  : context.l10n.trips_list_pastSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        final tripWithStats = row as TripWithStats;
```

then keep the existing `switch (viewMode)` tile construction, and for upcoming trips wrap the tile with the banner:

```dart
        final tile = switch (viewMode) { /* existing three cases unchanged */ };
        if (!tripWithStats.trip.isUpcoming) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: UpcomingTripBanner(trip: tripWithStats.trip),
            ),
            tile,
          ],
        );
```

Update `itemCount` to `rows.length`. Preserve the existing sort for `past` (it arrives already sorted by the sort provider — do not re-sort it). If `sortedFilteredTripsProvider` sorting means `trips` arrive newest-first, `past` inherits that order, which is the spec behavior. This partitioning applies in all three view modes because it wraps the shared builder.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_upcoming_test.dart test/features/trips/presentation/pages/trip_list_page_test.dart`
Expected: PASS (new tests plus no regression in existing list tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(trips): upcoming section with countdown and checklist progress (#164)"
```

---

### Task 13: Checklist Templates settings pages + routes

**Files:**
- Create: `lib/features/checklists/presentation/pages/checklist_templates_page.dart`
- Create: `lib/features/checklists/presentation/pages/checklist_template_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (add routes after the tank-presets block, ~line 958; add imports)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (add ListTile after Tank Presets in `_ManageSectionContent`, ~line 1644)
- Test: `test/features/checklists/presentation/pages/checklist_templates_page_test.dart`

**Interfaces:**
- Consumes: Tasks 4, 7 (repository via providers), l10n keys (Task 8).
- Produces: routes `/checklist-templates`, `/checklist-templates/new`, `/checklist-templates/:templateId/edit`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/checklists/presentation/pages/checklist_templates_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_templates_page.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('lists templates with item counts', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith(
            (ref) async => [
              ChecklistTemplate(
                id: 'tpl1',
                name: 'Liveaboard packing',
                description: 'Everything for a week aboard',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
          checklistTemplateItemsProvider('tpl1').overrideWith(
            (ref) async => [
              ChecklistTemplateItem(
                id: 'x1',
                templateId: 'tpl1',
                title: 'Wetsuit',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ],
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checklist Templates'), findsOneWidget);
    expect(find.text('Liveaboard packing'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          checklistTemplatesProvider.overrideWith((ref) async => []),
        ],
        child: const ChecklistTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No templates yet'), findsOneWidget);
  });
}
```

Note: `ChecklistTemplatesPage` contains its own `Scaffold`; if `testApp` wraps children in a `Scaffold(body:)`, nesting is harmless for these assertions (existing page tests do the same — check how `tank_presets_page` is tested if a conflict arises, or pass the page directly as `home` via a raw `MaterialApp` like `trip_list_page_test.dart` does).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checklists/presentation/pages/checklist_templates_page_test.dart`
Expected: FAIL (pages missing).

- [ ] **Step 3: Implement the list page**

Create `lib/features/checklists/presentation/pages/checklist_templates_page.dart` (mirrors `tank_presets_page.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page listing reusable checklist templates.
class ChecklistTemplatesPage extends ConsumerWidget {
  const ChecklistTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(checklistTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checklists_templates_pageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/checklist-templates/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.checklists_templates_addTemplate),
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Text(context.l10n.checklists_templates_empty),
            );
          }
          return ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _TemplateTile(template: templates[index]),
          );
        },
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final ChecklistTemplate template;

  const _TemplateTile({required this.template});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checklists_templates_deleteTitle),
        content: Text(l10n.checklists_templates_deleteContent(template.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(checklistTemplateRepositoryProvider)
          .deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistTemplateItemsProvider(template.id));
    final count = itemsAsync.value?.length;
    return ListTile(
      leading: const Icon(Icons.checklist),
      title: Text(template.name),
      subtitle: Text(
        count == null
            ? template.description
            : context.l10n.checklists_applySheet_itemCount(count),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/checklist-templates/${template.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () => context.push('/checklist-templates/${template.id}/edit'),
    );
  }
}
```

Note on `common_action_cancel`/`common_action_delete`: if those l10n keys exist (check `app_en.arb`), prefer them over `MaterialLocalizations` labels for consistency with `tank_presets_page.dart` — copy whatever that page actually uses.

- [ ] **Step 4: Implement the edit page**

Create `lib/features/checklists/presentation/pages/checklist_template_edit_page.dart`. Structure: `ConsumerStatefulWidget` with `String? templateId` (`isEditing => templateId != null`), a name + description form, and a reorderable item list editing `List<ChecklistTemplateItem>` in local state, saved wholesale on Save via `createTemplate`/`updateTemplate` + `saveItems`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Create/edit page for a checklist template and its items.
class ChecklistTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const ChecklistTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<ChecklistTemplateEditPage> createState() =>
      _ChecklistTemplateEditPageState();
}

class _ChecklistTemplateEditPageState
    extends ConsumerState<ChecklistTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<ChecklistTemplateItem> _items = [];
  ChecklistTemplate? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repository = ref.read(checklistTemplateRepositoryProvider);
    final template = await repository.getTemplateById(widget.templateId!);
    final items = await repository.getItemsForTemplate(widget.templateId!);
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({ChecklistTemplateItem? item}) async {
    final result = await _showItemDialog(item: item);
    if (result == null) return;
    setState(() {
      if (item == null) {
        _items = [..._items, result];
      } else {
        _items = [
          for (final existing in _items)
            if (identical(existing, item)) result else existing,
        ];
      }
    });
  }

  Future<ChecklistTemplateItem?> _showItemDialog({
    ChecklistTemplateItem? item,
  }) {
    final titleController = TextEditingController(text: item?.title ?? '');
    final categoryController = TextEditingController(
      text: item?.category ?? '',
    );
    final notesController = TextEditingController(text: item?.notes ?? '');
    final offsetController = TextEditingController(
      text: item?.dueOffsetDays?.toString() ?? '',
    );
    final itemFormKey = GlobalKey<FormState>();

    return showDialog<ChecklistTemplateItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.checklists_template_addItem),
        content: Form(
          key: itemFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.checklists_item_titleLabel,
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? context.l10n.checklists_item_titleRequired
                      : null,
                ),
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: context.l10n.checklists_item_categoryLabel,
                  ),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: context.l10n.checklists_item_notesLabel,
                  ),
                ),
                TextFormField(
                  controller: offsetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.checklists_item_dueOffsetLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              if (!itemFormKey.currentState!.validate()) return;
              final category = categoryController.text.trim();
              Navigator.of(context).pop(
                ChecklistTemplateItem(
                  id: item?.id ?? '',
                  templateId: widget.templateId ?? '',
                  title: titleController.text.trim(),
                  category: category.isEmpty ? null : category,
                  notes: notesController.text.trim(),
                  dueOffsetDays: int.tryParse(offsetController.text.trim()),
                  sortOrder: item?.sortOrder ?? _items.length,
                  createdAt: item?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(checklistTemplateRepositoryProvider);
    final navigator = Navigator.of(context);
    String templateId;
    if (_existing == null) {
      final created = await repository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      templateId = created.id;
    } else {
      await repository.updateTemplate(
        _existing!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
      templateId = _existing!.id;
    }
    await repository.saveItems(
      templateId,
      [
        for (final item in _items) item.copyWith(templateId: templateId),
      ],
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.checklists_templates_pageTitle),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.checklists_template_nameLabel,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? context.l10n.checklists_template_nameRequired
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.checklists_template_descriptionLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.checklists_template_itemsHeader,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final items = [..._items];
                        if (newIndex > oldIndex) newIndex--;
                        final item = items.removeAt(oldIndex);
                        items.insert(newIndex, item);
                        _items = items;
                      });
                    },
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        ListTile(
                          key: ValueKey('item-$i-${_items[i].title}'),
                          title: Text(_items[i].title),
                          subtitle: _items[i].category == null
                              ? null
                              : Text(_items[i].category!),
                          leading: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(
                              () => _items = [..._items]..removeAt(i),
                            ),
                          ),
                          onTap: () => _addOrEditItem(item: _items[i]),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.checklists_template_addItem),
                    onPressed: () => _addOrEditItem(),
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 5: Add routes and the settings entry**

(a) In `lib/core/router/app_router.dart`, add imports:

```dart
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_templates_page.dart';
```

and after the tank-presets GoRoute block (~line 958), add:

```dart
      // Checklist Templates Management
      GoRoute(
        path: '/checklist-templates',
        name: 'checklistTemplates',
        builder: (context, state) => const ChecklistTemplatesPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'newChecklistTemplate',
            builder: (context, state) => const ChecklistTemplateEditPage(),
          ),
          GoRoute(
            path: ':templateId/edit',
            name: 'editChecklistTemplate',
            builder: (context, state) => ChecklistTemplateEditPage(
              templateId: state.pathParameters['templateId'],
            ),
          ),
        ],
      ),
```

(b) In `lib/features/settings/presentation/pages/settings_page.dart` `_ManageSectionContent`, after the Tank Presets ListTile (and its `Divider`), add:

```dart
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(context.l10n.settings_manage_checklistTemplates),
            subtitle: Text(
              context.l10n.settings_manage_checklistTemplates_subtitle,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/checklist-templates'),
          ),
```

(Match the exact Divider placement convention of the surrounding tiles.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/checklists/presentation/pages/checklist_templates_page_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(checklists): template management pages, routes, settings entry (#164)"
```

---

### Task 14: Sync round-trip test + final verification

**Files:**
- Test: `test/core/services/sync/checklist_sync_round_trip_test.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the sync round-trip test**

Create `test/core/services/sync/checklist_sync_round_trip_test.dart`. Model its scaffolding on the existing `sync_serializer_round_trip_test.dart` (use the same helpers from `test/helpers/sync_test_helpers.dart` if it provides serializer construction). The test contract:

```dart
// 1. Create a trip, a template with 2 items, and 2 trip checklist items
//    (one done) through the repositories.
// 2. Export a full SyncData via the serializer (hlcSince: null).
// 3. Assert data.checklistTemplates has 1 record, data.checklistTemplateItems
//    has 2, data.tripChecklistItems has 2, and the done item's is_done
//    round-trips truthy.
// 4. SyncData.fromJson(jsonDecode(jsonEncode(data.toJson()))) preserves all
//    three lists (lengths and record ids).
```

Write it as a real test importing the serializer exactly as the existing round-trip test does — that file is the authoritative template for construction and any required fakes.

- [ ] **Step 2: Run it plus the full checklist + sync + trips suites**

```bash
flutter test test/core/services/sync/checklist_sync_round_trip_test.dart
flutter test test/features/checklists/
flutter test test/features/trips/
flutter test test/core/services/sync/
flutter test test/core/database/migration_v95_checklists_test.dart
```

Expected: ALL PASS.

- [ ] **Step 3: Full-project verification**

```bash
flutter analyze
dart format . 
git status --short
```

Expected: analyze clean; format changes nothing (already formatted); no unexpected untracked files.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test(sync): checklist entities round-trip through sync serializer (#164)"
```

---

## Execution Notes

- Baseline established in the worktree: 415 trips tests passing before Task 1.
- Tasks 1→7 are strictly sequential (each consumes the previous). Tasks 9-13 depend on 8 (l10n keys) and 7 (providers). Task 12 additionally depends on 3 (Trip getters). Task 14 is last.
- When a referenced line number has drifted, locate the anchor by the quoted code, not the number.
- Where the plan says "check how X does it and copy that exactly", that check is part of the task — the referenced file is the source of truth over this plan's code sketch.
- Push with `--no-verify` (worktree pre-push hook runs against the main tree and reports false failures).

