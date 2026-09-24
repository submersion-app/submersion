import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media_store/data/media_store_preflight.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

import '../../helpers/in_memory_media_object_store.dart';

/// The admission check the worker runs before every transfer (design spec
/// section 13): this device must still be attached to the store the runtime
/// was built for, and the bucket must still carry that store's marker.
void main() {
  late MediaStoreAttachState attachState;
  late InMemoryMediaObjectStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    store = InMemoryMediaObjectStore();
  });

  void writeMarker(String storeId) {
    store.objects[StoreKeys.markerKey] = utf8.encode(
      jsonEncode({'storeId': storeId, 'formatVersion': 1, 'createdAt': ''}),
    );
  }

  Future<void> attach(String storeId) =>
      attachState.setAttached(storeId, providerType: CloudProviderType.icloud);

  test('passes when the container marker matches the attached store', () async {
    await attach('a');
    writeMarker('a');
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    expect(await preflight(), isTrue);
  });

  test('suspends once this device has detached', () async {
    await attach('a');
    writeMarker('a');
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    await attachState.clear();
    expect(await preflight(), isFalse);
  });

  test('suspends when the attachment changed under the runtime', () async {
    await attach('a');
    writeMarker('c');
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    await attach('c');
    expect(await preflight(), isFalse);
  });

  test('suspends on a foreign marker rather than adopting it', () async {
    await attach('a');
    writeMarker('b');
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    expect(await preflight(), isFalse);
    expect(
      await attachState.attachedStoreId(),
      'a',
      reason:
          'the marker a wiped or repointed store holds is the user\'s '
          'call to adopt, not the drain loop\'s (spec section 13)',
    );
  });

  test('suspends on a missing marker', () async {
    await attach('a');
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    expect(await preflight(), isFalse);
  });

  test('a marker read that fails propagates for the worker to '
      'classify', () async {
    await attach('a');
    store.failNextWith = const MediaStoreException(
      'still downloading: smv1/store.json',
      kind: MediaStoreErrorKind.transient,
    );
    final preflight = MediaStorePreflight(
      attachState: attachState,
      store: store,
      attachedStoreId: 'a',
    );
    await expectLater(preflight(), throwsA(isA<MediaStoreException>()));
  });

  // The worker names each refusal to the user (spec 7.1), and a marker
  // mismatch is remembered so the pending-setup card can offer a reconnect
  // without a runtime.
  group('check', () {
    MediaStorePreflight preflightFor(String attachedStoreId) =>
        MediaStorePreflight(
          attachState: attachState,
          store: store,
          attachedStoreId: attachedStoreId,
        );

    test('a detached device answers detached', () async {
      writeMarker('a');
      expect(await preflightFor('a').check(), MediaTransferHoldKind.detached);
    });

    test('another attachment answers detached', () async {
      await attach('c');
      writeMarker('c');
      expect(await preflightFor('a').check(), MediaTransferHoldKind.detached);
    });

    test('a foreign marker is a mismatch, and is remembered', () async {
      await attach('a');
      writeMarker('b');

      expect(
        await preflightFor('a').check(),
        MediaTransferHoldKind.markerMismatch,
      );
      expect(await attachState.hasMarkerMismatch(), isTrue);
    });

    test('a missing marker is a mismatch', () async {
      await attach('a');

      expect(
        await preflightFor('a').check(),
        MediaTransferHoldKind.markerMismatch,
      );
      expect(await attachState.hasMarkerMismatch(), isTrue);
    });

    test('a matching marker admits and forgets a mismatch', () async {
      await attach('a');
      await attachState.setMarkerMismatch(true);
      writeMarker('a');

      expect(await preflightFor('a').check(), isNull);
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });

    test('an unreadable marker remembers nothing', () async {
      await attach('a');
      store.failNextWith = const MediaStoreException(
        'still downloading: smv1/store.json',
        kind: MediaStoreErrorKind.transient,
      );

      await expectLater(
        preflightFor('a').check(),
        throwsA(isA<MediaStoreException>()),
      );
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });

    // The marker read is a network call. A reconnect landing during it
    // clears the flag for the new store, and this stale check must not set
    // it again, or the new store shows a reconnect card it does not need.
    test('a reconnect during the marker read is not answered for', () async {
      await attach('a');
      final reconnecting = _ReconnectsDuringRead(() => attach('c'));
      reconnecting.objects[StoreKeys.markerKey] = utf8.encode(
        jsonEncode({'storeId': 'b', 'formatVersion': 1, 'createdAt': ''}),
      );

      final verdict = await MediaStorePreflight(
        attachState: attachState,
        store: reconnecting,
        attachedStoreId: 'a',
      ).check();

      expect(verdict, MediaTransferHoldKind.detached);
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });

    // Reconnecting to the SAME store clears the flag as well, and a check
    // that began before it must not set it again: comparing store ids alone
    // would not notice.
    test('a same-store reconnect during the marker read is not answered '
        'for', () async {
      await attach('a');
      final reconnecting = _ReconnectsDuringRead(() => attach('a'));
      reconnecting.objects[StoreKeys.markerKey] = utf8.encode(
        jsonEncode({'storeId': 'b', 'formatVersion': 1, 'createdAt': ''}),
      );

      final verdict = await MediaStorePreflight(
        attachState: attachState,
        store: reconnecting,
        attachedStoreId: 'a',
      ).check();

      expect(verdict, MediaTransferHoldKind.detached);
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });

    test('a mismatch is written only within the attachment it was read '
        'in', () async {
      await attach('a');
      final before = await attachState.attachGeneration();
      await attach('a');

      await attachState.setMarkerMismatch(true, withinGeneration: before);
      expect(await attachState.hasMarkerMismatch(), isFalse);

      final now = await attachState.attachGeneration();
      await attachState.setMarkerMismatch(true, withinGeneration: now);
      expect(await attachState.hasMarkerMismatch(), isTrue);
    });

    // Reconnecting is the fix, so any attach change forgets the mismatch.
    test('attaching or detaching forgets a mismatch', () async {
      await attachState.setMarkerMismatch(true);
      await attach('a');
      expect(await attachState.hasMarkerMismatch(), isFalse);

      await attachState.setMarkerMismatch(true);
      await attachState.clear();
      expect(await attachState.hasMarkerMismatch(), isFalse);
    });
  });
}

/// Runs [onRead] while the marker is being fetched, the way a user's
/// reconnect can land during that network call.
class _ReconnectsDuringRead extends InMemoryMediaObjectStore {
  _ReconnectsDuringRead(this.onRead);
  final Future<void> Function() onRead;

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    await onRead();
    return super.getFile(key, destination, onProgress: onProgress);
  }
}
