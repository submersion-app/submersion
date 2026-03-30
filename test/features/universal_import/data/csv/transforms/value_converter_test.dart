import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/value_converter.dart';

void main() {
  late ValueConverter converter;

  setUp(() {
    converter = const ValueConverter();
  });

  // ---------------------------------------------------------------------------
  group('unit conversions', () {
    group('convertUnit - feet to meters', () {
      test('converts 100 ft to meters', () {
        final result = converter.convertUnit(100.0, DetectedUnit.feet);
        expect(result, closeTo(30.5, 0.1));
      });

      test('converts 0 ft to 0 m', () {
        final result = converter.convertUnit(0.0, DetectedUnit.feet);
        expect(result, closeTo(0.0, 0.01));
      });

      test('converts 60 ft to meters', () {
        final result = converter.convertUnit(60.0, DetectedUnit.feet);
        expect(result, closeTo(18.3, 0.1));
      });
    });

    group('convertUnit - Fahrenheit to Celsius', () {
      test('converts 72 F to Celsius', () {
        final result = converter.convertUnit(72.0, DetectedUnit.fahrenheit);
        expect(result, closeTo(22.2, 0.1));
      });

      test('converts 32 F to 0 C', () {
        final result = converter.convertUnit(32.0, DetectedUnit.fahrenheit);
        expect(result, closeTo(0.0, 0.1));
      });

      test('converts 212 F to 100 C', () {
        final result = converter.convertUnit(212.0, DetectedUnit.fahrenheit);
        expect(result, closeTo(100.0, 0.1));
      });
    });

    group('convertUnit - PSI to bar', () {
      test('converts 3000 PSI to bar', () {
        final result = converter.convertUnit(3000.0, DetectedUnit.psi);
        expect(result, closeTo(206.8, 0.1));
      });

      test('converts 0 PSI to 0 bar', () {
        final result = converter.convertUnit(0.0, DetectedUnit.psi);
        expect(result, closeTo(0.0, 0.1));
      });
    });

    group('convertUnit - cubicFeet to liters', () {
      test('converts 80 cuft to liters', () {
        final result = converter.convertUnit(80.0, DetectedUnit.cubicFeet);
        expect(result, closeTo(2265.3, 0.1));
      });

      test('converts 0 cuft to 0 L', () {
        final result = converter.convertUnit(0.0, DetectedUnit.cubicFeet);
        expect(result, closeTo(0.0, 0.1));
      });
    });

    group('convertUnit - pounds to kg', () {
      test('converts 10 lbs to kg', () {
        final result = converter.convertUnit(10.0, DetectedUnit.pounds);
        expect(result, closeTo(4.5, 0.1));
      });

      test('converts 0 lbs to 0 kg', () {
        final result = converter.convertUnit(0.0, DetectedUnit.pounds);
        expect(result, closeTo(0.0, 0.1));
      });
    });

    group('convertUnit - metric units unchanged', () {
      test('meters are returned unchanged', () {
        expect(converter.convertUnit(18.5, DetectedUnit.meters), 18.5);
      });

      test('celsius is returned unchanged', () {
        expect(converter.convertUnit(22.0, DetectedUnit.celsius), 22.0);
      });

      test('bar is returned unchanged', () {
        expect(converter.convertUnit(200.0, DetectedUnit.bar), 200.0);
      });

      test('liters are returned unchanged', () {
        expect(converter.convertUnit(12.0, DetectedUnit.liters), 12.0);
      });

      test('kilograms are returned unchanged', () {
        expect(converter.convertUnit(10.0, DetectedUnit.kilograms), 10.0);
      });
    });
  });

  // ---------------------------------------------------------------------------
  group('parseDuration', () {
    test('parses minutes as double: "45" -> 2700 seconds', () {
      final result = converter.parseDuration('45', DurationFormat.minutes);
      expect(result, isNotNull);
      expect(result!.inSeconds, 2700);
    });

    test('parses fractional minutes: "45.5" -> 2730 seconds', () {
      final result = converter.parseDuration('45.5', DurationFormat.minutes);
      expect(result, isNotNull);
      expect(result!.inSeconds, 2730);
    });

    test('parses M:SS format: "1:23" -> Duration(minutes:1, seconds:23)', () {
      final result = converter.parseDuration('1:23', DurationFormat.hms);
      expect(result, isNotNull);
      expect(result!.inSeconds, 83);
    });

    test('parses H:MM:SS format: "1:23:45" -> Duration(h:1, m:23, s:45)', () {
      final result = converter.parseDuration('1:23:45', DurationFormat.hms);
      expect(result, isNotNull);
      expect(result!.inSeconds, 5025);
    });

    test('parses M:SS format: "0:42" -> Duration(minutes:0, seconds:42)', () {
      final result = converter.parseDuration('0:42', DurationFormat.hms);
      expect(result, isNotNull);
      expect(result!.inSeconds, 42);
    });

    test(
      'parses Subsurface duration: "25:20" -> Duration(minutes:25, seconds:20)',
      () {
        final result = converter.parseDuration('25:20', DurationFormat.hms);
        expect(result, isNotNull);
        expect(result!.inSeconds, 1520);
      },
    );

    test('returns null for null input', () {
      expect(converter.parseDuration(null, DurationFormat.minutes), isNull);
      expect(converter.parseDuration(null, DurationFormat.hms), isNull);
    });

    test('returns null for empty input', () {
      expect(converter.parseDuration('', DurationFormat.minutes), isNull);
      expect(converter.parseDuration('', DurationFormat.hms), isNull);
    });

    test('returns null for unparseable hms input', () {
      expect(
        converter.parseDuration('not-a-duration', DurationFormat.hms),
        isNull,
      );
    });

    test('returns null for unparseable minutes input', () {
      expect(converter.parseDuration('abc', DurationFormat.minutes), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('parseVisibility', () {
    test('maps "excellent" (case-insensitive)', () {
      expect(converter.parseVisibility('excellent'), 'excellent');
      expect(converter.parseVisibility('Excellent'), 'excellent');
      expect(converter.parseVisibility('EXCELLENT'), 'excellent');
    });

    test('maps "good"', () {
      expect(converter.parseVisibility('good'), 'good');
    });

    test('maps "moderate"', () {
      expect(converter.parseVisibility('moderate'), 'moderate');
    });

    test('maps "poor"', () {
      expect(converter.parseVisibility('poor'), 'poor');
    });

    test('maps "unknown"', () {
      expect(converter.parseVisibility('unknown'), 'unknown');
    });

    group('maps descriptive text', () {
      test('"crystal clear" -> excellent', () {
        expect(converter.parseVisibility('crystal clear'), 'excellent');
      });

      test('"murky" -> poor', () {
        expect(converter.parseVisibility('murky'), 'poor');
      });
    });

    group('maps numeric meters', () {
      test('>20m -> excellent', () {
        expect(converter.parseVisibility('25'), 'excellent');
        expect(converter.parseVisibility('30'), 'excellent');
      });

      test('>10m -> good', () {
        expect(converter.parseVisibility('15'), 'good');
        expect(converter.parseVisibility('20'), 'good');
      });

      test('>5m -> moderate', () {
        expect(converter.parseVisibility('8'), 'moderate');
        expect(converter.parseVisibility('10'), 'moderate');
      });

      test('<=5m -> poor', () {
        expect(converter.parseVisibility('5'), 'poor');
        expect(converter.parseVisibility('3'), 'poor');
        expect(converter.parseVisibility('0'), 'poor');
      });
    });

    test('returns "unknown" for null', () {
      expect(converter.parseVisibility(null), 'unknown');
    });

    test('returns "unknown" for empty string', () {
      expect(converter.parseVisibility(''), 'unknown');
    });

    test('returns "unknown" for unrecognised text', () {
      expect(converter.parseVisibility('blurry'), 'unknown');
    });
  });

  // ---------------------------------------------------------------------------
  group('normalizeRating', () {
    test('preserves 1-5 ratings as-is', () {
      expect(converter.normalizeRating('1'), 1);
      expect(converter.normalizeRating('3'), 3);
      expect(converter.normalizeRating('5'), 5);
    });

    test('clamps 0 and negative values to 1', () {
      expect(converter.normalizeRating('0'), 1);
      expect(converter.normalizeRating('-1'), 1);
    });

    test('converts 6-10 scale: divide by 2', () {
      expect(converter.normalizeRating('6'), 3);
      expect(converter.normalizeRating('8'), 4);
      expect(converter.normalizeRating('10'), 5);
    });

    test('converts 11-100 scale: divide by 20', () {
      expect(converter.normalizeRating('20'), 1);
      expect(converter.normalizeRating('60'), 3);
      expect(converter.normalizeRating('100'), 5);
    });

    test('clamps >100 to 5', () {
      expect(converter.normalizeRating('101'), 5);
      expect(converter.normalizeRating('1000'), 5);
    });

    test('returns null for null input', () {
      expect(converter.normalizeRating(null), isNull);
    });

    test('returns null for empty input', () {
      expect(converter.normalizeRating(''), isNull);
    });

    test('returns null for unparseable input', () {
      expect(converter.normalizeRating('abc'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('parseDiveType', () {
    test('maps training keywords', () {
      expect(converter.parseDiveType('training'), 'training');
      expect(converter.parseDiveType('student'), 'training');
      expect(converter.parseDiveType('course'), 'training');
    });

    test('maps night', () {
      expect(converter.parseDiveType('night'), 'night');
    });

    test('maps deep', () {
      expect(converter.parseDiveType('deep'), 'deep');
    });

    test('maps wreck', () {
      expect(converter.parseDiveType('wreck'), 'wreck');
    });

    test('maps drift', () {
      expect(converter.parseDiveType('drift'), 'drift');
    });

    test('maps cave/cavern', () {
      expect(converter.parseDiveType('cave'), 'cave');
      expect(converter.parseDiveType('cavern'), 'cave');
    });

    test('maps technical/tec', () {
      expect(converter.parseDiveType('technical'), 'technical');
      expect(converter.parseDiveType('tec'), 'technical');
    });

    test('maps freedive keywords', () {
      expect(converter.parseDiveType('freedive'), 'freedive');
      expect(converter.parseDiveType('free dive'), 'freedive');
      expect(converter.parseDiveType('apnea'), 'freedive');
    });

    test('maps ice', () {
      expect(converter.parseDiveType('ice'), 'ice');
    });

    test('maps altitude', () {
      expect(converter.parseDiveType('altitude'), 'altitude');
    });

    test('maps shore/beach', () {
      expect(converter.parseDiveType('shore'), 'shore');
      expect(converter.parseDiveType('beach'), 'shore');
    });

    test('maps boat', () {
      expect(converter.parseDiveType('boat'), 'boat');
    });

    test('maps liveaboard', () {
      expect(converter.parseDiveType('liveaboard'), 'liveaboard');
    });

    test('is case-insensitive', () {
      expect(converter.parseDiveType('WRECK'), 'wreck');
      expect(converter.parseDiveType('Night'), 'night');
    });

    test('returns recreational for unknown keywords', () {
      expect(converter.parseDiveType('fun'), 'recreational');
      expect(converter.parseDiveType('vacation'), 'recreational');
    });

    test('returns recreational for null', () {
      expect(converter.parseDiveType(null), 'recreational');
    });

    test('returns recreational for empty string', () {
      expect(converter.parseDiveType(''), 'recreational');
    });
  });

  // ---------------------------------------------------------------------------
  group('parseDouble', () {
    test('parses clean positive number', () {
      expect(converter.parseDouble('42.5'), closeTo(42.5, 0.001));
    });

    test('parses clean integer string', () {
      expect(converter.parseDouble('100'), closeTo(100.0, 0.001));
    });

    test('parses negative number', () {
      expect(converter.parseDouble('-3.5'), closeTo(-3.5, 0.001));
    });

    test('strips commas from thousands separator', () {
      expect(converter.parseDouble('1,234.56'), closeTo(1234.56, 0.001));
    });

    test('strips non-numeric characters (units appended)', () {
      expect(converter.parseDouble('18m'), closeTo(18.0, 0.001));
    });

    test('returns null for null input', () {
      expect(converter.parseDouble(null), isNull);
    });

    test('returns null for empty string', () {
      expect(converter.parseDouble(''), isNull);
    });

    test('returns null for unparseable text', () {
      expect(converter.parseDouble('abc'), isNull);
    });

    test('returns null for string with no digits', () {
      expect(converter.parseDouble('---'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('parseInt', () {
    test('parses and rounds to integer', () {
      expect(converter.parseInt('42'), 42);
    });

    test('rounds decimal up', () {
      expect(converter.parseInt('42.7'), 43);
    });

    test('rounds decimal down', () {
      expect(converter.parseInt('42.2'), 42);
    });

    test('returns null for null input', () {
      expect(converter.parseInt(null), isNull);
    });

    test('returns null for unparseable input', () {
      expect(converter.parseInt('abc'), isNull);
    });
  });
}
