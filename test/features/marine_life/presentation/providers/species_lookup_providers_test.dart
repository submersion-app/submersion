import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';

void main() {
  test('a language tag becomes its lowercase language code', () {
    expect(lookupLocaleCode('de'), 'de');
    expect(lookupLocaleCode('pt-BR'), 'pt');
    expect(lookupLocaleCode('zh_Hans'), 'zh');
    expect(lookupLocaleCode('EN'), 'en');
  });

  test('system resolves through the platform language', () {
    expect(lookupLocaleCode('system', systemLanguageCode: () => 'fr'), 'fr');
  });
}
