import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  group('the bundled asset', () {
    final matcher = SpeciesCatalogMatcher.fromJsonString(
      File(
        p.join('assets', 'data', 'species_gbif_keys.json'),
      ).readAsStringSync(),
    );

    // A synonym's key finds only the records filed under the old name: the
    // zebra shark's drew 116 of its 1,490 records, the giant cuttlefish's 13
    // of 1,396. Occurrence records carry the accepted key, so nearby records
    // match a species by it too.
    test('names a renamed species by its accepted key, not its synonym', () {
      expect(matcher.gbifKeyFor('sp_zebra_shark'), 2417450);
      expect(matcher.gbifKeyFor('sp_giant_cuttlefish'), 12258728);
      expect(matcher.localIdFor(2417450), 'sp_zebra_shark');
      expect(matcher.localIdFor(8493577), isNull);
    });
  });
}
