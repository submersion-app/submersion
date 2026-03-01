import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  group('Cumulative tissue loading integration', () {
    test('3-dive day: NDL should decrease with each successive dive', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      // Build a simple constant-depth profile
      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      // Dive 1: 25m for 30 min (fresh)
      final dive1 = service.analyze(
        diveId: 'dive-1',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
      );

      // Simulate 45 min surface interval (short enough to retain meaningful
      // residual nitrogen in slower compartments between repetitive dives)
      final algo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      algo.setCompartments(List.from(dive1.decoStatuses.last.compartments));
      algo.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 45 * 60,
        fN2: airN2Fraction,
      );
      final si1Compartments = algo.compartments;

      // Dive 2: 25m for 30 min (with residual from dive 1)
      final dive2 = service.analyze(
        diveId: 'dive-2',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        startCompartments: si1Compartments,
      );

      // Simulate another 45 min surface interval
      final algo2 = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
      algo2.setCompartments(List.from(dive2.decoStatuses.last.compartments));
      algo2.calculateSegment(
        depthMeters: 0.0,
        durationSeconds: 45 * 60,
        fN2: airN2Fraction,
      );
      final si2Compartments = algo2.compartments;

      // Dive 3: 25m for 30 min (with residual from dives 1+2)
      final dive3 = service.analyze(
        diveId: 'dive-3',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        startCompartments: si2Compartments,
      );

      // NDL should decrease: dive1 > dive2 > dive3
      final ndl1 = dive1.ndlCurve.first;
      final ndl2 = dive2.ndlCurve.first;
      final ndl3 = dive3.ndlCurve.first;

      expect(
        ndl1,
        greaterThan(ndl2),
        reason: 'Dive 2 NDL should be shorter than dive 1',
      );
      expect(
        ndl2,
        greaterThan(ndl3),
        reason: 'Dive 3 NDL should be shorter than dive 2',
      );

      // All should still have positive NDL at the start
      expect(ndl1, greaterThan(0));
      expect(ndl2, greaterThan(0));
      expect(ndl3, greaterThan(0));
    });

    test('OTU should accumulate across dives via startOtu', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      // Dive 1: EAN32 at 25m for 30 min
      final dive1 = service.analyze(
        diveId: 'dive-1',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        o2Fraction: 0.32,
      );

      // Dive 2: same profile, startOtu from dive 1
      final dive2 = service.analyze(
        diveId: 'dive-2',
        depths: depths(25.0, 30),
        timestamps: timestamps(30),
        o2Fraction: 0.32,
        startOtu: dive1.o2Exposure.otu,
      );

      expect(dive2.o2Exposure.otuStart, equals(dive1.o2Exposure.otu));
      expect(
        dive2.o2Exposure.otuDaily,
        closeTo(dive1.o2Exposure.otu + dive2.o2Exposure.otu, 0.01),
      );
    });

    test('startCompartments with null should behave like fresh dive', () {
      final service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);

      List<double> depths(double depth, int durationMin) {
        return List.generate(durationMin + 1, (_) => depth);
      }

      List<int> timestamps(int durationMin) {
        return List.generate(durationMin + 1, (i) => i * 60);
      }

      final withNull = service.analyze(
        diveId: 'null-test',
        depths: depths(18.0, 30),
        timestamps: timestamps(30),
        startCompartments: null,
      );

      final withoutParam = service.analyze(
        diveId: 'no-param-test',
        depths: depths(18.0, 30),
        timestamps: timestamps(30),
      );

      expect(withNull.ndlCurve, equals(withoutParam.ndlCurve));
    });
  });
}
