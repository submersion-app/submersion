import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/tank_preset_size_match.dart';

/// Whether two sizes are one cylinder, and which of the diver's own presets a
/// cylinder still is (issue #800).
void main() {
  group('isSameCylinderSize', () {
    test('the same size, or one a unit conversion left a hair off', () {
      expect(isSameCylinderSize(11.1, 206.843, 11.1, 206.843), isTrue);
      expect(
        isSameCylinderSize(11.099999999999998, 206.84299, 11.1, 206.843),
        isTrue,
      );
      // 3000 psi typed back is 206.8427 bar.
      expect(isSameCylinderSize(11.1, 206.8427, 11.1, 206.843), isTrue);
    });

    test('a different volume or working pressure is another cylinder', () {
      expect(isSameCylinderSize(12, 206.843, 11.1, 206.843), isFalse);
      expect(isSameCylinderSize(11.1, 232, 11.1, 206.843), isFalse);
    });
  });

  group('ownPresetFor', () {
    final copy = TankPresetEntity.create(
      id: 'c1',
      name: 'al80_copy',
      displayName: 'AL80 (copy)',
      volumeLiters: 11.1,
      workingPressureBar: 206.843,
      material: TankMaterial.aluminum,
      ratedCapacityCuft: 77.4,
    );
    final builtIn = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);

    test('finds the diver\'s preset of that name and size', () {
      expect(ownPresetFor('al80_copy', 11.1, 206.8427, [builtIn, copy]), copy);
    });

    test('not when the size changed since, nor a built-in, nor nothing', () {
      expect(ownPresetFor('al80_copy', 12, 206.843, [copy]), isNull);
      expect(ownPresetFor('al80', 11.1, 206.843, [builtIn]), isNull);
      expect(ownPresetFor(null, 11.1, 206.843, [copy]), isNull);
      expect(ownPresetFor('al80_copy', null, 206.843, [copy]), isNull);
      expect(ownPresetFor('al80_copy', 11.1, 206.843, null), isNull);
    });
  });
}
