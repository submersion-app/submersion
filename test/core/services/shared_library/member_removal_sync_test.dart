import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/suggestion_signatures.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/shared_library_test_account.dart';

/// Sync with a member removed from a shared site library (issue #3481).
/// Ann (d1) owns the library; the other profiles share her device unless a
/// test opens a fresh one.
void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryTransport t;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final store = SharedLibraryStore();

  SharedLibraryMembershipService memberships() =>
      SharedLibraryMembershipService(
        accountById: anyTestAccount,
        store: SharedLibraryStore(),
        transportFor: ({required account, required prefix}) async =>
            SharedLibraryTransport(cloud, prefix: prefix),
        recoveryKdf: const KdfParams(m: 1024, t: 1),
      );
  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships().transportForLibrary(l),
  );
  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  Future<SharedLibraryMembership> membershipOf(String diverId) async =>
      (await store.membership(diverId: diverId, libraryId: lib.id))!;

  /// [diverId] joins as [name], is approved and gets [role].
  Future<SharedLibraryMembership> addMember(
    String diverId,
    String name,
    SharedLibraryRole role,
  ) async {
    await diver(diverId);
    await memberships().join(
      account: account,
      prefix: 'site-sync',
      diverId: diverId,
      displayName: name,
    );
    final ann = await membershipOf('d1');
    final m = await membershipOf(diverId);
    await memberships().approveMember(
      libraryId: lib.id,
      memberId: m.memberId,
      actingMemberId: ann.memberId,
      publicKey: m.signingKey!.publicKey,
    );
    if (role != SharedLibraryRole.reader) {
      await memberships().setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: m.memberId,
        role: role,
      );
    }
    return m;
  }

  Future<void> remove(SharedLibraryMembership m) async =>
      memberships().removeMember(
        libraryId: lib.id,
        memberId: m.memberId,
        actingMemberId: (await membershipOf('d1')).memberId,
      );

  Future<void> addSite(String id, String name) async {
    await SiteRepository().createSite(
      DiveSite(id: id, name: name, sharedLibraryId: lib.id),
    );
    await store.putSiteState(
      SharedSiteState(siteId: id, libraryId: lib.id, dirty: true),
    );
  }

  Future<String?> remoteName(String siteId) async {
    for (final f in await t.listSites()) {
      if (SharedLibraryTransport.siteIdOf(f) == siteId) {
        return (await t.readSite(f.id)).fields['name'] as String?;
      }
    }
    return null;
  }

  Future<Set<String>> cardIds() async => {
    for (final m in await t.listMembers()) m.memberId,
  };

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    lib = await memberships().create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  test("a removed editor's earlier edits survive on a fresh device", () async {
    await addMember('d2', 'Bo', SharedLibraryRole.editor);
    await addSite('s1', 'Blue Hole');
    await syncer().sync(lib.id, diverId: 'd2');
    expect(await remoteName('s1'), 'Blue Hole');
    await remove(await membershipOf('d2'));

    // Someone who joins afterwards, on a device of their own.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await diver('d9');
    await memberships().join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd9',
      displayName: 'Cy',
    );
    await syncer().sync(lib.id, diverId: 'd9');
    expect((await SiteRepository().getSiteById('s1'))?.name, 'Blue Hole');
  });

  test(
    'a removal outweighs an editing approval the roles still hold',
    () async {
      final bo = await addMember('d2', 'Bo', SharedLibraryRole.editor);
      await addSite('s1', 'Blue Hole');
      await syncer().sync(lib.id, diverId: 'd2');
      await remove(bo);
      // An older owner app approves Bo again and makes him an editor, and
      // Bo's older app uploads an edit made after the removal.
      final ann = (await membershipOf('d1')).memberId;
      await t.writeMember(
        await SharedLibraryMember.signed(
          memberId: bo.memberId,
          displayName: 'Bo',
          joinedAt: DateTime.utc(2026, 10),
          key: bo.signingKey!,
        ),
        appVersion: '1.8.2',
      );
      await memberships().approveMember(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: ann,
        publicKey: bo.signingKey!.publicKey,
      );
      await memberships().setRole(
        libraryId: lib.id,
        actingMemberId: ann,
        memberId: bo.memberId,
        role: SharedLibraryRole.editor,
      );
      final file = (await t.listSites()).single;
      final doc = await t.readSite(file.id);
      final later = DateTime.now().add(const Duration(hours: 1));
      await t.writeSite(
        await signOwnFields(
          doc.copyWith(
            fields: {...doc.fields, 'name': 'Renamed later'},
            clocks: {
              ...doc.clocks,
              'name': FieldClock(
                hlc: Hlc(later.millisecondsSinceEpoch, 0, bo.memberId),
                memberId: bo.memberId,
              ),
            },
          ),
          libraryId: lib.id,
          memberId: bo.memberId,
          key: bo.signingKey!,
        ),
      );

      // An owner's device keeps its value and does not take the later edit.
      await syncer().sync(lib.id, diverId: 'd1');
      expect((await SiteRepository().getSiteById('s1'))?.name, 'Blue Hole');
    },
  );

  test('the removed device stops writing and keeps its card away', () async {
    final bo = await addMember('d2', 'Bo', SharedLibraryRole.editor);
    await addSite('s1', 'Blue Hole');
    await syncer().sync(lib.id, diverId: 'd2');
    await remove(bo);

    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(name: 'Renamed'),
      actingDiverId: 'd2',
    );
    await store.putSiteState(
      SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
    );
    final result = await syncer().sync(lib.id, diverId: 'd2');
    expect(result.status, SharedLibrarySyncStatus.readOnly);
    expect(await remoteName('s1'), 'Blue Hole');
    expect(await cardIds(), isNot(contains(bo.memberId)));
    expect((await store.removals(lib.id)).single.memberId, bo.memberId);
  });

  test('a record no owner signed changes nothing', () async {
    final bo = await addMember('d2', 'Bo', SharedLibraryRole.reader);
    final ed = await addMember('d3', 'Ed', SharedLibraryRole.editor);
    await t.writeRemoval(
      await MemberRemoval.signed(
        libraryId: lib.id,
        memberId: bo.memberId,
        displayName: 'Bo',
        removedAt: DateTime.now(),
        removedBy: ed.memberId,
        key: ed.signingKey!,
      ),
    );
    await t.deleteMember(bo.memberId);
    await syncer().sync(lib.id, diverId: 'd1');
    expect(await store.removals(lib.id), isEmpty);
    final result = await syncer().sync(lib.id, diverId: 'd2');
    expect(result.status, SharedLibrarySyncStatus.success);
    expect(await cardIds(), contains(bo.memberId));
  });

  test('allow back brings them back as pending', () async {
    final bo = await addMember('d2', 'Bo', SharedLibraryRole.editor);
    await remove(bo);
    await memberships().allowBack(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: (await membershipOf('d1')).memberId,
    );
    await syncer().sync(lib.id, diverId: 'd2');
    expect(await cardIds(), contains(bo.memberId));
    expect((await t.readRoles()).approvedKeys, isNot(contains(bo.memberId)));
    expect(await store.removals(lib.id), isEmpty);
  });

  group('undecided suggestions', () {
    Future<void> suggest(
      SharedLibraryMembership by,
      String id,
      DateTime createdAt,
    ) async => t.writeSuggestion(
      id,
      await signSuggestion(
        SharedSiteSuggestion(
          id: id,
          libraryId: lib.id,
          siteId: 's1',
          memberId: by.memberId,
          memberName: by.displayName,
          fields: const {'hazards': 'surge'},
          createdAt: createdAt,
          direction: SharedSiteSuggestion.outgoing,
        ).toJson(),
        by.signingKey!,
        libraryId: lib.id,
      ),
    );

    Future<Map<String, String>> inbox() async => {
      for (final s in await store.suggestions(
        lib.id,
        direction: SharedSiteSuggestion.incoming,
      ))
        s.fileId: s.status,
    };

    test('one from before the removal stays for the owners', () async {
      final bo = await addMember('d2', 'Bo', SharedLibraryRole.reader);
      await suggest(
        bo,
        'sg1',
        DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      await remove(bo);
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await inbox(), {'sg1': SharedSiteSuggestion.pending});
    });

    /// What a removed device on v1.8.2 does: writes its card again.
    Future<void> cardBack(SharedLibraryMembership m) async => t.writeMember(
      await SharedLibraryMember.signed(
        memberId: m.memberId,
        displayName: m.displayName,
        joinedAt: DateTime.utc(2026, 10),
        key: m.signingKey!,
      ),
      appVersion: '1.8.2',
    );

    test('with their card back, earlier ones are pending, later ones '
        'are not held', () async {
      final bo = await addMember('d2', 'Bo', SharedLibraryRole.reader);
      await suggest(
        bo,
        'sg1',
        DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      await remove(bo);
      await cardBack(bo);
      await suggest(
        bo,
        'sg2',
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await inbox(), {'sg1': SharedSiteSuggestion.pending});
    });

    test('a removal outweighs an approval the roles still hold', () async {
      final bo = await addMember('d2', 'Bo', SharedLibraryRole.reader);
      await suggest(
        bo,
        'sg1',
        DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      await remove(bo);
      // An older owner app approves the card Bo's older app wrote again.
      await cardBack(bo);
      await memberships().approveMember(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: (await membershipOf('d1')).memberId,
        publicKey: bo.signingKey!.publicKey,
      );
      await suggest(
        bo,
        'sg2',
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await inbox(), {'sg1': SharedSiteSuggestion.pending});
    });

    test('one dated after the removal is not taken in', () async {
      final bo = await addMember('d2', 'Bo', SharedLibraryRole.reader);
      await remove(bo);
      await suggest(
        bo,
        'sg2',
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await inbox(), isEmpty);
    });
  });
}
