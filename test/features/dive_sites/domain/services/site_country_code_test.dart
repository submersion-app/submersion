import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/services/site_country_code.dart';

/// The code a site saves with its country text (issue #4426): the one that
/// came with that text (the geocoder's, or the stored one), else the code
/// the text reads as, so a hand edit never leaves a stale flag.
void main() {
  test('text as geocoded keeps the geocoder code', () {
    expect(
      countryCodeOnSave(
        country: 'Korea',
        known: (country: 'Korea', code: 'KR'),
      ),
      'KR',
    );
  });

  test('surrounding whitespace does not count as an edit', () {
    expect(
      countryCodeOnSave(
        country: 'Korea',
        known: (country: ' Korea ', code: 'KR'),
      ),
      'KR',
    );
  });

  test('a hand edit reads the new text', () {
    expect(
      countryCodeOnSave(
        country: 'Mexico',
        known: (country: 'Korea', code: 'KR'),
      ),
      'MX',
    );
  });

  test('a hand edit to unrecognised text clears the code', () {
    expect(
      countryCodeOnSave(
        country: 'Atlantis',
        known: (country: 'Korea', code: 'KR'),
      ),
      isNull,
    );
  });

  test('no known code reads the text', () {
    expect(
      countryCodeOnSave(country: 'México', known: (country: null, code: null)),
      'MX',
    );
  });

  test('a cleared country clears the code', () {
    expect(
      countryCodeOnSave(country: null, known: (country: 'Korea', code: 'KR')),
      isNull,
    );
  });
}
