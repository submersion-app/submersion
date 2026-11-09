import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

void main() {
  const json = '''
{
  "speciesKeys": {"2417522": "sp_whale_shark", "2418064": "sp_grey_reef_shark"},
  "taxonKeys": [1, 2]
}
''';

  group('SpeciesCatalogMatcher.gbifKeyFor', () {
    test('returns the species-rank key for a built-in id', () {
      final matcher = SpeciesCatalogMatcher.fromJsonString(json);

      expect(matcher.gbifKeyFor('sp_whale_shark'), 2417522);
      expect(matcher.gbifKeyFor('sp_grey_reef_shark'), 2418064);
    });

    test('returns null for an id the asset does not name', () {
      final matcher = SpeciesCatalogMatcher.fromJsonString(json);

      expect(matcher.gbifKeyFor('sp_unknown'), isNull);
    });

    test('still maps keys to ids the other way', () {
      final matcher = SpeciesCatalogMatcher.fromJsonString(json);

      expect(matcher.localIdFor(2417522), 'sp_whale_shark');
    });
  });
}
