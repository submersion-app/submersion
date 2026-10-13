import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_site_notes.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// A profile's private notes and rating on library sites reach its other
/// devices through personal sync (issue #2567).
void main() {
  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  Future<void> member(String diverId, {bool editor = false}) async {
    final store = SharedLibraryStore();
    await store.upsertLibrary(
      SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(editors: editor ? const {'m'} : const {}),
      ),
    );
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms',
        diverId: diverId,
        libraryId: 'L',
        memberId: 'm',
        displayName: diverId,
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
  }

  tearDown(SyncCoordinator.reset);

  group('on one device', () {
    setUp(() async {
      await setUpTestDatabase();
      await diver('d1');
    });

    tearDown(tearDownTestDatabase);

    test('notes on a library site are kept for the profile, to sync', () async {
      await member('d1');
      await SiteRepository().createSite(
        const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'),
      );
      final site = (await SiteRepository().getSiteById('s'))!;
      await SiteRepository().updateSite(
        site.copyWith(notes: 'strong surge at the corner', rating: 4),
        actingDiverId: 'd1',
      );
      final kept = (await SharedLibraryStore().siteNotes(
        diverId: 'd1',
        siteId: 's',
      ))!;
      expect(kept.notes, 'strong surge at the corner');
      expect(kept.rating, 4);
      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.where(
          (r) =>
              r.entityType == SharedLibraryStore.siteNotesEntity &&
              r.recordId == 'd1:s',
        ),
        hasLength(1),
      );
      // Never a library edit.
      expect(
        (await SharedLibraryStore().getSiteState('s'))?.dirty,
        isNot(true),
      );
    });

    test(
      'the newest notes reach the library site, never a personal one',
      () async {
        await member('d1');
        await SiteRepository().createSite(
          const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'),
        );
        await SiteRepository().createSite(
          const DiveSite(id: 'p', name: 'Mine', diverId: 'd1', notes: 'own'),
        );
        // As personal sync brings them from the profile's other device.
        await SharedLibraryStore().putSiteNotes(
          diverId: 'd1',
          siteId: 's',
          notes: 'from the tablet',
          rating: 5,
        );
        await SharedLibraryStore().putSiteNotes(
          diverId: 'd1',
          siteId: 'p',
          notes: 'not for a personal site',
          rating: null,
        );
        await applyLibrarySiteNotes(DatabaseService.instance.database);
        final s = (await SiteRepository().getSiteById('s'))!;
        expect(s.notes, 'from the tablet');
        expect(s.rating, 5);
        expect((await SiteRepository().getSiteById('p'))!.notes, 'own');
        expect(
          (await SharedLibraryStore().getSiteState('s'))?.dirty,
          isNot(true),
        );
      },
    );

    test("another profile's notes on a row are never taken up", () async {
      await member('d1');
      await diver('d2');
      await SharedLibraryStore().upsertMembership(
        const SharedLibraryMembership(
          id: 'ms2',
          diverId: 'd2',
          libraryId: 'L',
          memberId: 'm2',
          displayName: 'd2',
          libraryName: 'Reef Survey',
          backendKind: 's3',
        ),
      );
      await SiteRepository().createSite(
        const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'),
      );
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'd1 only',
        rating: null,
      );
      await applyLibrarySiteNotes(DatabaseService.instance.database);
      await SharedLibraryStore().backfillSiteNotes(
        libraryId: 'L',
        diverId: 'd2',
      );
      expect(
        await SharedLibraryStore().siteNotes(diverId: 'd2', siteId: 's'),
        isNull,
      );
    });

    test('notes are taken up once, never from a row adopted later', () async {
      await member('d1');
      await SharedLibraryStore().backfillSiteNotes(
        libraryId: 'L',
        diverId: 'd1',
      );
      // A pull adopts a stale personal copy that still holds old notes.
      await SiteRepository().createSite(
        const DiveSite(
          id: 's',
          name: 'Blue',
          notes: 'stale',
          sharedLibraryId: 'L',
        ),
      );
      await SharedLibraryStore().backfillSiteNotes(
        libraryId: 'L',
        diverId: 'd1',
      );
      expect(
        await SharedLibraryStore().siteNotes(diverId: 'd1', siteId: 's'),
        isNull,
      );
    });

    test('a site added to a library keeps its notes for the profile', () async {
      await member('d1', editor: true);
      await SiteRepository().createSite(
        const DiveSite(
          id: 'p',
          name: 'Mine',
          diverId: 'd1',
          notes: 'my notes',
          rating: 3,
        ),
      );
      await SharedSitePublisher().push(
        siteId: 'p',
        libraryId: 'L',
        diverId: 'd1',
      );
      final kept = (await SharedLibraryStore().siteNotes(
        diverId: 'd1',
        siteId: 'p',
      ))!;
      expect(kept.notes, 'my notes');
      expect(kept.rating, 3);
    });
  });

  test(
    'a library pull on another device brings the profile its notes',
    () async {
      final cloud = FakeCloudStorageProvider();
      final account = ConnectedAccount(
        id: 'acc',
        kind: AccountKind.s3,
        label: 'Survey bucket',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      SharedLibraryMembershipService memberships() =>
          SharedLibraryMembershipService(
            store: SharedLibraryStore(),
            transportFor: ({required account, required prefix}) async =>
                SharedLibraryTransport(cloud, prefix: prefix),
            recoveryKdf: const KdfParams(m: 1024, t: 1),
          );
      SharedLibraryService syncer() => SharedLibraryService(
        store: SharedLibraryStore(),
        transportFor: (l) => memberships().transportForLibrary(l),
      );

      // The phone: the library and its site.
      await setUpTestDatabase();
      await diver('d1');
      final lib = await memberships().create(
        account: account,
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await SiteRepository().createSite(
        DiveSite(id: 's1', name: 'Blue', sharedLibraryId: lib.id),
      );
      await SharedLibraryStore().putSiteState(
        SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
      );
      await syncer().sync(lib.id, diverId: 'd1');
      await tearDownTestDatabase();

      // The tablet: personal sync has brought the profile's notes, then the
      // library is connected and pulled.
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await diver('d1');
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's1',
        notes: 'written on the phone',
        rating: 4,
      );
      await memberships().join(
        account: account,
        prefix: 'site-sync',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await syncer().sync(lib.id, diverId: 'd1');
      final site = (await SiteRepository().getSiteById('s1'))!;
      expect(site.name, 'Blue');
      expect(site.notes, 'written on the phone');
      expect(site.rating, 4);
    },
  );

  test('notes written before they were kept apart are taken up', () async {
    final cloud = FakeCloudStorageProvider();
    final memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: const KdfParams(m: 1024, t: 1),
    );
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await diver('d1');
    final lib = await memberships.create(
      account: ConnectedAccount(
        id: 'acc',
        kind: AccountKind.s3,
        label: 'Survey bucket',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    // A library site from an earlier build: its notes sit only on the row.
    await SiteRepository().createSite(
      DiveSite(
        id: 's1',
        name: 'Blue',
        notes: 'from before',
        rating: 2,
        sharedLibraryId: lib.id,
      ),
    );
    await SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (l) => memberships.transportForLibrary(l),
    ).sync(lib.id, diverId: 'd1');
    final kept = (await SharedLibraryStore().siteNotes(
      diverId: 'd1',
      siteId: 's1',
    ))!;
    expect(kept.notes, 'from before');
    expect(kept.rating, 2);

    // Never over a record the profile already has.
    await SharedLibraryStore().putSiteNotes(
      diverId: 'd1',
      siteId: 's1',
      notes: 'newer',
      rating: 5,
    );
    await SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (l) => memberships.transportForLibrary(l),
    ).sync(lib.id, diverId: 'd1');
    expect(
      (await SharedLibraryStore().siteNotes(
        diverId: 'd1',
        siteId: 's1',
      ))!.notes,
      'newer',
    );
  });
}
