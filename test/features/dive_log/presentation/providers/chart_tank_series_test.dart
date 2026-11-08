import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';

const _real = {
  'air': [TankPressurePoint(tankId: 'air', timestamp: 0, pressure: 200)],
};

void main() {
  group('chartTankSeries', () {
    test('the estimates, once loaded', () {
      const estimated = EstimatedTankPressures(_real, {'stage'});
      expect(chartTankSeries(estimated, _real), same(estimated));
    });

    test('the measured series alone while estimates are missing', () {
      expect(
        chartTankSeries(null, _real),
        const EstimatedTankPressures(_real, {}),
      );
    });

    test('nothing when neither has loaded', () {
      expect(chartTankSeries(null, null), isNull);
    });
  });
}
