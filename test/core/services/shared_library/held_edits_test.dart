import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';
import 'shared_library_service_test.dart' show device, markDirty, seedLibrary;

/// Edits held for an owner's approval, and fields a member could not
/// verify, are never lost on the way (issue #2567).
void main() {
  late Directory dir;
  late File aFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('held_edits_');
    aFile = File(p.join(dir.path, 'a.sqlite'));
  });

  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
    dir.deleteSync(recursive: true);
  });

  SharedLibraryMembershipService memberships(FakeCloudStorageProvider cloud) =>
      SharedLibraryMembershipService(
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) async =>
            SharedLibraryTransport(cloud, prefix: prefix),
        accountById: (id) async => ConnectedAccount(
          id: id,
          kind: AccountKind.s3,
          label: '',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  /// Owner a holds s1 'Blue'; editor p, not yet approved, renames it to
  /// 'Blue Hole'. Leaves a's database open.
  Future<FakeCloudStorageProvider> heldRename() async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a'}, editors: {'p'}, approved: {'a'});
    var svc = await device(cloud, 'a', file: aFile);
    await SiteRepository().createSite(
      const DiveSite(
        id: 's1',
        name: 'Blue',
        maxDepth: 10,
        sharedLibraryId: 'L',
      ),
    );
    await markDirty('s1');
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    svc = await device(cloud, 'p');
    await svc.sync('L', diverId: 'd-p');
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(name: 'Blue Hole'),
      actingDiverId: 'd-p',
    );
    await svc.sync('L', diverId: 'd-p');
    await tearDownTestDatabase();

    svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue');
    return cloud;
  }

  test('an owner approving here sees the held edit on the next sync', () async {
    final cloud = await heldRename();
    await memberships(cloud).approveMember(
      libraryId: 'L',
      memberId: 'p',
      actingMemberId: 'a',
      publicKey: (await testMemberKey('p')).publicKey,
    );
    final svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue Hole');
  });

  test(
    "an owner's upload that carried a held edit still applies it later",
    () async {
      final cloud = await heldRename();
      var svc = await device(cloud, 'a', file: aFile);
      // The owner edits another field: the upload carries p's rename.
      final site = (await SiteRepository().getSiteById('s1'))!;
      await SiteRepository().updateSite(
        site.copyWith(maxDepth: 12),
        actingDiverId: 'd-a',
      );
      await svc.sync('L', diverId: 'd-a');
      await memberships(cloud).approveMember(
        libraryId: 'L',
        memberId: 'p',
        actingMemberId: 'a',
        publicKey: (await testMemberKey('p')).publicKey,
      );
      svc = await device(cloud, 'a', file: aFile);
      await svc.sync('L', diverId: 'd-a');
      expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue Hole');
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      final stored = await t.readSite((await t.listSites()).single.id);
      expect(stored.fields['name'], 'Blue Hole');
      expect(stored.fields['maxDepth'], 12);
    },
  );

  test('a field a member could not verify is never wiped by them', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
    var svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    // Added as the app adds a site: every field clocked.
    await SiteRepository().createSite(
      const DiveSite(
        id: 's1',
        name: 'Blue',
        description: 'Deep wall',
        diverId: 'd-a',
      ),
    );
    await SharedSitePublisher().push(
      siteId: 's1',
      libraryId: 'L',
      diverId: 'd-a',
    );
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    // The stored description no longer matches its signature (spelled
    // differently by a device that re-rendered it).
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final file = (await t.listSites()).single;
    final doc = await t.readSite(file.id);
    await t.writeRaw(
      'sites/${file.name.split('/').last}',
      SiteDocument.encode(
        doc.copyWith(fields: {...doc.fields, 'description': 'deep wall'}),
      ),
    );

    // Editor b joins, cannot verify the description, and edits the name.
    svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(name: 'Blue Wall'),
      actingDiverId: 'd-b',
    );
    await svc.sync('L', diverId: 'd-b');
    await tearDownTestDatabase();

    svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    final back = (await SiteRepository().getSiteById('s1'))!;
    expect(back.name, 'Blue Wall');
    expect(back.description, 'Deep wall');
  });
}
