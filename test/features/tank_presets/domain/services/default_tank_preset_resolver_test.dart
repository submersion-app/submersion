import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';

void main() {
  group('DefaultTankPresetResolver', () {
    test('resolves built-in preset by name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve('al80');
      expect(result, isNotNull);
      expect(result!.name, 'al80');
      expect(result.volumeLiters, 11.1);
      expect(result.workingPressureBar, closeTo(207, 1));
    });

    test('returns null for unknown preset name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve('nonexistent');
      expect(result, isNull);
    });

    test('returns null for null preset name', () async {
      final resolver = DefaultTankPresetResolver();
      final result = await resolver.resolve(null);
      expect(result, isNull);
    });

    test('resolves all built-in presets', () async {
      final resolver = DefaultTankPresetResolver();
      for (final preset in TankPresets.all) {
        final result = await resolver.resolve(preset.name);
        expect(result, isNotNull, reason: 'Failed to resolve ${preset.name}');
        expect(result!.volumeLiters, preset.volumeLiters);
      }
    });
  });
}
