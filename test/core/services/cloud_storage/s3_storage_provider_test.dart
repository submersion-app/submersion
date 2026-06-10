import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
}

/// Records calls; serves canned objects.
class _FakeS3ApiClient implements S3ApiClient {
  _FakeS3ApiClient(this.config);

  final S3Config config;
  final List<String> calls = [];
  final Map<String, Uint8List> objects = {};
  List<S3ObjectInfo> listing = [];
  bool closed = false;

  @override
  Future<void> putObject(String key, Uint8List bytes) async {
    calls.add('put:$key');
    objects[key] = bytes;
  }

  @override
  Future<Uint8List> getObject(String key) async {
    calls.add('get:$key');
    final data = objects[key];
    if (data == null) throw CloudStorageException('File not found in S3: $key');
    return data;
  }

  @override
  Future<S3ObjectInfo?> headObject(String key) async {
    calls.add('head:$key');
    if (!objects.containsKey(key)) return null;
    return S3ObjectInfo(
      key: key,
      lastModified: DateTime.utc(2026, 6, 9),
      size: objects[key]!.length,
    );
  }

  @override
  Future<void> deleteObject(String key) async {
    calls.add('delete:$key');
    objects.remove(key);
  }

  @override
  Future<List<S3ObjectInfo>> listObjects({String prefix = ''}) async {
    calls.add('list:$prefix');
    return listing;
  }

  @override
  void close() => closed = true;
}

void main() {
  late _MemoryCredentialsStore store;
  late List<_FakeS3ApiClient> builtClients;
  late S3StorageProvider provider;

  S3Config config() => S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dive-sync',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  setUp(() {
    store = _MemoryCredentialsStore();
    builtClients = [];
    provider = S3StorageProvider(
      store: store,
      apiClientFactory: (config) {
        final client = _FakeS3ApiClient(config);
        builtClients.add(client);
        return client;
      },
    );
  });

  group('identity and availability', () {
    test('providerId and providerName', () {
      expect(provider.providerId, 's3');
      expect(provider.providerName, 'S3-Compatible Storage');
    });

    test('isAvailable is true everywhere', () async {
      expect(await provider.isAvailable(), isTrue);
    });

    test('isAuthenticated reflects config presence', () async {
      expect(await provider.isAuthenticated(), isFalse);
      store.stored = config();
      expect(await provider.isAuthenticated(), isTrue);
    });

    test('getUserEmail is the bucket @ host label', () async {
      store.stored = config();
      expect(await provider.getUserEmail(), 'dive-sync @ nas.local');
    });

    test('getUserEmail is null when unconfigured', () async {
      expect(await provider.getUserEmail(), isNull);
    });
  });

  group('authenticate', () {
    test('throws a clear error when unconfigured', () {
      expect(
        () => provider.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('not configured'),
          ),
        ),
      );
    });

    test('runs the read+write probe: list, put probe, delete probe', () async {
      store.stored = config();
      await provider.authenticate();
      final client = builtClients.single;
      expect(client.calls, [
        'list:submersion-sync/',
        'put:submersion-sync/.submersion-probe',
        'delete:submersion-sync/.submersion-probe',
      ]);
    });
  });

  group('testConnection', () {
    test('rejects an invalid config before any network call', () async {
      await expectLater(
        provider.testConnection(config().copyWith(bucket: '')),
        throwsA(isA<CloudStorageException>()),
      );
      expect(builtClients, isEmpty);
    });

    test('probes the given config without persisting it', () async {
      await provider.testConnection(config());
      expect(store.stored, isNull);
      expect(builtClients.single.closed, isTrue);
      expect(builtClients.single.calls.first, startsWith('list:'));
    });
  });

  group('file operations', () {
    setUp(() => store.stored = config());

    test('uploadFile keys under the folderId and returns the key', () async {
      final result = await provider.uploadFile(
        Uint8List.fromList([1]),
        'submersion_sync_dev-a.json',
        folderId: 'submersion-sync/',
      );
      expect(result.fileId, 'submersion-sync/submersion_sync_dev-a.json');
      expect(
        builtClients.single.calls,
        contains('put:submersion-sync/submersion_sync_dev-a.json'),
      );
    });

    test('uploadFile falls back to the configured prefix', () async {
      final result = await provider.uploadFile(
        Uint8List.fromList([1]),
        'f.json',
      );
      expect(result.fileId, 'submersion-sync/f.json');
    });

    test('downloadFile fetches by full key', () async {
      store.stored = config();
      await provider.uploadFile(Uint8List.fromList([7]), 'f.json');
      final bytes = await provider.downloadFile('submersion-sync/f.json');
      expect(bytes, [7]);
    });

    test(
      'listFiles maps keys to basenames and filters by namePattern',
      () async {
        final client = _FakeS3ApiClient(config());
        provider = S3StorageProvider(
          store: store,
          apiClientFactory: (_) => client,
        );
        client.listing = [
          S3ObjectInfo(
            key: 'submersion-sync/submersion_sync_dev-a.json',
            lastModified: DateTime.utc(2026, 6, 1),
            size: 10,
          ),
          S3ObjectInfo(
            key: 'submersion-sync/unrelated.txt',
            lastModified: DateTime.utc(2026, 6, 2),
            size: 5,
          ),
        ];
        final files = await provider.listFiles(namePattern: 'submersion_sync');
        expect(files, hasLength(1));
        expect(files.single.id, 'submersion-sync/submersion_sync_dev-a.json');
        expect(files.single.name, 'submersion_sync_dev-a.json');
        expect(files.single.sizeBytes, 10);
      },
    );

    test('getFileInfo returns null for a missing key', () async {
      expect(await provider.getFileInfo('submersion-sync/nope.json'), isNull);
    });

    test('fileExists mirrors headObject', () async {
      await provider.uploadFile(Uint8List.fromList([1]), 'f.json');
      expect(await provider.fileExists('submersion-sync/f.json'), isTrue);
      expect(await provider.fileExists('submersion-sync/nope.json'), isFalse);
    });

    test('folders resolve to the configured prefix', () async {
      expect(await provider.getOrCreateSyncFolder(), 'submersion-sync/');
      expect(await provider.createFolder('anything'), 'submersion-sync/');
    });
  });

  group('config lifecycle', () {
    test('signOut clears the store and authentication', () async {
      store.stored = config();
      expect(await provider.isAuthenticated(), isTrue);
      await provider.signOut();
      expect(store.stored, isNull);
      expect(await provider.isAuthenticated(), isFalse);
    });

    test('saveConfig invalidates the cached client', () async {
      store.stored = config();
      await provider.uploadFile(Uint8List.fromList([1]), 'f.json');
      expect(builtClients, hasLength(1));

      await provider.saveConfig(config().copyWith(bucket: 'other-bucket'));
      await provider.uploadFile(Uint8List.fromList([2]), 'g.json');

      expect(builtClients, hasLength(2));
      expect(builtClients.last.config.bucket, 'other-bucket');
    });
  });
}
