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

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';

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
  }) : _db = db,
       _extractor = extractor,
       _maxConcurrent = maxConcurrent,
       _perHostMinInterval = perHostMinInterval,
       _now = now;

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
  /// The `autoMatch` flag is reserved for the URL-tab Phase 3 work that
  /// auto-attaches imported media to dives by date; it does not affect the
  /// fetch pipeline itself.
  Future<List<String>> ingest(
    List<Uri> urls, {
    // ignore: avoid_unused_constructor_parameters
    bool autoMatch = true,
  }) async {
    final ids = <String>[];
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
    }
    // Fire-and-forget background fill so callers see rows immediately.
    final fill = _runFill(ids, urls);
    _running.add(fill);
    // Remove from `_running` once it settles, so `idle()` doesn't keep
    // accumulating completed futures.
    fill.whenComplete(() => _running.remove(fill));
    return ids;
  }

  /// Awaits any pending background work. Tests use this to deterministically
  /// drain the pipeline before asserting on row state.
  Future<void> idle() async {
    while (_running.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_running));
    }
  }

  Future<void> _runFill(List<String> ids, List<Uri> urls) async {
    final futures = <Future<void>>[];
    for (var i = 0; i < ids.length; i++) {
      futures.add(_processOne(ids[i], urls[i]));
    }
    await Future.wait(futures);
  }

  Future<void> _processOne(String id, Uri uri) async {
    await _acquireSlot();
    try {
      // Serialise per-host so concurrent workers wait for the prior call's
      // throttle window to clear, and observe the previous call's start
      // time atomically rather than racing.
      final previous = _hostChain[uri.host] ?? Future<void>.value();
      final completer = Completer<void>();
      _hostChain[uri.host] = completer.future;
      try {
        await previous;
      } catch (_) {
        // Errors on the previous call don't block subsequent ones.
      }
      try {
        await _waitForHostThrottle(uri.host);
        _hostLastCall[uri.host] = _now();
      } finally {
        completer.complete();
      }

      final result = await _extractor.extract(uri);
      if (result.failure != null) {
        await _markFailed(id, result.failure!);
      } else {
        await _patchSuccess(id, result);
      }
    } catch (e) {
      await _markFailed(id, 'pipeline: $e');
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

  Future<void> _patchSuccess(String id, UrlExtractionResult result) async {
    final nowMillis = _now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
      MediaCompanion(
        url: Value(result.url),
        width: Value(result.width),
        height: Value(result.height),
        latitude: Value(result.lat),
        longitude: Value(result.lon),
        takenAt: Value(result.takenAt?.millisecondsSinceEpoch),
        lastVerifiedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
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

DateTime _defaultNow() => DateTime.now().toUtc();
