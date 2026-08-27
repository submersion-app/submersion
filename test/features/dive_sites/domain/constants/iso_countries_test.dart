import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/constants/iso_countries.dart';

void main() {
  group('isoCountryNames', () {
    test('contains a broad set of countries', () {
      expect(isoCountryNames.length, greaterThan(150));
    });

    test('includes common diving destinations', () {
      expect(isoCountryNames, contains('Indonesia'));
      expect(isoCountryNames, contains('Egypt'));
      expect(isoCountryNames, contains('Philippines'));
      expect(isoCountryNames, contains('United States'));
      expect(isoCountryNames, contains('Mexico'));
    });

    test('has no duplicates', () {
      expect(isoCountryNames.toSet().length, isoCountryNames.length);
    });

    test('is sorted alphabetically', () {
      final sorted = [...isoCountryNames]..sort();
      expect(isoCountryNames, sorted);
    });
  });
}
