import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await _diver('d1');
    await _diver('d2');
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Club',
        connectedAccountId: 'acc',
        prefix: 'club',
        roles: SharedLibraryRoles(editors: {'m1'}),
      ),
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('push converts in place and clocks every field', () async {
    await SiteRepository().createSite(
      const DiveSite(
        id: 'p',
        diverId: 'd1',
        name: 'Mine',
        isShared: true,
        hazards: 'h',
      ),
    );
    expect(
      await ProfileHidesRepository().hide(SharedItemKind.site, 'p', 'd2'),
      isTrue,
    );
    await SharedSitePublisher().push(
      siteId: 'p',
      libraryId: 'L',
      diverId: 'd1',
    );
    final site = (await SiteRepository().getSiteById('p'))!;
    expect(site.sharedLibraryId, 'L');
    expect(site.diverId, isNull);
    expect(site.isShared, isFalse);
    expect(site.hazards, 'h');
    final state = (await SharedLibraryStore().getSiteState('p'))!;
    expect(state.dirty, isTrue);
    expect(state.deleted, isFalse);
    expect(state.clocks.keys, containsAll(SiteDocument.fieldNames));
    expect(state.clocks['name']!.memberId, 'm1');
    expect(state.lastEditorMemberId, 'm1');
    final hides = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM site_hides WHERE site_id = 'p'")
        .get();
    expect(hides, hasLength(1), reason: 'hides are left in place');
    expect(
      (await SiteRepository().getAllSites(diverId: 'd1')).map((s) => s.id),
      contains('p'),
    );
    final tombstones = await DatabaseService.instance.database
        .customSelect(
          "SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' "
          "AND record_id = 'p'",
        )
        .get();
    expect(
      tombstones,
      isEmpty,
      reason:
          'a device that has not connected the library keeps the personal '
          'copy its dives link to; connecting adopts it in place (same id)',
    );
  });

  test('push refuses a site another profile owns', () async {
    await SiteRepository().createSite(
      const DiveSite(id: 'theirs', diverId: 'd2', name: 'Bob', isShared: true),
    );
    await expectLater(
      SharedSitePublisher().push(
        siteId: 'theirs',
        libraryId: 'L',
        diverId: 'd1',
      ),
      throwsStateError,
    );
    final site = (await SiteRepository().getSiteById('theirs'))!;
    expect(site.sharedLibraryId, isNull);
    expect(site.diverId, 'd2');
  });

  test('push refuses a diver without a membership', () async {
    await SiteRepository().createSite(const DiveSite(id: 'p', name: 'Mine'));
    expect(
      () => SharedSitePublisher().push(
        siteId: 'p',
        libraryId: 'L',
        diverId: 'd2',
      ),
      throwsStateError,
    );
    expect((await SiteRepository().getSiteById('p'))!.sharedLibraryId, isNull);
  });

  test('push of a site already in a library is a no-op', () async {
    await SiteRepository().createSite(
      const DiveSite(id: 'p', name: 'Mine', sharedLibraryId: 'L'),
    );
    await SharedSitePublisher().push(
      siteId: 'p',
      libraryId: 'L',
      diverId: 'd1',
    );
    expect(await SharedLibraryStore().getSiteState('p'), isNull);
  });

  test(
    'deleteFromLibrary stamps the tombstone and removes the unlinked row',
    () async {
      await SiteRepository().createSite(
        const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'),
      );
      await SharedLibraryStore().putSiteState(
        const SharedSiteState(siteId: 'lib', libraryId: 'L'),
      );
      await SharedSitePublisher().deleteFromLibrary(
        siteId: 'lib',
        diverId: 'd1',
      );
      final state = (await SharedLibraryStore().getSiteState('lib'))!;
      expect(state.deleted, isTrue);
      expect(state.dirty, isTrue);
      expect(state.clocks['deleted']!.memberId, 'm1');
      expect(await SiteRepository().getSiteById('lib'), isNull);
    },
  );

  test(
    'undelete flips the flag with a newer clock and forces a re-pull',
    () async {
      await SharedLibraryStore().putSiteState(
        const SharedSiteState(
          siteId: 'gone',
          libraryId: 'L',
          deleted: true,
          remoteModifiedTime: '2026-01-01T00:00:00Z',
          clocks: {'deleted': FieldClock(hlc: Hlc(5, 0, 'x'), memberId: 'x')},
        ),
      );
      await SharedSitePublisher().undelete(siteId: 'gone', diverId: 'd1');
      final state = (await SharedLibraryStore().getSiteState('gone'))!;
      expect(state.deleted, isFalse);
      expect(state.dirty, isTrue);
      expect(state.remoteModifiedTime, isNull);
      expect(
        state.clocks['deleted']!.hlc.compareTo(const Hlc(5, 0, 'x')),
        greaterThan(0),
      );
    },
  );

  test('a reader may neither delete from the library nor undelete', () async {
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms2',
        diverId: 'd2',
        libraryId: 'L',
        memberId: 'm2',
        displayName: 'Bob',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 'c', name: 'Club', sharedLibraryId: 'L'),
    );
    await SharedLibraryStore().putSiteState(
      const SharedSiteState(siteId: 'c', libraryId: 'L'),
    );
    await expectLater(
      SharedSitePublisher().deleteFromLibrary(siteId: 'c', diverId: 'd2'),
      throwsStateError,
    );
    await expectLater(
      SharedSitePublisher().undelete(siteId: 'c', diverId: 'd2'),
      throwsStateError,
    );
    expect(await SiteRepository().getSiteById('c'), isNotNull);
    expect((await SharedLibraryStore().getSiteState('c'))!.dirty, isFalse);
  });

  test('a reader cannot push a site into the library', () async {
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms2',
        diverId: 'd2',
        libraryId: 'L',
        memberId: 'm2',
        displayName: 'Bob',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 'bobs', diverId: 'd2', name: 'Bob site'),
    );
    await expectLater(
      SharedSitePublisher().push(siteId: 'bobs', libraryId: 'L', diverId: 'd2'),
      throwsStateError,
    );
    expect(
      (await SiteRepository().getSiteById('bobs'))!.sharedLibraryId,
      isNull,
    );
  });
}
