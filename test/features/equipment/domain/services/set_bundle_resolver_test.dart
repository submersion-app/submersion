import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

final _t = DateTime(2026, 11, 1);

EquipmentSet _set(
  String id, {
  String? diverId = 'd1',
  List<String> gear = const [],
  List<String> includes = const [],
  List<String> presets = const [],
  List<String> configs = const [],
}) => EquipmentSet(
  id: id,
  diverId: diverId,
  name: id,
  equipmentIds: gear,
  includedSetIds: includes,
  weightPresetIds: presets,
  cylinderConfigIds: configs,
  createdAt: _t,
  updatedAt: _t,
);

WeightPreset _preset(String id, List<(WeightType, double, String)> rows) =>
    WeightPreset(
      id: id,
      diverId: 'd1',
      displayName: id,
      notes: '',
      sortOrder: 0,
      createdAt: _t,
      updatedAt: _t,
      entries: [
        for (final (i, (type, kg, label)) in rows.indexed)
          WeightPresetEntry(
            id: '$id-$i',
            presetId: id,
            weightType: type,
            amountKg: kg,
            label: label,
            sortOrder: i,
          ),
      ],
    );

CylinderConfig _config(String id, List<(TankRole, double)> cylinders) =>
    CylinderConfig(
      id: id,
      diverId: 'd1',
      name: id,
      createdAt: _t,
      updatedAt: _t,
      items: [
        for (final (i, (role, volume)) in cylinders.indexed)
          CylinderConfigItem(
            id: '$id-$i',
            configId: id,
            sortOrder: i,
            tankRole: role,
            volumeL: volume,
            createdAt: _t,
            updatedAt: _t,
          ),
      ],
    );

Map<String, T> _byId<T>(Iterable<T> items, String Function(T) id) => {
  for (final item in items) id(item): item,
};

void main() {
  final base6 = _preset('base6', [(WeightType.backplate, 2.72, 'Pockets')]);
  final belt6 = _preset('belt6', [(WeightType.belt, 2.72, '')]);
  final al80 = _config('al80', [(TankRole.backGas, 11.1)]);
  final stage = _config('stage', [(TankRole.deco, 5.7)]);
  final presets = _byId([base6, belt6], (p) => p.id);
  final configs = _byId([al80, stage], (c) => c.id);

  group('resolve', () {
    final rig = _set(
      'rig',
      gear: ['bp', 'reg'],
      presets: ['base6'],
      configs: ['al80'],
    );
    final outer = _set(
      'outer',
      gear: ['cam'],
      includes: ['rig'],
      presets: ['belt6'],
      configs: ['stage'],
    );
    final sets = _byId([rig, outer], (s) => s.id);

    test('puts included sets first, then own lists', () {
      final bundle = SetBundleResolver.resolve(
        outer,
        setsById: sets,
        presetsById: presets,
        configsById: configs,
      );
      expect(bundle.setId, 'outer');
      expect(bundle.gearIds, ['bp', 'reg', 'cam']);
      expect(bundle.weights.map((w) => w.weightType), [
        WeightType.backplate,
        WeightType.belt,
      ]);
      expect(bundle.weights.first.label, 'Pockets');
      expect(bundle.totalWeightKg, closeTo(5.44, 1e-9));
      expect(bundle.cylinders.map((c) => c.tankRole), [
        TankRole.backGas,
        TankRole.deco,
      ]);
      expect(bundle.isEmpty, isFalse);
      expect(bundle.hasGear, isTrue);
    });

    test('removes duplicate gear', () {
      final dup = _set('dup', gear: ['reg', 'cam'], includes: ['rig']);
      final bundle = SetBundleResolver.resolve(
        dup,
        setsById: _byId([rig, dup], (s) => s.id),
        presetsById: presets,
        configsById: configs,
      );
      expect(bundle.gearIds, ['bp', 'reg', 'cam']);
    });

    test('counts a preset reached twice twice', () {
      final twice = _set('twice', includes: ['rig'], presets: ['base6']);
      final bundle = SetBundleResolver.resolve(
        twice,
        setsById: _byId([rig, twice], (s) => s.id),
        presetsById: presets,
        configsById: configs,
      );
      expect(bundle.weights, hasLength(2));
      expect(bundle.totalWeightKg, closeTo(5.44, 1e-9));
    });

    test('renumbers cylinder sortOrder across configurations', () {
      final doubles = _config('doubles', [
        (TankRole.backGas, 12),
        (TankRole.backGas, 12),
      ]);
      final both = _set('both', configs: ['doubles', 'stage']);
      final bundle = SetBundleResolver.resolve(
        both,
        setsById: _byId([both], (s) => s.id),
        presetsById: presets,
        configsById: _byId([doubles, stage], (c) => c.id),
      );
      expect(bundle.cylinders.map((c) => c.sortOrder), [0, 1, 2]);
      expect(bundle.cylinders.last.tankRole, TankRole.deco);
    });

    test('ignores unknown ids and deeper includes', () {
      final deep = _set('deep', gear: ['deepGear']);
      final middle = _set(
        'middle',
        gear: ['mid'],
        includes: ['deep'],
        presets: ['base6'],
      );
      final top = _set(
        'top',
        gear: ['own'],
        includes: ['middle', 'gone'],
        presets: ['missing'],
        configs: ['missing'],
      );
      final bundle = SetBundleResolver.resolve(
        top,
        setsById: _byId([deep, middle, top], (s) => s.id),
        presetsById: presets,
        configsById: configs,
      );
      // middle's own lists count; what middle includes does not.
      expect(bundle.gearIds, ['mid', 'own']);
      expect(bundle.weights, hasLength(1));
      expect(bundle.cylinders, isEmpty);
    });

    test('a set that includes itself does not loop', () {
      final loop = _set('loop', gear: ['g'], includes: ['loop']);
      final bundle = SetBundleResolver.resolve(
        loop,
        setsById: _byId([loop], (s) => s.id),
        presetsById: presets,
        configsById: configs,
      );
      expect(bundle.gearIds, ['g']);
    });

    test('a set with nothing resolves to an empty bundle', () {
      final empty = _set('empty');
      final bundle = SetBundleResolver.resolve(
        empty,
        setsById: _byId([empty], (s) => s.id),
        presetsById: presets,
        configsById: configs,
      );
      expect(bundle.isEmpty, isTrue);
      expect(bundle.hasGear, isFalse);
      expect(bundle.totalWeightKg, 0);
    });

    test('toDiveWeights gives each entry a fresh id on the dive', () {
      final bundle = SetBundleResolver.resolve(
        outer,
        setsById: sets,
        presetsById: presets,
        configsById: configs,
      );
      var n = 0;
      final weights = bundle.toDiveWeights(
        diveId: 'dive1',
        newId: () => 'w${n++}',
      );
      expect(weights.map((w) => w.id), ['w0', 'w1']);
      expect(weights.every((w) => w.diveId == 'dive1'), isTrue);
      expect(weights.first.label, 'Pockets');
      expect(weights.first.amountKg, 2.72);
    });
  });

  group('effectiveGearIds', () {
    test('is included gear then own gear, without duplicates', () {
      final rig = _set('rig', gear: ['bp', 'reg']);
      final outer = _set('outer', gear: ['reg', 'cam'], includes: ['rig']);
      expect(
        SetBundleResolver.effectiveGearIds(outer, {'rig': rig, 'outer': outer}),
        ['bp', 'reg', 'cam'],
      );
    });
  });

  group('absorb', () {
    final rig = _set('rig');
    final outer = _set('outer', includes: ['rig']);
    final other = _set('other');

    test('drops a set another landing set includes', () {
      expect(SetBundleResolver.absorb([rig, outer]).map((s) => s.id), [
        'outer',
      ]);
      expect(SetBundleResolver.absorb([outer, rig]).map((s) => s.id), [
        'outer',
      ]);
    });

    test('keeps unrelated sets in order', () {
      expect(SetBundleResolver.absorb([other, rig]).map((s) => s.id), [
        'other',
        'rig',
      ]);
    });

    // Sync can leave two sets including each other. Dropping both would
    // apply neither bundle; the lower id stands, whatever the order.
    test('of two sets that include each other, the lower id stands', () {
      final a = _set('a', includes: ['b']);
      final b = _set('b', includes: ['a']);
      expect(SetBundleResolver.absorb([a, b]).map((s) => s.id), ['a']);
      expect(SetBundleResolver.absorb([b, a]).map((s) => s.id), ['a']);
    });
  });

  group('canInclude', () {
    final plain = _set('plain');
    final outer = _set('outer', includes: ['plain']);
    final other = _set('other');
    final foreign = _set('foreign', diverId: 'd2');
    final all = [plain, outer, other, foreign];

    test('allows a plain set of the same diver', () {
      expect(SetBundleResolver.canInclude(other, plain, all), isTrue);
    });

    test('refuses itself', () {
      expect(SetBundleResolver.canInclude(other, other, all), isFalse);
    });

    test('refuses a candidate that has includes', () {
      expect(SetBundleResolver.canInclude(other, outer, all), isFalse);
    });

    test('refuses when another set already includes the outer set', () {
      expect(SetBundleResolver.canInclude(plain, other, all), isFalse);
    });

    test('refuses a set of another diver', () {
      expect(SetBundleResolver.canInclude(other, foreign, all), isFalse);
    });
  });

  group('outerSetsOf', () {
    test('lists the sets that include a set', () {
      final rig = _set('rig');
      final a = _set('a', includes: ['rig']);
      final b = _set('b');
      expect(
        SetBundleResolver.outerSetsOf('rig', [rig, a, b]).map((s) => s.id),
        ['a'],
      );
    });
  });

  group('sameWeights', () {
    const drafts = <WeightEntryDraft>[
      (weightType: WeightType.belt, amountKg: 2.72, notes: '', label: 'Belt'),
      (weightType: WeightType.backplate, amountKg: 1, notes: 'n', label: ''),
    ];
    DiveWeight onDive(WeightEntryDraft d, String id) => DiveWeight(
      id: id,
      diveId: 'dive1',
      weightType: d.weightType,
      amountKg: d.amountKg,
      notes: d.notes,
      label: d.label,
    );

    test('is true for the same entries in order, whatever their ids', () {
      expect(
        SetBundleResolver.sameWeights([
          onDive(drafts[0], 'x'),
          onDive(drafts[1], 'y'),
        ], drafts),
        isTrue,
      );
    });

    test('is false for a different amount, order or length', () {
      expect(
        SetBundleResolver.sameWeights([
          onDive(drafts[0], 'x').copyWith(amountKg: 3),
          onDive(drafts[1], 'y'),
        ], drafts),
        isFalse,
      );
      expect(
        SetBundleResolver.sameWeights([
          onDive(drafts[1], 'y'),
          onDive(drafts[0], 'x'),
        ], drafts),
        isFalse,
      );
      expect(
        SetBundleResolver.sameWeights([onDive(drafts[0], 'x')], drafts),
        isFalse,
      );
    });

    test('two empty lists match', () {
      expect(SetBundleResolver.sameWeights(const [], const []), isTrue);
    });
  });
}
