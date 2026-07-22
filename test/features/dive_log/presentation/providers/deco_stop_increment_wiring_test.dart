import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's configured stop increment must reach the quantizer that builds
/// the deco stop band. Testing [ProfileAnalysisService] directly cannot catch a
/// break here: the service honours whatever increment it is handed, so the
/// defect is entirely in whether the provider hands it one.
///
/// Every leaf setting [profileAnalysisServiceProvider] reads is overridden, so
/// `settingsProvider` is never constructed and the test needs no database or
/// SharedPreferences.
void main() {
  // A square profile deep enough and long enough to owe decompression.
  final depths = <double>[
    for (var i = 0; i < 30; i++) i * 45.0 / 30,
    for (var i = 0; i < 120; i++) 45.0,
    for (var i = 0; i < 30; i++) 45.0 - i * 45.0 / 30,
  ];
  final timestamps = [for (var i = 0; i < depths.length; i++) i * 20];

  ProfileAnalysis analyseWithIncrement(double increment) {
    final container = ProviderContainer(
      overrides: [
        gfLowProvider.overrideWithValue(30),
        gfHighProvider.overrideWithValue(70),
        ppO2MaxWorkingProvider.overrideWithValue(1.4),
        ppO2MaxDecoProvider.overrideWithValue(1.6),
        cnsWarningThresholdProvider.overrideWithValue(80),
        ascentRateWarningProvider.overrideWithValue(9.0),
        ascentRateCriticalProvider.overrideWithValue(12.0),
        lastStopDepthProvider.overrideWithValue(3.0),
        cnsCalculationMethodProvider.overrideWithValue(
          CnsCalculationMethod.shearwater,
        ),
        decoStopIncrementProvider.overrideWithValue(increment),
      ],
    );
    addTearDown(container.dispose);

    return container
        .read(profileAnalysisServiceProvider)
        .analyze(
          diveId: 'increment-wiring',
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
        );
  }

  List<double> stopsFor(double increment) => analyseWithIncrement(
    increment,
  ).decoStopCurve.where((s) => s > 0).toList();

  bool sitsOnGrid(List<double> stops, double increment) => stops.every(
    (s) => (s / increment - (s / increment).round()).abs() < 1e-6,
  );

  test('the configured stop increment reaches the deco stop band', () {
    final stops = stopsFor(2.0);

    expect(
      stops,
      isNotEmpty,
      reason: 'the fixture profile must incur a decompression obligation',
    );
    expect(
      sitsOnGrid(stops, 2.0),
      isTrue,
      reason:
          'stops are not multiples of 2.0 - the provider is not passing '
          'decoStopIncrement to ProfileAnalysisService',
    );
  });

  test('a different increment moves the band onto a different grid', () {
    // Guards against a hardcoded value that happens to satisfy one grid:
    // a 3 m band fails both this and the 2 m case above.
    final coarse = stopsFor(5.0);

    expect(coarse, isNotEmpty);
    expect(
      sitsOnGrid(coarse, 5.0),
      isTrue,
      reason: 'stops are not multiples of 5.0',
    );
  });

  test('the default increment still yields a 3 m grid', () {
    final stops = stopsFor(3.0);

    expect(stops, isNotEmpty);
    expect(sitsOnGrid(stops, 3.0), isTrue);
  });
}
