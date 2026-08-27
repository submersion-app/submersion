# Gear Service Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single per-item service clock with N concurrent service clocks (date / dive-count / hours triggers, whichever comes first) driven by a built-in + custom service-kind catalog, surfaced on gear detail, gear list, dashboard, trip banners, and local notifications.

**Architecture:** Two new synced Drift tables (`service_kinds` catalog, `service_schedules` clocks) plus a nullable `service_kind_id` on `service_records`. Next-due is always computed by a pure `ServiceDueEngine` from the newest service record of a kind (with anchor-date fallbacks) — never stored. Riverpod providers feed four UI surfaces and the extended notification scheduler.

**Tech Stack:** Flutter 3.x, Drift ORM (schema v112 → v113), Riverpod, go_router, flutter_local_notifications, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-16-gear-service-ledger-design.md`

## Global Constraints

- Worktree: all paths relative to `.claude/worktrees/gear-service-ledger`. Run all commands from the worktree root.
- Schema version goes 112 → 113. Exactly one new migration block; idempotent `_assert…` helper called from BOTH `onUpgrade` and `beforeOpen` (parallel-branch self-heal pattern).
- Raw-SQL indexes never exist on fresh installs unless asserted from `beforeOpen`/helper — `onCreate` only runs `m.createAll()`. Put new indexes in the `_assert…` helper.
- Enums serialize to DB as `.name` (Dart identifier); decode via `values.firstWhere((e) => e.name == v, orElse: …)`.
- Timestamps are `millisecondsSinceEpoch` ints. Dive duration = `COALESCE(runtime, bottom_time)` in SECONDS.
- Every synced-table mutation: `markRecordPending` (create/update) or `logDeletion` (delete) + `SyncEventBus.notifyLocalChange()`. Cascade-deleted synced children need explicit per-row tombstones inside the same transaction.
- Sync entity keys: `serviceKinds`, `serviceSchedules` (camelCase, match `_baseTables` keys everywhere).
- Built-in service kinds: `isBuiltIn = true`, `hlc` NULL, stable slug ids, seeded in `onCreate` + v113 block + `beforeOpen` (INSERT OR IGNORE), skipped by the sync exporter, undeletable through the repository.
- No emojis anywhere. `dart format .` must be clean before every commit. New user-facing strings go into `lib/l10n/arb/app_en.arb` AND all 10 locale files (`ar, de, es, fr, he, hu, it, nl, pt, zh`), referenced as `context.l10n.<key>`.
- After editing `database.dart`: `dart run build_runner build --delete-conflicting-outputs`. After editing arb files: `flutter gen-l10n`.
- Run tests per-file (`flutter test <file> -r expanded`), never the whole suite mid-task.
- Commit after each task; message style `feat(equipment): …` / `test: …`; no Co-Authored-By lines, no session URLs.
- Routes use `/equipment/...` prefix (NOT `/gear`).

---

### Task 1: Schema v113 — tables, columns, migration, seeds, backfill

**Files:**
- Modify: `lib/core/constants/enums.dart` (EquipmentType ~line 4)
- Modify: `lib/core/database/database.dart` (tables near `EquipmentSetGeofences` ~841; `@DriftDatabase` list ~2117; `currentSchemaVersion`/`migrationVersions` ~2208; `onCreate` ~2686; `onUpgrade` tail ~5545; `beforeOpen` ~5547; `_assert…` helpers ~2418; seed constants ~1582)
- Modify: `test/core/database/equipment_set_geofence_schema_test.dart` (version tripwire)
- Test: `test/core/database/migration_v113_service_ledger_test.dart` (create)
- Test: `test/core/database/service_ledger_schema_test.dart` (create)

**Interfaces:**
- Consumes: existing `Equipment`, `ServiceRecords`, `ScheduledNotifications`, `Divers` tables.
- Produces: Drift tables `ServiceKinds` (data class `ServiceKindRow`), `ServiceSchedules` (data class `ServiceScheduleRow`); columns `service_records.service_kind_id TEXT`, `scheduled_notifications.schedule_id TEXT`, `diver_settings.trip_service_lead_days INTEGER NOT NULL DEFAULT 14`; enum value `EquipmentType.transmitter`; built-in kind ids `hydro`, `vip`, `o2-clean`, `regulator-service`, `computer-battery`, `transmitter-battery`, `bcd-inspection`, `drysuit-seals`, `general-service`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/core/database/migration_v113_service_ledger_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal v112 database: only the tables the v113 step reads or alters.
NativeDatabase _dbAt112() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 112');
      rawDb.execute('''
        CREATE TABLE equipment (
          id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
          type TEXT NOT NULL, brand TEXT, model TEXT, serial_number TEXT,
          size TEXT, thickness TEXT, buoyancy_kg REAL, weight_kg REAL,
          status TEXT NOT NULL DEFAULT 'active', purchase_date INTEGER,
          purchase_price REAL, purchase_currency TEXT NOT NULL DEFAULT 'USD',
          last_service_date INTEGER, service_interval_days INTEGER,
          notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
          custom_reminder_enabled INTEGER, custom_reminder_days TEXT,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE service_records (
          id TEXT NOT NULL PRIMARY KEY, equipment_id TEXT NOT NULL,
          service_type TEXT NOT NULL, service_date INTEGER NOT NULL,
          provider TEXT, cost REAL, currency TEXT NOT NULL DEFAULT 'USD',
          next_service_due INTEGER, notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE scheduled_notifications (
          id TEXT NOT NULL PRIMARY KEY, equipment_id TEXT NOT NULL,
          scheduled_date INTEGER NOT NULL, reminder_days_before INTEGER NOT NULL,
          notification_id INTEGER NOT NULL, created_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY, diver_id TEXT NOT NULL,
          notifications_enabled INTEGER NOT NULL DEFAULT 1,
          service_reminder_days TEXT NOT NULL DEFAULT '[7, 14, 30]',
          reminder_time TEXT NOT NULL DEFAULT '09:00'
        )
      ''');
      rawDb.execute(
        "INSERT INTO equipment (id, name, type, service_interval_days, "
        "last_service_date, created_at, updated_at) VALUES "
        "('e-reg', 'Apeks XTX50', 'regulator', 365, 1700000000000, 1, 1)",
      );
      rawDb.execute(
        "INSERT INTO equipment (id, name, type, created_at, updated_at) "
        "VALUES ('e-tank', 'AL80', 'tank', 1, 1)",
      );
    },
  );
}

void main() {
  test('v113 creates ledger tables, seeds kinds, backfills legacy', () async {
    final db = AppDatabase(_dbAt112());
    addTearDown(() => db.close());

    final kindCols = await db
        .customSelect("PRAGMA table_info('service_kinds')")
        .get();
    expect(kindCols, isNotEmpty);
    final schedCols = await db
        .customSelect("PRAGMA table_info('service_schedules')")
        .get();
    expect(schedCols, isNotEmpty);

    final kinds = await db
        .customSelect('SELECT id, is_built_in FROM service_kinds ORDER BY id')
        .get();
    expect(
      kinds.map((r) => r.data['id']),
      containsAll([
        'hydro', 'vip', 'o2-clean', 'regulator-service', 'computer-battery',
        'transmitter-battery', 'bcd-inspection', 'drysuit-seals',
        'general-service',
      ]),
    );
    expect(kinds.every((r) => r.data['is_built_in'] == 1), isTrue);

    // Legacy backfill: e-reg had an interval -> one general-service schedule
    // with deterministic id; e-tank had none -> no schedule.
    final scheds = await db
        .customSelect('SELECT * FROM service_schedules')
        .get();
    expect(scheds, hasLength(1));
    expect(scheds.first.data['id'], 'legacy-svc-e-reg');
    expect(scheds.first.data['equipment_id'], 'e-reg');
    expect(scheds.first.data['service_kind_id'], 'general-service');
    expect(scheds.first.data['interval_days'], 365);
    expect(scheds.first.data['anchor_date'], 1700000000000);

    final srCols = await db
        .customSelect("PRAGMA table_info('service_records')")
        .get();
    expect(srCols.map((c) => c.read<String>('name')),
        contains('service_kind_id'));
    final snCols = await db
        .customSelect("PRAGMA table_info('scheduled_notifications')")
        .get();
    expect(snCols.map((c) => c.read<String>('name')), contains('schedule_id'));
    final dsCols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    expect(dsCols.map((c) => c.read<String>('name')),
        contains('trip_service_lead_days'));
  });

  test('v113 backfill is idempotent (re-running assert does not duplicate)',
      () async {
    final db = AppDatabase(_dbAt112());
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get(); // force open
    final scheds = await db
        .customSelect('SELECT COUNT(*) AS c FROM service_schedules')
        .getSingle();
    expect(scheds.data['c'], 1);
  });

  test('version ladder includes 113', () {
    expect(AppDatabase.currentSchemaVersion, 113);
    expect(AppDatabase.migrationVersions, contains(113));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_v113_service_ledger_test.dart -r expanded`
Expected: FAIL (`service_kinds` table missing; version is 112).

- [ ] **Step 3: Add the enum value**

In `lib/core/constants/enums.dart`, inside `EquipmentType` after `computer('Dive Computer'),`:

```dart
  transmitter('Transmitter'),
```

- [ ] **Step 4: Add Drift tables and columns**

In `lib/core/database/database.dart`, immediately after the `EquipmentSetGeofences` class (~line 841):

```dart
/// Catalog of service kinds (hydro, VIP, regulator service, ...).
/// Built-ins are reference data: seeded on create/upgrade/open, skipped by
/// sync export, undeletable through the repository. Custom kinds sync.
@DataClassName('ServiceKindRow')
class ServiceKinds extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// JSON array of EquipmentType names this kind suggests for, e.g. '["tank"]'.
  TextColumn get applicableTypes =>
      text().withDefault(const Constant('[]'))();
  IntColumn get defaultIntervalDays => integer().nullable()();
  IntColumn get defaultIntervalDives => integer().nullable()();
  RealColumn get defaultIntervalHours => real().nullable()();

  /// Auto-create a schedule when matching equipment is created.
  BoolColumn get autoAttach => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One service clock per (equipment item, service kind). Next-due is always
/// computed from the newest ServiceRecord of the kind (anchorDate/purchase
/// fallbacks) -- never stored, so dive logging does not churn sync rows.
@DataClassName('ServiceScheduleRow')
class ServiceSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceKindId =>
      text().references(ServiceKinds, #id, onDelete: KeyAction.cascade)();

  /// Per-item overrides; null = inherit the kind's default interval.
  IntColumn get intervalDays => integer().nullable()();
  IntColumn get intervalDives => integer().nullable()();
  RealColumn get intervalHours => real().nullable()();

  /// Baseline when no ServiceRecord of this kind exists yet (e.g. last hydro
  /// before app adoption). Fallback chain: purchaseDate, then createdAt.
  IntColumn get anchorDate => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `ServiceRecords` after `nextServiceDue` (~line 1445):

```dart
  /// v113: which service kind this record fulfills (resets that clock).
  /// Plain text (no FK) so records survive custom-kind deletion.
  TextColumn get serviceKindId => text().nullable()();
```

Add to `ScheduledNotifications` after `equipmentId` (~line 2054):

```dart
  /// v113: the service schedule this reminder belongs to (null = legacy
  /// single-clock reminder). Local-only table, not synced.
  TextColumn get scheduleId => text().nullable()();
```

Add to `DiverSettings` after `reminderTime` (~line 1298):

```dart
  // v113: days before a trip to nag about gear due before trip end.
  IntColumn get tripServiceLeadDays =>
      integer().withDefault(const Constant(14))();
```

Register both new tables in the `@DriftDatabase(tables: [...])` list (~line 2117), after `ConnectedAccounts`:

```dart
    ServiceKinds,
    ServiceSchedules,
```

- [ ] **Step 5: Seed constant, assert helper, migration block, beforeOpen backstop**

Near `kSeedBuiltInDiveTypesSql` (~line 1582) add:

```dart
/// Built-in service kinds: identical on every device, stable slug ids
/// (service_schedules.service_kind_id references them), INSERT OR IGNORE
/// so re-running is a no-op. Intervals per tech-diving convention.
const String kSeedBuiltInServiceKindsSql = '''
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     is_built_in, created_at, updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, NULL, t.auto, 1,
         n.now_ms, n.now_ms
  FROM (
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, 1 AS auto
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, 1
    UNION ALL SELECT 'o2-clean', 'O2 clean', '["tank"]', 365, NULL, 0
    UNION ALL SELECT 'regulator-service', 'Regulator service',
           '["regulator"]', 365, 100, 1
    UNION ALL SELECT 'computer-battery', 'Computer battery', '["computer"]',
           730, NULL, 1
    UNION ALL SELECT 'transmitter-battery', 'Transmitter battery',
           '["transmitter"]', 365, NULL, 1
    UNION ALL SELECT 'bcd-inspection', 'BCD/wing inspection', '["bcd"]',
           365, NULL, 1
    UNION ALL SELECT 'drysuit-seals', 'Drysuit seals', '["drysuit"]',
           730, NULL, 0
    UNION ALL SELECT 'general-service', 'General service', '[]',
           NULL, NULL, 0
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
```

Next to `_assertEquipmentThicknessColumn` (~line 2410) add the idempotent helper (schema + seeds + backfill are all INSERT OR IGNORE / PRAGMA-guarded, so it is safe from both onUpgrade and beforeOpen — including the backfill, whose deterministic ids make INSERT OR IGNORE a no-op on re-run and identical across devices, avoiding sync duplicates):

```dart
  /// v113: service ledger -- service_kinds + service_schedules tables,
  /// service_records.service_kind_id, scheduled_notifications.schedule_id,
  /// diver_settings.trip_service_lead_days, built-in kind seed, and the
  /// legacy single-clock backfill. Idempotent; called from onUpgrade AND
  /// the beforeOpen backstop (parallel-branch collision self-heal).
  Future<void> _assertServiceLedgerSchema() async {
    await createMigrator().createTable(serviceKinds);
    await createMigrator().createTable(serviceSchedules);

    final srCols = await customSelect(
      "PRAGMA table_info('service_records')",
    ).get();
    if (srCols.isNotEmpty &&
        !srCols.any((c) => c.read<String>('name') == 'service_kind_id')) {
      await customStatement(
        'ALTER TABLE service_records ADD COLUMN service_kind_id TEXT',
      );
    }

    final snCols = await customSelect(
      "PRAGMA table_info('scheduled_notifications')",
    ).get();
    if (snCols.isNotEmpty &&
        !snCols.any((c) => c.read<String>('name') == 'schedule_id')) {
      await customStatement(
        'ALTER TABLE scheduled_notifications ADD COLUMN schedule_id TEXT',
      );
    }

    final dsCols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (dsCols.isNotEmpty &&
        !dsCols.any(
          (c) => c.read<String>('name') == 'trip_service_lead_days',
        )) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN trip_service_lead_days '
        'INTEGER NOT NULL DEFAULT 14',
      );
    }

    // Indexes: onCreate's createAll() never builds raw-SQL indexes, so they
    // must be asserted here to exist on fresh installs too.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_schedules_equipment '
      'ON service_schedules(equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_records_kind '
      'ON service_records(equipment_id, service_kind_id)',
    );

    await customStatement(kSeedBuiltInServiceKindsSql);

    // Legacy single-clock backfill: items with a legacy interval get one
    // "General service" schedule. Deterministic id ('legacy-svc-' || id)
    // makes this idempotent and cross-device collision-free.
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1,
             n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
    ''');
  }
```

In `onUpgrade`, after the `if (from < 112) await reportProgress();` line (~5545):

```dart
        if (from < 113) {
          await _assertServiceLedgerSchema();
        }
        if (from < 113) await reportProgress();
```

In `beforeOpen`, after the v112 backstop call:

```dart
        // v113 backstop: re-assert service ledger schema + built-in kinds.
        await _assertServiceLedgerSchema();
```

In `onCreate`, after `await customStatement(kSeedBuiltInDiveRolesSql);`:

```dart
        // Seed built-in service kinds (v113 migration backfills these for
        // upgraded databases; beforeOpen re-asserts).
        await customStatement(kSeedBuiltInServiceKindsSql);
```

Bump the version and ladder (~2208):

```dart
  static const int currentSchemaVersion = 113;
```

Append `113,` to `migrationVersions`.

Update the tripwire in `test/core/database/equipment_set_geofence_schema_test.dart`:

```dart
  test('v113 is the current schema version (exact-latest tripwire)', () {
    expect(AppDatabase.currentSchemaVersion, 113);
    expect(AppDatabase.migrationVersions, contains(113));
  });
```

- [ ] **Step 6: Codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, regenerates `database.g.dart` with `ServiceKindRow`, `ServiceScheduleRow`, companions.

- [ ] **Step 7: Write the fresh-install typed-API test**

```dart
// test/core/database/service_ledger_schema_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('built-in kinds are seeded on fresh install', () async {
    final kinds = await db.select(db.serviceKinds).get();
    expect(kinds.length, 9);
    expect(kinds.every((k) => k.isBuiltIn), isTrue);
    final hydro = kinds.firstWhere((k) => k.id == 'hydro');
    expect(hydro.defaultIntervalDays, 1825);
    expect(hydro.autoAttach, isTrue);
    final reg = kinds.firstWhere((k) => k.id == 'regulator-service');
    expect(reg.defaultIntervalDives, 100);
  });

  test('service_schedules round-trips and cascades on equipment delete',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: 'e1',
            name: 'AL80',
            type: 'tank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.serviceSchedules).insert(
          ServiceSchedulesCompanion.insert(
            id: 's1',
            equipmentId: 'e1',
            serviceKindId: 'hydro',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final rows = await db.select(db.serviceSchedules).get();
    expect(rows, hasLength(1));
    expect(rows.first.enabled, isTrue); // default
    expect(rows.first.intervalDays, isNull); // inherit kind default

    await (db.delete(db.equipment)..where((t) => t.id.equals('e1'))).go();
    expect(await db.select(db.serviceSchedules).get(), isEmpty); // cascade
  });

  test('fresh install has the service ledger indexes', () async {
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name LIKE 'idx_service_%'",
        )
        .get();
    expect(
      idx.map((r) => r.data['name']),
      containsAll(
        ['idx_service_schedules_equipment', 'idx_service_records_kind'],
      ),
    );
  });
}
```

- [ ] **Step 8: Run both tests**

Run: `flutter test test/core/database/migration_v113_service_ledger_test.dart test/core/database/service_ledger_schema_test.dart test/core/database/equipment_set_geofence_schema_test.dart -r expanded`
Expected: ALL PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): schema v113 service ledger tables, seeds, backfill"
```

---

### Task 2: Domain entities

**Files:**
- Create: `lib/features/equipment/domain/entities/service_kind.dart`
- Create: `lib/features/equipment/domain/entities/service_schedule.dart`
- Create: `lib/features/equipment/domain/entities/service_clock_status.dart`
- Modify: `lib/features/equipment/domain/entities/service_record.dart` (add `serviceKindId`)
- Test: `test/features/equipment/domain/entities/service_ledger_entities_test.dart`

**Interfaces:**
- Produces:
  - `class ServiceKind extends Equatable` — fields `String id`, `String? diverId`, `String name`, `List<EquipmentType> applicableTypes`, `int? defaultIntervalDays`, `int? defaultIntervalDives`, `double? defaultIntervalHours`, `bool autoAttach`, `bool isBuiltIn`, `DateTime createdAt`, `DateTime updatedAt`; `copyWith`; `bool appliesTo(EquipmentType type)` (true when list empty or contains type).
  - `class ServiceSchedule extends Equatable` — fields `String id`, `String equipmentId`, `String serviceKindId`, `int? intervalDays`, `int? intervalDives`, `double? intervalHours`, `DateTime? anchorDate`, `bool enabled`, `DateTime createdAt`, `DateTime updatedAt`; `copyWith`.
  - `enum ServiceClockSeverity { ok, dueSoon, overdue }`
  - `class ServiceClockStatus extends Equatable` — fields `ServiceSchedule schedule`, `ServiceKind kind`, `DateTime anchor`, `DateTime? dueDate`, `int? divesSinceAnchor`, `int? divesRemaining`, `double? hoursSinceAnchor`, `double? hoursRemaining`, `ServiceClockSeverity severity`; getter `int? daysUntilDue` (null when no dueDate; negative when past).
  - `class DiveUsageSample` — `DateTime date`, `int durationSeconds` (defined in `service_clock_status.dart`).
  - `ServiceRecord` gains `final String? serviceKindId;` (constructor param, `copyWith`, `props`).

- [ ] **Step 1: Write failing entity tests**

```dart
// test/features/equipment/domain/entities/service_ledger_entities_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind({List<EquipmentType> types = const [EquipmentType.tank]}) =>
      ServiceKind(
        id: 'hydro',
        name: 'Hydrostatic test',
        applicableTypes: types,
        defaultIntervalDays: 1825,
        autoAttach: true,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      );

  test('appliesTo matches listed types; empty list matches all', () {
    expect(kind().appliesTo(EquipmentType.tank), isTrue);
    expect(kind().appliesTo(EquipmentType.regulator), isFalse);
    expect(kind(types: const []).appliesTo(EquipmentType.fins), isTrue);
  });

  test('copyWith preserves unset fields', () {
    final s = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      enabled: true,
      createdAt: t0,
      updatedAt: t0,
    );
    final s2 = s.copyWith(intervalDays: 365);
    expect(s2.intervalDays, 365);
    expect(s2.equipmentId, 'e1');
    expect(s.intervalDays, isNull); // immutability
  });

  test('ServiceClockStatus.daysUntilDue is negative when overdue', () {
    final status = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1', equipmentId: 'e1', serviceKindId: 'hydro',
        enabled: true, createdAt: t0, updatedAt: t0,
      ),
      kind: kind(),
      anchor: t0,
      dueDate: DateTime(2026, 1, 10),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 1, 15),
    );
    expect(status.daysUntilDue, -5);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/domain/entities/service_ledger_entities_test.dart -r expanded`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement the entities**

```dart
// lib/features/equipment/domain/entities/service_kind.dart
import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// A type of maintenance a piece of equipment can need (hydro, VIP, ...).
class ServiceKind extends Equatable {
  final String id;
  final String? diverId; // null = built-in / shared
  final String name;

  /// Equipment types this kind suggests for; empty = applies to any type.
  final List<EquipmentType> applicableTypes;
  final int? defaultIntervalDays;
  final int? defaultIntervalDives;
  final double? defaultIntervalHours;
  final bool autoAttach;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceKind({
    required this.id,
    this.diverId,
    required this.name,
    this.applicableTypes = const [],
    this.defaultIntervalDays,
    this.defaultIntervalDives,
    this.defaultIntervalHours,
    this.autoAttach = false,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool appliesTo(EquipmentType type) =>
      applicableTypes.isEmpty || applicableTypes.contains(type);

  ServiceKind copyWith({
    String? id,
    String? diverId,
    String? name,
    List<EquipmentType>? applicableTypes,
    int? defaultIntervalDays,
    int? defaultIntervalDives,
    double? defaultIntervalHours,
    bool? autoAttach,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceKind(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      applicableTypes: applicableTypes ?? this.applicableTypes,
      defaultIntervalDays: defaultIntervalDays ?? this.defaultIntervalDays,
      defaultIntervalDives: defaultIntervalDives ?? this.defaultIntervalDives,
      defaultIntervalHours:
          defaultIntervalHours ?? this.defaultIntervalHours,
      autoAttach: autoAttach ?? this.autoAttach,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, diverId, name, applicableTypes, defaultIntervalDays,
        defaultIntervalDives, defaultIntervalHours, autoAttach, isBuiltIn,
        createdAt, updatedAt,
      ];
}
```

```dart
// lib/features/equipment/domain/entities/service_schedule.dart
import 'package:equatable/equatable.dart';

/// One service clock on one equipment item. Null intervals inherit the
/// kind's defaults; a clock with all three intervals null never fires.
class ServiceSchedule extends Equatable {
  final String id;
  final String equipmentId;
  final String serviceKindId;
  final int? intervalDays;
  final int? intervalDives;
  final double? intervalHours;
  final DateTime? anchorDate;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceSchedule({
    required this.id,
    required this.equipmentId,
    required this.serviceKindId,
    this.intervalDays,
    this.intervalDives,
    this.intervalHours,
    this.anchorDate,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ServiceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? serviceKindId,
    int? intervalDays,
    int? intervalDives,
    double? intervalHours,
    DateTime? anchorDate,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      serviceKindId: serviceKindId ?? this.serviceKindId,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalDives: intervalDives ?? this.intervalDives,
      intervalHours: intervalHours ?? this.intervalHours,
      anchorDate: anchorDate ?? this.anchorDate,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, equipmentId, serviceKindId, intervalDays, intervalDives,
        intervalHours, anchorDate, enabled, createdAt, updatedAt,
      ];
}
```

```dart
// lib/features/equipment/domain/entities/service_clock_status.dart
import 'package:equatable/equatable.dart';

import 'service_kind.dart';
import 'service_schedule.dart';

enum ServiceClockSeverity { ok, dueSoon, overdue }

/// A dive's contribution to usage-based clocks.
class DiveUsageSample {
  final DateTime date;
  final int durationSeconds;

  const DiveUsageSample({required this.date, required this.durationSeconds});
}

/// The evaluated state of one service clock at a point in time.
class ServiceClockStatus extends Equatable {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final DateTime anchor;
  final DateTime? dueDate;
  final int? divesSinceAnchor;
  final int? divesRemaining;
  final double? hoursSinceAnchor;
  final double? hoursRemaining;
  final ServiceClockSeverity severity;
  final DateTime now;

  const ServiceClockStatus({
    required this.schedule,
    required this.kind,
    required this.anchor,
    this.dueDate,
    this.divesSinceAnchor,
    this.divesRemaining,
    this.hoursSinceAnchor,
    this.hoursRemaining,
    required this.severity,
    required this.now,
  });

  /// Days until the date trigger fires; negative when past, null when the
  /// clock has no date trigger.
  int? get daysUntilDue => dueDate?.difference(now).inDays;

  @override
  List<Object?> get props => [
        schedule, kind, anchor, dueDate, divesSinceAnchor, divesRemaining,
        hoursSinceAnchor, hoursRemaining, severity, now,
      ];
}
```

In `lib/features/equipment/domain/entities/service_record.dart`: add `final String? serviceKindId;` after `serviceType`, add `this.serviceKindId,` to the constructor, thread it through `copyWith` and `props`, and keep `ServiceRecord.empty()` passing null.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/equipment/domain/entities/service_ledger_entities_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): service ledger domain entities"
```

---

### Task 3: ServiceDueEngine (pure domain service)

**Files:**
- Create: `lib/features/equipment/domain/services/service_due_engine.dart`
- Test: `test/features/equipment/domain/services/service_due_engine_test.dart`

**Interfaces:**
- Consumes: Task 2 entities; `ServiceRecord.serviceKindId`; `EquipmentItem.purchaseDate`.
- Produces:

```dart
class ServiceDueEngine {
  const ServiceDueEngine();

  List<ServiceClockStatus> evaluate({
    required List<ServiceSchedule> schedules,
    required Map<String, ServiceKind> kindsById,
    required List<ServiceRecord> records,
    required List<DiveUsageSample> usage,
    DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
    required int dueSoonWindowDays,
    required DateTime now,
  });
}
```

Results sorted overdue-first, then by soonest due date. Anchor rule: newest `ServiceRecord` whose `serviceKindId == schedule.serviceKindId`, else `schedule.anchorDate`, else `purchaseDate`, else `equipmentCreatedAt`. Severity rule: `overdue` when the date trigger has passed OR `divesRemaining <= 0` OR `hoursRemaining <= 0`; `dueSoon` when `dueDate` within `dueSoonWindowDays`, or a usage trigger has 10% or less of its interval remaining (`(interval * 0.1).ceil()` dives; `interval * 0.1` hours); else `ok`. Disabled schedules and schedules whose resolved intervals are all null are skipped; schedules whose kind is missing from `kindsById` are skipped.

- [ ] **Step 1: Write the failing engine tests**

```dart
// test/features/equipment/domain/services/service_due_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';

void main() {
  const engine = ServiceDueEngine();
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 16);

  ServiceKind hydro() => ServiceKind(
        id: 'hydro', name: 'Hydro', defaultIntervalDays: 1825,
        applicableTypes: const [EquipmentType.tank],
        isBuiltIn: true, createdAt: t0, updatedAt: t0,
      );
  ServiceKind regService() => ServiceKind(
        id: 'regulator-service', name: 'Reg service',
        defaultIntervalDays: 365, defaultIntervalDives: 100,
        applicableTypes: const [EquipmentType.regulator],
        isBuiltIn: true, createdAt: t0, updatedAt: t0,
      );
  ServiceSchedule sched(String kindId,
          {int? days, int? dives, double? hours, DateTime? anchor,
          bool enabled = true}) =>
      ServiceSchedule(
        id: 's-$kindId', equipmentId: 'e1', serviceKindId: kindId,
        intervalDays: days, intervalDives: dives, intervalHours: hours,
        anchorDate: anchor, enabled: enabled, createdAt: t0, updatedAt: t0,
      );
  ServiceRecord record(String kindId, DateTime date) => ServiceRecord(
        id: 'r-$kindId', equipmentId: 'e1', serviceType: ServiceType.other,
        serviceKindId: kindId, serviceDate: date,
        createdAt: date, updatedAt: date,
      );

  List<ServiceClockStatus> run({
    required List<ServiceSchedule> schedules,
    List<ServiceKind> kinds = const [],
    List<ServiceRecord> records = const [],
    List<DiveUsageSample> usage = const [],
    DateTime? purchaseDate,
  }) =>
      engine.evaluate(
        schedules: schedules,
        kindsById: {for (final k in kinds) k.id: k},
        records: records,
        usage: usage,
        purchaseDate: purchaseDate,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: now,
      );

  test('date trigger: anchor from newest matching record', () {
    final statuses = run(
      schedules: [sched('hydro')],
      kinds: [hydro()],
      records: [
        record('hydro', DateTime(2022, 6, 1)),
        record('hydro', DateTime(2024, 6, 1)), // newest wins
      ],
    );
    expect(statuses.single.anchor, DateTime(2024, 6, 1));
    expect(statuses.single.dueDate,
        DateTime(2024, 6, 1).add(const Duration(days: 1825)));
    expect(statuses.single.severity, ServiceClockSeverity.ok);
  });

  test('anchor fallback chain: anchorDate, purchaseDate, createdAt', () {
    expect(
      run(schedules: [sched('hydro', anchor: DateTime(2023, 3, 1))],
          kinds: [hydro()]).single.anchor,
      DateTime(2023, 3, 1),
    );
    expect(
      run(schedules: [sched('hydro')], kinds: [hydro()],
          purchaseDate: DateTime(2024, 2, 2)).single.anchor,
      DateTime(2024, 2, 2),
    );
    expect(run(schedules: [sched('hydro')], kinds: [hydro()]).single.anchor,
        t0);
  });

  test('overdue when date trigger passed', () {
    final statuses = run(
      schedules: [sched('hydro', anchor: DateTime(2021, 1, 1))],
      kinds: [hydro()],
    );
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
    expect(statuses.single.daysUntilDue, isNegative);
  });

  test('dueSoon when date within window', () {
    // due = anchor + 1825d; pick anchor so due lands 20 days from now.
    final anchor = now.add(const Duration(days: 20 - 1825));
    final statuses =
        run(schedules: [sched('hydro', anchor: anchor)], kinds: [hydro()]);
    expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('whichever comes first: dive trigger overdue beats healthy date', () {
    final usage = List.generate(
      100,
      (i) => DiveUsageSample(
        date: DateTime(2026, 1, 1).add(Duration(days: i)),
        durationSeconds: 3600,
      ),
    );
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2025, 12, 1))],
      kinds: [regService()],
      usage: usage,
    );
    // Date due is 2026-11-30 (fine) but 100 of 100 dives are used up.
    expect(statuses.single.divesSinceAnchor, 100);
    expect(statuses.single.divesRemaining, 0);
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
  });

  test('usage dueSoon at 10 percent remaining', () {
    final usage = List.generate(
      91,
      (i) => DiveUsageSample(
        date: DateTime(2026, 1, 1).add(Duration(hours: i)),
        durationSeconds: 3600,
      ),
    );
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2025, 12, 1))],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.divesRemaining, 9);
    expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('hours trigger', () {
    final usage = [
      DiveUsageSample(date: DateTime(2026, 2, 1), durationSeconds: 7200),
      DiveUsageSample(date: DateTime(2026, 3, 1), durationSeconds: 5400),
    ];
    final statuses = run(
      schedules: [
        sched('regulator-service',
            hours: 3.0, anchor: DateTime(2026, 1, 1)),
      ],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.hoursSinceAnchor, closeTo(3.5, 0.001));
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
  });

  test('usage before anchor does not count', () {
    final usage = [
      DiveUsageSample(date: DateTime(2025, 1, 1), durationSeconds: 3600),
      DiveUsageSample(date: DateTime(2026, 2, 1), durationSeconds: 3600),
    ];
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2026, 1, 1))],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.divesSinceAnchor, 1);
  });

  test('disabled, missing-kind, and no-trigger schedules are skipped', () {
    final noTriggerKind = ServiceKind(
      id: 'general-service', name: 'General service',
      isBuiltIn: true, createdAt: t0, updatedAt: t0,
    );
    final statuses = run(
      schedules: [
        sched('hydro', enabled: false),
        sched('unknown-kind'),
        sched('general-service'),
      ],
      kinds: [hydro(), noTriggerKind],
    );
    expect(statuses, isEmpty);
  });

  test('sorted overdue first, then soonest due date', () {
    final statuses = run(
      schedules: [
        sched('hydro', anchor: now.subtract(const Duration(days: 1800))),
        sched('regulator-service', anchor: DateTime(2020, 1, 1)),
      ],
      kinds: [hydro(), regService()],
    );
    expect(statuses.first.kind.id, 'regulator-service'); // overdue
    expect(statuses.first.severity, ServiceClockSeverity.overdue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/domain/services/service_due_engine_test.dart -r expanded`
Expected: FAIL (engine file missing).

- [ ] **Step 3: Implement the engine**

```dart
// lib/features/equipment/domain/services/service_due_engine.dart
import '../entities/service_clock_status.dart';
import '../entities/service_kind.dart';
import '../entities/service_record.dart';
import '../entities/service_schedule.dart';

/// Evaluates an equipment item's service clocks. Pure: no database, no
/// DateTime.now() -- callers supply `now` so results are testable and
/// consistent across a single UI frame.
class ServiceDueEngine {
  const ServiceDueEngine();

  List<ServiceClockStatus> evaluate({
    required List<ServiceSchedule> schedules,
    required Map<String, ServiceKind> kindsById,
    required List<ServiceRecord> records,
    required List<DiveUsageSample> usage,
    DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    final statuses = <ServiceClockStatus>[];

    for (final schedule in schedules) {
      if (!schedule.enabled) continue;
      final kind = kindsById[schedule.serviceKindId];
      if (kind == null) continue;

      final intervalDays = schedule.intervalDays ?? kind.defaultIntervalDays;
      final intervalDives =
          schedule.intervalDives ?? kind.defaultIntervalDives;
      final intervalHours =
          schedule.intervalHours ?? kind.defaultIntervalHours;
      if (intervalDays == null &&
          intervalDives == null &&
          intervalHours == null) {
        continue; // no triggers configured
      }

      final anchor = _anchorFor(
        schedule: schedule,
        records: records,
        purchaseDate: purchaseDate,
        equipmentCreatedAt: equipmentCreatedAt,
      );

      final dueDate =
          intervalDays != null ? anchor.add(Duration(days: intervalDays)) : null;

      final usageSince =
          usage.where((u) => u.date.isAfter(anchor)).toList();
      int? divesSince;
      int? divesRemaining;
      if (intervalDives != null) {
        divesSince = usageSince.length;
        divesRemaining = intervalDives - divesSince;
      }
      double? hoursSince;
      double? hoursRemaining;
      if (intervalHours != null) {
        hoursSince = usageSince.fold<int>(
              0,
              (sum, u) => sum + u.durationSeconds,
            ) /
            3600.0;
        hoursRemaining = intervalHours - hoursSince;
      }

      statuses.add(
        ServiceClockStatus(
          schedule: schedule,
          kind: kind,
          anchor: anchor,
          dueDate: dueDate,
          divesSinceAnchor: divesSince,
          divesRemaining: divesRemaining,
          hoursSinceAnchor: hoursSince,
          hoursRemaining: hoursRemaining,
          severity: _severity(
            dueDate: dueDate,
            divesRemaining: divesRemaining,
            intervalDives: intervalDives,
            hoursRemaining: hoursRemaining,
            intervalHours: intervalHours,
            dueSoonWindowDays: dueSoonWindowDays,
            now: now,
          ),
          now: now,
        ),
      );
    }

    statuses.sort((a, b) {
      if (a.severity != b.severity) {
        return b.severity.index.compareTo(a.severity.index);
      }
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return statuses;
  }

  DateTime _anchorFor({
    required ServiceSchedule schedule,
    required List<ServiceRecord> records,
    required DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
  }) {
    DateTime? newest;
    for (final r in records) {
      if (r.serviceKindId != schedule.serviceKindId) continue;
      if (newest == null || r.serviceDate.isAfter(newest)) {
        newest = r.serviceDate;
      }
    }
    return newest ??
        schedule.anchorDate ??
        purchaseDate ??
        equipmentCreatedAt;
  }

  ServiceClockSeverity _severity({
    required DateTime? dueDate,
    required int? divesRemaining,
    required int? intervalDives,
    required double? hoursRemaining,
    required double? intervalHours,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    if ((dueDate != null && !now.isBefore(dueDate)) ||
        (divesRemaining != null && divesRemaining <= 0) ||
        (hoursRemaining != null && hoursRemaining <= 0)) {
      return ServiceClockSeverity.overdue;
    }
    if (dueDate != null &&
        dueDate.difference(now).inDays <= dueSoonWindowDays) {
      return ServiceClockSeverity.dueSoon;
    }
    if (divesRemaining != null &&
        intervalDives != null &&
        divesRemaining <= (intervalDives * 0.1).ceil()) {
      return ServiceClockSeverity.dueSoon;
    }
    if (hoursRemaining != null &&
        intervalHours != null &&
        hoursRemaining <= intervalHours * 0.1) {
      return ServiceClockSeverity.dueSoon;
    }
    return ServiceClockSeverity.ok;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/equipment/domain/services/service_due_engine_test.dart -r expanded`
Expected: PASS (all 10 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): ServiceDueEngine with date/dive/hour triggers"
```

---

### Task 4: Repositories — kinds, schedules, usage query, auto-attach, tombstones

**Files:**
- Create: `lib/features/equipment/data/repositories/service_kind_repository.dart`
- Create: `lib/features/equipment/data/repositories/service_schedule_repository.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`createEquipment` auto-attach hook; `deleteEquipment` child tombstones; add `getUsageSamplesForEquipment`)
- Modify: `lib/features/equipment/data/repositories/service_record_repository.dart` (persist/map `serviceKindId`)
- Test: `test/features/equipment/data/service_kind_repository_test.dart`
- Test: `test/features/equipment/data/service_schedule_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 2 entities, existing `SyncRepository.markRecordPending/logDeletion`, `SyncEventBus.notifyLocalChange`, `DatabaseService.instance.database`.
- Produces:
  - `ServiceKindRepository`: `Future<List<ServiceKind>> getAllKinds({String? diverId})` (built-ins + diver's customs), `Future<ServiceKind?> getKindById(String id)`, `Future<ServiceKind> createKind(ServiceKind kind)`, `Future<void> updateKind(ServiceKind kind)` (throws `StateError` on built-in), `Future<void> deleteKind(String id)` (throws `StateError` on built-in; tombstones cascaded schedules in one transaction). Sync entity type `'serviceKinds'`.
  - `ServiceScheduleRepository`: `Future<List<ServiceSchedule>> getSchedulesForEquipment(String equipmentId)`, `Future<List<ServiceSchedule>> getAllSchedules()`, `Future<ServiceSchedule> createSchedule(ServiceSchedule s)`, `Future<void> updateSchedule(ServiceSchedule s)`, `Future<void> deleteSchedule(String id)`, `Future<void> autoAttachForEquipment({required String equipmentId, required EquipmentType type})` (creates one enabled schedule per built-in/custom kind with `autoAttach && appliesTo(type)` that has no existing schedule of that kind on the item; deterministic id `'auto-<kindId>-<equipmentId>'`). Sync entity type `'serviceSchedules'`.
  - `EquipmentRepository.getUsageSamplesForEquipment(String equipmentId, {DateTime? since}) -> Future<List<DiveUsageSample>>` using SQL:

```sql
SELECT d.dive_date_time AS date_ms,
       COALESCE(d.runtime, d.bottom_time, 0) AS duration_sec
FROM (
  SELECT dive_id FROM dive_equipment WHERE equipment_id = ?1
  UNION
  SELECT dive_id FROM dive_tanks
    WHERE equipment_id = ?1 AND dive_id IS NOT NULL
) je
JOIN dives d ON d.id = je.dive_id
WHERE (?2 IS NULL OR d.dive_date_time >= ?2)
```

(check the actual `dive_tanks` FK column name for the dive reference — it is `dive_id` per the DiveTanks table — and adjust `?2` binding to `Variable.withInt(sinceMs)`; when `since` is null pass two variables with the second as `const Variable(null)`.)
  - `EquipmentRepository.createEquipment` calls `ServiceScheduleRepository().autoAttachForEquipment(...)` after insert.
  - `EquipmentRepository.deleteEquipment` adopts the `deleteSet` transaction pattern: load schedule ids + service record ids for the item, delete the equipment row, then `logDeletion` per schedule (`'serviceSchedules'`), per service record (`'serviceRecords'`), and the equipment row, all in one `_db.transaction`, then a single `SyncEventBus.notifyLocalChange()`.

Repository write-path pattern (copy `service_record_repository.dart` exactly): insert/update -> `markRecordPending(entityType: ..., recordId: ..., localUpdatedAt: now)` -> `SyncEventBus.notifyLocalChange()`; delete -> `logDeletion` -> notify. Mappers convert rows to entities with `DateTime.fromMillisecondsSinceEpoch`, enums via `.name` + `firstWhere(orElse:)`, and `applicableTypes` via `jsonDecode` to `List<String>` mapped through `EquipmentType.values.firstWhere((t) => t.name == s, orElse: () => EquipmentType.other)`.

- [ ] **Step 1: Write failing repository tests**

```dart
// test/features/equipment/data/service_schedule_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ServiceScheduleRepository repo;
  late EquipmentRepository equipmentRepo;

  setUp(() {
    db = createTestDatabase();
    DatabaseService.instance.setDatabaseForTesting(db);
    repo = ServiceScheduleRepository();
    equipmentRepo = EquipmentRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Future<EquipmentItem> makeTank() => equipmentRepo.createEquipment(
        EquipmentItem(
          id: '',
          name: 'AL80',
          type: EquipmentType.tank,
          status: EquipmentStatus.active,
          purchaseCurrency: 'USD',
          notes: '',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

  test('auto-attach creates hydro and vip (not o2-clean) for a tank',
      () async {
    final tank = await makeTank();
    final schedules = await repo.getSchedulesForEquipment(tank.id);
    final kindIds = schedules.map((s) => s.serviceKindId).toSet();
    expect(kindIds, containsAll(['hydro', 'vip']));
    expect(kindIds, isNot(contains('o2-clean'))); // autoAttach = false
  });

  test('auto-attach is idempotent', () async {
    final tank = await makeTank();
    await repo.autoAttachForEquipment(
      equipmentId: tank.id,
      type: EquipmentType.tank,
    );
    final schedules = await repo.getSchedulesForEquipment(tank.id);
    expect(schedules.where((s) => s.serviceKindId == 'hydro'), hasLength(1));
  });

  test('CRUD round-trip with overrides', () async {
    final tank = await makeTank();
    final created = await repo.createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: tank.id,
        serviceKindId: 'o2-clean',
        intervalDays: 180,
        anchorDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    expect(created.id, isNotEmpty);
    await repo.updateSchedule(created.copyWith(enabled: false));
    final reloaded = await repo.getSchedulesForEquipment(tank.id);
    final o2 = reloaded.firstWhere((s) => s.serviceKindId == 'o2-clean');
    expect(o2.enabled, isFalse);
    expect(o2.intervalDays, 180);
    expect(o2.anchorDate, DateTime(2026, 3, 1));
  });

  test('deleting equipment tombstones its schedules', () async {
    final tank = await makeTank();
    final before = await repo.getSchedulesForEquipment(tank.id);
    expect(before, isNotEmpty);
    await equipmentRepo.deleteEquipment(tank.id);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'serviceSchedules'",
        )
        .get();
    expect(
      tombstones.map((r) => r.data['record_id']),
      containsAll(before.map((s) => s.id)),
    );
  });
}
```

```dart
// test/features/equipment/data/service_kind_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ServiceKindRepository repo;

  setUp(() {
    db = createTestDatabase();
    DatabaseService.instance.setDatabaseForTesting(db);
    repo = ServiceKindRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('getAllKinds returns the 9 built-ins', () async {
    final kinds = await repo.getAllKinds();
    expect(kinds.length, 9);
    expect(kinds.every((k) => k.isBuiltIn), isTrue);
    final hydro = kinds.firstWhere((k) => k.id == 'hydro');
    expect(hydro.applicableTypes, [EquipmentType.tank]);
    expect(hydro.defaultIntervalDays, 1825);
  });

  test('custom kind CRUD; built-ins are protected', () async {
    final custom = await repo.createKind(
      ServiceKind(
        id: '',
        name: 'Scrubber repack',
        applicableTypes: const [EquipmentType.other],
        defaultIntervalHours: 5.0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    expect(custom.id, isNotEmpty);
    expect(custom.isBuiltIn, isFalse);

    await repo.updateKind(custom.copyWith(defaultIntervalHours: 6.0));
    final reloaded = await repo.getKindById(custom.id);
    expect(reloaded!.defaultIntervalHours, 6.0);

    await repo.deleteKind(custom.id);
    expect(await repo.getKindById(custom.id), isNull);

    final hydro = await repo.getKindById('hydro');
    expect(() => repo.deleteKind('hydro'), throwsStateError);
    expect(() => repo.updateKind(hydro!.copyWith(name: 'x')),
        throwsStateError);
  });
}
```

Note: if `DatabaseService.instance.setDatabaseForTesting` does not exist, check `test/helpers/test_database.dart` for the established way existing repository tests bind the test DB (e.g. a `DatabaseService.overrideForTesting(db)` or constructor injection used by `service_record_repository` tests) and use that mechanism instead — do not invent a new one.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/data/service_kind_repository_test.dart test/features/equipment/data/service_schedule_repository_test.dart -r expanded`
Expected: FAIL (repositories missing).

- [ ] **Step 3: Implement `ServiceKindRepository`**

```dart
// lib/features/equipment/data/repositories/service_kind_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../../../core/services/sync/sync_repository.dart';
import '../../domain/entities/service_kind.dart' as domain;

/// CRUD for the service-kind catalog. Built-ins are reference data:
/// they cannot be edited or deleted here, are skipped by sync export,
/// and are re-seeded in beforeOpen.
class ServiceKindRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<domain.ServiceKind>> getAllKinds({String? diverId}) async {
    final query = _db.select(_db.serviceKinds)
      ..where(
        (t) => t.isBuiltIn.equals(true) |
            (diverId == null
                ? t.diverId.isNull() | t.diverId.isNotNull()
                : t.diverId.equals(diverId) | t.diverId.isNull()),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  Future<domain.ServiceKind?> getKindById(String id) async {
    final row = await (_db.select(
      _db.serviceKinds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<domain.ServiceKind> createKind(domain.ServiceKind kind) async {
    final id = kind.id.isEmpty ? _uuid.v4() : kind.id;
    final now = DateTime.now();
    await _db.into(_db.serviceKinds).insert(
          ServiceKindsCompanion(
            id: Value(id),
            diverId: Value(kind.diverId),
            name: Value(kind.name),
            applicableTypes: Value(
              jsonEncode(kind.applicableTypes.map((t) => t.name).toList()),
            ),
            defaultIntervalDays: Value(kind.defaultIntervalDays),
            defaultIntervalDives: Value(kind.defaultIntervalDives),
            defaultIntervalHours: Value(kind.defaultIntervalHours),
            autoAttach: Value(kind.autoAttach),
            isBuiltIn: const Value(false),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'serviceKinds',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return kind.copyWith(
      id: id,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateKind(domain.ServiceKind kind) async {
    if (kind.isBuiltIn) {
      throw StateError('Built-in service kinds cannot be edited');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.serviceKinds,
    )..where((t) => t.id.equals(kind.id) & t.isBuiltIn.equals(false))).write(
      ServiceKindsCompanion(
        name: Value(kind.name),
        applicableTypes: Value(
          jsonEncode(kind.applicableTypes.map((t) => t.name).toList()),
        ),
        defaultIntervalDays: Value(kind.defaultIntervalDays),
        defaultIntervalDives: Value(kind.defaultIntervalDives),
        defaultIntervalHours: Value(kind.defaultIntervalHours),
        autoAttach: Value(kind.autoAttach),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'serviceKinds',
      recordId: kind.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a custom kind. Schedules referencing it are cascade-deleted by
  /// SQLite, so each is tombstoned explicitly (cascades emit no deletion-log
  /// entries; a peer would resurrect them otherwise).
  Future<void> deleteKind(String id) async {
    final row = await (_db.select(
      _db.serviceKinds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.isBuiltIn) {
      throw StateError('Built-in service kinds cannot be deleted');
    }
    await _db.transaction(() async {
      final schedules = await (_db.select(
        _db.serviceSchedules,
      )..where((t) => t.serviceKindId.equals(id))).get();
      await (_db.delete(_db.serviceKinds)..where((t) => t.id.equals(id)))
          .go();
      for (final s in schedules) {
        await _syncRepository.logDeletion(
          entityType: 'serviceSchedules',
          recordId: s.id,
        );
      }
      await _syncRepository.logDeletion(
        entityType: 'serviceKinds',
        recordId: id,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  domain.ServiceKind _mapRow(ServiceKindRow row) {
    final typeNames =
        (jsonDecode(row.applicableTypes) as List<dynamic>).cast<String>();
    return domain.ServiceKind(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      applicableTypes: typeNames
          .map(
            (s) => EquipmentType.values.firstWhere(
              (t) => t.name == s,
              orElse: () => EquipmentType.other,
            ),
          )
          .toList(),
      defaultIntervalDays: row.defaultIntervalDays,
      defaultIntervalDives: row.defaultIntervalDives,
      defaultIntervalHours: row.defaultIntervalHours,
      autoAttach: row.autoAttach,
      isBuiltIn: row.isBuiltIn,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
```

- [ ] **Step 4: Implement `ServiceScheduleRepository`**

```dart
// lib/features/equipment/data/repositories/service_schedule_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../../../core/services/sync/sync_repository.dart';
import '../../domain/entities/service_schedule.dart' as domain;
import 'service_kind_repository.dart';

/// CRUD for service clocks plus the auto-attach hook that seeds clocks on
/// newly created equipment.
class ServiceScheduleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<domain.ServiceSchedule>> getSchedulesForEquipment(
    String equipmentId,
  ) async {
    final rows = await (_db.select(
      _db.serviceSchedules,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    return rows.map(_mapRow).toList();
  }

  Future<List<domain.ServiceSchedule>> getAllSchedules() async {
    final rows = await _db.select(_db.serviceSchedules).get();
    return rows.map(_mapRow).toList();
  }

  Future<domain.ServiceSchedule> createSchedule(
    domain.ServiceSchedule schedule,
  ) async {
    final id = schedule.id.isEmpty ? _uuid.v4() : schedule.id;
    final now = DateTime.now();
    await _db.into(_db.serviceSchedules).insert(
          ServiceSchedulesCompanion(
            id: Value(id),
            equipmentId: Value(schedule.equipmentId),
            serviceKindId: Value(schedule.serviceKindId),
            intervalDays: Value(schedule.intervalDays),
            intervalDives: Value(schedule.intervalDives),
            intervalHours: Value(schedule.intervalHours),
            anchorDate: Value(
              schedule.anchorDate?.millisecondsSinceEpoch,
            ),
            enabled: Value(schedule.enabled),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'serviceSchedules',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return schedule.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  Future<void> updateSchedule(domain.ServiceSchedule schedule) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.serviceSchedules,
    )..where((t) => t.id.equals(schedule.id))).write(
      ServiceSchedulesCompanion(
        intervalDays: Value(schedule.intervalDays),
        intervalDives: Value(schedule.intervalDives),
        intervalHours: Value(schedule.intervalHours),
        anchorDate: Value(schedule.anchorDate?.millisecondsSinceEpoch),
        enabled: Value(schedule.enabled),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'serviceSchedules',
      recordId: schedule.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> deleteSchedule(String id) async {
    await (_db.delete(
      _db.serviceSchedules,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'serviceSchedules',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Creates one enabled schedule per auto-attach kind matching [type] that
  /// the item does not already have. Deterministic ids keep this idempotent
  /// and collision-free across devices.
  Future<void> autoAttachForEquipment({
    required String equipmentId,
    required EquipmentType type,
  }) async {
    final kinds = await ServiceKindRepository().getAllKinds();
    final existing = await getSchedulesForEquipment(equipmentId);
    final existingKindIds = existing.map((s) => s.serviceKindId).toSet();
    final now = DateTime.now();
    for (final kind in kinds) {
      if (!kind.autoAttach || !kind.appliesTo(type)) continue;
      if (existingKindIds.contains(kind.id)) continue;
      await createSchedule(
        domain.ServiceSchedule(
          id: 'auto-${kind.id}-$equipmentId',
          equipmentId: equipmentId,
          serviceKindId: kind.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  domain.ServiceSchedule _mapRow(ServiceScheduleRow row) {
    return domain.ServiceSchedule(
      id: row.id,
      equipmentId: row.equipmentId,
      serviceKindId: row.serviceKindId,
      intervalDays: row.intervalDays,
      intervalDives: row.intervalDives,
      intervalHours: row.intervalHours,
      anchorDate: row.anchorDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.anchorDate!),
      enabled: row.enabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
```

- [ ] **Step 5: Wire equipment repository**

In `equipment_repository_impl.dart`:

1. Import `service_schedule_repository.dart` and `../../domain/entities/service_clock_status.dart`.
2. At the end of `createEquipment` (after the insert + markRecordPending + notify, before returning), add:

```dart
    await ServiceScheduleRepository().autoAttachForEquipment(
      equipmentId: id,
      type: equipment.type,
    );
```

3. Replace the body of `deleteEquipment` (lines ~283-299) with the transactional child-tombstone pattern:

```dart
  /// Delete equipment. Service schedules and service records are first-class
  /// synced children cascade-deleted by SQLite, but cascades emit no
  /// deletion-log entries, so each is tombstoned explicitly (mirrors
  /// EquipmentSetRepository.deleteSet).
  Future<void> deleteEquipment(String id) async {
    try {
      _log.info('Deleting equipment: $id');
      await _db.transaction(() async {
        final schedules = await (_db.select(
          _db.serviceSchedules,
        )..where((t) => t.equipmentId.equals(id))).get();
        final records = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.equipmentId.equals(id))).get();
        await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
        for (final s in schedules) {
          await _syncRepository.logDeletion(
            entityType: 'serviceSchedules',
            recordId: s.id,
          );
        }
        for (final r in records) {
          await _syncRepository.logDeletion(
            entityType: 'serviceRecords',
            recordId: r.id,
          );
        }
        await _syncRepository.logDeletion(
          entityType: 'equipment',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted equipment: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

4. Add the usage query (next to `getDiveCountForEquipment`, ~line 471):

```dart
  /// (date, duration) samples of dives linked to this equipment via the
  /// dive_equipment junction or dive_tanks.equipment_id, for usage-based
  /// service clocks. Duration is COALESCE(runtime, bottom_time) seconds.
  Future<List<DiveUsageSample>> getUsageSamplesForEquipment(
    String equipmentId, {
    DateTime? since,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT d.dive_date_time AS date_ms,
             COALESCE(d.runtime, d.bottom_time, 0) AS duration_sec
      FROM (
        SELECT dive_id FROM dive_equipment WHERE equipment_id = ?1
        UNION
        SELECT dive_id FROM dive_tanks
          WHERE equipment_id = ?1 AND dive_id IS NOT NULL
      ) je
      JOIN dives d ON d.id = je.dive_id
      WHERE (?2 IS NULL OR d.dive_date_time >= ?2)
      ORDER BY d.dive_date_time
      ''',
          variables: [
            Variable.withString(equipmentId),
            Variable(since?.millisecondsSinceEpoch),
          ],
        )
        .get();
    return rows
        .map(
          (r) => DiveUsageSample(
            date: DateTime.fromMillisecondsSinceEpoch(
              r.data['date_ms'] as int,
            ),
            durationSeconds: (r.data['duration_sec'] as num).toInt(),
          ),
        )
        .toList();
  }
```

5. In `service_record_repository.dart`: add `serviceKindId: Value(record.serviceKindId),` to the create and update companions, and `serviceKindId: row.serviceKindId,` / `row.data['service_kind_id'] as String?` to both mappers.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/equipment/data/service_kind_repository_test.dart test/features/equipment/data/service_schedule_repository_test.dart -r expanded`
Expected: PASS. Also run the existing equipment repository tests to catch regressions: `flutter test test/features/equipment/ -r expanded`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): service kind/schedule repositories, usage query, auto-attach, child tombstones"
```

---

### Task 5: Sync registration for serviceKinds and serviceSchedules

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (all `serviceRecords` touchpoints, mirrored)
- Modify: `lib/core/services/sync/sync_service.dart` (push manifest ~1056, LWW map ~1609, FK map ~1724)
- Test: `test/core/services/sync/service_ledger_sync_test.dart`

**Interfaces:**
- Consumes: Task 1 tables. Copy template: every `serviceRecords` occurrence enumerated below.
- Produces: sync entity types `serviceKinds` and `serviceSchedules` fully round-trippable; built-in kinds excluded from export.

Mirror the `serviceRecords` wiring at each of these `sync_data_serializer.dart` locations, once per new table, keeping `serviceKinds` BEFORE `serviceSchedules` everywhere so parents import first (order: after the existing `serviceRecords` entries):

1. `SyncData` field declarations (~line 235): `final List<Map<String, dynamic>> serviceKinds;` and `final List<Map<String, dynamic>> serviceSchedules;`
2. Constructor defaults (~292): `this.serviceKinds = const [],` / `this.serviceSchedules = const [],`
3. `toJson` (~350): `'serviceKinds': serviceKinds,` / `'serviceSchedules': serviceSchedules,`
4. `fromJson` (~409): `serviceKinds: _parseList(json['serviceKinds']),` / `serviceSchedules: _parseList(json['serviceSchedules']),`
5. `_baseTables` (~615):

```dart
    (key: 'serviceKinds', table: _db.serviceKinds, blob: false, full: null),
    (
      key: 'serviceSchedules',
      table: _db.serviceSchedules,
      blob: false,
      full: null,
    ),
```

6. Export assembly (~1031): `serviceKinds: await _safeExport('serviceKinds', ...)`, same for schedules — match the exact `_safeExport` call shape used by `serviceRecords` at that site.
7. Single-record fetch switch (~1387): two new cases returning `row?.toJson()` from `getSingleOrNull()`.
8. Bulk fetch by id-set (~1737): two new cases mapping `id.isIn(idList)` rows to `{id: row.toJson()}`.
9. Single import/apply (~1934): `insertOnConflictUpdate(ServiceKindRow.fromJson(data).toCompanion(false))` / `ServiceScheduleRow.fromJson(data).toCompanion(false)` (HLC entities use `.toCompanion(false)` — this is the established rule).
10. Batch import/apply (~2382): `insertAllOnConflictUpdate` with the same `.fromJson(...).toCompanion(false)` mapping.
11. Merge descriptor (~2892): `case 'serviceKinds': return plain(_db.serviceKinds, _db.serviceKinds.id);` and same for schedules.
12. Table lookup (~3063): two new cases returning the table.
13. Deletion apply (~3201): two new cases deleting by `id.equals(recordId)`.
14. Dedicated exporter next to `_exportServiceRecords` (~3676): clone it for each table; the `serviceKinds` variant adds `AND is_built_in = 0` to the WHERE clause (built-ins are reference data, never exported — mirrors the dive-types convention).

In `sync_service.dart`:

- Push manifest (~1056): `(type: 'serviceKinds', records: data.serviceKinds, hasUpdatedAt: true),` then the schedules entry.
- LWW config map (~1609): `'serviceKinds': true,` / `'serviceSchedules': true,`
- Child→parent FK map (~1724):

```dart
    'serviceSchedules': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
      (field: 'serviceKindId', parent: 'serviceKinds', nullable: false),
    ],
```

(`serviceKinds` needs no FK entry — `diverId` handling should match whatever the existing `equipment` entry does for its nullable `diverId`; if `equipment` has no FK-map entry for `diverId`, omit one for kinds too.)

- [ ] **Step 1: Write the failing round-trip test**

```dart
// test/core/services/sync/service_ledger_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

// Follow the setup style of the closest existing serializer test in
// test/core/services/sync/ (e.g. the equipmentSetGeofences or
// serviceRecords round-trip test) for constructing SyncDataSerializer.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() {
    db = createTestDatabase();
    DatabaseService.instance.setDatabaseForTesting(db);
    serializer = SyncDataSerializer(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('export skips built-in kinds, includes custom kinds and schedules',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.serviceKinds).insert(
          ServiceKindsCompanion.insert(
            id: 'custom-1',
            name: 'Scrubber repack',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: 'e1', name: 'AL80', type: 'tank',
            createdAt: now, updatedAt: now,
          ),
        );
    await db.into(db.serviceSchedules).insert(
          ServiceSchedulesCompanion.insert(
            id: 's1', equipmentId: 'e1', serviceKindId: 'hydro',
            createdAt: now, updatedAt: now,
          ),
        );

    final data = await serializer.exportAll();
    expect(
      data.serviceKinds.map((k) => k['id']),
      isNot(contains('hydro')), // built-in excluded
    );
    expect(data.serviceKinds.map((k) => k['id']), contains('custom-1'));
    expect(data.serviceSchedules.map((s) => s['id']), contains('s1'));
  });

  test('import round-trips a schedule', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: 'e1', name: 'AL80', type: 'tank',
            createdAt: now, updatedAt: now,
          ),
        );
    await serializer.importRecord('serviceSchedules', {
      'id': 's-remote',
      'equipment_id': 'e1',
      'service_kind_id': 'vip',
      'interval_days': 400,
      'enabled': true,
      'created_at': now,
      'updated_at': now,
    });
    final rows = await db.select(db.serviceSchedules).get();
    expect(rows.single.id, 's-remote');
    expect(rows.single.intervalDays, 400);
  });

  test('deletion apply removes the row', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
          EquipmentCompanion.insert(
            id: 'e1', name: 'AL80', type: 'tank',
            createdAt: now, updatedAt: now,
          ),
        );
    await db.into(db.serviceSchedules).insert(
          ServiceSchedulesCompanion.insert(
            id: 's1', equipmentId: 'e1', serviceKindId: 'hydro',
            createdAt: now, updatedAt: now,
          ),
        );
    await serializer.applyDeletion('serviceSchedules', 's1');
    expect(await db.select(db.serviceSchedules).get(), isEmpty);
  });
}
```

IMPORTANT: before writing this test, open one existing serializer test in `test/core/services/sync/` and match the real constructor and method names (`exportAll`, `importRecord`, `applyDeletion` are placeholders for whatever the actual public API is — e.g. the methods the serviceRecords tests exercise). Use the real names; the assertions above are the contract.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/service_ledger_sync_test.dart -r expanded`
Expected: FAIL (SyncData has no serviceKinds field / switch cases missing).

- [ ] **Step 3: Implement all touchpoints** (the 14 serializer spots + 3 sync_service spots listed in Interfaces above, copying the adjacent `serviceRecords` code shape exactly at each site).

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/sync/service_ledger_sync_test.dart -r expanded`
Expected: PASS. Then run the whole sync test directory to catch regressions: `flutter test test/core/services/sync/ -r expanded`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(sync): register serviceKinds and serviceSchedules entities"
```

---

### Task 6: Providers — clock statuses, due clocks, trip alerts

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart`
- Test: `test/features/equipment/presentation/service_clock_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 2-4 (`ServiceDueEngine`, repositories, `getUsageSamplesForEquipment`), existing `validatedCurrentDiverIdProvider`, `settingsProvider` (`AppSettings.serviceReminderDays`), `tripByIdProvider` (find the actual name in `lib/features/trips/presentation/providers/` — the provider that yields a `Trip` by id), `repository.watchEquipmentChanges()`.
- Produces (all in `equipment_providers.dart`):

```dart
/// item + one evaluated clock, for cross-equipment lists.
typedef DueClock = ({EquipmentItem item, ServiceClockStatus status});

final serviceKindRepositoryProvider = Provider<ServiceKindRepository>(...);
final serviceScheduleRepositoryProvider =
    Provider<ServiceScheduleRepository>(...);
final serviceKindsProvider = FutureProvider<List<ServiceKind>>(...);
final serviceClockStatusesProvider =
    FutureProvider.family<List<ServiceClockStatus>, String>(...); // equipmentId
final dueClocksProvider = FutureProvider<List<DueClock>>(...); // severity != ok
final tripServiceAlertsProvider =
    FutureProvider.family<List<DueClock>, String>(...); // tripId
```

Evaluation recipe shared by the three consumers (extract as a private helper `Future<List<ServiceClockStatus>> _evaluateFor(Ref ref, EquipmentItem item)`): load schedules for the item, all kinds as `{id: kind}`, service records for the item, usage samples (`since:` the oldest anchor is an optimization — passing `null` is correct and simpler; do that), `dueSoonWindowDays` = max of `settings.serviceReminderDays` (fallback 30), `now = DateTime.now()`, then `const ServiceDueEngine().evaluate(...)`. `dueClocksProvider` maps over active equipment (`getActiveEquipment`), calls the helper, keeps statuses with `severity != ServiceClockSeverity.ok`, sorts overdue-first then by `dueDate`. `tripServiceAlertsProvider` loads the trip, evaluates all active equipment, and keeps a status when `status.severity == ServiceClockSeverity.overdue || (status.dueDate != null && status.dueDate!.isBefore(trip.endDate))`. Both list providers call `ref.invalidateSelfWhen(repository.watchEquipmentChanges())`; `serviceClockStatusesProvider` does the same so logging dives/records refreshes it. Extend `ServiceRecordNotifier.refresh()` to also `_ref.invalidate(serviceClockStatusesProvider(equipmentId));` and `_ref.invalidate(dueClocksProvider);`.

- [ ] **Step 1: Write the failing provider test** — use a `ProviderContainer` with the test database bound (mirror an existing provider test in `test/features/equipment/presentation/` for the container setup + diver override pattern). Scenarios: (a) a tank with an overdue hydro anchor appears in `dueClocksProvider`; (b) `serviceClockStatusesProvider` returns hydro+vip for an auto-attached tank; (c) `tripServiceAlertsProvider` includes a clock whose dueDate falls before the trip's endDate and excludes one due after. Insert the trip row directly via `db.into(db.trips)`.
- [ ] **Step 2: Run to verify failure** — `flutter test test/features/equipment/presentation/service_clock_providers_test.dart -r expanded` — FAIL.
- [ ] **Step 3: Implement providers per the Interfaces block.**
- [ ] **Step 4: Run tests** — same command — PASS.
- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): service clock providers and trip alerts"
```

---

### Task 7: Equipment detail — Service clocks card, kind picker, override dialog, record kind wiring

**Files:**
- Create: `lib/features/equipment/presentation/widgets/service_clocks_card.dart`
- Create: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (replace `_buildServiceSection` usage ~599 with the card; pass kind into add-service dialog)
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (drop the single service-interval field for NEW items only; keep it when editing an item that still has a legacy interval)
- Test: `test/features/equipment/presentation/service_clocks_card_test.dart`

**Interfaces:**
- Consumes: `serviceClockStatusesProvider`, `serviceKindsProvider`, `serviceScheduleRepositoryProvider`, `serviceRecordNotifierProvider`, `ServiceRecordDialog` (~line 1218 of the detail page).
- Produces:
  - `class ServiceClocksCard extends ConsumerWidget` — ctor `{required String equipmentId, required EquipmentType equipmentType}`. Renders a `Card` titled with `context.l10n.equipment_serviceClocks_title`; one `ListTile` per `ServiceClockStatus`: leading colored dot (severity: `ok` -> `surfaceContainerHighest`, `dueSoon` -> `tertiaryContainer`, `overdue` -> `errorContainer`, matching `_buildServiceSection`'s pill colors), title = kind name, subtitle = binding trigger text (due date via `MaterialLocalizations.of(context).formatShortDate`, or `context.l10n.equipment_serviceClocks_divesLeft(divesRemaining, intervalDives)`, or hours-left), trailing `PopupMenuButton` with: log service, edit, pause/resume, remove. Footer row: `TextButton.icon` "Add clock" -> `showServiceKindPicker`, and disabled-clock count when > 0.
  - `Future<void> showServiceKindPicker(BuildContext context, WidgetRef ref, {required String equipmentId, required EquipmentType equipmentType})` — modal bottom sheet (the `SafeArea > Column(mainAxisSize: min)` ListTile pattern from `trip_detail_page.dart:542`) listing kinds where `kind.appliesTo(equipmentType)` and no existing schedule; tapping creates a schedule via `createSchedule` with empty overrides; last tile "Manage service types" -> `context.push('/equipment/service-types')`.
  - `Future<void> showScheduleOverrideDialog(BuildContext context, WidgetRef ref, {required ServiceClockStatus status})` — `AlertDialog` with three numeric `TextFormField`s (days/dives/hours, blank = inherit default, hint shows the kind default) and an anchor-date picker row (same `InkWell`+`InputDecorator`+`showDatePicker` shape as `ServiceRecordDialog._pickServiceDate`); Save -> `updateSchedule` + invalidate `serviceClockStatusesProvider(equipmentId)`.
  - "Log service" menu action opens the existing `ServiceRecordDialog` and the saved record carries `serviceKindId: status.kind.id` (add an optional `String? serviceKindId` ctor param to `ServiceRecordDialog`, threaded into `_save()`'s `ServiceRecord`; also add a `DropdownButtonFormField<ServiceKind?>` "Applies to clock" inside the dialog, prefilled from the param, so ad-hoc adds can tag a kind too).
- The old `_buildServiceSection` call in the detail page body is replaced by `ServiceClocksCard(equipmentId: equipment.id, equipmentType: equipment.type)`; delete the now-unused `_buildServiceSection` method.

- [ ] **Step 1: Write the failing widget test** — pump `ServiceClocksCard` inside a `ProviderScope` with the test DB (follow an existing equipment widget test for scaffolding; remember `themeAnimationDuration: Duration.zero` and `tester.runAsync` for post-pump drift awaits — both are known traps). Seed a tank with auto-attached clocks, one overdue (anchor 6 years back). Assert: kind names render, the overdue row shows the overdue color, "Add clock" opens a sheet listing `O2 clean` (not attached) but not `Hydrostatic test` (already attached).
- [ ] **Step 2: Run to verify failure** — `flutter test test/features/equipment/presentation/service_clocks_card_test.dart -r expanded` — FAIL.
- [ ] **Step 3: Implement the card, picker, dialog, detail-page/edit-page wiring per Interfaces.** Add placeholder-free English strings for every new label to `app_en.arb` in this task (translations come in Task 11): `equipment_serviceClocks_title` ("Service clocks"), `equipment_serviceClocks_addClock` ("Add clock"), `equipment_serviceClocks_logService` ("Log service"), `equipment_serviceClocks_edit` ("Edit intervals"), `equipment_serviceClocks_pause` ("Pause"), `equipment_serviceClocks_resume` ("Resume"), `equipment_serviceClocks_remove` ("Remove"), `equipment_serviceClocks_dueOn` ("Due {date}"), `equipment_serviceClocks_overdueSince` ("Overdue since {date}"), `equipment_serviceClocks_divesLeft` ("{remaining} of {total} dives left"), `equipment_serviceClocks_hoursLeft` ("{remaining} of {total} hours left"), `equipment_serviceClocks_manageKinds` ("Manage service types"), `equipment_serviceClocks_appliesToClock` ("Applies to clock"), plus `@`-metadata for the parameterized ones. Run `flutter gen-l10n` after editing.
- [ ] **Step 4: Run tests** — PASS. Also `flutter test test/features/equipment/ -r expanded` — PASS.
- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): service clocks card on equipment detail"
```

---

### Task 8: Manage service types page + route

**Files:**
- Create: `lib/features/equipment/presentation/pages/service_kind_list_page.dart`
- Modify: `lib/core/router/app_router.dart` (sibling route under `/equipment` ~line 448; import ~57-62)
- Test: `test/features/equipment/presentation/service_kind_list_page_test.dart`

**Interfaces:**
- Consumes: `serviceKindsProvider`, `serviceKindRepositoryProvider`.
- Produces: `class ServiceKindListPage extends ConsumerWidget` at route `GoRoute(path: 'service-types', name: 'manageServiceTypes', ...)` (full path `/equipment/service-types`). Two sections: built-ins (read-only ListTiles, lock icon, subtitle shows default interval summary) and custom kinds (tap to edit, swipe/menu to delete, FAB or header button to add). Add/edit dialog: name field, equipment-type multi-select (`FilterChip` per `EquipmentType.values` like the settings reminder-day chips), three numeric interval fields, auto-attach `SwitchListTile`. Mutations via `serviceKindRepositoryProvider` + `ref.invalidate(serviceKindsProvider)`. Deleting a custom kind shows a confirm dialog warning that attached clocks are removed (`deleteKind` cascades + tombstones them — Task 4).
- Strings added to `app_en.arb`: `equipment_serviceKinds_title` ("Service types"), `equipment_serviceKinds_builtIn` ("Built-in"), `equipment_serviceKinds_custom` ("Custom"), `equipment_serviceKinds_add` ("Add service type"), `equipment_serviceKinds_deleteConfirm` ("Delete this service type? Clocks using it will be removed."), `equipment_serviceKinds_autoAttach` ("Attach automatically to new gear").

- [ ] **Step 1: Write the failing widget test** — pump the page; assert the 9 built-ins render with a lock affordance and no delete action; add a custom kind through the dialog and assert it appears in the Custom section.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement page + route + strings; `flutter gen-l10n`.**
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Format, commit** — `feat(equipment): manage service types page`.

---

### Task 9: Gear list badges + dashboard card

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (`DashboardAlerts` ~line 12, `dashboardAlertsProvider` ~84)
- Modify: `lib/features/dashboard/presentation/widgets/alerts_card.dart`
- Create: `lib/features/dashboard/presentation/widgets/service_due_card.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (add card to the Column + refresh invalidation list)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` and `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (badge severity/subtitle from clocks)
- Test: `test/features/dashboard/service_due_card_test.dart`

**Interfaces:**
- Consumes: `dueClocksProvider`, `DueClock` (Task 6).
- Produces:
  - `DashboardAlerts` gains `final List<DueClock> serviceClocksDue;` (keep the legacy `equipmentServiceDue` list for other consumers, but populate `serviceClocksDue` from `dueClocksProvider` and switch `AlertsCard`'s service line to it: text = kind-aware `context.l10n.dashboard_alerts_clockDue(item.name, kind.name)` / `dashboard_alerts_clockOverdue(...)`).
  - `class ServiceDueCard extends ConsumerWidget` — watches `dueClocksProvider`; `SizedBox.shrink()` when empty; else a `Card` listing up to 5 clocks (overdue first — provider already sorts), each `ListTile`: item name, kind + due phrase subtitle, severity dot, `onTap: context.push('/equipment/${item.id}')`; "+N more" footer when truncated (no silent cap).
  - Gear list tiles: severity = worst clock for the item. To avoid N queries in list rows, add `final Map<String, ServiceClockSeverity> worstByEquipmentId` exposure: a new provider `equipmentServiceSeverityProvider = FutureProvider<Map<String, ServiceClockSeverity>>` in `equipment_providers.dart` derived from `dueClocksProvider` (absent id = ok). Tiles watch it and show the existing badge with the new color + a subtitle naming the worst clock's kind when not ok.
- Strings: `dashboard_serviceDue_title` ("Service due"), `dashboard_serviceDue_more` ("+{count} more"), `dashboard_alerts_clockDue` ("{name}: {kind} due"), `dashboard_alerts_clockOverdue` ("{name}: {kind} overdue"), `equipment_list_worstClock` ("{kind} overdue") — with metadata.

- [ ] **Step 1: Write the failing widget test** for `ServiceDueCard` (empty -> shrink; overdue tank renders name + hydro line first).
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement; `flutter gen-l10n`.**
- [ ] **Step 4: Run tests** — new test + `flutter test test/features/dashboard/ -r expanded` — PASS.
- [ ] **Step 5: Format, commit** — `feat(dashboard): service due card and clock-aware alerts`.

---

### Task 10: Trip banner + service-alert sheet

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_service_alert_banner.dart`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (insert banner in `_buildStandardLayout` ~112 and the liveaboard layout, between the embedded header and the `Expanded` body)
- Modify: `lib/features/trips/presentation/widgets/upcoming_trip_banner.dart` (append a compact service line when alerts exist)
- Test: `test/features/trips/trip_service_alert_banner_test.dart`

**Interfaces:**
- Consumes: `tripServiceAlertsProvider(tripId)` (Task 6), `Trip.isUpcoming`/`daysUntilStart`.
- Produces: `class TripServiceAlertBanner extends ConsumerWidget` — ctor `{required Trip trip}`. Renders nothing when the trip is not upcoming/in-progress or alerts are empty. Otherwise a `MaterialBanner`-styled container (errorContainer when any overdue, tertiaryContainer otherwise): build-icon + `context.l10n.trips_serviceAlert_count(count)` + chevron; tap -> `showModalBottomSheet` (the `SafeArea > Column(mainAxisSize: min)` ListTile pattern) listing each `DueClock`: item name, kind, due phrase vs trip start (e.g. "Hydro due 3 Aug — before this trip"); tapping a row `Navigator.pop` then `context.push('/equipment/${item.id}')`. `UpcomingTripBanner` gains one extra `Row` line reusing the same provider: `context.l10n.trips_serviceAlert_count(count)` in error color when non-empty.
- Strings: `trips_serviceAlert_count` ("{count, plural, =1{1 item needs service before this trip} other{{count} items need service before this trip}}"), `trips_serviceAlert_dueBefore` ("{kind} due {date}"), `trips_serviceAlert_overdue` ("{kind} overdue") — with metadata.

- [ ] **Step 1: Write the failing widget test** — trip starting in 10 days + tank with hydro due in 5 days -> banner text renders; tapping opens sheet listing "AL80" + hydro; trip with no due gear -> nothing rendered.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement; `flutter gen-l10n`.**
- [ ] **Step 4: Run tests** — new test + `flutter test test/features/trips/ -r expanded` — PASS.
- [ ] **Step 5: Format, commit** — `feat(trips): pre-trip gear service alerts`.

---

### Task 11: Notifications — per-schedule reminders, trip nag, settings

**Files:**
- Modify: `lib/core/services/notification_service.dart` (`scheduleServiceReminder` ~127; new `scheduleTripServiceReminder`)
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart` (whole scheduling core)
- Modify: `lib/features/notifications/data/repositories/scheduled_notification_repository.dart` (persist/query `scheduleId`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (trip lead-time control ~1591, inside the `notificationsEnabled` guard)
- Modify: the `AppSettings` entity + `settingsProvider` notifier (find them via `settingsProvider` imports in settings_page.dart) to carry `tripServiceLeadDays` (int, default 14) backed by the new `diver_settings.trip_service_lead_days` column, with a `setTripServiceLeadDays(int)` mutation following `setReminderTime`'s shape.
- Test: `test/features/notifications/service_ledger_scheduler_test.dart`

**Interfaces:**
- Consumes: `ServiceScheduleRepository.getAllSchedules`, `ServiceKindRepository.getAllKinds`, `ServiceDueEngine`, `EquipmentRepository.getUsageSamplesForEquipment` + `getAllEquipment`, trips repository (upcoming trips), `tripServiceAlertsProvider` logic (re-evaluated inside the scheduler, not via Riverpod — the scheduler is a plain service).
- Produces:
  - `NotificationService.scheduleServiceReminder` signature becomes:

```dart
  Future<int> scheduleServiceReminder({
    required String scheduleId,
    required String equipmentId,
    required String equipmentName,
    required String kindName,
    required String? brandModel,
    required DateTime scheduledDate,
    required int daysBefore,
  })
```

with `final notificationId = scheduleId.hashCode + daysBefore;` (the old `equipmentId.hashCode` scheme collides across two clocks on one item — flutter_local_notifications silently replaces on ID collision), title `'$kindName due: $equipmentName'`, body naming the kind; payload stays `equipmentId` so the existing tap-routing keeps working.
  - `NotificationService.scheduleTripServiceReminder({required String tripId, required String tripName, required int itemCount, required DateTime scheduledDate})` — same channel, `notificationId = tripId.hashCode ^ 0x7452195C`, title `'Gear service before $tripName'`, body `'$itemCount item(s) need service before this trip'` (localized at the call site is unnecessary — platform notifications in this app are English-only today, matching `scheduleServiceReminder`; keep consistent).
  - `NotificationScheduler.scheduleAll` now: loads all active equipment, kinds, schedules; for each item evaluates clocks with `ServiceDueEngine` (dueSoonWindowDays = max reminder day); for each clock with a `dueDate`, schedules per reminder-day exactly like the old `_scheduleForEquipment` (same custom/global reminder-days resolution per ITEM, same reminder-time-of-day, same skip-past/already-scheduled checks but keyed by `scheduleId` + `daysBefore`); records rows with `scheduleId`. Usage-only clocks get no scheduled push (nothing to anchor a future date to) — they surface via in-app badges. Then: loads upcoming trips, computes trip alerts (same rule as `tripServiceAlertsProvider`), and schedules one trip reminder at `trip.startDate - tripServiceLeadDays` when in the future and alerts are non-empty.
  - `ScheduledNotificationRepository.isScheduled`/`recordScheduled` gain a `String? scheduleId` parameter (matching on it when provided); `_cancelForEquipment` cancels by equipment as before (IDs are re-derivable from schedules: cancel via recorded `notificationId` rows — keep using the recorded rows, which is what `deleteAll`/`deleteExpired` already manage).
- Settings UI: a `ListTile` "Trip service lead time" with a `DropdownButton<int>` of 7/14/21/30 days bound to `settings.tripServiceLeadDays` -> `setTripServiceLeadDays`. String keys: `settings_notifications_tripLeadTitle` ("Trip service lead time"), `settings_notifications_tripLeadDays` ("{days} days before a trip").

- [ ] **Step 1: Write the failing scheduler test** — bind test DB; seed: one tank, auto-attached clocks, hydro anchored so dueDate = now + 20 days; settings reminder days `[7, 14, 30]`. Call `scheduler.scheduleAll(...)` with a mocked/no-op `NotificationService` (follow the existing scheduler test's mocking approach in `test/features/notifications/` — there are existing mocks per the settings-notifier pattern; reuse them). Assert: `scheduled_notifications` rows exist for daysBefore 7 and 14 (30 is in the past relative to a 20-day-out due date), each row carries the hydro schedule id, and two clocks on one item produce distinct `notificationId`s.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement scheduler + service + repository + settings changes; `flutter gen-l10n`.**
- [ ] **Step 4: Run tests** — new test + `flutter test test/features/notifications/ test/features/settings/ -r expanded` — PASS.
- [ ] **Step 5: Format, commit** — `feat(notifications): per-clock service reminders and trip nag`.

---

### Task 12: L10n sweep — translate all new keys into the 10 locales

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: every key added in Tasks 7-11 (grep `app_en.arb` for keys added since Task 1: `equipment_serviceClocks_*`, `equipment_serviceKinds_*`, `dashboard_serviceDue_*`, `dashboard_alerts_clock*`, `equipment_list_worstClock`, `trips_serviceAlert_*`, `settings_notifications_tripLead*`).
- Produces: each key translated in all 10 files (localized translations, not English copies; keep placeholders and plural syntax identical to the English template).

- [ ] **Step 1: List the new keys** — `git diff main -- lib/l10n/arb/app_en.arb` to enumerate them.
- [ ] **Step 2: Add translations to all 10 locale files.** Preserve ICU plural structure for `trips_serviceAlert_count` in each language (Arabic and Hebrew need their locale-correct plural categories).
- [ ] **Step 3: Regenerate and verify** — `flutter gen-l10n` then `flutter analyze` — both clean (gen-l10n fails loudly on missing keys/placeholder mismatches).
- [ ] **Step 4: Format, commit** — `feat(l10n): service ledger strings for all locales`.

---

### Task 13: Final verification gate

**Files:** none new.

- [ ] **Step 1: Full format check** — `dart format .` — Expected: "0 changed" (or commit any reflow).
- [ ] **Step 2: Analyze** — `flutter analyze` — Expected: "No issues found!" (never pipe through tail/head — full output).
- [ ] **Step 3: Run the feature's test surface** (per-directory, not the whole suite at once):

```bash
flutter test test/core/database/ -r compact
flutter test test/core/services/sync/ -r compact
flutter test test/features/equipment/ -r compact
flutter test test/features/dashboard/ test/features/trips/ -r compact
flutter test test/features/notifications/ test/features/settings/ -r compact
```

Expected: ALL PASS.
- [ ] **Step 4: Invoke the superpowers:verification-before-completion skill, then the verify skill** to exercise the flow end-to-end in the running app (`flutter run -d macos` — check no other flutter run session is active first): create a tank, confirm hydro/VIP clocks auto-attach, log a VIP record and watch the clock reset, check the dashboard card and a trip banner with a near-due clock.
- [ ] **Step 5: Commit any fixes; leave the branch ready for review** (`superpowers:finishing-a-development-branch` decides merge/PR next — PR description without attribution lines per project rules).

---

## Self-review notes (already applied)

- Spec coverage: schema/§1 -> Task 1-2; engine+usage/§2 -> Tasks 3, 4, 6; notifications/§2 -> Task 11; UI/§3 -> Tasks 7-10; settings lead time/§3 -> Task 11; sync/§4 -> Tasks 4 (write path), 5 (transport); testing/§4 -> per-task TDD + Task 13. Out-of-scope items from the spec are not planned.
- The spec's "General service" backfill anchor uses `lastServiceDate`; items with an interval but no lastServiceDate get a NULL anchor and fall back to purchase/created dates in the engine — matches spec's fallback chain.
- Type consistency: `DueClock` defined once (Task 6) and consumed in Tasks 9-10; `ServiceClockStatus.now` field exists to make `daysUntilDue` pure; engine signature identical in Tasks 3 and 6.
- Known flexibility points called out inline: test-DB binding helper name (Task 4), serializer test API names (Task 5), trip provider name (Task 6) — executors must mirror the existing code, not invent APIs.
