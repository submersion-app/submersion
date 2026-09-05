import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';

void main() {
  const dateLabel = 'Jul 25';

  group('generateDefaultPlanName', () {
    // The caller formats the date, in the diver's own order, and hands the
    // generator a finished label (#1512). Nothing here depends on
    // Intl.defaultLocale any more.

    test('combines site, depth, and date', () {
      expect(
        generateDefaultPlanName(
          siteName: 'Blue Hole',
          depthLabel: '40m',
          dateLabel: dateLabel,
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
          dateLabel: dateLabel,
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
          dateLabel: dateLabel,
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
          dateLabel: dateLabel,
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
          dateLabel: dateLabel,
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
          dateLabel: dateLabel,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole 40m - Jul 25',
      );
    });
  });
}
