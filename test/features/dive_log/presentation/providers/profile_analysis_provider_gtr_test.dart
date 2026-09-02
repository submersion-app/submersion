import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// The computer's own GTR (the `rbt` sample, seconds) overlays the calculated
/// curve the same way TTS does, with one difference: where the computer
/// blanked its display (deco, no comms, first minutes) the sample is null and
/// the overlay stays blank rather than borrowing the app's number, because the
/// point of the computer source is to show what the diver actually saw.
void main() {
  late ProfileAnalysisService service;
  late List<DiveProfilePoint> profile;
  late ProfileAnalysis base;

  setUp(() {
    service = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
    // 20 m for an hour, every 10 s, draining 3 bar/min at depth.
    profile = List.generate(
      361,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: 20.0),
    );
    base = service.analyze(
      diveId: 'gtr-overlay',
      depths: profile.map((p) => p.depth).toList(),
      timestamps: profile.map((p) => p.timestamp).toList(),
      pressures: profile.map((p) => 230.0 - 3.0 * p.timestamp / 60).toList(),
    );
    expect(base.hasGtrData, isTrue, reason: 'fixture needs a calculated GTR');
  });

  List<DiveProfilePoint> withComputerGtr() => [
    for (var i = 0; i < profile.length; i++)
      if (i >= 100 && i < 300) profile[i].copyWith(rbt: 1500) else profile[i],
  ];

  group('overlayComputerDecoData GTR', () {
    test(
      'uses the computer GTR per sample and stays blank where it blanked',
      () {
        final (result, info) = overlayComputerDecoData(
          base,
          withComputerGtr(),
          gtrSource: MetricDataSource.computer,
        );

        expect(result.gtrCurve!.length, profile.length);
        expect(result.gtrCurve![200], 1500);
        expect(result.gtrCurve![50], isNull);
        expect(info.gtrActual, MetricDataSource.computer);
      },
    );

    test('falls back to the calculated curve when no sample has rbt', () {
      final (result, info) = overlayComputerDecoData(
        base,
        profile,
        gtrSource: MetricDataSource.computer,
      );

      expect(result.gtrCurve, same(base.gtrCurve));
      expect(info.gtrActual, MetricDataSource.calculated);
    });

    test('keeps the calculated curve when the source is calculated', () {
      final (result, info) = overlayComputerDecoData(
        base,
        withComputerGtr(),
        gtrSource: MetricDataSource.calculated,
      );

      expect(result.gtrCurve, same(base.gtrCurve));
      expect(info.gtrActual, MetricDataSource.calculated);
    });
  });
}
