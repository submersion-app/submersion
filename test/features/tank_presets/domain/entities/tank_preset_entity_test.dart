import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

void main() {
  group('TankPresetEntity', () {
    group('volumeCuft', () {
      test('returns ratedCapacityCuft when available', () {
        final entity = TankPresetEntity(
          id: 'test',
          name: 'test',
          displayName: 'Test',
          volumeLiters: 11.1,
          workingPressureBar: 206.843,
          material: TankMaterial.aluminum,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          ratedCapacityCuft: 77.4,
        );
        expect(entity.volumeCuft, 77.4);
      });

      test('calculates from ideal gas when ratedCapacityCuft is null', () {
        final entity = TankPresetEntity(
          id: 'test',
          name: 'test',
          displayName: 'Test',
          volumeLiters: 12.0,
          workingPressureBar: 200.0,
          material: TankMaterial.steel,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
        // 12.0 * 200.0 / 28.3168 = 84.76
        expect(entity.volumeCuft, closeTo(84.76, 0.1));
      });
    });

    group('fromBuiltIn', () {
      test('copies ratedCapacityCuft from TankPreset', () {
        final entity = TankPresetEntity.fromBuiltIn(TankPresets.al80);
        expect(entity.ratedCapacityCuft, 77.4);
        expect(entity.volumeCuft, 77.4);
        expect(entity.volumeLiters, 11.1);
        expect(entity.workingPressureBar, closeTo(206.843, 0.001));
        expect(entity.isBuiltIn, isTrue);
      });

      test('metric tank has null ratedCapacityCuft', () {
        final entity = TankPresetEntity.fromBuiltIn(TankPresets.steel12);
        expect(entity.ratedCapacityCuft, isNull);
        // Falls back to ideal gas calculation
        expect(entity.volumeCuft, closeTo(84.76, 0.1));
      });
    });

    group('copyWith', () {
      test('preserves ratedCapacityCuft', () {
        final entity = TankPresetEntity.fromBuiltIn(TankPresets.hp100);
        final copy = entity.copyWith(description: 'updated');
        expect(copy.ratedCapacityCuft, 100.0);
        expect(copy.description, 'updated');
      });

      test('overrides ratedCapacityCuft', () {
        final entity = TankPresetEntity.fromBuiltIn(TankPresets.hp100);
        final copy = entity.copyWith(ratedCapacityCuft: 99.5);
        expect(copy.ratedCapacityCuft, 99.5);
      });
    });

    group('create factory', () {
      test('creates custom preset without ratedCapacityCuft', () {
        final entity = TankPresetEntity.create(
          id: 'custom-1',
          name: 'custom',
          displayName: 'Custom Tank',
          volumeLiters: 10.0,
          workingPressureBar: 200.0,
          material: TankMaterial.steel,
        );
        expect(entity.ratedCapacityCuft, isNull);
        expect(entity.isBuiltIn, isFalse);
        expect(entity.volumeCuft, closeTo(70.65, 0.1));
      });
    });

    group('equatable', () {
      test('ratedCapacityCuft is included in equality', () {
        final a = TankPresetEntity(
          id: 'test',
          name: 'test',
          displayName: 'Test',
          volumeLiters: 11.1,
          workingPressureBar: 207.0,
          material: TankMaterial.aluminum,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          ratedCapacityCuft: 77.4,
        );
        final b = TankPresetEntity(
          id: 'test',
          name: 'test',
          displayName: 'Test',
          volumeLiters: 11.1,
          workingPressureBar: 207.0,
          material: TankMaterial.aluminum,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          ratedCapacityCuft: 80.0,
        );
        expect(a, isNot(equals(b)));
      });
    });
  });
}
