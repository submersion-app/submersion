import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/cylinder_breath_starts_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

List<TankPressurePoint> _series(String tankId, double Function(int t) bar) => [
  for (var t = 0; t < 2400; t += 2)
    TankPressurePoint(tankId: tankId, timestamp: t, pressure: bar(t)),
];

void main() {
  test(
    'gives each cylinder that was breathed after a hold its starts',
    () async {
      final container = ProviderContainer(
        overrides: [
          tankPressuresProvider('dive-1').overrideWith(
            (ref) async => {
              'deco': _series(
                'deco',
                (t) => t < 1200 ? 200 : 200 - (t - 1200) * 3.4 / 60,
              ),
              'held': _series('held', (t) => 200),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final starts = await container.read(
        cylinderBreathStartsProvider('dive-1').future,
      );

      expect(starts.keys, ['deco']);
      expect(starts['deco'], hasLength(1));
      expect(starts['deco']!.single, inInclusiveRange(1202, 1230));
    },
  );
}
