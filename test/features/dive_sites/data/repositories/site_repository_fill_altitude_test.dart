import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// A write refused underneath, as for a shared library site this profile
/// may not edit: `updateSiteAltitude` returns without storing anything.
class _Refusing extends SiteRepository {
  @override
  Future<void> updateSiteAltitude(String siteId, double altitudeMeters) async {}
}

/// A looked-up altitude for a site is stored only while the site has none
/// (issue #4527): one the site gained since the lookup is newer and kept.
void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  test('a site with no altitude takes the looked-up one', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'Lake'));

    final wrote = await sites.fillSiteAltitudeIfEmpty('s1', 434);

    expect(wrote, isTrue);
    expect((await sites.getSiteById('s1'))!.altitude, 434);
  });

  test('a site with an altitude keeps it', () async {
    await sites.createSite(
      const DiveSite(id: 's1', name: 'Lake', altitude: 512),
    );

    final wrote = await sites.fillSiteAltitudeIfEmpty('s1', 434);

    expect(wrote, isFalse);
    expect((await sites.getSiteById('s1'))!.altitude, 512);
  });

  test('a site that is gone writes nothing', () async {
    expect(await sites.fillSiteAltitudeIfEmpty('missing', 434), isFalse);
  });

  test('a write refused underneath reports that nothing was stored', () async {
    await sites.createSite(const DiveSite(id: 's1', name: 'Lake'));

    final wrote = await _Refusing().fillSiteAltitudeIfEmpty('s1', 434);

    expect(wrote, isFalse);
    expect((await sites.getSiteById('s1'))!.altitude, isNull);
  });
}
