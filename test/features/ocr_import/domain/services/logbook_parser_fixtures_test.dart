import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

import '../../fixtures/logbook_fixtures.dart';

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

void main() {
  final parser = LogbookParser();

  test('sample 1: PADI handwritten imperial page', () {
    final result = parser.parse(
      padiHandwrittenImperial(),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.diveNumber, 66);
    expect(result.date, DateTime(2006, 2, 6, 10, 0));
    expect(result.hasTimeOfDay, isTrue);
    expect(result.durationMinutes, 32);
    expect(result.maxDepthMeters, closeTo(21.03, 0.05)); // 69 ft
    expect(result.startPressureBar, closeTo(206.8, 0.5)); // 3K = 3000 psi
    expect(result.endPressureBar, closeTo(110.3, 0.5)); // 1600 psi
    expect(result.waterTempCelsius, closeTo(22.78, 0.05)); // 73 F
    expect(result.weightKg, closeTo(2.72, 0.01)); // 6 lbs
    expect(result.siteName, "O'ahu - pipe");
    expect(result.notes, contains('HUMPBACK WHALE'));
    expect(result.unmapped['visibility'], '60 ft');
  });

  test('sample 2: PADI training metric page', () {
    final result = parser.parse(
      padiTrainingMetric(),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.date, DateTime(2023, 5, 14));
    expect(result.hasTimeOfDay, isFalse);
    expect(result.maxDepthMeters, closeTo(11.1, 0.001));
    expect(result.durationMinutes, 45);
    expect(result.startPressureBar, 200);
    expect(result.endPressureBar, 70);
    expect(result.airTempCelsius, 24);
    expect(result.waterTempCelsius, 25);
    expect(result.siteName, 'Pinnacle, Sodwana Bay');
    expect(result.notes, 'First dive in the ocean!');
    // The certification number on the page must never leak into fields.
    expect(result.diveNumber, isNull);
  });

  test('sample 3: generic third-party template', () {
    final result = parser.parse(
      genericThirdParty(),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.diveNumber, 102);
    expect(result.date, DateTime(2024, 3, 7));
    expect(result.siteName, 'Blue Corner');
    expect(result.maxDepthMeters, 28);
    expect(result.o2Percent, 32);
    expect(result.startPressureBar, 210);
    expect(result.endPressureBar, 60);
  });

  test('sample 4: typewriter boxed template', () {
    final result = parser.parse(
      typewriterBoxed(),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.siteName, 'Chac Mool Cenote');
    expect(result.locationText, 'Mexico');
    expect(result.waterTempCelsius, 25);
    expect(result.durationMinutes, 51);
    expect(result.maxDepthMeters, 12);
  });

  test('certification trap page extracts nothing', () {
    final result = parser.parse(
      certificationTrap(),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.isEmpty, isTrue);
  });
}
