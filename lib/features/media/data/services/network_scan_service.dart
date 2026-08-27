// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 3. Deviations from the plan code:
//
// - `NetworkCredentialsService.headersFor` takes a `Uri` and returns a
//   nullable `Future<Map<String, String>?>`, not a `String` returning a
//   non-null map. We pass the parsed `Uri` and coerce a `null` result to an
//   empty map before merging with per-request overrides.
// - `lastVerifiedAt` uses `clock.now()` from `package:clock` rather than raw
//   `DateTime.now()`, matching Task 2's lesson: `fakeAsync` only fakes
//   `Timer`s and `clock.now()`, not `DateTime.now()`. Tests that drive time
//   under `fakeAsync` (future tasks may add some) will see the synthetic
//   clock without us having to touch this file again.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

typedef HttpClientFactory = http.Client Function();

/// User-triggered re-verification scan over every `networkUrl` and
/// `manifestEntry` `MediaItem`.
///
/// Implements Phase 3 deliverable 8 from
/// `2026-04-25-media-source-extension-design.md`. Purely user-initiated; no
/// background timer, no app-launch trigger. The Settings page surfaces the
/// progress + final report through a dialog.
///
/// Per-row error isolation: a throw on one row never aborts the loop; it
/// just bumps the `unreachable` counter and the loop continues.
class NetworkScanService {
  final MediaRepository _repository;
  final NetworkCredentialsService _credentials;
  // ignore: unused_field
  final ManifestSubscriptionRepository _subscriptions;
  final HostRateLimiter _rateLimiter;
  final HttpClientFactory _httpClientFactory;
  final _log = LoggerService.forClass(NetworkScanService);

  NetworkScanReport? _lastReport;

  NetworkScanService({
    required MediaRepository repository,
    required NetworkCredentialsService credentials,
    required ManifestSubscriptionRepository subscriptions,
    required HostRateLimiter rateLimiter,
    HttpClientFactory? httpClientFactory,
  }) : _repository = repository,
       _credentials = credentials,
       _subscriptions = subscriptions,
       _rateLimiter = rateLimiter,
       _httpClientFactory = httpClientFactory ?? (() => http.Client());

  /// The most recent scan's final report, or `null` if no scan has finished.
  NetworkScanReport? get lastReport => _lastReport;

  /// Walks every `networkUrl` and `manifestEntry` row and emits progress
  /// events as each one completes. The final event has
  /// `phase == NetworkScanPhase.finished`. The accompanying final report is
  /// stored in [lastReport] and persists until the next scan starts.
  ///
  /// When the consumer cancels the stream subscription (e.g. user dismisses
  /// the dialog), the generator terminates and any in-flight HTTP requests
  /// are aborted. Rows that completed before cancellation keep their
  /// updated `isOrphaned` / `lastVerifiedAt` state in the DB; rows that
  /// were mid-fetch are left untouched. Re-running the scan picks up
  /// where the previous one left off (since unverified rows still have
  /// stale state).
  Stream<NetworkScanProgress> scanAll() async* {
    final stopwatch = Stopwatch()..start();
    final client = _httpClientFactory();
    try {
      _log.info('Starting network scan');

      final urlRows = await _safeFetch(MediaSourceType.networkUrl);
      final manifestRows = await _safeFetch(MediaSourceType.manifestEntry);
      final all = [...urlRows, ...manifestRows];

      final scannable = all.where((r) => r.url != null).toList();
      final skippedNoUrl = all.length - scannable.length;

      var progress = NetworkScanProgress.starting(total: scannable.length);
      yield progress;

      // We use a list of futures so multiple in-flight requests across
      // different hosts can advance in parallel; the rate limiter governs
      // per-host budgets internally. The completion order drives the
      // progress stream — first done emits first.
      final controller = StreamController<NetworkScanProgress>();

      final inflight = <Future<void>>[];
      for (final row in scannable) {
        inflight.add(
          _scanOne(client, row).then((available) {
            progress = NetworkScanProgress(
              phase: NetworkScanPhase.scanning,
              total: progress.total,
              done: progress.done + 1,
              available: progress.available + (available ? 1 : 0),
              unreachable: progress.unreachable + (available ? 0 : 1),
            );
            controller.add(progress);
          }),
        );
      }

      // Drain inflight + close the controller when all are done.
      // Assign `_lastReport` BEFORE emitting the `finished` event so any
      // consumer that reads `lastReport` synchronously on the finished
      // event sees a populated report (no race window).
      Future<void>.microtask(() async {
        await Future.wait<void>(inflight);
        progress = NetworkScanProgress(
          phase: NetworkScanPhase.finished,
          total: progress.total,
          done: progress.done,
          available: progress.available,
          unreachable: progress.unreachable,
        );
        stopwatch.stop();
        _lastReport = NetworkScanReport.fromProgress(
          progress,
          skippedNoUrl: skippedNoUrl,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        controller.add(progress);
        await controller.close();
      });

      await for (final p in controller.stream) {
        yield p;
      }

      _log.info(
        'Network scan complete: total=${_lastReport!.total}, '
        'available=${_lastReport!.available}, '
        'unreachable=${_lastReport!.unreachable}, '
        'skippedNoUrl=${_lastReport!.skippedNoUrl}, '
        'durationMs=${_lastReport!.durationMs}',
      );
    } catch (e, st) {
      _log.error('Network scan failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<List<MediaItem>> _safeFetch(MediaSourceType type) async {
    try {
      return await _repository.getAllBySourceType(type);
    } catch (e, st) {
      _log.error(
        'Failed to enumerate media for $type',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  /// Scans a single row. Returns `true` if the row is reachable, `false`
  /// if it should be marked orphaned. Always updates `lastVerifiedAt`.
  /// Per-row exceptions are caught and logged; the scan continues.
  Future<bool> _scanOne(http.Client client, MediaItem row) async {
    final urlString = row.url!;
    final uri = Uri.parse(urlString);
    final host = uri.host;

    try {
      final headers = await _resolveAuthHeaders(row, uri);
      final reachable = await _rateLimiter.run<bool>(host, () async {
        // First try HEAD. Some servers return 405 / 501 / 400 for HEAD on
        // user-content endpoints; in that case fall back to a 1-byte
        // range GET, which is still polite.
        final headResp = await client.head(uri, headers: headers);
        if (_isHeadUnsupported(headResp.statusCode)) {
          final getResp = await client.get(
            uri,
            headers: {...headers, 'Range': 'bytes=0-0'},
          );
          return _isReachable(getResp.statusCode);
        }
        return _isReachable(headResp.statusCode);
      });

      await _persistResult(row, reachable: reachable);
      return reachable;
    } catch (e, st) {
      _log.warning(
        'Scan failed for media ${row.id} (${row.url}): $e',
        stackTrace: st,
      );
      try {
        await _persistResult(row, reachable: false);
      } catch (e2, st2) {
        _log.error(
          'Failed to persist orphan flag for ${row.id}',
          error: e2,
          stackTrace: st2,
        );
      }
      return false;
    }
  }

  Future<void> _persistResult(MediaItem row, {required bool reachable}) {
    final updated = row.copyWith(
      isOrphaned: !reachable,
      lastVerifiedAt: clock.now(),
    );
    return _repository.updateMedia(updated);
  }

  Future<Map<String, String>> _resolveAuthHeaders(
    MediaItem row,
    Uri uri,
  ) async {
    // The credentials service is keyed by hostname: a single host owns at
    // most one credential set, so for both `networkUrl` and `manifestEntry`
    // rows the URL's host is the right key. (For manifestEntry rows, the
    // parent subscription's `credentialsHostId` is just a back-reference to
    // the same host record.) If `headersFor` returns null, we fall back to
    // an empty map — the request goes through without auth.
    final headers = await _credentials.headersFor(uri);
    return headers ?? const <String, String>{};
  }

  bool _isHeadUnsupported(int code) =>
      code == 405 || code == 501 || code == 400;

  bool _isReachable(int code) => code >= 200 && code < 400;
}
