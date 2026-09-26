import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/tank_preset_visibility.dart';

TankPresetEntity _custom(String name) => TankPresetEntity(
  id: name,
  diverId: 'd1',
  name: name,
  displayName: name,
  volumeLiters: 12,
  workingPressureBar: 232,
  material: TankMaterial.steel,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<TankPresetEntity> _all({List<TankPresetEntity> custom = const []}) => [
  ...custom,
  ...TankPresets.all.map(TankPresetEntity.fromBuiltIn),
];

List<String> _names(List<TankPresetEntity> presets) =>
    presets.map((p) => p.name).toList();

void main() {
  group('visibleTankPresets', () {
    test('returns the list unchanged when nothing is hidden', () {
      final all = _all(custom: [_custom('mine')]);
      expect(visibleTankPresets(all, const {}), same(all));
    });

    test('drops hidden built-in presets and keeps the order', () {
      final visible = visibleTankPresets(_all(), const {'al80', 'hp100'});
      expect(_names(visible), isNot(contains('al80')));
      expect(_names(visible), isNot(contains('hp100')));
      expect(
        _names(visible),
        TankPresets.all
            .map((p) => p.name)
            .where((n) => n != 'al80' && n != 'hp100')
            .toList(),
      );
    });

    test('never hides a custom preset that shares a built-in slug', () {
      final all = _all(custom: [_custom('al80')]);
      final visible = visibleTankPresets(all, const {'al80'});
      expect(visible.where((p) => p.name == 'al80').single.isBuiltIn, isFalse);
    });

    test('always keeps the default preset, even if marked hidden', () {
      final visible = visibleTankPresets(_all(), const {
        'al80',
        'steel12',
      }, defaultPresetName: 'steel12');
      expect(_names(visible), contains('steel12'));
      expect(_names(visible), isNot(contains('al80')));
    });

    test('ignores unknown names in the hidden set', () {
      final all = _all();
      expect(visibleTankPresets(all, const {'no-such-preset'}), hasLength(13));
    });

    test('can hide every built-in preset', () {
      final everything = TankPresets.all.map((p) => p.name).toSet();
      expect(visibleTankPresets(_all(), everything), isEmpty);
    });
  });

  group('withKeptTankPresets', () {
    test('returns the list unchanged when every kept name is present', () {
      final visible = _all();
      expect(withKeptTankPresets(visible, const ['al80', null]), same(visible));
    });

    test('restores a hidden built-in preset at its catalog position', () {
      final visible = visibleTankPresets(_all(), const {'al80'});
      final kept = withKeptTankPresets(visible, const ['al80']);
      expect(_names(kept), TankPresets.all.map((p) => p.name).toList());
    });

    test('keeps custom presets first', () {
      final visible = visibleTankPresets(
        _all(custom: [_custom('mine')]),
        const {'hp80'},
      );
      final kept = withKeptTankPresets(visible, const ['hp80']);
      expect(kept.first.name, 'mine');
      expect(_names(kept), contains('hp80'));
    });

    test('reuses the existing instances of the visible presets', () {
      final visible = visibleTankPresets(_all(), const {'al80'});
      final kept = withKeptTankPresets(visible, const ['al80']);
      final al100 = visible.firstWhere((p) => p.name == 'al100');
      expect(kept.firstWhere((p) => p.name == 'al100'), same(al100));
    });

    test('ignores null and names that are not built-in presets', () {
      final visible = visibleTankPresets(_all(), const {'al80'});
      expect(
        withKeptTankPresets(visible, const [null, 'unknown']),
        same(visible),
      );
    });
  });
}
