import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_surface_breathing.dart';
import 'package:submersion/features/dive_log/domain/services/surface_breathing.dart';

/// An Avelo Hydrotank's pressure falls when water is pushed out, on the
/// surface as well as at depth (issue #4657). That fall is no sign the diver
/// breathed on the surface, so it must not stretch the gas-use window every
/// other cylinder's rates divide by.
void main() {
  // On the surface to 120 s, 12 m to 2520 s, on the surface to 2700 s.
  final profile = [
    const DiveProfilePoint(timestamp: 0, depth: 0),
    const DiveProfilePoint(timestamp: 120, depth: 0),
    for (var t = 180; t <= 2460; t += 60)
      DiveProfilePoint(timestamp: t, depth: 12),
    const DiveProfilePoint(timestamp: 2520, depth: 0),
    const DiveProfilePoint(timestamp: 2700, depth: 0),
  ];

  // A 30 bar fall after surfacing: a purge on a Hydrotank, surface breathing
  // on back gas.
  final fallAfterSurfacing = [
    const TankPressurePoint(tankId: 'main', timestamp: 0, pressure: 230),
    const TankPressurePoint(tankId: 'main', timestamp: 2520, pressure: 230),
    const TankPressurePoint(tankId: 'main', timestamp: 2640, pressure: 200),
  ];

  SurfaceBreathing? breathing(TankRole role) => diveSurfaceBreathing(
    profile: profile,
    tanks: [
      DiveTank(id: 'main', role: role),
      const DiveTank(id: 'pony', role: TankRole.pony),
    ],
    switches: const [],
    tankPressures: {'main': fallAfterSurfacing},
  );

  test('the fall on back gas stretches the window', () {
    expect(breathing(TankRole.backGas)?.until, isNotNull);
  });

  test('a Hydrotank purge on the surface stretches nothing', () {
    expect(breathing(TankRole.hydrotank), isNull);
  });
}
