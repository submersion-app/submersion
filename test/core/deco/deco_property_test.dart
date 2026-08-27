import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

int _tts({
  required double depth,
  required int bottomMinutes,
  double gfLow = 0.4,
  double gfHigh = 0.8,
  DiveEnvironment env = DiveEnvironment.standard,
}) {
  final algo = BuhlmannAlgorithm(
    gfLow: gfLow,
    gfHigh: gfHigh,
    environment: env,
  );
  algo.calculateSegment(
    depthMeters: depth,
    durationSeconds: bottomMinutes * 60,
  );
  return algo.calculateTts(currentDepth: depth);
}

void main() {
  group('deco invariants', () {
    test('longer bottom time never shortens TTS', () {
      for (final depth in [30.0, 45.0, 60.0]) {
        int previous = 0;
        for (int minutes = 10; minutes <= 60; minutes += 5) {
          final tts = _tts(depth: depth, bottomMinutes: minutes);
          expect(
            tts,
            greaterThanOrEqualTo(previous),
            reason: 'depth $depth, $minutes min',
          );
          previous = tts;
        }
      }
    });

    test('deeper dives never shorten TTS at fixed bottom time', () {
      int previous = 0;
      for (double depth = 20; depth <= 60; depth += 5) {
        final tts = _tts(depth: depth, bottomMinutes: 25);
        expect(tts, greaterThanOrEqualTo(previous), reason: 'depth $depth');
        previous = tts;
      }
    });

    test('raising GF-high never increases TTS', () {
      for (final depth in [40.0, 55.0]) {
        int? previous;
        for (double gfHigh = 0.6; gfHigh <= 0.95; gfHigh += 0.05) {
          final tts = _tts(depth: depth, bottomMinutes: 30, gfHigh: gfHigh);
          if (previous != null) {
            expect(
              tts,
              lessThanOrEqualTo(previous),
              reason: 'depth $depth, gfHigh $gfHigh',
            );
          }
          previous = tts;
        }
      }
    });

    test('higher altitude never lengthens NDL', () {
      int? previous;
      for (double alt = 0; alt <= 3000; alt += 500) {
        final algo = BuhlmannAlgorithm(
          gfLow: 0.5,
          gfHigh: 0.8,
          environment: DiveEnvironment.forConditions(altitudeMeters: alt),
        );
        final ndl = algo.calculateNdl(depthMeters: 25);
        if (previous != null) {
          expect(ndl, lessThanOrEqualTo(previous), reason: 'altitude $alt');
        }
        previous = ndl;
      }
    });

    test('denser water never lengthens NDL at the same depth', () {
      int? previous;
      for (final density in [
        DiveEnvironment.freshWaterDensity,
        DiveEnvironment.brackishWaterDensity,
        DiveEnvironment.en13319Density,
        DiveEnvironment.saltWaterDensity,
      ]) {
        final algo = BuhlmannAlgorithm(
          gfLow: 0.5,
          gfHigh: 0.8,
          environment: DiveEnvironment(waterDensityKgM3: density),
        );
        final ndl = algo.calculateNdl(depthMeters: 30);
        if (previous != null) {
          expect(ndl, lessThanOrEqualTo(previous), reason: 'density $density');
        }
        previous = ndl;
      }
    });
  });
}
