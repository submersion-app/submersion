import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'fake_cloud_storage_provider.dart';

void main() {
  Uint8List u(String s) => Uint8List.fromList(utf8.encode(s));

  test('upload, list by pattern, download, delete', () async {
    final p = FakeCloudStorageProvider();
    final folder = await p.getOrCreateSyncFolder();

    final up = await p.uploadFile(
      u('hello'),
      'ssv1.dev.cs.000000000001.json',
      folderId: folder,
    );
    await p.uploadFile(u('ignore'), 'other.txt', folderId: folder);

    final listed = await p.listFiles(folderId: folder, namePattern: 'ssv1.');
    expect(listed.map((f) => f.name), ['ssv1.dev.cs.000000000001.json']);

    expect(utf8.decode(await p.downloadFile(up.fileId)), 'hello');
    expect(await p.fileExists(up.fileId), isTrue);

    await p.deleteFile(up.fileId);
    expect(await p.fileExists(up.fileId), isFalse);
  });

  test('uploadFile overwrites the same name (upsert)', () async {
    final p = FakeCloudStorageProvider();
    final folder = await p.getOrCreateSyncFolder();
    await p.uploadFile(u('v1'), 'm.json', folderId: folder);
    final up2 = await p.uploadFile(u('v2'), 'm.json', folderId: folder);
    expect(utf8.decode(await p.downloadFile(up2.fileId)), 'v2');
    final listed = await p.listFiles(folderId: folder, namePattern: 'm.json');
    expect(listed.length, 1);
  });

  test('downloadFile throws for a missing file', () async {
    final p = FakeCloudStorageProvider();
    expect(() => p.downloadFile('sync/nope'), throwsA(isA<Exception>()));
  });
}
