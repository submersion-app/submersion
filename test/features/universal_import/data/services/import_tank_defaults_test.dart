import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/universal_import/data/services/import_tank_defaults.dart';

void main() {
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.al80);

  group('applyTankDefaults', () {
    test('fills missing volume from preset', () {
      final tank = <String, dynamic>{'startPressure': 200};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 11.1);
      expect(result['startPressure'], 200);
    });

    test('does not overwrite existing volume', () {
      final tank = <String, dynamic>{'volume': 15.0};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 15.0);
    });

    test('fills missing workingPressure from preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], closeTo(207, 1));
    });

    test('does not overwrite existing workingPressure', () {
      final tank = <String, dynamic>{'workingPressure': 234};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], 234);
    });

    test('fills missing material from preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['material'], TankMaterial.aluminum);
    });

    test('does not overwrite existing material', () {
      final tank = <String, dynamic>{'material': TankMaterial.steel};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['material'], TankMaterial.steel);
    });

    test('fills missing startPressure from defaultStartPressure', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 210,
      );
      expect(result['startPressure'], 210);
    });

    test('treats zero volume as missing', () {
      final tank = <String, dynamic>{'volume': 0.0};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 11.1);
    });

    test('treats zero workingPressure as missing', () {
      final tank = <String, dynamic>{'workingPressure': 0};
      final result = applyTankDefaults(
        tank,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(result['workingPressure'], closeTo(207, 1));
    });

    test('returns unmodified tank when no preset provided', () {
      final tank = <String, dynamic>{'volume': 15.0};
      final result = applyTankDefaults(
        tank,
        defaultPreset: null,
        defaultStartPressure: 200,
      );
      expect(result['volume'], 15.0);
      expect(result.containsKey('workingPressure'), false);
    });

    test('applies startPressure fallback even without preset', () {
      final tank = <String, dynamic>{};
      final result = applyTankDefaults(
        tank,
        defaultPreset: null,
        defaultStartPressure: 200,
      );
      expect(result['startPressure'], 200);
    });
  });

  group('applyTankDefaultsToList', () {
    test('applies defaults to all tanks in list', () {
      final tanks = [
        <String, dynamic>{'volume': 15.0},
        <String, dynamic>{},
      ];
      final results = applyTankDefaultsToList(
        tanks,
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(results[0]['volume'], 15.0);
      expect(results[1]['volume'], 11.1);
    });

    test('returns empty list for empty input', () {
      final results = applyTankDefaultsToList(
        [],
        defaultPreset: al80,
        defaultStartPressure: 200,
      );
      expect(results, isEmpty);
    });
  });
}
