import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';

import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';

import '../../../helpers/in_memory_media_object_store.dart';

/// A store whose marker is present but unreadable until something makes the
/// adapter go and look, which is how an iCloud container behaves before its
/// metadata has reached this device.
class _InvisibleUntilListed extends InMemoryMediaObjectStore {
  bool listed = false;

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) {
    listed = true;
    return super.list(keyPrefix);
  }

  @override
  Future<Uint8List> getBytes(String key) async {
    if (!listed) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    return super.getBytes(key);
  }
}

/// A store a browser reaches: it can hand over bytes but has no file to
/// download into or upload from (issue #4193).
class _NoFiles extends InMemoryMediaObjectStore {
  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) => throw UnsupportedError('no files in a browser');

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) => throw UnsupportedError('no files in a browser');
}

void main() {
  test('ensure writes a marker when absent and is stable afterwards', () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);

    final first = await markers.ensure();
    expect(first.created, isTrue);
    expect(first.marker.storeId, isNotEmpty);
    expect(first.marker.formatVersion, 1);
    expect(store.objects.containsKey(StoreKeys.markerKey), isTrue);

    final second = await markers.ensure();
    expect(second.created, isFalse);
    expect(second.marker.storeId, first.marker.storeId);
  });

  test('read returns null when no marker exists and parses an existing '
      'one', () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);
    expect(await markers.read(), isNull);
    await markers.ensure();
    final marker = await markers.read();
    expect(marker, isNotNull);
    expect(marker!.storeId, isNotEmpty);
  });

  test('corrupt marker json reads as null', () async {
    final store = InMemoryMediaObjectStore();
    store.objects[StoreKeys.markerKey] = 'not json'.codeUnits;
    final markers = StoreMarkerStore(store: store);
    expect(await markers.read(), isNull);
  });

  // Issue #1356: read() cannot tell "no marker" from "cannot see it yet", and
  // minting on the second answer overwrites the marker another device wrote,
  // splitting one store in two.
  test('a marker only a listing can see is adopted, not overwritten', () async {
    final store = _InvisibleUntilListed();
    await StoreMarkerStore(store: InMemoryMediaObjectStore()).ensure();
    store.objects[StoreKeys.markerKey] = utf8.encode(
      jsonEncode({
        'storeId': 'store-from-the-other-device',
        'formatVersion': 1,
        'createdAt': '',
      }),
    );

    final ensured = await StoreMarkerStore(store: store).ensure();

    expect(ensured.created, isFalse);
    expect(ensured.marker.storeId, 'store-from-the-other-device');
    expect(
      jsonDecode(utf8.decode(store.objects[StoreKeys.markerKey]!))['storeId'],
      'store-from-the-other-device',
      reason: 'the other device\'s marker must survive untouched',
    );
  });

  test('a store with no marker at all still mints one', () async {
    final store = _InvisibleUntilListed();
    final ensured = await StoreMarkerStore(store: store).ensure();
    expect(ensured.created, isTrue);
    expect(store.objects.containsKey(StoreKeys.markerKey), isTrue);
  });

  group('a device that only reads the store (issue #4193)', () {
    Future<void> seed(InMemoryMediaObjectStore store) async {
      store.objects[StoreKeys.markerKey] = utf8.encode(
        jsonEncode({
          'storeId': 'store-from-a-phone',
          'formatVersion': 1,
          'createdAt': '',
        }),
      );
    }

    test('reads the marker in memory, with no file to download into', () async {
      final store = _NoFiles();
      await seed(store);

      final marker = await StoreMarkerStore(store: store).read();

      expect(marker?.storeId, 'store-from-a-phone');
    });

    test('joins the marker that is there', () async {
      final store = _NoFiles();
      await seed(store);

      final ensured = await StoreMarkerStore(
        store: store,
        canWrite: false,
      ).ensure();

      expect(ensured.created, isFalse);
      expect(ensured.marker.storeId, 'store-from-a-phone');
    });

    test(
      'refuses to start a store where there is none, writing nothing',
      () async {
        final store = _NoFiles();

        await expectLater(
          StoreMarkerStore(store: store, canWrite: false).ensure(),
          throwsA(isA<MediaStoreReadOnly>()),
        );
        expect(store.objects, isEmpty);
      },
    );
  });
}
