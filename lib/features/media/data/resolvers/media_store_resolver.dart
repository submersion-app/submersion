import 'dart:async';
import 'dart:io';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_fetch_gate.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Store-backed fallback resolution (design spec section 10). Deliberately
/// NOT a MediaSourceResolver and never registered under a MediaSourceType:
/// rows keep their native source type, so disconnecting the store degrades
/// every row to exactly the pre-store behavior.
class MediaStoreResolver {
  MediaStoreResolver({
    required MediaObjectStore store,
    required MediaCacheStore cache,
    MediaFetchGate? gate,
    Duration probeBudget = kMediaFetchSlotBudget,
    int maxConcurrentProbes = 4,
  }) : assert(maxConcurrentProbes > 0),
       assert(probeBudget > Duration.zero),
       _store = store,
       _cache = cache,
       _gate = gate ?? MediaFetchGate(),
       _probeBudget = probeBudget,
       _maxConcurrentProbes = maxConcurrentProbes;

  final MediaObjectStore _store;
  final MediaCacheStore _cache;

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
          StoreKeys.renditionKey(hash, ext: isVideo ? 'mp4' : 'jpg'),
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

  /// Returns FileData when the bytes are cached or fetched (originals are
  /// hash-verified); null when this item is not confirmed in the store or
  /// any error occurs (the caller keeps its native UnavailableData).
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

  Future<MediaSourceData?> _fetchThumb(MediaItem item, String hash) =>
      _gate.run('$hash#thumb', () => _fetchThumbInner(item, hash));

  Future<MediaSourceData?> _fetchThumbInner(MediaItem item, String hash) async {
    // The pipeline always uploads thumbs as JPEG, whatever the source's own
    // format. For a video that JPEG is a poster frame and for a document it
    // is a page-1 render, so the result is decodable as an image even though
    // the row is not -- something only this side knows, and the flag is how
    // MediaItemView is told. A photo's thumb is the photo itself, resized,
    // so it is not a stand-in and stays unflagged.
    final isPoster =
        item.mediaType == MediaType.video ||
        item.mediaType == MediaType.document;
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) {
        return FileData(
          file: cached,
          isPoster: isPoster,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.thumbnail,
        );
      }
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(
        hash,
        MediaCacheKind.thumb,
        staging,
        extension: 'jpg',
      );
      return FileData(
        file: file,
        isPoster: isPoster,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.thumbnail,
      );
    } on Exception catch (e) {
      _log.warning('Thumb fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  /// Fetches the compressed rendition (spec section 11). Derived bytes, so no
  /// hash verification; validated against remoteCompressedUploadedAt so a
  /// re-uploaded (overwritten) rendition invalidates a stale cache entry.
  Future<MediaSourceData?> _fetchCompressed(MediaItem item, String hash) =>
      // The rendition's freshness is checked against the row's own stamp, so
      // two rows sharing a hash but not a stamp must not share a fetch.
      _gate.run(
        '$hash#rendition'
        '#${item.remoteCompressedUploadedAt?.millisecondsSinceEpoch ?? 0}',
        () => _fetchCompressedInner(item, hash),
      );

  Future<MediaSourceData?> _fetchCompressedInner(
    MediaItem item,
    String hash,
  ) async {
    final ext = item.mediaType == MediaType.video ? 'mp4' : 'jpg';
    File? staging;
    try {
      final cached = await _cache.get(
        hash,
        MediaCacheKind.rendition,
        freshAfter: item.remoteCompressedUploadedAt,
      );
      if (cached != null) {
        return FileData(
          file: cached,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.rendition,
        );
      }
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.renditionKey(hash, ext: ext), staging);
      final file = await _cache.put(
        hash,
        MediaCacheKind.rendition,
        staging,
        sourceVersion: item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
        extension: ext,
      );
      return FileData(
        file: file,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.rendition,
      );
    } on Exception catch (e) {
      _log.warning('Rendition fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  Future<MediaSourceData?> _fetchOriginal(MediaItem item, String hash) =>
      _gate.run('$hash#original', () => _fetchOriginalInner(item, hash));

  Future<MediaSourceData?> _fetchOriginalInner(
    MediaItem item,
    String hash,
  ) async {
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) {
        return FileData(
          file: cached,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.original,
        );
      }

      staging = await _cache.stagingFile();
      final extension = StoreKeys.extensionFor(item.originalFilename);
      await _store.getFile(
        StoreKeys.objectKey(hash, extension: extension),
        staging,
      );
      final digest = await sha256OfFile(staging);
      if (digest.hash != hash) {
        _log.warning('Store object failed hash verification for ${item.id}');
        return null;
      }
      final file = await _cache.put(
        hash,
        MediaCacheKind.original,
        staging,
        extension: _cacheExtensionFor(item, extension),
      );
      return FileData(
        file: file,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.original,
      );
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  /// Extension for the CACHED copy, which is a different question from the
  /// store key's.
  ///
  /// The key records how the object was addressed when it was uploaded and
  /// can never be recomputed differently — that is where the bytes live. The
  /// cache name is local and disposable, and its only job is to let the OS
  /// identify the file. Those come apart when a row has no usable filename:
  /// [StoreKeys.extensionFor] yields [StoreKeys.unknownExtension], which is a
  /// fine address and a useless container hint, so a video cached under it
  /// stays unplayable (`AVURLAsset` infers the container from the path
  /// extension alone).
  ///
  /// Only videos are rescued. A photo's bytes are identified by sniffing, so
  /// giving it a guessed image extension would risk contradicting them for no
  /// gain. Videos fall back to the local path's extension — still recorded on
  /// the row even after the file itself is gone — and then to the media
  /// type's container. That last guess is safe: AVFoundation opens QuickTime
  /// and MP4 bytes under either extension, and rejects only names it does not
  /// recognise at all.
  String _cacheExtensionFor(MediaItem item, String storeExtension) {
    if (storeExtension != StoreKeys.unknownExtension) return storeExtension;
    if (item.mediaType != MediaType.video) return storeExtension;
    final localPath = item.localPath ?? '';
    final dot = localPath.lastIndexOf('.');
    if (dot >= 0 && dot < localPath.length - 1) {
      final ext = localPath.substring(dot + 1).toLowerCase();
      if (_extPattern.hasMatch(ext)) return ext;
    }
    return 'mp4';
  }

  static final RegExp _extPattern = RegExp(r'^[a-z0-9]{1,8}$');

  /// cache.put moves the staging file into the pool, so anything still at
  /// the staging path after a fetch is the debris of a failed one
  /// (partial download, hash mismatch, put error).
  Future<void> _discardStaging(File? staging) async {
    if (staging == null) return;
    try {
      if (await staging.exists()) await staging.delete();
    } on FileSystemException {
      // Best-effort: an undeletable staging file is not worth surfacing.
    }
  }

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
