import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, CylinderConfigItem;
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/set_bundle_loader.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../../../../helpers/test_database.dart';

/// Loading a set's bundle from the database (issue #4525).
void main() {
  late AppDatabase db;
  late String base6;
  late String belt6;
  late String al80;
  final now = DateTime(2026, 11, 1);

  EquipmentSet set(
    String id, {
    List<String> gear = const [],
    List<String> includes = const [],
    List<String> presets = const [],
    List<String> configs = const [],
  }) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: id,
    equipmentIds: gear,
    includedSetIds: includes,
    weightPresetIds: presets,
    cylinderConfigIds: configs,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    final t = now.millisecondsSinceEpoch;
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
    final equipment = EquipmentRepository();
    for (final id in ['bp', 'reg', 'cam']) {
      await equipment.createEquipment(
        EquipmentItem(
          id: id,
          diverId: 'd1',
          name: id,
          type: EquipmentType.other,
        ),
        notify: false,
      );
    }
    final presets = WeightPresetRepository();
    base6 = (await presets.createPreset(
      diverId: 'd1',
      displayName: 'Base',
      entries: const [
        (
          weightType: WeightType.backplate,
          amountKg: 2.72,
          notes: '',
          label: 'Pockets',
        ),
      ],
    )).id;
    belt6 = (await presets.createPreset(
      diverId: 'd1',
      displayName: 'Belt',
      entries: const [
        (weightType: WeightType.belt, amountKg: 2.72, notes: '', label: ''),
      ],
    )).id;
    final configs = CylinderConfigRepository();
    al80 = await configs.createConfig(diverId: 'd1', name: 'AL80');
    await configs.saveItems(al80, [
      CylinderConfigItem(
        id: '',
        configId: al80,
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final sets = EquipmentSetRepository();
    await sets.createSet(
      set('rig', gear: ['bp', 'reg'], presets: [base6], configs: [al80]),
    );
    await sets.createSet(
      set('outer', gear: ['cam'], includes: ['rig'], presets: [belt6]),
    );
    await sets.createSet(set('lead', presets: [belt6]));
  });
  tearDown(tearDownTestDatabase);

  test('load resolves a set with its included set, presets and '
      'configurations', () async {
    final bundle = (await SetBundleLoader().loadOne('outer'))!;
    expect(bundle.setId, 'outer');
    expect(bundle.gearIds.toSet(), {'bp', 'reg', 'cam'});
    expect(bundle.weights.map((w) => w.weightType), [
      WeightType.backplate,
      WeightType.belt,
    ]);
    expect(bundle.totalWeightKg, closeTo(5.44, 1e-9));
    expect(bundle.cylinders, hasLength(1));
    expect(bundle.cylinders.single.o2Percent, 32);
  });

  test('load keeps the order asked for', () async {
    final bundles = await SetBundleLoader().load(['lead', 'rig']);
    expect(bundles.map((b) => b.setId), ['lead', 'rig']);
  });

  test('load absorbs an included set that is also requested', () async {
    final bundles = await SetBundleLoader().load(['rig', 'outer']);
    expect(bundles.map((b) => b.setId), ['outer']);
    // The inner set's lead counts once, inside the outer bundle.
    expect(bundles.single.totalWeightKg, closeTo(5.44, 1e-9));
  });

  test('load skips an unknown set id and an empty request', () async {
    expect(await SetBundleLoader().load(['nope']), isEmpty);
    expect(await SetBundleLoader().load(const []), isEmpty);
    expect(await SetBundleLoader().loadOne('nope'), isNull);
  });

  test('a set with only weights loads a bundle with no gear', () async {
    final bundle = (await SetBundleLoader().loadOne('lead'))!;
    expect(bundle.hasGear, isFalse);
    expect(bundle.isEmpty, isFalse);
  });

  group('providers', () {
    test('setBundleSummaryProvider counts gear, lead and cylinders', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final summary = (await container.read(
        setBundleSummaryProvider('outer').future,
      ))!;
      expect(summary.gearCount, 3);
      expect(summary.leadKg, closeTo(5.44, 1e-9));
      expect(summary.cylinderCount, 1);
      expect(
        await container.read(setBundleSummaryProvider('nope').future),
        isNull,
      );
    });

    test('setBundleProvider refreshes when a preset changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(setBundleProvider('lead'), (_, _) {});
      addTearDown(sub.close);
      expect(
        (await container.read(setBundleProvider('lead').future))!.totalWeightKg,
        closeTo(2.72, 1e-9),
      );

      await WeightPresetRepository().updatePreset(
        id: belt6,
        displayName: 'Belt',
        entries: const [
          (weightType: WeightType.belt, amountKg: 4, notes: '', label: ''),
        ],
      );
      // The change streams are debounced.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(
        (await container.read(setBundleProvider('lead').future))!.totalWeightKg,
        closeTo(4, 1e-9),
      );
    });
  });
}
