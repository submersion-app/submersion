import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/tide/tide.dart';

void main() {
  group('TideConstituent', () {
    test('creates constituent with correct values', () {
      const constituent = TideConstituent(
        name: 'M2',
        amplitude: 0.523,
        phase: 127.4,
      );

      expect(constituent.name, 'M2');
      expect(constituent.amplitude, 0.523);
      expect(constituent.phase, 127.4);
    });

    test('fromJson parses correctly', () {
      final constituent = TideConstituent.fromJson('S2', {
        'amplitude': 0.187,
        'phase': 156.2,
      });

      expect(constituent.name, 'S2');
      expect(constituent.amplitude, 0.187);
      expect(constituent.phase, 156.2);
    });

    test('toJson serializes correctly', () {
      const constituent = TideConstituent(
        name: 'K1',
        amplitude: 0.142,
        phase: 45.0,
      );
      final json = constituent.toJson();

      expect(json['amplitude'], 0.142);
      expect(json['phase'], 45.0);
    });

    test('equality works correctly', () {
      const c1 = TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0);
      const c2 = TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0);
      const c3 = TideConstituent(name: 'M2', amplitude: 0.6, phase: 100.0);

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
    });
  });

  group('TidePrediction', () {
    test('creates prediction with correct values', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final prediction = TidePrediction(time: time, heightMeters: 1.23);

      expect(prediction.time, time);
      expect(prediction.heightMeters, 1.23);
    });

    test('serialization roundtrip works', () {
      final original = TidePrediction(
        time: DateTime.utc(2025, 6, 15, 12, 0, 0),
        heightMeters: -0.45,
      );
      final json = original.toJson();
      final restored = TidePrediction.fromJson(json);

      expect(restored.time, original.time);
      expect(restored.heightMeters, original.heightMeters);
    });
  });

  group('TideExtreme', () {
    test('creates high tide extreme', () {
      final extreme = TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2025, 6, 15, 14, 30, 0),
        heightMeters: 2.15,
      );

      expect(extreme.type, TideExtremeType.high);
      expect(extreme.type.displayName, 'High Tide');
      expect(extreme.heightMeters, 2.15);
    });

    test('creates low tide extreme', () {
      final extreme = TideExtreme(
        type: TideExtremeType.low,
        time: DateTime.utc(2025, 6, 15, 8, 15, 0),
        heightMeters: -0.35,
      );

      expect(extreme.type, TideExtremeType.low);
      expect(extreme.type.displayName, 'Low Tide');
      expect(extreme.heightMeters, -0.35);
    });

    test('durationFrom calculates correctly', () {
      final extreme = TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2025, 6, 15, 14, 0, 0),
        heightMeters: 2.0,
      );
      final from = DateTime.utc(2025, 6, 15, 12, 0, 0);

      expect(extreme.durationFrom(from), const Duration(hours: 2));
    });

    test('isFutureFrom returns correct value', () {
      final extreme = TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2025, 6, 15, 14, 0, 0),
        heightMeters: 2.0,
      );

      expect(extreme.isFutureFrom(DateTime.utc(2025, 6, 15, 12, 0, 0)), true);
      expect(extreme.isFutureFrom(DateTime.utc(2025, 6, 15, 16, 0, 0)), false);
    });
  });

  group('TideState', () {
    test('displayName returns correct values', () {
      expect(TideState.rising.displayName, 'Rising');
      expect(TideState.falling.displayName, 'Falling');
      expect(TideState.slackHigh.displayName, 'High Tide (Slack)');
      expect(TideState.slackLow.displayName, 'Low Tide (Slack)');
    });

    test('isSlack returns correct values', () {
      expect(TideState.rising.isSlack, false);
      expect(TideState.falling.isSlack, false);
      expect(TideState.slackHigh.isSlack, true);
      expect(TideState.slackLow.isSlack, true);
    });

    test('fromString parses correctly', () {
      expect(TideState.fromString('rising'), TideState.rising);
      expect(TideState.fromString('slackhigh'), TideState.slackHigh);
      expect(TideState.fromString('invalid'), null);
      expect(TideState.fromString(null), null);
    });
  });

  group('HarmonicConstituents', () {
    test('all major constituents have speeds defined', () {
      for (final name in majorConstituents) {
        expect(
          constituentSpeeds.containsKey(name),
          true,
          reason: 'Missing speed for $name',
        );
      }
    });

    test('all major constituents have Doodson numbers', () {
      for (final name in majorConstituents) {
        expect(
          doodsonNumbers.containsKey(name),
          true,
          reason: 'Missing Doodson number for $name',
        );
        expect(
          doodsonNumbers[name]!.length,
          6,
          reason: 'Doodson number for $name should have 6 components',
        );
      }
    });

    test('constituent speeds are in expected ranges', () {
      // Semi-diurnal: ~28-30 degrees/hour
      expect(constituentSpeeds['M2'], closeTo(28.98, 0.1));
      expect(constituentSpeeds['S2'], equals(30.0));

      // Diurnal: ~13-16 degrees/hour
      expect(constituentSpeeds['K1'], closeTo(15.04, 0.1));
      expect(constituentSpeeds['O1'], closeTo(13.94, 0.1));

      // Long-period: <1 degree/hour
      expect(constituentSpeeds['Mf'], lessThan(2.0));
      expect(constituentSpeeds['Mm'], lessThan(1.0));
    });

    test('normalizeAngle works correctly', () {
      expect(normalizeAngle(0), 0);
      expect(normalizeAngle(360), 0);
      expect(normalizeAngle(450), 90);
      expect(normalizeAngle(-90), 270);
      expect(normalizeAngle(-450), 270);
    });
  });

  group('AstronomicalArguments', () {
    test('calculates arguments for J2000 epoch', () {
      // At J2000.0 epoch (Jan 1, 2000, 12:00 TT), T should be 0
      final time = DateTime.utc(2000, 1, 1, 12, 0, 0);
      final args = AstronomicalArguments.forDateTime(time);

      // T should be very close to 0 at J2000
      expect(args.T, closeTo(0.0, 0.001));
    });

    test('calculates arguments for known date', () {
      // Test with a specific date
      final time = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final args = AstronomicalArguments.forDateTime(time);

      // Arguments should be in valid ranges
      expect(args.s, inInclusiveRange(0, 360));
      expect(args.h, inInclusiveRange(0, 360));
      expect(args.p, inInclusiveRange(0, 360));
      expect(args.n, inInclusiveRange(0, 360));
    });

    test('nodal factors are in expected range', () {
      final time = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final args = AstronomicalArguments.forDateTime(time);

      // Nodal factors should be between 0.7 and 1.3 for most constituents
      expect(args.nodalFactor('M2'), inInclusiveRange(0.9, 1.1));
      expect(args.nodalFactor('S2'), equals(1.0)); // S2 has no nodal correction
      expect(args.nodalFactor('K1'), inInclusiveRange(0.8, 1.2));
      expect(args.nodalFactor('O1'), inInclusiveRange(0.8, 1.2));
    });

    test('equilibrium phase is in valid range', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final args = AstronomicalArguments.forDateTime(time);

      // All equilibrium phases should be normalized to 0-360
      for (final name in majorConstituents) {
        final phase = args.equilibriumPhase(name);
        expect(
          phase,
          inInclusiveRange(0, 360),
          reason: 'Equilibrium phase for $name out of range',
        );
      }
    });

    test('hoursFromReferenceEpoch calculates correctly', () {
      final epoch = DateTime.utc(2000, 1, 1, 0, 0, 0);
      final later = DateTime.utc(2000, 1, 2, 0, 0, 0); // 24 hours later

      expect(AstronomicalArguments.hoursFromReferenceEpoch(epoch), 0.0);
      expect(AstronomicalArguments.hoursFromReferenceEpoch(later), 24.0);
    });
  });

  group('TideCalculator', () {
    late TideCalculator calculator;

    setUp(() {
      // Create a calculator with realistic constituent data
      // These values are representative of a typical ocean location
      calculator = TideCalculator(
        constituents: {
          'M2': const TideConstituent(
            name: 'M2',
            amplitude: 0.50,
            phase: 120.0,
          ),
          'S2': const TideConstituent(
            name: 'S2',
            amplitude: 0.20,
            phase: 150.0,
          ),
          'N2': const TideConstituent(
            name: 'N2',
            amplitude: 0.10,
            phase: 100.0,
          ),
          'K2': const TideConstituent(
            name: 'K2',
            amplitude: 0.05,
            phase: 160.0,
          ),
          'K1': const TideConstituent(name: 'K1', amplitude: 0.15, phase: 45.0),
          'O1': const TideConstituent(name: 'O1', amplitude: 0.12, phase: 30.0),
          'P1': const TideConstituent(name: 'P1', amplitude: 0.05, phase: 50.0),
          'Q1': const TideConstituent(name: 'Q1', amplitude: 0.03, phase: 20.0),
        },
      );
    });

    test('calculateHeight returns reasonable values', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final height = calculator.calculateHeight(time);

      // Height should be within the sum of all amplitudes
      final maxHeight = calculator.constituents.values
          .map((c) => c.amplitude)
          .fold(0.0, (a, b) => a + b);

      expect(height, inInclusiveRange(-maxHeight, maxHeight));
    });

    test('calculateHeight varies over time', () {
      final heights = <double>[];
      for (int hour = 0; hour < 24; hour++) {
        final time = DateTime.utc(2025, 6, 15, hour, 0, 0);
        heights.add(calculator.calculateHeight(time));
      }

      // Heights should not all be the same
      final unique = heights.toSet();
      expect(unique.length, greaterThan(1));

      // Should see variation indicating tidal cycle
      final range =
          heights.reduce((a, b) => a > b ? a : b) -
          heights.reduce((a, b) => a < b ? a : b);
      expect(range, greaterThan(0.1)); // At least 10cm range
    });

    test('predict returns correct number of predictions', () {
      final start = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final end = DateTime.utc(2025, 6, 15, 6, 0, 0);

      // 6 hours at 10 minute intervals = 37 predictions (0, 10, 20, ... 360 minutes)
      final predictions = calculator.predict(
        start: start,
        end: end,
        interval: const Duration(minutes: 10),
      );

      expect(predictions.length, 37);
      expect(predictions.first.time, start);
      expect(predictions.last.time, end);
    });

    test('predict returns predictions in order', () {
      final start = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final end = DateTime.utc(2025, 6, 15, 12, 0, 0);

      final predictions = calculator.predict(start: start, end: end);

      for (int i = 1; i < predictions.length; i++) {
        expect(predictions[i].time.isAfter(predictions[i - 1].time), true);
      }
    });

    test('findExtremes finds high and low tides', () {
      final start = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final end = DateTime.utc(2025, 6, 16, 0, 0, 0); // 24 hours

      final extremes = calculator.findExtremes(start: start, end: end);

      // Should find approximately 4 extremes in 24 hours (2 highs, 2 lows)
      // for semi-diurnal tides. Mixed tides may produce more (up to 8).
      expect(extremes.length, inInclusiveRange(3, 8));

      // Should have both high and low tides
      final highs = extremes.where((e) => e.type == TideExtremeType.high);
      final lows = extremes.where((e) => e.type == TideExtremeType.low);

      expect(highs.length, greaterThan(0));
      expect(lows.length, greaterThan(0));
    });

    test('extremes alternate between high and low', () {
      final start = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final end = DateTime.utc(2025, 6, 16, 0, 0, 0);

      final extremes = calculator.findExtremes(start: start, end: end);

      if (extremes.length >= 2) {
        for (int i = 1; i < extremes.length; i++) {
          expect(
            extremes[i].type,
            isNot(equals(extremes[i - 1].type)),
            reason: 'Consecutive extremes should alternate',
          );
        }
      }
    });

    test('high tides are higher than adjacent low tides', () {
      final start = DateTime.utc(2025, 6, 15, 0, 0, 0);
      final end = DateTime.utc(2025, 6, 16, 0, 0, 0);

      final extremes = calculator.findExtremes(start: start, end: end);

      for (int i = 0; i < extremes.length - 1; i++) {
        if (extremes[i].type == TideExtremeType.high) {
          // Check adjacent low tide is lower
          final nextLow = extremes
              .skip(i + 1)
              .firstWhere(
                (e) => e.type == TideExtremeType.low,
                orElse: () => extremes[i],
              );
          if (nextLow != extremes[i]) {
            expect(extremes[i].heightMeters, greaterThan(nextLow.heightMeters));
          }
        }
      }
    });

    test('getCurrentState returns valid state', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final state = calculator.getCurrentState(time);

      expect(TideState.values, contains(state));
    });

    test('getStatus returns comprehensive information', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final status = calculator.getStatus(time);

      expect(status.state, isA<TideState>());
      expect(status.currentHeight, isA<double>());
      expect(status.rateOfChange, isA<double>());
    });

    test('getTideAtTime returns height and state', () {
      final time = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final result = calculator.getTideAtTime(time);

      expect(result.height, isA<double>());
      expect(result.state, isA<TideState>());
    });

    test('hasMinimumConstituents returns true for valid calculator', () {
      expect(calculator.hasMinimumConstituents, true);
    });

    test('hasMinimumConstituents returns false when missing constituents', () {
      final minimal = TideCalculator(
        constituents: {
          'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0),
        },
      );

      expect(minimal.hasMinimumConstituents, false);
    });

    test('dominantConstituent returns largest amplitude', () {
      final dominant = calculator.dominantConstituent;

      expect(dominant, isNotNull);
      expect(dominant!.name, 'M2'); // M2 has largest amplitude in test data
      expect(dominant.amplitude, 0.50);
    });

    test('estimatedTidalRange calculates correctly', () {
      // Sum of amplitudes * 2
      const expectedRange =
          (0.50 + 0.20 + 0.10 + 0.05 + 0.15 + 0.12 + 0.05 + 0.03) * 2;
      expect(calculator.estimatedTidalRange, closeTo(expectedRange, 0.01));
    });

    test('majorConstituentsOnly filters correctly', () {
      final allConstituents = {
        'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0),
        'S2': const TideConstituent(name: 'S2', amplitude: 0.2, phase: 150.0),
        'K1': const TideConstituent(name: 'K1', amplitude: 0.15, phase: 45.0),
        'O1': const TideConstituent(name: 'O1', amplitude: 0.12, phase: 30.0),
        'Eps2': const TideConstituent(
          name: 'Eps2',
          amplitude: 0.01,
          phase: 80.0,
        ),
      };

      final majorOnly = TideCalculator.majorConstituentsOnly(
        allConstituents: allConstituents,
      );

      expect(majorOnly.constituents.length, 4);
      expect(majorOnly.constituents.containsKey('M2'), true);
      expect(majorOnly.constituents.containsKey('Eps2'), false);
    });
  });

  group('TideCalculator Integration', () {
    test('full prediction cycle for a typical location', () {
      // San Francisco-like tidal characteristics (mixed semi-diurnal)
      final calculator = TideCalculator(
        constituents: {
          'M2': const TideConstituent(
            name: 'M2',
            amplitude: 0.55,
            phase: 355.0,
          ),
          'S2': const TideConstituent(name: 'S2', amplitude: 0.13, phase: 15.0),
          'N2': const TideConstituent(
            name: 'N2',
            amplitude: 0.12,
            phase: 335.0,
          ),
          'K1': const TideConstituent(
            name: 'K1',
            amplitude: 0.37,
            phase: 225.0,
          ),
          'O1': const TideConstituent(
            name: 'O1',
            amplitude: 0.23,
            phase: 205.0,
          ),
          'P1': const TideConstituent(
            name: 'P1',
            amplitude: 0.12,
            phase: 220.0,
          ),
        },
      );

      final start = DateTime.utc(2025, 6, 21, 0, 0, 0); // Summer solstice
      final end = DateTime.utc(2025, 6, 22, 0, 0, 0);

      // Generate predictions
      final predictions = calculator.predict(start: start, end: end);
      expect(predictions.length, greaterThan(100));

      // Find extremes (mixed tides like SF can have more extremes due to
      // significant diurnal components interacting with semi-diurnal)
      final extremes = calculator.findExtremes(start: start, end: end);
      expect(extremes.length, inInclusiveRange(3, 10));

      // Verify tidal range is reasonable for mixed tide
      final heights = predictions.map((p) => p.heightMeters).toList();
      final maxHeight = heights.reduce((a, b) => a > b ? a : b);
      final minHeight = heights.reduce((a, b) => a < b ? a : b);
      final range = maxHeight - minHeight;

      // Tidal range should be roughly 2x sum of major amplitudes
      // For mixed tides, expect 1-3 meters
      expect(range, inInclusiveRange(0.5, 3.0));
    });
  });
}
