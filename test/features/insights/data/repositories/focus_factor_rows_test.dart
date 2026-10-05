import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  const scale = VisibilityScale.tropical;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> dive(
    String id, {
    int day = 1,
    bool excluded = false,
    bool planned = false,
    double? maxDepth = 20,
    int? runtime = 2700,
    int? bottomTime = 2400,
    String? diverRole,
    String? buddy,
    double? visibilityMeters,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              DateTime.utc(2025, 3, day, 9).millisecondsSinceEpoch,
            ),
            maxDepth: Value(maxDepth),
            avgDepth: const Value(12),
            runtime: Value(runtime),
            bottomTime: Value(bottomTime),
            waterTemp: const Value(24),
            weightAmount: const Value(6),
            diverRole: Value(diverRole),
            buddy: Value(buddy),
            visibilityMeters: Value(visibilityMeters),
            excludedFromStats: Value(excluded),
            isPlanned: Value(planned),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> tank(
    String diveId,
    int order,
    double volume,
    double o2, [
    double he = 0,
  ]) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('t-$diveId-$order'),
          diveId: Value(diveId),
          volume: Value(volume),
          o2Percent: Value(o2),
          hePercent: Value(he),
          tankOrder: Value(order),
        ),
      );

  test('excluded and planned dives are out of scope', () async {
    await dive('in');
    await dive('out', excluded: true);
    await dive('plan', planned: true);
    final result = await repository.getFocusFactorRows(visibilityScale: scale);
    expect(result.map((r) => r.diveId), ['in']);
  });

  test('duration prefers runtime and falls back to bottom time', () async {
    await dive('rt', runtime: 3000, bottomTime: 2400);
    await dive('bt', day: 2, runtime: null, bottomTime: 1800);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['rt']!.durationMinutes, 50);
    expect(byId['bt']!.durationMinutes, 30);
  });

  test('gas class and first tank follow the tanks', () async {
    await dive('air');
    await tank('air', 0, 11.1, 21);
    await dive('nx', day: 2);
    await tank('nx', 1, 7, 50);
    await tank('nx', 0, 12, 32);
    await dive('tx', day: 3);
    await tank('tx', 0, 24, 18, 45);
    await dive('none', day: 4);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['air']!.gasClass, 'air');
    expect(byId['nx']!.gasClass, 'nitrox');
    expect(byId['nx']!.firstTankVolume, 12);
    expect(byId['tx']!.gasClass, 'trimix');
    expect(byId['none']!.gasClass, isNull);
    expect(byId['none']!.firstTankVolume, isNull);
  });

  test('solo and buddy follow the social page rules', () async {
    await dive('solo', diverRole: DiveRole.soloId);
    await dive('buddy', day: 2, buddy: 'Sam Lee');
    await dive('unknown', day: 3);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['solo']!.buddyKey, 'solo');
    expect(byId['buddy']!.buddyKey, 'buddy');
    expect(byId['unknown']!.buddyKey, isNull);
  });

  test('visibility uses the diver scale bands', () async {
    await dive('clear', visibilityMeters: 40);
    await dive('none', day: 2);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['clear']!.visibilityKey, 'excellent');
    expect(byId['none']!.visibilityKey, isNull);
  });

  test('suits classify as drysuit, wetsuit thickness, or unknown', () async {
    final equipment = EquipmentRepository();
    final dives = DiveRepository();
    final wet = await equipment.createEquipment(
      EquipmentItem(
        id: 'w5',
        name: 'Wetsuit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'w5',
            key: 'thickness_mm',
            valueText: '5',
            valueNum: 5,
          ),
        ],
      ),
    );
    final dry = await equipment.createEquipment(
      const EquipmentItem(id: 'dry', name: 'Dry', type: EquipmentType.drysuit),
    );
    final bare = await equipment.createEquipment(
      const EquipmentItem(id: 'w?', name: 'Old', type: EquipmentType.wetsuit),
    );
    await dives.createDive(
      domain.Dive(
        id: 'wet',
        dateTime: DateTime(2025, 3, 1),
        gear: looseGear([wet]),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'dry',
        dateTime: DateTime(2025, 3, 2),
        gear: looseGear([dry, wet]),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'bare',
        dateTime: DateTime(2025, 3, 3),
        gear: looseGear([bare]),
      ),
    );
    await dives.createDive(
      domain.Dive(id: 'nosuit', dateTime: DateTime(2025, 3, 4)),
    );
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['wet']!.suitKey, 'wetsuit:5');
    expect(byId['dry']!.suitKey, 'drysuit');
    expect(byId['bare']!.suitKey, 'unknown');
    expect(byId['nosuit']!.suitKey, isNull);
  });

  test('the Insights filter applies', () async {
    await dive('shallow', maxDepth: 8);
    await dive('deep', day: 2, maxDepth: 30);
    final result = await repository.getFocusFactorRows(
      visibilityScale: scale,
      filter: const DiveFilterState(minDepth: 15),
    );
    expect(result.map((r) => r.diveId), ['deep']);
  });

  test(
    'weight sums the dive weight rows and falls back to the legacy column',
    () async {
      await dive('rows');
      for (final (id, kg) in [('w1', 4.0), ('w2', 3.0)]) {
        await db
            .into(db.diveWeights)
            .insert(
              DiveWeightsCompanion(
                id: Value(id),
                diveId: const Value('rows'),
                weightType: const Value('belt'),
                amountKg: Value(kg),
                createdAt: const Value(0),
              ),
            );
      }
      await dive('legacy', day: 2);
      final byId = {
        for (final r in await repository.getFocusFactorRows(
          visibilityScale: scale,
        ))
          r.diveId: r,
      };
      expect(byId['rows']!.weight, 7);
      // The helper sets the retired weight_amount column to 6 kg.
      expect(byId['legacy']!.weight, 6);
    },
  );

  test(
    'duration falls back to entry and exit times like the dive page',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = DateTime.utc(2025, 3, 9, 9).millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('timed'),
              diveDateTime: Value(entry),
              entryTime: Value(entry),
              exitTime: Value(entry + 52 * 60 * 1000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final byId = {
        for (final r in await repository.getFocusFactorRows(
          visibilityScale: scale,
        ))
          r.diveId: r,
      };
      expect(byId['timed']!.durationMinutes, 52);
    },
  );

  test('dive types come from every linked type', () async {
    await dive('multi');
    await dive('none', day: 2);
    for (final (id, type) in [('t1', 'reef'), ('t2', 'night')]) {
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion(
              id: Value(id),
              diveId: const Value('multi'),
              diveTypeId: Value(type),
              createdAt: const Value(0),
            ),
          );
    }
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: scale,
      ))
        r.diveId: r,
    };
    expect(byId['multi']!.diveTypes, unorderedEquals(['reef', 'night']));
    expect(byId['none']!.diveTypes, isEmpty);
  });
}
