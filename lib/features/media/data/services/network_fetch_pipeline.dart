// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 12. Deviations from the plan code:
//
// - The Drift table is `Media` / `MediaCompanion` (not `MediaItems` /
//   `MediaItemsCompanion` as the plan example shows). The plan was written
//   against an idealised schema; the actual schema uses the existing legacy
//   `media` table extended with the v72 source-type columns.
// - `Media.id` is TEXT (UUID), so `ingest` returns `Future<List<String>>`
//   rather than the plan's `Future<List<int>>`. Generated UUIDs match the
//   pattern `MediaRepository.createMedia` already uses for new rows.
// - `MediaCompanion.insert` requires `id`, `filePath`, `createdAt`,
//   `updatedAt`. We pass an empty `filePath` (URL items have no local file)
//   to satisfy the NOT-NULL constraint, mirroring `MediaRepository`.
// - Per-host throttle is implemented by polling a synthetic `now()` clock
//   between microtask yields rather than `Future.delayed(remaining)`, so
//   the unit-test fake clock can advance time between pumps without the
//   worker blocking on a real-time delay.
//
// Phase 3b extension (Task 10):
// - `ingestManifestEntries` accepts a list of `ManifestEntry` plus the
//   owning `subscriptionId`. Each entry is inserted with
//   `sourceType = 'manifestEntry'` and the manifest-supplied scalars
//   applied directly. If the manifest already provides every field the
//   extractor would otherwise populate (`takenAt`, `width`, `height`,
//   and either both `latitude`/`longitude` or none), the EXIF/range-GET
//   step is skipped and the row is stamped `lastVerifiedAt = now`
//   without ever hitting the network. Otherwise the same background
//   fill path runs, with manifest-supplied fields taking precedence
//   over extracted ones (manifest is treated as authoritative).
// - The plan's idealised version of Task 10 used a `_PipelineJob` queue
//   and a `forTest()` factory; this implementation reuses 3a's existing
//   `_processOne` machinery instead, threading a `_FillSpec` value
//   through it so the same worker pool, per-host throttle, and
//   diagnostics path serve both the URL and manifest paths without
//   duplication.
//
// The pipeline composes `UrlMetadataExtractor` (which itself wraps the
// `NetworkUrlResolver` + EXIF stack) with the `media` and
// `media_fetch_diagnostics` tables. It writes directly through Drift
// rather than going through `MediaRepository` because the repository's
// `createMedia` insists on a fully-formed domain entity, and the pipeline
// needs to insert a stub row first and patch it asynchronously once the
// metadata extraction completes.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Background-fetch pipeline for ad-hoc HTTP(S) media URLs.
///
/// `ingest` synchronously inserts a `media` row per URL with
/// `sourceType = 'networkUrl'` and `lastVerifiedAt = null`, and returns
/// the new row IDs. A bounded worker pool then runs metadata extraction
/// in the background (max 4 concurrent, max 1 call every 250 ms per host)
/// and either patches the row with extracted metadata + `lastVerifiedAt`
/// or marks it `isOrphaned = true` and writes a `media_fetch_diagnostics`
/// row.
class NetworkFetchPipeline {
  NetworkFetchPipeline({
    required AppDatabase db,
    required UrlMetadataExtractor extractor,
    int maxConcurrent = 4,
    Duration perHostMinInterval = const Duration(milliseconds: 250),
    DateTime Function() now = _defaultNow,
    Future<List<DiveBounds>> Function(DateTime takenAt)? diveBoundsLoader,
    DivePhotoMatcher? matcher,
    SyncRepository? syncRepository,
  }) : _db = db,
       _extractor = extractor,
       _maxConcurrent = maxConcurrent,
       _perHostMinInterval = perHostMinInterval,
       _now = now,
       _diveBoundsLoader = diveBoundsLoader,
       _matcher = matcher ?? const DivePhotoMatcher(),
       _syncRepository = syncRepository ?? SyncRepository();

  /// Loads candidate dives around a photo timestamp for auto-matching.
  /// Null disables auto-match entirely (tests, headless imports).
  final Future<List<DiveBounds>> Function(DateTime takenAt)? _diveBoundsLoader;
  final DivePhotoMatcher _matcher;

  /// Marks auto-matched rows pending for sync. COUPLING NOTE: the default
  /// SyncRepository resolves its database via DatabaseService, while this
  /// pipeline writes through the injected [_db]. Callers constructing the
  /// pipeline with a standalone database (tests, headless imports) must
  /// either register it with DatabaseService or inject a SyncRepository
  /// bound to the same database - otherwise the pending mark fails and the
  /// auto-attach is rolled back.
  final SyncRepository _syncRepository;

  final AppDatabase _db;
  final UrlMetadataExtractor _extractor;
  final int _maxConcurrent;
  final Duration _perHostMinInterval;
  final DateTime Function() _now;
  final _uuid = const Uuid();

  /// In-flight background tasks. `idle()` awaits all of them.
  final List<Future<void>> _running = [];

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

  /// Synchronously inserts one `media` row per URL and kicks off background
  /// metadata extraction. Returns the new row IDs in input order.
  ///
  /// With `autoMatch` (the default), rows whose extracted or
  /// manifest-supplied `takenAt` lands confidently inside exactly one
  /// dive's time window are attached to that dive after the background
  /// fill completes (same DivePhotoMatcher semantics as the gallery scan
  /// and Lightroom auto-linking).
  Future<List<String>> ingest(List<Uri> urls, {bool autoMatch = true}) async {
    final ids = <String>[];
    final specs = <_FillSpec>[];
    final nowMillis = _now().millisecondsSinceEpoch;
    for (final uri in urls) {
      final id = _uuid.v4();
      await _db
          .into(_db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '',
              sourceType: const Value('networkUrl'),
              url: Value(uri.toString()),
              isOrphaned: const Value(false),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      ids.add(id);
      specs.add(_FillSpec(id: id, uri: uri, autoMatch: autoMatch));
    }
    _scheduleFill(specs);
    return ids;
  }

  /// Synchronously inserts one `media` row per [ManifestEntry] under the
  /// owning [subscriptionId] and kicks off background metadata extraction.
  /// Returns the new row IDs in input order.
  ///
  /// Each row is inserted with `sourceType = 'manifestEntry'`, the
  /// `subscriptionId` and `entryKey` filled in for cross-device dedup
  /// (enforced by the partial unique index `idx_media_subscription_entry`),
  /// and any manifest-supplied scalars (`takenAt`, `latitude`, `longitude`,
  /// `width`, `height`, `caption`, `durationSeconds`, `mediaType`) applied
  /// directly so the row is immediately useful before any background work.
  ///
  /// EXIF / range-GET extraction is skipped when the manifest already
  /// provides every field the extractor would populate (`takenAt`, `width`,
  /// `height`, and GPS coordinates). In that case the row is simply
  /// stamped `lastVerifiedAt = now` and no network call is issued.
  /// Otherwise the same background-fill path used for URL ingest runs,
  /// but manifest-supplied fields take precedence over extracted ones.
  Future<List<String>> ingestManifestEntries(
    List<ManifestEntry> entries,
    String subscriptionId, {
    bool autoMatch = true,
  }) async {
    final ids = <String>[];
    final specs = <_FillSpec>[];
    final nowMillis = _now().millisecondsSinceEpoch;
    for (final entry in entries) {
      final id = _uuid.v4();
      final fileType = _fileTypeFromMediaType(entry.mediaType);
      await _db
          .into(_db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '',
              fileType: Value(fileType),
              sourceType: const Value('manifestEntry'),
              subscriptionId: Value(subscriptionId),
              entryKey: Value(entry.entryKey),
              url: Value(entry.url),
              latitude: Value(entry.latitude),
              longitude: Value(entry.longitude),
              takenAt: Value(entry.takenAt?.millisecondsSinceEpoch),
              width: Value(entry.width),
              height: Value(entry.height),
              durationSeconds: Value(entry.durationSeconds),
              caption: Value(entry.caption),
              isOrphaned: const Value(false),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      ids.add(id);
      final uri = Uri.parse(entry.url);
      specs.add(
        _FillSpec.fromManifest(
          id: id,
          uri: uri,
          entry: entry,
          autoMatch: autoMatch,
        ),
      );
    }
    _scheduleFill(specs);
    return ids;
  }

  /// Awaits any pending background work. Tests use this to deterministically
  /// drain the pipeline before asserting on row state.
  Future<void> idle() async {
    while (_running.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_running));
    }
  }

  void _scheduleFill(List<_FillSpec> specs) {
    if (specs.isEmpty) return;
    // Fire-and-forget background fill so callers see rows immediately.
    final fill = _runFill(specs);
    _running.add(fill);
    // Remove from `_running` once it settles, so `idle()` doesn't keep
    // accumulating completed futures.
    fill.whenComplete(() => _running.remove(fill));
  }

  Future<void> _runFill(List<_FillSpec> specs) async {
    final futures = <Future<void>>[];
    for (final spec in specs) {
      futures.add(_processOne(spec));
    }
    await Future.wait(futures);
  }

  Future<void> _processOne(_FillSpec spec) async {
    // Manifest entries that already have every field the extractor would
    // populate skip the network round-trip entirely. Just stamp
    // `lastVerifiedAt` so the row is treated as verified-against-the-
    // manifest at this clock tick.
    if (spec.skipExtract) {
      try {
        await _markVerifiedNoExtract(spec.id);
        if (spec.autoMatch && spec.manifestTakenAt != null) {
          await _tryAutoMatch(spec.id, spec.manifestTakenAt!);
        }
      } catch (e) {
        await _markFailed(spec.id, 'pipeline: $e');
      }
      return;
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
        await _markFailed(spec.id, result.failure!);
      } else {
        await _patchSuccess(spec, result);
        final takenAt = spec.manifestTakenAt ?? result.takenAt;
        if (spec.autoMatch && takenAt != null) {
          await _tryAutoMatch(spec.id, takenAt);
        }
      }
    } catch (e) {
      await _markFailed(spec.id, 'pipeline: $e');
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

  Future<void> _patchSuccess(_FillSpec spec, UrlExtractionResult result) async {
    final nowMillis = _now().millisecondsSinceEpoch;
    // Manifest-supplied fields take precedence over extracted ones —
    // the manifest is treated as authoritative since the feed publisher
    // has more context than EXIF inference does. Falls back to the
    // extractor's value when the manifest didn't provide one.
    final width = spec.manifestWidth ?? result.width;
    final height = spec.manifestHeight ?? result.height;
    final lat = spec.manifestLatitude ?? result.lat;
    final lon = spec.manifestLongitude ?? result.lon;
    final takenAt = spec.manifestTakenAt ?? result.takenAt;
    await (_db.update(_db.media)..where((t) => t.id.equals(spec.id))).write(
      MediaCompanion(
        url: Value(result.url),
        width: Value(width),
        height: Value(height),
        latitude: Value(lat),
        longitude: Value(lon),
        takenAt: Value(takenAt?.millisecondsSinceEpoch),
        lastVerifiedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  /// Stamp `lastVerifiedAt` for a row whose manifest entry was already
  /// fully prefilled, so no extractor call was needed. The synchronous
  /// insert step has already populated every metadata column from the
  /// manifest; here we only mark the row as verified-now.
  Future<void> _markVerifiedNoExtract(String id) async {
    final nowMillis = _now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
      MediaCompanion(
        lastVerifiedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  /// Attach the row to a dive when its timestamp lands confidently inside
  /// exactly one dive window. Best-effort: never attaches over an existing
  /// diveId, ambiguous matches are left for the suggestions flow, and any
  /// failure leaves the row exactly as the fill wrote it.
  Future<void> _tryAutoMatch(String id, DateTime takenAt) async {
    final loader = _diveBoundsLoader;
    if (loader == null) return;
    try {
      final row = await (_db.select(
        _db.media,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.diveId != null) return;
      final match = _matcher.matchTimestamp(
        takenAt: takenAt,
        dives: await loader(takenAt),
      );
      if (match.kind != TimestampMatchKind.confident) return;
      final nowMillis = _now().millisecondsSinceEpoch;
      // Conditional on diveId still being NULL: a user/manual attachment
      // landing between the read above and this write must win.
      final updated =
          await (_db.update(
            _db.media,
          )..where((t) => t.id.equals(id) & t.diveId.isNull())).write(
            MediaCompanion(
              diveId: Value(match.diveId),
              updatedAt: Value(nowMillis),
            ),
          );
      if (updated == 0) return;
      // The attachment must propagate cross-device like any media edit. If
      // the pending mark cannot be written, revert the attach: a row that
      // is attached only on this device would contradict the guarantee
      // that failures leave the row exactly as the fill wrote it.
      try {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: nowMillis,
        );
        SyncEventBus.notifyLocalChange();
      } catch (_) {
        // True restore: the pre-attach updatedAt comes back too, so the
        // row is byte-for-byte what the fill wrote (no unsynced edit).
        // The updatedAt == nowMillis guard pins the rollback to the exact
        // write made above: a newer edit (even one attaching the same
        // dive) carries a different stamp and is left untouched.
        await (_db.update(_db.media)..where(
              (t) =>
                  t.id.equals(id) &
                  t.diveId.equals(match.diveId!) &
                  t.updatedAt.equals(nowMillis),
            ))
            .write(
              MediaCompanion(
                diveId: const Value(null),
                updatedAt: Value(row.updatedAt),
              ),
            );
      }
    } catch (_) {
      // Auto-match is additive; the imported row stays library-level.
    }
  }

  Future<void> _markFailed(String id, String message) async {
    final nowMillis = _now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
      MediaCompanion(
        isOrphaned: const Value(true),
        updatedAt: Value(nowMillis),
      ),
    );
    await _db
        .into(_db.mediaFetchDiagnostics)
        .insertOnConflictUpdate(
          MediaFetchDiagnosticsCompanion.insert(
            mediaItemId: id,
            lastErrorAt: Value(nowMillis),
            lastErrorMessage: Value(message),
            errorCount: const Value(1),
          ),
        );
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

/// Per-row plan for a single background-fill operation. Captures both
/// the URL path (no manifest fields, always extract) and the manifest
/// path (manifest-supplied fields, extraction skipped when fully
/// prefilled). Fields named `manifest*` are non-null only for entries
/// that came from a manifest.
class _FillSpec {
  /// Builds a spec for the URL `ingest` path. No manifest fields are
  /// set, and extraction is always required.
  _FillSpec({required this.id, required this.uri, this.autoMatch = false})
    : skipExtract = false,
      manifestTakenAt = null,
      manifestLatitude = null,
      manifestLongitude = null,
      manifestWidth = null,
      manifestHeight = null;

  /// Builds a spec for the manifest-entry path, copying any manifest-
  /// supplied scalars and computing whether the EXIF/range-GET step
  /// can be skipped because every field the extractor would populate
  /// is already supplied by the manifest.
  _FillSpec.fromManifest({
    required this.id,
    required this.uri,
    required ManifestEntry entry,
    this.autoMatch = false,
  }) : manifestTakenAt = entry.takenAt,
       manifestLatitude = entry.latitude,
       manifestLongitude = entry.longitude,
       manifestWidth = entry.width,
       manifestHeight = entry.height,
       // The extractor populates `takenAt`, `width`, `height`, and
       // `lat`/`lon`. The skip is safe iff the manifest already
       // provided all of those — partial prefill still goes through
       // extraction, with manifest fields winning at merge time.
       skipExtract =
           entry.takenAt != null &&
           entry.width != null &&
           entry.height != null &&
           entry.latitude != null &&
           entry.longitude != null;

  final String id;
  final Uri uri;
  final bool skipExtract;
  final bool autoMatch;
  final DateTime? manifestTakenAt;
  final double? manifestLatitude;
  final double? manifestLongitude;
  final int? manifestWidth;
  final int? manifestHeight;
}

DateTime _defaultNow() => DateTime.now().toUtc();
