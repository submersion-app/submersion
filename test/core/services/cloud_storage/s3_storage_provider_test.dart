import 'dart:async';
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
  void Function(String region)? onRegionCorrected;

  void _assertOpen() {
    if (closed) throw const CloudStorageException('client closed');
  }

  @override
  Future<void> putObject(String key, Uint8List bytes) async {
    _assertOpen();
    calls.add('put:$key');
    objects[key] = bytes;
  }

  @override
  Future<Uint8List> getObject(String key) async {
    _assertOpen();
    calls.add('get:$key');
    final data = objects[key];
    if (data == null) throw CloudStorageException('File not found in S3: $key');
    return data;
  }

  @override
  Future<S3ObjectInfo?> headObject(String key) async {
    _assertOpen();
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
    _assertOpen();
    calls.add('delete:$key');
    objects.remove(key);
  }

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    _assertOpen();
    calls.add('list:$prefix');
    return listing;
  }

  @override
  void close() => closed = true;
}

class _GatedCredentialsStore implements S3CredentialsStore {
  _GatedCredentialsStore(this._gate);

  final Completer<void> _gate;
  bool gateNextLoad = true;
  S3Config? stored;

  @override
  Future<S3Config?> load() async {
    final value = stored; // capture BEFORE parking, like a real stale read
    if (gateNextLoad) {
      gateNextLoad = false;
      await _gate.future;
      return value;
    }
    return stored;
  }

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
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
      apiClientFactory: (config, {onRegionCorrected}) {
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

    test(
      'runs the read+write probe: list, put probe, get probe, delete probe',
      () async {
        store.stored = config();
        await provider.authenticate();
        final client = builtClients.single;
        expect(client.calls, [
          'list:submersion-sync/',
          'put:submersion-sync/.submersion-probe',
          'get:submersion-sync/.submersion-probe',
          'delete:submersion-sync/.submersion-probe',
        ]);
      },
    );

    test('authenticate closes its transient probe client', () async {
      store.stored = config();
      await provider.authenticate();
      expect(builtClients.single.closed, isTrue);
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
          apiClientFactory: (_, {onRegionCorrected}) => client,
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
      expect(
        await provider.createFolder('anything'),
        'submersion-sync/anything/',
      );
      expect(
        await provider.createFolder('Backups', parentFolderId: 'other/'),
        'other/Backups/',
      );
    });

    test('empty prefix keys at the bucket root', () async {
      store.stored = config().copyWith(prefix: '');
      expect(await provider.getOrCreateSyncFolder(), '');
      final result = await provider.uploadFile(
        Uint8List.fromList([1]),
        'f.json',
      );
      expect(result.fileId, 'f.json');
    });

    test('listFiles drops bare-prefix directory markers', () async {
      store.stored = config();
      final client = _FakeS3ApiClient(config());
      provider = S3StorageProvider(
        store: store,
        apiClientFactory: (_, {onRegionCorrected}) => client,
      );
      client.listing = [
        S3ObjectInfo(
          key: 'submersion-sync/',
          lastModified: DateTime.utc(2026, 6, 1),
          size: 0,
        ),
        S3ObjectInfo(
          key: 'submersion-sync/submersion_sync_a.json',
          lastModified: DateTime.utc(2026, 6, 2),
          size: 5,
        ),
      ];
      final files = await provider.listFiles();
      expect(files.map((f) => f.name), ['submersion_sync_a.json']);
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

    test('saveConfig and signOut close the cached client', () async {
      store.stored = config();
      await provider.uploadFile(Uint8List.fromList([1]), 'f.json');
      final first = builtClients.single;
      await provider.saveConfig(config().copyWith(bucket: 'b2'));
      expect(first.closed, isTrue);
      await provider.uploadFile(Uint8List.fromList([2]), 'g.json');
      final second = builtClients.last;
      await provider.signOut();
      expect(second.closed, isTrue);
    });

    test(
      'a saveConfig racing a config load does not re-pin stale state',
      () async {
        final gate = Completer<void>();
        final gatedStore = _GatedCredentialsStore(gate)..stored = config();
        provider = S3StorageProvider(
          store: gatedStore,
          apiClientFactory: (c, {onRegionCorrected}) {
            final client = _FakeS3ApiClient(c);
            builtClients.add(client);
            return client;
          },
        );
        final firstRead = provider.getUserEmail(); // parks on the gate
        gatedStore.gateNextLoad = false; // saves/loads after this are direct
        await provider.saveConfig(config().copyWith(bucket: 'new-bucket'));
        gate.complete(); // stale load resumes AFTER the invalidation
        await firstRead;
        expect(await provider.getUserEmail(), 'new-bucket @ nas.local');
      },
    );
  });

  group('region correction persistence', () {
    test(
      'persists a server-corrected region without dropping the client',
      () async {
        store.stored = config(); // region defaults to us-east-1
        void Function(String region)? captured;
        final client = _FakeS3ApiClient(config());
        final correcting = S3StorageProvider(
          store: store,
          apiClientFactory: (_, {onRegionCorrected}) {
            captured = onRegionCorrected;
            return client;
          },
        );

        await correcting.listFiles(); // builds the session client
        expect(captured, isNotNull);
        captured!('eu-west-1');
        await pumpEventQueue();

        expect(store.stored!.region, 'eu-west-1');
        expect(client.closed, isFalse); // live client keeps its connection
        expect(await correcting.listFiles(), isEmpty); // still usable
      },
    );

    test('testConnection forwards corrections to the caller and does not '
        'persist', () async {
      void Function(String region)? captured;
      final probing = S3StorageProvider(
        store: store,
        apiClientFactory: (c, {onRegionCorrected}) {
          captured = onRegionCorrected;
          return _FakeS3ApiClient(c);
        },
      );
      final reported = <String>[];

      await probing.testConnection(config(), onRegionCorrected: reported.add);
      captured!('auto');
      await pumpEventQueue();

      expect(reported, ['auto']);
      expect(store.stored, isNull); // unsaved probe never writes the store
    });
  });
}
