import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import '../../support/fake_keychain_storage.dart';

/// Serves corrupted bytes on download: the probe write succeeds but the
/// read-back does not match what was written.
class _CorruptingStore extends InMemoryMediaObjectStore {
  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    await destination.writeAsBytes('garbage'.codeUnits, flush: true);
  }
}

void main() {
  late InMemoryMediaObjectStore fakeStore;
  late MediaStoreCredentialsStore credentials;
  late MediaStoreAttachState attachState;
  late MediaStoresRepository storesRepository;
  late MediaStoreService service;

  final config = S3Config(
    endpoint: 'https://minio.example.com',
    bucket: 'dive-media',
    prefix: 'submersion-media/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    fakeStore = InMemoryMediaObjectStore();
    credentials = MediaStoreCredentialsStore(storage: InMemoryKeychain());
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    storesRepository = MediaStoresRepository();
    service = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      storeFactory: (_) => fakeStore,
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('connectS3 creates the marker, attaches, and writes the '
      'descriptor', () async {
    final result = await service.connectS3(config);
    expect(result.createdNewStore, isTrue);
    expect(fakeStore.objects.containsKey('smv1/store.json'), isTrue);
    expect(await attachState.attachedStoreId(), result.storeId);
    final active = await storesRepository.getActive();
    expect(active!.providerType, 's3');
    expect(active.displayHint, contains('dive-media'));
    expect(await credentials.load(), isNotNull);
  });

  test('connectS3 against an existing store adopts its storeId', () async {
    final first = await service.connectS3(config);
    await service.disconnect();
    final second = await service.connectS3(config);
    expect(second.createdNewStore, isFalse);
    expect(second.storeId, first.storeId);
  });

  test('testConnection round-trips a probe object and cleans up', () async {
    await service.testConnection(config);
    expect(fakeStore.objects.keys.where((k) => k.contains('probe')), isEmpty);
  });

  test('testConnection fails when the read-back returns different '
      'bytes', () async {
    final corrupting = _CorruptingStore();
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      storeFactory: (_) => corrupting,
    );
    await expectLater(
      svc.testConnection(config),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.message,
          'message',
          contains('read-back'),
        ),
      ),
    );
    expect(
      corrupting.objects.keys.where((k) => k.contains('probe')),
      isEmpty,
      reason: 'probe cleanup still runs on failure',
    );
  });

  test('invalid config throws before touching the store', () async {
    final bad = S3Config(
      endpoint: 'https://minio.example.com',
      bucket: '',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
    );
    await expectLater(
      service.connectS3(bad),
      throwsA(isA<MediaStoreException>()),
    );
    expect(fakeStore.objects, isEmpty);
  });

  test('disconnect clears credentials and attach state', () async {
    await service.connectS3(config);
    await service.disconnect();
    expect(await credentials.load(), isNull);
    expect(await attachState.attachedStoreId(), isNull);
  });

  test('connectDropbox ensures the marker and records provider '
      'type', () async {
    final dropboxFake = InMemoryMediaObjectStore();
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      dropboxStoreFactory: () async => dropboxFake,
    );
    final result = await svc.connectDropbox();
    expect(result.createdNewStore, isTrue);
    expect(dropboxFake.objects.containsKey('smv1/store.json'), isTrue);
    expect(await attachState.attachedProviderType(), CloudProviderType.dropbox);
    final active = await storesRepository.getActive();
    expect(active!.providerType, 'dropbox');
    expect(
      await credentials.load(),
      isNull,
      reason: 'managed providers never touch the S3 keychain entry',
    );
  });

  test('connectICloud ensures the marker and records provider '
      'type', () async {
    final icloudFake = InMemoryMediaObjectStore();
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      icloudStoreFactory: () async => icloudFake,
    );
    final result = await svc.connectICloud();
    expect(icloudFake.objects.containsKey('smv1/store.json'), isTrue);
    expect(await attachState.attachedProviderType(), CloudProviderType.icloud);
    expect((await storesRepository.getActive())!.displayHint, 'iCloud');
    expect(result.storeId, isNotEmpty);
  });

  test('connect on an unavailable managed provider throws auth', () async {
    final svc = MediaStoreService(
      credentials: credentials,
      attachState: attachState,
      storesRepository: storesRepository,
      googleDriveStoreFactory: () async => null,
    );
    await expectLater(
      svc.connectGoogleDrive(),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.auth,
        ),
      ),
    );
    expect(await attachState.attachedStoreId(), isNull);
  });

  test('buildMediaObjectStore returns an S3 store for a config and null '
      'without one', () async {
    final store = await buildMediaObjectStore(
      CloudProviderType.s3,
      s3Config: config,
    );
    expect(store, isNotNull);
    expect(
      await buildMediaObjectStore(CloudProviderType.s3),
      isNull,
      reason: 'no config means no S3 store',
    );
  });

  test('buildMediaObjectStore yields null for managed providers that are '
      'not authenticated in tests', () async {
    // Dropbox/Drive/iCloud all lack live credentials in a unit test, so
    // each arm resolves to an unusable (null) store rather than throwing.
    for (final type in [
      CloudProviderType.dropbox,
      CloudProviderType.googledrive,
      CloudProviderType.icloud,
    ]) {
      MediaObjectStore? store;
      try {
        store = await buildMediaObjectStore(type);
      } catch (_) {
        // A platform-channel absence is an acceptable "not available".
        store = null;
      }
      expect(store, isNull, reason: '$type is unauthenticated here');
    }
  });
}
