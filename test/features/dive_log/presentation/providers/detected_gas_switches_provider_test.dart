import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/detected_gas_switches_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _left = DiveTank(
  id: 'left',
  volume: 12,
  role: TankRole.sidemountLeft,
  order: 0,
);
const _right = DiveTank(
  id: 'right',
  volume: 12,
  role: TankRole.sidemountRight,
  order: 1,
);

Dive _dive({DiveMode mode = DiveMode.oc}) => Dive(
  id: 'dive-1',
  dateTime: DateTime.utc(2026, 11, 1),
  diveMode: mode,
  tanks: const [_left, _right],
  profile: [
    for (var t = 0; t <= 2400; t += 60)
      DiveProfilePoint(timestamp: t, depth: 18),
  ],
);

/// The right cylinder breathed from the start to 10:00, the left after.
Map<String, List<TankPressurePoint>> _pressures() {
  List<TankPressurePoint> series(String id, bool Function(int t) on) {
    var bar = 200.0;
    return [
      for (var t = 0; t <= 2400; t += 2)
        TankPressurePoint(
          tankId: id,
          timestamp: t,
          pressure: t > 0 && on(t) ? bar -= 3.4 / 30 : bar,
        ),
    ];
  }

  return {
    'left': series('left', (t) => t > 600),
    'right': series('right', (t) => t <= 600),
  };
}

ProviderContainer _container(Dive? dive) => ProviderContainer(
  overrides: [
    diveProvider('dive-1').overrideWith((ref) async => dive),
    tankPressuresProvider('dive-1').overrideWith((ref) async => _pressures()),
    ppO2MaxDecoProvider.overrideWithValue(1.6),
  ],
);

Future<T> _read<T>(ProviderContainer c, FutureProvider<T> provider) async {
  final sub = c.listen(provider.future, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

void main() {
  test('lets go of a dive once nothing reads it', () async {
    final container = _container(_dive());
    addTearDown(container.dispose);
    final provider = detectedGasSwitchesProvider('dive-1');

    container.listen(provider, (_, _) {}).close();
    await container.pump();

    expect(container.exists(provider), isFalse);
  });

  test('gives the start and the switches the pressures show', () async {
    final container = _container(_dive());
    addTearDown(container.dispose);

    final detected = await _read(
      container,
      detectedGasSwitchesProvider('dive-1'),
    );

    expect(detected!.startingTankId, 'right');
    expect([for (final s in detected.addable) s.tankId], ['right', 'left']);
    expect(detected.addable.first.t, 0);
    expect(detected.addable.last.t, closeTo(600, 30));
  });

  test('a rebreather dive gives nothing', () async {
    final container = _container(_dive(mode: DiveMode.ccr));
    addTearDown(container.dispose);

    expect(
      await _read(container, detectedGasSwitchesProvider('dive-1')),
      isNull,
    );
  });

  test('a dive that is gone gives nothing', () async {
    final container = _container(null);
    addTearDown(container.dispose);

    expect(
      await _read(container, detectedGasSwitchesProvider('dive-1')),
      isNull,
    );
  });
}
