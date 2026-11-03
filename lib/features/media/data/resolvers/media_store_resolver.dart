import 'dart:async';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/disk_media_store_fetches.dart';
import 'package:submersion/features/media/data/resolvers/media_bytes_memory.dart';
import 'package:submersion/features/media/data/resolvers/media_fetch_gate.dart';
import 'package:submersion/features/media/data/resolvers/media_store_fetches.dart';
import 'package:submersion/features/media/data/resolvers/memory_media_store_fetches.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Store-backed fallback resolution (design spec section 10). Deliberately
/// NOT a MediaSourceResolver and never registered under a MediaSourceType:
/// rows keep their native source type, so disconnecting the store degrades
/// every row to exactly the pre-store behavior.
class MediaStoreResolver {
  /// The installed apps' resolver: each tier is cached on disk in [cache].
  MediaStoreResolver({
    required MediaObjectStore store,
    required MediaCacheStore cache,
    MediaFetchGate? gate,
    Duration probeBudget = kMediaFetchSlotBudget,
    int maxConcurrentProbes = 4,
  }) : this._(
         store: store,
         fetches: DiskMediaStoreFetches(store: store, cache: cache),
         gate: gate,
         probeBudget: probeBudget,
         maxConcurrentProbes: maxConcurrentProbes,
       );

  /// A browser's resolver (issue #4121): each tier is kept in [memory] and
  /// served as bytes, since a page has no file to download into.
  MediaStoreResolver.inMemory({
    required MediaObjectStore store,
    MediaBytesMemory? memory,
    MediaFetchGate? gate,
    Duration probeBudget = kMediaFetchSlotBudget,
    int maxConcurrentProbes = 4,
  }) : this._(
         store: store,
         fetches: MemoryMediaStoreFetches(
           store: store,
           memory: memory ?? MediaBytesMemory(),
         ),
         gate: gate,
         probeBudget: probeBudget,
         maxConcurrentProbes: maxConcurrentProbes,
       );

  MediaStoreResolver._({
    required MediaObjectStore store,
    required MediaStoreFetches fetches,
    MediaFetchGate? gate,
    required Duration probeBudget,
    required int maxConcurrentProbes,
  }) : assert(maxConcurrentProbes > 0),
       assert(probeBudget > Duration.zero),
       _store = store,
       _fetches = fetches,
       _gate = gate ?? MediaFetchGate(),
       _probeBudget = probeBudget,
       _maxConcurrentProbes = maxConcurrentProbes;

  /// Answers the probes' HEADs; [_fetches] downloads.
  final MediaObjectStore _store;
  final MediaStoreFetches _fetches;

  /// Caps and coalesces the fetches below. One per resolver, and the resolver
  /// is built once per store runtime, so every display surface sharing that
  /// runtime shares the budget -- which is the point: the grid, an open
  /// viewer and the dive-detail strip are all pulling from the same endpoint.
  final MediaFetchGate _gate;
  final _log = LoggerService.forClass(
    MediaStoreResolver,
    category: LogCategory.media,
  );

  /// Probe answers per store key for the life of this resolver (one store
  /// runtime). Keyed by the full key, not the hash: an original's key
  /// carries its extension, and one content hash can be stored under more
  /// than one. A HEAD that failed or ran out of time is not recorded, since
  /// it says nothing about the object.
  final Map<String, _ProbeAnswer> _probes = {};

  /// Probes in flight, so tiles asking about the same object share one HEAD.
  final Map<String, Future<_ProbeAnswer?>> _probing = {};

  /// How long one probe HEAD may take before the tile gives up on it, and
  /// how many run at once. Probes bypass [_gate] (it carries fetch results,
  /// not answers), so they carry the same two bounds of their own: a grid
  /// scrolling through foreign rows must not burst unbounded HEADs at the
  /// endpoint, and a stalled provider must not hold a tile forever.
  final Duration _probeBudget;
  final int _maxConcurrentProbes;
  var _probesRunning = 0;
  final _probeWaiters = <Completer<void>>[];
  bool _disposed = false;

  /// Serves [item] from the store when its synced upload stamps are missing
  /// but the store may hold it anyway (media sync program spec 7.2): a stamp
  /// that is late, or was lost. Each tier the request needs is HEADed once
  /// and remembered, found or absent, so a grid of such rows costs one HEAD
  /// per row and tier for the life of this resolver.
  ///
  /// The tiers are tried in [tryResolveRemote]'s order, the thumb (for a
  /// thumbnail), the original, then the compressed rendition, one at a time:
  /// a found tier is served through [tryResolveRemote] with only that tier
  /// stamped, and only if its fetch fails (a broken GET, bytes that do not
  /// match the hash) is the next tier asked about. So a row whose first tier
  /// serves costs one HEAD, and a found tier that cannot be read still falls
  /// through as a stamped row would. A video thumbnail never falls back past
  /// its thumb: its original and rendition are both video.
  ///
  /// A found tier is treated as stamped at the store's own modification
  /// time, the only version a probe has: the rendition's cache checks
  /// freshness against it, so a copy cached before the object was
  /// overwritten is not served. Read-only: nothing is written back, since
  /// the stamps are the uploading device's facts (decided 2026-09-23).
  Future<MediaSourceData?> tryResolveProbed(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null) return null;
    final isVideo = item.mediaType == MediaType.video;
    final unstamped = item.copyWith(
      remoteThumbUploadedAt: null,
      remoteUploadedAt: null,
      remoteCompressedUploadedAt: null,
    );
    final tiers = <(String, MediaItem Function(DateTime))>[
      if (thumbnail)
        (
          StoreKeys.thumbKey(hash),
          (at) => unstamped.copyWith(remoteThumbUploadedAt: at),
        ),
      if (!thumbnail || !isVideo) ...[
        (
          StoreKeys.objectKey(
            hash,
            extension: StoreKeys.extensionFor(item.originalFilename),
          ),
          (at) => unstamped.copyWith(remoteUploadedAt: at),
        ),
        (
          StoreKeys.renditionKey(
            hash,
            ext: StoreKeys.renditionExtension(isVideo: isVideo),
          ),
          (at) => unstamped.copyWith(remoteCompressedUploadedAt: at),
        ),
      ],
    ];
    for (final (key, stampedAt) in tiers) {
      final modified = await _probe(key);
      if (modified == null) continue;
      final served = await tryResolveRemote(
        stampedAt(modified),
        thumbnail: thumbnail,
      );
      if (served != null) return served;
    }
    return null;
  }

  /// When the store last modified [key], or null when it does not hold it
  /// or could not say.
  Future<DateTime?> _probe(String key) async {
    final known = _probes[key];
    if (known != null) return known.modified;
    // A block body on purpose: remove() returns the entry, which is this very
    // future, and whenComplete waits on a future its callback returns, so
    // `=> _probing.remove(...)` would wait on itself forever.
    final answer = await (_probing[key] ??= _head(key).whenComplete(() {
      _probing.remove(key);
    }));
    if (answer == null) return null;
    _probes[key] = answer;
    return answer.modified;
  }

  /// The store's answer for [key], or null when it could not say (the HEAD
  /// failed, ran out of its budget, found no free slot within it, or this
  /// resolver was disposed).
  Future<_ProbeAnswer?> _head(String key) async {
    if (!await _acquireProbeSlot()) return null;
    final Future<StoreObjectInfo?> head;
    try {
      head = _store.head(key);
    } on Object catch (e) {
      _releaseProbeSlot();
      _log.debug('Store probe for $key failed; not remembered', error: e);
      return null;
    }
    // The slot follows the request, not the wait for it. A timeout stops
    // the waiting but cannot cancel the HEAD, so a stalled one keeps its
    // slot until it settles, and a dead endpoint never has more than the
    // cap in flight however often tiles retry.
    unawaited(
      head.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
        _releaseProbeSlot();
      }),
    );
    try {
      final info = await head.timeout(_probeBudget);
      return (modified: info?.lastModified);
    } on Object catch (e) {
      _log.debug('Store probe for $key failed; not remembered', error: e);
      return null;
    }
  }

  /// False when no slot came free within the budget, or once disposed: a
  /// probe waiting for a slot gives up rather than holding its tile.
  Future<bool> _acquireProbeSlot() async {
    if (_disposed) return false;
    if (_probesRunning < _maxConcurrentProbes) {
      _probesRunning++;
      return true;
    }
    final waiter = Completer<void>();
    _probeWaiters.add(waiter);
    try {
      await waiter.future.timeout(_probeBudget);
    } on TimeoutException {
      // A slot handed over just as the wait ran out is ours to give back.
      // After dispose the waiter was dropped without one.
      if (!_disposed && !_probeWaiters.remove(waiter)) _releaseProbeSlot();
      return false;
    }
    if (_disposed) return false;
    return true;
  }

  /// Hands the slot straight to the next waiter, or frees it.
  void _releaseProbeSlot() {
    if (_probeWaiters.isNotEmpty) {
      _probeWaiters.removeAt(0).complete();
    } else {
      _probesRunning--;
    }
  }

  /// Returns the bytes, as FileData on disk or BytesData in a browser, when
  /// they are cached or fetched (originals are hash-verified); null when
  /// this item is not confirmed in the store or any error occurs (the caller
  /// keeps its native UnavailableData).
  ///
  /// Thumbnail requests route to the thumb object when one was uploaded
  /// and degrade to the original otherwise (spec section 10). The thumb
  /// path needs only the thumb stamp: the pipeline uploads thumbs before
  /// originals, so another device can legitimately serve the thumb while
  /// the original is still in flight.
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null) return null;
    if (thumbnail && item.remoteThumbUploadedAt != null) {
      final thumb = await _fetchThumb(item, hash);
      if (thumb != null) return thumb;
      // Fall through: a missing/broken thumb degrades to the original.
    }
    if (thumbnail && item.mediaType == MediaType.video) {
      // A video's original and rendition are both video: they can only ever
      // render as the movie placeholder, so degrading to them buys nothing
      // and costs a full download (potentially over cellular) per grid tile.
      // Give up instead and let the caller keep its native placeholder.
      return null;
    }
    if (item.remoteUploadedAt != null) {
      final original = await _fetchOriginal(item, hash);
      if (original != null) return original;
    }
    if (item.remoteCompressedUploadedAt != null) {
      return _fetchCompressed(item, hash);
    }
    return null;
  }

  Future<MediaSourceData?> _fetchThumb(MediaItem item, String hash) {
    final version = _thumbVersion(item);
    // As with renditions: two rows sharing a hash but not a stamp must not
    // share a fetch that is checked against the stamp.
    return _gate.run(
      version == null
          ? '$hash#thumb'
          : '$hash#thumb#${version.millisecondsSinceEpoch}',
      () => _fetches.thumb(
        item,
        hash,
        freshAfter: version,
        isPoster: _isPoster(item),
      ),
    );
  }

  /// Whether [item]'s thumb is a decodable stand-in for a row that is not
  /// itself an image.
  ///
  /// The pipeline always uploads thumbs as JPEG, whatever the source's own
  /// format. For a video that JPEG is a poster frame and for a document it
  /// is a page-1 render, so the result is decodable as an image even though
  /// the row is not -- something only this side knows, and the flag is how
  /// MediaItemView is told. A photo's thumb is the photo itself, resized,
  /// so it is not a stand-in and stays unflagged.
  bool _isPoster(MediaItem item) =>
      item.mediaType == MediaType.video || item.mediaType == MediaType.document;

  /// What a cached thumb of [item] must be at least as new as, or null when
  /// any copy will do.
  ///
  /// A PDF's thumb is the one that gets overwritten in place
  /// (PdfThumbRefreshSweep, issue #3996), and its stamp is how this device
  /// finds out. Everything else keeps the one-stat path: a grid asks for
  /// these every time a tile scrolls into view.
  DateTime? _thumbVersion(MediaItem item) =>
      item.isPdf ? item.remoteThumbUploadedAt : null;

  /// Fetches the compressed rendition (spec section 11). Derived bytes, so no
  /// hash verification; validated against remoteCompressedUploadedAt so a
  /// re-uploaded (overwritten) rendition invalidates a stale cache entry.
  Future<MediaSourceData?> _fetchCompressed(MediaItem item, String hash) =>
      // The rendition's freshness is checked against the row's own stamp, so
      // two rows sharing a hash but not a stamp must not share a fetch.
      _gate.run(
        '$hash#rendition'
        '#${item.remoteCompressedUploadedAt?.millisecondsSinceEpoch ?? 0}',
        () => _fetches.rendition(item, hash),
      );

  Future<MediaSourceData?> _fetchOriginal(MediaItem item, String hash) =>
      _gate.run('$hash#original', () => _fetches.original(item, hash));

  /// Releases the fetch gate's budget timers and lets go of probes waiting
  /// for a slot. Called when the store runtime that owns this resolver is
  /// torn down or replaced; see [LocalFileResolver.dispose] for why a stray
  /// budget timer matters.
  void dispose() {
    _disposed = true;
    final waiters = List.of(_probeWaiters);
    _probeWaiters.clear();
    for (final waiter in waiters) {
      waiter.complete();
    }
    _gate.dispose();
  }
}

/// One probe's answer: when the store last modified the object, or null
/// [modified] when the store does not hold it.
typedef _ProbeAnswer = ({DateTime? modified});
