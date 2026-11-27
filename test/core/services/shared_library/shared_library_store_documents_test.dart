import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';

import '../../../helpers/test_database.dart';

FieldClock c(int t) => FieldClock(hlc: Hlc(t, 0, 'm1'), memberId: 'm1');

SharedDocumentState state(
  String id, {
  String library = 'L',
  String site = 's1',
  bool dirty = false,
  String? stamp,
  bool parked = false,
}) => SharedDocumentState(
  documentId: id,
  libraryId: library,
  siteId: site,
  clocks: {'title': c(5)},
  remoteModifiedTime: stamp,
  dirty: dirty,
  parked: parked,
);

void main() {
  late SharedLibraryStore store;

  setUp(() async {
    await setUpTestDatabase();
    store = SharedLibraryStore();
  });
  tearDown(tearDownTestDatabase);

  test('put then get round-trips the clocks and flags', () async {
    await store.putDocumentState(
      state('doc1', dirty: true, stamp: 't', parked: true),
    );
    final back = await store.getDocumentState('doc1');
    expect(back!.clocks, {'title': c(5)});
    expect(back.siteId, 's1');
    expect(back.dirty, isTrue);
    expect(back.parked, isTrue);
    expect(back.remoteModifiedTime, 't');
    expect(await store.getDocumentState('nope'), isNull);
  });

  test('dirtyDocuments returns only dirty rows of that library', () async {
    await store.putDocumentState(state('a', dirty: true));
    await store.putDocumentState(state('b'));
    await store.putDocumentState(state('c', library: 'L2', dirty: true));
    expect((await store.dirtyDocuments('L')).map((s) => s.documentId), ['a']);
    expect((await store.documentStates('L')).keys, unorderedEquals(['a', 'b']));
  });

  test('clearDocumentStampsForSite clears only that site', () async {
    await store.putDocumentState(state('a', stamp: 't1', parked: true));
    await store.putDocumentState(state('b', site: 's2', stamp: 't2'));
    await store.clearDocumentStampsForSite('s1');
    final a = await store.getDocumentState('a');
    expect(a!.remoteModifiedTime, isNull);
    expect(a.parked, isFalse);
    expect((await store.getDocumentState('b'))!.remoteModifiedTime, 't2');
  });

  test('deleteDocumentState removes one row', () async {
    await store.putDocumentState(state('a'));
    await store.deleteDocumentState('a');
    expect(await store.getDocumentState('a'), isNull);
  });

  test('deleteLibrary removes the library\'s document states', () async {
    await store.putDocumentState(state('a'));
    await store.putDocumentState(state('b', library: 'L2'));
    await store.deleteLibrary('L');
    expect(await store.getDocumentState('a'), isNull);
    expect(await store.getDocumentState('b'), isNotNull);
  });

  test('clearRemoteStamps clears document stamps too', () async {
    await store.putDocumentState(state('a', stamp: 't1'));
    await store.putSiteState(
      const SharedSiteState(
        siteId: 's1',
        libraryId: 'L',
        remoteModifiedTime: 'x',
      ),
    );
    await store.clearRemoteStamps('L');
    expect((await store.getDocumentState('a'))!.remoteModifiedTime, isNull);
    expect((await store.getSiteState('s1'))!.remoteModifiedTime, isNull);
  });
}
