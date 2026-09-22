import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/utils/location_options.dart';

void main() {
  group('distinctLocationLabels', () {
    test('drops null and blank values', () {
      expect(distinctLocationLabels(['Egypt', null, '', '   ']), ['Egypt']);
    });

    test('sorts the result alphabetically', () {
      expect(distinctLocationLabels(['Thailand', 'Egypt', 'Fiji']), [
        'Egypt',
        'Fiji',
        'Thailand',
      ]);
    });

    test('collapses values that differ only by case or surrounding '
        'whitespace (issue #1373)', () {
      expect(distinctLocationLabels(['Egypt', 'Egypt', ' EGYPT ']), ['Egypt']);
    });

    test('collapses values that differ only by internal whitespace runs', () {
      expect(distinctLocationLabels(['New Zealand', 'New  Zealand']), [
        'New Zealand',
      ]);
    });

    test('frequency outranks capitalization: the more common spelling wins '
        'even when it is not the "properly" capitalized one', () {
      expect(distinctLocationLabels(['egypt', 'egypt', 'Egypt']), ['egypt']);
      expect(distinctLocationLabels(['Egypt', 'egypt', 'egypt']), ['egypt']);
    });

    test('a single typo does not outrank the acronym most sites use', () {
      expect(distinctLocationLabels(['UK', 'UK', 'UK', 'Uk']), ['UK']);
    });

    test('when spellings are equally frequent, prefers ordinary '
        'capitalization over all-caps or all-lowercase', () {
      expect(distinctLocationLabels(['Egypt', 'egypt', ' EGYPT ']), ['Egypt']);
    });

    test('treats different locations as distinct entries', () {
      expect(distinctLocationLabels(['Egypt', 'Thailand', 'Egypt']), [
        'Egypt',
        'Thailand',
      ]);
    });

    test('returns an empty list when nothing is left', () {
      expect(distinctLocationLabels([null, '', '  ']), isEmpty);
    });
  });

  group('locationDedupKey', () {
    test('normalizes case and surrounding whitespace', () {
      expect(locationDedupKey(' Egypt '), locationDedupKey('egypt'));
    });

    test('collapses internal whitespace runs', () {
      expect(locationDedupKey('New  Zealand'), locationDedupKey('New Zealand'));
    });

    test('does not collapse genuinely different values', () {
      expect(
        locationDedupKey('Egypt') == locationDedupKey('Egypt (Sinai)'),
        isFalse,
      );
    });
  });
}
