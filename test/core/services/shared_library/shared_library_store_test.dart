import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SharedLibraryStore store;

  setUp(() async {
    await setUpTestDatabase();
    store = SharedLibraryStore();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('library round trip, status update and cascade delete', () async {
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Club',
        connectedAccountId: 'acc',
        prefix: 'club/',
      ),
    );
    await store.replaceMembers('L', [
      SharedLibraryMember(
        memberId: 'm1',
        displayName: 'Ann',
        joinedAt: DateTime.utc(2026),
      ),
    ]);
    await store.setLibraryStatus(
      'L',
      lastError: 'boom',
      roles: const SharedLibraryRoles(owners: {'m1'}),
    );
    final lib = (await store.getLibrary('L'))!;
    expect(lib.lastError, 'boom');
    expect(lib.prefix, 'club/');
    expect(lib.roles.roleOf('m1'), SharedLibraryRole.owner);
    expect(await store.memberNames('L'), {'m1': 'Ann'});
    await store.setLibraryStatus('L', clearError: true, readOnlyDetected: true);
    final again = (await store.getLibrary('L'))!;
    expect(again.lastError, isNull);
    expect(again.readOnlyDetected, isTrue);
    expect((await store.getLibraries()).map((l) => l.id), ['L']);
    await store.deleteLibrary('L');
    expect(await store.getMembers('L'), isEmpty);
    expect(await store.getLibrary('L'), isNull);
  });

  test('memberIdForDiver is stable across libraries', () async {
    final first = await store.memberIdForDiver('d1');
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: first,
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    expect(await store.memberIdForDiver('d1'), first);
    final rows = await store.membershipsForDiver('d1');
    expect(rows.single.memberId, first);
    expect((await store.membership(diverId: 'd1', libraryId: 'L'))?.id, 'ms1');
    expect(await store.membership(diverId: 'd1', libraryId: 'X'), isNull);
    expect((await store.membershipsForLibrary('L')).single.diverId, 'd1');
    await store.deleteMembership('ms1');
    expect(await store.membershipsForDiver('d1'), isEmpty);
  });

  test('upsertMembership stamps an hlc for personal sync', () async {
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms1',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm',
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT hlc FROM shared_library_memberships WHERE id = 'ms1'",
        )
        .getSingle();
    expect(row.read<String?>('hlc'), isNotNull);
  });

  test('site state keeps clocks, the dirty flag and deleted', () async {
    const clock = FieldClock(hlc: Hlc(1, 0, 'm'), memberId: 'm');
    const state = SharedSiteState(
      siteId: 's',
      libraryId: 'L',
      clocks: {'name': clock},
      dirty: true,
    );
    await store.putSiteState(state);
    final read = (await store.getSiteState('s'))!;
    expect(read.clocks['name'], clock);
    expect(read.dirty, isTrue);
    expect(read.deleted, isFalse);
    expect((await store.dirtySites('L')).map((e) => e.siteId), ['s']);
    expect((await store.siteStates('L')).keys, ['s']);
    await store.putSiteState(read.copyWith(deleted: true, dirty: false));
    final after = (await store.getSiteState('s'))!;
    expect(after.deleted, isTrue);
    expect(await store.dirtySites('L'), isEmpty);
    await store.deleteSiteState('s');
    expect(await store.getSiteState('s'), isNull);
  });

  test('suggestions filter by direction, status and site', () async {
    await store.putSuggestion(
      SharedSiteSuggestion(
        id: 'g1',
        libraryId: 'L',
        siteId: 's',
        memberId: 'm',
        memberName: 'Ann',
        fields: const {'notes': 'x'},
        createdAt: DateTime.utc(2026),
        direction: 'outgoing',
        status: 'pending',
      ),
    );
    expect(
      await store.suggestions('L', direction: 'outgoing', status: 'pending'),
      hasLength(1),
    );
    expect(await store.suggestions('L', direction: 'incoming'), isEmpty);
    expect(await store.suggestions('L', siteId: 'other'), isEmpty);
    final s = (await store.suggestions('L')).single;
    expect(s.fields, {'notes': 'x'});
    await store.putSuggestion(s.copyWith(status: 'uploaded'));
    expect(await store.suggestions('L', status: 'pending'), isEmpty);
    await store.deleteSuggestion('g1');
    expect(await store.suggestions('L'), isEmpty);
  });

  test('deleting a library drops its site states and suggestions', () async {
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Club',
        connectedAccountId: 'a',
        prefix: 'p',
      ),
    );
    await store.putSiteState(
      const SharedSiteState(
        siteId: 'gone',
        libraryId: 'L',
        deleted: true,
        dirty: true,
      ),
    );
    await store.putSuggestion(
      SharedSiteSuggestion(
        id: 'g',
        libraryId: 'L',
        siteId: 'gone',
        memberId: 'm',
        memberName: 'M',
        createdAt: DateTime.utc(2026),
        direction: SharedSiteSuggestion.incoming,
      ),
    );
    await store.deleteLibrary('L');
    expect(
      await store.getSiteState('gone'),
      isNull,
      reason: 'a stale pending tombstone would delete the site on rejoin',
    );
    expect(await store.suggestions('L'), isEmpty);
  });

  test('a membership write stamps its clock for the personal sync', () async {
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm',
        displayName: 'Ann',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    final rows = await DatabaseService.instance.database
        .customSelect(
          "SELECT hlc FROM shared_library_memberships WHERE id = 'ms'",
        )
        .get();
    expect(rows.single.read<String?>('hlc'), isNotNull);
  });
}
