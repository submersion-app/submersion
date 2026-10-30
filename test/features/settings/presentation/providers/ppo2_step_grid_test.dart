import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('SettingsNotifier step grids (issue #3580)', () {
    test('every ppO2 band grid point is the exact nearest double, with no '
        'float noise from multiplying by the step', () {
      for (var tenths = 12; tenths <= 16; tenths++) {
        // Slider-style interpolation, which lands a hair off the grid.
        final interpolated = 1.2 + (tenths - 12) * 0.1;
        expect(
          SettingsNotifier.ppO2DecoBandOnGrid(interpolated),
          tenths / 10.0,
          reason: 'band at $tenths tenths',
        );
      }
    });

    test('ppO2 bands clamp to the selectable range', () {
      expect(SettingsNotifier.ppO2DecoBandOnGrid(0.9), 1.2);
      expect(SettingsNotifier.ppO2DecoBandOnGrid(1.9), 1.6);
    });

    test('the floor variants round down, never up, onto exact grid points', () {
      expect(SettingsNotifier.ppO2DecoBandFloorOnGrid(1.55), 1.5);
      expect(SettingsNotifier.ppO2DecoBandFloorOnGrid(1.4), 1.4);
      // Float noise just under a grid line stays on it.
      expect(SettingsNotifier.ppO2DecoBandFloorOnGrid(1.2 + 0.1 * 2), 1.4);
      expect(SettingsNotifier.maxO2DepthFloorOnGrid(5.8), 5.5);
      expect(SettingsNotifier.maxO2DepthFloorOnGrid(6.0), 6.0);
    });

    test('the explicit O2 depth snaps to exact half meters', () {
      expect(SettingsNotifier.maxO2DepthOnGrid(4.4), 4.5);
      expect(SettingsNotifier.maxO2DepthOnGrid(6.2), 6.0);
      expect(SettingsNotifier.maxO2DepthOnGrid(12), 9.0);
    });
  });
}
