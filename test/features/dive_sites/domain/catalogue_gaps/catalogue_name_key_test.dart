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

  test('the key is the folded name', () {
    expect(catalogueNameKey('  Salt-Pier (South) '), 'salt pier south');
  });
}
