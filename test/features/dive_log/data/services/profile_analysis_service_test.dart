import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  group('ProfileAnalysisService cumulative support', () {
    late ProfileAnalysisService service;

    setUp(() {
      service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
    });

    test(
      'analyze with startCompartments should produce shorter NDL than fresh',
      () {
        // Create pre-loaded compartments from a simulated first dive
        final preAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        preAlgorithm.calculateSegment(
          depthMeters: 30.0,
          durationSeconds: 20 * 60,
          fN2: airN2Fraction,
        );
        // 60 min surface interval
        preAlgorithm.calculateSegment(
          depthMeters: 0.0,
          durationSeconds: 60 * 60,
          fN2: airN2Fraction,
        );
        final residualCompartments = preAlgorithm.compartments;

        // Build a 30-min dive at 18m
        final depths = <double>[];
        final timestamps = <int>[];
        for (int t = 0; t <= 30 * 60; t += 60) {
          timestamps.add(t);
          depths.add(18.0);
        }

        // Analyze with residual loading
        final cumulative = service.analyze(
          diveId: 'test-cumulative',
          depths: depths,
          timestamps: timestamps,
          startCompartments: residualCompartments,
        );

        // Analyze fresh (no residual)
        final fresh = service.analyze(
          diveId: 'test-fresh',
          depths: depths,
          timestamps: timestamps,
        );

        // Last NDL value should be shorter for cumulative
        expect(
          cumulative.ndlCurve.last,
          lessThan(fresh.ndlCurve.last),
          reason: 'Cumulative tissue loading should reduce NDL',
        );
      },
    );

    test('analyze with startOtu should set otuStart on O2Exposure', () {
      final depths = <double>[];
      final timestamps = <int>[];
      for (int t = 0; t <= 30 * 60; t += 60) {
        timestamps.add(t);
        depths.add(18.0);
      }

      final result = service.analyze(
        diveId: 'test-otu',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: 0.32, // EAN32 for meaningful OTU
        startOtu: 120.0,
      );

      expect(result.o2Exposure.otuStart, equals(120.0));
      expect(result.o2Exposure.otuDaily, equals(120.0 + result.o2Exposure.otu));
    });

    test(
      'analyze without startCompartments should use surface-saturated state',
      () {
        final depths = <double>[];
        final timestamps = <int>[];
        for (int t = 0; t <= 30 * 60; t += 60) {
          timestamps.add(t);
          depths.add(18.0);
        }

        // Two calls without startCompartments should produce identical results
        final result1 = service.analyze(
          diveId: 'test-1',
          depths: depths,
          timestamps: timestamps,
        );
        final result2 = service.analyze(
          diveId: 'test-2',
          depths: depths,
          timestamps: timestamps,
        );

        expect(result1.ndlCurve, equals(result2.ndlCurve));
      },
    );

    test(
      'analyze with wrong-length startCompartments throws ArgumentError',
      () {
        final depths = <double>[18.0, 18.0, 18.0];
        final timestamps = <int>[0, 60, 120];

        // Create a list with wrong number of compartments (5 instead of 16)
        final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        final wrongCompartments = algorithm.compartments.sublist(0, 5);

        expect(
          () => service.analyze(
            diveId: 'test-wrong-length',
            depths: depths,
            timestamps: timestamps,
            startCompartments: wrongCompartments,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('$zhl16CompartmentCount'),
            ),
          ),
        );
      },
    );

    test('analyze with negative startOtu throws ArgumentError', () {
      final depths = <double>[18.0, 18.0, 18.0];
      final timestamps = <int>[0, 60, 120];

      expect(
        () => service.analyze(
          diveId: 'test-negative-otu',
          depths: depths,
          timestamps: timestamps,
          startOtu: -10.0,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('non-negative'),
          ),
        ),
      );
    });
  });
}
