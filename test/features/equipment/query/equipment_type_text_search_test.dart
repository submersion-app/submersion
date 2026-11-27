import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/query/equipment_type_text_search.dart';

/// A plain word finds equipment by its type (issue #5106): any type's name in
/// any app language, and for cylinders also the other words divers use.
void main() {
  group('equipmentTypeNamesMatching', () {
    test('the cylinder label finds cylinders, ignoring case', () {
      expect(equipmentTypeNamesMatching('cylinder'), contains('tank'));
      expect(equipmentTypeNamesMatching('Cylinder'), contains('tank'));
    });

    test('the other English words for a cylinder find cylinders', () {
      for (final word in ['tank', 'bottle', 'stage', 'pony']) {
        expect(
          equipmentTypeNamesMatching(word),
          contains('tank'),
          reason: word,
        );
      }
    });

    test('a translated cylinder word finds cylinders', () {
      expect(equipmentTypeNamesMatching('Flasche'), contains('tank'));
      expect(equipmentTypeNamesMatching('FLASCHE'), contains('tank'));
      expect(equipmentTypeNamesMatching('botella'), contains('tank'));
      expect(equipmentTypeNamesMatching('bloc'), contains('tank'));
      // A dropped word stays a search word (issue #5106).
      expect(equipmentTypeNamesMatching('bouteille'), contains('tank'));
    });

    test('any type is found by its name', () {
      expect(equipmentTypeNamesMatching('regulator'), contains('regulator'));
      expect(equipmentTypeNamesMatching('bcd'), contains('bcd'));
    });

    test('a cylinder band answers to its other names', () {
      expect(equipmentTypeNamesMatching('cam band'), contains('tankBand'));
      expect(equipmentTypeNamesMatching('tank band'), contains('tankBand'));
    });

    test('ignores accents and surrounding whitespace', () {
      expect(
        equipmentTypeNamesMatching('  REGULATOR  '),
        contains('regulator'),
      );
    });

    test('a blank or unknown term matches nothing', () {
      expect(equipmentTypeNamesMatching(''), isEmpty);
      expect(equipmentTypeNamesMatching('   '), isEmpty);
      expect(equipmentTypeNamesMatching('zzznope'), isEmpty);
    });

    test('LIKE wildcards are literal text, not patterns', () {
      expect(equipmentTypeNamesMatching('%'), isEmpty);
      expect(equipmentTypeNamesMatching('_'), isEmpty);
    });
  });
}
