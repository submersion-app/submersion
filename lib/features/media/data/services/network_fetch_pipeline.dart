// Two-step contract. `resolve` / `resolveManifestEntries` extract metadata
// through a bounded worker pool (max 4 concurrent, max 1 call every 250 ms
// per host) and write nothing; `insertResolved` inserts rows that already
// carry their dive or site link. The split exists so a caller can decide
// who owns each item BEFORE any row exists: a media row with neither link
// has no place in the library, and this pipeline is the one creator that
// cannot know the link until it has fetched the bytes.
//
// Writes go through Drift directly rather than MediaRepository.createMedia,
// which insists on a fully-formed domain entity; the row here is assembled
// from extractor output and manifest scalars.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';

/// What the pipeline learned about one URL or manifest entry before any row
/// exists for it: the caller decides the link, then hands it back to
/// [NetworkFetchPipeline.insertResolved].
class ResolvedNetworkMedia {
  const ResolvedNetworkMedia({
    required this.uri,
    this.entry,
    this.result,
    this.failure,
  });

  final Uri uri;

  /// Present for manifest entries; carries the feed-supplied scalars.
  final ManifestEntry? entry;

  /// Extractor output; null when extraction was skipped (fully prefilled
  /// manifest entry) or failed.
  final UrlExtractionResult? result;

  /// Why extraction failed, when it did.
  final String? failure;

  bool get failed => failure != null;

  /// Manifest wins over extraction: the publisher knows more than EXIF.
  DateTime? get takenAt => entry?.takenAt ?? result?.takenAt;
}

/// A resolved item paired with the ONE thing that owns it. A row with
/// neither link has no business in the library, and one with both would
/// belong to a dive the site never named, so the constructor refuses both.
class NetworkInsertRequest {
  NetworkInsertRequest({required this.media, this.diveId, this.siteId})
    : assert(
        (diveId == null) != (siteId == null),
        'exactly one of diveId / siteId',
      );

  final ResolvedNetworkMedia media;
  final String? diveId;
  final String? siteId;
}

/// Metadata fetch and row insert for HTTP(S) media, as two separate calls.
class NetworkFetchPipeline {
  NetworkFetchPipeline({
    required AppDatabase db,
    required UrlMetadataExtractor extractor,
    int maxConcurrent = 4,
    Duration perHostMinInterval = const Duration(milliseconds: 250),
    DateTime Function() now = _defaultNow,
    SyncRepository? syncRepository,
  }) : _db = db,
       _extractor = extractor,
       _maxConcurrent = maxConcurrent,
       _perHostMinInterval = perHostMinInterval,
       _now = now,
       _syncRepository = syncRepository ?? SyncRepository();

  /// Marks inserted rows pending for sync. COUPLING NOTE: the default
  /// SyncRepository resolves its database via DatabaseService, while this
  /// pipeline writes through the injected [_db]. Callers constructing the
  /// pipeline with a standalone database (tests, headless imports) must
  /// either register it with DatabaseService or inject a SyncRepository
  /// bound to the same database.
  final SyncRepository _syncRepository;

  final AppDatabase _db;
  final UrlMetadataExtractor _extractor;
  final int _maxConcurrent;
  final Duration _perHostMinInterval;
  final DateTime Function() _now;
  final _uuid = const Uuid();

  /// Active worker count. Worker `_acquireSlot` waits until this drops
  /// below `_maxConcurrent` before proceeding.
  int _activeWorkers = 0;

  /// FIFO queue of waiters parked at `_acquireSlot`.
  final List<Completer<void>> _slotWaiters = [];

  /// Per-host last-call timestamps, used to enforce the per-host throttle.
  /// Updated when a worker is about to call `extract` (not when it
  /// finishes), since throttling is keyed off call-start time.
  final Map<String, DateTime> _hostLastCall = {};

  /// Per-host serialisation chain. Each scheduled call for a host waits on
  /// the previous call's `Future`, so concurrent workers targeting the same
  /// host take turns through the throttle window rather than racing each
  /// other on `_hostLastCall` reads.
  final Map<String, Future<void>> _hostChain = {};

  /// Extracts metadata for [uris] through the worker pool and per-host
  /// throttle. Writes nothing. Results come back in input order.
  Future<List<ResolvedNetworkMedia>> resolve(List<Uri> uris) {
    return Future.wait([
      for (final uri in uris) _resolveOne(_FillSpec(uri: uri)),
    ]);
  }

  /// [resolve] for manifest entries. An entry that already carries every
  /// field the extractor would populate skips the network round-trip.
  Future<List<ResolvedNetworkMedia>> resolveManifestEntries(
    List<ManifestEntry> entries,
  ) {
    return Future.wait([
      for (final entry in entries)
        _resolveOne(
          _FillSpec.fromManifest(uri: Uri.parse(entry.url), entry: entry),
        ),
    ]);
  }

  /// Inserts one row per request, already linked. A failed fetch still
  /// gets its row (orphaned, with a diagnostics record) because the caller
  /// chose a target for it; nothing here ever inserts an unlinked row.
  ///
  /// Manifest-supplied fields take precedence over extracted ones: the feed
  /// publisher has more context than EXIF inference does.
  Future<List<String>> insertResolved(
    List<NetworkInsertRequest> requests, {
    String? subscriptionId,
  }) async {
    final ids = <String>[];
    final nowMillis = _now().millisecondsSinceEpoch;
    for (final request in requests) {
      final media = request.media;
      final entry = media.entry;
      final result = media.result;
      final id = _uuid.v4();
      await _db
          .into(_db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '',
              fileType: Value(_fileTypeFromMediaType(entry?.mediaType)),
              sourceType: Value(entry == null ? 'networkUrl' : 'manifestEntry'),
              subscriptionId: Value(entry == null ? null : subscriptionId),
              entryKey: Value(entry?.entryKey),
              url: Value(result?.url ?? media.uri.toString()),
              diveId: Value(request.diveId),
              siteId: Value(request.siteId),
              latitude: Value(entry?.latitude ?? result?.lat),
              longitude: Value(entry?.longitude ?? result?.lon),
              takenAt: Value(media.takenAt?.millisecondsSinceEpoch),
              width: Value(entry?.width ?? result?.width),
              height: Value(entry?.height ?? result?.height),
              durationSeconds: Value(entry?.durationSeconds),
              caption: Value(entry?.caption),
              isOrphaned: Value(media.failed),
              lastVerifiedAt: Value(media.failed ? null : nowMillis),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      if (media.failed) {
        await _db
            .into(_db.mediaFetchDiagnostics)
            .insertOnConflictUpdate(
              MediaFetchDiagnosticsCompanion.insert(
                mediaItemId: id,
                lastErrorAt: Value(nowMillis),
                lastErrorMessage: Value(media.failure),
                errorCount: const Value(1),
              ),
            );
      }
      // The link is part of the row from its first synced version.
      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: nowMillis,
      );
      ids.add(id);
    }
    if (ids.isNotEmpty) SyncEventBus.notifyLocalChange();
    return ids;
  }

  Future<ResolvedNetworkMedia> _resolveOne(_FillSpec spec) async {
    // A fully prefilled manifest entry needs no network round-trip.
    if (spec.skipExtract) {
      return ResolvedNetworkMedia(uri: spec.uri, entry: spec.entry);
    }
    await _acquireSlot();
    try {
      // Serialise per-host so concurrent workers wait for the prior call's
      // throttle window to clear, and observe the previous call's start
      // time atomically rather than racing.
      final previous = _hostChain[spec.uri.host] ?? Future<void>.value();
      final completer = Completer<void>();
      _hostChain[spec.uri.host] = completer.future;
      try {
        await previous;
      } catch (_) {
        // Errors on the previous call don't block subsequent ones.
      }
      try {
        await _waitForHostThrottle(spec.uri.host);
        _hostLastCall[spec.uri.host] = _now();
      } finally {
        completer.complete();
      }
      final result = await _extractor.extract(spec.uri);
      if (result.failure != null) {
        return ResolvedNetworkMedia(
          uri: spec.uri,
          entry: spec.entry,
          failure: result.failure,
        );
      }
      return ResolvedNetworkMedia(
        uri: spec.uri,
        entry: spec.entry,
        result: result,
      );
    } catch (e) {
      return ResolvedNetworkMedia(
        uri: spec.uri,
        entry: spec.entry,
        failure: 'pipeline: $e',
      );
    } finally {
      _releaseSlot();
    }
  }

  Future<void> _acquireSlot() async {
    if (_activeWorkers < _maxConcurrent) {
      _activeWorkers += 1;
      return;
    }
    final waiter = Completer<void>();
    _slotWaiters.add(waiter);
    await waiter.future;
    _activeWorkers += 1;
  }

  void _releaseSlot() {
    _activeWorkers -= 1;
    if (_slotWaiters.isNotEmpty) {
      final next = _slotWaiters.removeAt(0);
      next.complete();
    }
  }

  /// Polls the synthetic clock (`_now()`) until at least
  /// `_perHostMinInterval` has elapsed since the last call to `host`. Yields
  /// via `Future<void>.delayed(Duration.zero)` between checks so a fake
  /// clock can advance between iterations without the worker blocking on
  /// real wall time.
  Future<void> _waitForHostThrottle(String host) async {
    final last = _hostLastCall[host];
    if (last == null) return;
    while (true) {
      final elapsed = _now().difference(last);
      if (elapsed >= _perHostMinInterval) return;
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// Maps a manifest entry's optional `mediaType` hint to the legacy
/// `media.file_type` column convention used elsewhere in the schema
/// (`'photo'`, `'video'`). Defaults to `'photo'` when the hint is
/// absent or unrecognised, matching `MediaRepository._mediaTypeToString`.
String _fileTypeFromMediaType(String? mediaType) {
  switch (mediaType) {
    case 'video':
      return 'video';
    case 'photo':
    default:
      return 'photo';
  }
}

/// One resolve job: a bare URL, or a manifest entry whose prefilled scalars
/// may make the network round-trip unnecessary.
class _FillSpec {
  _FillSpec({required this.uri}) : entry = null, skipExtract = false;

  /// The extractor populates `takenAt`, `width`, `height`, and `lat`/`lon`.
  /// The skip is safe iff the manifest already provided all of those;
  /// partial prefill still goes through extraction, with manifest fields
  /// winning at insert time.
  _FillSpec.fromManifest({required this.uri, required ManifestEntry entry})
    : entry = entry,
      skipExtract =
          entry.takenAt != null &&
          entry.width != null &&
          entry.height != null &&
          entry.latitude != null &&
          entry.longitude != null;

  final Uri uri;
  final ManifestEntry? entry;
  final bool skipExtract;
}

DateTime _defaultNow() => DateTime.now().toUtc();
