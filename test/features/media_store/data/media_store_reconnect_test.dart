import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_store_reconnect.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';

import '../../../helpers/in_memory_media_object_store.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

/// Counts backfills instead of reading the library.
class _CountingBackfill extends MediaBackfillService {
  _CountingBackfill()
    : super(
        mediaRepository: MediaRepository(),
        queue: MediaTransferQueueRepository(),
      );

  int calls = 0;

  @override
  Future<int> enqueueAll() async {
    calls++;
    return 3;
  }
}

/// Runs [onGetFile] once before serving a read, to change state mid-read.
class _HookedStore extends InMemoryMediaObjectStore {
  Future<void> Function()? onGetFile;

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    final hook = onGetFile;
    onGetFile = null;
    await hook?.call();
    return super.getFile(key, destination, onProgress: onProgress);
  }
}

/// Answers a fixed count of items kept only in each store.
class _HeldOnlyRepository extends MediaRepository {
  _HeldOnlyRepository(this.held);

  final Map<String, int> held;

  @override
  Future<int> countHeldOnlyInStore(String storeId) async => held[storeId] ?? 0;
}

ConnectedAccount _row(String id) => ConnectedAccount(
  id: id,
  kind: AccountKind.dropbox,
  label: 'Dropbox',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void _writeMarker(InMemoryMediaObjectStore store, String storeId) {
  store.objects['smv1/store.json'] = utf8.encode(
    jsonEncode({'storeId': storeId, 'formatVersion': 1, 'createdAt': ''}),
  );
}

void main() {
  late MediaStoreAttachState attachState;
  late MediaStoresRepository stores;
  late MediaStoreService service;
  late _CountingBackfill backfill;
  late _HookedStore store;
  late Map<String, ConnectedAccount> accounts;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    stores = MediaStoresRepository();
    service = MediaStoreService(
      credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      attachState: attachState,
      storesRepository: stores,
      mediaRepository: MediaRepository(),
      markerRetryBackoff: const [],
    );
    backfill = _CountingBackfill();
    store = _HookedStore();
    accounts = {'db-row': _row('db-row')};
  });

  tearDown(tearDownTestDatabase);

  MediaStoreReconnect reconnect({
    MediaObjectStore? Function()? storeFor,
    MediaRepository? mediaRepository,
  }) => MediaStoreReconnect(
    attachState: attachState,
    service: service,
    backfill: backfill,
    stores: stores,
    mediaRepository: mediaRepository ?? MediaRepository(),
    accountById: (id) async => accounts[id],
    storeFor: (_) async => storeFor == null ? store : storeFor(),
  );

  /// Attaches this device to [storeId] through 'db-row', announced, with
  /// the preflight's mismatch flag set.
  Future<void> attachedWithMismatch(String storeId) async {
    await attachState.setAttached(
      storeId,
      providerType: _row('db-row').kind.cloudProviderType!,
      accountId: 'db-row',
    );
    await stores.upsertActive(
      storeId: storeId,
      providerType: 'dropbox',
      displayHint: 'Dropbox',
      accountId: 'db-row',
    );
    await attachState.setMarkerMismatch(true);
  }

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
    await media.stampRemoteUploaded(created.id, uploadedAt: DateTime.utc(2026));
    return created.id;
  }

  group('inspect', () {
    test('a detached device has nothing to reconnect', () async {
      expect(await reconnect().inspect(), isA<ReconnectDetached>());
    });

    test('a marker that matches again clears the mismatch', () async {
      await attachedWithMismatch('store-a');
      _writeMarker(store, 'store-a');

      expect(await reconnect().inspect(), isA<ReconnectResolved>());
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });

    test('another store the library knows is offered as one to join', () async {
      await attachedWithMismatch('store-a');
      await stores.upsertActive(
        storeId: 'store-b',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
      );
      _writeMarker(store, 'store-b');

      final found = await reconnect().inspect();

      expect(found, isA<ReconnectOtherStore>());
      found as ReconnectOtherStore;
      expect(found.storeId, 'store-b');
      expect(found.knownToLibrary, isTrue);
      expect(await attachState.hasMarkerMismatch(), isTrue);
    });

    test('another store the library has no record of says so', () async {
      await attachedWithMismatch('store-a');
      _writeMarker(store, 'store-x');

      final found = await reconnect().inspect() as ReconnectOtherStore;

      expect(found.knownToLibrary, isFalse);
    });

    test('an attach change during the read is answered for the new '
        'attachment', () async {
      await attachedWithMismatch('store-a');
      _writeMarker(store, 'store-b');
      store.onGetFile = () async {
        // Another flow reattaches to the store the folder holds.
        await attachState.setAttached(
          'store-b',
          providerType: _row('db-row').kind.cloudProviderType!,
          accountId: 'db-row',
        );
      };

      expect(await reconnect().inspect(), isA<ReconnectResolved>());
    });

    test('a store with no marker is offered for starting again', () async {
      await attachedWithMismatch('store-a');

      expect(await reconnect().inspect(), isA<ReconnectNoMarker>());
    });

    test('counts what only the attached store holds', () async {
      await attachedWithMismatch('store-a');
      final repo = _HeldOnlyRepository({'store-a': 4, 'store-b': 9});

      final none = await reconnect(mediaRepository: repo).inspect();
      _writeMarker(store, 'store-b');
      final other = await reconnect(mediaRepository: repo).inspect();

      expect(none.heldOnlyInCloud, 4);
      expect(other.heldOnlyInCloud, 4);
    });

    // Copilot review: read() answers null for a malformed marker too, and
    // starting again over it would mint over a marker other devices use.
    test('a marker that is there but malformed is unreadable, not '
        'missing', () async {
      await attachedWithMismatch('store-a');
      store.objects['smv1/store.json'] = utf8.encode('{not json');

      final found = await reconnect().inspect();

      expect(found, isA<ReconnectUnreadable>());
    });

    test('a marker that cannot be read reports the error', () async {
      await attachedWithMismatch('store-a');
      store.failNextWith = const MediaStoreException(
        'network down',
        kind: MediaStoreErrorKind.transient,
      );

      final found = await reconnect().inspect();

      expect(found, isA<ReconnectUnreadable>());
      expect((found as ReconnectUnreadable).message, contains('network down'));
    });

    test(
      'an attachment with no account needs the account chosen again',
      () async {
        await attachState.setAttached(
          'store-a',
          providerType: _row('db-row').kind.cloudProviderType!,
        );

        expect(await reconnect().inspect(), isA<ReconnectNeedsAccount>());
      },
    );

    test(
      'an account whose row is gone needs the account chosen again',
      () async {
        await attachedWithMismatch('store-a');
        accounts.clear();

        expect(await reconnect().inspect(), isA<ReconnectNeedsAccount>());
      },
    );

    test(
      'an account with no keys here needs the account chosen again',
      () async {
        await attachedWithMismatch('store-a');

        expect(
          await reconnect(storeFor: () => null).inspect(),
          isA<ReconnectNeedsAccount>(),
        );
      },
    );
  });

  group('reconnect', () {
    test('adopting attaches to the store there now, announces it, claims '
        "this device's old stamps for the old store and queues every "
        'photo', () async {
      await attachedWithMismatch('store-a');
      final id = await stampedRow();
      _writeMarker(store, 'store-b');

      final done = await reconnect().reconnect();

      expect(done.result.storeId, 'store-b');
      expect(done.result.createdNewStore, isFalse);
      expect(done.queued, 3);
      expect(await attachState.attachedStoreId(), 'store-b');
      expect(await attachState.hasMarkerMismatch(), isFalse);
      expect((await stores.getActive())!.id, 'store-b');
      expect(
        (await MediaRepository().getMediaById(id))!.remoteStoreId,
        'store-a',
      );
      expect(backfill.calls, 1);
    });

    test('starting again mints a new store where there is no marker', () async {
      await attachedWithMismatch('store-a');

      final done = await reconnect().reconnect();

      expect(done.result.createdNewStore, isTrue);
      expect(done.result.storeId, isNot('store-a'));
      expect(store.objects.containsKey('smv1/store.json'), isTrue);
      expect(await attachState.attachedStoreId(), done.result.storeId);
    });

    test('starting again over a malformed marker is refused, leaving it '
        'in place', () async {
      await attachedWithMismatch('store-a');
      final malformed = utf8.encode('{"storeId": ""}');
      store.objects['smv1/store.json'] = malformed;

      await expectLater(
        reconnect().reconnect(),
        throwsA(isA<MediaStoreException>()),
      );
      expect(store.objects['smv1/store.json'], malformed);
      expect(await attachState.attachedStoreId(), 'store-a');
      expect(backfill.calls, 0);
    });

    // Copilot review: an attach change landing during the reconnect's own
    // marker check must not be claimed for or overwritten.
    test('an attach change during the reconnect is refused, leaving the '
        'newer attachment', () async {
      await attachedWithMismatch('store-a');
      _writeMarker(store, 'store-b');
      store.onGetFile = () async {
        await attachState.setAttached(
          'store-c',
          providerType: _row('db-row').kind.cloudProviderType!,
          accountId: 'db-row',
        );
      };

      await expectLater(
        reconnect().reconnect(),
        throwsA(isA<MediaStoreException>()),
      );
      expect(await attachState.attachedStoreId(), 'store-c');
      expect(backfill.calls, 0);
    });

    test('an account with no keys is refused with nothing changed', () async {
      await attachedWithMismatch('store-a');

      await expectLater(
        reconnect(storeFor: () => null).reconnect(),
        throwsA(isA<MediaStoreAccountUnusable>()),
      );
      expect(await attachState.attachedStoreId(), 'store-a');
      expect(backfill.calls, 0);
    });
  });

  test('detaching clears the attachment', () async {
    await attachedWithMismatch('store-a');

    await reconnect().detach();

    expect(await attachState.attachedStoreId(), isNull);
  });
}
