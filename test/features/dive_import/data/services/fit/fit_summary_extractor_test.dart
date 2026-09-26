import 'dart:io';

import 'package:fit_tool/fit_tool.dart';
// ignore: implementation_imports
import 'package:fit_tool/src/utils/logger.dart' as fit_log;
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:submersion/features/dive_import/data/services/fit/fit_summary_extractor.dart';

void main() {
  test(
    'extracts dive number, bottom time, SI, CNS/OTU, GPS, water type, GF',
    () {
      final summary = DiveSummaryMessage()
        ..diveNumber = 92
        ..bottomTime = 5168.781
        ..surfaceInterval = 167491
        ..startCns = 0
        ..endCns = 32
        ..startN2 = 5
        ..endN2 = 71
        ..o2Toxicity = 90;
      final session = SessionMessage()
        ..startPositionLat = 35.815
        ..startPositionLong = 14.451;
      final settings = DiveSettingsMessage()
        ..waterType = WaterType.salt
        ..gfLow = 50
        ..gfHigh = 85
        ..model = TissueModelType.zhl16c;

      final s = FitSummaryExtractor.extract(
        summary: summary,
        session: session,
        settings: settings,
      );

      expect(s.diveNumber, 92);
      expect(
        s.bottomTime,
        const Duration(seconds: 5169),
      ); // 5168.781 -> rounded
      expect(s.surfaceInterval, const Duration(seconds: 167491));
      expect(s.cnsEnd, 32);
      expect(s.startN2, 5);
      expect(s.endN2, 71);
      expect(s.otu, 90);
      expect(s.entryLat, closeTo(35.815, 1e-4));
      expect(s.entryLong, closeTo(14.451, 1e-4));
      expect(s.waterType, 'salt');
      expect(s.decoModel, 'zhl_16c');
      expect(s.gfLow, 50);
      expect(s.gfHigh, 85);
    },
  );

  test('handles all-null inputs gracefully', () {
    final s = FitSummaryExtractor.extract(
      summary: null,
      session: null,
      settings: null,
    );
    expect(s.diveNumber, isNull);
    expect(s.bottomTime, isNull);
    expect(s.entryLat, isNull);
    expect(s.waterType, isNull);
    expect(s.startN2, isNull);
    expect(s.endN2, isNull);
  });

  test('leaves N2 null when the summary does not carry it', () {
    final s = FitSummaryExtractor.extract(
      summary: DiveSummaryMessage()
        ..diveNumber = 3
        ..endCns = 12,
      session: null,
      settings: null,
    );
    expect(s.cnsEnd, 12);
    expect(s.startN2, isNull);
    expect(s.endN2, isNull);
  });

  test('reads start/end N2 from the real Descent dive summary', () {
    // Silence fit_tool's warnings about fields its bundled profile lacks.
    fit_log.logger = Logger(level: Level.error);
    final bytes = File(
      'test/dives/005_oc-trimix-two-deco-gases.fit',
    ).readAsBytesSync();
    final messages = FitFile.fromBytes(
      bytes,
    ).records.map((r) => r.message).whereType<Message>().toList();
    // The file holds two dive_summary messages; the one referencing the
    // session carries a dive number and the real values. The other is all
    // invalid sentinels, which fit_tool reads as null.
    final summary = messages.whereType<DiveSummaryMessage>().firstWhere(
      (s) => s.diveNumber != null,
    );
    final settings = messages.whereType<DiveSettingsMessage>().first;

    final s = FitSummaryExtractor.extract(
      summary: summary,
      session: null,
      settings: settings,
    );

    expect(s.startN2, 0);
    expect(s.endN2, 86);
    expect(s.decoModel, 'zhl_16c');
  });
}
