import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

SharedSiteSuggestion _incoming(String id, Map<String, Object?> fields) =>
    SharedSiteSuggestion(
      id: id,
      libraryId: 'L',
      siteId: 's',
      memberId: 'r',
      memberName: 'Ray',
      note: 'please',
      fields: fields,
      createdAt: DateTime.utc(2026, 10, 1),
      direction: SharedSiteSuggestion.incoming,
    );

void main() {
  late FakeCloudStorageProvider cloud;
  late SuggestionService service;
  late SharedLibraryTransport t;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'club');
    await _diver('reader');
    await _diver('owner');
    final store = SharedLibraryStore();
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Club',
        connectedAccountId: 'acc',
        prefix: 'club',
        roles: SharedLibraryRoles(owners: {'o'}),
      ),
    );
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'm-r',
        diverId: 'reader',
        libraryId: 'L',
        memberId: 'r',
        displayName: 'Ray',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'm-o',
        diverId: 'owner',
        libraryId: 'L',
        memberId: 'o',
        displayName: 'Olga',
        libraryName: 'Club',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 's', name: 'S', hazards: 'old', sharedLibraryId: 'L'),
    );
    await store.putSiteState(
      const SharedSiteState(siteId: 's', libraryId: 'L'),
    );
    service = SuggestionService(
      transportFor: (lib) async =>
          SharedLibraryTransport(cloud, prefix: lib.prefix),
    );
  });

  tearDown(tearDownTestDatabase);

  test(
    'propose stores only the changed fields and leaves the site alone',
    () async {
      final site = (await SiteRepository().getSiteById('s'))!;
      final s = await service.propose(
        proposed: site.copyWith(hazards: 'new', notes: 'n'),
        diverId: 'reader',
        note: 'please',
      );
      expect(s!.fields, {'hazards': 'new', 'notes': 'n'});
      expect(s.direction, SharedSiteSuggestion.outgoing);
      expect(s.status, SharedSiteSuggestion.pending);
      expect(s.memberId, 'r');
      expect(s.memberName, 'Ray');
      expect(s.note, 'please');
      expect((await SiteRepository().getSiteById('s'))!.hazards, 'old');
      expect(await service.propose(proposed: site, diverId: 'reader'), isNull);
      final stored = await SharedLibraryStore().suggestions('L');
      expect(stored.single.id, s.id);
    },
  );

  test('propose carries changed child lists', () async {
    final site = (await SiteRepository().getSiteById('s'))!;
    final s = await service.propose(
      proposed: site,
      diverId: 'reader',
      childFields: {
        'siteTypes': ['Reef'],
      },
    );
    expect(s!.fields, {
      'siteTypes': ['Reef'],
    });
  });

  test('withdraw removes a pending outgoing suggestion', () async {
    final site = (await SiteRepository().getSiteById('s'))!;
    final s = await service.propose(
      proposed: site.copyWith(notes: 'x'),
      diverId: 'reader',
    );
    await service.withdraw(s!.id);
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });

  test(
    'accept applies with the suggester as editor and removes the file',
    () async {
      await t.writeSuggestion(
        'g1',
        _incoming('g1', {'hazards': 'new'}).toJson(),
      );
      await SharedLibraryStore().putSuggestion(
        _incoming('g1', {'hazards': 'new'}),
      );
      final diff = await service.diff(
        (await SharedLibraryStore().suggestions('L')).single,
      );
      expect(diff['hazards'], ('old', 'new'));
      await service.accept('g1', diverId: 'owner');
      expect((await SiteRepository().getSiteById('s'))!.hazards, 'new');
      final state = (await SharedLibraryStore().getSiteState('s'))!;
      expect(state.clocks['hazards']!.memberId, 'r');
      expect(state.lastEditorMemberId, 'r');
      expect(state.dirty, isTrue);
      expect(await t.listSuggestions(), isEmpty);
      expect(await SharedLibraryStore().suggestions('L'), isEmpty);
    },
  );

  test(
    'dismiss drops the file and the row; a vanished file is tolerated',
    () async {
      await SharedLibraryStore().putSuggestion(_incoming('g2', {'notes': 'x'}));
      await service.dismiss('g2', diverId: 'owner');
      expect(await SharedLibraryStore().suggestions('L'), isEmpty);
      expect((await SiteRepository().getSiteById('s'))!.notes, '');
    },
  );

  test('a reader may neither accept nor dismiss', () async {
    await SharedLibraryStore().putSuggestion(_incoming('g4', {'notes': 'x'}));
    expect(() => service.accept('g4', diverId: 'reader'), throwsStateError);
    expect(() => service.dismiss('g4', diverId: 'reader'), throwsStateError);
    expect(await SharedLibraryStore().suggestions('L'), hasLength(1));
  });

  test('accept of a suggestion whose site is gone only dismisses', () async {
    await SharedLibraryStore().putSuggestion(_incoming('g3', {'notes': 'x'}));
    await SiteRepository().deleteSite('s');
    await service.accept('g3', diverId: 'owner');
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });

  test('an accept whose remote delete fails is not re-imported, and the '
      'next sync finishes the delete', () async {
    await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
    await t.writeRoles(const SharedLibraryRoles(owners: {'o'}));
    await t.writeSuggestion('g9', _incoming('g9', {'hazards': 'new'}).toJson());
    await SharedLibraryStore().putSuggestion(
      _incoming('g9', {'hazards': 'new'}),
    );

    cloud.failDeletes = true; // offline at the moment of the accept
    await service.accept('g9', diverId: 'owner');
    expect((await SiteRepository().getSiteById('s'))!.hazards, 'new');
    final inbox = await SharedLibraryStore().suggestions(
      'L',
      direction: SharedSiteSuggestion.incoming,
      status: SharedSiteSuggestion.pending,
    );
    expect(inbox, isEmpty, reason: 'handled, so out of the inbox');

    final sync = SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (lib) async =>
          SharedLibraryTransport(cloud, prefix: lib.prefix),
    );
    await sync.sync('L', diverId: 'owner');
    expect(
      await SharedLibraryStore().suggestions(
        'L',
        direction: SharedSiteSuggestion.incoming,
        status: SharedSiteSuggestion.pending,
      ),
      isEmpty,
      reason: 'the still-present file is not imported again',
    );

    cloud.failDeletes = false;
    await sync.sync('L', diverId: 'owner');
    expect(await t.listSuggestions(), isEmpty);
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });

  test('only a reader proposes; an owner edits instead', () async {
    await expectLater(
      service.propose(
        proposed: (await SiteRepository().getSiteById(
          's',
        ))!.copyWith(hazards: 'owner idea'),
        diverId: 'owner',
      ),
      throwsStateError,
    );
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });
}
