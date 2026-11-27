import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/latin_fold.dart';

void main() {
  test('lower-cases and drops Latin diacritics', () {
    expect(foldLatinForSearch('Złoty'), 'zloty');
    expect(
      foldLatinForSearch('São Tomé and Príncipe'),
      'sao tome and principe',
    );
    expect(foldLatinForSearch('Vietnamese đồng'), 'vietnamese dong');
    expect(foldLatinForSearch('Mongolian tögrög'), 'mongolian togrog');
  });

  test("drops the ʻokina and apostrophes", () {
    expect(foldLatinForSearch('Tongan paʻanga'), 'tongan paanga');
    expect(foldLatinForSearch("pa'anga"), 'paanga');
  });

  test('leaves other scripts alone', () {
    expect(foldLatinForSearch('円'), '円');
    expect(foldLatinForSearch('Франк'), 'франк');
  });
}
