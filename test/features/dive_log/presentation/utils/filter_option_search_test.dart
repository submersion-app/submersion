import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/text/fuzzy_match.dart';

import 'package:submersion/features/dive_log/presentation/utils/filter_option_search.dart';

void main() {
  group('filterOptionMatches', () {
    test('an empty query matches every option', () {
      expect(filterOptionMatches('Blue Hole', ''), isTrue);
      expect(filterOptionMatches('', ''), isTrue);
    });

    test('a whitespace-only query matches every option', () {
      expect(filterOptionMatches('Blue Hole', '   '), isTrue);
    });

    test('matches a substring anywhere in the option, not just the start', () {
      expect(filterOptionMatches('Blue Hole', 'hole'), isTrue);
      expect(filterOptionMatches('Blue Hole', 'ue ho'), isTrue);
    });

    test('ignores case on both sides', () {
      expect(filterOptionMatches('BLUE HOLE', 'blue'), isTrue);
      expect(filterOptionMatches('blue hole', 'BLUE'), isTrue);
    });

    test('ignores diacritics on both sides', () {
      expect(filterOptionMatches('Cancún', 'cancun'), isTrue);
      expect(filterOptionMatches('Cancun', 'cancún'), isTrue);
    });

    test('ignores surrounding whitespace in the query', () {
      expect(filterOptionMatches('Blue Hole', '  hole  '), isTrue);
    });

    test('rejects an option that does not contain the query', () {
      expect(filterOptionMatches('Blue Hole', 'wreck'), isFalse);
    });

    test('rejects any query against an empty option', () {
      expect(filterOptionMatches('', 'hole'), isFalse);
    });
  });

  group('FilterOptionQuery', () {
    test('normalizes the query once and matches normalized search text', () {
      final query = FilterOptionQuery('  CANCÚN ');

      expect(query.normalizedQuery, 'cancun');
      expect(query.matches(normalize('Cancún Reef')), isTrue);
      expect(query.matches(normalize('Blue Hole')), isFalse);
    });

    test('an empty query matches every option', () {
      final query = FilterOptionQuery('   ');

      expect(query.matches(normalize('Blue Hole')), isTrue);
      expect(query.matches(''), isTrue);
    });

    test('agrees with filterOptionMatches', () {
      const haystack = 'Blue Hole Dahab Egypt';
      for (final raw in ['', 'blue', 'EGYPT', 'dahab egypt', 'wreck']) {
        expect(
          FilterOptionQuery(raw).matches(normalize(haystack)),
          filterOptionMatches(haystack, raw),
          reason: 'query "$raw"',
        );
      }
    });
  });

  group('buildFilterSearchText', () {
    test('joins the non-empty parts so any one of them matches', () {
      final searchText = buildFilterSearchText([
        'Blue Hole',
        'Dahab, Egypt',
        'Egypt',
        null,
        '',
      ]);

      expect(filterOptionMatches(searchText, 'blue'), isTrue);
      expect(filterOptionMatches(searchText, 'dahab'), isTrue);
      expect(filterOptionMatches(searchText, 'egypt'), isTrue);
    });

    test('does not let adjacent parts run together into a false match', () {
      final searchText = buildFilterSearchText(['Blue', 'Hole']);

      expect(filterOptionMatches(searchText, 'bluehole'), isFalse);
      expect(filterOptionMatches(searchText, 'blue hole'), isTrue);
    });
  });
}
