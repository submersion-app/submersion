import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

const _hash =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

MediaItem _video({bool original = true, bool rendition = false}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2026, 6, 9),
  createdAt: DateTime.utc(2026, 6, 9),
  updatedAt: DateTime.utc(2026, 6, 9),
  originalFilename: 'clip.MOV',
  contentHash: _hash,
  remoteUploadedAt: original ? DateTime.utc(2026, 6, 9) : null,
  remoteCompressedUploadedAt: rendition ? DateTime.utc(2026, 6, 9) : null,
);

/// An S3-like store: every link names the key and a running count.
class _LinkStore implements MediaObjectStore, DirectLinkStore {
  final List<String> asked = [];
  final List<bool> fresh = [];

  @override
  Future<DirectLink> directLink(String key, {bool fresh = false}) async {
    asked.add(key);
    this.fresh.add(fresh);
    return DirectLink(
      url: Uri.parse('https://s3.test/$key?n=${asked.length}'),
      expiresAt: DateTime.utc(2026, 6, 9, 18),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A WebDAV-like store, read a range at a time.
class _RangeStore implements MediaObjectStore, RangeReadStore {
  @override
  Future<StoreObjectInfo?> head(String key) async => StoreObjectInfo(
    key: key,
    sizeBytes: 10,
    lastModified: DateTime.utc(2026),
  );

  @override
  Future<Uint8List> readRange(
    String key, {
    required int start,
    required int endInclusive,
  }) async => Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A store that holds [held] and answers a HEAD for each, recording asks.
class _HeldStore implements MediaObjectStore {
  _HeldStore(this.held, {this.fails = false});

  final Map<String, DateTime> held;
  final bool fails;
  final List<String> heads = [];

  @override
  Future<StoreObjectInfo?> head(String key) async {
    heads.add(key);
    if (fails) {
      throw const MediaStoreException(
        'unreachable',
        kind: MediaStoreErrorKind.transient,
      );
    }
    final at = held[key];
    return at == null ? null : StoreObjectInfo(key: key, lastModified: at);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlainStore implements MediaObjectStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final originalKey = StoreKeys.objectKey(_hash, extension: 'mov');
  final renditionKey = StoreKeys.renditionKey(_hash, ext: 'mp4');

  test('original then rendition, each opening a fresh link', () async {
    final store = _LinkStore();
    final plan = planStoreVideo(
      _video(rendition: true),
      store: store,
      relay: null,
    );
    expect(plan, isA<StreamPlayback>());
    final candidates = (plan as StreamPlayback).candidates;
    expect(candidates.map((c) => c.tier), [
      ServedTier.original,
      ServedTier.rendition,
    ]);
    expect(store.asked, isEmpty, reason: 'links are made only when opened');
    final first = await candidates.first.open();
    final again = await candidates.first.open();
    expect(first.path, '/$originalKey');
    expect(first, isNot(again));
    expect((await candidates.last.open()).path, '/$renditionKey');
  });

  test('a rendition alone plays the rendition', () {
    final plan = planStoreVideo(
      _video(original: false, rendition: true),
      store: _LinkStore(),
      relay: null,
    );
    expect(
      (plan as StreamPlayback).candidates.single.tier,
      ServedTier.rendition,
    );
  });

  test(
    'a range store streams through the relay and releases its ticket',
    () async {
      var n = 0;
      final relay = MediaStreamRelay(
        base: Uri.parse('https://app.test/sub/'),
        newTicket: () => 't${++n}',
      );
      final plan = planStoreVideo(_video(), store: _RangeStore(), relay: relay);
      final candidate = (plan as StreamPlayback).candidates.single;
      final url = await candidate.open();
      expect(url, Uri.parse('https://app.test/sub/media-stream/t1'));
      expect((await relay.answer('t1', 'bytes=0-')).status, isNot(404));
      candidate.close(url);
      expect((await relay.answer('t1', 'bytes=0-')).status, 404);
    },
  );

  test('a range store without a relay needs a normal window', () {
    final plan = planStoreVideo(_video(), store: _RangeStore(), relay: null);
    expect((plan as NoPlayback).reason, NoPlaybackReason.needsNormalWindow);
  });

  test('a row with no hash is not found', () {
    final plan = planStoreVideo(
      MediaItem(
        id: 'm2',
        mediaType: MediaType.video,
        takenAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        remoteUploadedAt: DateTime.utc(2026),
      ),
      store: _LinkStore(),
      relay: null,
    );
    expect((plan as NoPlayback).reason, NoPlaybackReason.notFound);
  });

  test('a row with nothing uploaded is not found', () {
    final plan = planStoreVideo(
      _video(original: false),
      store: _LinkStore(),
      relay: null,
    );
    expect((plan as NoPlayback).reason, NoPlaybackReason.notFound);
  });

  test('a store that streams neither way is not found', () {
    final plan = planStoreVideo(_video(), store: _PlainStore(), relay: null);
    expect((plan as NoPlayback).reason, NoPlaybackReason.notFound);
  });

  test(
    'a candidate asks for a fresh link on every open after its first',
    () async {
      final store = _LinkStore();
      final plan = planStoreVideo(_video(), store: store, relay: null);
      final candidate = (plan as StreamPlayback).candidates.single;
      await candidate.open();
      await candidate.open();
      expect(store.fresh, [false, true]);
    },
  );

  group('withProbedStamps', () {
    test('stamps what the store holds for a row with no stamps', () async {
      // Its upload facts have not reached this device, but the store has
      // the rendition: the tile shows its poster, so it should play too.
      final at = DateTime.utc(2026, 7, 1);
      final store = _HeldStore({renditionKey: at});
      final probed = await withProbedStamps(
        _video(original: false),
        store: store,
      );
      expect(store.heads, unorderedEquals([originalKey, renditionKey]));
      expect(probed.remoteUploadedAt, isNull);
      expect(probed.remoteCompressedUploadedAt, at);
    });

    test('leaves a row with a stamp as it is, asking nothing', () async {
      final store = _HeldStore({});
      final item = _video(original: true);
      expect(await withProbedStamps(item, store: store), same(item));
      expect(store.heads, isEmpty);
    });

    test('a store that cannot say leaves the row unstamped', () async {
      final store = _HeldStore({}, fails: true);
      final probed = await withProbedStamps(
        _video(original: false),
        store: store,
      );
      expect(probed.remoteUploadedAt, isNull);
      expect(probed.remoteCompressedUploadedAt, isNull);
    });
  });
}
