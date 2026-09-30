import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';

void main() {
  test('environment mirrors the dive detail analysis resolution', () {
    const s = ScenarioSettings(
      altitudeMeters: 1500,
      waterType: WaterType.fresh,
      surfacePressureBar: 0.9,
    );
    expect(
      s.environment,
      DiveEnvironment.forConditions(
        altitudeMeters: 1500,
        waterType: WaterType.fresh,
        surfacePressureBar: 0.9,
      ),
    );
    expect(const ScenarioSettings().environment, DiveEnvironment.standard);
    expect(
      const ScenarioSettings(altitudeMeters: 0).environment.surfacePressureBar,
      closeTo(1.01325, 1e-3),
    );
  });

  test('withGf replaces only the gradient factors', () {
    const s = ScenarioSettings(surfacePressureBar: 0.95, buddyFactor: 3);
    final g = s.withGf(low: 40, high: 85);
    expect(g.gfLowPercent, 40);
    expect(g.gfHighPercent, 85);
    expect(g.surfacePressureBar, 0.95);
    expect(g.buddyFactor, 3);
  });
}
