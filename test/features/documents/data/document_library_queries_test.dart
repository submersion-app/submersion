import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../helpers/test_database.dart';

/// Where shared library documents (issue #4713) show: on their site's card
/// for every member, never in a diver's own list or reminders.
void main() {
  const site = DocumentOwner(DocumentOwnerKind.site, 'lib');
  late DocumentRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    for (final id in ['d1', 'd2']) {
      await DiverRepository().createDiver(
        Diver(
          id: id,
          name: id,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
    }
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Club',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'),
    );
    await LibraryDocumentBridge().apply(
      LibraryDocumentRecord(
        id: 'club',
        siteId: 'lib',
        fields: {
          'type': 'permit',
          'title': 'Club permit',
          'expiryDate': DateTime.now()
              .add(const Duration(days: 3))
              .millisecondsSinceEpoch,
          'pages': [
            {
              'id': 'p1',
              'pageIndex': 0,
              'side': null,
              'fileName': 'a.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 1,
              'fileId': 'f1',
              'sha256': sha256Hex([1]),
            },
          ],
        },
      ),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: {
        'f1': Uint8List.fromList([1]),
      },
    );
    repo = DocumentRepository();
    for (final (id, diver) in [('mine', 'd1'), ('theirs', 'd2')]) {
      await repo.save(
        Document(
          id: id,
          diverId: diver,
          owner: site,
          type: DocumentType.map,
          title: id,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        const [],
      );
    }
  });
  tearDown(tearDownTestDatabase);

  test("a site's documents include shared ones for a member", () async {
    final docs = await repo.getForOwner(site, diverId: 'd1');
    expect(docs.map((d) => d.id), unorderedEquals(['club', 'mine']));
  });

  test('a profile without the membership does not see them', () async {
    final docs = await repo.getForOwner(site, diverId: 'd2');
    expect(docs.map((d) => d.id), ['theirs']);
  });

  test("a diver's own list leaves shared documents out", () async {
    final entries = await repo.getAllForDiver('d1');
    expect(entries.map((e) => e.document.id), ['mine']);
  });

  test(
    'the shared list holds the documents of the diver\'s libraries',
    () async {
      final entries = await repo.getSharedForDiver('d1');
      expect(entries.map((e) => e.document.id), ['club']);
      expect(await repo.getSharedForDiver('d2'), isEmpty);
    },
  );

  test('reminders leave a shared document with an expiry out', () async {
    final reminding = await repo.getRemindingForDiver('d1');
    expect(reminding.map((d) => d.id), isNot(contains('club')));
  });
}
