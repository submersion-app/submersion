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

    test('scores a known pair', () {
      expect(diceCoefficient('night', 'nacht'), 0.25);
    });

    test('counts a repeated bigram as often as both sides have it', () {
      expect(diceCoefficient('aaaa', 'aa'), 0.5);
      expect(diceCoefficient('abab', 'baba'), closeTo(2 / 3, 1e-12));
    });

    test('tells bigrams of characters outside Latin-1 apart', () {
      expect(diceCoefficient('海の家', '海の島'), 0.5);
      // Packed into too few bits, these two pairs would come out the same.
      expect(diceCoefficient('a一', 'o漀'), 0.0);
    });
  });

  group('DiceText', () {
    test('compares like diceCoefficient, however often', () {
      const pairs = [
        ('Manta Pt', 'Manta Point'),
        ('Blue Hole', 'Shark Reef'),
        ('Cancún', 'cancun'),
        ('a', 'b'),
        ('', ''),
        ('', 'ab'),
      ];
      for (final (a, b) in pairs) {
        final left = DiceText(a);
        final right = DiceText(b);
        expect(left.similarity(right), diceCoefficient(a, b), reason: '$a/$b');
        expect(right.similarity(left), diceCoefficient(a, b), reason: '$b/$a');
      }
    });

    test('holds the normalized text', () {
      expect(DiceText('  Cancún ').normalized, 'cancun');
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
