import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show DiveSitesCompanion;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

import '../../../../helpers/test_database.dart';

/// What a diver has settled about catalogue records for a site is stored
/// with the site. Like the link, it is written when the site is made and
/// never by an ordinary edit, whose entity is built fresh from a form.
void main() {
  late SiteRepository sites;

  const answers = SiteCatalogueAnswers(
    also: {'osm_node_2'},
    notSame: {'osm_node_3'},
    declined: {
      'osm_node_1': {'depth'},
    },
  );

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  test('createSite stores the answers and reads them back', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueAnswers: answers),
    );

    expect((await sites.getSiteById('s1'))!.catalogueAnswers, answers);
  });

  test('a site made by hand has no answers', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'My Reef'));

    expect(
      (await sites.getSiteById('s1'))!.catalogueAnswers,
      SiteCatalogueAnswers.empty,
    );
  });

  test('updateSite leaves the answers alone', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueAnswers: answers),
    );

    await sites.updateSite(const DiveSite(id: 's1', name: 'Salt Pier South'));

    final saved = (await sites.getSiteById('s1'))!;
    expect(saved.name, 'Salt Pier South');
    expect(saved.catalogueAnswers, answers);
  });

  test('an import patch that carries answers writes them', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'Salt Pier'));

    await sites.updateSiteWithImportedMetadata(
      const DiveSite(id: 's1', name: 'Salt Pier'),
      DiveSitesCompanion(catalogueAnswers: Value(answers.encode())),
    );

    expect((await sites.getSiteById('s1'))!.catalogueAnswers, answers);
  });

  test('text nobody can read does not stop the site list loading', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'Salt Pier'));
    await sites.updateSiteWithImportedMetadata(
      const DiveSite(id: 's1', name: 'Salt Pier'),
      const DiveSitesCompanion(catalogueAnswers: Value('[1, 2')),
    );

    final all = await sites.getAllSites();
    expect(all.single.catalogueAnswers, SiteCatalogueAnswers.empty);
  });
}
