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

  group('SCR loop fallback (#4660)', () {
    test('a dive without its own rate and VO2 uses the diver defaults', () {
      final config = const ScenarioSettings(
        defaultScrInjectionRateLpm: 7.5,
        defaultScrVo2Lpm: 2.0,
      ).engineConfigFor();
      expect(config.scrInjectionRateLpm, 7.5);
      expect(config.scrVo2Lpm, 2.0);
    });

    test('a dive that logged its own rate and VO2 keeps them', () {
      final config = const ScenarioSettings(
        defaultScrInjectionRateLpm: 7.5,
        defaultScrVo2Lpm: 2.0,
      ).engineConfigFor(scrInjectionRateLpm: 10, scrVo2Lpm: 1.1);
      expect(config.scrInjectionRateLpm, 10);
      expect(config.scrVo2Lpm, 1.1);
    });

    test('the defaults are the figures the lab used before', () {
      final config = const ScenarioSettings().engineConfigFor();
      expect(config.scrInjectionRateLpm, 12.0);
      expect(config.scrVo2Lpm, 1.3);
    });

    test('the defaults take part in equality', () {
      expect(
        const ScenarioSettings(defaultScrVo2Lpm: 2.0),
        isNot(const ScenarioSettings()),
      );
      expect(
        const ScenarioSettings().copyWith(defaultScrInjectionRateLpm: 7.5),
        const ScenarioSettings(defaultScrInjectionRateLpm: 7.5),
      );
    });
  });
}
