import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// [AnalysisSettings.fingerprint] is stored beside persisted results and
/// compared across devices (issue #2592), so it must be stable for equal
/// settings and change with every field.
void main() {
  const base = AnalysisSettings(
    gfLow: 50,
    gfHigh: 85,
    ppO2MaxWorking: 1.4,
    ppO2MaxDeco: 1.6,
    cnsWarningThreshold: 80,
    ascentRateWarning: 9,
    ascentRateCritical: 12,
    lastStopDepth: 3,
    decoStopIncrement: 3,
    cnsCalculationMethod: CnsCalculationMethod.shearwater,
    ascentGasSet: AscentGasSet.allCarried,
    gtrReservePressure: 50,
    ndlSource: MetricDataSource.computer,
    ttsSource: MetricDataSource.computer,
    cnsSource: MetricDataSource.computer,
    decoStopSource: MetricDataSource.computer,
    gtrSource: MetricDataSource.computer,
  );

  test('the fingerprint is the documented, versioned text', () {
    expect(
      base.fingerprint,
      'a1;gf=50/85;ppo2=1.4/1.6;cnsw=80;asc=9/12;stop=3/3;cnsm=shearwater;'
      'gas=allCarried;gtr=50;src=computer/computer/computer/computer/computer',
    );
  });

  test('whole values print without a fraction, others in full', () {
    expect(base.copyWith(lastStopDepth: 3.0).fingerprint, base.fingerprint);
    expect(
      base.copyWith(lastStopDepth: 4.5).fingerprint,
      contains('stop=4.5/3'),
    );
  });

  test('copyWith with no arguments is equal, with the same hash', () {
    final copy = base.copyWith();
    expect(copy, base);
    expect(copy.hashCode, base.hashCode);
  });

  test('every field moves the fingerprint', () {
    final variants = [
      base.copyWith(gfLow: 40),
      base.copyWith(gfHigh: 80),
      base.copyWith(ppO2MaxWorking: 1.3),
      base.copyWith(ppO2MaxDeco: 1.5),
      base.copyWith(cnsWarningThreshold: 70),
      base.copyWith(ascentRateWarning: 8),
      base.copyWith(ascentRateCritical: 10),
      base.copyWith(lastStopDepth: 6),
      base.copyWith(decoStopIncrement: 6),
      base.copyWith(cnsCalculationMethod: CnsCalculationMethod.values.last),
      base.copyWith(ascentGasSet: AscentGasSet.values.last),
      base.copyWith(gtrReservePressure: 40),
      base.copyWith(ndlSource: MetricDataSource.calculated),
      base.copyWith(ttsSource: MetricDataSource.calculated),
      base.copyWith(cnsSource: MetricDataSource.calculated),
      base.copyWith(decoStopSource: MetricDataSource.calculated),
      base.copyWith(gtrSource: MetricDataSource.calculated),
    ];
    final prints = {for (final v in variants) v.fingerprint};
    expect(prints, hasLength(variants.length));
    expect(prints, isNot(contains(base.fingerprint)));
    for (final v in variants) {
      expect(v == base, isFalse);
    }
  });

  test('the fractions are the percentages over a hundred', () {
    expect(base.gfLowFraction, 0.5);
    expect(base.gfHighFraction, 0.85);
  });
}
