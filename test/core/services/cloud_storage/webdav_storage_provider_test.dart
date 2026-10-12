import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

import '../../../helpers/fake_webdav_server.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late FakeWebDavServer server;
  late WebDavCredentialsStore store;
  late WebDavStorageProvider provider;
  late Directory tmp;

  final config = WebDavConfig(
    serverUrl: 'https://dav.test/dav',
    username: 'alice',
    password: 'secret',
  );

  WebDavClient factory(WebDavConfig c) =>
      WebDavClient(c, httpClient: server.client, backoff: (_) => Duration.zero);

  setUp(() async {
    server = FakeWebDavServer();
    store = WebDavCredentialsStore(storage: InMemoryKeychain());
    provider = WebDavStorageProvider(store: store, clientFactory: factory);
    tmp = await Directory.systemTemp.createTemp('webdav_provider_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('identity and presence-only authentication state', () async {
    expect(provider.providerId, 'webdav');
    expect(await provider.isAuthenticated(), isFalse);
    await provider.saveConfig(config);
    expect(await provider.isAuthenticated(), isTrue);
    expect(await provider.getUserEmail(), 'alice @ dav.test');
    await provider.signOut();
    expect(await provider.isAuthenticated(), isFalse);
  });

  test('testConnection creates the folder and cleans up the probe', () async {
    final result = await provider.testConnection(config);
    expect(server.collections, contains('/dav/Submersion'));
    expect(
      server.files.keys.where((k) => k.contains('.submersion-probe')),
      isEmpty,
    );
    expect(result.toJson(), config.toJson());
    expect(await store.load(), isNull, reason: 'testConnection never saves');
  });

  test('an invalid config fails before any request', () async {
    await expectLater(
      provider.testConnection(config.copyWith(password: '')),
      throwsA(
        isA<WebDavException>().having(
          (e) => e.code,
          'code',
          WebDavErrorCode.invalidConfig,
        ),
      ),
    );
    expect(server.captured, isEmpty);
  });

  test('upload, list, info, download, delete under the sync folder', () async {
    await provider.saveConfig(config);
    final folder = await provider.getOrCreateSyncFolder();
    expect(folder, 'Submersion');
    final up = await provider.uploadFile(
      Uint8List.fromList(utf8.encode('x')),
      'submersion_sync_a.json',
      folderId: folder,
    );
    expect(up.fileId, 'Submersion/submersion_sync_a.json');
    final list = await provider.listFiles(
      folderId: folder,
      namePattern: 'sync_',
    );
    expect(list.single.name, 'submersion_sync_a.json');
    expect((await provider.getFileInfo(up.fileId))!.sizeBytes, 1);
    expect(utf8.decode(await provider.downloadFile(up.fileId)), 'x');
    await provider.deleteFile(up.fileId);
    expect(await provider.fileExists(up.fileId), isFalse);
  });

  test('listFiles on a folder deleted on the server is empty', () async {
    await provider.saveConfig(config);
    expect(await provider.listFiles(), isEmpty);
  });

  test('createFolder nests under the sync folder', () async {
    await provider.saveConfig(config);
    expect(await provider.createFolder('Backups'), 'Submersion/Backups');
    expect(server.collections, contains('/dav/Submersion/Backups'));
  });

  test('uploadFileFromPath and downloadToFile stream through disk', () async {
    await provider.saveConfig(config);
    final src = File(p.join(tmp.path, 'backup.db'));
    await src.writeAsBytes(List<int>.generate(200000, (i) => i % 7));
    final up = await provider.uploadFileFromPath(
      src.path,
      'b.db',
      folderId: 'Submersion/Backups',
    );
    final dest = p.join(tmp.path, 'back.db');
    await provider.downloadToFile(up.fileId, dest);
    expect(await File(dest).readAsBytes(), await src.readAsBytes());
  });

  test('a large backup to a per-user files address is chunked', () async {
    server = FakeWebDavServer(
      seedCollections: const [
        '/remote.php/dav/files/alice',
        '/remote.php/dav/uploads/alice',
      ],
    );
    await provider.saveConfig(
      WebDavConfig(
        serverUrl: 'https://dav.test/remote.php/dav/files/alice',
        username: 'alice',
        password: 'secret',
      ),
    );
    final src = File(p.join(tmp.path, 'big.db'));
    await src.writeAsBytes(Uint8List(ChunkedUpload.chunkBytes + 5));
    await provider.uploadFileFromPath(src.path, 'big.db');
    expect(server.count('MOVE'), 1);
    expect(
      server.files['/remote.php/dav/files/alice/Submersion/big.db']!.length,
      ChunkedUpload.chunkBytes + 5,
    );
  });

  test('authenticate without a config explains what to do', () async {
    await expectLater(
      provider.authenticate(),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('the probe never touches a file the user already has', () async {
    server.seedFile('/dav/Submersion/.submersion-probe', [1, 2, 3]);
    await provider.testConnection(config);
    expect(server.files['/dav/Submersion/.submersion-probe'], [1, 2, 3]);
    expect(
      server.files.keys.where((k) => k.contains('submersion-probe-')),
      isEmpty,
    );
  });

  test('a probe whose read-back fails still removes its file', () async {
    server.methodStatuses['GET'] = 403;
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<WebDavException>()),
    );
    expect(
      server.files.keys.where((k) => k.contains('submersion-probe')),
      isEmpty,
    );
  });
}
