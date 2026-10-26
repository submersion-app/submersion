import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide ConnectedAccount;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import '../../support/fake_keychain_storage.dart';

/// An iCloud container whose files never finish downloading (the native 12 s
/// poll expires), as seen by the second device to attach while the first
/// device's marker is still coming down from iCloud.
class _UndownloadablePlatform extends DirectoryICloudMediaPlatform {
  _UndownloadablePlatform(super.root);

  @override
  Future<bool> ensureDownloaded(String path) async => false;
}

/// Never serves the marker, however often it is asked.
class _AlwaysTransientStore extends InMemoryMediaObjectStore {
  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    throw const MediaStoreException(
      'still downloading from iCloud: smv1/store.json',
      kind: MediaStoreErrorKind.transient,
    );
  }
}

ConnectedAccount _row(String id, AccountKind kind) => ConnectedAccount(
  id: id,
  kind: kind,
  label: kind == AccountKind.s3 ? 'dive-media @ minio' : kind.name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late MediaStoreCredentialsStore credentials;
  late MediaStoreAttachState attachState;
  late MediaStoresRepository storesRepository;
  late AppDatabase db;

  final config = S3Config(
    endpoint: 'https://minio.example.com',
    bucket: 'dive-media',
    prefix: 'submersion-media/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    credentials = MediaStoreCredentialsStore(storage: InMemoryKeychain());
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    storesRepository = MediaStoresRepository();
  });

  tearDown(tearDownTestDatabase);

  MediaStoreService service({List<Duration> backoff = const []}) =>
      MediaStoreService(
        credentials: credentials,
        attachState: attachState,
        storesRepository: storesRepository,
        mediaRepository: MediaRepository(),
        markerRetryBackoff: backoff,
      );

  test('attaching creates the marker, attaches, and announces the store '
      'with its account', () async {
    final store = InMemoryMediaObjectStore();

    final result = await service().attachToAccountRow(
      _row('s3-media', AccountKind.s3),
      store,
    );

    expect(result.createdNewStore, isTrue);
    expect(store.objects.containsKey('smv1/store.json'), isTrue);
    expect(await attachState.attachedStoreId(), result.storeId);
    expect(await attachState.attachedAccountId(), 's3-media');
    final active = (await storesRepository.getActive())!;
    expect(active.providerType, 's3');
    expect(active.displayHint, 'dive-media @ minio');
    expect(active.accountId, 's3-media');
  });

  test('attaching to a store that already has a marker adopts it', () async {
    final store = InMemoryMediaObjectStore();
    final row = _row('db-row', AccountKind.dropbox);
    final first = await service().attachToAccountRow(row, store);
    await service().disconnect();

    final second = await service().attachToAccountRow(row, store);

    expect(second.createdNewStore, isFalse);
    expect(second.storeId, first.storeId);
  });

  test(
    'an account with no usable store is refused, attaching nothing',
    () async {
      await expectLater(
        service().attachToAccountRow(_row('db-row', AccountKind.dropbox), null),
        throwsA(
          isA<MediaStoreException>().having(
            (e) => e.kind,
            'kind',
            MediaStoreErrorKind.auth,
          ),
        ),
      );
      expect(await attachState.attachedStoreId(), isNull);
    },
  );

  test('detaching clears the legacy keys and the attachment, and keeps the '
      'announcement', () async {
    await credentials.save(config);
    await service().attachToAccountRow(
      _row('s3-media', AccountKind.s3),
      InMemoryMediaObjectStore(),
    );

    await service().disconnect();

    expect(await credentials.load(), isNull);
    expect(await attachState.attachedStoreId(), isNull);
    expect(await storesRepository.getActive(), isNotNull);
  });

  // A store announced before descriptors recorded their account: the
  // attached device fills it in, so another device joins the right folder.
  test(
    'the attached account is recorded on a descriptor naming none',
    () async {
      final result = await service().attachToAccountRow(
        _row('s3-media', AccountKind.s3),
        InMemoryMediaObjectStore(),
      );
      await (db.update(db.mediaStores)
            ..where((t) => t.id.equals(result.storeId)))
          .write(const MediaStoresCompanion(accountId: Value(null)));
      final before = (await storesRepository.getById(result.storeId))!;

      await service().recordAttachedAccount();

      final after = (await storesRepository.getById(result.storeId))!;
      expect(before.accountId, isNull);
      expect(after.accountId, 's3-media');
    },
  );

  test('a recorded account is never overwritten', () async {
    final result = await service().attachToAccountRow(
      _row('s3-media', AccountKind.s3),
      InMemoryMediaObjectStore(),
    );
    await storesRepository.recordAccount(result.storeId, 'other');

    expect(
      (await storesRepository.getById(result.storeId))!.accountId,
      's3-media',
    );
  });

  // Issue #3482: stamps that name no store were made in the store the
  // library announced. Moving to another store claims them for it first,
  // or they would count as copies in the new one.
  group('unclaimed stamps', () {
    Future<String> stampedRow() async {
      final media = MediaRepository();
      final created = await media.createMedia(
        MediaItem(
          id: '',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: '/tmp/a.jpg',
          takenAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await media.stampRemoteUploaded(
        created.id,
        uploadedAt: DateTime.utc(2026),
      );
      return created.id;
    }

    Future<String?> storeOf(String id) async =>
        (await MediaRepository().getMediaById(id))!.remoteStoreId;

    test(
      'attaching to another store claims them for the one announced',
      () async {
        await storesRepository.upsertActive(
          storeId: 'store-a',
          providerType: 's3',
          displayHint: 'old @ minio',
        );
        final id = await stampedRow();

        final result = await service().attachToAccountRow(
          _row('db-row', AccountKind.dropbox),
          InMemoryMediaObjectStore(),
        );

        expect(result.storeId, isNot('store-a'));
        expect(await storeOf(id), 'store-a');
      },
    );

    test('rejoining the announced store claims nothing', () async {
      final store = InMemoryMediaObjectStore();
      final row = _row('db-row', AccountKind.dropbox);
      await service().attachToAccountRow(row, store);
      await service().disconnect();
      final id = await stampedRow();

      await service().attachToAccountRow(row, store);

      expect(await storeOf(id), isNull);
    });

    test('a refused attach claims nothing', () async {
      await storesRepository.upsertActive(
        storeId: 'store-a',
        providerType: 's3',
        displayHint: 'old @ minio',
      );
      final id = await stampedRow();

      await expectLater(
        service().attachToAccountRow(_row('db-row', AccountKind.dropbox), null),
        throwsA(isA<MediaStoreException>()),
      );

      expect(await storeOf(id), isNull);
    });
  });

  // Issue #1356: the phone attached while the Mac's store.json had not
  // finished downloading, minted its own store id over it, and the Mac's
  // every preflight failed against a marker it did not recognise.
  test('iCloud does not mint a new store over a marker that is still '
      'downloading', () async {
    final container = await Directory.systemTemp.createTemp('icloud_attach');
    addTearDown(() => container.delete(recursive: true));
    final marker =
        File(p.join(container.path, 'submersion-media', 'smv1', 'store.json'))
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '{"storeId":"store-from-the-mac","formatVersion":1,"createdAt":""}',
          );

    await expectLater(
      service().attachToAccountRow(
        _row('icloud-row', AccountKind.icloud),
        ICloudMediaObjectStore(platform: _UndownloadablePlatform(container)),
      ),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );

    expect(await attachState.attachedStoreId(), isNull);
    expect(
      jsonDecode(marker.readAsStringSync())['storeId'],
      'store-from-the-mac',
      reason: 'the marker the other device wrote must survive untouched',
    );
  });

  // Attaching is a foreground action the user is watching, and on iCloud the
  // container's copy of store.json may still be coming down. Refusing on the
  // first attempt would fail an attach that succeeds seconds later.
  test('a store that cannot serve the marker yet is retried, then '
      'attaches', () async {
    final store = InMemoryMediaObjectStore()
      ..failNextWith = const MediaStoreException(
        'still downloading from iCloud: smv1/store.json',
        kind: MediaStoreErrorKind.transient,
      );

    final result = await service(
      backoff: const [Duration.zero, Duration.zero],
    ).attachToAccountRow(_row('icloud-row', AccountKind.icloud), store);

    expect(result.storeId, isNotEmpty);
    expect(await attachState.attachedStoreId(), result.storeId);
  });

  test('a store that keeps refusing the marker gives up rather than '
      'attaching', () async {
    await expectLater(
      service(backoff: const [Duration.zero]).attachToAccountRow(
        _row('icloud-row', AccountKind.icloud),
        _AlwaysTransientStore(),
      ),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
    expect(await attachState.attachedStoreId(), isNull);
  });

  test('buildMediaObjectStore returns an S3 store for a config and null '
      'without one', () async {
    expect(
      await buildMediaObjectStore(CloudProviderType.s3, s3Config: config),
      isNotNull,
    );
    expect(
      await buildMediaObjectStore(CloudProviderType.s3),
      isNull,
      reason: 'no config means no S3 store',
    );
  });

  test('buildMediaObjectStore yields null for managed providers that are '
      'not authenticated in tests', () async {
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
