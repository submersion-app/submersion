import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_search.dart';

const _site = DiveSite(
  id: 's1',
  name: 'Blue Hole',
  country: 'Egypt',
  region: 'South Sinai',
  city: 'Dahab',
  island: 'Nowhere Isle',
  bodyOfWater: 'Red Sea',
);

void main() {
  group('siteSearchText', () {
    test('joins every location field and skips blanks', () {
      expect(
        siteSearchText(_site),
        'Blue Hole Egypt South Sinai Dahab Nowhere Isle Red Sea',
      );
      expect(
        siteSearchText(const DiveSite(id: 'x', name: 'Reef', country: '  ')),
        'Reef',
      );
    });
  });

  group('SiteQuery', () {
    test('matches each location field', () {
      for (final q in ['egypt', 'sinai', 'dahab', 'isle', 'red sea', 'hole']) {
        expect(SiteQuery(q).matchesSite(_site), isTrue, reason: q);
      }
    });

    test('folds case and diacritics', () {
      const site = DiveSite(id: 'c', name: 'Cenote', city: 'Cancún');
      expect(SiteQuery('CANCUN').matchesSite(site), isTrue);
    });

    test('every word must match somewhere, in any order', () {
      expect(SiteQuery('blue egypt').matchesSite(_site), isTrue);
      expect(SiteQuery('egypt blue').matchesSite(_site), isTrue);
      expect(SiteQuery('blue mexico').matchesSite(_site), isFalse);
    });

    test('a whitespace-only query is empty and matches everything', () {
      final query = SiteQuery('   ');
      expect(query.isEmpty, isTrue);
      expect(query.matchesSite(_site), isTrue);
    });
  });
}
