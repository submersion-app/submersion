import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService service;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Club bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    await _diver('d1');
    cloud = FakeCloudStorageProvider();
    service = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    );
  });

  tearDown(tearDownTestDatabase);

  test('probe, create, then a second profile joins', () async {
    expect(
      (await service.probe(account: account, prefix: 'club')).exists,
      isFalse,
    );
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.readManifest())!['name'], 'Club');
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect((await t.readRoles()).roleOf(me.memberId), SharedLibraryRole.owner);
    expect((await t.listMembers()).single.displayName, 'Ann');
    expect(me.locationHint, 'Club bucket: club');
    expect(me.backendKind, 's3');
    final probe = await service.probe(account: account, prefix: 'club');
    expect(probe.exists, isTrue);
    expect(probe.name, 'Club');
    expect(probe.id, lib.id);

    await _diver('d2');
    final joined = await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    expect(joined.id, lib.id);
    expect(await t.listMembers(), hasLength(2));
    expect(await SharedLibraryStore().getLibraries(), hasLength(1));
    expect(
      await SharedLibraryStore().membershipsForLibrary(lib.id),
      hasLength(2),
    );
  });

  test('join refuses a prefix with no library or a newer format', () async {
    expect(
      () => service.join(
        account: account,
        prefix: 'empty',
        diverId: 'd1',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
    await SharedLibraryTransport(
      cloud,
      prefix: 'new',
    ).writeManifest({'id': 'N', 'name': 'New', 'formatVersion': 99});
    expect(
      (await service.probe(account: account, prefix: 'new')).needsNewerApp,
      isTrue,
    );
    expect(
      () => service.join(
        account: account,
        prefix: 'new',
        diverId: 'd1',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
  });

  test('setRole rewrites roles and refuses to demote the last owner', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: me.memberId,
      memberId: 'other',
      role: SharedLibraryRole.editor,
    );
    expect(
      () => service.setRole(
        libraryId: lib.id,
        actingMemberId: 'other',
        memberId: me.memberId,
        role: SharedLibraryRole.reader,
      ),
      throwsStateError,
      reason: 'an editor may not change roles',
    );
    final roles = await SharedLibraryTransport(
      cloud,
      prefix: 'club',
    ).readRoles();
    expect(roles.roleOf('other'), SharedLibraryRole.editor);
    expect(
      (await SharedLibraryStore().getLibrary(lib.id))!.roles.roleOf('other'),
      SharedLibraryRole.editor,
    );
    expect(
      () => service.setRole(
        libraryId: lib.id,
        actingMemberId: me.memberId,
        memberId: me.memberId,
        role: SharedLibraryRole.editor,
      ),
      throwsStateError,
    );
  });

  test('rename updates the card, the membership and the cache', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await service.rename(
      libraryId: lib.id,
      diverId: 'd1',
      displayName: 'Annie',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.listMembers()).single.displayName, 'Annie');
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect(me.displayName, 'Annie');
    expect((await SharedLibraryStore().memberNames(lib.id)).values, ['Annie']);
  });

  test(
    'leave removes the membership, the sites and the unused library',
    () async {
      final lib = await service.create(
        account: account,
        prefix: 'club',
        name: 'Club',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await SiteRepository().createSite(
        DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id),
      );
      await SharedLibraryStore().putSiteState(
        SharedSiteState(siteId: 'lib', libraryId: lib.id),
      );
      await service.leave(libraryId: lib.id, diverId: 'd1');
      expect(
        await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id),
        isNull,
      );
      expect(await SharedLibraryStore().getLibrary(lib.id), isNull);
      expect(await SiteRepository().getSiteById('lib'), isNull);
      expect(
        await SharedLibraryTransport(cloud, prefix: 'club').listMembers(),
        isEmpty,
      );
    },
  );

  test('leave keeps the library while another profile is a member', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    await SiteRepository().createSite(
      DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id),
    );
    await service.leave(libraryId: lib.id, diverId: 'd1');
    expect(await SharedLibraryStore().getLibrary(lib.id), isNotNull);
    expect(
      await SharedLibraryStore().membershipsForLibrary(lib.id),
      hasLength(1),
    );
    expect(
      (await SiteRepository().getSiteById('lib'))?.sharedLibraryId,
      lib.id,
      reason: 'the remaining profile keeps the club sites',
    );
  });
}
