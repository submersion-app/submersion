import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  required double depth,
  required double o2,
  double he = 0,
  double? altitude,
  WaterType? waterType,
}) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
  );
  container.read(calcDepthProvider.notifier).state = depth;
  container.read(calcO2Provider.notifier).state = o2;
  container.read(calcHeProvider.notifier).state = he;
  container.read(calcAltitudeProvider.notifier).state = altitude;
  container.read(calcWaterTypeProvider.notifier).state = waterType;
  return container;
}

void main() {
  // Issue #4299: the Gas Safety card read 1 bar and 10 m per bar while the
  // decompression result beside it used the selected altitude and water.
  group('calculator gas values follow the selected environment', () {
    test('EAN36 at 35 m in a 3000 m fresh-water lake', () {
      final container = _container(
        depth: 35,
        o2: 36,
        altitude: 3000,
        waterType: WaterType.fresh,
      );
      addTearDown(container.dispose);
      final env = container.read(calcEnvironmentProvider);

      final ppO2 = container.read(calcPpO2Provider);
      expect(ppO2, closeTo(env.pressureAtDepth(35) * 0.36, 1e-12));
      // The flat model read 1.62 bar, over the 1.6 bar danger line.
      expect(ppO2, lessThan(1.6));

      expect(
        container.read(calcMODProvider),
        closeTo(env.depthAtPressure(1.4 / 0.36), 1e-9),
      );
    });

    test('oxygen at 6 m in salt water below sea level', () {
      final container = _container(
        depth: 6,
        o2: 100,
        altitude: -430,
        waterType: WaterType.salt,
      );
      addTearDown(container.dispose);
      final env = container.read(calcEnvironmentProvider);

      final ppO2 = container.read(calcPpO2Provider);
      expect(ppO2, closeTo(env.pressureAtDepth(6), 1e-12));
      // The flat model read exactly 1.60 bar, under the danger line.
      expect(ppO2, greaterThan(1.6));
    });

    test('END of a trimix at altitude reads the same water', () {
      final container = _container(
        depth: 60,
        o2: 21,
        he: 35,
        altitude: 3000,
        waterType: WaterType.fresh,
      );
      addTearDown(container.dispose);
      final env = container.read(calcEnvironmentProvider);

      expect(
        container.read(calcENDProvider),
        closeTo(env.depthAtPressure(env.pressureAtDepth(60) * 0.65), 1e-9),
      );
    });

    test('with no altitude or water chosen the values are unchanged', () {
      final container = _container(depth: 35, o2: 36);
      addTearDown(container.dispose);

      expect(container.read(calcEnvironmentProvider), DiveEnvironment.standard);
      expect(container.read(calcPpO2Provider), closeTo(1.62, 1e-12));
      expect(
        container.read(calcMODProvider),
        closeTo((1.4 / 0.36 - 1) * 10, 1e-9),
      );
    });
  });
}
