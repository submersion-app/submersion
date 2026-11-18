import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// An Avelo Hydrotank's pressure rises with the water pumped in (issue
/// #4657). The combined pressure curve feeds the profile's SAC curve and the
/// app's gas time remaining, so a dive breathing a Hydrotank has none: the
/// pony's curve alone would read near zero while the diver is on the
/// Hydrotank, as the whole-dive SAC would.
void main() {
  const hydrotank = DiveTank(
    id: 'h',
    volume: 10,
    gasMix: GasMix(o2: 21),
    role: TankRole.hydrotank,
  );
  const pony = DiveTank(
    id: 'p',
    volume: 3,
    gasMix: GasMix(o2: 21),
    role: TankRole.pony,
  );
  final pressures = {
    'h': const [
      TankPressurePoint(tankId: 'h', timestamp: 0, pressure: 200),
      TankPressurePoint(tankId: 'h', timestamp: 60, pressure: 215),
    ],
    'p': const [
      TankPressurePoint(tankId: 'p', timestamp: 0, pressure: 200),
      TankPressurePoint(tankId: 'p', timestamp: 60, pressure: 200),
    ],
  };

  test('a Hydrotank-only dive has no combined pressure curve', () {
    expect(
      combineMultiTankPressures(
        timestamps: const [0, 60],
        tankPressures: {'h': pressures['h']!},
        tanks: const [hydrotank],
      ),
      isNull,
    );
  });

  test('a pony beside the Hydrotank does not stand in for the dive', () {
    expect(
      combineMultiTankPressures(
        timestamps: const [0, 60],
        tankPressures: pressures,
        tanks: const [hydrotank, pony],
      ),
      isNull,
    );
  });
}
