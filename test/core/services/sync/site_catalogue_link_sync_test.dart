import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/test_database.dart';

/// A site's link to the built-in catalogue record it was adopted from,
/// through the sync serializer itself: what one device writes out is what
/// another reads in, so the site stays linked (and its catalogue twin
/// stays hidden) on every device.
void main() {
  late SyncDataSerializer serializer;
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    sites = SiteRepository();
  });
  tearDown(tearDownTestDatabase);

  test('a linked site is written out with its link', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'osm_node_1'),
    );

    final record = await serializer.fetchRecord('diveSites', 's1');

    expect(record, isNotNull);
    expect(record!['catalogueId'], 'osm_node_1');
  });

  test('an incoming site keeps the link it arrives with', () async {
    await serializer.upsertRecord('diveSites', {
      'id': 's1',
      'name': 'Salt Pier',
      'description': '',
      'notes': '',
      'isShared': false,
      'catalogueId': 'osm_node_1',
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final site = (await sites.getSiteById('s1'))!;
    expect(site.catalogueId, 'osm_node_1');
    expect((await sites.getSiteByCatalogueId('osm_node_1'))!.id, 's1');
  });

  test("a record round-trips from one device's row to another's", () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        name: 'Salt Pier',
        location: GeoPoint(12.08, -68.28),
        catalogueId: 'osm_node_1',
      ),
    );
    final record = (await serializer.fetchRecord('diveSites', 's1'))!;

    // The other device: an empty database that receives the record.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await SyncDataSerializer().upsertRecord('diveSites', record);

    final arrived = (await SiteRepository().getSiteById('s1'))!;
    expect(arrived.catalogueId, 'osm_node_1');
    expect(arrived.location, const GeoPoint(12.08, -68.28));
  });
}
