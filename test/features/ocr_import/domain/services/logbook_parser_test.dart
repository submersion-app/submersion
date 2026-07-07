import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

OcrTextBlock block(
  String text,
  double l,
  double t, {
  double w = 80,
  double h = 12,
}) => OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

OcrResult page(List<OcrTextBlock> blocks) =>
    OcrResult(blocks: blocks, imageSize: const Size(1000, 1400));

void main() {
  final parser = LogbookParser();

  test('label-bound metric page parses to metric fields', () {
    final result = parser.parse(
      page([
        block('Date', 0, 0),
        block('05/14/2023', 90, 0),
        block('Location', 0, 30),
        block('Pinnacle, Sodwana Bay', 90, 30, w: 200),
        block('DEPTH', 40, 220),
        block('11.1m', 45, 195, w: 40),
        block('TIME', 150, 220),
        block('45min', 150, 195, w: 40),
        block('Start psi/bar', 0, 300, w: 90),
        block('200 bar', 100, 300, w: 50),
        block('End psi/bar', 0, 330, w: 90),
        block('70 bar', 100, 330, w: 50),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.date, DateTime(2023, 5, 14));
    expect(result.siteName, 'Pinnacle, Sodwana Bay');
    expect(result.maxDepthMeters, closeTo(11.1, 0.001));
    expect(result.durationMinutes, 45);
    expect(result.startPressureBar, 200);
    expect(result.endPressureBar, 70);
  });

  test('imperial page converts to metric storage', () {
    final result = parser.parse(
      page([
        block('DEPTH', 40, 220),
        block('69', 45, 195, w: 30),
        block('Visibility', 0, 400),
        block('60 ft', 100, 400, w: 40),
        block('bar/psi START', 200, 100, w: 90),
        block('3K', 200, 120, w: 30),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    // 60 ft visibility makes the page imperial: 69 is feet, 3K is psi.
    expect(result.maxDepthMeters, closeTo(21.03, 0.05));
    expect(result.startPressureBar, closeTo(206.8, 0.5));
    expect(result.unmapped['visibility'], '60 ft');
  });

  test('duration derived from time in and out', () {
    final result = parser.parse(
      page([
        block('Time IN', 0, 100),
        block('10:00A', 0, 120, w: 50),
        block('Time OUT', 120, 100),
        block('10:32', 120, 120, w: 50),
        block('Date', 0, 0),
        block("6 Feb '06", 90, 0, w: 70),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.durationMinutes, 32);
    expect(result.hasTimeOfDay, isTrue);
    expect(result.date, DateTime(2006, 2, 6, 10, 0));
  });

  test('implausible depth is silently dropped', () {
    final result = parser.parse(
      page([block('DEPTH', 40, 220), block('1800', 45, 195, w: 40)]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.maxDepthMeters, isNull);
  });

  test('notes collect handwriting below the comments label', () {
    final result = parser.parse(
      page([
        block('Comments', 0, 700),
        block('WE SAW', 0, 750, w: 120),
        block('A HUMPBACK WHALE', 0, 790, w: 300),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.notes, 'WE SAW A HUMPBACK WHALE');
  });

  test('empty page yields isEmpty result', () {
    final result = parser.parse(
      page([]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.isEmpty, isTrue);
  });

  group('branch coverage', () {
    test('rating and nitrox labels bind', () {
      final result = parser.parse(
        page([
          block('Rating', 0, 0),
          block('5', 90, 0, w: 20),
          block('Nitrox', 0, 40),
          block('EAN32', 90, 40, w: 60),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.rating, 5);
      expect(result.o2Percent, 32);
    });

    test('explicit kg weight stays metric', () {
      final result = parser.parse(
        page([
          block('Weight Used :', 0, 0, w: 110),
          block('11 kg', 120, 0, w: 50),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.weightKg, 11);
    });

    test('implausible air temperature is dropped', () {
      final result = parser.parse(
        page([block('Air', 0, 0, w: 40), block('90', 50, 0, w: 30)]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.airTempCelsius, isNull);
    });

    test('start pressure below end pressure drops both', () {
      final result = parser.parse(
        page([
          block('Start', 0, 0, w: 60),
          block('100 bar', 70, 0, w: 60),
          block('End', 0, 40, w: 60),
          block('150 bar', 70, 40, w: 60),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.startPressureBar, isNull);
      expect(result.endPressureBar, isNull);
    });

    test('implausible duration is dropped', () {
      final result = parser.parse(
        page([block('Bottom Time', 0, 0, w: 100), block('900', 110, 0, w: 40)]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.durationMinutes, isNull);
    });

    test('pattern pass fills date, depth, and duration from bare values', () {
      final result = parser.parse(
        page([
          block('05/14/2023', 0, 0, w: 110),
          block('18m', 0, 40, w: 40),
          block('42 min', 0, 80, w: 60),
          block('150 bar', 0, 120, w: 60),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.date, DateTime(2023, 5, 14));
      expect(result.maxDepthMeters, 18);
      expect(result.durationMinutes, 42);
      // A single free pressure becomes the start pressure only.
      expect(result.startPressureBar, 150);
      expect(result.endPressureBar, isNull);
    });

    test('pattern pass handles imperial free values', () {
      final result = parser.parse(
        page([
          block('60 ft', 0, 0, w: 50),
          block('3000 psi', 0, 40, w: 80),
          block('2200 psi', 0, 80, w: 80),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.maxDepthMeters, closeTo(18.29, 0.01));
      expect(result.startPressureBar, closeTo(206.8, 0.5));
      expect(result.endPressureBar, closeTo(151.7, 0.5));
    });

    test('a bare number never becomes a site name', () {
      final result = parser.parse(
        page([block('Location', 0, 0), block('42', 110, 0, w: 30)]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.siteName, isNull);
    });

    test('dive number zero is rejected', () {
      final result = parser.parse(
        page([block('Dive No.', 0, 0), block('0', 100, 0, w: 20)]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.diveNumber, isNull);
    });

    test('time out alone yields neither duration nor time of day', () {
      final result = parser.parse(
        page([
          block('Time OUT', 0, 0),
          block('10:32', 0, 20, w: 50),
          block('Date', 200, 0, w: 50),
          block('05/14/2023', 260, 0, w: 110),
        ]),
        fallbackUnits: metric,
        preferDayFirst: false,
      );
      expect(result.durationMinutes, isNull);
      expect(result.hasTimeOfDay, isFalse);
      expect(result.date, DateTime(2023, 5, 14));
    });
  });
}
