import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// An owner profile and a reader profile on one device (issue #2567).
void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService memberships;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  Future<void> addDiver(String id, String name) =>
      DiverRepository().createDiver(
        Diver(
          id: id,
          name: name,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

  Future<String> memberOf(String diverId) async =>
      (await SharedLibraryStore().membership(
        diverId: diverId,
        libraryId: lib.id,
      ))!.memberId;

  Future<List<SharedSiteSuggestion>> inbox() =>
      SharedLibraryStore().suggestions(
        lib.id,
        direction: SharedSiteSuggestion.incoming,
        status: SharedSiteSuggestion.pending,
      );

  setUp(() async {
    await setUpTestDatabase();
    await addDiver('owner', 'Ann');
    await addDiver('reader', 'Bo');
    cloud = FakeCloudStorageProvider();
    memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: const KdfParams(m: 1024, t: 1),
    );
    lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'owner',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Blue', hazards: 'old', sharedLibraryId: lib.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
    );
    await syncer().sync(lib.id, diverId: 'owner');
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'reader',
      displayName: 'Bo',
    );
    await memberships.approveMember(
      libraryId: lib.id,
      memberId: await memberOf('reader'),
      actingMemberId: await memberOf('owner'),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  Future<void> suggestAsReader() async {
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SuggestionService(
      transportFor: (l) => memberships.transportForLibrary(l),
    ).propose(
      proposed: site.copyWith(hazards: 'new'),
      diverId: 'reader',
    );
  }

  test('the reader syncs, then the owner sees the suggestion', () async {
    await suggestAsReader();
    await syncer().sync(lib.id, diverId: 'reader');
    await syncer().sync(lib.id, diverId: 'owner');
    final got = await inbox();
    expect(got, hasLength(1));
    expect(got.single.fields, {'hazards': 'new'});
  });

  test('the owner syncs first and still sees the suggestion', () async {
    await suggestAsReader();
    // Switched to the owner before the reader's sync ran.
    await syncer().sync(lib.id, diverId: 'owner');
    final got = await inbox();
    expect(got, hasLength(1));
    expect(got.single.memberId, await memberOf('reader'));
  });

  test("the owner's copy leaves the reader's own entry in place", () async {
    await suggestAsReader();
    await syncer().sync(lib.id, diverId: 'reader');
    await syncer().sync(lib.id, diverId: 'owner');
    final mine = await SharedLibraryStore().suggestions(
      lib.id,
      direction: SharedSiteSuggestion.outgoing,
    );
    expect(mine, hasLength(1));
    expect(mine.single.status, SharedSiteSuggestion.uploaded);
    expect(await inbox(), hasLength(1));

    // Another owner sync neither duplicates nor drops either copy.
    await syncer().sync(lib.id, diverId: 'owner');
    expect(await inbox(), hasLength(1));

    // Accepting removes the folder's file and the owner's copy only.
    await SuggestionService(
      transportFor: (l) => memberships.transportForLibrary(l),
    ).accept((await inbox()).single.id, diverId: 'owner');
    expect(await inbox(), isEmpty);
    expect(
      await SharedLibraryTransport(
        cloud,
        prefix: 'site-sync',
      ).listSuggestions(),
      isEmpty,
    );
    expect((await SiteRepository().getSiteById('s1'))!.hazards, 'new');
  });

  test(
    'a suggestion by a member not yet approved is held, then counts',
    () async {
      await addDiver('late', 'Cy');
      await memberships.join(
        account: account,
        prefix: 'site-sync',
        diverId: 'late',
        displayName: 'Cy',
      );
      final site = (await SiteRepository().getSiteById('s1'))!;
      await SuggestionService(
        transportFor: (l) => memberships.transportForLibrary(l),
      ).propose(
        proposed: site.copyWith(hazards: 'late'),
        diverId: 'late',
      );
      await syncer().sync(lib.id, diverId: 'late');
      await syncer().sync(lib.id, diverId: 'owner');

      Future<List<SharedSiteSuggestion>> held() =>
          SharedLibraryStore().suggestions(
            lib.id,
            direction: SharedSiteSuggestion.incoming,
            status: SharedSiteSuggestion.held,
          );
      expect(await inbox(), isEmpty);
      expect(await held(), hasLength(1));

      await memberships.approveMember(
        libraryId: lib.id,
        memberId: await memberOf('late'),
        actingMemberId: await memberOf('owner'),
      );
      await syncer().sync(lib.id, diverId: 'owner');
      expect(await held(), isEmpty);
      expect((await inbox()).single.fields, {'hazards': 'late'});
    },
  );
}
