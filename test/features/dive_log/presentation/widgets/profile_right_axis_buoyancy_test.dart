import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Issue #4593: the buoyancy right axis has data, and a range spanning
/// neutral, exactly when the chart was handed a usable curve.
void main() {
  final profile = [
    for (var i = 0; i < 4; i++) DiveProfilePoint(timestamp: i * 30, depth: 10),
  ];

  DiveProfileChart chart(List<double?>? curve) =>
      DiveProfileChart(profile: profile, buoyancyCurve: curve);

  ({double min, double max})? range(List<double?>? curve) => getMetricRange(
    ProfileRightAxisMetric.buoyancy,
    const UnitFormatter(AppSettings()),
    chart(curve),
    hasMultiTankPressure: false,
    cnsMaxScale: 100,
    otuMaxScale: 300,
    gfMaxScale: 100,
    surfaceGfMaxScale: 100,
    ttsMaxScale: 60,
    ppO2MaxScale: 1.6,
    ppN2MaxScale: 4,
    ppHeMaxScale: 2,
    densityMaxScale: 6,
    o2CellMvMax: (_) => null,
    ascentRateAxisRange: (_) => null,
  );

  bool hasData(List<double?>? curve) => hasDataForMetric(
    ProfileRightAxisMetric.buoyancy,
    chart(curve),
    hasMultiTankPressure: false,
  );

  test('a curve with two readings has data and a range through 0', () {
    final curve = <double?>[-2, -1.5, null, -0.5];
    expect(hasData(curve), isTrue);
    final r = range(curve)!;
    expect(r.min, lessThan(-2));
    expect(r.max, greaterThanOrEqualTo(0));
  });

  test('no curve, or fewer than two readings, has no data', () {
    expect(hasData(null), isFalse);
    expect(hasData(<double?>[1.0, null, null, null]), isFalse);
    expect(range(null), isNull);
  });
}
