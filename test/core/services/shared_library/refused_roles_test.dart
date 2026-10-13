import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';
import 'shared_library_service_test.dart' show device, markDirty, seedLibrary;

/// A device that refused the folder's roles (forged, or newer than it can
/// follow) only reads: its uploads would fight the edits of owners it no
/// longer knows (issue #2567).
void main() {
  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
  });

  test('a device that refused the roles uploads nothing', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
    final svc = await device(cloud, 'b');
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    await markDirty('s1');
    expect(
      (await svc.sync('L', diverId: 'd-b')).status,
      SharedLibrarySyncStatus.success,
    );
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final stored = await t.readSite((await t.listSites()).single.id);

    // Roles this device cannot trust: signed by someone it knows as no owner.
    final trusted = (await SharedLibraryStore().getLibrary('L'))!.roles;
    await t.writeRoles(
      await trusted
          .copyWith(version: trusted.version + 2, owners: {'c'})
          .signed(libraryId: 'L', signedBy: 'c', key: await testMemberKey('c')),
    );
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(name: 'Blue Hole'),
      actingDiverId: 'd-b',
    );
    final result = await svc.sync('L', diverId: 'd-b');
    expect(result.status, SharedLibrarySyncStatus.readOnly);
    expect((await SharedLibraryStore().getLibrary('L'))!.rolesRejected, isTrue);
    final after = await t.readSite((await t.listSites()).single.id);
    expect(after.fields['name'], stored.fields['name']);
  });
}
