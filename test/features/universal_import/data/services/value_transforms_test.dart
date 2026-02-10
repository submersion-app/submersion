import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

void main() {
  const service = ValueTransformService();

  group('feetToMeters', () {
    test('converts 100 feet to 30.5 meters', () {
      expect(service.feetToMeters('100'), 30.5);
    });

    test('converts 33 feet to 10.1 meters', () {
      expect(service.feetToMeters('33'), 10.1);
    });

    test('handles decimal values', () {
      expect(service.feetToMeters('66.5'), 20.3);
    });

    test('strips non-numeric characters', () {
      expect(service.feetToMeters('100 ft'), 30.5);
    });

    test('returns null for empty string', () {
      expect(service.feetToMeters(''), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(service.feetToMeters('abc'), isNull);
    });
  });

  group('fahrenheitToCelsius', () {
    test('converts 32F to 0C', () {
      expect(service.fahrenheitToCelsius('32'), 0.0);
    });

    test('converts 77F to 25C', () {
      expect(service.fahrenheitToCelsius('77'), 25.0);
    });

    test('converts 50F to 10C', () {
      expect(service.fahrenheitToCelsius('50'), 10.0);
    });

    test('returns null for empty string', () {
      expect(service.fahrenheitToCelsius(''), isNull);
    });
  });

  group('psiToBar', () {
    test('converts 3000 psi to ~206.8 bar', () {
      expect(service.psiToBar('3000'), closeTo(206.8, 0.1));
    });

    test('converts 200 psi', () {
      expect(service.psiToBar('200'), closeTo(13.8, 0.1));
    });

    test('returns null for non-numeric', () {
      expect(service.psiToBar('n/a'), isNull);
    });
  });

  group('cubicFeetToLiters', () {
    test('converts 80 cuft to ~2265.3 L', () {
      expect(service.cubicFeetToLiters('80'), closeTo(2265.3, 0.1));
    });

    test('returns null for empty', () {
      expect(service.cubicFeetToLiters(''), isNull);
    });
  });

  group('minutesToSeconds', () {
    test('converts 45 minutes to 2700 seconds', () {
      expect(service.minutesToSeconds('45'), const Duration(seconds: 2700));
    });

    test('handles decimal minutes', () {
      expect(service.minutesToSeconds('30.5'), const Duration(seconds: 1830));
    });

    test('returns null for invalid', () {
      expect(service.minutesToSeconds('abc'), isNull);
    });
  });

  group('hmsToSeconds', () {
    test('converts 1:30:00 to 5400 seconds', () {
      expect(
        service.hmsToSeconds('1:30:00'),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('converts 0:45:30 to 2730 seconds', () {
      expect(
        service.hmsToSeconds('0:45:30'),
        const Duration(minutes: 45, seconds: 30),
      );
    });

    test('converts M:S format', () {
      expect(
        service.hmsToSeconds('45:30'),
        const Duration(minutes: 45, seconds: 30),
      );
    });

    test('returns null for invalid format', () {
      expect(service.hmsToSeconds('abc'), isNull);
    });

    test('returns null for single value', () {
      expect(service.hmsToSeconds('45'), isNull);
    });
  });

  group('parseVisibilityScale', () {
    test('maps excellent text', () {
      expect(service.parseVisibilityScale('Excellent'), 'excellent');
    });

    test('maps good text', () {
      expect(service.parseVisibilityScale('Good'), 'good');
    });

    test('maps moderate/fair text', () {
      expect(service.parseVisibilityScale('Fair'), 'moderate');
    });

    test('maps poor text', () {
      expect(service.parseVisibilityScale('Poor'), 'poor');
    });

    test('maps >30m to excellent', () {
      expect(service.parseVisibilityScale('>30m'), 'excellent');
    });

    test('maps numeric 25 to good', () {
      expect(service.parseVisibilityScale('25'), 'good');
    });

    test('maps numeric 10 to moderate', () {
      expect(service.parseVisibilityScale('10'), 'moderate');
    });

    test('maps numeric 3 to poor', () {
      expect(service.parseVisibilityScale('3'), 'poor');
    });

    test('returns unknown for unrecognized text', () {
      expect(service.parseVisibilityScale('foggy'), 'unknown');
    });
  });

  group('parseDiveType', () {
    test('maps night dive', () {
      expect(service.parseDiveType('Night Dive'), 'night');
    });

    test('maps deep dive', () {
      expect(service.parseDiveType('Deep'), 'deep');
    });

    test('maps wreck dive', () {
      expect(service.parseDiveType('Wreck Exploration'), 'wreck');
    });

    test('maps cave/cavern', () {
      expect(service.parseDiveType('Cavern Dive'), 'cave');
    });

    test('maps training', () {
      expect(service.parseDiveType('Training Course'), 'training');
    });

    test('defaults to recreational', () {
      expect(service.parseDiveType('Fun dive'), 'recreational');
    });
  });

  group('normalizeRating', () {
    test('keeps 1-5 scale', () {
      expect(service.normalizeRating('4'), 4);
    });

    test('rounds in 1-5 range', () {
      expect(service.normalizeRating('3.7'), 4);
    });

    test('normalizes 1-10 scale', () {
      expect(service.normalizeRating('8'), 4);
    });

    test('normalizes 1-100 scale', () {
      expect(service.normalizeRating('80'), 4);
    });

    test('returns null for zero', () {
      expect(service.normalizeRating('0'), isNull);
    });

    test('returns null for non-numeric', () {
      expect(service.normalizeRating('great'), isNull);
    });
  });

  group('parseDate', () {
    test('parses yyyy-MM-dd', () {
      expect(service.parseDate('2024-01-15'), DateTime(2024, 1, 15));
    });

    test('parses MM/dd/yyyy', () {
      expect(service.parseDate('01/15/2024'), DateTime(2024, 1, 15));
    });

    test('parses ISO 8601', () {
      final result = service.parseDate('2024-01-15T10:30:00');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('returns null for garbage', () {
      expect(service.parseDate('not a date'), isNull);
    });
  });

  group('parseTime', () {
    test('parses HH:mm', () {
      final result = service.parseTime('14:30');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
    });

    test('parses HH:mm:ss', () {
      final result = service.parseTime('14:30:45');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
    });

    test('returns null for invalid', () {
      expect(service.parseTime('noon'), isNull);
    });
  });

  group('applyTransform', () {
    test('delegates to feetToMeters', () {
      expect(service.applyTransform(ValueTransform.feetToMeters, '100'), 30.5);
    });

    test('delegates to fahrenheitToCelsius', () {
      expect(
        service.applyTransform(ValueTransform.fahrenheitToCelsius, '77'),
        25.0,
      );
    });

    test('returns null for empty input', () {
      expect(service.applyTransform(ValueTransform.feetToMeters, ''), isNull);
    });

    test('returns null for whitespace-only input', () {
      expect(
        service.applyTransform(ValueTransform.feetToMeters, '   '),
        isNull,
      );
    });
  });

  group('isLikelyFeet', () {
    test('returns true for column name with ft', () {
      expect(
        ValueTransformService.isLikelyFeet(['100'], 'Max Depth (ft)'),
        isTrue,
      );
    });

    test('returns false for column name with meter', () {
      expect(
        ValueTransformService.isLikelyFeet(['30'], 'Max Depth (meter)'),
        isFalse,
      );
    });

    test('returns true when most values > 100', () {
      expect(
        ValueTransformService.isLikelyFeet([
          '110',
          '130',
          '95',
          '120',
        ], 'Max Depth'),
        isTrue,
      );
    });

    test('returns false when most values < 100', () {
      expect(
        ValueTransformService.isLikelyFeet([
          '25',
          '30',
          '18',
          '42',
        ], 'Max Depth'),
        isFalse,
      );
    });
  });

  group('isLikelyFahrenheit', () {
    test('returns true for column with fahrenheit', () {
      expect(
        ValueTransformService.isLikelyFahrenheit([
          '77',
        ], 'Water Temp (fahrenheit)'),
        isTrue,
      );
    });

    test('returns false for column with celsius', () {
      expect(
        ValueTransformService.isLikelyFahrenheit([
          '25',
        ], 'Water Temp (celsius)'),
        isFalse,
      );
    });

    test('returns true when most values > 50', () {
      expect(
        ValueTransformService.isLikelyFahrenheit([
          '72',
          '68',
          '75',
        ], 'Water Temp'),
        isTrue,
      );
    });
  });

  group('isLikelyPsi', () {
    test('returns true for column with psi', () {
      expect(
        ValueTransformService.isLikelyPsi(['3000'], 'Start Pressure (psi)'),
        isTrue,
      );
    });

    test('returns false for column with bar', () {
      expect(
        ValueTransformService.isLikelyPsi(['200'], 'Start Pressure (bar)'),
        isFalse,
      );
    });

    test('returns true when most values > 500', () {
      expect(
        ValueTransformService.isLikelyPsi(['3000', '2500', '2800'], 'Pressure'),
        isTrue,
      );
    });
  });
}
