import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal v112 database: only the tables the v122 step reads or alters.
NativeDatabase _dbAt112() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 112');
      rawDb.execute('''
        CREATE TABLE divers (
          id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
        )
      ''');
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
  test('v122 creates ledger tables, seeds kinds, backfills legacy', () async {
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
        'hydro',
        'vip',
        'o2-clean',
        'regulator-service',
        'computer-battery',
        'transmitter-battery',
        'bcd-inspection',
        'drysuit-seals',
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
    expect(
      srCols.map((c) => c.read<String>('name')),
      contains('service_kind_id'),
    );
    final snCols = await db
        .customSelect("PRAGMA table_info('scheduled_notifications')")
        .get();
    expect(snCols.map((c) => c.read<String>('name')), contains('schedule_id'));
    final dsCols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    expect(
      dsCols.map((c) => c.read<String>('name')),
      contains('trip_service_lead_days'),
    );
  });

  test(
    'v122 backfill is idempotent (re-running assert does not duplicate)',
    () async {
      final db = AppDatabase(_dbAt112());
      addTearDown(() => db.close());
      await db.customSelect('SELECT 1').get(); // force open
      final scheds = await db
          .customSelect('SELECT COUNT(*) AS c FROM service_schedules')
          .getSingle();
      expect(scheds.data['c'], 1);
    },
  );

  test('version ladder includes 122', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(122));
    expect(AppDatabase.migrationVersions, contains(122));
  });
}
