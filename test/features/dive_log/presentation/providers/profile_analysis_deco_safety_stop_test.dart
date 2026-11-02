import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/deco_stop_windows.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// A hold in the 3-6 m band while deco is owed is required decompression, so
/// the calculated safety stop must not label it. A hold the diver chose after
/// the obligation cleared is still a safety stop (issue #4079).
void main() {
  /// [minutes] at [depth], sampled every 10 seconds from [start].
  List<DiveProfilePoint> hold(int start, double depth, int minutes) => [
    for (var i = 0; i < minutes * 6; i++)
      DiveProfilePoint(timestamp: start + i * 10, depth: depth),
  ];

  /// Straight line from [from] to [to], sampled every 10 seconds.
  List<DiveProfilePoint> ramp(int start, double from, double to, int seconds) {
    final steps = seconds ~/ 10;
    return [
      for (var i = 0; i < steps; i++)
        DiveProfilePoint(
          timestamp: start + i * 10,
          depth: from + (to - from) * i / steps,
        ),
    ];
  }

  /// A dive of [bottomMinutes] at [bottomDepth], then [stopMinutes] at 5 m,
  /// then the surface.
  List<DiveProfilePoint> diveWithStop({
    required double bottomDepth,
    required int bottomMinutes,
    int stopMinutes = 5,
  }) {
    final descent = ramp(0, 0, bottomDepth, 60);
    final bottom = hold(60, bottomDepth, bottomMinutes);
    final ascentStart = bottom.last.timestamp + 10;
    final ascentSeconds = ((bottomDepth - 5) / 9 * 60).round();
    final ascent = ramp(ascentStart, bottomDepth, 5, ascentSeconds);
    final stopStart = ascentStart + ascentSeconds;
    final stop = hold(stopStart, 5, stopMinutes);
    final surfacing = ramp(stop.last.timestamp + 10, 5, 0, 40);
    final last = surfacing.last.timestamp + 10;
    return [
      ...descent,
      ...bottom,
      ...ascent,
      ...stop,
      ...surfacing,
      DiveProfilePoint(timestamp: last, depth: 0),
    ];
  }

  ProfileAnalysis analyze(List<DiveProfilePoint> profile) =>
      ProfileAnalysisService().analyze(
        diveId: 'dive',
        depths: profile.map((p) => p.depth).toList(),
        timestamps: profile.map((p) => p.timestamp).toList(),
      );

  List<ProfileEvent> safetyStops(ProfileAnalysis analysis) => analysis.events
      .where(
        (e) =>
            e.eventType == ProfileEventType.safetyStopStart ||
            e.eventType == ProfileEventType.safetyStopEnd,
      )
      .toList();

  /// The sample the detected stop opened on.
  int arrivalIndex(ProfileAnalysis analysis, List<DiveProfilePoint> profile) {
    final start = safetyStops(analysis).first;
    return profile.indexWhere((p) => p.timestamp == start.timestamp);
  }

  group('a deco dive', () {
    late List<DiveProfilePoint> profile;
    late ProfileAnalysis base;

    setUp(() {
      profile = diveWithStop(bottomDepth: 40, bottomMinutes: 25);
      base = analyze(profile);
      expect(safetyStops(base), hasLength(2));
      expect(base.ndlCurve[arrivalIndex(base, profile)], lessThan(0));
    });

    test('loses a calculated safety stop on its deco stop', () {
      final (result, _) = overlayComputerDecoData(base, profile);

      expect(safetyStops(result), isEmpty);
    });

    test('keeps its other computed events', () {
      final (result, _) = overlayComputerDecoData(base, profile);

      expect(
        result.events.map((e) => e.eventType),
        contains(ProfileEventType.maxDepth),
      );
    });

    test('loses it on the path that only carries cell millivolts', () {
      final withMillivolts = [
        for (final p in profile) p.copyWith(o2SensorMv1: 11),
      ];

      final (result, _) = overlayComputerDecoData(base, withMillivolts);

      expect(result.o2CellMvCurves, isNotNull);
      expect(safetyStops(result), isEmpty);
    });

    test('reports the stop it removed as a deco stop window', () {
      final stops = safetyStops(base);

      final (result, _) = overlayComputerDecoData(base, profile);

      expect(result.decoStopWindows, [
        (start: stops.first.timestamp, end: stops.last.timestamp),
      ]);
    });

    test('keeps a safety stop the computer logged as an event', () {
      final recorded = ProfileEvent.safetyStop(
        id: 'recorded',
        diveId: 'dive',
        timestamp: safetyStops(base).first.timestamp,
        depth: 5,
        createdAt: DateTime.utc(2026),
        source: EventSource.imported,
      );

      final (result, _) = overlayComputerDecoData(
        base.copyWith(events: [...base.events, recorded]),
        profile,
      );

      expect(safetyStops(result), [recorded]);
    });

    test('keeps the stop when the computer read no obligation there', () {
      // With the NDL source on the computer, its reading is what the chart
      // shows, so a model that disagrees must not take the label away.
      final clear = [
        for (final p in profile) p.copyWith(ndl: 600, decoType: 0),
      ];

      final (result, _) = overlayComputerDecoData(
        base,
        clear,
        ndlSource: MetricDataSource.computer,
      );

      expect(safetyStops(result), hasLength(2));
      expect(result.decoStopWindows, isEmpty);
    });

    test('keeps a stop the computer flagged as a safety stop', () {
      // Some computers still run a safety stop after light deco, and what the
      // computer recorded outranks the app's model.
      final arrival = arrivalIndex(base, profile);
      final flagged = [
        for (var i = 0; i < profile.length; i++)
          i == arrival + 6
              ? profile[i].copyWith(decoType: kDecoTypeSafetyStop)
              : profile[i],
      ];

      final (result, _) = overlayComputerDecoData(base, flagged);

      expect(safetyStops(result), hasLength(2));
    });
  });

  group('a no-deco dive', () {
    late List<DiveProfilePoint> profile;
    late ProfileAnalysis base;

    setUp(() {
      profile = diveWithStop(bottomDepth: 18, bottomMinutes: 15);
      base = analyze(profile);
      expect(base.hadDecoObligation, isFalse);
      expect(safetyStops(base), hasLength(2));
    });

    test('keeps its calculated safety stop', () {
      final (result, _) = overlayComputerDecoData(base, profile);

      expect(safetyStops(result), hasLength(2));
      expect(result.decoStopWindows, isEmpty);
    });

    test('loses it when the computer flagged deco on arrival', () {
      // The calculated source is in view, but the computer's model still says
      // this diver was decompressing: this was not a voluntary stop.
      final arrival = arrivalIndex(base, profile);
      final flagged = [
        for (var i = 0; i < profile.length; i++)
          i == arrival
              ? profile[i].copyWith(decoType: kDecoTypeDecoStop)
              : profile[i],
      ];

      final (result, _) = overlayComputerDecoData(base, flagged);

      expect(safetyStops(result), isEmpty);
    });

    test('loses it when the computer deco reading covers the arrival', () {
      final arrival = arrivalIndex(base, profile);
      final flagged = [
        for (var i = 0; i < profile.length; i++)
          i >= arrival - 30 && i <= arrival + 3
              ? profile[i].copyWith(decoType: kDecoTypeDecoStop)
              : profile[i].copyWith(ndl: 600, decoType: kDecoTypeNdl),
      ];

      final (result, _) = overlayComputerDecoData(
        base,
        flagged,
        ndlSource: MetricDataSource.computer,
      );

      expect(safetyStops(result), isEmpty);
    });
  });

  group('a light deco dive', () {
    late List<DiveProfilePoint> profile;
    late ProfileAnalysis noDeco;

    setUp(() {
      profile = diveWithStop(bottomDepth: 18, bottomMinutes: 15);
      noDeco = analyze(profile);
    });

    /// [noDeco] with deco owed on every sample before [clearedAt].
    ProfileAnalysis owedUntil(int clearedAt) => noDeco.copyWith(
      ndlCurve: [
        for (var i = 0; i < noDeco.ndlCurve.length; i++)
          i < clearedAt ? -1 : noDeco.ndlCurve[i],
      ],
    );

    test('keeps the stop when the obligation cleared before the band', () {
      final base = owedUntil(arrivalIndex(noDeco, profile));
      expect(base.hadDecoObligation, isTrue);

      final (result, _) = overlayComputerDecoData(base, profile);

      expect(safetyStops(result), hasLength(2));
    });

    test('loses the stop when deco was still owed on arrival', () {
      final base = owedUntil(arrivalIndex(noDeco, profile) + 1);

      final (result, _) = overlayComputerDecoData(base, profile);

      expect(safetyStops(result), isEmpty);
    });
  });

  group('safetyStopWindows', () {
    ProfileEvent stop(int timestamp, {required bool isStart}) =>
        ProfileEvent.safetyStop(
          id: '$timestamp',
          diveId: 'dive',
          timestamp: timestamp,
          depth: 5,
          createdAt: DateTime.utc(2026),
          isStart: isStart,
          source: EventSource.imported,
        );

    test('pairs each start with the next end', () {
      expect(
        safetyStopWindows([
          stop(100, isStart: true),
          stop(200, isStart: false),
          stop(300, isStart: true),
          stop(400, isStart: false),
        ]),
        [(start: 100, end: 200), (start: 300, end: 400)],
      );
    });

    test('a start with no end has no window', () {
      expect(safetyStopWindows([stop(100, isStart: true)]), isEmpty);
    });

    test('an end with no start has no window', () {
      expect(safetyStopWindows([stop(100, isStart: false)]), isEmpty);
    });

    group('for one source', () {
      ProfileEvent from(
        String? computerId,
        int timestamp, {
        required bool isStart,
      }) => stop(timestamp, isStart: isStart).copyWith(computerId: computerId);

      test('leaves out another computer\'s stop', () {
        expect(
          safetyStopWindows(
            [
              from('other', 100, isStart: true),
              from('other', 200, isStart: false),
            ],
            analyzedSource: (computerId: 'viewed'),
          ),
          isEmpty,
        );
      });

      test('another computer\'s start cannot open its own stop', () {
        expect(
          safetyStopWindows(
            [
              from('other', 100, isStart: true),
              from('viewed', 150, isStart: true),
              from('viewed', 300, isStart: false),
            ],
            analyzedSource: (computerId: 'viewed'),
          ),
          [(start: 150, end: 300)],
        );
      });

      test('keeps a stop with no computer', () {
        expect(
          safetyStopWindows(
            [from(null, 100, isStart: true), from(null, 200, isStart: false)],
            analyzedSource: (computerId: 'viewed'),
          ),
          [(start: 100, end: 200)],
        );
      });

      test('a source with no computer only reads unattributed stops', () {
        expect(
          safetyStopWindows(
            [
              from('other', 100, isStart: true),
              from('other', 200, isStart: false),
              from(null, 300, isStart: true),
              from(null, 400, isStart: false),
            ],
            analyzedSource: (computerId: null),
          ),
          [(start: 300, end: 400)],
        );
      });

      test('a dive-level analysis reads every computer', () {
        expect(
          safetyStopWindows([
            from('other', 100, isStart: true),
            from('other', 200, isStart: false),
          ]),
          [(start: 100, end: 200)],
        );
      });
    });
  });

  test('each stop on a dive is judged on its own', () {
    // A shallow pause early in the dive was voluntary; the stop at the end of
    // the deeper second half was not.
    final firstStop = hold(60, 5, 5);
    final secondDescent = ramp(firstStop.last.timestamp + 10, 5, 18, 60);
    final bottom = hold(secondDescent.last.timestamp + 10, 18, 10);
    final ascent = ramp(bottom.last.timestamp + 10, 18, 5, 90);
    final secondStop = hold(ascent.last.timestamp + 10, 5, 5);
    final surfacing = ramp(secondStop.last.timestamp + 10, 5, 0, 40);
    final profile = [
      // The band only counts after the deepest sample of the dive.
      ...ramp(0, 0, 30, 60),
      ...firstStop,
      ...secondDescent,
      ...bottom,
      ...ascent,
      ...secondStop,
      ...surfacing,
      DiveProfilePoint(timestamp: surfacing.last.timestamp + 10, depth: 0),
    ];
    final base = analyze(profile);
    final stops = safetyStops(base);
    expect(stops, hasLength(4));

    final secondArrival = profile.indexWhere(
      (p) => p.timestamp == stops[2].timestamp,
    );
    final owedOnSecond = base.copyWith(
      ndlCurve: [
        for (var i = 0; i < base.ndlCurve.length; i++)
          i == secondArrival ? -1 : base.ndlCurve[i],
      ],
    );

    final (result, _) = overlayComputerDecoData(owedOnSecond, profile);

    expect(safetyStops(result), [stops[0], stops[1]]);
    expect(result.decoStopWindows, [
      (start: stops[2].timestamp, end: stops[3].timestamp),
    ]);
  });
}
