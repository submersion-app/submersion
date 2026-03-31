import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/value_converter.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';

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

    test('returns null for 0 and negative values (unrated)', () {
      expect(converter.normalizeRating('0'), isNull);
      expect(converter.normalizeRating('-1'), isNull);
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

  // ===========================================================================
  // ValueTransformService
  // ===========================================================================

  group('ValueTransformService', () {
    late ValueTransformService service;

    setUp(() {
      service = const ValueTransformService();
    });

    // -------------------------------------------------------------------------
    group('applyTransform', () {
      test('returns null for empty string', () {
        for (final transform in ValueTransform.values) {
          expect(service.applyTransform(transform, ''), isNull);
        }
      });

      test('returns null for whitespace-only string', () {
        for (final transform in ValueTransform.values) {
          expect(service.applyTransform(transform, '   '), isNull);
        }
      });

      test('dispatches feetToMeters', () {
        final result = service.applyTransform(
          ValueTransform.feetToMeters,
          '100',
        );
        expect(result, isA<double>());
        expect(result as double, closeTo(30.5, 0.1));
      });

      test('dispatches fahrenheitToCelsius', () {
        final result = service.applyTransform(
          ValueTransform.fahrenheitToCelsius,
          '72',
        );
        expect(result, isA<double>());
        expect(result as double, closeTo(22.2, 0.1));
      });

      test('dispatches psiToBar', () {
        final result = service.applyTransform(ValueTransform.psiToBar, '3000');
        expect(result, isA<double>());
        expect(result as double, closeTo(206.8, 0.1));
      });

      test('dispatches cubicFeetToLiters', () {
        final result = service.applyTransform(
          ValueTransform.cubicFeetToLiters,
          '80',
        );
        expect(result, isA<double>());
        expect(result as double, closeTo(2265.3, 0.1));
      });

      test('dispatches minutesToSeconds', () {
        final result = service.applyTransform(
          ValueTransform.minutesToSeconds,
          '45',
        );
        expect(result, isA<Duration>());
        expect((result as Duration).inSeconds, 2700);
      });

      test('dispatches hmsToSeconds', () {
        final result = service.applyTransform(
          ValueTransform.hmsToSeconds,
          '1:23:45',
        );
        expect(result, isA<Duration>());
        expect((result as Duration).inSeconds, 5025);
      });

      test('dispatches visibilityScale', () {
        final result = service.applyTransform(
          ValueTransform.visibilityScale,
          'excellent',
        );
        expect(result, 'excellent');
      });

      test('dispatches diveTypeMap', () {
        final result = service.applyTransform(
          ValueTransform.diveTypeMap,
          'wreck',
        );
        expect(result, 'wreck');
      });

      test('dispatches ratingScale', () {
        final result = service.applyTransform(ValueTransform.ratingScale, '4');
        expect(result, 4);
      });
    });

    // -------------------------------------------------------------------------
    group('feetToMeters', () {
      test('converts 100 ft to meters', () {
        expect(service.feetToMeters('100'), closeTo(30.5, 0.1));
      });

      test('converts 0 ft to 0 m', () {
        expect(service.feetToMeters('0'), closeTo(0.0, 0.01));
      });

      test('converts 60 ft to meters', () {
        expect(service.feetToMeters('60'), closeTo(18.3, 0.1));
      });

      test('strips non-numeric characters', () {
        expect(service.feetToMeters('100ft'), closeTo(30.5, 0.1));
      });

      test('returns null for non-numeric input', () {
        expect(service.feetToMeters('abc'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('fahrenheitToCelsius', () {
      test('converts 72 F to Celsius', () {
        expect(service.fahrenheitToCelsius('72'), closeTo(22.2, 0.1));
      });

      test('converts 32 F to 0 C', () {
        expect(service.fahrenheitToCelsius('32'), closeTo(0.0, 0.1));
      });

      test('converts 212 F to 100 C', () {
        expect(service.fahrenheitToCelsius('212'), closeTo(100.0, 0.1));
      });

      test('returns null for non-numeric input', () {
        expect(service.fahrenheitToCelsius('warm'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('psiToBar', () {
      test('converts 3000 PSI to bar', () {
        expect(service.psiToBar('3000'), closeTo(206.8, 0.1));
      });

      test('converts 0 PSI to 0 bar', () {
        expect(service.psiToBar('0'), closeTo(0.0, 0.01));
      });

      test('returns null for non-numeric input', () {
        expect(service.psiToBar('full'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('cubicFeetToLiters', () {
      test('converts 80 cuft to liters', () {
        expect(service.cubicFeetToLiters('80'), closeTo(2265.3, 0.1));
      });

      test('converts 0 cuft to 0 L', () {
        expect(service.cubicFeetToLiters('0'), closeTo(0.0, 0.01));
      });

      test('returns null for non-numeric input', () {
        expect(service.cubicFeetToLiters('big'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('minutesToSeconds', () {
      test('converts 45 minutes to Duration', () {
        final result = service.minutesToSeconds('45');
        expect(result, isNotNull);
        expect(result!.inSeconds, 2700);
      });

      test('converts fractional minutes: "45.5" -> 2730 seconds', () {
        final result = service.minutesToSeconds('45.5');
        expect(result, isNotNull);
        expect(result!.inSeconds, 2730);
      });

      test('converts 0 minutes to 0 seconds', () {
        final result = service.minutesToSeconds('0');
        expect(result, isNotNull);
        expect(result!.inSeconds, 0);
      });

      test('returns null for non-numeric input', () {
        expect(service.minutesToSeconds('abc'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('hmsToSeconds', () {
      test('parses H:MM:SS format: "1:23:45"', () {
        final result = service.hmsToSeconds('1:23:45');
        expect(result, isNotNull);
        expect(result!.inSeconds, 5025);
      });

      test('parses M:SS format: "25:20"', () {
        final result = service.hmsToSeconds('25:20');
        expect(result, isNotNull);
        expect(result!.inSeconds, 1520);
      });

      test('parses M:SS format: "0:42"', () {
        final result = service.hmsToSeconds('0:42');
        expect(result, isNotNull);
        expect(result!.inSeconds, 42);
      });

      test('parses "0:0:0" as zero duration', () {
        final result = service.hmsToSeconds('0:0:0');
        expect(result, isNotNull);
        expect(result!.inSeconds, 0);
      });

      test('returns null for single-part input', () {
        expect(service.hmsToSeconds('42'), isNull);
      });

      test('returns null for non-numeric colon-separated input', () {
        expect(service.hmsToSeconds('a:b:c'), isNull);
      });

      test('returns null for four-part input', () {
        expect(service.hmsToSeconds('1:2:3:4'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('parseVisibilityScale', () {
      test('maps "excellent"', () {
        expect(service.parseVisibilityScale('excellent'), 'excellent');
      });

      test('maps "good"', () {
        expect(service.parseVisibilityScale('good'), 'good');
      });

      test('maps "moderate"', () {
        expect(service.parseVisibilityScale('moderate'), 'moderate');
      });

      test('maps "fair" to moderate', () {
        expect(service.parseVisibilityScale('fair'), 'moderate');
      });

      test('maps "poor"', () {
        expect(service.parseVisibilityScale('poor'), 'poor');
      });

      test('maps range-based text ">30" to excellent', () {
        expect(service.parseVisibilityScale('>30'), 'excellent');
      });

      test('maps range-based text "15-30" to good', () {
        expect(service.parseVisibilityScale('15-30'), 'good');
      });

      test('maps range-based text "5-15" to moderate', () {
        expect(service.parseVisibilityScale('5-15'), 'moderate');
      });

      test('maps range-based text "<5" to poor', () {
        expect(service.parseVisibilityScale('<5'), 'poor');
      });

      group('numeric meters', () {
        test('>30m -> excellent', () {
          expect(service.parseVisibilityScale('35'), 'excellent');
        });

        test('>15m -> good', () {
          expect(service.parseVisibilityScale('20'), 'good');
        });

        test('>5m -> moderate', () {
          expect(service.parseVisibilityScale('10'), 'moderate');
        });

        test('<=5m -> poor', () {
          expect(service.parseVisibilityScale('3'), 'poor');
        });
      });

      test('is case-insensitive', () {
        expect(service.parseVisibilityScale('EXCELLENT'), 'excellent');
        expect(service.parseVisibilityScale('Good'), 'good');
      });

      test('returns "unknown" for unrecognised text', () {
        expect(service.parseVisibilityScale('blurry'), 'unknown');
      });
    });

    // -------------------------------------------------------------------------
    group('parseDiveType', () {
      test('maps training keywords', () {
        expect(service.parseDiveType('training'), 'training');
        expect(service.parseDiveType('course'), 'training');
      });

      test('maps night', () {
        expect(service.parseDiveType('night'), 'night');
      });

      test('maps deep', () {
        expect(service.parseDiveType('deep'), 'deep');
      });

      test('maps wreck', () {
        expect(service.parseDiveType('wreck'), 'wreck');
      });

      test('maps drift', () {
        expect(service.parseDiveType('drift'), 'drift');
      });

      test('maps cave/cavern', () {
        expect(service.parseDiveType('cave'), 'cave');
        expect(service.parseDiveType('cavern'), 'cave');
      });

      test('maps tech/technical', () {
        expect(service.parseDiveType('technical'), 'technical');
        expect(service.parseDiveType('tech'), 'technical');
      });

      test('maps freedive keywords', () {
        expect(service.parseDiveType('freedive'), 'freedive');
        expect(service.parseDiveType('free diving'), 'freedive');
      });

      test('maps ice', () {
        expect(service.parseDiveType('ice'), 'ice');
      });

      test('maps altitude', () {
        expect(service.parseDiveType('altitude'), 'altitude');
      });

      test('maps shore', () {
        expect(service.parseDiveType('shore'), 'shore');
      });

      test('maps boat', () {
        expect(service.parseDiveType('boat'), 'boat');
      });

      test('maps liveaboard', () {
        expect(service.parseDiveType('liveaboard'), 'liveaboard');
      });

      test('is case-insensitive', () {
        expect(service.parseDiveType('WRECK'), 'wreck');
        expect(service.parseDiveType('Night'), 'night');
      });

      test('returns recreational for unknown input', () {
        expect(service.parseDiveType('fun'), 'recreational');
        expect(service.parseDiveType('vacation'), 'recreational');
      });
    });

    // -------------------------------------------------------------------------
    group('normalizeRating', () {
      test('preserves 1-5 ratings', () {
        expect(service.normalizeRating('1'), 1);
        expect(service.normalizeRating('3'), 3);
        expect(service.normalizeRating('5'), 5);
      });

      test('returns null for 0 and negative values', () {
        expect(service.normalizeRating('0'), isNull);
        expect(service.normalizeRating('-1'), isNull);
      });

      test('converts 6-10 scale: divide by 2, clamped 1-5', () {
        expect(service.normalizeRating('6'), 3);
        expect(service.normalizeRating('8'), 4);
        expect(service.normalizeRating('10'), 5);
      });

      test('converts 11-100 scale: divide by 20, clamped 1-5', () {
        expect(service.normalizeRating('20'), 1);
        expect(service.normalizeRating('60'), 3);
        expect(service.normalizeRating('100'), 5);
      });

      test('clamps >100 to range 1-5', () {
        expect(service.normalizeRating('200'), 5);
      });

      test('returns null for non-numeric input', () {
        expect(service.normalizeRating('abc'), isNull);
      });

      test('rounds fractional values on 1-5 scale', () {
        expect(service.normalizeRating('2.6'), 3);
        expect(service.normalizeRating('4.4'), 4);
      });
    });

    // -------------------------------------------------------------------------
    group('parseDate', () {
      test('parses yyyy-MM-dd', () {
        final result = service.parseDate('2024-03-15');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
        expect(result.isUtc, isTrue);
      });

      test('parses MM/dd/yyyy', () {
        final result = service.parseDate('03/15/2024');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });

      test('parses yyyy/MM/dd', () {
        final result = service.parseDate('2024/03/15');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });

      test('parses dd.MM.yyyy', () {
        final result = service.parseDate('15.03.2024');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });

      test('parses ISO 8601 with timezone as fallback', () {
        final result = service.parseDate('2024-03-15T10:30:00Z');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
        expect(result.isUtc, isTrue);
      });

      test('returns null for unparseable input', () {
        expect(service.parseDate('not-a-date'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('parseTime', () {
      test('parses HH:mm (24h)', () {
        final result = service.parseTime('14:30');
        expect(result, isNotNull);
        expect(result!.hour, 14);
        expect(result.minute, 30);
      });

      test('parses H:mm (single-digit hour)', () {
        final result = service.parseTime('9:05');
        expect(result, isNotNull);
        expect(result!.hour, 9);
        expect(result.minute, 5);
      });

      test('parses HH:mm:ss (matched by HH:mm first, seconds ignored)', () {
        // Note: the format list tries 'HH:mm' before 'HH:mm:ss', so
        // '14:30:45' is parsed by 'HH:mm' which captures hour and minute
        // but drops seconds.
        final result = service.parseTime('14:30:45');
        expect(result, isNotNull);
        expect(result!.hour, 14);
        expect(result.minute, 30);
      });

      test('returns null for unparseable input', () {
        expect(service.parseTime('not-a-time'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('isLikelyFeet', () {
      test('returns true when column name contains "ft"', () {
        expect(
          ValueTransformService.isLikelyFeet(['30'], 'Max Depth (ft)'),
          isTrue,
        );
      });

      test('returns true when column name contains "feet"', () {
        expect(
          ValueTransformService.isLikelyFeet(['30'], 'Depth in feet'),
          isTrue,
        );
      });

      test('returns false when column name contains "meter"', () {
        expect(
          ValueTransformService.isLikelyFeet(['130'], 'Depth (meter)'),
          isFalse,
        );
      });

      test('returns false when column name contains "m)"', () {
        expect(
          ValueTransformService.isLikelyFeet(['130'], 'Depth (m)'),
          isFalse,
        );
      });

      test('returns true when majority of values > 100', () {
        expect(
          ValueTransformService.isLikelyFeet(['110', '120', '130'], 'depth'),
          isTrue,
        );
      });

      test('returns false when majority of values <= 100', () {
        expect(
          ValueTransformService.isLikelyFeet(['18', '25', '30'], 'depth'),
          isFalse,
        );
      });

      test('returns false for empty sample values with generic name', () {
        expect(ValueTransformService.isLikelyFeet([], 'depth'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('isLikelyFahrenheit', () {
      test('returns true when column name contains "fahrenheit"', () {
        expect(
          ValueTransformService.isLikelyFahrenheit(['70'], 'Temp (Fahrenheit)'),
          isTrue,
        );
      });

      test('returns true when column name contains "f)"', () {
        expect(
          ValueTransformService.isLikelyFahrenheit(['70'], 'Water Temp (F)'),
          isTrue,
        );
      });

      test('returns false when column name contains "celsius"', () {
        expect(
          ValueTransformService.isLikelyFahrenheit(['70'], 'Temp (Celsius)'),
          isFalse,
        );
      });

      test('returns false when column name contains "c)"', () {
        expect(
          ValueTransformService.isLikelyFahrenheit(['70'], 'Temp (C)'),
          isFalse,
        );
      });

      test('returns true when majority of values > 50', () {
        expect(
          ValueTransformService.isLikelyFahrenheit([
            '72',
            '68',
            '75',
          ], 'temperature'),
          isTrue,
        );
      });

      test('returns false when majority of values <= 50', () {
        expect(
          ValueTransformService.isLikelyFahrenheit([
            '22',
            '18',
            '25',
          ], 'temperature'),
          isFalse,
        );
      });

      test('returns false for empty sample values with generic name', () {
        expect(ValueTransformService.isLikelyFahrenheit([], 'temp'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('isLikelyPsi', () {
      test('returns true when column name contains "psi"', () {
        expect(
          ValueTransformService.isLikelyPsi(['3000'], 'Start Pressure (psi)'),
          isTrue,
        );
      });

      test('returns false when column name contains "bar"', () {
        expect(
          ValueTransformService.isLikelyPsi(['3000'], 'Pressure (bar)'),
          isFalse,
        );
      });

      test('returns true when majority of values > 500', () {
        expect(
          ValueTransformService.isLikelyPsi([
            '3000',
            '2800',
            '3200',
          ], 'pressure'),
          isTrue,
        );
      });

      test('returns false when majority of values <= 500', () {
        expect(
          ValueTransformService.isLikelyPsi(['200', '210', '180'], 'pressure'),
          isFalse,
        );
      });

      test('returns false for empty sample values with generic name', () {
        expect(ValueTransformService.isLikelyPsi([], 'pressure'), isFalse);
      });

      test('returns true for mixed-case "PSI" in column name', () {
        expect(
          ValueTransformService.isLikelyPsi(['200'], 'Start Pressure (PSI)'),
          isTrue,
        );
      });

      test('returns false for mixed-case "Bar" in column name', () {
        expect(
          ValueTransformService.isLikelyPsi(['3000'], 'Pressure (Bar)'),
          isFalse,
        );
      });

      test('uses majority heuristic with mixed high/low values', () {
        // 2 out of 3 values > 500 -> true
        expect(
          ValueTransformService.isLikelyPsi([
            '3000',
            '200',
            '2800',
          ], 'pressure'),
          isTrue,
        );
        // 1 out of 3 values > 500 -> false
        expect(
          ValueTransformService.isLikelyPsi(['200', '210', '3000'], 'pressure'),
          isFalse,
        );
      });

      test('handles non-numeric values in samples gracefully', () {
        expect(
          ValueTransformService.isLikelyPsi(['abc', 'def'], 'pressure'),
          isFalse,
        );
      });
    });

    // -------------------------------------------------------------------------
    group('hmsToSeconds - non-numeric edge cases', () {
      test('returns null for non-numeric 2-part M:SS', () {
        expect(service.hmsToSeconds('a:b'), isNull);
      });

      test('returns null for non-numeric 3-part H:M:S', () {
        expect(service.hmsToSeconds('x:y:z'), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('parseDate - ISO fallback for non-UTC DateTime', () {
      test('converts non-UTC parsed DateTime to UTC components', () {
        // DateTime.tryParse with an offset produces a UTC datetime; test a
        // string that DateTime.tryParse handles but DateFormat does not.
        final result = service.parseDate('2024-03-15T10:30:00+05:00');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
        expect(result.year, 2024);
        expect(result.month, 3);
      });
    });

    // -------------------------------------------------------------------------
    group('parseDate - additional format coverage', () {
      test('parses dd/MM/yyyy', () {
        final result = service.parseDate('15/03/2024');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
      });

      test('parses dd-MM-yyyy', () {
        final result = service.parseDate('15-03-2024');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
      });

      test('parses MM-dd-yyyy', () {
        final result = service.parseDate('03-25-2024');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
        expect(result.year, 2024);
        expect(result.month, 3);
        expect(result.day, 25);
      });

      test('parses yyyy.MM.dd', () {
        final result = service.parseDate('2024.03.15');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
        expect(result.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });
    });

    // -------------------------------------------------------------------------
    group('parseTime - edge cases', () {
      test('returns null for unparseable time strings', () {
        expect(service.parseTime('not-a-time'), isNull);
        expect(service.parseTime('xyz'), isNull);
      });

      test('parses single-digit hour H:mm format', () {
        final result = service.parseTime('9:05');
        expect(result, isNotNull);
        expect(result!.hour, 9);
        expect(result.minute, 5);
      });

      test('parses HH:mm:ss format', () {
        final result = service.parseTime('14:30:45');
        expect(result, isNotNull);
        // HH:mm matches first (not strict), so hour/minute are captured.
        expect(result!.hour, 14);
        expect(result.minute, 30);
      });
    });
  });

  // ===========================================================================
  // ValueConverter - parseDuration non-numeric edge cases
  // ===========================================================================

  group('ValueConverter parseDuration - non-numeric colon-separated', () {
    late ValueConverter converter;

    setUp(() {
      converter = const ValueConverter();
    });

    test('returns null for 2-part hms with non-numeric parts', () {
      expect(converter.parseDuration('a:b', DurationFormat.hms), isNull);
    });

    test('returns null for 3-part hms with non-numeric parts', () {
      expect(converter.parseDuration('a:b:c', DurationFormat.hms), isNull);
    });

    test('returns null for 4-part hms input', () {
      expect(converter.parseDuration('1:2:3:4', DurationFormat.hms), isNull);
    });
  });

  // ===========================================================================
  // ValueTransformService - parseDate ISO fallback non-UTC path
  // ===========================================================================

  group(
    'ValueTransformService parseDate - ISO fallback non-UTC conversion',
    () {
      late ValueTransformService service;

      setUp(() {
        service = const ValueTransformService();
      });

      test('converts non-UTC DateTime.tryParse result to UTC components', () {
        // DateTime.tryParse('2024-03-15T10:30:00') returns a local DateTime
        // (isUtc == false), which the parseDate method should convert to UTC
        // by copying year/month/day/etc. into DateTime.utc().
        final result = service.parseDate('2024-03-15T10:30:00');
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
        expect(result.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
        expect(result.hour, 10);
        expect(result.minute, 30);
      });
    },
  );
}
