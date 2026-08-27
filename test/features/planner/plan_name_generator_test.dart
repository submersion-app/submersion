import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';

void main() {
  final date = DateTime(2026, 7, 25);

  group('generateDefaultPlanName', () {
    // The generator dates the name with DateFormat.MMMd(), which resolves
    // against Intl.defaultLocale - a process global that app.dart sets from
    // the app locale. Pin it so the "Jul 25" assertions state their real
    // dependency instead of riding on intl's implicit en_US fallback, and
    // restore it so the global stays contained.
    //
    // Setting the global explicitly means intl stops using its built-in
    // fallback and demands real symbol data, so the locale must be initialized
    // first. Widget tests get that for free from GlobalMaterialLocalizations;
    // this is a pure unit test, so it has to ask.
    late String? previousLocale;

    // Symbol data does not depend on per-test state, so load it once.
    setUpAll(() => initializeDateFormatting('en'));

    setUp(() {
      previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
    });

    tearDown(() => Intl.defaultLocale = previousLocale);

    test('combines site, depth, and date', () {
      expect(
        generateDefaultPlanName(
          siteName: 'Blue Hole',
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole 40m - Jul 25',
      );
    });

    test('omits the depth when no depth label is supplied', () {
      expect(
        generateDefaultPlanName(
          siteName: 'Blue Hole',
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole - Jul 25',
      );
    });

    test('omits the site when no site name is supplied', () {
      expect(
        generateDefaultPlanName(
          siteName: null,
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        '40m - Jul 25',
      );
    });

    test('falls back to the supplied label when site and depth are absent', () {
      expect(
        generateDefaultPlanName(
          siteName: null,
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Dive Plan - Jul 25',
      );
    });

    test('treats a blank site name as absent', () {
      expect(
        generateDefaultPlanName(
          siteName: '   ',
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Dive Plan - Jul 25',
      );
    });

    test('trims surrounding whitespace on the site name', () {
      expect(
        generateDefaultPlanName(
          siteName: '  Blue Hole  ',
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole 40m - Jul 25',
      );
    });
  });
}
