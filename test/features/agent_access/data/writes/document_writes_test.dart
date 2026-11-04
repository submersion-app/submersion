import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A diver's documents, written as their details (pages stay in the app),
/// and smart albums, as the documents page and the media library keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late List<String> rearmed;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    rearmed = [];
    h = ChildWriteHarness(
      db,
      catalog: (repos) => WriteCatalog(
        repos,
        rearmDocuments: (docs) async =>
            rearmed.addAll([for (final d in docs) d.id]),
      ),
    );
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  // d2 is the other profile's private dive; d1 is this profile's own.
  test('a document cannot be attached to another profile\'s record', () async {
    Map<String, Object?> on(String dive) => createOp('documents', {
      'type': 'other',
      'title': 'Log page',
      'owner_kind': 'dive',
      'owner_id': dive,
    });

    final plan = await h.preview([on('d2')]);
    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);

    final own = await h.preview([on('d1')]);
    expect(own.items.single.block, isNull);
  });

  test(
    'a document\'s details are written and it is deleted with its pages listed',
    () async {
      final id = await make('documents', {
        'type': 'permit',
        'title': ' Marine park permit ',
        'expiry_date': '2026-01-31',
      });
      expect(rearmed, [id]);
      final doc = (await h.one('documents', id))!;
      expect(
        [doc['title'], doc['owner_kind'], doc['expiry_date']],
        ['Marine park permit', 'personal', '2026-01-31'],
      );
      await db
          .into(db.documentPages)
          .insert(
            DocumentPagesCompanion.insert(
              id: 'page-1',
              documentId: id,
              pageIndex: 0,
              fileName: 'permit.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
              createdAt: kSeedTime,
              updatedAt: kSeedTime,
            ),
          );

      await h.run([
        updateOp('documents', id, {'notes': 'Renewed online'}),
      ]);
      expect((await h.one('documents', id))!['notes'], 'Renewed online');
      expect(await db.select(db.documentPages).get(), hasLength(1));

      final drop = await h.preview([deleteOp('documents', id)]);
      expect(drop.items.single.reach.parts, {'document_pages': 1});
      await h.apply(drop);
      expect(await h.one('documents', id), isNull);
    },
  );

  test('is_primary on a non-insurance document is refused', () async {
    final plan = await h.preview([
      createOp('documents', {'type': 'permit', 'is_primary': true}),
      createOp('documents', {'type': 'booking', 'phone': '+1 555'}),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('making a document primary lists the one it takes over from', () async {
    await make('documents', {
      'type': 'insurance',
      'title': 'DAN',
      'is_primary': true,
    });
    final second = await make('documents', {
      'type': 'insurance',
      'title': 'DiveAssure',
    });

    final plan = await h.preview([
      updateOp('documents', second, {'is_primary': true}),
    ]);
    expect(plan.items.single.alsoChanges, {'documents': 1});
    await h.apply(plan);

    final primaries = await (db.select(
      db.documents,
    )..where((d) => d.isPrimary.equals(true))).get();
    expect([for (final d in primaries) d.id], [second]);
    expect(DocumentType.insurance.name, 'insurance');
  });

  test('a smart album is created, renamed and deleted', () async {
    final id = await make('smart_albums', {
      'name': ' Reef photos ',
      'filter': {'mediaType': 'photo', 'from_date': '2024-03-01'},
    });
    final album = (await h.one('smart_albums', id))!;
    expect(album['name'], 'Reef photos');
    expect((album['filter']! as Map)['from_date'], '2024-03-01');

    await h.run([
      updateOp('smart_albums', id, {'name': 'Reefs'}),
    ]);
    expect((await h.one('smart_albums', id))!['name'], 'Reefs');

    await h.run([deleteOp('smart_albums', id)]);
    expect(await h.one('smart_albums', id), isNull);
  });

  test('an empty filter is refused', () async {
    final plan = await h.preview([
      createOp('smart_albums', {'name': 'All', 'filter': <String, Object?>{}}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });
}
