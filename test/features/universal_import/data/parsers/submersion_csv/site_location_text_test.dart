import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/site_location_text.dart';

void main() {
  test(
    'locality prefix dropped, region and country split on the last comma',
    () {
      expect(parseSiteLocationText('San Pedro · Lighthouse Reef, Belize'), (
        region: 'Lighthouse Reef',
        country: 'Belize',
      ));
    },
  );

  test('a region containing a comma keeps it', () {
    expect(parseSiteLocationText('Bay Islands, Roatan, Honduras'), (
      region: 'Bay Islands, Roatan',
      country: 'Honduras',
    ));
  });

  test('a single part is read as the country', () {
    expect(parseSiteLocationText('Egypt'), (region: null, country: 'Egypt'));
  });

  test('blank is empty', () {
    expect(parseSiteLocationText('  '), (region: null, country: null));
    expect(parseSiteLocationText(null), (region: null, country: null));
  });
}
