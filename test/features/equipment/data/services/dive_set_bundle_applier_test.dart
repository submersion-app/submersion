import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/dive_set_bundle_applier.dart';

import '../../../../helpers/test_database.dart';

/// Applying a set's weights and cylinders to a saved dive with nobody
/// watching (issue #4525): imports, bulk edit and rules. It fills what is
/// missing and never touches what a diver or a dive computer recorded.
void main() {
  late AppDatabase db;
  late DiveSetBundleApplier applier;
  const t = 1700000000000;

  Future<void> set(
    String id, {
    String? name,
    List<String> gear = const [],
    List<String> includes = const [],
    List<String> presets = const [],
    List<String> configs = const [],
  }) async {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            diverId: const Value('d1'),
            name: name ?? id,
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final g in gear) {
      await db
          .into(db.equipmentSetItems)
          .insert(EquipmentSetItemsCompanion.insert(setId: id, equipmentId: g));
    }
    for (final (i, ref) in includes.indexed) {
      await db
          .into(db.equipmentSetIncludes)
          .insert(
            EquipmentSetIncludesCompanion.insert(
              id: '$id-i$i',
              setId: id,
              includedSetId: ref,
              sortOrder: Value(i),
              createdAt: t,
            ),
          );
    }
    for (final (i, ref) in presets.indexed) {
      await db
          .into(db.equipmentSetWeightPresets)
          .insert(
            EquipmentSetWeightPresetsCompanion.insert(
              id: '$id-p$i',
              setId: id,
              presetId: ref,
              sortOrder: Value(i),
              createdAt: t,
            ),
          );
    }
    for (final (i, ref) in configs.indexed) {
      await db
          .into(db.equipmentSetCylinderConfigs)
          .insert(
            EquipmentSetCylinderConfigsCompanion.insert(
              id: '$id-c$i',
              setId: id,
              configId: ref,
              sortOrder: Value(i),
              createdAt: t,
            ),
          );
    }
  }

  Future<void> preset(String id, double kg, {String type = 'belt'}) async {
    await db
        .into(db.weightPresets)
        .insert(
          WeightPresetsCompanion.insert(
            id: id,
            displayName: id,
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.weightPresetEntries)
        .insert(
          WeightPresetEntriesCompanion.insert(
            id: '$id-e',
            presetId: id,
            weightType: type,
            amountKg: kg,
            createdAt: t,
          ),
        );
  }

  /// A configuration of (role, litres, O2 %) cylinders.
  Future<void> config(String id, List<(String, double, double)> items) async {
    await db
        .into(db.cylinderConfigs)
        .insert(
          CylinderConfigsCompanion.insert(
            id: id,
            name: id,
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final (i, (role, volume, o2)) in items.indexed) {
      await db
          .into(db.cylinderConfigItems)
          .insert(
            CylinderConfigItemsCompanion.insert(
              id: '$id-$i',
              configId: id,
              sortOrder: Value(i),
              tankRole: role,
              volumeL: Value(volume),
              o2Percent: Value(o2),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  }

  Future<void> dive(String id, {double? legacyWeightKg}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          diveDateTime: t,
          weightAmount: Value(legacyWeightKg),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> tank(
    String id,
    String diveId, {
    String role = 'backGas',
    double? volume,
    double o2 = 21,
    int order = 0,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          tankRole: Value(role),
          volume: Value(volume),
          o2Percent: Value(o2),
          tankOrder: Value(order),
        ),
      );

  Future<void> weight(String id, String diveId, double kg) => db
      .into(db.diveWeights)
      .insert(
        DiveWeightsCompanion.insert(
          id: id,
          diveId: diveId,
          weightType: 'belt',
          amountKg: kg,
          createdAt: t,
        ),
      );

  Future<void> gearOn(String diveId, String equipmentId, String? setId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(
          diveId: diveId,
          equipmentId: equipmentId,
          viaSetId: Value(setId),
        ),
      );

  Future<List<double>> weightsOf(String diveId) async {
    final rows = await (db.select(
      db.diveWeights,
    )..where((w) => w.diveId.equals(diveId))).get();
    return [for (final r in rows) r.amountKg]..sort();
  }

  Future<List<DiveTank>> tanksOf(String diveId) =>
      (db.select(db.diveTanks)
            ..where((x) => x.diveId.equals(diveId))
            ..orderBy([(x) => OrderingTerm.asc(x.tankOrder)]))
          .get();

  Future<Map<String, String?>> tagsOf(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId: r.viaSetId};
  }

  setUp(() async {
    db = await setUpTestDatabase();
    applier = DiveSetBundleApplier();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['bp', 'reg', 'cam']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              diverId: const Value('d1'),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await preset('belt8', 3.63);
    await preset('pockets6', 2.72, type: 'backplate');
    await config('al80', [('backGas', 11.1, 32)]);
    await config('withDeco', [('backGas', 11.1, 32), ('deco', 5.7, 50)]);
    await dive('dive1');
  });
  tearDown(tearDownTestDatabase);

  test('fills weights and inserts cylinders on a dive with neither', () async {
    await set('rig', presets: ['belt8'], configs: ['withDeco']);
    final changed = await applier.apply(diveId: 'dive1', setIds: ['rig']);
    expect(changed, (weights: true, tanks: true));
    expect(await weightsOf('dive1'), [closeTo(3.63, 1e-9)]);
    final tanks = await tanksOf('dive1');
    expect(tanks.map((x) => x.tankRole), ['backGas', 'deco']);
    expect(tanks.map((x) => x.o2Percent), [32, 50]);
    expect(tanks.map((x) => x.tankOrder), [0, 1]);
  });

  test('leaves weights alone when the dive has weight rows', () async {
    await set('rig', presets: ['belt8']);
    await weight('w1', 'dive1', 5);
    final changed = await applier.apply(diveId: 'dive1', setIds: ['rig']);
    expect(changed.weights, isFalse);
    expect(await weightsOf('dive1'), [5]);
  });

  test('a positive legacy weight_amount blocks the fill', () async {
    await set('rig', presets: ['belt8']);
    await dive('legacy', legacyWeightKg: 4);
    await dive('zero', legacyWeightKg: 0);
    expect(
      (await applier.apply(diveId: 'legacy', setIds: ['rig'])).weights,
      isFalse,
    );
    expect(await weightsOf('legacy'), isEmpty);
    // Zero is "none recorded".
    expect(
      (await applier.apply(diveId: 'zero', setIds: ['rig'])).weights,
      isTrue,
    );
  });

  test('with tanks present it fills a missing size and inserts '
      'nothing', () async {
    await set('rig', configs: ['withDeco']);
    await tank('t1', 'dive1');
    final changed = await applier.apply(diveId: 'dive1', setIds: ['rig']);
    expect(changed.tanks, isTrue);
    final tanks = await tanksOf('dive1');
    expect(tanks, hasLength(1));
    expect(tanks.single.volume, closeTo(11.1, 1e-9));
  });

  test('it never changes a gas mix or a size that is already set', () async {
    await set('rig', configs: ['al80']);
    await tank('t1', 'dive1', volume: 15, o2: 21);
    final changed = await applier.apply(diveId: 'dive1', setIds: ['rig']);
    expect(changed.tanks, isFalse);
    final only = (await tanksOf('dive1')).single;
    expect(only.volume, 15);
    expect(only.o2Percent, 21);
  });

  test('two sets landing together combine their weights in order', () async {
    await set('rig', presets: ['belt8']);
    await set('extra', presets: ['pockets6']);
    await applier.apply(diveId: 'dive1', setIds: ['rig', 'extra']);
    expect(await weightsOf('dive1'), [
      closeTo(2.72, 1e-9),
      closeTo(3.63, 1e-9),
    ]);
  });

  test('an included set landing with its outer set is absorbed', () async {
    await set('rig', presets: ['belt8'], configs: ['al80']);
    await set('outer', includes: ['rig'], presets: ['pockets6']);
    await applier.apply(diveId: 'dive1', setIds: ['rig', 'outer']);
    // The rig's belt once (through the outer set), then the outer pockets.
    expect(await weightsOf('dive1'), [
      closeTo(2.72, 1e-9),
      closeTo(3.63, 1e-9),
    ]);
    expect(await tanksOf('dive1'), hasLength(1));
  });

  test('applying twice changes nothing the second time', () async {
    await set('rig', presets: ['belt8'], configs: ['withDeco']);
    await applier.apply(diveId: 'dive1', setIds: ['rig']);
    final again = await applier.apply(diveId: 'dive1', setIds: ['rig']);
    expect(again, (weights: false, tanks: false));
    expect(await weightsOf('dive1'), hasLength(1));
    expect(await tanksOf('dive1'), hasLength(2));
  });

  test(
    'a set with nothing to carry, or an unknown set, does nothing',
    () async {
      await set('plain', gear: ['bp']);
      expect(await applier.apply(diveId: 'dive1', setIds: ['plain', 'nope']), (
        weights: false,
        tanks: false,
      ));
      expect(await applier.apply(diveId: 'dive1', setIds: const []), (
        weights: false,
        tanks: false,
      ));
    },
  );

  test('written rows are marked pending for sync', () async {
    await set('rig', presets: ['belt8'], configs: ['al80']);
    await applier.apply(diveId: 'dive1', setIds: ['rig']);
    final pending = await db
        .customSelect(
          "SELECT entity_type FROM sync_records WHERE sync_status = 'pending'",
        )
        .get();
    final types = {for (final r in pending) r.read<String>('entity_type')};
    expect(types, containsAll(['diveWeights', 'diveTanks']));
  });

  group('applyTagged', () {
    test('uses the sets tagged on the dive, lead set first, then by '
        'name', () async {
      await set('zeta', name: 'Zeta', gear: ['bp'], presets: ['belt8']);
      await set('alpha', name: 'Alpha', gear: ['reg'], presets: ['pockets6']);
      await set('lead', name: 'Lead', presets: ['belt8']);
      await gearOn('dive1', 'bp', 'zeta');
      await gearOn('dive1', 'reg', 'alpha');
      await applier.applyTagged(diveId: 'dive1', leadSetId: 'lead');
      final rows =
          await (db.select(db.diveWeights)
                ..where((w) => w.diveId.equals('dive1'))
                ..orderBy([(w) => OrderingTerm.asc(w.rowId)]))
              .get();
      // Lead (belt 3.63), Alpha (pockets 2.72), Zeta (belt 3.63).
      expect(rows.map((r) => r.amountKg), [
        closeTo(3.63, 1e-9),
        closeTo(2.72, 1e-9),
        closeTo(3.63, 1e-9),
      ]);
    });

    test('alsoSetIds names sets that landed without leaving a tag', () async {
      await set('zeta', name: 'Zeta', gear: ['bp'], presets: ['belt8']);
      await set('alpha', name: 'Alpha', gear: ['bp'], presets: ['pockets6']);
      await gearOn('dive1', 'bp', 'zeta');
      await applier.applyTagged(
        diveId: 'dive1',
        alsoSetIds: const ['alpha', 'zeta'],
      );
      final rows =
          await (db.select(db.diveWeights)
                ..where((w) => w.diveId.equals('dive1'))
                ..orderBy([(w) => OrderingTerm.asc(w.rowId)]))
              .get();
      // Alpha (named first), then Zeta once: named and tagged.
      expect(rows.map((r) => r.amountKg), [
        closeTo(2.72, 1e-9),
        closeTo(3.63, 1e-9),
      ]);
    });

    test('with retagAbsorbed an included set\'s gear takes the outer '
        'set\'s tag', () async {
      await set('rig', gear: ['bp', 'reg'], presets: ['belt8']);
      await set('outer', gear: ['cam'], includes: ['rig']);
      await gearOn('dive1', 'bp', 'rig');
      await gearOn('dive1', 'reg', 'rig');
      await gearOn('dive1', 'cam', 'outer');
      await applier.applyTagged(diveId: 'dive1', retagAbsorbed: true);
      expect((await tagsOf('dive1')).values.toSet(), {'outer'});
      expect(await weightsOf('dive1'), [closeTo(3.63, 1e-9)]);
    });

    test('without retagAbsorbed the tags stay', () async {
      await set('rig', gear: ['bp'], presets: ['belt8']);
      await set('outer', gear: ['cam'], includes: ['rig']);
      await gearOn('dive1', 'bp', 'rig');
      await gearOn('dive1', 'cam', 'outer');
      await applier.applyTagged(diveId: 'dive1');
      expect(await tagsOf('dive1'), {'bp': 'rig', 'cam': 'outer'});
      // Still counted once.
      expect(await weightsOf('dive1'), [closeTo(3.63, 1e-9)]);
    });
  });

  group('swapWeights', () {
    setUp(() async {
      await set('def', presets: ['belt8']);
      await set('fenced', presets: ['pockets6']);
      await set('bare', gear: ['bp']);
    });

    test('replaces weights still exactly what the old set filled', () async {
      await applier.apply(diveId: 'dive1', setIds: ['def']);
      expect(
        await applier.swapWeights(
          diveId: 'dive1',
          fromSetId: 'def',
          toSetId: 'fenced',
        ),
        isTrue,
      );
      expect(await weightsOf('dive1'), [closeTo(2.72, 1e-9)]);
    });

    test('leaves weights the diver edited', () async {
      await weight('w1', 'dive1', 5);
      expect(
        await applier.swapWeights(
          diveId: 'dive1',
          fromSetId: 'def',
          toSetId: 'fenced',
        ),
        isFalse,
      );
      expect(await weightsOf('dive1'), [5]);
    });

    test('removes them when the new set has none', () async {
      await applier.apply(diveId: 'dive1', setIds: ['def']);
      expect(
        await applier.swapWeights(
          diveId: 'dive1',
          fromSetId: 'def',
          toSetId: 'bare',
        ),
        isTrue,
      );
      expect(await weightsOf('dive1'), isEmpty);
    });

    test('does nothing when the old set carried no weights', () async {
      expect(
        await applier.swapWeights(
          diveId: 'dive1',
          fromSetId: 'bare',
          toSetId: 'fenced',
        ),
        isFalse,
      );
      expect(await weightsOf('dive1'), isEmpty);
    });
  });
}
