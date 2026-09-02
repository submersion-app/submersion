import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/services/inaturalist_parsers.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

String _fixture(String name) =>
    File('test/fixtures/inaturalist/$name').readAsStringSync();

void main() {
  group('parseAutocomplete', () {
    test('maps the whale shark hit with its German common name', () {
      final hits = parseAutocomplete(
        _fixture('autocomplete_whale_shark_de.json'),
      );

      // The API returned several hits; the whale shark is the first.
      expect(hits, isNotEmpty);
      final hit = hits.first;
      expect(hit.taxonId, 52188);
      expect(hit.scientificName, 'Rhincodon typus');
      expect(hit.rank, 'species');
      expect(hit.commonName, 'Walhai');
      expect(hit.matchedTerm, 'Whale Shark');
      expect(hit.observationCount, greaterThan(0));
      expect(hit.isResolvable, isTrue);
    });

    test('keeps a licensed photo with its attribution', () {
      final hit = parseAutocomplete(
        _fixture('autocomplete_whale_shark_de.json'),
      ).first;

      expect(hit.photo, isNotNull);
      expect(hit.photo!.squareUrl, startsWith('https://'));
      expect(hit.photo!.attribution, contains('CC BY-NC'));
    });

    test('drops an unlicensed photo and falls back to the English name', () {
      const body = '''
      {"results": [{
        "id": 1, "name": "Genus one", "rank": "genus", "rank_level": 20,
        "english_common_name": "Fallback", "observations_count": 3,
        "default_photo": {"license_code": null, "attribution": "(c) x",
                          "square_url": "https://x/1.jpg"}
      }]}''';

      final hit = parseAutocomplete(body).single;

      expect(hit.photo, isNull);
      expect(hit.commonName, 'Fallback');
      expect(hit.isResolvable, isFalse);
    });

    test('tolerates a hit without any common name or photo', () {
      const body =
          '{"results": [{"id": 2, "name": "Nomen nudum", "rank": "species", '
          '"rank_level": 10, "observations_count": 0}]}';

      final hit = parseAutocomplete(body).single;

      expect(hit.commonName, isNull);
      expect(hit.photo, isNull);
      expect(hit.observationCount, 0);
    });

    test('throws a malformed exception for a body that is not JSON', () {
      expect(
        () => parseAutocomplete('<html>'),
        throwsA(
          isA<SpeciesLookupException>().having(
            (e) => e.kind,
            'kind',
            SpeciesLookupErrorKind.malformed,
          ),
        ),
      );
    });
  });

  group('parseTaxonDetail', () {
    test('reads the ancestry in order with ranks', () {
      final detail = parseTaxonDetail(_fixture('taxon_52188_de.json'));

      expect(detail.taxonId, 52188);
      expect(detail.scientificName, 'Rhincodon typus');
      expect(detail.commonName, 'Walhai');
      expect(detail.rank, 'species');
      expect(
        detail.ancestors.first,
        const TaxonAncestor('kingdom', 'Animalia'),
      );
      expect(
        detail.ancestors,
        contains(const TaxonAncestor('class', 'Chondrichthyes')),
      );
      expect(detail.ancestors.last.rank, 'genus');
    });
  });

  group('typed failures', () {
    test('a non-numeric id string is a malformed response, not a leak', () {
      const body =
          '{"results": [{"id": "abc", "name": "Rhincodon typus", '
          '"rank": "species", "rank_level": 10}]}';

      expect(
        () => parseAutocomplete(body),
        throwsA(
          isA<SpeciesLookupException>().having(
            (e) => e.kind,
            'kind',
            SpeciesLookupErrorKind.malformed,
          ),
        ),
      );
    });

    test('a taxon detail with a wrongly typed field is malformed', () {
      const body =
          '{"results": [{"id": 52188, "name": "Rhincodon typus", '
          '"rank": 5, "ancestors": []}]}';

      expect(
        () => parseTaxonDetail(body),
        throwsA(
          isA<SpeciesLookupException>().having(
            (e) => e.kind,
            'kind',
            SpeciesLookupErrorKind.malformed,
          ),
        ),
      );
    });

    test('a taxon detail with a non-numeric id is malformed', () {
      const body =
          '{"results": [{"id": "x", "name": "Rhincodon typus", '
          '"rank": "species"}]}';

      expect(
        () => parseTaxonDetail(body),
        throwsA(isA<SpeciesLookupException>()),
      );
    });
  });
}
