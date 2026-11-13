import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// A site adopted from the built-in catalogue remembers which record it
/// came from. The link is written when the site is made and when a merge
/// rewrites it, and an ordinary edit never touches it.
void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  test('createSite stores the link and reads it back', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_1'),
    );

    expect((await sites.getSiteById('s1'))!.catalogueId, 'osm_node_1');
  });

  test('a site made by hand has no link', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'My Reef'));

    expect((await sites.getSiteById('s1'))!.catalogueId, isNull);
  });

  test('updateSite leaves the link alone', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_1'),
    );

    // What the site edit page saves: an entity built fresh from its form,
    // which knows nothing of the link.
    await sites.updateSite(const DiveSite(id: 's1', name: 'Salt Pier South'));

    final saved = (await sites.getSiteById('s1'))!;
    expect(saved.name, 'Salt Pier South');
    expect(saved.catalogueId, 'osm_node_1');
  });

  test('updateSite cannot move a link to another record', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_1'),
    );

    await sites.updateSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_2'),
    );

    expect((await sites.getSiteById('s1'))!.catalogueId, 'osm_node_1');
  });

  group('getSiteByCatalogueId', () {
    test('finds the site with no diver when none is given', () async {
      await sites.createSite(
        const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_1'),
      );

      expect((await sites.getSiteByCatalogueId('osm_node_1'))!.id, 's1');
      expect(await sites.getSiteByCatalogueId('osm_node_2'), isNull);
    });

    test('returns the oldest when a diver has two', () async {
      await sites.createSite(
        const DiveSite(id: 'older', name: 'A', catalogueId: 'osm_node_1'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await sites.createSite(
        const DiveSite(id: 'newer', name: 'B', catalogueId: 'osm_node_1'),
      );

      expect((await sites.getSiteByCatalogueId('osm_node_1'))!.id, 'older');
    });
  });

  group('merging', () {
    Future<void> seed({String? survivorLink, String? otherLink}) async {
      await sites.createSite(
        DiveSite(id: 'survivor', name: 'Reef', catalogueId: survivorLink),
      );
      await sites.createSite(
        DiveSite(id: 'other', name: 'Reef 2', catalogueId: otherLink),
      );
    }

    // The merge page hands over a site built from its form: no link.
    const merged = DiveSite(id: 'survivor', name: 'Reef (merged)');

    test('keeps the survivor\'s link', () async {
      await seed(survivorLink: 'a', otherLink: 'b');

      await sites.mergeSites(
        mergedSite: merged,
        siteIds: ['survivor', 'other'],
      );

      final site = (await sites.getSiteById('survivor'))!;
      expect(site.name, 'Reef (merged)');
      expect(site.catalogueId, 'a');
    });

    test('takes the other site\'s link when the survivor has none', () async {
      await seed(otherLink: 'b');

      await sites.mergeSites(
        mergedSite: merged,
        siteIds: ['survivor', 'other'],
      );

      expect((await sites.getSiteById('survivor'))!.catalogueId, 'b');
    });

    test('leaves the survivor unlinked when neither has a link', () async {
      await seed();

      await sites.mergeSites(
        mergedSite: merged,
        siteIds: ['survivor', 'other'],
      );

      expect((await sites.getSiteById('survivor'))!.catalogueId, isNull);
    });

    test('undoing a merge restores each site\'s link', () async {
      await seed(otherLink: 'b');
      final snapshot = await sites.mergeSites(
        mergedSite: merged,
        siteIds: ['survivor', 'other'],
      );

      await sites.undoMerge(snapshot!);

      expect((await sites.getSiteById('survivor'))!.catalogueId, isNull);
      expect((await sites.getSiteById('other'))!.catalogueId, 'b');
    });
  });
}
