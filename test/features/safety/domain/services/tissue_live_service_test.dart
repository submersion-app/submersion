import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/safety/domain/services/tissue_live_service.dart';

void main() {
  final diveEnd = DateTime.utc(2026, 7, 17, 12);

  // A loaded end-of-dive state: 30m for 40 minutes on air, not surface-
  // saturated, so off-gassing has something to actually unload.
  List<TissueCompartment> loadedCompartments() {
    final algorithm = BuhlmannAlgorithm();
    algorithm.calculateSegment(
      depthMeters: 30,
      durationSeconds: 40 * 60,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
    return algorithm.compartments;
  }

  test('no time elapsed: compartments unchanged', () {
    final compartments = loadedCompartments();
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: compartments,
      lastDiveEnd: diveEnd,
      now: diveEnd,
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    for (var i = 0; i < compartments.length; i++) {
      expect(result.compartments[i].currentPN2, compartments[i].currentPN2);
      expect(result.compartments[i].currentPHe, compartments[i].currentPHe);
    }
  });

  test('now before dive end (clock skew): no off-gassing applied, not negative '
      'elapsed time', () {
    final compartments = loadedCompartments();
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: compartments,
      lastDiveEnd: diveEnd,
      now: diveEnd.subtract(const Duration(minutes: 5)),
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    for (var i = 0; i < compartments.length; i++) {
      expect(result.compartments[i].currentPN2, compartments[i].currentPN2);
    }
  });

  test('elapsed time off-gasses every compartment toward surface air', () {
    final compartments = loadedCompartments();
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: compartments,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 2)),
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    final surfaceN2 = calculateInspiredN2(1.0, airN2Fraction);
    for (var i = 0; i < compartments.length; i++) {
      final before = compartments[i].currentPN2;
      final after = result.compartments[i].currentPN2;
      // Loaded above surface equilibrium, so two hours of off-gassing must
      // move every compartment strictly closer to (not past) the surface
      // tension, never further away.
      expect(after, lessThan(before));
      expect(after, greaterThan(surfaceN2));
    }
  });

  test('48 hours is long enough to fully surface-saturate even the slowest '
      'compartment', () {
    final compartments = loadedCompartments();
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: compartments,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 48)),
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    final surfaceN2 = calculateInspiredN2(1.0, airN2Fraction);
    for (final comp in result.compartments) {
      expect(comp.currentPN2, closeTo(surfaceN2, 0.01));
    }
  });

  test('result is projected at the surface, not at depth', () {
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: loadedCompartments(),
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 1)),
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    expect(result.currentDepthMeters, 0.0);
    expect(result.ambientPressureBar, 1.0);
    // At the surface there is nowhere to ascend to, so the readout must
    // never claim a mandatory deco obligation.
    expect(result.ndlSeconds, greaterThanOrEqualTo(0));
    expect(result.ceilingMeters, 0.0);
    expect(result.decoStops, isEmpty);
  });

  test('passes the current gradient factors through to the result', () {
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: loadedCompartments(),
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 1)),
      gfLow: 0.2,
      gfHigh: 0.9,
    );

    expect(result.gfLow, 0.2);
    expect(result.gfHigh, 0.9);
  });

  test('inspired N2/He at the surface are known, so offgassing badges can '
      'render', () {
    final result = TissueLiveService.currentStatus(
      endOfDiveCompartments: loadedCompartments(),
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 1)),
      gfLow: 0.3,
      gfHigh: 0.7,
    );

    expect(result.inspiredN2Bar, isNotNull);
    expect(result.inspiredHeBar, 0.0);
  });

  group('surfaceIntervalTimeline', () {
    test('no time elapsed: a single entry, not off-gassed', () {
      final compartments = loadedCompartments();
      final timeline = TissueLiveService.surfaceIntervalTimeline(
        endOfDiveCompartments: compartments,
        lastDiveEnd: diveEnd,
        now: diveEnd,
        gfLow: 0.3,
        gfHigh: 0.7,
      );

      expect(timeline, hasLength(1));
      for (var i = 0; i < compartments.length; i++) {
        expect(
          timeline.single.compartments[i].currentPN2,
          compartments[i].currentPN2,
        );
      }
    });

    test(
      'now before dive end (clock skew): a single entry, not off-gassed',
      () {
        final timeline = TissueLiveService.surfaceIntervalTimeline(
          endOfDiveCompartments: loadedCompartments(),
          lastDiveEnd: diveEnd,
          now: diveEnd.subtract(const Duration(minutes: 5)),
          gfLow: 0.3,
          gfHigh: 0.7,
        );

        expect(timeline, hasLength(1));
      },
    );

    test('a positive elapsed time is sampled into multiple entries', () {
      final timeline = TissueLiveService.surfaceIntervalTimeline(
        endOfDiveCompartments: loadedCompartments(),
        lastDiveEnd: diveEnd,
        now: diveEnd.add(const Duration(hours: 2)),
        gfLow: 0.3,
        gfHigh: 0.7,
      );

      // One more than the sample count: the end-of-dive entry plus one per
      // step.
      expect(timeline.length, TissueLiveService.timelineSampleCount + 1);
    });

    test('each entry off-gasses further than the last, monotonically toward '
        'the surface', () {
      final timeline = TissueLiveService.surfaceIntervalTimeline(
        endOfDiveCompartments: loadedCompartments(),
        lastDiveEnd: diveEnd,
        now: diveEnd.add(const Duration(hours: 2)),
        gfLow: 0.3,
        gfHigh: 0.7,
      );

      for (var i = 1; i < timeline.length; i++) {
        final previous = timeline[i - 1].compartments[0].currentPN2;
        final current = timeline[i].compartments[0].currentPN2;
        expect(current, lessThanOrEqualTo(previous));
      }
    });

    test('the timeline\'s last entry matches currentStatus for the same '
        'inputs', () {
      final compartments = loadedCompartments();
      final elapsed = diveEnd.add(const Duration(hours: 5));

      final timeline = TissueLiveService.surfaceIntervalTimeline(
        endOfDiveCompartments: compartments,
        lastDiveEnd: diveEnd,
        now: elapsed,
        gfLow: 0.3,
        gfHigh: 0.7,
      );
      final current = TissueLiveService.currentStatus(
        endOfDiveCompartments: compartments,
        lastDiveEnd: diveEnd,
        now: elapsed,
        gfLow: 0.3,
        gfHigh: 0.7,
      );

      for (var i = 0; i < compartments.length; i++) {
        expect(
          timeline.last.compartments[i].currentPN2,
          closeTo(current.compartments[i].currentPN2, 1e-9),
        );
      }
    });

    test('does not balloon in size for a long surface interval', () {
      final timeline = TissueLiveService.surfaceIntervalTimeline(
        endOfDiveCompartments: loadedCompartments(),
        lastDiveEnd: diveEnd,
        now: diveEnd.add(const Duration(hours: 48)),
        gfLow: 0.3,
        gfHigh: 0.7,
      );

      expect(
        timeline.length,
        lessThanOrEqualTo(TissueLiveService.timelineSampleCount + 1),
      );
    });
  });

  group('altitude', () {
    final altitude = DiveEnvironment.forConditions(altitudeMeters: 2000);

    // Saturated at the 2000 m surface, then the slowest compartment left
    // 0.1 bar above that surface's equilibrium: a real residual load there,
    // yet still BELOW the 1.0 bar sea-level equilibrium.
    List<TissueCompartment> altitudeResidual() {
      final compartments = BuhlmannAlgorithm(
        environment: altitude,
      ).compartments.toList();
      final slowest = compartments.last;
      compartments[compartments.length - 1] = slowest.copyWith(
        currentPN2: slowest.currentPN2 + 0.1,
      );
      return compartments;
    }

    DecoStatus projectAt(DiveEnvironment environment) =>
        TissueLiveService.currentStatus(
          endOfDiveCompartments: altitudeResidual(),
          lastDiveEnd: diveEnd,
          now: diveEnd.add(const Duration(hours: 1)),
          gfLow: 0.3,
          gfHigh: 0.7,
          environment: environment,
        );

    test('off-gasses toward the dive site\'s surface and keeps its residual '
        'load visible', () {
      final status = projectAt(altitude);
      final surfaceN2 = calculateInspiredN2(
        altitude.surfacePressureBar,
        airN2Fraction,
      );

      expect(status.ambientPressureBar, altitude.surfacePressureBar);
      expect(status.compartments.last.currentPN2, greaterThan(surfaceN2));
      expect(status.isOffgassing(status.compartments.last), isTrue);
      expect(TissueLiveService.hasResidualLoad(status), isTrue);
    });

    test('the same tissues judged at the standard sea-level surface would '
        'hide that load', () {
      expect(
        TissueLiveService.hasResidualLoad(projectAt(DiveEnvironment.standard)),
        isFalse,
      );
    });
  });
}
