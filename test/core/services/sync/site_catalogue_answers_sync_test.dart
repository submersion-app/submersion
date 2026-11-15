import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

import '../../../helpers/test_database.dart';

/// What a diver settled about catalogue records for a site, through the
/// sync serializer itself: an answer given on one device is known on the
/// next, so a declined offer is not made again there.
void main() {
  late SyncDataSerializer serializer;
  late SiteRepository sites;

  const answers = SiteCatalogueAnswers(
    notSame: {'osm_node_3'},
    declined: {
      'osm_node_1': {'depth'},
    },
  );

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    sites = SiteRepository();
  });
  tearDown(tearDownTestDatabase);

  test('a site is written out with its answers', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Salt Pier', catalogueAnswers: answers),
    );

    final record = await serializer.fetchRecord('diveSites', 's1');

    expect(record!['catalogueAnswers'], answers.encode());
  });

  test('a site without answers is written out with none', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'Salt Pier'));

    final record = await serializer.fetchRecord('diveSites', 's1');

    expect(record!.containsKey('catalogueAnswers'), isTrue);
    expect(record['catalogueAnswers'], isNull);
  });

  test('an incoming site keeps the answers it arrives with', () async {
    await serializer.upsertRecord('diveSites', {
      'id': 's1',
      'name': 'Salt Pier',
      'description': '',
      'notes': '',
      'isShared': false,
      'catalogueAnswers': answers.encode(),
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    expect((await sites.getSiteById('s1'))!.catalogueAnswers, answers);
  });

  test("a record round-trips from one device's row to another's", () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        name: 'Salt Pier',
        catalogueId: 'osm_node_1',
        catalogueAnswers: answers,
      ),
    );
    final record = (await serializer.fetchRecord('diveSites', 's1'))!;

    // The other device: an empty database that receives the record.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await SyncDataSerializer().upsertRecord('diveSites', record);

    final arrived = (await SiteRepository().getSiteById('s1'))!;
    expect(arrived.catalogueId, 'osm_node_1');
    expect(arrived.catalogueAnswers, answers);
  });
}
