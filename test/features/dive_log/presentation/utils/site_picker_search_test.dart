import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/site_picker_search.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('siteMatchesPickerQuery', () {
    const blueHole = DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      country: 'Belize',
      region: 'Lighthouse Reef',
    );

    const cenote = DiveSite(
      id: 'site-2',
      name: 'Dos Ojos',
      country: 'Mexico',
      region: 'Yucatan',
    );

    test('returns true for empty query', () {
      expect(siteMatchesPickerQuery(blueHole, ''), isTrue);
      expect(siteMatchesPickerQuery(blueHole, '   '), isTrue);
    });

    test('matches by site name case-insensitively', () {
      expect(siteMatchesPickerQuery(blueHole, 'blue'), isTrue);
      expect(siteMatchesPickerQuery(blueHole, 'BLUE HOLE'), isTrue);
    });

    test('matches by country and region fields', () {
      expect(siteMatchesPickerQuery(blueHole, 'belize'), isTrue);
      expect(siteMatchesPickerQuery(blueHole, 'reef'), isTrue);
      expect(siteMatchesPickerQuery(cenote, 'yucatan'), isTrue);
    });

    test('trims whitespace around query', () {
      expect(siteMatchesPickerQuery(cenote, '  dos ojos  '), isTrue);
    });

    test('returns false when query does not match searchable fields', () {
      expect(siteMatchesPickerQuery(blueHole, 'galapagos'), isFalse);
      expect(siteMatchesPickerQuery(cenote, 'belize'), isFalse);
    });
  });
}
