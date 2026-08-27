import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/ocr_import/domain/services/site_resolver.dart';

DiveSite site(String id, String name) => DiveSite(id: id, name: name);

void main() {
  final sites = [
    site('1', 'Blue Corner'),
    site('2', 'Pinnacle, Sodwana Bay'),
    site('3', 'Molokini Crater'),
  ];

  test('exact name matches', () {
    expect(resolveSiteByName('Blue Corner', sites)?.id, '1');
  });

  test('OCR noise still matches above threshold', () {
    expect(resolveSiteByName('Pinnacle Sodwana Bay', sites)?.id, '2');
  });

  test('unrelated name returns null', () {
    expect(resolveSiteByName("O'ahu - pipe", sites), isNull);
  });

  test('empty input returns null', () {
    expect(resolveSiteByName('', sites), isNull);
    expect(resolveSiteByName('Blue Corner', const []), isNull);
  });
}
