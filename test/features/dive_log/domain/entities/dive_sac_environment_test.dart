import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Issue #3958: a logged dive's SAC and RMV divide by the ambient pressure it
/// was really breathed at, the one its decompression replay runs in.
void main() {
  const tank = DiveTank(
    id: 't1',
    volume: 12,
    startPressure: 200,
    endPressure: 100,
    role: TankRole.backGas,
  );

  Dive dive({
    double? altitude,
    double? surfacePressure,
    WaterType? waterType,
    DiveSite? site,
  }) => Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 1, 1),
    runtime: const Duration(minutes: 50),
    avgDepth: 20,
    tanks: const [tank],
    altitude: altitude,
    surfacePressure: surfacePressure,
    waterType: waterType,
    site: site,
  );

  group('environment', () {
    test('a dive with no conditions keeps the standard environment', () {
      expect(dive().environment, DiveEnvironment.standard);
    });

    test('follows altitude and water type', () {
      expect(
        dive(altitude: 3000, waterType: WaterType.fresh).environment,
        DiveEnvironment.forConditions(
          altitudeMeters: 3000,
          waterType: WaterType.fresh,
        ),
      );
    });

    test('an explicit surface pressure wins over the altitude', () {
      expect(
        dive(
          altitude: 3000,
          surfacePressure: 0.95,
        ).environment.surfacePressureBar,
        0.95,
      );
    });

    test('falls back to the site water type', () {
      expect(
        dive(
          site: const DiveSite(
            id: 's1',
            name: 'Lake',
            waterType: WaterType.fresh,
          ),
        ).environment.waterDensityKgM3,
        DiveEnvironment.freshWaterDensity,
      );
    });
  });

  test('SAC divides by the ambient pressure at the dive site', () {
    final altitude = dive(altitude: 3000, waterType: WaterType.fresh);
    final ambient = altitude.environment.pressureAtDepth(20);

    expect(altitude.sac, closeTo(100 / 50 / ambient, 1e-9));
    expect(altitude.sac, greaterThan(dive().sac!));
  });

  test('a standard dive keeps its flat SAC', () {
    expect(dive().sac, closeTo(100 / 50 / 3, 1e-6));
  });

  test('RMV divides by the ambient pressure at the dive site', () {
    final altitude = dive(altitude: 3000, waterType: WaterType.fresh);
    final ambient = altitude.environment.pressureAtDepth(20);

    expect(
      altitude.rmvFor(GasModel.ideal),
      closeTo(100 * 12 / 50 / ambient, 1e-9),
    );
  });
}
