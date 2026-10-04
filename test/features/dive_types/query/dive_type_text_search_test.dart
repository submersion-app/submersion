import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_types/query/dive_type_text_search.dart';

void main() {
  group('builtInDiveTypeIdsMatching', () {
    test('matches the English name, ignoring case', () {
      expect(builtInDiveTypeIdsMatching('ice'), {'ice'});
      expect(builtInDiveTypeIdsMatching('ICE'), {'ice'});
    });

    test('matches a translated full name in any app language', () {
      expect(builtInDiveTypeIdsMatching('Eistauchen'), {'ice'});
      expect(builtInDiveTypeIdsMatching('sotto ghiaccio'), {'ice'});
    });

    test('matches a translated short name', () {
      expect(builtInDiveTypeIdsMatching('wrack'), {'wreck'});
    });

    test('folds case beyond ASCII', () {
      expect(builtInDiveTypeIdsMatching('ÉPAVE'), {'wreck'});
      expect(builtInDiveTypeIdsMatching('épave'), {'wreck'});
    });

    test('trims surrounding whitespace', () {
      expect(builtInDiveTypeIdsMatching('  nacht  '), {'night'});
    });

    test('a substring can match several types', () {
      // "Cave" and "Cavern" both contain "cav".
      expect(
        builtInDiveTypeIdsMatching('cav'),
        containsAll(['cave', 'cavern']),
      );
    });

    test('an unknown or blank term matches nothing', () {
      expect(builtInDiveTypeIdsMatching('zzznope'), isEmpty);
      expect(builtInDiveTypeIdsMatching(''), isEmpty);
      expect(builtInDiveTypeIdsMatching('   '), isEmpty);
    });

    test('LIKE wildcards are literal text, not patterns', () {
      expect(builtInDiveTypeIdsMatching('%'), isEmpty);
      expect(builtInDiveTypeIdsMatching('_'), isEmpty);
    });
  });
}
