import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  final metric = MissionUnits(const UnitFormatter(AppSettings()));
  final imperial = MissionUnits(
    const UnitFormatter(
      AppSettings(
        depthUnit: DepthUnit.feet,
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    ),
  );

  test('speeds show per minute in the depth unit', () {
    expect(metric.speed(0.9), '54 ${metric.speedSymbol}');
    expect(metric.speedDisplay(0.9), closeTo(54, 1e-9));
    expect(imperial.speedDisplay(0.9), closeTo(177.165, 1e-3));
  });

  test('an imperial value typed and read back does not drift', () {
    const mps = 0.9;
    expect(imperial.speedMps(imperial.speedDisplay(mps)), closeTo(mps, 1e-12));
    const meters = 300.0;
    expect(
      imperial.distanceMeters(imperial.distanceDisplay(meters)),
      closeTo(meters, 1e-9),
    );
    const sac = 15.0;
    expect(
      imperial.sacLitersPerMin(imperial.sacDisplay(sac)),
      closeTo(sac, 1e-9),
    );
  });

  test('a heading shows in whole degrees', () {
    expect(metric.heading(135.4), '135°');
  });
}
