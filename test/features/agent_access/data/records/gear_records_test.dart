import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  Future<void> item(String id, String? owner) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    await item('mine', kDiverA);
    await item('theirs', kDiverB);
    await item('lent', kDiverB);
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'share',
            equipmentId: 'lent',
            diverId: kDiverA,
            createdAt: t,
          ),
        );
    await db
        .into(db.serviceKinds)
        .insert(
          ServiceKindsCompanion.insert(
            id: 'annual',
            name: 'Annual',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    for (final id in ['mine', 'theirs', 'lent']) {
      await db
          .into(db.serviceRecords)
          .insert(
            ServiceRecordsCompanion.insert(
              id: 'rec-$id',
              equipmentId: id,
              serviceCategory: 'annual',
              serviceDate: DateTime(2024, 3, 1).millisecondsSinceEpoch,
              cost: const Value(120),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.serviceSchedules)
          .insert(
            ServiceSchedulesCompanion.insert(
              id: 'sch-$id',
              equipmentId: id,
              serviceKindId: 'annual',
              intervalDays: const Value(365),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.equipmentObservations)
          .insert(
            EquipmentObservationsCompanion.insert(
              id: 'obs-$id',
              equipmentId: id,
              observedAt: t,
              status: 'ok',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.equipmentLocationMoves)
          .insert(
            EquipmentLocationMovesCompanion.insert(
              id: 'mv-$id',
              equipmentId: id,
              movedAt: t,
              createdAt: t,
            ),
          );
      await db
          .into(db.equipmentAttributes)
          .insert(
            EquipmentAttributesCompanion.insert(
              id: 'attr-$id',
              equipmentId: id,
              attrKey: 'size',
              valueText: const Value('M'),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await item('hose', kDiverA);
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'comp',
            parentEquipmentId: 'mine',
            componentEquipmentId: 'hose',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final (id, owner) in [('set-a', kDiverA), ('set-b', kDiverB)]) {
      await db
          .into(db.equipmentSets)
          .insert(
            EquipmentSetsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    await db
        .into(db.equipmentSetItems)
        .insert(
          EquipmentSetItemsCompanion.insert(
            setId: 'set-a',
            equipmentId: 'mine',
          ),
        );
    for (final (id, owner) in [
      ('loc-a', kDiverA),
      ('loc-b', kDiverB),
      ('loc-none', null),
    ]) {
      await db
          .into(db.equipmentLocations)
          .insert(
            EquipmentLocationsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    for (final (id, owner) in [('tx-a', kDiverA), ('tx-b', kDiverB)]) {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: id,
              label: id,
              tankRole: 'backGas',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              volumeL: const Value(12),
            ),
          );
    }
    for (final (id, owner) in [('cfg-a', kDiverA), ('cfg-b', kDiverB)]) {
      await db
          .into(db.cylinderConfigs)
          .insert(
            CylinderConfigsCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    await db
        .into(db.cylinderConfigItems)
        .insert(
          CylinderConfigItemsCompanion.insert(
            id: 'cfg-item',
            configId: 'cfg-a',
            tankRole: 'backGas',
            createdAt: t,
            updatedAt: t,
            o2Percent: const Value(32),
            volumeL: const Value(12),
          ),
        );
    for (final (id, owner, gear) in [
      ('fill-mine', kDiverA, 'mine'),
      ('fill-lent', kDiverB, 'lent'),
      ('fill-theirs', kDiverB, 'theirs'),
      ('fill-loose', kDiverA, null),
    ]) {
      await db
          .into(db.cylinderFills)
          .insert(
            CylinderFillsCompanion.insert(
              id: id,
              passportId: 'p-$id',
              filledAt: t,
              o2Percent: 32,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              equipmentId: Value(gear),
              pressureBar: const Value(200),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> rootIds(List<String> ids) async {
    final out = await h.get('equipment', ids);
    return {
      for (final r in (out['records'] as List).cast<Map>()) r['id'] as String,
    };
  }

  group('equipment', () {
    test(
      'equipment owned by another diver and not shared is missing',
      () async {
        expect(await rootIds(['mine', 'theirs', 'lent']), {'mine', 'lent'});
      },
    );

    test('purchase and service dates are calendar dates', () async {
      final bought = DateTime(2023, 6, 15).millisecondsSinceEpoch;
      await (db.update(db.equipment)..where((e) => e.id.equals('mine'))).write(
        EquipmentCompanion(
          purchaseDate: Value(bought),
          lastServiceDate: Value(bought),
        ),
      );
      final doc = (await h.one('equipment', 'mine'))!;
      expect(doc['purchase_date'], '2023-06-15');
      expect(doc['last_service_date'], '2023-06-15');
    });

    test('attributes are in the document', () async {
      final doc = (await h.one('equipment', 'mine'))!;
      final attribute = (doc['attributes'] as List).cast<Map>().single;
      expect(attribute['key'], 'size');
      expect(attribute['value_text'], 'M');
    });

    test('blocks arrive when named', () async {
      final doc = (await h.one(
        'equipment',
        'mine',
        include: [
          'service_records',
          'service_schedules',
          'components',
          'shares',
          'tags',
          'media',
          'location_moves',
          'observations',
          'fills',
          'transmitters',
        ],
      ))!;
      expect((doc['service_records'] as List), hasLength(1));
      expect((doc['service_schedules'] as List), hasLength(1));
      expect(
        (doc['components'] as List)
            .cast<Map>()
            .single['component_equipment_id'],
        'hose',
      );
      expect(doc['shares'], isEmpty);
      expect(doc['tags'], isEmpty);
      expect(doc['media'], isEmpty);
      expect((doc['location_moves'] as List), hasLength(1));
      expect((doc['observations'] as List), hasLength(1));
      expect((doc['fills'] as List), hasLength(1));
      expect(doc['transmitters'], isEmpty);
    });
  });

  group('equipment children', () {
    test('a share holder reads service records', () async {
      expect(await h.one('service_records', 'rec-lent'), isNotNull);
      expect(await h.one('service_records', 'rec-theirs'), isNull);
      expect((await h.list('service_records')).toSet(), {
        'rec-mine',
        'rec-lent',
      });
    });

    test('cost keeps its currency', () async {
      final doc = (await h.one('service_records', 'rec-mine'))!;
      expect(doc['cost'], 120.0);
      expect(doc['currency'], 'USD');
      expect(doc['service_date'], '2024-03-01');
    });

    for (final (entity, own, other) in [
      ('service_schedules', 'sch-mine', 'sch-theirs'),
      ('equipment_observations', 'obs-mine', 'obs-theirs'),
      ('equipment_location_moves', 'mv-mine', 'mv-theirs'),
    ]) {
      test('$entity reads by id and stops at the profile', () async {
        expect((await h.one(entity, own))!['equipment_id'], 'mine');
        expect(await h.one(entity, other), isNull);
      });

      test('$entity lists by equipment', () async {
        expect(await h.list(entity, parentId: 'mine'), [own]);
        expect(await h.list(entity, parentId: 'theirs'), isEmpty);
      });
    }

    test('schedules carry their intervals', () async {
      final doc = (await h.one('service_schedules', 'sch-mine'))!;
      expect(doc['interval_days'], 365);
      expect(doc['exposure_intervals'], isEmpty);
    });

    test('components list by parent', () async {
      expect(await h.list('equipment_components', parentId: 'mine'), ['comp']);
      expect((await h.one('equipment_components', 'comp'))!['role'], '');
    });

    test('shares read for the item', () async {
      expect(await h.list('equipment_shares', parentId: 'lent'), ['share']);
      expect((await h.one('equipment_shares', 'share'))!['diver_id'], kDiverA);
    });
  });

  group('owned gear records', () {
    test('sets carry their items only when asked', () async {
      final bare = (await h.one('equipment_sets', 'set-a'))!;
      expect(bare['equipment_ids'], ['mine']);
      expect(bare.containsKey('geofences'), isFalse);
      final doc = (await h.one(
        'equipment_sets',
        'set-a',
        include: ['items', 'geofences'],
      ))!;
      expect((doc['items'] as List).cast<Map>().single['id'], 'mine');
      expect(doc['geofences'], isEmpty);
      expect(await h.one('equipment_sets', 'set-b'), isNull);
    });

    test('a cylinder config folds its items in', () async {
      final doc = (await h.one(
        'cylinder_configs',
        'cfg-a',
        include: ['items'],
      ))!;
      final item = (doc['items'] as List).cast<Map>().single;
      expect(item['volume_l'], 12.0);
      expect(item['o2_fraction'], closeTo(0.32, 1e-9));
    });

    test('a transmitter carries unit-named sizes', () async {
      final doc = (await h.one('transmitters', 'tx-a'))!;
      expect(doc['volume_l'], 12.0);
      expect(doc['role'], 'backGas');
    });

    test('fills follow visible cylinders', () async {
      final fill = (await h.one('cylinder_fills', 'fill-lent'))!;
      expect(fill['pressure_bar'], 200.0);
      expect(fill['o2_fraction'], closeTo(0.32, 1e-9));
      expect(await h.one('cylinder_fills', 'fill-theirs'), isNull);
    });

    test('scope matches getAllVisibleTo for fills', () async {
      final expected = {
        for (final f in await CylinderFillRepository().getAllVisibleTo(kDiverA))
          f.id,
      };
      expect((await h.list('cylinder_fills')).toSet(), expected);
      expect(expected, {'fill-mine', 'fill-lent', 'fill-loose'});
    });

    test('scope matches getAllSets', () async {
      final expected = {
        for (final s in await EquipmentSetRepository().getAllSets(
          diverId: kDiverA,
        ))
          s.id,
      };
      expect((await h.list('equipment_sets')).toSet(), expected);
    });

    test('scope matches getLocations', () async {
      final expected = {
        for (final l in await EquipmentLocationRepository().getLocations(
          diverId: kDiverA,
        ))
          l.id,
      };
      expect((await h.list('equipment_locations')).toSet(), expected);
      expect(expected, {'loc-a', 'loc-none'});
    });

    test('scope matches getAllKinds', () async {
      final expected = {
        for (final k in await ServiceKindRepository().getAllKinds(
          diverId: kDiverA,
        ))
          k.id,
      };
      expect((await h.list('service_kinds')).toSet(), expected);
    });

    test('scope matches getForDiver for transmitters', () async {
      final expected = {
        for (final x in await TransmitterRepository().getForDiver(kDiverA))
          x.id,
      };
      expect((await h.list('transmitters')).toSet(), expected);
    });

    test('scope matches getAllConfigs', () async {
      final expected = {
        for (final c in await CylinderConfigRepository().getAllConfigs(
          diverId: kDiverA,
        ))
          c.id,
      };
      expect((await h.list('cylinder_configs')).toSet(), expected);
    });
  });
}
