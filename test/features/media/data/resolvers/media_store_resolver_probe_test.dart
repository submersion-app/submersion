import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../../helpers/in_memory_media_object_store.dart';

/// Counts HEADs, and can fail the next one.
class _CountingStore extends InMemoryMediaObjectStore {
  final heads = <String>[];
  Exception? failNextHead;

  /// When set, every HEAD waits on it: a stalled provider.
  Completer<void>? hold;
  var inFlight = 0;
  var maxInFlight = 0;

  @override
  Future<StoreObjectInfo?> head(String key) async {
    heads.add(key);
    final fail = failNextHead;
    if (fail != null) {
      failNextHead = null;
      throw fail;
    }
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final wait = hold;
      if (wait != null) await wait.future;
      return await super.head(key);
    } finally {
      inFlight--;
    }
  }
}

/// A foreign row can reach a device before its upload stamps do, or lose
/// them in a merge. The store the device is attached to may hold its bytes
/// anyway, and the probe is how the tile finds out (media sync program spec
/// 7.2).
void main() {
  late Directory root;
  late LocalCacheDatabase cacheDb;
  late _CountingStore store;
  late MediaStoreResolver resolver;
  final bytes = List<int>.generate(512, (i) => (i * 7) % 251);
  final hash = sha256.convert(bytes).toString();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('store_probe');
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    store = _CountingStore();
    resolver = MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
  });

  tearDown(() async {
    resolver.dispose();
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// A row with no upload stamps at all, as a peer's row arrives before its
  /// stamps do.
  MediaItem unstamped({
    MediaType mediaType = MediaType.photo,
    String? contentHash,
    bool withHash = true,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: MediaSourceType.localFile,
    localPath: p.join('elsewhere', 'reef.jpg'),
    originalFilename: 'reef.jpg',
    contentHash: withHash ? (contentHash ?? hash) : null,
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  String originalKey() =>
      StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor('reef.jpg'));

  test('an unstamped row whose thumb is in the store is served', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: true,
    );

    expect(served, isA<FileData>());
  });

  test('with no thumb, a thumbnail is served from the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: true,
    );

    expect(served, isA<FileData>());
    expect(store.heads, [StoreKeys.thumbKey(hash), originalKey()]);
  });

  test('a full view probes and serves the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: false,
    );

    expect(served, isA<FileData>());
    expect(store.heads, [originalKey()]);
  });

  // A grid redraws its tiles constantly. Absence is remembered, so a row
  // the store does not hold costs one HEAD per session, not one per frame.
  test('an absent object is asked about once', () async {
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );

    expect(store.heads, [
      originalKey(),
      StoreKeys.renditionKey(hash, ext: 'jpg'),
    ], reason: 'each tier asked once, then remembered');
  });

  // A failed HEAD says nothing about the object (offline, a blip), so it
  // is not remembered as absent.
  test('a probe that failed is asked again', () async {
    store.objects[originalKey()] = bytes;
    store.failNextHead = const MediaStoreException(
      'offline',
      kind: MediaStoreErrorKind.transient,
    );

    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isA<FileData>(),
    );
  });

  // A video's original is a video: it can only draw as the movie
  // placeholder, so a thumbnail never costs its download, or its HEAD.
  test('a video thumbnail never falls back to the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(mediaType: MediaType.video),
      thumbnail: true,
    );

    expect(served, isNull);
    expect(store.heads, [StoreKeys.thumbKey(hash)]);
  });

  test('a row with no content hash is not probed', () async {
    final served = await resolver.tryResolveProbed(
      unstamped(withHash: false),
      thumbnail: true,
    );

    expect(served, isNull);
    expect(store.heads, isEmpty);
  });

  // Some uploads keep only the compressed rendition; with its stamp lost,
  // the rendition is still in the store.
  test('a row whose store copy is only the rendition is served', () async {
    store.objects[StoreKeys.renditionKey(hash, ext: 'jpg')] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: false,
    );

    expect(served, isA<FileData>());
  });

  // A found tier whose fetch fails (a broken GET, bytes that do not match
  // the hash) is not the end: the tiers after it are asked about too, as
  // tryResolveRemote falls through for a stamped row.
  test(
    'a found original that fails to fetch falls back to the rendition',
    () async {
      store.objects[originalKey()] = List<int>.filled(16, 1);
      store.objects[StoreKeys.renditionKey(hash, ext: 'jpg')] = bytes;

      final served = await resolver.tryResolveProbed(
        unstamped(),
        thumbnail: false,
      );

      expect((served! as FileData).file.readAsBytesSync(), bytes);
      expect(store.heads, [
        originalKey(),
        StoreKeys.renditionKey(hash, ext: 'jpg'),
      ]);
    },
  );

  // A rendition can be overwritten in place (a re-upload at another level).
  // With the stamp lost, the store's own modification time is the only
  // version there is, and a copy cached before it must not be served.
  test('a probed rendition does not serve an older cached copy', () async {
    final renditionKey = StoreKeys.renditionKey(hash, ext: 'jpg');
    final staleBytes = List<int>.filled(64, 7);
    final staging = File(p.join(root.path, 'old.jpg'))
      ..writeAsBytesSync(staleBytes);
    await MediaCacheStore(database: cacheDb, root: root).put(
      hash,
      MediaCacheKind.rendition,
      staging,
      sourceVersion: DateTime(2026, 7, 1).millisecondsSinceEpoch,
      extension: 'jpg',
    );
    store.objects[renditionKey] = bytes;
    store.modified[renditionKey] = DateTime(2026, 8, 1);

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: false,
    );

    expect((served! as FileData).file.readAsBytesSync(), bytes);
  });

  // The original's key carries its extension, and one content hash can be
  // stored under more than one: the answer for one key says nothing about
  // another.
  test('probe answers are per store key, not per content hash', () async {
    MediaItem named(String filename) => MediaItem(
      id: filename,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: p.join('elsewhere', filename),
      originalFilename: filename,
      contentHash: hash,
      takenAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    store.objects[StoreKeys.objectKey(
          hash,
          extension: StoreKeys.extensionFor('reef.bin'),
        )] =
        bytes;

    expect(
      await resolver.tryResolveProbed(named('reef.jpg'), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveProbed(named('reef.bin'), thumbnail: false),
      isA<FileData>(),
    );
  });

  // A stalled provider must not hold a tile forever: the probe gives up
  // after its budget, says nothing, and asks again next time.
  test('a probe that stalls gives up and is asked again', () async {
    final stalling = MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
      probeBudget: const Duration(milliseconds: 20),
    );
    addTearDown(stalling.dispose);
    store.objects[originalKey()] = bytes;
    store.hold = Completer<void>();

    expect(
      await stalling.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );

    store.hold!.complete();
    store.hold = null;
    expect(
      await stalling.tryResolveProbed(unstamped(), thumbnail: false),
      isA<FileData>(),
    );
  });

  // No slot would ever open, or every HEAD would give up before it began:
  // either way every tile would wait on nothing.
  test('a resolver that could never probe is refused', () {
    MediaStoreResolver build({
      int maxConcurrentProbes = 4,
      Duration probeBudget = const Duration(seconds: 1),
    }) => MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
      maxConcurrentProbes: maxConcurrentProbes,
      probeBudget: probeBudget,
    );

    expect(() => build(maxConcurrentProbes: 0), throwsA(isA<AssertionError>()));
    expect(() => build(probeBudget: Duration.zero), throwsAssertionError);
  });

  // A timeout stops the waiting, not the request. The slot stays taken
  // until the stalled HEAD itself settles, so a dead endpoint never has
  // more than the cap in flight; a probe that cannot get a slot within the
  // budget gives up rather than holding its tile.
  test('a timed-out HEAD keeps its slot until it settles', () async {
    final single = MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
      maxConcurrentProbes: 1,
      probeBudget: const Duration(milliseconds: 20),
    );
    addTearDown(single.dispose);
    store.hold = Completer<void>();
    MediaItem other(int i) =>
        unstamped(contentHash: sha256.convert([i]).toString());

    expect(await single.tryResolveProbed(other(1), thumbnail: false), isNull);
    expect(await single.tryResolveProbed(other(2), thumbnail: false), isNull);
    expect(store.heads, hasLength(1), reason: 'the stalled HEAD holds it');

    store.hold!.complete();
    store.hold = null;
    await pumpEventQueue();
    await single.tryResolveProbed(other(2), thumbnail: false);
    expect(store.heads, hasLength(3), reason: 'freed once it settled');
  });

  // A store runtime torn down mid-scroll must not leave tiles waiting for a
  // slot that will never open.
  test('disposing lets go of probes waiting for a slot', () async {
    final single = MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
      maxConcurrentProbes: 1,
    );
    store.hold = Completer<void>();
    final running = single.tryResolveProbed(
      unstamped(contentHash: sha256.convert([1]).toString()),
      thumbnail: false,
    );
    final waiting = single.tryResolveProbed(
      unstamped(contentHash: sha256.convert([2]).toString()),
      thumbnail: false,
    );
    await pumpEventQueue();

    single.dispose();

    expect(await waiting, isNull);
    expect(store.heads, hasLength(1), reason: 'the waiter never ran a HEAD');
    store.hold!.complete();
    await running;
  });

  // A grid of foreign rows probes as it scrolls; the HEADs are capped the
  // way the fetch gate caps fetches.
  test('probes run a few at a time', () async {
    store.hold = Completer<void>();
    final probes = [
      for (var i = 0; i < 10; i++)
        resolver.tryResolveProbed(
          unstamped(contentHash: sha256.convert([i]).toString()),
          thumbnail: false,
        ),
    ];
    await pumpEventQueue();
    expect(store.maxInFlight, lessThanOrEqualTo(4));

    store.hold!.complete();
    await Future.wait(probes);
    expect(
      store.heads,
      hasLength(20),
      reason: 'every row still asked: its original, then its rendition',
    );
  });
}
