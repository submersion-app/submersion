# Pre-Dive Checklist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit-grade pre-dive checklists — built-in and custom templates (BWRAF through CCR build), a crash-safe session runner with Done/Skipped/Flagged states, recorded values, strict ordering, locked completion records, equipment-set expansion with service warnings, and automatic linking of sessions to later-imported dives.

**Architecture:** New self-contained feature module `lib/features/pre_dive/` mirroring the shipped `lib/features/checklists/` template-to-instance snapshot pattern. Four new synced Drift tables (schema v113). Pure domain services (session engine, item composer) + thin repositories + Riverpod `FutureProvider`s. Entry points are thin doors into one session-runner page.

**Tech Stack:** Flutter, Drift ORM, Riverpod 3 (hand-written providers, no codegen), go_router, existing HLC sync framework.

**Spec:** `docs/superpowers/specs/2026-07-16-pre-dive-checklist-design.md` — read it before starting.

## Global Constraints

- Schema migration is version **113** (`currentSchemaVersion` is 112 on main). If another branch consumed 113 by execution time, use the next free version everywhere `113` appears and keep DDL idempotent.
- All `createdAt`/`updatedAt`/`startedAt`/`completedAt` columns are **integer epoch milliseconds** (`DateTime.now().millisecondsSinceEpoch`), matching every other table.
- Entity-type key strings for sync are camelCase: `preDiveChecklistTemplates`, `preDiveChecklistTemplateItems`, `preDiveSessions`, `preDiveSessionItems`.
- Every mutating repository write: `markRecordPending(entityType:, recordId:, localUpdatedAt: now)` then one `SyncEventBus.notifyLocalChange()`. Deletes: `logDeletion(entityType:, recordId:)` per row (children included).
- Completed/aborted sessions are immutable — enforced in the repository (throw `StateError`), not just UI.
- Built-in templates: `isBuiltIn = true`, seeded by `INSERT OR IGNORE` SQL constants in `database.dart`, re-seeded in `beforeOpen`, **skipped by sync export**, rejected by update/delete repository methods.
- No emojis in code, comments, or docs. `dart format .` (whole repo) must produce no changes before every commit. Commit messages: plain, imperative, no Co-Authored-By lines.
- New user-facing strings go in `lib/l10n/arb/app_en.arb` AND all 10 other locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then `flutter gen-l10n`. Tasks 8-14 add English strings as they go; Task 15 is the full translation sweep.
- Run tests per-file (`flutter test test/path/file_test.dart`) — broad directories hit Bash timeouts.
- If executing in a fresh worktree: `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs` first, or DB tests fail on missing `database.g.dart`.
- Line references below were verified on the branch base; re-locate by the quoted anchor text if drifted.

## File Structure

```
lib/features/pre_dive/
  domain/entities/pre_dive_checklist_template.dart   # template + template item entities + PreDiveItemType
  domain/entities/pre_dive_session.dart              # session + session item entities + status/state enums
  domain/services/checklist_session_engine.dart      # pure: actionability, canComplete, flag count
  domain/services/session_item_composer.dart         # pure: template items -> session item snapshots (+ equipment expansion)
  data/repositories/pre_dive_template_repository.dart
  data/repositories/pre_dive_session_repository.dart
  data/services/checklist_dive_linker.dart           # auto-link sessions to imported dives
  presentation/providers/pre_dive_providers.dart
  presentation/pages/pre_dive_templates_page.dart
  presentation/pages/pre_dive_template_edit_page.dart
  presentation/pages/pre_dive_sessions_page.dart
  presentation/pages/pre_dive_session_runner_page.dart
  presentation/widgets/session_item_tile.dart
  presentation/widgets/start_session_sheet.dart
  presentation/widgets/pre_dive_dashboard_card.dart
  presentation/widgets/dive_pre_dive_section.dart

test/features/pre_dive/   # one test file per source file above (same relative names + _test)
test/core/database/migration_v113_pre_dive_test.dart
test/core/services/sync/sync_pre_dive_test.dart
```

Modified: `database.dart` (tables, migration, backstop, seeds), `sync_data_serializer.dart` (6 touch points x 4 entities), `sync_service.dart` (merge order + structural maps), `sync_repository.dart` (`_hlcTargets`), `app_router.dart`, `add_dive_bottom_sheet.dart`, `settings_page.dart`, `dive_detail_sections.dart` + `dive_detail_page.dart`, `dashboard_page.dart`, `tools_page.dart`, `trip_detail_page.dart`, importer call sites (4), arb files (11).

---

### Task 1: Schema — four pre_dive tables, migration v113, backstop

**Files:**
- Modify: `lib/core/database/database.dart` (table classes after `TripChecklistItems` ~:202; `@DriftDatabase` list ~:2178; `currentSchemaVersion` :2208; `migrationVersions` tail :2324; `onUpgrade` tail ~:5546; `beforeOpen` ~:5577)
- Modify: `test/core/database/equipment_set_geofence_schema_test.dart:77-80` (retire old exact tripwire)
- Test: `test/core/database/migration_v113_pre_dive_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: Drift tables `PreDiveChecklistTemplates`, `PreDiveChecklistTemplateItems`, `PreDiveSessions`, `PreDiveSessionItems` (generated data classes take Drift's default singular names — domain entities are imported `as domain` in repositories, same collision handling as the checklists feature). Backstop helper `_assertPreDiveChecklistSchema()`.

- [ ] **Step 1: Write the failing migration test** at `test/core/database/migration_v113_pre_dive_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v113 creates the four pre-dive checklist tables', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 112');
        // Minimal parents so FK references resolve.
        rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE equipment_sets (id TEXT NOT NULL PRIMARY KEY)',
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final expectations = {
      'pre_dive_checklist_templates': ['id', 'strict_order', 'is_built_in', 'builtin_key', 'hlc'],
      'pre_dive_checklist_template_items': ['id', 'template_id', 'item_type', 'is_required', 'value_min', 'hlc'],
      'pre_dive_sessions': ['id', 'template_name', 'strict_order', 'dive_id', 'trip_id', 'status', 'started_at', 'hlc'],
      'pre_dive_session_items': ['id', 'session_id', 'state', 'value_number', 'completed_at', 'equipment_id', 'hlc'],
    };
    for (final entry in expectations.entries) {
      final cols = await db
          .customSelect("PRAGMA table_info('${entry.key}')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, isNotEmpty, reason: '${entry.key} table missing');
      for (final col in entry.value) {
        expect(names, contains(col), reason: '${entry.key} missing $col');
      }
    }
  });

  test('v113 is the current schema version (exact-latest tripwire)', () {
    expect(AppDatabase.currentSchemaVersion, 113);
    expect(AppDatabase.migrationVersions, contains(113));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v113_pre_dive_test.dart`
Expected: FAIL — `pre_dive_checklist_templates table missing` and tripwire `112 != 113`.

- [ ] **Step 3: Add the four table classes** to `database.dart`, directly after the `TripChecklistItems` class (~line 202):

```dart
/// Pre-dive checklist templates (spec 2026-07-16-pre-dive-checklist).
/// Built-ins (isBuiltIn) are seeded by kSeedBuiltInPreDiveTemplate* SQL,
/// re-asserted in beforeOpen, and skipped by sync export.
class PreDiveChecklistTemplates extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().nullable()();

  /// Enforce item order during sessions (CCR-build style).
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Stable identity for built-in re-seeding and content upgrades.
  TextColumn get builtinKey => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Items belonging to a pre-dive checklist template.
class PreDiveChecklistTemplateItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(PreDiveChecklistTemplates, #id)();

  /// Visual grouping header (e.g. "Cells", "Bailout").
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 'check' | 'value' | 'equipmentSet' (PreDiveItemType.name).
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();

  /// Warning thresholds for value items — advisory, never blocking.
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();

  /// Required items must end Done or Flagged (never Skipped).
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// A pre-dive checklist run. Snapshots everything at start; completed and
/// aborted sessions are immutable audit records (repository-enforced).
class PreDiveSessions extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get templateId => text().nullable().references(
    PreDiveChecklistTemplates,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Snapshot; survives template deletion.
  TextColumn get templateName => text()();

  /// Snapshot of the template's strictOrder at session start.
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get tripId =>
      text().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  IntColumn get startedAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  /// 'inProgress' | 'completed' | 'aborted' (PreDiveSessionStatus.name).
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  TextColumn get equipmentSetId => text().nullable().references(
    EquipmentSets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Display snapshot; survives set deletion.
  TextColumn get equipmentSetName => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Per-session checklist items: a full snapshot of the template item plus
/// run state. Mutated individually during a run, so first-class HLC rows.
class PreDiveSessionItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    PreDiveSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();

  /// 'pending' | 'done' | 'skipped' | 'flagged' (PreDiveItemState.name).
  TextColumn get state => text().withDefault(const Constant('pending'))();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get valueText => text().nullable()();

  /// Diver note recorded during the run (e.g. "cell 2 sluggish").
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Stamped at tap time — audit evidence, never backfilled.
  IntColumn get completedAt => integer().nullable()();

  /// Set for equipment-expanded rows; navigation only.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}
```

- [ ] **Step 4: Register the tables** in the `@DriftDatabase(tables: [...])` list, after `TripChecklistItems` (~line 2180):

```dart
    // Pre-dive checklists (spec 2026-07-16-pre-dive-checklist)
    PreDiveChecklistTemplates,
    PreDiveChecklistTemplateItems,
    PreDiveSessions,
    PreDiveSessionItems,
```

- [ ] **Step 5: Bump version, add migration + backstop.** Set `currentSchemaVersion = 113`, append `113` to `migrationVersions`. Add the backstop helper next to `_assertEquipmentSetDefaultAndGeofenceSchema` (~line 2420):

```dart
  /// v113: pre-dive checklist tables. Migrator.createTable is IF NOT EXISTS,
  /// so this is safe to call from both onUpgrade and the beforeOpen backstop
  /// (parallel-branch version-collision self-heal).
  Future<void> _assertPreDiveChecklistSchema() async {
    final m = createMigrator();
    await m.createTable(preDiveChecklistTemplates);
    await m.createTable(preDiveChecklistTemplateItems);
    await m.createTable(preDiveSessions);
    await m.createTable(preDiveSessionItems);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_template_items_template_id '
      'ON pre_dive_checklist_template_items(template_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_sessions_dive_id '
      'ON pre_dive_sessions(dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_session_items_session_id '
      'ON pre_dive_session_items(session_id)',
    );
  }
```

In `onUpgrade`, after the `if (from < 112)` block:

```dart
        if (from < 113) {
          await _assertPreDiveChecklistSchema();
        }
        if (from < 113) await reportProgress();
```

In `beforeOpen`, after `await _assertEquipmentThicknessColumn();`:

```dart
        // v113 backstop: re-assert the pre-dive checklist tables.
        await _assertPreDiveChecklistSchema();
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, `database.g.dart` regenerated.

- [ ] **Step 7: Run the new test — passes**

Run: `flutter test test/core/database/migration_v113_pre_dive_test.dart`
Expected: PASS (both tests).

- [ ] **Step 8: Retire the old exact tripwire.** In `test/core/database/equipment_set_geofence_schema_test.dart:77-80`, change the v112 exact-equality test to the historical form (only the newest migration owns exactness):

```dart
  test('v112 is on the migration ladder', () {
    expect(AppDatabase.migrationVersions, contains(112));
  });
```

Run: `flutter test test/core/database/equipment_set_geofence_schema_test.dart`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive checklist tables (schema v113)"
```

---

### Task 2: Domain entities and enums

**Files:**
- Create: `lib/features/pre_dive/domain/entities/pre_dive_checklist_template.dart`
- Create: `lib/features/pre_dive/domain/entities/pre_dive_session.dart`
- Test: `test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`

**Interfaces:**
- Consumes: `package:equatable/equatable.dart` only (pure Dart).
- Produces (used by every later task):
  - `enum PreDiveItemType { check, value, equipmentSet }` with `static PreDiveItemType parse(String raw)` (fallback `check`).
  - `enum PreDiveSessionStatus { inProgress, completed, aborted }` with `parse` (fallback `inProgress`).
  - `enum PreDiveItemState { pending, done, skipped, flagged }` with `parse` (fallback `pending`).
  - `class PreDiveChecklistTemplate` — fields `id, diverId, name, description, category, strictOrder, isBuiltIn, builtinKey, createdAt, updatedAt`; `copyWith` with `_undefined` sentinel for `diverId, category, builtinKey`.
  - `class PreDiveChecklistTemplateItem` — fields `id, templateId, section, title, notes, sortOrder, itemType, valueLabel, valueUnit, valueMin, valueMax, isRequired, createdAt, updatedAt`; sentinel for nullable fields.
  - `class PreDiveSession` — fields `id, diverId, templateId, templateName, strictOrder, diveId, tripId, startedAt (DateTime), completedAt (DateTime?), status, equipmentSetId, equipmentSetName, notes, createdAt, updatedAt`; `bool get isLocked => status != PreDiveSessionStatus.inProgress;` sentinel for nullable fields.
  - `class PreDiveSessionItem` — fields `id, sessionId, section, title, notes, sortOrder, itemType, valueLabel, valueUnit, valueMin, valueMax, isRequired, state, valueNumber, valueText, note, completedAt (DateTime?), equipmentId, createdAt, updatedAt`; `bool get isResolved => state != PreDiveItemState.pending;` `bool get valueOutOfRange` (true when `valueNumber != null` and outside a non-null min/max); sentinel for nullable fields.

- [ ] **Step 1: Write the failing test** at `test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  group('enums', () {
    test('parse known and unknown values', () {
      expect(PreDiveItemType.parse('equipmentSet'), PreDiveItemType.equipmentSet);
      expect(PreDiveItemType.parse('garbage'), PreDiveItemType.check);
      expect(PreDiveSessionStatus.parse('completed'), PreDiveSessionStatus.completed);
      expect(PreDiveSessionStatus.parse(''), PreDiveSessionStatus.inProgress);
      expect(PreDiveItemState.parse('flagged'), PreDiveItemState.flagged);
      expect(PreDiveItemState.parse('nope'), PreDiveItemState.pending);
    });
  });

  group('PreDiveSession', () {
    PreDiveSession session(PreDiveSessionStatus status) => PreDiveSession(
      id: 's1', templateName: 'BWRAF', startedAt: now,
      status: status, createdAt: now, updatedAt: now,
    );

    test('isLocked for completed and aborted, not inProgress', () {
      expect(session(PreDiveSessionStatus.inProgress).isLocked, isFalse);
      expect(session(PreDiveSessionStatus.completed).isLocked, isTrue);
      expect(session(PreDiveSessionStatus.aborted).isLocked, isTrue);
    });

    test('copyWith sentinel can null out diveId', () {
      final linked = session(PreDiveSessionStatus.inProgress)
          .copyWith(diveId: 'd1');
      expect(linked.diveId, 'd1');
      expect(linked.copyWith(diveId: null).diveId, isNull);
      expect(linked.copyWith().diveId, 'd1');
    });
  });

  group('PreDiveSessionItem', () {
    PreDiveSessionItem item({double? v, double? min, double? max}) =>
        PreDiveSessionItem(
          id: 'i1', sessionId: 's1', title: 'Cell 1 mV',
          itemType: PreDiveItemType.value, valueNumber: v,
          valueMin: min, valueMax: max, createdAt: now, updatedAt: now,
        );

    test('valueOutOfRange only when outside non-null bounds', () {
      expect(item(v: 9.0, min: 8.5, max: 13.0).valueOutOfRange, isFalse);
      expect(item(v: 7.0, min: 8.5, max: 13.0).valueOutOfRange, isTrue);
      expect(item(v: 14.0, min: 8.5, max: 13.0).valueOutOfRange, isTrue);
      expect(item(v: 14.0).valueOutOfRange, isFalse);
      expect(item(v: null, min: 8.5).valueOutOfRange, isFalse);
    });

    test('isResolved for any non-pending state', () {
      expect(item().isResolved, isFalse);
      expect(item().copyWith(state: PreDiveItemState.skipped).isResolved, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`
Expected: FAIL — files do not exist (compile error).

- [ ] **Step 3: Implement the entities.** Follow `lib/features/checklists/domain/entities/checklist_template.dart` conventions exactly (Equatable, const constructors, `_undefined` sentinel, full `props`). `pre_dive_checklist_template.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Kind of checklist item.
enum PreDiveItemType {
  check,
  value,
  equipmentSet;

  static PreDiveItemType parse(String raw) => PreDiveItemType.values
      .firstWhere((e) => e.name == raw, orElse: () => PreDiveItemType.check);
}

/// Reusable pre-dive checklist template (built-in or user-created).
class PreDiveChecklistTemplate extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final String? category;
  final bool strictOrder;
  final bool isBuiltIn;
  final String? builtinKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveChecklistTemplate({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.category,
    this.strictOrder = false,
    this.isBuiltIn = false,
    this.builtinKey,
    required this.createdAt,
    required this.updatedAt,
  });

  PreDiveChecklistTemplate copyWith({
    String? id,
    Object? diverId = _undefined,
    String? name,
    String? description,
    Object? category = _undefined,
    bool? strictOrder,
    bool? isBuiltIn,
    Object? builtinKey = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveChecklistTemplate(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category == _undefined ? this.category : category as String?,
      strictOrder: strictOrder ?? this.strictOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      builtinKey:
          builtinKey == _undefined ? this.builtinKey : builtinKey as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, diverId, name, description, category, strictOrder,
    isBuiltIn, builtinKey, createdAt, updatedAt,
  ];
}

/// Item belonging to a pre-dive checklist template.
class PreDiveChecklistTemplateItem extends Equatable {
  final String id;
  final String templateId;
  final String? section;
  final String title;
  final String notes;
  final int sortOrder;
  final PreDiveItemType itemType;
  final String? valueLabel;
  final String? valueUnit;
  final double? valueMin;
  final double? valueMax;
  final bool isRequired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveChecklistTemplateItem({
    required this.id,
    required this.templateId,
    this.section,
    required this.title,
    this.notes = '',
    this.sortOrder = 0,
    this.itemType = PreDiveItemType.check,
    this.valueLabel,
    this.valueUnit,
    this.valueMin,
    this.valueMax,
    this.isRequired = false,
    required this.createdAt,
    required this.updatedAt,
  });

  PreDiveChecklistTemplateItem copyWith({
    String? id,
    String? templateId,
    Object? section = _undefined,
    String? title,
    String? notes,
    int? sortOrder,
    PreDiveItemType? itemType,
    Object? valueLabel = _undefined,
    Object? valueUnit = _undefined,
    Object? valueMin = _undefined,
    Object? valueMax = _undefined,
    bool? isRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveChecklistTemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      section: section == _undefined ? this.section : section as String?,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      itemType: itemType ?? this.itemType,
      valueLabel:
          valueLabel == _undefined ? this.valueLabel : valueLabel as String?,
      valueUnit:
          valueUnit == _undefined ? this.valueUnit : valueUnit as String?,
      valueMin: valueMin == _undefined ? this.valueMin : valueMin as double?,
      valueMax: valueMax == _undefined ? this.valueMax : valueMax as double?,
      isRequired: isRequired ?? this.isRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, templateId, section, title, notes, sortOrder, itemType,
    valueLabel, valueUnit, valueMin, valueMax, isRequired,
    createdAt, updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

`pre_dive_session.dart` follows the identical shape (import `pre_dive_checklist_template.dart` for `PreDiveItemType`):

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';

/// Lifecycle of a pre-dive checklist run.
enum PreDiveSessionStatus {
  inProgress,
  completed,
  aborted;

  static PreDiveSessionStatus parse(String raw) =>
      PreDiveSessionStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PreDiveSessionStatus.inProgress,
      );
}

/// Outcome state of a single item during a run.
enum PreDiveItemState {
  pending,
  done,
  skipped,
  flagged;

  static PreDiveItemState parse(String raw) => PreDiveItemState.values
      .firstWhere((e) => e.name == raw, orElse: () => PreDiveItemState.pending);
}

/// A pre-dive checklist run. Completed/aborted sessions are immutable.
class PreDiveSession extends Equatable {
  final String id;
  final String? diverId;
  final String? templateId;
  final String templateName;
  final bool strictOrder;
  final String? diveId;
  final String? tripId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final PreDiveSessionStatus status;
  final String? equipmentSetId;
  final String? equipmentSetName;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveSession({
    required this.id,
    this.diverId,
    this.templateId,
    required this.templateName,
    this.strictOrder = false,
    this.diveId,
    this.tripId,
    required this.startedAt,
    this.completedAt,
    this.status = PreDiveSessionStatus.inProgress,
    this.equipmentSetId,
    this.equipmentSetName,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLocked => status != PreDiveSessionStatus.inProgress;

  PreDiveSession copyWith({
    String? id,
    Object? diverId = _undefined,
    Object? templateId = _undefined,
    String? templateName,
    bool? strictOrder,
    Object? diveId = _undefined,
    Object? tripId = _undefined,
    DateTime? startedAt,
    Object? completedAt = _undefined,
    PreDiveSessionStatus? status,
    Object? equipmentSetId = _undefined,
    Object? equipmentSetName = _undefined,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveSession(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      templateId:
          templateId == _undefined ? this.templateId : templateId as String?,
      templateName: templateName ?? this.templateName,
      strictOrder: strictOrder ?? this.strictOrder,
      diveId: diveId == _undefined ? this.diveId : diveId as String?,
      tripId: tripId == _undefined ? this.tripId : tripId as String?,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
      status: status ?? this.status,
      equipmentSetId: equipmentSetId == _undefined
          ? this.equipmentSetId
          : equipmentSetId as String?,
      equipmentSetName: equipmentSetName == _undefined
          ? this.equipmentSetName
          : equipmentSetName as String?,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, diverId, templateId, templateName, strictOrder, diveId, tripId,
    startedAt, completedAt, status, equipmentSetId, equipmentSetName,
    notes, createdAt, updatedAt,
  ];
}

/// Snapshot of one template item plus its run state.
class PreDiveSessionItem extends Equatable {
  final String id;
  final String sessionId;
  final String? section;
  final String title;
  final String notes;
  final int sortOrder;
  final PreDiveItemType itemType;
  final String? valueLabel;
  final String? valueUnit;
  final double? valueMin;
  final double? valueMax;
  final bool isRequired;
  final PreDiveItemState state;
  final double? valueNumber;
  final String? valueText;
  final String note;
  final DateTime? completedAt;
  final String? equipmentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveSessionItem({
    required this.id,
    required this.sessionId,
    this.section,
    required this.title,
    this.notes = '',
    this.sortOrder = 0,
    this.itemType = PreDiveItemType.check,
    this.valueLabel,
    this.valueUnit,
    this.valueMin,
    this.valueMax,
    this.isRequired = false,
    this.state = PreDiveItemState.pending,
    this.valueNumber,
    this.valueText,
    this.note = '',
    this.completedAt,
    this.equipmentId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isResolved => state != PreDiveItemState.pending;

  /// Advisory range warning for recorded values (never blocking).
  bool get valueOutOfRange {
    final v = valueNumber;
    if (v == null) return false;
    final belowMin = valueMin != null && v < valueMin!;
    final aboveMax = valueMax != null && v > valueMax!;
    return belowMin || aboveMax;
  }

  PreDiveSessionItem copyWith({
    String? id,
    String? sessionId,
    Object? section = _undefined,
    String? title,
    String? notes,
    int? sortOrder,
    PreDiveItemType? itemType,
    Object? valueLabel = _undefined,
    Object? valueUnit = _undefined,
    Object? valueMin = _undefined,
    Object? valueMax = _undefined,
    bool? isRequired,
    PreDiveItemState? state,
    Object? valueNumber = _undefined,
    Object? valueText = _undefined,
    String? note,
    Object? completedAt = _undefined,
    Object? equipmentId = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveSessionItem(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      section: section == _undefined ? this.section : section as String?,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      itemType: itemType ?? this.itemType,
      valueLabel:
          valueLabel == _undefined ? this.valueLabel : valueLabel as String?,
      valueUnit:
          valueUnit == _undefined ? this.valueUnit : valueUnit as String?,
      valueMin: valueMin == _undefined ? this.valueMin : valueMin as double?,
      valueMax: valueMax == _undefined ? this.valueMax : valueMax as double?,
      isRequired: isRequired ?? this.isRequired,
      state: state ?? this.state,
      valueNumber: valueNumber == _undefined
          ? this.valueNumber
          : valueNumber as double?,
      valueText:
          valueText == _undefined ? this.valueText : valueText as String?,
      note: note ?? this.note,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
      equipmentId:
          equipmentId == _undefined ? this.equipmentId : equipmentId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, sessionId, section, title, notes, sortOrder, itemType,
    valueLabel, valueUnit, valueMin, valueMax, isRequired, state,
    valueNumber, valueText, note, completedAt, equipmentId,
    createdAt, updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive checklist domain entities"
```

---

### Task 3: Pure domain services — session engine and item composer

**Files:**
- Create: `lib/features/pre_dive/domain/services/checklist_session_engine.dart`
- Create: `lib/features/pre_dive/domain/services/session_item_composer.dart`
- Test: `test/features/pre_dive/domain/services/checklist_session_engine_test.dart`
- Test: `test/features/pre_dive/domain/services/session_item_composer_test.dart`

**Interfaces:**
- Consumes: Task 2 entities; `EquipmentSet` (`lib/features/equipment/domain/entities/equipment_set.dart`, has `id`, `name`, `equipmentIds`), `EquipmentItem` (`lib/features/equipment/domain/entities/equipment_item.dart`, has `id`, `name`, `isServiceDue`).
- Produces:
  - `ChecklistSessionEngine.isItemActionable(session, sortedItems, item) -> bool`
  - `ChecklistSessionEngine.nextActionableItem(session, sortedItems) -> PreDiveSessionItem?`
  - `ChecklistSessionEngine.canComplete(items) -> bool`
  - `ChecklistSessionEngine.flaggedCount(items) -> int`
  - `ChecklistSessionEngine.resolvedCount(items) -> int`
  - `SessionItemComposer.compose({required templateItems, EquipmentSet? equipmentSet, List<EquipmentItem> equipmentItems = const [], required DateTime now}) -> List<PreDiveSessionItem>` — items with `id: ''` and `sessionId: ''` (repository fills both), sorted by resulting `sortOrder`.

- [ ] **Step 1: Write the failing engine test** at `test/features/pre_dive/domain/services/checklist_session_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session({bool strict = false, PreDiveSessionStatus status = PreDiveSessionStatus.inProgress}) =>
      PreDiveSession(
        id: 's1', templateName: 'T', strictOrder: strict,
        startedAt: now, status: status, createdAt: now, updatedAt: now,
      );

  PreDiveSessionItem item(int order,
          {PreDiveItemState state = PreDiveItemState.pending,
          bool required = false}) =>
      PreDiveSessionItem(
        id: 'i$order', sessionId: 's1', title: 'Item $order',
        sortOrder: order, state: state, isRequired: required,
        createdAt: now, updatedAt: now,
      );

  group('nextActionableItem / isItemActionable', () {
    test('free order: every pending item is actionable', () {
      final items = [item(0, state: PreDiveItemState.done), item(1), item(2)];
      final s = session();
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[1]), isTrue);
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[2]), isTrue);
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[0]), isFalse);
    });

    test('strict order: only the first pending item is actionable', () {
      final items = [item(0, state: PreDiveItemState.done), item(1), item(2)];
      final s = session(strict: true);
      expect(ChecklistSessionEngine.nextActionableItem(s, items)!.id, 'i1');
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[1]), isTrue);
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[2]), isFalse);
    });

    test('locked session: nothing is actionable', () {
      final items = [item(0)];
      final s = session(status: PreDiveSessionStatus.completed);
      expect(ChecklistSessionEngine.isItemActionable(s, items, items[0]), isFalse);
      expect(ChecklistSessionEngine.nextActionableItem(s, items), isNull);
    });
  });

  group('canComplete', () {
    test('truth table over required/optional and states', () {
      // required pending -> false
      expect(ChecklistSessionEngine.canComplete([item(0, required: true)]), isFalse);
      // required skipped -> false (skip is not a valid required outcome)
      expect(ChecklistSessionEngine.canComplete(
          [item(0, required: true, state: PreDiveItemState.skipped)]), isFalse);
      // required done -> true
      expect(ChecklistSessionEngine.canComplete(
          [item(0, required: true, state: PreDiveItemState.done)]), isTrue);
      // required flagged -> true (informed decision, confirmed in UI)
      expect(ChecklistSessionEngine.canComplete(
          [item(0, required: true, state: PreDiveItemState.flagged)]), isTrue);
      // optional pending does not block
      expect(ChecklistSessionEngine.canComplete(
          [item(0), item(1, required: true, state: PreDiveItemState.done)]), isTrue);
      // empty list completes
      expect(ChecklistSessionEngine.canComplete(const []), isTrue);
    });
  });

  test('flaggedCount and resolvedCount', () {
    final items = [
      item(0, state: PreDiveItemState.flagged),
      item(1, state: PreDiveItemState.done),
      item(2),
    ];
    expect(ChecklistSessionEngine.flaggedCount(items), 1);
    expect(ChecklistSessionEngine.resolvedCount(items), 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/pre_dive/domain/services/checklist_session_engine_test.dart`
Expected: FAIL (file not found / compile error).

- [ ] **Step 3: Implement the engine** at `lib/features/pre_dive/domain/services/checklist_session_engine.dart`:

```dart
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Pure rules for running a pre-dive checklist session. No I/O; the
/// repository enforces persistence-level immutability, this class answers
/// "what may the diver do right now".
class ChecklistSessionEngine {
  const ChecklistSessionEngine._();

  /// Items must be passed sorted by [PreDiveSessionItem.sortOrder].
  static PreDiveSessionItem? nextActionableItem(
    PreDiveSession session,
    List<PreDiveSessionItem> sortedItems,
  ) {
    if (session.isLocked) return null;
    for (final item in sortedItems) {
      if (item.state == PreDiveItemState.pending) return item;
    }
    return null;
  }

  static bool isItemActionable(
    PreDiveSession session,
    List<PreDiveSessionItem> sortedItems,
    PreDiveSessionItem item,
  ) {
    if (session.isLocked) return false;
    if (item.state != PreDiveItemState.pending) return false;
    if (!session.strictOrder) return true;
    return nextActionableItem(session, sortedItems)?.id == item.id;
  }

  /// Required items must end Done or Flagged. Optional items never block.
  static bool canComplete(List<PreDiveSessionItem> items) {
    return items.every(
      (i) =>
          !i.isRequired ||
          i.state == PreDiveItemState.done ||
          i.state == PreDiveItemState.flagged,
    );
  }

  static int flaggedCount(List<PreDiveSessionItem> items) =>
      items.where((i) => i.state == PreDiveItemState.flagged).length;

  static int resolvedCount(List<PreDiveSessionItem> items) =>
      items.where((i) => i.isResolved).length;
}
```

- [ ] **Step 4: Run engine test — passes**

Run: `flutter test test/features/pre_dive/domain/services/checklist_session_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing composer test** at `test/features/pre_dive/domain/services/session_item_composer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/session_item_composer.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplateItem tItem(int order,
          {PreDiveItemType type = PreDiveItemType.check,
          String? section,
          bool required = false}) =>
      PreDiveChecklistTemplateItem(
        id: 't$order', templateId: 'tpl', title: 'T$order',
        sortOrder: order, itemType: type, section: section,
        isRequired: required, createdAt: now, updatedAt: now,
      );

  // Adjust constructor args to EquipmentItem's actual required fields; only
  // id, name, lastServiceDate, serviceIntervalDays matter here.
  EquipmentItem gear(String id, String name, {bool overdue = false}) =>
      EquipmentItem(
        id: id, name: name,
        lastServiceDate: overdue ? now.subtract(const Duration(days: 400)) : null,
        serviceIntervalDays: overdue ? 365 : null,
        createdAt: now, updatedAt: now,
      );

  test('check and value items snapshot 1:1 with blank id/sessionId', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0), tItem(1, type: PreDiveItemType.value)],
      now: now,
    );
    expect(out, hasLength(2));
    expect(out[0].id, isEmpty);
    expect(out[0].sessionId, isEmpty);
    expect(out[0].title, 'T0');
    expect(out[1].itemType, PreDiveItemType.value);
    expect(out.every((i) => i.state == PreDiveItemState.pending), isTrue);
  });

  test('equipmentSet placeholder expands to one row per gear item', () {
    final set = EquipmentSet(
      id: 'set1', name: 'Warm water', equipmentIds: const ['g1', 'g2'],
      createdAt: now, updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0),
        tItem(1, type: PreDiveItemType.equipmentSet, section: 'Gear', required: true),
        tItem(2),
      ],
      equipmentSet: set,
      equipmentItems: [gear('g1', 'Regulator'), gear('g2', 'BCD')],
      now: now,
    );
    expect(out.map((i) => i.title).toList(),
        ['T0', 'Regulator', 'BCD', 'T2']);
    final reg = out[1];
    expect(reg.equipmentId, 'g1');
    expect(reg.section, 'Gear');
    expect(reg.isRequired, isTrue);
    expect(reg.itemType, PreDiveItemType.check);
    // sortOrder strictly increasing overall
    expect(out.map((i) => i.sortOrder).toList(), [0, 1, 2, 3]);
  });

  test('overdue-service gear starts pre-flagged with a note', () {
    final set = EquipmentSet(
      id: 'set1', name: 'S', equipmentIds: const ['g1'],
      createdAt: now, updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipmentSet)],
      equipmentSet: set,
      equipmentItems: [gear('g1', 'Old Reg', overdue: true)],
      now: now,
    );
    expect(out.single.state, PreDiveItemState.flagged);
    expect(out.single.note, isNotEmpty);
    expect(out.single.completedAt, isNotNull);
  });

  test('placeholder degrades to a plain check item without a set', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipmentSet)],
      now: now,
    );
    expect(out.single.itemType, PreDiveItemType.check);
    expect(out.single.equipmentId, isNull);
    expect(out.single.title, 'T0');
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart`
Expected: FAIL (composer missing). If `EquipmentItem`'s constructor requires more fields than the test helper passes, fix the helper (add required args with dummy values) — do not change `EquipmentItem`.

- [ ] **Step 7: Implement the composer** at `lib/features/pre_dive/domain/services/session_item_composer.dart`:

```dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Turns template items into session-item snapshots at session start.
/// Pure: callers load the equipment set and its gear items. Repository
/// assigns ids and sessionId afterwards.
class SessionItemComposer {
  const SessionItemComposer._();

  static List<PreDiveSessionItem> compose({
    required List<PreDiveChecklistTemplateItem> templateItems,
    EquipmentSet? equipmentSet,
    List<EquipmentItem> equipmentItems = const [],
    required DateTime now,
  }) {
    final byId = {for (final g in equipmentItems) g.id: g};
    final sorted = [...templateItems]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final out = <PreDiveSessionItem>[];
    var order = 0;

    for (final t in sorted) {
      if (t.itemType == PreDiveItemType.equipmentSet && equipmentSet != null) {
        for (final gearId in equipmentSet.equipmentIds) {
          final gear = byId[gearId];
          if (gear == null) continue;
          final overdue = gear.isServiceDue;
          out.add(
            PreDiveSessionItem(
              id: '',
              sessionId: '',
              section: t.section,
              title: gear.name,
              sortOrder: order++,
              itemType: PreDiveItemType.check,
              isRequired: t.isRequired,
              // Overdue service demands an explicit decision: the row
              // starts flagged and the diver may clear it to done.
              state: overdue
                  ? PreDiveItemState.flagged
                  : PreDiveItemState.pending,
              note: overdue ? 'Service overdue' : '',
              completedAt: overdue ? now : null,
              equipmentId: gear.id,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        continue;
      }
      // equipmentSet placeholder without a set degrades to a plain check
      // item so the checklist stays runnable.
      final effectiveType = t.itemType == PreDiveItemType.equipmentSet
          ? PreDiveItemType.check
          : t.itemType;
      out.add(
        PreDiveSessionItem(
          id: '',
          sessionId: '',
          section: t.section,
          title: t.title,
          notes: t.notes,
          sortOrder: order++,
          itemType: effectiveType,
          valueLabel: t.valueLabel,
          valueUnit: t.valueUnit,
          valueMin: t.valueMin,
          valueMax: t.valueMax,
          isRequired: t.isRequired,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return out;
  }
}
```

Note: the `'Service overdue'` note is intentionally a plain English audit string stored in data (like gear names), not localized UI copy.

- [ ] **Step 8: Run composer test — passes**

Run: `flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive session engine and item composer"
```

---

### Task 4: Template repository

**Files:**
- Create: `lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart`
- Test: `test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 2 entities, `SyncRepository` (`markRecordPending`, `logDeletion`), `DatabaseService.instance.database`, `LoggerService.forClass`, `SyncEventBus.notifyLocalChange`.
- Produces (class `PreDiveTemplateRepository`, all instance methods):
  - `Stream<void> watchTemplatesChanges()`
  - `Future<List<domain.PreDiveChecklistTemplate>> getAllTemplates({String? diverId})` — returns built-ins plus the diver's own templates, built-ins first then by name.
  - `Future<domain.PreDiveChecklistTemplate?> getTemplateById(String id)`
  - `Future<List<domain.PreDiveChecklistTemplateItem>> getItemsForTemplate(String templateId)` — sorted by `sortOrder`.
  - `Future<domain.PreDiveChecklistTemplate> createTemplate(domain.PreDiveChecklistTemplate template)`
  - `Future<void> updateTemplate(domain.PreDiveChecklistTemplate template)` — throws `StateError` on built-ins.
  - `Future<void> deleteTemplate(String id)` — throws `StateError` on built-ins; tombstones items + template.
  - `Future<void> saveItems(String templateId, List<domain.PreDiveChecklistTemplateItem> items)` — replace-all in a transaction; throws `StateError` on built-ins.
  - `Future<domain.PreDiveChecklistTemplate> cloneTemplate(String templateId, {String? diverId, required String newName})` — copies template (as non-built-in, `builtinKey: null`) + items.

- [ ] **Step 1: Write the failing test.** Mirror the arrangement of `test/features/checklists/data/repositories/checklist_template_repository_test.dart` (in-memory DB via `test/helpers/test_database.dart`, real `SyncRepository`, `tombstoneCount` helper querying `deletion_log`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveTemplateRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = PreDiveTemplateRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<int> tombstoneCount(String entityType, String recordId) async {
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log '
          'WHERE entity_type = ? AND record_id = ?',
          variables: [Variable(entityType), Variable(recordId)],
        )
        .get();
    return rows.first.read<int>('n');
  }

  domain.PreDiveChecklistTemplate template({String name = 'BWRAF'}) {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplate(
      id: '', name: name, createdAt: now, updatedAt: now,
    );
  }

  domain.PreDiveChecklistTemplateItem item(String templateId, String title,
      {int order = 0}) {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplateItem(
      id: '', templateId: templateId, title: title, sortOrder: order,
      createdAt: now, updatedAt: now,
    );
  }

  test('creates with generated id and reads back', () async {
    final created = await repository.createTemplate(template());
    expect(created.id, isNotEmpty);
    final all = await repository.getAllTemplates();
    expect(all, hasLength(1));
    expect(all.first.name, 'BWRAF');
  });

  test('saveItems round-trips typed fields sorted by order', () async {
    final tpl = await repository.createTemplate(template());
    await repository.saveItems(tpl.id, [
      item(tpl.id, 'Cell 1', order: 1).copyWith(
        itemType: domain.PreDiveItemType.value,
        valueLabel: 'mV', valueUnit: 'mV', valueMin: 8.5, valueMax: 13.0,
        isRequired: true,
      ),
      item(tpl.id, 'Assemble', order: 0),
    ]);
    final items = await repository.getItemsForTemplate(tpl.id);
    expect(items.map((i) => i.title).toList(), ['Assemble', 'Cell 1']);
    expect(items[1].itemType, domain.PreDiveItemType.value);
    expect(items[1].valueMin, 8.5);
    expect(items[1].isRequired, isTrue);
  });

  test('deleteTemplate tombstones the template and each item', () async {
    final tpl = await repository.createTemplate(template());
    await repository.saveItems(tpl.id, [
      item(tpl.id, 'One'), item(tpl.id, 'Two', order: 1),
    ]);
    final items = await repository.getItemsForTemplate(tpl.id);
    await repository.deleteTemplate(tpl.id);
    expect(await tombstoneCount('preDiveChecklistTemplates', tpl.id), 1);
    for (final it in items) {
      expect(await tombstoneCount('preDiveChecklistTemplateItems', it.id), 1);
    }
    expect(await repository.getAllTemplates(), isEmpty);
  });

  test('built-in templates reject update, delete, and saveItems', () async {
    final created = await repository.createTemplate(
      template(name: 'Built-in').copyWith(isBuiltIn: true, builtinKey: 'k'),
    );
    expect(() => repository.updateTemplate(created.copyWith(name: 'X')),
        throwsStateError);
    expect(() => repository.deleteTemplate(created.id), throwsStateError);
    expect(() => repository.saveItems(created.id, const []), throwsStateError);
  });

  test('cloneTemplate copies items as an editable user template', () async {
    final builtIn = await repository.createTemplate(
      template(name: 'CCR Build').copyWith(isBuiltIn: true, builtinKey: 'ccr'),
    );
    // Seed items directly (saveItems rejects built-ins): use the db.
    // Simplest path — clone from a user template instead:
    final user = await repository.createTemplate(template(name: 'Mine'));
    await repository.saveItems(user.id, [item(user.id, 'Step 1')]);
    final clone = await repository.cloneTemplate(
      user.id, newName: 'Mine (copy)',
    );
    expect(clone.id, isNot(user.id));
    expect(clone.isBuiltIn, isFalse);
    expect(clone.builtinKey, isNull);
    final cloneItems = await repository.getItemsForTemplate(clone.id);
    expect(cloneItems.single.title, 'Step 1');
    expect(cloneItems.single.templateId, clone.id);
    // Built-in templates are clonable too (metadata only, no items yet).
    final builtInClone = await repository.cloneTemplate(
      builtIn.id, newName: 'CCR (copy)',
    );
    expect(builtInClone.isBuiltIn, isFalse);
  });

  test('getAllTemplates scopes by diver but always includes built-ins',
      () async {
    await repository.createTemplate(
      template(name: 'Global built-in').copyWith(isBuiltIn: true, builtinKey: 'g'),
    );
    await repository.createTemplate(
      template(name: 'Mine').copyWith(diverId: 'diver-1'),
    );
    await repository.createTemplate(
      template(name: 'Theirs').copyWith(diverId: 'diver-2'),
    );
    final mine = await repository.getAllTemplates(diverId: 'diver-1');
    expect(mine.map((t) => t.name).toSet(), {'Global built-in', 'Mine'});
  });
}
```

Add the missing `import 'package:drift/drift.dart' show Variable;` if the analyzer asks for it. Note: `diverId: 'diver-1'` rows require a matching `divers` row only if FKs enforce it — the checklist tests pass raw diver ids the same way; if an FK failure occurs, insert minimal diver rows via `db.customStatement("INSERT INTO divers (id, ...) VALUES ...")` mirroring how the existing checklist repository test handles diverId scoping (check that file and copy its arrangement).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`
Expected: FAIL (repository missing).

- [ ] **Step 3: Implement the repository.** Copy the internals style of `checklist_template_repository.dart` verbatim (constructor, `_db` getter, `SyncRepository`, uuid, logger, try/catch + `rethrow`, `markRecordPending` + `SyncEventBus.notifyLocalChange()` after every write, `logDeletion` on deletes, replace-all `saveItems` doing sync bookkeeping after the transaction commits). Entity type keys: `preDiveChecklistTemplates` / `preDiveChecklistTemplateItems`. Key deltas from the checklist original:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;

class PreDiveTemplateRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(PreDiveTemplateRepository);

  Stream<void> watchTemplatesChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.preDiveChecklistTemplates,
      _db.preDiveChecklistTemplateItems,
    ]),
  );

  Future<List<domain.PreDiveChecklistTemplate>> getAllTemplates({
    String? diverId,
  }) async {
    final query = _db.select(_db.preDiveChecklistTemplates)
      ..where(
        (t) => diverId == null
            ? t.isBuiltIn.equals(true) | t.diverId.isNull()
            : t.isBuiltIn.equals(true) | t.diverId.equals(diverId),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.isBuiltIn),
        (t) => OrderingTerm.asc(t.name),
      ]);
    final rows = await query.get();
    return rows.map(_toDomainTemplate).toList();
  }

  /// Guard shared by update/delete/saveItems: built-ins are read-only.
  Future<void> _assertNotBuiltIn(String templateId) async {
    final row = await (_db.select(
      _db.preDiveChecklistTemplates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    if (row != null && row.isBuiltIn) {
      throw StateError('Built-in pre-dive templates are read-only');
    }
  }
  // createTemplate / updateTemplate / deleteTemplate / saveItems /
  // getTemplateById / getItemsForTemplate: copy from
  // checklist_template_repository.dart, adding the extra columns
  // (category, strictOrder, isBuiltIn, builtinKey on templates; section,
  // itemType: Value(item.itemType.name), valueLabel/Unit/Min/Max,
  // isRequired on items) and calling _assertNotBuiltIn first in
  // updateTemplate, deleteTemplate, and saveItems.

  Future<domain.PreDiveChecklistTemplate> cloneTemplate(
    String templateId, {
    String? diverId,
    required String newName,
  }) async {
    final source = await getTemplateById(templateId);
    if (source == null) {
      throw StateError('Template $templateId no longer exists');
    }
    final items = await getItemsForTemplate(templateId);
    final clone = await createTemplate(
      source.copyWith(
        id: '',
        diverId: diverId,
        name: newName,
        isBuiltIn: false,
        builtinKey: null,
      ),
    );
    await saveItems(
      clone.id,
      [for (final i in items) i.copyWith(id: '', templateId: clone.id)],
    );
    return clone;
  }

  domain.PreDiveChecklistTemplate _toDomainTemplate(
    PreDiveChecklistTemplate row,
  ) => domain.PreDiveChecklistTemplate(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    description: row.description,
    category: row.category,
    strictOrder: row.strictOrder,
    isBuiltIn: row.isBuiltIn,
    builtinKey: row.builtinKey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
  // _toDomainItem mirrors this, with
  // itemType: domain.PreDiveItemType.parse(row.itemType).
}
```

(The generated Drift row class for table `PreDiveChecklistTemplates` is named `PreDiveChecklistTemplate` — hence the `as domain` alias, exactly like the checklists feature.)

- [ ] **Step 4: Run test — passes**

Run: `flutter test test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive template repository"
```

---

### Task 5: Session repository

**Files:**
- Create: `lib/features/pre_dive/data/repositories/pre_dive_session_repository.dart`
- Test: `test/features/pre_dive/data/repositories/pre_dive_session_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 outputs; same core services as Task 4.
- Produces (class `PreDiveSessionRepository`):
  - `Stream<void> watchSessionsChanges()` — table updates on sessions + session items.
  - `Future<domain.PreDiveSession> startSession({required domain.PreDiveChecklistTemplate template, required List<domain.PreDiveSessionItem> items, String? diverId, String? diveId, String? tripId, String? equipmentSetId, String? equipmentSetName})` — inserts session + items in one transaction (snapshotting `templateName`, `strictOrder`), assigns uuids, marks all rows pending after commit.
  - `Future<domain.PreDiveSession?> getSessionById(String id)`
  - `Future<List<domain.PreDiveSessionItem>> getItemsForSession(String sessionId)` — sorted by `sortOrder`.
  - `Future<List<domain.PreDiveSession>> getAllSessions({String? diverId})` — newest `startedAt` first.
  - `Future<domain.PreDiveSession?> getActiveSession({String? diverId})` — most recent `inProgress`.
  - `Future<domain.PreDiveSession?> getSessionForDive(String diveId)`
  - `Future<List<domain.PreDiveSession>> getUnlinkedSessions({String? diverId})` — `diveId IS NULL`, any status.
  - `Future<void> updateItemState({required String sessionId, required String itemId, required domain.PreDiveItemState state, double? valueNumber, String? valueText, String? note})` — sets `completedAt = now` when state != pending, clears it when pending; throws `StateError` if the session is locked.
  - `Future<void> completeSession(String id)` / `Future<void> abortSession(String id)` — set status + `completedAt`; throw `StateError` if already locked.
  - `Future<void> linkToDive(String sessionId, String diveId)` / `Future<void> unlinkFromDive(String sessionId)` — allowed on locked sessions (linking is metadata, not audit content).
  - `Future<void> deleteSession(String id)` — deletes items + session with tombstones for every row.

- [ ] **Step 1: Write the failing test** (same test-database arrangement as Task 4):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveSessionRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = PreDiveSessionRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime.now();

  domain.PreDiveChecklistTemplate template({bool strict = false}) =>
      domain.PreDiveChecklistTemplate(
        id: 'tpl-1', name: 'CCR Build', strictOrder: strict,
        createdAt: now, updatedAt: now,
      );

  domain.PreDiveSessionItem draft(String title, {int order = 0}) =>
      domain.PreDiveSessionItem(
        id: '', sessionId: '', title: title, sortOrder: order,
        createdAt: now, updatedAt: now,
      );

  Future<domain.PreDiveSession> start({bool strict = false}) =>
      repository.startSession(
        template: template(strict: strict),
        items: [draft('A'), draft('B', order: 1)],
      );

  test('startSession snapshots template name and strictOrder', () async {
    final session = await start(strict: true);
    expect(session.id, isNotEmpty);
    expect(session.templateName, 'CCR Build');
    expect(session.strictOrder, isTrue);
    expect(session.status, domain.PreDiveSessionStatus.inProgress);
    final items = await repository.getItemsForSession(session.id);
    expect(items.map((i) => i.title).toList(), ['A', 'B']);
    expect(items.every((i) => i.sessionId == session.id), isTrue);
    expect(items.every((i) => i.id.isNotEmpty), isTrue);
  });

  test('updateItemState stamps and clears completedAt', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.updateItemState(
      sessionId: session.id, itemId: items[0].id,
      state: domain.PreDiveItemState.done,
    );
    var reread = await repository.getItemsForSession(session.id);
    expect(reread[0].state, domain.PreDiveItemState.done);
    expect(reread[0].completedAt, isNotNull);
    await repository.updateItemState(
      sessionId: session.id, itemId: items[0].id,
      state: domain.PreDiveItemState.pending,
    );
    reread = await repository.getItemsForSession(session.id);
    expect(reread[0].completedAt, isNull);
  });

  test('flag with note and value round-trip', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.updateItemState(
      sessionId: session.id, itemId: items[1].id,
      state: domain.PreDiveItemState.flagged,
      valueNumber: 7.9, note: 'cell 2 sluggish',
    );
    final reread = await repository.getItemsForSession(session.id);
    expect(reread[1].state, domain.PreDiveItemState.flagged);
    expect(reread[1].valueNumber, 7.9);
    expect(reread[1].note, 'cell 2 sluggish');
  });

  test('completed sessions are immutable', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.completeSession(session.id);
    final locked = await repository.getSessionById(session.id);
    expect(locked!.status, domain.PreDiveSessionStatus.completed);
    expect(locked.completedAt, isNotNull);
    expect(
      () => repository.updateItemState(
        sessionId: session.id, itemId: items[0].id,
        state: domain.PreDiveItemState.done,
      ),
      throwsStateError,
    );
    expect(() => repository.completeSession(session.id), throwsStateError);
    expect(() => repository.abortSession(session.id), throwsStateError);
  });

  test('link and unlink work on locked sessions', () async {
    final session = await start();
    await repository.completeSession(session.id);
    await repository.linkToDive(session.id, 'dive-1');
    expect((await repository.getSessionForDive('dive-1'))!.id, session.id);
    expect(await repository.getUnlinkedSessions(), isEmpty);
    await repository.unlinkFromDive(session.id);
    expect(await repository.getSessionForDive('dive-1'), isNull);
    expect(await repository.getUnlinkedSessions(), hasLength(1));
  });

  test('getActiveSession returns latest inProgress only', () async {
    final s1 = await start();
    await repository.completeSession(s1.id);
    final s2 = await start();
    expect((await repository.getActiveSession())!.id, s2.id);
    await repository.abortSession(s2.id);
    expect(await repository.getActiveSession(), isNull);
  });

  test('deleteSession tombstones session and items', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.deleteSession(session.id);
    expect(await repository.getSessionById(session.id), isNull);
    expect(await repository.getItemsForSession(session.id), isEmpty);
    // Tombstone assertions: copy the tombstoneCount helper from Task 1's
    // template repository test and assert 1 for the session id under
    // 'preDiveSessions' and each item id under 'preDiveSessionItems'.
    expect(items, hasLength(2));
  });
}
```

Note: `linkToDive(session.id, 'dive-1')` references a dive row that does not exist — if the FK rejects it, insert a minimal dive row first via `DatabaseService.instance.database.customStatement("INSERT INTO dives (id, dive_date_time, ...) VALUES ('dive-1', 0, ...)")` filling only NOT NULL columns (check `PRAGMA table_info('dives')` output in the failure message for which are required), or use the generated `DivesCompanion.insert`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/pre_dive/data/repositories/pre_dive_session_repository_test.dart`
Expected: FAIL (repository missing).

- [ ] **Step 3: Implement.** Same file skeleton as Task 4 (imports, `_db`, `SyncRepository`, uuid, logger, try/catch-rethrow). Core patterns:

```dart
  static const _sessionEntity = 'preDiveSessions';
  static const _itemEntity = 'preDiveSessionItems';

  Future<domain.PreDiveSession> startSession({
    required domain.PreDiveChecklistTemplate template,
    required List<domain.PreDiveSessionItem> items,
    String? diverId,
    String? diveId,
    String? tripId,
    String? equipmentSetId,
    String? equipmentSetName,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final itemIds = <String>[];
      await _db.transaction(() async {
        await _db.into(_db.preDiveSessions).insert(
          PreDiveSessionsCompanion(
            id: Value(sessionId),
            diverId: Value(diverId),
            templateId: Value(template.id.isEmpty ? null : template.id),
            templateName: Value(template.name),
            strictOrder: Value(template.strictOrder),
            diveId: Value(diveId),
            tripId: Value(tripId),
            startedAt: Value(now),
            status: Value(domain.PreDiveSessionStatus.inProgress.name),
            equipmentSetId: Value(equipmentSetId),
            equipmentSetName: Value(equipmentSetName),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        for (final item in items) {
          final itemId = _uuid.v4();
          itemIds.add(itemId);
          await _db.into(_db.preDiveSessionItems).insert(
            PreDiveSessionItemsCompanion(
              id: Value(itemId),
              sessionId: Value(sessionId),
              section: Value(item.section),
              title: Value(item.title),
              notes: Value(item.notes),
              sortOrder: Value(item.sortOrder),
              itemType: Value(item.itemType.name),
              valueLabel: Value(item.valueLabel),
              valueUnit: Value(item.valueUnit),
              valueMin: Value(item.valueMin),
              valueMax: Value(item.valueMax),
              isRequired: Value(item.isRequired),
              state: Value(item.state.name),
              note: Value(item.note),
              completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
              equipmentId: Value(item.equipmentId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      });
      await _syncRepository.markRecordPending(
        entityType: _sessionEntity, recordId: sessionId, localUpdatedAt: now);
      for (final id in itemIds) {
        await _syncRepository.markRecordPending(
          entityType: _itemEntity, recordId: id, localUpdatedAt: now);
      }
      SyncEventBus.notifyLocalChange();
      return (await getSessionById(sessionId))!;
    } catch (e, stackTrace) {
      _log.error('Failed to start pre-dive session',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Audit-record integrity: no mutation once a session leaves inProgress.
  Future<void> _assertMutable(String sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) {
      throw StateError('Pre-dive session $sessionId does not exist');
    }
    if (session.isLocked) {
      throw StateError('Pre-dive session $sessionId is locked');
    }
  }
```

`updateItemState` calls `_assertMutable(sessionId)` first, then writes a `PreDiveSessionItemsCompanion` with `state: Value(state.name)`, `completedAt: Value(state == domain.PreDiveItemState.pending ? null : DateTime.now().millisecondsSinceEpoch)`, `updatedAt`, and only-if-provided `Value`s for `valueNumber`/`valueText`/`note` (use `valueNumber == null ? const Value.absent() : Value(valueNumber)` so passing nothing preserves stored values), then `markRecordPending(_itemEntity, ...)` + notify. `completeSession`/`abortSession` call `_assertMutable`, then write `status` + `completedAt` + `updatedAt`, mark pending + notify. `linkToDive`/`unlinkFromDive` skip `_assertMutable` (write `diveId` + `updatedAt` only), mark pending + notify. `deleteSession` mirrors Task 4's `deleteTemplate` (children first, `logDeletion` per row). Queries: `getActiveSession` = `where status equals 'inProgress'` + `orderBy desc(startedAt)` + `limit 1`; `getUnlinkedSessions` = `where diveId IS NULL` (+ diver scope); row-to-domain mapping converts epoch ints with `DateTime.fromMillisecondsSinceEpoch` and enums with `parse`.

- [ ] **Step 4: Run test — passes**

Run: `flutter test test/features/pre_dive/data/repositories/pre_dive_session_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive session repository with immutability guards"
```

---

### Task 6: Built-in template seeding

**Files:**
- Modify: `lib/core/database/database.dart` (seed SQL constants near `kSeedBuiltInDiveTypesSql` ~:1582; `onCreate`; the v113 `onUpgrade` block; `beforeOpen` re-seed near the dive-types re-seed ~:5588)
- Test: `test/core/database/pre_dive_builtin_seed_test.dart`

**Interfaces:**
- Consumes: Task 1 tables.
- Produces: `kSeedBuiltInPreDiveTemplatesSql` and `kSeedBuiltInPreDiveTemplateItemsSql` top-level const strings; four built-in templates with stable ids `builtin-predive-bwraf`, `builtin-predive-gue-edge`, `builtin-predive-ccr-build`, `builtin-predive-gear-packing` (builtinKey = same string).

- [ ] **Step 1: Write the failing test** at `test/core/database/pre_dive_builtin_seed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<Map<String, Object?>>> rows(String sql) async {
    final db = DatabaseService.instance.database;
    final r = await db.customSelect(sql).get();
    return r.map((row) => row.data).toList();
  }

  test('fresh database seeds the four built-in templates with items',
      () async {
    // Force beforeOpen to run.
    await rows('SELECT 1');
    final templates = await rows(
      'SELECT id, name, strict_order, is_built_in FROM '
      'pre_dive_checklist_templates WHERE is_built_in = 1 ORDER BY id',
    );
    expect(templates.map((t) => t['id']).toList(), [
      'builtin-predive-bwraf',
      'builtin-predive-ccr-build',
      'builtin-predive-gear-packing',
      'builtin-predive-gue-edge',
    ]);
    final ccr = templates.firstWhere(
      (t) => t['id'] == 'builtin-predive-ccr-build',
    );
    expect(ccr['strict_order'], 1);

    final itemCounts = await rows(
      'SELECT template_id, COUNT(*) AS n FROM '
      'pre_dive_checklist_template_items GROUP BY template_id',
    );
    expect(itemCounts, hasLength(4));
    for (final row in itemCounts) {
      expect((row['n'] as int) >= 4, isTrue, reason: '${row['template_id']}');
    }
    // CCR build has value items with thresholds.
    final valueItems = await rows(
      "SELECT id FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-ccr-build' "
      "AND item_type = 'value' AND value_min IS NOT NULL",
    );
    expect(valueItems, isNotEmpty);
    // Gear packing has the equipmentSet placeholder.
    final placeholder = await rows(
      "SELECT id FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-gear-packing' "
      "AND item_type = 'equipmentSet'",
    );
    expect(placeholder, hasLength(1));
  });

  test('re-seed restores a deleted built-in (INSERT OR IGNORE idempotence)',
      () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "DELETE FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-bwraf'",
    );
    await db.customStatement(
      "DELETE FROM pre_dive_checklist_templates "
      "WHERE id = 'builtin-predive-bwraf'",
    );
    // Simulate next open's beforeOpen re-seed.
    await db.customStatement(kSeedBuiltInPreDiveTemplatesSql);
    await db.customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
    final restored = await rows(
      "SELECT id FROM pre_dive_checklist_templates "
      "WHERE id = 'builtin-predive-bwraf'",
    );
    expect(restored, hasLength(1));
    // Running twice must not duplicate.
    await db.customStatement(kSeedBuiltInPreDiveTemplatesSql);
    final all = await rows(
      'SELECT COUNT(*) AS n FROM pre_dive_checklist_templates '
      'WHERE is_built_in = 1',
    );
    expect(all.first['n'], 4);
  });
}
```

Add `import 'package:submersion/core/database/database.dart';` for the constants.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/pre_dive_builtin_seed_test.dart`
Expected: FAIL — constants undefined / no seeded rows.

- [ ] **Step 3: Add the seed constants** to `database.dart` next to `kSeedBuiltInDiveTypesSql`. Timestamps are the constant `0` (built-ins are device-local, never synced; deterministic values keep the statement idempotent). Content (abbreviated rows shown in full — write ALL rows exactly):

```dart
/// Built-in pre-dive checklist templates. INSERT OR IGNORE keyed on stable
/// ids so re-seeding on every open is idempotent and restores replace-adopt
/// wipes. Built-ins are read-only in the UI and skipped by sync export.
const String kSeedBuiltInPreDiveTemplatesSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_templates
    (id, name, description, category, strict_order, is_built_in,
     builtin_key, created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf', 'BWRAF Buddy Check',
     'Standard recreational pre-dive safety check',
     'Safety', 0, 1, 'builtin-predive-bwraf', 0, 0),
    ('builtin-predive-gue-edge', 'GUE EDGE',
     'Team pre-dive sequence',
     'Safety', 0, 1, 'builtin-predive-gue-edge', 0, 0),
    ('builtin-predive-ccr-build', 'CCR Build (generic)',
     'Generic rebreather assembly and pre-breathe checklist',
     'CCR', 1, 1, 'builtin-predive-ccr-build', 0, 0),
    ('builtin-predive-gear-packing', 'Gear Packing',
     'Pack and stage everything before leaving for the site',
     'Packing', 0, 1, 'builtin-predive-gear-packing', 0, 0)
''';

const String kSeedBuiltInPreDiveTemplateItemsSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_template_items
    (id, template_id, section, title, notes, sort_order, item_type,
     value_label, value_unit, value_min, value_max, is_required,
     created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf-0', 'builtin-predive-bwraf', NULL,
     'BCD / Buoyancy: inflate, deflate, dump valves', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-1', 'builtin-predive-bwraf', NULL,
     'Weights: in place, releases clear', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-2', 'builtin-predive-bwraf', NULL,
     'Releases: locate and check all buckles', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-3', 'builtin-predive-bwraf', NULL,
     'Air: valve open, breathe both regs, check gauge', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-bwraf-4', 'builtin-predive-bwraf', NULL,
     'Final OK: mask, fins, computer set, buddy signal', '', 4, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-0', 'builtin-predive-gue-edge', NULL,
     'Equipment: full gear check head to toe', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-1', 'builtin-predive-gue-edge', NULL,
     'Descent: agree on descent method and reference', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-2', 'builtin-predive-gue-edge', NULL,
     'Gas: analyze, label, confirm MOD and turn pressure', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-gue-3', 'builtin-predive-gue-edge', NULL,
     'Environment: conditions, entry/exit, hazards', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-0', 'builtin-predive-ccr-build', 'Assembly',
     'Scrubber packed and within duration limits', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-1', 'builtin-predive-ccr-build', 'Assembly',
     'Loop assembled, mushroom valves checked', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-2', 'builtin-predive-ccr-build', 'Tests',
     'Negative pressure test held 60 s', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-3', 'builtin-predive-ccr-build', 'Tests',
     'Positive pressure test held 60 s', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-4', 'builtin-predive-ccr-build', 'Cells',
     'Cell 1 mV in air', '', 4, 'value',
     'Cell 1', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-5', 'builtin-predive-ccr-build', 'Cells',
     'Cell 2 mV in air', '', 5, 'value',
     'Cell 2', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-6', 'builtin-predive-ccr-build', 'Cells',
     'Cell 3 mV in air', '', 6, 'value',
     'Cell 3', 'mV', 8.5, 13.0, 1, 0, 0),
    ('builtin-predive-ccr-7', 'builtin-predive-ccr-build', 'Gas',
     'Diluent and O2 analyzed, MOD labels on', '', 7, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-8', 'builtin-predive-ccr-build', 'Pre-breathe',
     'Five-minute pre-breathe, setpoint holds', '', 8, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-ccr-9', 'builtin-predive-ccr-build', 'Bailout',
     'Bailout analyzed, pressurized, clipped', '', 9, 'check',
     NULL, NULL, NULL, NULL, 1, 0, 0),
    ('builtin-predive-pack-0', 'builtin-predive-gear-packing', NULL,
     'Certification card and insurance', '', 0, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-1', 'builtin-predive-gear-packing', NULL,
     'Equipment set', '', 1, 'equipmentSet',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-2', 'builtin-predive-gear-packing', NULL,
     'Save-a-dive kit and spares', '', 2, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0),
    ('builtin-predive-pack-3', 'builtin-predive-gear-packing', NULL,
     'Water, sun protection, logbook', '', 3, 'check',
     NULL, NULL, NULL, NULL, 0, 0, 0)
''';
```

- [ ] **Step 4: Wire the seeds.** Three call sites, all `await customStatement(...)` for BOTH constants in order (templates, then items):
  1. `onCreate` — right after the dive-types seed call.
  2. The v113 `onUpgrade` block from Task 1, after `_assertPreDiveChecklistSchema()`.
  3. `beforeOpen` — after the dive-types re-seed, guarded the same way:

```dart
        final preDiveTable = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='pre_dive_checklist_templates'",
        ).get();
        if (preDiveTable.isNotEmpty) {
          await customStatement(kSeedBuiltInPreDiveTemplatesSql);
          await customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
        }
```

- [ ] **Step 5: Run test — passes**

Run: `flutter test test/core/database/pre_dive_builtin_seed_test.dart`
Expected: PASS. Also rerun `flutter test test/core/database/migration_v113_pre_dive_test.dart` — still PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: seed built-in pre-dive checklist templates"
```

---

### Task 7: Sync integration

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map ~:30)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (fields/toJson/fromJson ~:240/:355/:414; `_baseTables` ~:630; delta exporters ~:3729 + `_safeExport` wiring ~:1048; apply-incoming switch ~:1967; batch-apply switch ~:2432; `recordIdsFor` ~:2818; table resolver ~:2989; tombstone-apply switch ~:3224)
- Modify: `lib/core/services/sync/sync_service.dart` (merge order ~:922; `entityHasUpdatedAt` ~:1568; parent-FK map ~:1693)
- Test: `test/core/services/sync/sync_pre_dive_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4-6.
- Produces: the four entity types fully registered for HLC stamping, delta export, apply, tombstones, and topological ordering. Built-in templates and their items excluded from export.

- [ ] **Step 1: Write the failing test** at `test/core/services/sync/sync_pre_dive_test.dart`. Find the existing checklist serializer test (`grep -rl "checklistTemplates" test/core/services/sync/ | head -3`) and copy its arrangement for constructing the serializer. The test asserts:

```dart
// Pseudocode contract — adapt construction to the existing sync test setup:
// 1. Round-trip: create a user template (Task 4 repo) + a session with
//    items (Task 5 repo); run the delta exporter with hlcSince: null;
//    expect the SyncData JSON to contain the template under
//    'preDiveChecklistTemplates', its items, the session, session items.
// 2. Built-in skip: the seeded builtin-predive-* templates and their items
//    must NOT appear in the export.
// 3. Apply: feed the exported JSON into the apply path on a second
//    in-memory database (or after deleting the local rows) and expect the
//    rows to exist afterwards.
// 4. Structural: sync_service's entityHasUpdatedAt/parent maps cover the
//    four new keys — the existing structural test
//    (grep -rn "covers exactly" test/core/services/sync/) fails on its own
//    if you miss one; reference it here and rerun it.
```

Write it as real code following the neighboring sync tests' construction idiom — the contract above is what must be asserted.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/sync_pre_dive_test.dart`
Expected: FAIL (unknown entity keys / missing fields).

- [ ] **Step 3: Register HLC targets** in `sync_repository.dart` `_hlcTargets`, after the `tripChecklistItems` entry:

```dart
    'preDiveChecklistTemplates': (
      table: 'pre_dive_checklist_templates',
      pk: 'id',
    ),
    'preDiveChecklistTemplateItems': (
      table: 'pre_dive_checklist_template_items',
      pk: 'id',
    ),
    'preDiveSessions': (table: 'pre_dive_sessions', pk: 'id'),
    'preDiveSessionItems': (table: 'pre_dive_session_items', pk: 'id'),
```

- [ ] **Step 4: Serializer — all six touch points**, copying the checklist entries at each location and adapting names:
  1. Four `final List<Map<String, dynamic>>` fields + constructor params + `toJson` keys + `fromJson` `_parseList` lines.
  2. `_baseTables`: four records `(key: 'preDiveSessions', table: _db.preDiveSessions, blob: false, full: null)` etc.
  3. Delta exporters — templates and template items filter built-ins:

```dart
  Future<List<Map<String, dynamic>>> _exportPreDiveChecklistTemplates(
    String? hlcSince,
  ) async {
    // Built-ins are re-seeded identically on every device; export custom
    // templates only (mirrors _exportDiveTypes).
    final query = _db.select(_db.preDiveChecklistTemplates)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportPreDiveChecklistTemplateItems(
    String? hlcSince,
  ) async {
    final builtinIds = _db.selectOnly(_db.preDiveChecklistTemplates)
      ..addColumns([_db.preDiveChecklistTemplates.id])
      ..where(_db.preDiveChecklistTemplates.isBuiltIn.equals(true));
    final query = _db.select(_db.preDiveChecklistTemplateItems)
      ..where((t) => t.templateId.isNotInQuery(builtinIds));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

  Sessions and session items export unfiltered (plain copy of `_exportChecklistTemplates` with the table swapped). Wire all four into the delta builder next to the checklist `_safeExport` calls.
  4. Apply-incoming switch cases (`insertOnConflictUpdate` with `<RowClass>.fromJson(data).toCompanion(false)`) — note these are HLC entities so `.toCompanion(false)` is correct here (matches the checklist cases).
  5. Batch-apply switch, `recordIdsFor`, table resolver, and tombstone-apply switch — one case per entity each, copied from the adjacent checklist cases.

- [ ] **Step 5: sync_service.dart** — merge order (after the `tripChecklistItems` line, parents before children):

```dart
          (type: 'preDiveChecklistTemplates', records: data.preDiveChecklistTemplates, hasUpdatedAt: true),
          (type: 'preDiveChecklistTemplateItems', records: data.preDiveChecklistTemplateItems, hasUpdatedAt: true),
          (type: 'preDiveSessions', records: data.preDiveSessions, hasUpdatedAt: true),
          (type: 'preDiveSessionItems', records: data.preDiveSessionItems, hasUpdatedAt: true),
```

`entityHasUpdatedAt`: four `: true` entries. Parent-FK map:

```dart
    'preDiveChecklistTemplateItems': [
      (field: 'templateId', parent: 'preDiveChecklistTemplates', nullable: false),
    ],
    'preDiveSessions': [
      (field: 'templateId', parent: 'preDiveChecklistTemplates', nullable: true),
      (field: 'diveId', parent: 'dives', nullable: true),
      (field: 'tripId', parent: 'trips', nullable: true),
    ],
    'preDiveSessionItems': [
      (field: 'sessionId', parent: 'preDiveSessions', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: true),
    ],
```

- [ ] **Step 6: Run the new test and the sync structural tests — pass**

Run: `flutter test test/core/services/sync/sync_pre_dive_test.dart`
Then find and run the existing structural coverage test file (`grep -rln "entityHasUpdatedAt" test/ | head -2`) — Expected: all PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: register pre-dive checklist entities for sync"
```

---

### Task 8: Providers, routes, templates list page, settings link

**Files:**
- Create: `lib/features/pre_dive/presentation/providers/pre_dive_providers.dart`
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_templates_page.dart`
- Modify: `lib/core/router/app_router.dart` (new routes after the `/checklist-templates` block ~:1101)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Manage Data card, after the checklist-templates ListTile ~:1679)
- Modify: `lib/l10n/arb/app_en.arb` (English strings only in this task)
- Test: `test/features/pre_dive/presentation/pages/pre_dive_templates_page_test.dart`

**Interfaces:**
- Consumes: Tasks 4-5 repositories; `validatedCurrentDiverIdProvider` (`lib/features/divers/presentation/providers/diver_providers.dart:194`); `equipmentSetsProvider` (`lib/features/equipment/presentation/providers/equipment_set_providers.dart:14`); the `package:submersion/core/providers/provider.dart` barrel (`invalidateSelfWhen`).
- Produces:
  - `preDiveTemplateRepositoryProvider` / `preDiveSessionRepositoryProvider` (plain `Provider`)
  - `preDiveTemplatesProvider` (`FutureProvider<List<domain.PreDiveChecklistTemplate>>`)
  - `preDiveTemplateProvider` / `preDiveTemplateItemsProvider` (`FutureProvider.family` by templateId)
  - `preDiveSessionProvider` / `preDiveSessionItemsProvider` (`FutureProvider.family` by sessionId)
  - `preDiveSessionsProvider` (`FutureProvider<List<domain.PreDiveSession>>`)
  - `preDiveActiveSessionProvider` (`FutureProvider<domain.PreDiveSession?>`)
  - `preDiveSessionForDiveProvider` (`FutureProvider.family` by diveId)
  - Routes: `/pre-dive-checklists` (name `preDiveTemplates`), `/pre-dive-checklists/new` (`newPreDiveTemplate`), `/pre-dive-checklists/:templateId/edit` (`editPreDiveTemplate`), `/pre-dive-sessions` (`preDiveSessions`), `/pre-dive-sessions/:sessionId` (`preDiveSessionRunner`).

- [ ] **Step 1: Providers.** Mirror `checklist_providers.dart` exactly (import the core barrel, not flutter_riverpod):

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

final preDiveTemplateRepositoryProvider = Provider<PreDiveTemplateRepository>(
  (ref) => PreDiveTemplateRepository(),
);

final preDiveSessionRepositoryProvider = Provider<PreDiveSessionRepository>(
  (ref) => PreDiveSessionRepository(),
);

final preDiveTemplatesProvider =
    FutureProvider<List<domain.PreDiveChecklistTemplate>>((ref) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getAllTemplates(diverId: diverId);
    });

final preDiveTemplateProvider = FutureProvider
    .family<domain.PreDiveChecklistTemplate?, String>((ref, templateId) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getTemplateById(templateId);
    });

final preDiveTemplateItemsProvider = FutureProvider
    .family<List<domain.PreDiveChecklistTemplateItem>, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getItemsForTemplate(templateId);
    });

final preDiveSessionsProvider = FutureProvider<List<domain.PreDiveSession>>((
  ref,
) async {
  final repository = ref.watch(preDiveSessionRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSessionsChanges());
  return repository.getAllSessions(diverId: diverId);
});

final preDiveActiveSessionProvider = FutureProvider<domain.PreDiveSession?>((
  ref,
) async {
  final repository = ref.watch(preDiveSessionRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSessionsChanges());
  return repository.getActiveSession(diverId: diverId);
});

final preDiveSessionProvider = FutureProvider
    .family<domain.PreDiveSession?, String>((ref, sessionId) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getSessionById(sessionId);
    });

final preDiveSessionItemsProvider = FutureProvider
    .family<List<domain.PreDiveSessionItem>, String>((ref, sessionId) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getItemsForSession(sessionId);
    });

final preDiveSessionForDiveProvider = FutureProvider
    .family<domain.PreDiveSession?, String>((ref, diveId) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getSessionForDive(diveId);
    });
```

- [ ] **Step 2: English strings** in `app_en.arb` (this task's pages only; keys are flat, feature-prefixed like the checklist keys):

```json
"preDive_templates_title": "Pre-Dive Checklists",
"preDive_templates_empty": "No pre-dive checklists yet",
"preDive_templates_builtInBadge": "Built-in",
"preDive_templates_clone": "Clone",
"preDive_templates_cloneSuffix": " (copy)",
"preDive_templates_delete": "Delete",
"preDive_templates_deleteConfirm": "Delete this checklist template?",
"preDive_templates_strictOrderBadge": "Strict order",
"settings_manage_preDiveChecklists": "Pre-Dive Checklists",
"settings_manage_preDiveChecklists_subtitle": "Buddy checks, CCR build lists, gear packing",
```

- [ ] **Step 3: Templates list page.** Model on `checklist_templates_page.dart` (107 lines): `ConsumerWidget`, watch `preDiveTemplatesProvider`, `AsyncValue.value`-style non-flickering read (copy the `itemsAsync.value` + `hasError` idiom from `trip_checklist_section.dart:28-42`), `ListView.separated`, FAB pushing `/pre-dive-checklists/new`. Tile: `leading` icon (`Icons.checklist_rtl`), title = name, subtitle = category, built-ins get a `Chip`-style "Built-in" label plus a lock icon and a popup menu with only Clone; user templates get Edit (tap) and a popup with Clone + Delete (confirm dialog). Clone calls `ref.read(preDiveTemplateRepositoryProvider).cloneTemplate(t.id, diverId: <current diver id read via ref.read(validatedCurrentDiverIdProvider.future)>, newName: t.name + context.l10n.preDive_templates_cloneSuffix)`.

- [ ] **Step 4: Routes** in `app_router.dart` directly after the `/checklist-templates` GoRoute block:

```dart
        // Pre-dive checklists
        GoRoute(
          path: '/pre-dive-checklists',
          name: 'preDiveTemplates',
          builder: (context, state) => const PreDiveTemplatesPage(),
          routes: [
            GoRoute(
              path: 'new',
              name: 'newPreDiveTemplate',
              builder: (context, state) => const PreDiveTemplateEditPage(),
            ),
            GoRoute(
              path: ':templateId/edit',
              name: 'editPreDiveTemplate',
              builder: (context, state) => PreDiveTemplateEditPage(
                templateId: state.pathParameters['templateId'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/pre-dive-sessions',
          name: 'preDiveSessions',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const PreDiveSessionsPage(),
          ),
          routes: [
            GoRoute(
              path: ':sessionId',
              name: 'preDiveSessionRunner',
              builder: (context, state) => PreDiveSessionRunnerPage(
                sessionId: state.pathParameters['sessionId']!,
              ),
            ),
          ],
        ),
```

`PreDiveTemplateEditPage`, `PreDiveSessionsPage`, and `PreDiveSessionRunnerPage` do not exist yet — create placeholder stubs now so the router compiles (a `Scaffold` with the page title; Tasks 9-10 replace them):

```dart
// pre_dive_template_edit_page.dart (stub, replaced in Task 9)
class PreDiveTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;
  const PreDiveTemplateEditPage({super.key, this.templateId});
  ...returns Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
}
```

- [ ] **Step 5: Settings link** — add after the checklist-templates ListTile + a `Divider(height: 1)` in `settings_page.dart`:

```dart
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.fact_check),
          title: Text(context.l10n.settings_manage_preDiveChecklists),
          subtitle: Text(
            context.l10n.settings_manage_preDiveChecklists_subtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/pre-dive-checklists'),
        ),
```

- [ ] **Step 6: Regenerate l10n and write the widget test.** Run `flutter gen-l10n`. Test at `test/features/pre_dive/presentation/pages/pre_dive_templates_page_test.dart` using `test/helpers/test_app.dart`'s `testApp(...)`:

```dart
// Overrides: preDiveTemplatesProvider.overrideWith((ref) async => [builtIn, userTpl]);
// Asserts:
// - both names render;
// - the built-in row shows the 'Built-in' badge text and no Delete menu entry;
// - the user row's popup menu contains 'Delete';
// - empty override renders 'No pre-dive checklists yet'.
```

Write it as real code following `trip_detail_checklist_test.dart`'s override idiom (`FutureProvider.overrideWith((ref) async => value)`), including the mobile surface-size helper if the page uses breakpoints.

- [ ] **Step 7: Run test + analyze**

Run: `flutter test test/features/pre_dive/presentation/pages/pre_dive_templates_page_test.dart` — PASS.
Run: `flutter analyze` — no new issues.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive checklist providers, routes, and templates page"
```

---

### Task 9: Template edit page

**Files:**
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart` (replace Task 8 stub)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart`

**Interfaces:**
- Consumes: Task 8 providers, Task 4 repository, `ChecklistTemplateEditPage` as the structural model (`lib/features/checklists/presentation/pages/checklist_template_edit_page.dart` — copy its state shape, ReorderableListView usage at :163-197, dialog-owns-controllers pattern at :205-212, and save flow).
- Produces: `PreDiveTemplateEditPage({String? templateId})` — full editor.

- [ ] **Step 1: English strings:**

```json
"preDive_edit_titleNew": "New Pre-Dive Checklist",
"preDive_edit_titleEdit": "Edit Pre-Dive Checklist",
"preDive_edit_name": "Name",
"preDive_edit_description": "Description",
"preDive_edit_category": "Category",
"preDive_edit_strictOrder": "Strict order",
"preDive_edit_strictOrderHelp": "Items must be completed top to bottom",
"preDive_edit_addItem": "Add item",
"preDive_edit_save": "Save",
"preDive_edit_nameRequired": "Enter a name",
"preDive_item_title": "Title",
"preDive_item_section": "Section",
"preDive_item_notes": "Notes",
"preDive_item_required": "Required",
"preDive_item_type_check": "Checkbox",
"preDive_item_type_value": "Recorded value",
"preDive_item_type_equipmentSet": "Equipment set items",
"preDive_item_valueLabel": "Value label",
"preDive_item_valueUnit": "Unit",
"preDive_item_valueMin": "Min (warning)",
"preDive_item_valueMax": "Max (warning)",
```

- [ ] **Step 2: Write the failing widget test.** Assert: (a) new-template mode renders name field and Save; (b) tapping Add item opens the item dialog; (c) selecting type "Recorded value" reveals the value label/unit/min/max fields; (d) Save with empty name shows the validation message and does not pop. Use `testApp`, override `preDiveTemplateProvider('t1')` / `preDiveTemplateItemsProvider('t1')` for edit mode. Remember `ensureVisible` before tapping controls low on the page and `tester.pump()` after dialog opens.

- [ ] **Step 3: Implement the page.** Copy `checklist_template_edit_page.dart` structure wholesale, with these deltas:
  - Header form adds a Category `TextFormField` and a `SwitchListTile` for `strictOrder` (title `preDive_edit_strictOrder`, subtitle `preDive_edit_strictOrderHelp`).
  - In-memory `List<domain.PreDiveChecklistTemplateItem> _items`; same ReorderableListView + delete-leading-icon + tap-to-edit rows; row subtitle shows section and a compact type/required summary (e.g. `Text([if (item.section != null) item.section!, _typeLabel(context, item.itemType), if (item.isRequired) context.l10n.preDive_item_required].join(' - '))`).
  - The item dialog (own StatefulWidget owning its controllers, disposed in its own `dispose` — copy the load-bearing comment) has: title field, section field, notes field, `DropdownButtonFormField<PreDiveItemType>` with the three localized labels, Required switch, and — only when type == value — value label/unit/min/max fields (`TextInputType.numberWithOptions(decimal: true)`, `double.tryParse`).
  - Save flow: `createTemplate` or `updateTemplate` then `saveItems(templateId, _items)` via `ref.read(preDiveTemplateRepositoryProvider)`; pop on success. Built-ins can never reach this page (list page offers no Edit for them), but guard anyway: if `template.isBuiltIn`, show the page read-only (disable Save and item mutation) — one boolean, no separate layout.
  - Sort orders reassigned `0..n-1` from list position at save time.

- [ ] **Step 4: Run test — passes; analyze clean**

Run: `flutter test test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart` — PASS.
Run: `flutter gen-l10n && flutter analyze` — clean.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive template editor"
```

---

### Task 10: Session runner, item tile, sessions list, start sheet

**Files:**
- Create: `lib/features/pre_dive/presentation/widgets/session_item_tile.dart`
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_session_runner_page.dart` (replace stub)
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_sessions_page.dart` (replace stub)
- Create: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_session_runner_page_test.dart`
- Test: `test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 8; `equipmentSetsProvider`; `EquipmentRepository().getAllEquipment(diverId:)`; `EquipmentSetSelector.bestSetFor` is NOT needed here (no dive location at start time) — the start sheet pre-selects the diver's default set (`sets.firstWhere((s) => s.isDefault, orElse: ...)`).
- Produces:
  - `SessionItemTile({required session, required sortedItems, required item, required onDone, required onSkip, required onFlag, required onEditValue, required onAddNote})`
  - `PreDiveSessionRunnerPage({required String sessionId})`
  - `PreDiveSessionsPage()`
  - `Future<void> showStartSessionSheet(BuildContext context, WidgetRef ref, {String? diveId, String? tripId})` — picks template (+ equipment set when the template has an `equipmentSet` item), composes items, starts the session, then `context.push('/pre-dive-sessions/$sessionId')`.

- [ ] **Step 1: English strings:**

```json
"preDive_runner_progress": "{done} of {total}",
"@preDive_runner_progress": {
  "placeholders": {"done": {"type": "int"}, "total": {"type": "int"}}
},
"preDive_runner_complete": "Complete",
"preDive_runner_completeFlagged": "Complete with {count} flagged items?",
"@preDive_runner_completeFlagged": {
  "placeholders": {"count": {"type": "int"}}
},
"preDive_runner_abort": "Abort checklist",
"preDive_runner_abortConfirm": "Abort this checklist? It will be kept in history as aborted.",
"preDive_runner_skip": "Skip",
"preDive_runner_flag": "Flag",
"preDive_runner_undo": "Reset to pending",
"preDive_runner_addNote": "Add note",
"preDive_runner_enterValue": "Enter value",
"preDive_runner_completedAt": "Completed {time}",
"@preDive_runner_completedAt": {"placeholders": {"time": {"type": "String"}}},
"preDive_runner_flaggedBadge": "{count} flagged",
"@preDive_runner_flaggedBadge": {"placeholders": {"count": {"type": "int"}}},
"preDive_runner_locked": "This checklist is locked",
"preDive_sessions_title": "Pre-Dive Checklists",
"preDive_sessions_empty": "No checklist runs yet",
"preDive_sessions_resume": "Resume",
"preDive_sessions_start": "Start checklist",
"preDive_sessions_statusCompleted": "Completed",
"preDive_sessions_statusAborted": "Aborted",
"preDive_sessions_statusInProgress": "In progress",
"preDive_sessions_linkedDive": "Linked dive",
"preDive_sessions_delete": "Delete",
"preDive_sessions_deleteConfirm": "Delete this checklist record?",
"preDive_start_title": "Start pre-dive checklist",
"preDive_start_template": "Checklist",
"preDive_start_equipmentSet": "Equipment set",
"preDive_start_noEquipmentSet": "None",
"preDive_start_begin": "Begin",
"cancel_button": "Cancel",
```

(If a generic cancel key already exists in `app_en.arb` — check with `grep '"cancel' lib/l10n/arb/app_en.arb` — use the existing key and drop `cancel_button`.)

- [ ] **Step 2: Write the failing runner test.** Overrides: `preDiveSessionProvider('s1')` and `preDiveSessionItemsProvider('s1')` with an in-progress strict-order session of 3 items (first done, second pending, third pending) and a repository provider override (`preDiveSessionRepositoryProvider.overrideWithValue(_FakeSessionRepo())` where `_FakeSessionRepo implements PreDiveSessionRepository` via `noSuchMethod`, recording `updateItemState` calls). Assert:
  - progress text "1 of 3" renders;
  - the third tile's checkbox/tap target is disabled (strict order) while the second is enabled;
  - tapping the second tile records an `updateItemState(state: done)` call;
  - Complete button disabled while a required item is pending, enabled after;
  - completed session (override status completed) renders the locked banner and no Complete button.

- [ ] **Step 3: Implement `SessionItemTile`.** Stateless. Large tap target (`minVerticalPadding: 12`), leading state icon: pending = `Icons.radio_button_unchecked`, done = `Icons.check_circle` (primary), skipped = `Icons.remove_circle_outline` (onSurfaceVariant), flagged = `Icons.flag` (error). Title `bodyLarge` (deck-readable); value items show `valueLabel: valueNumber valueUnit` line, amber (`Colors.amber.shade700`) when `item.valueOutOfRange`; note line in italics when non-empty; trailing shows per-item completed time (`TimeOfDay.fromDateTime(...).format(context)`) when resolved. Behavior: `enabled = ChecklistSessionEngine.isItemActionable(session, sortedItems, item)`; disabled pending tiles render dimmed (`Opacity(0.4)`). Tap: value items -> `onEditValue`, check items -> `onDone`. Long-press (and a trailing `PopupMenuButton` for discoverability) offers Skip (hidden when `item.isRequired`), Flag, Add note, and — when resolved and the session is unlocked — Reset to pending.

- [ ] **Step 4: Implement `PreDiveSessionRunnerPage`.** `ConsumerWidget`. Watch `preDiveSessionProvider(sessionId)` + `preDiveSessionItemsProvider(sessionId)` with the non-flicker `.value` idiom. Layout:
  - AppBar: title = `session.templateName`; actions: abort `IconButton(Icons.close)` (confirm dialog -> `abortSession` -> pop) only when unlocked; flagged-count badge chip when `flaggedCount > 0`.
  - Sticky header: `LinearProgressIndicator(value: resolved/total)` + `Text(l10n.preDive_runner_progress(resolved, total))`.
  - Body: `ListView` grouped by `section` (null-section items first, then each section under a header `Text(section, style: titleSmall)`) of `SessionItemTile`s.
  - Locked sessions: a `MaterialBanner`-style container with `l10n.preDive_runner_locked` + status/completedAt; tiles render read-only (engine returns not-actionable).
  - Bottom bar (unlocked only): full-width `FilledButton` "Complete", `onPressed: ChecklistSessionEngine.canComplete(items) ? _complete : null`. `_complete` shows the flagged confirmation dialog when `flaggedCount > 0`, then `completeSession` (page stays, now rendering read-only).
  - Value entry dialog: `TextField` (decimal keyboard, suffix = unit) + optional note field; saves via `updateItemState(state: done, valueNumber: parsed, note: ...)`. Note dialog: single field, saves note preserving current state (call `updateItemState` with the item's current state + note).
  - Every mutation goes through `ref.read(preDiveSessionRepositoryProvider)` — providers self-invalidate via `watchSessionsChanges()`, no manual refresh.

- [ ] **Step 5: Implement `PreDiveSessionsPage`.** `ConsumerWidget` watching `preDiveSessionsProvider` + `preDiveActiveSessionProvider`. Active session pinned in a `Card` on top with progress + `FilledButton` Resume (`context.push('/pre-dive-sessions/${s.id}')`). History below: `ListView.separated`, tile title = templateName, subtitle = started date (`MaterialLocalizations.of(context).formatMediumDate`) + status label + flag badge, linked-dive chip when `diveId != null` (`ActionChip` pushing `/dives/${s.diveId}`), popup menu Delete (confirm -> `deleteSession`). FAB "Start checklist" -> `showStartSessionSheet(context, ref)`.

- [ ] **Step 6: Implement `showStartSessionSheet`.** `showModalBottomSheet` with a `Consumer` body: template `DropdownButtonFormField` from `preDiveTemplatesProvider` (default first entry); when the chosen template's items (read via `ref.read(preDiveTemplateRepositoryProvider).getItemsForTemplate(...)` on selection) contain an `equipmentSet` item, show an equipment-set dropdown from `equipmentSetsProvider` (pre-select the set with `isDefault == true`, allow "None"). Begin button:

```dart
Future<void> _begin() async {
  final templateRepo = ref.read(preDiveTemplateRepositoryProvider);
  final sessionRepo = ref.read(preDiveSessionRepositoryProvider);
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final templateItems = await templateRepo.getItemsForTemplate(template.id);
  List<EquipmentItem> gear = const [];
  if (chosenSet != null) {
    final all = await EquipmentRepository().getAllEquipment(diverId: diverId);
    gear = all.where((g) => chosenSet.equipmentIds.contains(g.id)).toList();
  }
  final items = SessionItemComposer.compose(
    templateItems: templateItems,
    equipmentSet: chosenSet,
    equipmentItems: gear,
    now: DateTime.now(),
  );
  final session = await sessionRepo.startSession(
    template: template,
    items: items,
    diverId: diverId,
    diveId: diveId,
    tripId: tripId,
    equipmentSetId: chosenSet?.id,
    equipmentSetName: chosenSet?.name,
  );
  if (context.mounted) {
    Navigator.pop(context);
    context.push('/pre-dive-sessions/${session.id}');
  }
}
```

- [ ] **Step 7: Start-sheet test.** Overrides: `preDiveTemplatesProvider` (two templates, one whose items include an equipmentSet item — override `preDiveTemplateRepositoryProvider` with a fake returning those items), `equipmentSetsProvider` (one default set). Assert the equipment dropdown appears only for the equipmentSet-bearing template and the default set is pre-selected.

- [ ] **Step 8: Run tests, analyze**

Run: `flutter gen-l10n`
Run: `flutter test test/features/pre_dive/presentation/pages/pre_dive_session_runner_page_test.dart` — PASS
Run: `flutter test test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart` — PASS
Run: `flutter analyze` — clean.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive session runner, sessions list, and start sheet"
```

---

### Task 11: Dive auto-linking

**Files:**
- Create: `lib/features/pre_dive/data/services/checklist_dive_linker.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (~:933, after the `DiveEquipmentDefaulter` call)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (~:1300)
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart` (~:383)
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (~:271)
- Test: `test/features/pre_dive/data/services/checklist_dive_linker_test.dart`

**Interfaces:**
- Consumes: Task 5 repository; domain `Dive` (`dive.dateTime`, `dive.id`, `dive.diverId`).
- Produces: `ChecklistDiveLinker` with `Future<bool> autoLinkForDive({required String diveId, required String? diverId, required DateTime diveStart})` and `Future<bool> applyForImportedDive(Dive dive)` (mirrors `DiveEquipmentDefaulter`'s shape: best-effort, never throws).

- [ ] **Step 1: Write the failing test** (in-memory DB arrangement as Tasks 4-5):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveSessionRepository sessions;
  late ChecklistDiveLinker linker;

  setUp(() async {
    await setUpTestDatabase();
    sessions = PreDiveSessionRepository();
    linker = ChecklistDiveLinker();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final diveStart = DateTime(2026, 7, 16, 9, 30);

  domain.PreDiveChecklistTemplate template() {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplate(
      id: 'tpl', name: 'BWRAF', createdAt: now, updatedAt: now,
    );
  }

  // startSession stamps startedAt = now, so tests adjust it directly in SQL.
  Future<domain.PreDiveSession> sessionStartedAt(DateTime t,
      {String? diverId}) async {
    final s = await sessions.startSession(
      template: template(),
      items: const [],
      diverId: diverId,
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'UPDATE pre_dive_sessions SET started_at = ? WHERE id = ?',
      [t.millisecondsSinceEpoch, s.id],
    );
    return (await sessions.getSessionById(s.id))!;
  }

  test('links the nearest unlinked session inside the window', () async {
    final far = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 2, minutes: 30)));
    final near = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 20)));
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1', diverId: null, diveStart: diveStart);
    expect(linked, isTrue);
    expect((await sessions.getSessionById(near.id))!.diveId, 'dive-1');
    expect((await sessions.getSessionById(far.id))!.diveId, isNull);
  });

  test('ignores sessions outside the 3h window or too far forward',
      () async {
    await sessionStartedAt(diveStart.subtract(const Duration(hours: 4)));
    await sessionStartedAt(diveStart.add(const Duration(hours: 1)));
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1', diverId: null, diveStart: diveStart);
    expect(linked, isFalse);
  });

  test('one-to-one: a dive that already has a session is skipped', () async {
    final s1 = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 30)));
    await sessions.linkToDive(s1.id, 'dive-1');
    final s2 = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 10)));
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1', diverId: null, diveStart: diveStart);
    expect(linked, isFalse);
    expect((await sessions.getSessionById(s2.id))!.diveId, isNull);
  });

  test('cross-diver isolation', () async {
    await sessionStartedAt(diveStart.subtract(const Duration(minutes: 10)),
        diverId: 'other-diver');
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1', diverId: 'me', diveStart: diveStart);
    expect(linked, isFalse);
  });
}
```

Add `import 'package:submersion/core/services/database_service.dart';` and, if the `dives`/`divers` FKs complain, insert minimal parent rows as in Task 5's note. `diverId: 'other-diver'` vs `'me'`: sessions with a non-matching diverId (or where exactly one side is null) must not link; sessions and dives both null-diverId may link.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/pre_dive/data/services/checklist_dive_linker_test.dart`
Expected: FAIL (linker missing).

- [ ] **Step 3: Implement the linker:**

```dart
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

/// Auto-links pre-dive checklist sessions to dives created afterwards.
/// Best-effort: linking failures must never abort a dive import
/// (mirrors DiveEquipmentDefaulter).
class ChecklistDiveLinker {
  final PreDiveSessionRepository _sessions;

  ChecklistDiveLinker({PreDiveSessionRepository? sessions})
    : _sessions = sessions ?? PreDiveSessionRepository();

  /// A checklist run belongs to the dive that splashed within this window
  /// after it started. The forward grace absorbs dive-computer wall-clock
  /// skew relative to the phone.
  static const linkWindow = Duration(hours: 3);
  static const forwardGrace = Duration(minutes: 15);

  Future<bool> autoLinkForDive({
    required String diveId,
    required String? diverId,
    required DateTime diveStart,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      // One-to-one: never steal onto a dive that already has a session.
      if (await _sessions.getSessionForDive(diveId) != null) return false;

      final candidates = await _sessions.getUnlinkedSessions(diverId: diverId);
      domain.PreDiveSession? best;
      Duration? bestDistance;
      for (final s in candidates) {
        if (s.diverId != diverId) continue;
        final delta = diveStart.difference(s.startedAt);
        final inWindow = delta <= linkWindow && delta >= -forwardGrace;
        if (!inWindow) continue;
        final distance = delta.abs();
        if (bestDistance == null || distance < bestDistance) {
          best = s;
          bestDistance = distance;
        }
      }
      if (best == null) return false;
      await _sessions.linkToDive(best.id, diveId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyForImportedDive(Dive dive) => autoLinkForDive(
    diveId: dive.id,
    diverId: dive.diverId,
    diveStart: dive.dateTime,
  );
}
```

Note on `getUnlinkedSessions(diverId:)`: make its diver filter exact-match in the repository (`diverId == null ? t.diverId.isNull() : t.diverId.equals(diverId)`) so the `s.diverId != diverId` re-check is belt-and-braces, then keep both.

- [ ] **Step 4: Run test — passes**

Run: `flutter test test/features/pre_dive/data/services/checklist_dive_linker_test.dart`
Expected: PASS.

- [ ] **Step 5: Hook the four import call sites.** At each location, directly after the existing `DiveEquipmentDefaulter` call, add the linker call with the same style the site already uses:
  - `uddf_entity_importer.dart:~1300`, `dive_import_providers.dart:~383`, `healthkit_adapter.dart:~271`:

```dart
      await ChecklistDiveLinker().applyForImportedDive(dive);
```

  - `dive_computer_repository_impl.dart:~933` (this site has `diveId`/`diverId` locals and the dive's entry timestamp available for the defaulter call — reuse them):

```dart
      await ChecklistDiveLinker().autoLinkForDive(
        diveId: diveId,
        diverId: diverId,
        diveStart: <the DateTime the inserted dive row uses for diveDateTime —
                    the same value the surrounding code inserted; convert with
                    DateTime.fromMillisecondsSinceEpoch if it is an epoch int>,
      );
```

  Read the 20 lines around each call site first; add the matching import lines.

- [ ] **Step 6: Analyze, spot-run an importer test file if one covers these seams**

Run: `flutter analyze` — clean.
Run: `grep -rln "applyForImportedDive" test/ | head -3` and run any file found — Expected: still PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: auto-link pre-dive sessions to imported dives"
```

---

### Task 12: Dive detail section, manual link/unlink, add-dive sheet entry

**Files:**
- Create: `lib/features/pre_dive/presentation/widgets/dive_pre_dive_section.dart`
- Modify: `lib/core/constants/dive_detail_sections.dart` (add enum value + all exhaustive switches)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_sectionBuilders` map ~:251)
- Modify: `lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/pre_dive/presentation/widgets/dive_pre_dive_section_test.dart`

**Interfaces:**
- Consumes: Task 8 providers (`preDiveSessionForDiveProvider`), Task 10 `showStartSessionSheet`, `DiveDetailSectionId` machinery.
- Produces: `DivePreDiveSection({required Dive dive})`; `DiveDetailSectionId.preDiveChecklist`.

- [ ] **Step 1: English strings:**

```json
"preDive_section_title": "Pre-Dive Check",
"preDive_section_link": "Link a checklist session",
"preDive_section_unlink": "Unlink",
"preDive_section_run": "Run pre-dive checklist",
"preDive_section_settingsName": "Pre-Dive Check",
"preDive_section_settingsDescription": "Linked pre-dive checklist session",
"diveLog_listPage_bottomSheet_preDiveChecklist": "Start pre-dive checklist",
```

- [ ] **Step 2: Enum value.** In `dive_detail_sections.dart` add `preDiveChecklist` to `DiveDetailSectionId` (before `dataSources` so it lands near the end of the default order), then satisfy every exhaustive `switch` in the file: `displayName` -> `'Pre-Dive Check'`, `description` -> `'Linked pre-dive checklist session'`, `localizedDisplayName` -> `l10n.preDive_section_settingsName`, localizedDescription -> `l10n.preDive_section_settingsDescription`, and any other switches the analyzer flags (e.g. `hiddenInGaugeMode` -> `false`). Check how stored section prefs handle enum values missing from saved settings (the decode/merge logic lives in this same file) — if it appends unknown ids automatically, nothing more to do; if not, follow whatever the most recently added id (`dataSources`) did.

- [ ] **Step 3: Section widget** `dive_pre_dive_section.dart` — `ConsumerWidget`:

```dart
// Watches preDiveSessionForDiveProvider(dive.id).
// - session != null: a Card row with Icons.fact_check, templateName,
//   completion date/time + status label, flagged badge when
//   flaggedCount > 0 (watch preDiveSessionItemsProvider(session.id)),
//   onTap -> context.push('/pre-dive-sessions/${session.id}'),
//   trailing PopupMenuButton with Unlink -> unlinkFromDive(session.id).
// - session == null && dive.isPlanned: OutlinedButton
//   l10n.preDive_section_run -> showStartSessionSheet(context, ref,
//   diveId: dive.id).
// - session == null && !dive.isPlanned: TextButton
//   l10n.preDive_section_link -> _showLinkPicker: a simple dialog listing
//   getUnlinkedSessions() (via ref.read(preDiveSessionRepositoryProvider)),
//   each tile shows templateName + startedAt date; tapping calls
//   linkToDive(session.id, dive.id) and pops.
```

Write it in full following the compact-card idiom of the section widgets already used by `dive_detail_page.dart` builders.

- [ ] **Step 4: Register the builder** in `_sectionBuilders` in `dive_detail_page.dart` (self-suppression: the section always renders — it is the affordance for linking — but stays one row tall):

```dart
      DiveDetailSectionId.preDiveChecklist: () => [
        const SizedBox(height: 24),
        DivePreDiveSection(dive: dive),
      ],
```

- [ ] **Step 5: Add-dive sheet tile** in `add_dive_bottom_sheet.dart`, after the import-from-computer tile:

```dart
            ListTile(
              leading: const Icon(Icons.fact_check),
              title: Text(
                sheetContext.l10n.diveLog_listPage_bottomSheet_preDiveChecklist,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/pre-dive-sessions');
              },
            ),
```

(Navigating to the sessions list rather than straight into the start sheet keeps the sheet function free of a `WidgetRef` dependency; the list page's FAB is one tap away.)

- [ ] **Step 6: Widget test** for the section: overrides for the three states (linked -> shows template name and Unlink menu; unlinked+planned -> shows Run button; unlinked+logged -> shows Link button). Use `testApp` with `preDiveSessionForDiveProvider('d1').overrideWith(...)`.

- [ ] **Step 7: Run tests, analyze**

Run: `flutter gen-l10n && flutter test test/features/pre_dive/presentation/widgets/dive_pre_dive_section_test.dart` — PASS.
Run: `flutter analyze` — clean (this catches any missed exhaustive switch).
Also run the dive-detail-sections settings page test if one exists: `grep -rln "DiveDetailSectionId" test/ | head -5` — run those files; fix count-based assertions that hard-code the number of sections.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive section to dive detail and add-dive sheet"
```

---

### Task 13: Dashboard card, Tools tile, Trips entry point

**Files:**
- Create: `lib/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (children column ~:36-49)
- Modify: `lib/features/tools/presentation/pages/tools_page.dart` (`_ToolCard` list)
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (next to `TripChecklistSection` usage ~:163)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/pre_dive/presentation/widgets/pre_dive_dashboard_card_test.dart`

**Interfaces:**
- Consumes: Task 8 providers, Task 10 sheet/pages.
- Produces: `PreDiveDashboardCard()`.

- [ ] **Step 1: English strings:**

```json
"preDive_dashboard_title": "Pre-Dive Check",
"preDive_dashboard_resume": "Resume - {done} of {total}",
"@preDive_dashboard_resume": {
  "placeholders": {"done": {"type": "int"}, "total": {"type": "int"}}
},
"preDive_dashboard_start": "Start pre-dive check",
"tools_preDive_title": "Pre-Dive Checklists",
"tools_preDive_subtitle": "Run and review checklist sessions",
"tools_preDive_description": "Buddy checks, CCR build lists, and gear packing with an audit trail",
"trips_detail_preDive_action": "Pre-dive checklist",
```

- [ ] **Step 2: Dashboard card.** `ConsumerWidget` styled like `quick_actions_card.dart` (Card, `margin: EdgeInsets.symmetric(vertical: 4)`, `Padding(12)`, bold `bodyMedium` title). Visibility rule (spec): hidden until the feature has been used — watch `preDiveActiveSessionProvider`, `preDiveSessionsProvider`, and `preDiveTemplatesProvider`; compute:

```dart
    final active = ref.watch(preDiveActiveSessionProvider).value;
    final sessions = ref.watch(preDiveSessionsProvider).value ?? const [];
    final templates = ref.watch(preDiveTemplatesProvider).value ?? const [];
    final hasUserTemplates = templates.any((t) => !t.isBuiltIn);
    if (active == null && sessions.isEmpty && !hasUserTemplates) {
      return const SizedBox.shrink();
    }
```

With an active session: watch `preDiveSessionItemsProvider(active.id)` and render a full-width `FilledButton` with `l10n.preDive_dashboard_resume(resolved, total)` pushing the runner. Otherwise a `FilledButton.tonal` `l10n.preDive_dashboard_start` pushing `/pre-dive-sessions`. Insert into `dashboard_page.dart` children after `const AlertsCard()`:

```dart
          const PreDiveDashboardCard(),
          const SizedBox(height: 12),
```

(Not `const` if the constructor isn't const — match what compiles.)

- [ ] **Step 3: Tools tile** in `tools_page.dart`, after the deco-calculator `_ToolCard`:

```dart
          _ToolCard(
            icon: Icons.fact_check,
            iconColor: colorScheme.primary,
            title: context.l10n.tools_preDive_title,
            subtitle: context.l10n.tools_preDive_subtitle,
            description: context.l10n.tools_preDive_description,
            onTap: () => context.push('/pre-dive-sessions'),
          ),
          const SizedBox(height: 12),
```

- [ ] **Step 4: Trips entry.** In `trip_detail_page.dart`, directly above the `TripChecklistSection(trip: ...)` usage in the liveaboard Checklist tab (and only when `trip.isUpcoming || trip.isInProgress` if such getters exist — otherwise always), add:

```dart
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fact_check),
                        label: Text(context.l10n.trips_detail_preDive_action),
                        onPressed: () =>
                            showStartSessionSheet(context, ref, tripId: trip.id),
                      ),
                    ),
                    const SizedBox(height: 12),
```

The enclosing widget must be a `ConsumerWidget`/have a `ref` — `TripDetailPage` builds via providers already; if the immediate builder lacks `ref`, wrap the button in a `Consumer`. For the non-liveaboard story layout, skip it (the Tools/dashboard/add-dive entries cover it; YAGNI).

- [ ] **Step 5: Dashboard card test.** Overrides: (a) all-empty -> expects `find.byType(PreDiveDashboardCard)` renders `SizedBox.shrink` (assert `find.text('Start pre-dive check')` is nothing); (b) active session with 3 items 1 resolved -> "Resume - 1 of 3"; (c) no active but one historical session -> Start button.

- [ ] **Step 6: Run tests, analyze**

Run: `flutter gen-l10n && flutter test test/features/pre_dive/presentation/widgets/pre_dive_dashboard_card_test.dart` — PASS.
Run: `flutter analyze` — clean. Also rerun any existing dashboard page test (`ls test/features/dashboard/`) — fix breakage from the inserted card by adding provider overrides for the three pre-dive providers.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: add pre-dive entry points to dashboard, tools, and trips"
```

---

### Task 14: Localization sweep and final verification

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: every `preDive_*`, `settings_manage_preDiveChecklists*`, `tools_preDive_*`, `trips_detail_preDive_action`, `diveLog_listPage_bottomSheet_preDiveChecklist` key added in Tasks 8-13.
- Produces: all 11 arb files in sync; `flutter gen-l10n` emits no untranslated-message warnings for these keys.

- [ ] **Step 1: Enumerate the new keys**

Run: `grep -o '"preDive[^"]*"\|"settings_manage_preDive[^"]*"\|"tools_preDive[^"]*"\|"trips_detail_preDive[^"]*"\|"diveLog_listPage_bottomSheet_preDiveChecklist"' lib/l10n/arb/app_en.arb | sort -u`
Expected: the full key list from Tasks 8-13.

- [ ] **Step 2: Translate every key into all 10 locale files.** Native-quality translations, preserving placeholder syntax (`{done}`, `{total}`, `{count}`, `{time}`) exactly and copying each `@key` metadata block unchanged. Keep diving terms conventional per language (e.g. German "Tarierweste" for BCD; Spanish "chaleco"; French "gilet stabilisateur"). Insert keys in the same relative position as in `app_en.arb`.

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: no "untranslated messages" warnings mentioning preDive keys.
Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS (all 11 locales load).

- [ ] **Step 4: Full-feature test pass (per-file, not the whole suite)**

```bash
flutter test test/core/database/migration_v113_pre_dive_test.dart
flutter test test/core/database/pre_dive_builtin_seed_test.dart
flutter test test/core/services/sync/sync_pre_dive_test.dart
flutter test test/features/pre_dive/   # directory is small enough to run whole
```

Expected: all PASS.

- [ ] **Step 5: Analyze + format**

Run: `flutter analyze` — zero issues.
Run: `dart format .` — no changes.

- [ ] **Step 6: Manual smoke checklist** (record results; `flutter run -d macos` — check no other `flutter run -d macos` session is active first):

1. Settings -> Pre-Dive Checklists: four built-ins listed with lock badges; clone BWRAF; edit the clone; add a value item.
2. Tools -> Pre-Dive Checklists -> Start: pick CCR Build; strict order enforced (third item inert until second done); enter a cell mV out of range -> amber; flag an item with a note; Complete -> flagged confirmation -> locked read-only view.
3. Gear Packing with an equipment set: gear rows expand; an overdue-service item starts flagged.
4. Dive detail on a logged dive: Link a checklist session -> pick the completed run -> section shows it; Unlink works.
5. Dashboard shows Resume while a run is in progress; kill the app mid-run; relaunch -> Resume restores every tapped state.

- [ ] **Step 7: Final commit**

```bash
dart format .
git add -A
git commit -m "feat: localize pre-dive checklist strings across all locales"
```

---

## Post-plan notes for the executor

- **Schema version collisions:** if `currentSchemaVersion` is no longer 112 when you start, take the next free number and update: the constant, `migrationVersions`, the `onUpgrade` guard, both tests in Task 1, and the tripwire expectations.
- **Do not run the full test suite in one command** — it times out. Per-file only, plus the final `test/features/pre_dive/` directory which is all new and small.
- **Pre-push hooks** run `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test` from the MAIN working tree — format the whole repo before every commit and keep analyze clean as you go.
- The spec (`docs/superpowers/specs/2026-07-16-pre-dive-checklist-design.md`) is the tiebreaker for any behavioral question this plan leaves open.
