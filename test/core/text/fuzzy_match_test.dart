import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

void main() {
  group('normalize', () {
    test('trims, lowercases, and strips diacritics', () {
      expect(normalize('  Cancún '), 'cancun');
      expect(normalize('Malapascua'), 'malapascua');
      expect(normalize('ÅÉÎÕÜ'), 'aeiou');
    });
  });

  group('diceCoefficient', () {
    test('identical normalized strings score 1.0', () {
      expect(diceCoefficient('Manta Point', 'manta point'), 1.0);
    });

    test('near-duplicate "Manta Pt" vs "Manta Point" scores above 0.7', () {
      expect(diceCoefficient('Manta Pt', 'Manta Point'), greaterThan(0.7));
    });

    test('unrelated strings score low', () {
      expect(diceCoefficient('Blue Hole', 'Shark Reef'), lessThan(0.3));
    });

    test('sub-2-char inputs fall back to equality', () {
      expect(diceCoefficient('a', 'a'), 1.0);
      expect(diceCoefficient('a', 'b'), 0.0);
    });
  });

  group('findSimilar', () {
    test('returns the best candidate at or above threshold', () {
      final result = findSimilar('Manta Pt', ['Blue Hole', 'Manta Point']);
      expect(result, 'Manta Point');
    });

    test('returns null when nothing meets the threshold', () {
      expect(findSimilar('Atlantis', ['Blue Hole', 'Shark Reef']), isNull);
    });

    test('ties resolve to the earliest-listed candidate', () {
      expect(findSimilar('Reef', ['Reef A', 'Reef B']), 'Reef A');
    });
  });
}
