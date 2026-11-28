import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';
import 'support/library_devices.dart';

/// Documents shared through a shared site library (issue #4713), synced
/// between members' devices on one fake storage.
void main() {
  late FakeCloudStorageProvider cloud;
  late Directory dir;

  File fileOf(String member) => File(p.join(dir.path, '$member.db'));

  setUp(() {
    cloud = FakeCloudStorageProvider();
    dir = Directory.systemTemp.createTempSync('library_docs_');
  });
  tearDown(() async {
    await closeLibraryDevice();
    try {
      await tearDownTestDatabase();
    } catch (_) {}
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  SharedLibraryTransport transport() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  int documentUploads() =>
      cloud.operationLog.where((e) => e.startsWith('upload:document-')).length;

  /// Member a's device, holding site s1 and a shared document on it, synced.
  Future<String> ownerShares({
    List<int> bytes = const [1, 2, 3],
    Set<String> owners = const {'a'},
  }) async {
    final svc = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      owners: owners,
    );
    await addLibrarySite('s1', 'a');
    final id = await addSharedDocument('s1', 'a', bytes: bytes);
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.success);
    return id;
  }

  test(
    "an editor's shared document reaches a reader with every page",
    () async {
      await seedTestLibrary(cloud);
      final id = await ownerShares();

      final svc = await libraryDevice(cloud, 'b');
      final r = await svc.sync('L', diverId: 'd-b');
      expect(r.status, SharedLibrarySyncStatus.success);
      final doc = (await DocumentRepository().getById(id))!;
      expect(doc.sharedLibraryId, 'L');
      expect(doc.diverId, isNull);
      expect(doc.title, 'Access');
      final pages = await DocumentRepository().getPages(id);
      expect(pages.single.bytes, [1, 2, 3]);
    },
  );

  test("a reader's device never uploads a document or page file", () async {
    await seedTestLibrary(cloud);
    final id = await ownerShares();
    final svc = await libraryDevice(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    await LibraryDocumentStamper().stamp(id, {'title'}, actingDiverId: 'd-b');
    final uploads = cloud.operationLog
        .where((e) => e.startsWith('upload:document-') || e.endsWith('.bin'))
        .length;
    await svc.sync('L', diverId: 'd-b');
    expect(
      cloud.operationLog
          .where((e) => e.startsWith('upload:document-') || e.endsWith('.bin'))
          .length,
      uploads,
    );
  });

  test('a page file with the wrong bytes keeps the document hidden and '
      'retries', () async {
    await seedTestLibrary(cloud);
    final id = await ownerShares();
    final page = (await transport().listPageFiles()).single;
    final good = (await cloud.downloadFile(page.id));
    cloud.seedFile(page.id, Uint8List.fromList([9, 9, 9]));

    final svc = await libraryDevice(cloud, 'b', file: fileOf('b'));
    expect(
      (await svc.sync('L', diverId: 'd-b')).status,
      SharedLibrarySyncStatus.success,
    );
    expect(await DocumentRepository().getById(id), isNull);

    cloud.seedFile(page.id, good);
    await svc.sync('L', diverId: 'd-b');
    expect((await DocumentRepository().getPages(id)).single.bytes, [1, 2, 3]);
  });

  test('concurrent page edits converge', () async {
    await seedTestLibrary(cloud, owners: {'a', 'b'});
    final id = await ownerShares(owners: {'a', 'b'});

    var svc = await libraryDevice(
      cloud,
      'b',
      file: fileOf('b'),
      owners: {'a', 'b'},
    );
    await svc.sync('L', diverId: 'd-b');
    Future<void> repage(String member, List<int> bytes) async {
      final repo = DocumentRepository();
      await repo.save((await repo.getById(id))!, [testPage(bytes)]);
      await LibraryDocumentStamper().stamp(id, {
        'pages',
      }, actingDiverId: 'd-$member');
    }

    await repage('b', [7, 7]);
    await svc.sync('L', diverId: 'd-b');

    svc = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      owners: {'a', 'b'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repage('a', [8, 8]);
    await svc.sync('L', diverId: 'd-a');
    await svc.sync('L', diverId: 'd-a');
    expect((await DocumentRepository().getPages(id)).single.bytes, [8, 8]);

    svc = await libraryDevice(
      cloud,
      'b',
      file: fileOf('b'),
      owners: {'a', 'b'},
    );
    await svc.sync('L', diverId: 'd-b');
    expect((await DocumentRepository().getPages(id)).single.bytes, [8, 8]);
    // The losing scan's file stays for the grace period.
    expect(await transport().listPageFiles(), hasLength(3));
  });

  test("a page file not fetched keeps an editor's push from overwriting "
      'newer edits', () async {
    await seedTestLibrary(cloud, owners: {'a', 'b'});
    final id = await ownerShares(owners: {'a', 'b'});
    var b = await libraryDevice(
      cloud,
      'b',
      file: fileOf('b'),
      owners: {'a', 'b'},
    );
    await b.sync('L', diverId: 'd-b');
    // b's own edit, not yet sent.
    await LibraryDocumentStamper().stamp(id, {'title'}, actingDiverId: 'd-b');

    final a = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      owners: {'a', 'b'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final repo = DocumentRepository();
    await repo.save(
      (await repo.getById(id))!.copyWith(notes: 'North slipway'),
      [
        testPage([9, 9]),
      ],
    );
    await LibraryDocumentStamper().stamp(id, {
      'pages',
      'notes',
    }, actingDiverId: 'd-a');
    await a.sync('L', diverId: 'd-a');
    final t = transport();
    final newest = await t.readDocument((await t.listDocuments()).single.id);
    final newFile = newest.pageRefs.single.fileId;
    // b cannot fetch a's new scan yet.
    await t.deletePageFile((await t.findPageFile(newFile))!.id);

    b = await libraryDevice(cloud, 'b', file: fileOf('b'), owners: {'a', 'b'});
    await b.sync('L', diverId: 'd-b');
    final after = await t.readDocument((await t.listDocuments()).single.id);
    expect(after.fields['notes'], 'North slipway');
    expect(after.pageRefs.single.fileId, newFile);
    expect((await SharedLibraryStore().getDocumentState(id))!.dirty, isTrue);
  });

  test('a document of a deleted site is not shown nor read again', () async {
    await seedTestLibrary(cloud);
    final id = await ownerShares();
    final a = await libraryDevice(cloud, 'a', file: fileOf('a'));
    await SharedSitePublisher().deleteFromLibrary(siteId: 's1', diverId: 'd-a');
    await a.sync('L', diverId: 'd-a');

    final svc = await libraryDevice(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    expect(await DocumentRepository().getById(id), isNull);
    final state = (await SharedLibraryStore().getDocumentState(id))!;
    expect(state.remoteModifiedTime, isNotNull);
    expect(state.parked, isFalse);
    final r = await svc.sync('L', diverId: 'd-b');
    expect(r.pulled, 0);
    expect(
      (await SharedLibraryStore().getDocumentState(id))!.remoteModifiedTime,
      state.remoteModifiedTime,
    );
  });

  test(
    'undeleting a site brings its documents back with their pages',
    () async {
      await seedTestLibrary(cloud);
      final id = await ownerShares();
      var a = await libraryDevice(cloud, 'a', file: fileOf('a'));
      await SharedSitePublisher().deleteFromLibrary(
        siteId: 's1',
        diverId: 'd-a',
      );
      await a.sync('L', diverId: 'd-a');

      var b = await libraryDevice(cloud, 'b', file: fileOf('b'));
      await b.sync('L', diverId: 'd-b');
      expect(await DocumentRepository().getById(id), isNull);

      a = await libraryDevice(cloud, 'a', file: fileOf('a'));
      await SharedSitePublisher().undelete(siteId: 's1', diverId: 'd-a');
      await a.sync('L', diverId: 'd-a');

      b = await libraryDevice(cloud, 'b', file: fileOf('b'));
      await b.sync('L', diverId: 'd-b');
      expect((await DocumentRepository().getPages(id)).single.bytes, [1, 2, 3]);
    },
  );

  test('a parked document appears when its site arrives', () async {
    await seedTestLibrary(cloud);
    final id = await ownerShares();
    final siteFile = (await transport().listSites()).single;
    final siteBytes = await cloud.downloadFile(siteFile.id);
    await cloud.deleteFile(siteFile.id);

    final b = await libraryDevice(cloud, 'b', file: fileOf('b'));
    await b.sync('L', diverId: 'd-b');
    expect(await DocumentRepository().getById(id), isNull);
    expect((await SharedLibraryStore().getDocumentState(id))!.parked, isTrue);

    cloud.seedFile(siteFile.id, siteBytes);
    await b.sync('L', diverId: 'd-b');
    expect((await DocumentRepository().getById(id))!.title, 'Access');
  });

  test('GC deletes an old unreferenced page file and keeps the rest', () async {
    await seedTestLibrary(cloud);
    await ownerShares();
    final t = transport();
    await t.writePageFile('orphan', Uint8List.fromList([5]));
    final later = DateTime.now().add(const Duration(days: 31));
    final a = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      now: () => later,
    );
    await a.sync('L', diverId: 'd-a');
    final left = (await t.listPageFiles())
        .map(SharedLibraryTransport.pageFileIdOf)
        .toSet();
    expect(left, hasLength(1));
    expect(left, isNot(contains('orphan')));
  });

  test('GC reads an unchanged document record once, however many syncs '
      'find an old page file it may not collect', () async {
    final counting = _CountingCloud();
    cloud = counting;
    await seedTestLibrary(cloud);
    await ownerShares();
    // A document waiting for a site this device does not hold: its page is
    // old and held nowhere here, and its record keeps it.
    final t = transport();
    await t.writePageFile('kept', Uint8List.fromList([9]));
    await t.writeDocument(
      LibraryDocumentRecord(
        id: 'waiting',
        siteId: 's9',
        fields: {
          'type': 'map',
          'pages': [
            {
              'id': 'pw',
              'pageIndex': 0,
              'side': null,
              'fileName': 'w.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 1,
              'fileId': 'kept',
              'sha256': sha256Hex([9]),
            },
          ],
        },
      ),
    );
    final later = DateTime.now().add(const Duration(days: 31));
    final a = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      now: () => later,
    );
    await a.sync('L', diverId: 'd-a');
    final afterFirst = counting.documentDownloads;
    await a.sync('L', diverId: 'd-a');
    await a.sync('L', diverId: 'd-a');
    expect(counting.documentDownloads, afterFirst);
    expect(
      (await t.listPageFiles()).map(SharedLibraryTransport.pageFileIdOf),
      contains('kept'),
    );
  });

  test('GC keeps an unreferenced page file younger than 30 days', () async {
    await seedTestLibrary(cloud);
    await ownerShares();
    final t = transport();
    await t.writePageFile('orphan', Uint8List.fromList([5]));
    final a = await libraryDevice(
      cloud,
      'a',
      file: fileOf('a'),
      now: () => DateTime.now().add(const Duration(days: 29)),
    );
    await a.sync('L', diverId: 'd-a');
    expect(
      (await t.listPageFiles()).map(SharedLibraryTransport.pageFileIdOf),
      contains('orphan'),
    );
  });

  test('a document field signed by an unknown member is not applied', () async {
    await seedTestLibrary(cloud);
    final a = await libraryDevice(cloud, 'a', file: fileOf('a'));
    await addLibrarySite('s1', 'a');
    await a.sync('L', diverId: 'd-a');
    final t = transport();
    await t.writePageFile('f1', Uint8List.fromList([1]));
    final forged = await signOwnFields(
      LibraryDocumentRecord(
        id: 'forged',
        siteId: 's1',
        fields: {
          'type': 'map',
          'title': 'Forged',
          'pages': [
            {
              'id': 'p1',
              'pageIndex': 0,
              'side': null,
              'fileName': 'x.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 1,
              'fileId': 'f1',
              'sha256': sha256Hex([1]),
            },
          ],
        },
        clocks: {
          for (final f in ['type', 'title', 'pages'])
            f: FieldClock(
              hlc: Hlc(DateTime.now().millisecondsSinceEpoch, 0, 'z'),
              memberId: 'z',
            ),
        },
      ),
      libraryId: 'L',
      memberId: 'z',
      key: await testMemberKey('z'),
    );
    await t.writeDocument(forged);

    final b = await libraryDevice(cloud, 'b');
    await b.sync('L', diverId: 'd-b');
    expect(await DocumentRepository().getById('forged'), isNull);
  });

  test('a dirty document counts as local library work', () async {
    await seedTestLibrary(cloud);
    await libraryDevice(cloud, 'a');
    final store = SharedLibraryStore();
    expect(await store.hasLocalLibraryWork(), isFalse);
    await addLibrarySite('s1', 'a');
    await store.putSiteState(
      (await store.getSiteState('s1'))!.copyWith(dirty: false),
    );
    expect(await store.hasLocalLibraryWork(), isFalse);
    final id = await addSharedDocument('s1', 'a');
    expect(await store.hasLocalLibraryWork(), isTrue);
    expect((await store.getDocumentState(id))!.dirty, isTrue);
    expect(documentUploads(), 0);
  });

  test("a first pull lists the storage the same number of times however "
      'many documents it brings', () async {
    Future<int> listingsFor(int documents) async {
      cloud = FakeCloudStorageProvider();
      await seedTestLibrary(cloud);
      final a = await libraryDevice(cloud, 'a');
      await addLibrarySite('s1', 'a');
      for (var i = 0; i < documents; i++) {
        await addSharedDocument('s1', 'a', bytes: [i, 1], title: 'Doc $i');
      }
      await a.sync('L', diverId: 'd-a');
      final b = await libraryDevice(cloud, 'b');
      final before = cloud.operationLog.where((e) => e == 'list').length;
      await b.sync('L', diverId: 'd-b');
      return cloud.operationLog.where((e) => e == 'list').length - before;
    }

    final one = await listingsFor(1);
    final five = await listingsFor(5);
    expect(five, one);
  });

  test('a record refiled under another site is not merged', () async {
    await seedTestLibrary(cloud);
    final id = await ownerShares();
    final b = await libraryDevice(cloud, 'b', file: fileOf('b'));
    await b.sync('L', diverId: 'd-b');

    // The owner's key re-signs the record under another site.
    final t = transport();
    final file = (await t.listDocuments()).single;
    final current = await t.readDocument(file.id);
    final at = DateTime.now().add(const Duration(minutes: 1));
    final moved = await signOwnFields(
      LibraryDocumentRecord(
        id: id,
        siteId: 's9',
        fields: {...current.fields, 'title': 'Moved'},
        clocks: {
          for (final f in current.fields.keys)
            f: FieldClock(
              hlc: Hlc(at.millisecondsSinceEpoch, 0, 'a'),
              memberId: 'a',
            ),
        },
      ),
      libraryId: 'L',
      memberId: 'a',
      key: await testMemberKey('a'),
    );
    await t.writeDocument(moved);

    await libraryDevice(cloud, 'b', file: fileOf('b'));
    await b.sync('L', diverId: 'd-b');
    final doc = (await DocumentRepository().getById(id))!;
    expect(doc.title, 'Access');
    expect(doc.owner.id, 's1');
  });
}

/// Counts the downloads of document records (the fake keys files by name).
class _CountingCloud extends FakeCloudStorageProvider {
  int documentDownloads = 0;

  @override
  Future<Uint8List> downloadFile(String fileId) {
    if (fileId.startsWith('document-')) documentDownloads++;
    return super.downloadFile(fileId);
  }
}
