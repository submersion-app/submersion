import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';

void main() {
  late UnitDetector detector;

  setUp(() {
    detector = const UnitDetector();
  });

  // ---------------------------------------------------------------------------
  group('parseHeaderUnit', () {
    test('extracts meters from [m]', () {
      final result = detector.parseHeaderUnit('maxdepth [m]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.meters);
      expect(result.unitType, UnitType.depth);
      expect(result.source, UnitSource.header);
      expect(result.confidence, 1.0);
    });

    test('extracts Celsius from [C]', () {
      final result = detector.parseHeaderUnit('watertemp [C]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.celsius);
      expect(result.unitType, UnitType.temperature);
      expect(result.source, UnitSource.header);
    });

    test('extracts bar from [bar] with tank number in parens', () {
      final result = detector.parseHeaderUnit('startpressure (1) [bar]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.bar);
      expect(result.unitType, UnitType.pressure);
      expect(result.source, UnitSource.header);
    });

    test('extracts feet from [ft]', () {
      final result = detector.parseHeaderUnit('maxdepth [ft]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.feet);
      expect(result.unitType, UnitType.depth);
      expect(result.source, UnitSource.header);
    });

    test('extracts Fahrenheit from [F]', () {
      final result = detector.parseHeaderUnit('watertemp [F]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.fahrenheit);
      expect(result.unitType, UnitType.temperature);
      expect(result.source, UnitSource.header);
    });

    test('extracts PSI from [psi]', () {
      final result = detector.parseHeaderUnit('startpressure [psi]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.psi);
      expect(result.unitType, UnitType.pressure);
      expect(result.source, UnitSource.header);
    });

    test('extracts liters from [l]', () {
      final result = detector.parseHeaderUnit('tankvolume [l]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.liters);
      expect(result.unitType, UnitType.volume);
      expect(result.source, UnitSource.header);
    });

    test('extracts cubicFeet from [cuft]', () {
      final result = detector.parseHeaderUnit('tankvolume [cuft]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.cubicFeet);
      expect(result.unitType, UnitType.volume);
      expect(result.source, UnitSource.header);
    });

    test('extracts kilograms from [kg]', () {
      final result = detector.parseHeaderUnit('weight [kg]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.kilograms);
      expect(result.unitType, UnitType.weight);
      expect(result.source, UnitSource.header);
    });

    test('extracts pounds from [lbs]', () {
      final result = detector.parseHeaderUnit('weight [lbs]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.pounds);
      expect(result.unitType, UnitType.weight);
      expect(result.source, UnitSource.header);
    });

    test('returns null for header without unit', () {
      final result = detector.parseHeaderUnit('maxdepth');
      expect(result, isNull);
    });

    test('returns null for header with unknown unit', () {
      final result = detector.parseHeaderUnit('maxdepth [fathoms]');
      expect(result, isNull);
    });

    test('is case-insensitive for unit strings', () {
      final result = detector.parseHeaderUnit('depth [M]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.meters);
    });
  });

  // ---------------------------------------------------------------------------
  group('detectFromValues', () {
    test('detects feet from large depth values', () {
      final result = detector.detectFromValues(
        columnName: 'maxdepth',
        unitType: UnitType.depth,
        samples: [120.0, 135.0, 98.0, 110.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.feet);
      expect(result.source, UnitSource.heuristic);
      expect(result.confidence, greaterThan(0.5));
    });

    test('detects meters from small depth values', () {
      final result = detector.detectFromValues(
        columnName: 'maxdepth',
        unitType: UnitType.depth,
        samples: [18.0, 25.0, 12.0, 30.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.meters);
      expect(result.source, UnitSource.heuristic);
      expect(result.confidence, greaterThan(0.5));
    });

    test('returns ambiguous confidence for 80-100 depth values', () {
      final result = detector.detectFromValues(
        columnName: 'maxdepth',
        unitType: UnitType.depth,
        samples: [85.0, 90.0, 88.0],
      );
      expect(result, isNotNull);
      expect(result!.confidence, 0.5);
    });

    test('detects Fahrenheit from high temp values', () {
      final result = detector.detectFromValues(
        columnName: 'watertemp',
        unitType: UnitType.temperature,
        samples: [72.0, 75.0, 68.0, 80.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.fahrenheit);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects Celsius from low temp values', () {
      final result = detector.detectFromValues(
        columnName: 'watertemp',
        unitType: UnitType.temperature,
        samples: [22.0, 18.0, 25.0, 20.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.celsius);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects PSI from high pressure values', () {
      final result = detector.detectFromValues(
        columnName: 'startpressure',
        unitType: UnitType.pressure,
        samples: [3000.0, 2500.0, 3200.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.psi);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects bar from low pressure values', () {
      final result = detector.detectFromValues(
        columnName: 'startpressure',
        unitType: UnitType.pressure,
        samples: [200.0, 180.0, 210.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.bar);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects cubicFeet from large volume values', () {
      final result = detector.detectFromValues(
        columnName: 'tankvolume',
        unitType: UnitType.volume,
        samples: [80.0, 63.0, 100.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.cubicFeet);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects liters from small volume values', () {
      final result = detector.detectFromValues(
        columnName: 'tankvolume',
        unitType: UnitType.volume,
        samples: [12.0, 15.0, 10.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.liters);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects pounds from large weight values', () {
      final result = detector.detectFromValues(
        columnName: 'weight',
        unitType: UnitType.weight,
        samples: [40.0, 35.0, 45.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.pounds);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects kg from small weight values', () {
      final result = detector.detectFromValues(
        columnName: 'weight',
        unitType: UnitType.weight,
        samples: [10.0, 12.0, 8.0],
      );
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.kilograms);
      expect(result.source, UnitSource.heuristic);
    });

    test('returns null for empty samples', () {
      final result = detector.detectFromValues(
        columnName: 'maxdepth',
        unitType: UnitType.depth,
        samples: [],
      );
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('unitTypeForField', () {
    test('identifies depth fields', () {
      expect(UnitDetector.unitTypeForField('maxdepth'), UnitType.depth);
      expect(UnitDetector.unitTypeForField('depth'), UnitType.depth);
      expect(UnitDetector.unitTypeForField('meandepth'), UnitType.depth);
    });

    test('identifies temperature fields', () {
      expect(UnitDetector.unitTypeForField('watertemp'), UnitType.temperature);
      expect(UnitDetector.unitTypeForField('temp'), UnitType.temperature);
      expect(UnitDetector.unitTypeForField('airtemp'), UnitType.temperature);
    });

    test('identifies pressure fields', () {
      expect(UnitDetector.unitTypeForField('startpressure'), UnitType.pressure);
      expect(UnitDetector.unitTypeForField('pressure'), UnitType.pressure);
      expect(UnitDetector.unitTypeForField('endpressure'), UnitType.pressure);
    });

    test('identifies volume fields', () {
      expect(UnitDetector.unitTypeForField('tankvolume'), UnitType.volume);
      expect(UnitDetector.unitTypeForField('volume'), UnitType.volume);
    });

    test('identifies weight fields', () {
      expect(UnitDetector.unitTypeForField('weight'), UnitType.weight);
      expect(UnitDetector.unitTypeForField('beltweight'), UnitType.weight);
    });

    test('returns null for non-unit fields', () {
      expect(UnitDetector.unitTypeForField('date'), isNull);
      expect(UnitDetector.unitTypeForField('time'), isNull);
      expect(UnitDetector.unitTypeForField('divenumber'), isNull);
      expect(UnitDetector.unitTypeForField('notes'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('ColumnUnitDetection.needsConversion', () {
    test('returns true for feet', () {
      const detection = ColumnUnitDetection(
        columnName: 'depth',
        unitType: UnitType.depth,
        detected: DetectedUnit.feet,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isTrue);
    });

    test('returns true for fahrenheit', () {
      const detection = ColumnUnitDetection(
        columnName: 'temp',
        unitType: UnitType.temperature,
        detected: DetectedUnit.fahrenheit,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isTrue);
    });

    test('returns true for psi', () {
      const detection = ColumnUnitDetection(
        columnName: 'pressure',
        unitType: UnitType.pressure,
        detected: DetectedUnit.psi,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isTrue);
    });

    test('returns true for cubicFeet', () {
      const detection = ColumnUnitDetection(
        columnName: 'volume',
        unitType: UnitType.volume,
        detected: DetectedUnit.cubicFeet,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isTrue);
    });

    test('returns true for pounds', () {
      const detection = ColumnUnitDetection(
        columnName: 'weight',
        unitType: UnitType.weight,
        detected: DetectedUnit.pounds,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isTrue);
    });

    test('returns false for meters', () {
      const detection = ColumnUnitDetection(
        columnName: 'depth',
        unitType: UnitType.depth,
        detected: DetectedUnit.meters,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isFalse);
    });

    test('returns false for celsius', () {
      const detection = ColumnUnitDetection(
        columnName: 'temp',
        unitType: UnitType.temperature,
        detected: DetectedUnit.celsius,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isFalse);
    });

    test('returns false for bar', () {
      const detection = ColumnUnitDetection(
        columnName: 'pressure',
        unitType: UnitType.pressure,
        detected: DetectedUnit.bar,
        source: UnitSource.header,
        confidence: 1.0,
      );
      expect(detection.needsConversion, isFalse);
    });
  });
}
