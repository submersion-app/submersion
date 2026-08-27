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
    expect(kinds.length, 12);
    expect(kinds.every((k) => k.isBuiltIn), isTrue);
    final hydro = kinds.firstWhere((k) => k.id == 'hydro');
    expect(hydro.defaultIntervalDays, 1825);
    expect(hydro.autoAttach, isTrue);
    final reg = kinds.firstWhere((k) => k.id == 'regulator-service');
    expect(reg.defaultIntervalDives, 100);
  });

  test('built-in kinds carry no default cost', () async {
    // Prices are personal and regional, and kSeedBuiltInServiceKindsSql is
    // INSERT OR IGNORE, so a seeded value would never reach an existing
    // install anyway. Leaving the seed alone also keeps its positional
    // column list intact.
    final kinds = await db.select(db.serviceKinds).get();
    expect(kinds, isNotEmpty);
    for (final kind in kinds.where((k) => k.isBuiltIn)) {
      expect(kind.defaultCost, isNull, reason: '${kind.id} has a seeded cost');
      expect(kind.defaultCurrency, isNull, reason: '${kind.id} has a currency');
    }
  });

  test('pre-existing built-in kinds keep null hour intervals', () async {
    // Characterization: pins the current seed so adding an hours column to
    // kSeedBuiltInServiceKindsSql cannot silently shift a positional value.
    const preExisting = <String>[
      'hydro',
      'vip',
      'o2-clean',
      'regulator-service',
      'computer-battery',
      'transmitter-battery',
      'bcd-inspection',
      'drysuit-seals',
      'general-service',
    ];

    final kinds = await db.select(db.serviceKinds).get();
    final byId = {for (final k in kinds) k.id: k};

    expect(byId.keys, containsAll(preExisting));

    for (final id in preExisting) {
      expect(
        byId[id]!.defaultIntervalHours,
        isNull,
        reason: '$id must not gain an hours interval',
      );
    }

    expect(byId['vip']!.defaultIntervalDays, 365);
    expect(byId['o2-clean']!.autoAttach, isFalse);
    expect(byId['drysuit-seals']!.defaultIntervalDays, 730);
    expect(byId['general-service']!.defaultIntervalDays, isNull);
    expect(byId['general-service']!.defaultIntervalDives, isNull);
    expect(byId['general-service']!.applicableTypes, '[]');
  });

  test('rebreather built-in kinds seed with the expected clocks', () async {
    final kinds = await db.select(db.serviceKinds).get();
    final byId = {
      for (final k in kinds)
        if (const [
          'scrubber-repack',
          'o2-cell-replacement',
          'rebreather-annual',
        ].contains(k.id))
          k.id: k,
    };

    expect(byId.length, 3);

    final scrubber = byId['scrubber-repack']!;
    expect(scrubber.defaultIntervalHours, 3.0);
    expect(scrubber.defaultIntervalDays, isNull);
    expect(scrubber.defaultIntervalDives, isNull);
    expect(scrubber.autoAttach, isTrue);

    final cells = byId['o2-cell-replacement']!;
    expect(cells.defaultIntervalDays, 365);
    expect(cells.defaultIntervalHours, isNull);

    expect(byId['rebreather-annual']!.defaultIntervalDays, 365);

    for (final kind in byId.values) {
      expect(kind.applicableTypes, '["rebreather"]', reason: kind.id);
      expect(kind.isBuiltIn, isTrue, reason: kind.id);
    }
  });

  test('re-running the built-in seed is a no-op', () async {
    await db.customStatement(kSeedBuiltInServiceKindsSql);
    await db.customStatement(kSeedBuiltInServiceKindsSql);

    final kinds = await db.select(db.serviceKinds).get();
    final scrubbers = kinds.where((k) => k.id == 'scrubber-repack');
    expect(scrubbers.length, 1);
  });

  test(
    'a database missing a rebreather kind regains it from the seed',
    () async {
      // The seed already runs from onCreate and the v122 beforeOpen backstop,
      // so an upgraded database picks the new kinds up without a migration.
      await db.customStatement(
        "DELETE FROM service_kinds WHERE id = 'scrubber-repack'",
      );
      var kinds = await db.select(db.serviceKinds).get();
      expect(kinds.where((k) => k.id == 'scrubber-repack'), isEmpty);

      await db.customStatement(kSeedBuiltInServiceKindsSql);

      kinds = await db.select(db.serviceKinds).get();
      expect(kinds.where((k) => k.id == 'scrubber-repack'), hasLength(1));
    },
  );

  test(
    'service_schedules round-trips and cascades on equipment delete',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'e1',
              name: 'AL80',
              type: 'tank',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.serviceSchedules)
          .insert(
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
      expect(rows.first.intervalDays, null); // inherit kind default

      await (db.delete(db.equipment)..where((t) => t.id.equals('e1'))).go();
      expect(await db.select(db.serviceSchedules).get(), isEmpty); // cascade
    },
  );

  test('fresh install has the service ledger indexes', () async {
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name LIKE 'idx_service_%'",
        )
        .get();
    expect(
      idx.map((r) => r.data['name']),
      containsAll([
        'idx_service_schedules_equipment',
        'idx_service_records_kind',
      ]),
    );
  });
}
