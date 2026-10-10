import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';

/// Documents follow their owner through merges and come back with it on
/// undo (issue #2613), the way media does: a merge moves them to the
/// survivor before deleting the duplicates, and an undo moves them back.
Future<Document> _addDoc(DocumentOwnerKind kind, String ownerId) =>
    DocumentRepository().save(
      Document(
        id: '',
        diverId: 'a',
        owner: DocumentOwner(kind, ownerId),
        type: DocumentType.permit,
        title: 'doc of $ownerId',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.txt',
          mimeType: 'text/plain',
          sizeBytes: 2,
          bytes: Uint8List.fromList([4, 2]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

Future<DocumentOwner?> _ownerOf(String documentId) async =>
    (await DocumentRepository().getById(documentId))?.owner;

void main() {
  late AppDatabase db;
  final repo = DocumentRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['a']);
  });
  tearDown(tearDownTestDatabase);

  group('repository', () {
    test(
      'reassignOwner moves documents and restoreOwners moves them back',
      () async {
        await seedSite(db, 's1', owner: 'a');
        await seedSite(db, 's2', owner: 'a');
        final doc = await _addDoc(DocumentOwnerKind.site, 's2');
        final moved = await repo.reassignOwner(DocumentOwnerKind.site, [
          's2',
        ], 's1');
        expect(moved, {doc.id: 's2'});
        expect(
          await _ownerOf(doc.id),
          const DocumentOwner(DocumentOwnerKind.site, 's1'),
        );
        await repo.restoreOwners(DocumentOwnerKind.site, moved);
        expect(
          await _ownerOf(doc.id),
          const DocumentOwner(DocumentOwnerKind.site, 's2'),
        );
      },
    );

    test(
      'a captured snapshot restores documents and pages after a delete',
      () async {
        await seedSite(db, 's1', owner: 'a');
        final doc = await _addDoc(DocumentOwnerKind.site, 's1');
        final snapshot = await repo.captureForOwners(DocumentOwnerKind.site, [
          's1',
        ]);
        await repo.deleteForOwner(DocumentOwnerKind.site, 's1');
        expect(await repo.getById(doc.id), isNull);
        await repo.restoreSnapshot(snapshot);
        expect((await repo.getById(doc.id))!.title, 'doc of s1');
        expect((await repo.getPages(doc.id)).single.bytes, [4, 2]);
      },
    );
  });

  group('sites', () {
    test(
      'a merge moves the duplicate\'s documents to the survivor; undo moves them back',
      () async {
        final sites = SiteRepository();
        await seedSite(db, 's1', owner: 'a');
        await seedSite(db, 's2', owner: 'a');
        final doc = await _addDoc(DocumentOwnerKind.site, 's2');
        final survivor = (await sites.getSiteById('s1'))!;
        final snapshot = await sites.mergeSites(
          mergedSite: survivor,
          siteIds: ['s1', 's2'],
          actingDiverId: 'a',
        );
        expect(
          await _ownerOf(doc.id),
          const DocumentOwner(DocumentOwnerKind.site, 's1'),
        );
        await sites.undoMerge(snapshot!);
        expect(
          await _ownerOf(doc.id),
          const DocumentOwner(DocumentOwnerKind.site, 's2'),
        );
      },
    );

    test('undoing a bulk delete brings the documents back', () async {
      final sites = SiteRepository();
      await seedSite(db, 's1', owner: 'a');
      final doc = await _addDoc(DocumentOwnerKind.site, 's1');
      final deleted = await sites.getSitesByIds(['s1']);
      final links = await sites.bulkDeleteSites(['s1'], actingDiverId: 'a');
      expect(await repo.getById(doc.id), isNull);
      // What SiteListNotifier.restoreSites does for the undo.
      for (final site in deleted) {
        await sites.createSite(site);
      }
      await sites.restoreSiteLinks(links);
      expect(
        await _ownerOf(doc.id),
        const DocumentOwner(DocumentOwnerKind.site, 's1'),
      );
      expect((await repo.getPages(doc.id)).single.bytes, [4, 2]);
    });
  });

  group('buddies', () {
    test(
      'a merge moves the duplicate\'s documents to the survivor; undo moves them back',
      () async {
        final buddies = BuddyRepository();
        Buddy buddy(String name) => Buddy(
          id: '',
          diverId: 'a',
          name: name,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final survivor = await buddies.createBuddy(buddy('Chris'));
        final dup = await buddies.createBuddy(buddy('C'));
        final doc = await _addDoc(DocumentOwnerKind.buddy, dup.id);
        final result = await BuddyMergeRepository().mergeBuddies(
          mergedBuddy: survivor,
          buddyIds: [survivor.id, dup.id],
        );
        expect(
          await _ownerOf(doc.id),
          DocumentOwner(DocumentOwnerKind.buddy, survivor.id),
        );
        await BuddyMergeRepository().undoMerge(result!.snapshot!);
        expect(
          await _ownerOf(doc.id),
          DocumentOwner(DocumentOwnerKind.buddy, dup.id),
        );
      },
    );
  });

  group('dives', () {
    Future<void> createDive(DiveRepository dives, String id, int minutes) {
      final entry = DateTime.utc(2026, 7, 1, 9, minutes);
      return dives.createDive(
        domain.Dive(
          id: id,
          diverId: 'a',
          dateTime: entry,
          entryTime: entry,
          runtime: const Duration(minutes: 10),
          maxDepth: 10,
        ),
      );
    }

    test(
      'a merge moves both dives\' documents to the merged dive; undo moves them back',
      () async {
        await db.customStatement('PRAGMA foreign_keys = OFF');
        final dives = DiveRepository();
        await createDive(dives, 'v1', 0);
        await createDive(dives, 'v2', 15);
        final d1 = await _addDoc(DocumentOwnerKind.dive, 'v1');
        final d2 = await _addDoc(DocumentOwnerKind.dive, 'v2');
        final outcome = await DiveMergeService(dives).apply(['v1', 'v2']);
        final mergedId = outcome.mergedDive.id;
        expect(
          await _ownerOf(d1.id),
          DocumentOwner(DocumentOwnerKind.dive, mergedId),
        );
        expect(
          await _ownerOf(d2.id),
          DocumentOwner(DocumentOwnerKind.dive, mergedId),
        );
        await DiveMergeService(dives).undo(outcome.snapshot);
        expect(
          await _ownerOf(d1.id),
          const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
        );
        expect(
          await _ownerOf(d2.id),
          const DocumentOwner(DocumentOwnerKind.dive, 'v2'),
        );
      },
    );
  });
}
