import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';

/// A member whose editing role ends (they leave, are demoted, or their
/// role is removed) keeps the edits they signed before then (issue #2567).
void main() {
  tearDown(SyncCoordinator.reset);

  group('the cut-off', () {
    Future<SiteDocument> signedAt(int physicalTime) async => signOwnFields(
      SiteDocument(
        id: 's',
        fields: const {'name': 'Blue'},
        clocks: {
          'name': FieldClock(hlc: Hlc(physicalTime, 0, 'x'), memberId: 'x'),
        },
      ),
      libraryId: 'L',
      memberId: 'x',
      key: await testMemberKey('x'),
    );

    test('an edit signed before it counts, one after does not', () async {
      final key = (await testMemberKey('x')).publicKey;
      final retired = {
        'x': [(key, 5000)],
      };
      final before = await dropUnverified(
        await signedAt(4000),
        local: const SiteDocument(id: 's'),
        libraryId: 'L',
        approvedKeys: const {},
        retiredKeys: retired,
      );
      expect(before.fields['name'], 'Blue');
      final after = await dropUnverified(
        await signedAt(6000),
        local: const SiteDocument(id: 's'),
        libraryId: 'L',
        approvedKeys: const {},
        retiredKeys: retired,
      );
      expect(after.fields, isEmpty);
    });

    test('roles record it on leaving an editing role, not on rejection', () {
      const roles = SharedLibraryRoles(
        owners: {'o'},
        editors: {'e'},
        approvedKeys: {'o': 'ko', 'e': 'ke', 'r': 'kr'},
      );
      final at = DateTime.utc(2026, 10, 1);
      final demoted = roles.changeRole('e', SharedLibraryRole.reader, at: at);
      expect(demoted.retired['e'], [
        (key: 'ke', untilMs: at.millisecondsSinceEpoch),
      ]);
      expect(demoted.retiredKeys['e'], [('ke', at.millisecondsSinceEpoch)]);
      // A reader never edited: nothing to keep.
      expect(
        roles.changeRole('r', SharedLibraryRole.reader, at: at).retired,
        isEmpty,
      );
      // Roles without retired keys sign as they always did.
      expect(roles.unsignedJson().containsKey('retired'), isFalse);
      expect(demoted.unsignedJson()['retired'], {
        'e': [
          {'key': 'ke', 'until': at.millisecondsSinceEpoch},
        ],
      });
      expect(SharedLibraryRoles.fromJson(demoted.toJson()), demoted);
    });

    test("an editor's new key keeps the old key's edits, every one", () {
      const roles = SharedLibraryRoles(
        editors: {'e'},
        approvedKeys: {'e': 'k1'},
      );
      final first = DateTime.utc(2026, 10, 1);
      final second = DateTime.utc(2026, 11, 1);
      final once = roles.approveKey('e', 'k2', at: first);
      expect(once.approvedKeys['e'], 'k2');
      final twice = once.approveKey('e', 'k3', at: second);
      expect(twice.approvedKeys['e'], 'k3');
      expect(twice.retiredKeys['e'], [
        ('k1', first.millisecondsSinceEpoch),
        ('k2', second.millisecondsSinceEpoch),
      ]);
      // The same key again, or a reader's new key, keeps nothing.
      expect(
        twice.approveKey('e', 'k3', at: second).retired['e'],
        hasLength(2),
      );
      const reader = SharedLibraryRoles(approvedKeys: {'r': 'k1'});
      expect(reader.approveKey('r', 'k2', at: first).retired, isEmpty);
    });
  });

  test(
    "a founder who leaves keeps their sites for members who join later",
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
      Future<void> diver(String id) => DiverRepository().createDiver(
        Diver(
          id: id,
          name: id,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      Future<String> memberOf(String diverId, String libraryId) async =>
          (await SharedLibraryStore().membership(
            diverId: diverId,
            libraryId: libraryId,
          ))!.memberId;

      await setUpTestDatabase();
      await diver('founder');
      await diver('heir');
      final lib = await memberships().create(
        account: account,
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'founder',
        displayName: 'Ann',
      );
      await SiteRepository().createSite(
        DiveSite(
          id: 's1',
          name: 'Blue',
          hazards: 'surge',
          sharedLibraryId: lib.id,
        ),
      );
      await SharedLibraryStore().putSiteState(
        SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
      );
      await syncer().sync(lib.id, diverId: 'founder');
      await memberships().join(
        account: account,
        prefix: 'site-sync',
        diverId: 'heir',
        displayName: 'Bo',
      );
      final founder = await memberOf('founder', lib.id);
      final heir = await memberOf('heir', lib.id);
      await memberships().approveMember(
        libraryId: lib.id,
        memberId: heir,
        actingMemberId: founder,
        publicKey: (await SharedLibraryStore().signingKeyForDiver(
          'heir',
        ))!.publicKey,
      );
      await memberships().setRole(
        libraryId: lib.id,
        actingMemberId: founder,
        memberId: heir,
        role: SharedLibraryRole.owner,
      );
      await memberships().leave(libraryId: lib.id, diverId: 'founder');
      await tearDownTestDatabase();

      // Someone who joins afterwards, on a device of their own.
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await diver('late');
      await memberships().join(
        account: account,
        prefix: 'site-sync',
        diverId: 'late',
        displayName: 'Cy',
      );
      await syncer().sync(lib.id, diverId: 'late');
      final site = (await SiteRepository().getSiteById('s1'))!;
      expect(site.name, 'Blue');
      expect(site.hazards, 'surge');
    },
  );
}
