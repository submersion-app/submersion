import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryTransport t;

  setUp(() {
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'site-sync');
  });

  const doc = LibraryDocumentRecord(
    id: 'doc1',
    siteId: 's1',
    fields: {'title': 'Access'},
  );
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  int pageUploads(String fileId) =>
      cloud.operationLog.where((e) => e == 'upload:$fileId.bin').length;

  test('a document round trips and is listed by id', () async {
    await t.writeDocument(doc);
    final files = await t.listDocuments();
    expect(files.map(SharedLibraryTransport.documentIdOf), ['doc1']);
    final back = await t.readDocument(files.single.id);
    expect(back.siteId, 's1');
    expect(back.fields['title'], 'Access');
    expect(await t.listSites(), isEmpty);
  });

  test('writeDocument refuses an unsafe id', () async {
    await expectLater(
      t.writeDocument(const LibraryDocumentRecord(id: '../x', siteId: 's1')),
      throwsArgumentError,
    );
  });

  test('a page file written twice is uploaded once', () async {
    await t.writePageFile('f1', bytes);
    await t.writePageFile('f1', bytes);
    expect(pageUploads('f1'), 1);
    final files = await t.listPageFiles();
    expect(files.map(SharedLibraryTransport.pageFileIdOf), ['f1']);
    expect(await t.readPageFile(files.single.id), bytes);
  });

  test('an encrypted library seals page files and opens them', () async {
    t
      ..cipher = await LibraryCipher.generate()
      ..encrypting = true;
    await t.writePageFile('f1', bytes);
    await t.writeDocument(doc);
    final page = (await t.listPageFiles()).single;
    expect(LibraryCipher.isSealed(await cloud.downloadFile(page.id)), isTrue);
    expect(await t.readPageFile(page.id), bytes);
    final file = (await t.listDocuments()).single;
    expect(LibraryCipher.isSealed(await cloud.downloadFile(file.id)), isTrue);
    expect((await t.readDocument(file.id)).fields['title'], 'Access');
  });

  test(
    'sealableFiles lists documents and pages; snapshot keeps no page',
    () async {
      await t.writeDocument(doc);
      await t.writePageFile('f1', bytes);
      final sealable = await t.sealableFiles();
      expect(sealable.keys, contains('documents/document-doc1.json'));
      expect(sealable.keys, contains('pages/f1.bin'));
      final withoutPages = await t.sealableFiles(withPages: false);
      expect(withoutPages.keys, isNot(contains('pages/f1.bin')));
      final snapshot = await t.snapshot();
      expect(snapshot.keys, contains('documents/document-doc1.json'));
      expect(snapshot.keys.where((k) => k.startsWith('pages/')), isEmpty);
    },
  );

  test('measureBytes counts documents and pages', () async {
    final before = (await t.measureBytes()).bytes;
    await t.writePageFile('f1', bytes);
    expect((await t.measureBytes()).bytes, before + bytes.length);
  });

  test('raw writes and deletes reach the new folders', () async {
    await t.writeRaw('pages/f2.bin', bytes);
    await t.writeRaw(
      'documents/document-doc2.json',
      LibraryDocumentRecord.encode(
        const LibraryDocumentRecord(id: 'doc2', siteId: 's1'),
      ),
    );
    expect((await t.listPageFiles()).map(SharedLibraryTransport.pageFileIdOf), [
      'f2',
    ]);
    expect(await t.listDocuments(), hasLength(1));
    await t.deleteRaw('pages/f2.bin');
    expect(await t.listPageFiles(), isEmpty);
  });

  test('deletePageFile removes one page file', () async {
    await t.writePageFile('f1', bytes);
    await t.deletePageFile((await t.listPageFiles()).single.id);
    expect(await t.listPageFiles(), isEmpty);
  });

  test('a new library cannot start with documents or pages, an existing '
      'one there still opens', () async {
    expect(SharedLibraryTransport.startsReserved('documents/club'), isTrue);
    expect(SharedLibraryTransport.startsReserved('pages'), isTrue);
    final existing = SharedLibraryTransport(cloud, prefix: 'documents');
    await existing.writeManifest({'id': 'L', 'formatVersion': 2});
    expect(await existing.readManifest(), isNotNull);
  });
}
