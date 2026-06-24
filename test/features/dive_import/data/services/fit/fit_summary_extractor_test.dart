import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
