import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

DiveSite _site(String id, {String? link, Set<String> also = const {}}) =>
    DiveSite(
      id: id,
      name: id,
      catalogueId: link,
      catalogueAnswers: SiteCatalogueAnswers(also: also),
    );

void main() {
  group('catalogueOwnerSiteId', () {
    test('the site adopted from the record', () {
      expect(
        catalogueOwnerSiteId([
          _site('other', link: 'elsewhere'),
          _site('mine', link: 'here'),
        ], 'here'),
        'mine',
      );
    });

    test('failing that, the site a merge folded it into', () {
      expect(
        catalogueOwnerSiteId([
          _site('survivor', link: 'elsewhere', also: {'here'}),
        ], 'here'),
        'survivor',
      );
    });

    test('the adopted site wins over a merged one, whatever their order', () {
      expect(
        catalogueOwnerSiteId([
          _site('survivor', link: 'elsewhere', also: {'here'}),
          _site('adopted', link: 'here'),
        ], 'here'),
        'adopted',
      );
    });

    test('null when no site of the diver\'s claims the record', () {
      expect(catalogueOwnerSiteId([_site('a', link: 'x')], 'here'), isNull);
      expect(catalogueOwnerSiteId(const [], 'here'), isNull);
    });
  });
}
