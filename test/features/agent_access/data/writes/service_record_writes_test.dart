import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/built_ins/hidden_built_ins_codec.dart';
import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Service records, as the log service dialog keeps them: a type the dialog
/// offers, a day that has happened, the prices and category it fills in,
/// and the item's last service date the repository moves.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<DateTime?> lastService() async {
    final row = await (db.select(
      db.equipment,
    )..where((e) => e.id.equals('suit'))).getSingle();
    return row.lastServiceDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.lastServiceDate!);
  }

  Map<String, Object?> record(String day, {String kind = 'seals'}) => {
    'equipment_id': 'suit',
    'service_kind_id': kind,
    'service_date': day,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'suit',
            name: 'Drysuit',
            type: 'drysuit',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.serviceKinds)
        .insert(
          ServiceKindsCompanion.insert(
            id: 'seals',
            name: 'Seal check',
            applicableTypes: const Value('["drysuit"]'),
            defaultIntervalDays: const Value(180),
            defaultCost: const Value(40),
            defaultCurrency: const Value('EUR'),
            defaultCategory: const Value('inspection'),
            diverId: const Value(kDiverA),
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a record takes the prices and category the dialog fills in', () async {
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: 'clock',
        equipmentId: 'suit',
        serviceKindId: 'seals',
        defaultCost: 55,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    final id = (await h.run([
      createOp('service_records', record('2026-03-01')),
    ])).created.single.id;

    final doc = (await h.one('service_records', id))!;
    expect(doc['category'], 'inspection');
    // The clock's price wins over the type's; the type names the currency.
    expect(doc['cost'], 55);
    expect(doc['currency'], 'EUR');
    expect(await lastService(), DateTime(2026, 3, 1));
  });

  test('a record is edited and deleted, and the date follows', () async {
    final first = (await h.run([
      createOp('service_records', record('2026-01-10')),
    ])).created.single.id;
    final second = (await h.run([
      createOp('service_records', record('2026-02-20')),
    ])).created.single.id;

    final edit = await h.preview([
      updateOp('service_records', second, {'service_date': '2026-01-05'}),
    ]);
    expect(edit.items.single.alsoChanges, {'equipment': 1});
    await h.apply(edit);
    expect(await lastService(), DateTime(2026, 1, 10));

    await h.run([deleteOp('service_records', first)]);
    expect(await lastService(), DateTime(2026, 1, 5));
    final last = await h.preview([deleteOp('service_records', second)]);
    expect(last.items.single.alsoChanges, {'equipment': 1});
    await h.apply(last);
    expect(await lastService(), isNull);
  });

  // createRecord writes the new record's date as is (#4201), so the plan
  // says so, and this pins it until that issue is fixed.
  test('an older record moves the last service date back', () async {
    await h.run([createOp('service_records', record('2026-03-01'))]);

    final plan = await h.preview([
      createOp('service_records', record('2025-03-01')),
    ]);
    expect(plan.items.single.alsoChanges, {'equipment': 1});
    await h.apply(plan);

    expect(await lastService(), DateTime(2025, 3, 1));
  });

  test(
    'a type the dialog would not offer, or a day ahead, is refused',
    () async {
      final hidden = (await ServiceKindRepository().getAllKinds())
          .firstWhere((k) => k.isBuiltIn && k.appliesTo(EquipmentType.drysuit))
          .id;
      await db
          .into(db.diverSettings)
          .insertOnConflictUpdate(
            DiverSettingsCompanion.insert(
              id: 'settings-a',
              diverId: kDiverA,
              createdAt: t,
              updatedAt: t,
              hiddenBuiltInIds: Value(
                encodeHiddenBuiltIns({
                  BuiltInCatalog.serviceKinds.key: {hidden},
                }),
              ),
            ),
          );

      final plan = await h.preview([
        createOp('service_records', record('2026-03-01', kind: hidden)),
        createOp('service_records', record('2999-03-01')),
      ]);

      expect(
        [for (final item in plan.items) item.block?.detail ?? ''],
        [contains('hidden'), contains('1950-01-01')],
      );
    },
  );

  // The log service dialog re-arms the item's reminders after a save.
  test('a record re-arms its item\'s reminders, and a failure there '
      'leaves it saved', () async {
    final asked = <String>[];
    final watched = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(
        repositories,
        refreshReminders: (itemId) async => asked.add(itemId),
      ),
    );
    await watched.run([createOp('service_records', record('2026-03-01'))]);
    expect(asked, ['suit']);

    final failing = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(
        repositories,
        refreshReminders: (_) async => throw StateError('no scheduler'),
      ),
    );
    final result = await failing.run([
      createOp('service_records', record('2026-04-01')),
    ]);
    expect(await h.one('service_records', result.created.single.id), isNotNull);
  });
}
