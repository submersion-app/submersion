import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart';

void main() {
  test('case, accents, punctuation and spacing do not tell names apart', () {
    expect(catalogueNamesEqual('Salt-Pier', 'salt  pier'), isTrue);
    expect(catalogueNamesEqual('Cancún', 'cancun'), isTrue);
    expect(catalogueNamesEqual("  Devil's Throat. ", 'devil s throat'), isTrue);
  });

  test('a different word is a different name', () {
    expect(catalogueNamesEqual('Thistlegorm', 'SS Thistlegorm'), isFalse);
    expect(catalogueNamesEqual('Blue Hole', 'Blue Hole North'), isFalse);
  });

  test('a name with nothing to compare equals nothing', () {
    expect(catalogueNameKey(''), '');
    expect(catalogueNameKey('   '), '');
    expect(catalogueNameKey('?!'), '');
    expect(catalogueNamesEqual('', ''), isFalse);
    expect(catalogueNamesEqual('?!', '...'), isFalse);
    expect(catalogueNamesEqual('', 'Blue Hole'), isFalse);
  });

  test('letters and digits of any script are kept', () {
    expect(catalogueNameKey('Затонувший-корабль 7'), 'затонувший корабль 7');
    expect(catalogueNamesEqual('沉船', '沉船'), isTrue);
    expect(catalogueNamesEqual('沉船', '珊瑚礁'), isFalse);
  });

  test('an accent typed as a separate mark is the same accent', () {
    // "Cancun" with a combining acute after the u, as some files store it.
    final decomposed = 'Cancu${String.fromCharCode(0x301)}n';

    expect(catalogueNameKey(decomposed), 'cancun');
    expect(catalogueNamesEqual(decomposed, 'Cancún'), isTrue);
  });

  test('marks that belong to another script stay in the word', () {
    // Thai vowel and tone marks are combining characters; dropping or
    // splitting on them would make different words alike.
    final kohTao = String.fromCharCodes([
      0x0E40,
      0x0E01,
      0x0E32,
      0x0E30,
      0x0E40,
      0x0E15,
      0x0E48,
      0x0E32,
    ]);
    final other = String.fromCharCodes([
      0x0E40,
      0x0E01,
      0x0E32,
      0x0E30,
      0x0E40,
      0x0E15,
      0x0E49,
      0x0E32,
    ]);

    expect(catalogueNameKey(kohTao), kohTao);
    expect(catalogueNamesEqual(kohTao, kohTao), isTrue);
    expect(catalogueNamesEqual(kohTao, other), isFalse);
  });

  test('the key is the folded name', () {
    expect(catalogueNameKey('  Salt-Pier (South) '), 'salt pier south');
  });
}
