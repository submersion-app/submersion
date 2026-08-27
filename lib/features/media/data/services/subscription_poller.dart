// Single-pass polling cycle: list active-due subscriptions, fetch each
// manifest, diff against existing `manifestEntry` rows, and apply the
// resulting insert / patch / orphan operations. App-launch + periodic +
// Poll-now scheduling lives in SubscriptionPollerScheduler.
//
// New entries go through the pipeline's resolve-then-insert contract, and
// the pipeline generates the row ids; the partial unique index
// `idx_media_subscription_entry` provides cross-device dedup so duplicate
// inserts on the same `(subscriptionId, entryKey)` are rejected at the DB
// level.
//
// "Changed entries" detection is intentionally simple: build the patched
// `MediaItem` from the existing row and the manifest entry, and skip the
// write only when the result is `==` to the current row. Equality is
// provided by the `Equatable` mixin on `MediaItem`, so the comparison
// ignores nothing. This avoids a verbose field-by-field diff and lets the
// row's `updatedAt` advance only on real changes.
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Drives one polling cycle across all active-due manifest subscriptions.
///
/// Each cycle:
///
/// 1. Query [ManifestSubscriptionRepository.listActiveDue] for due rows.
/// 2. Per subscription (error-isolated): fetch the manifest with
///    conditional headers, then dispatch on outcome:
///    - `NotModified` → bump timestamps via `recordPollNotModified`.
///    - `Failure` → record the error and apply the repo's exponential
///      backoff via `recordPollFailure`.
///    - `Success` → diff the parsed entries against existing
///      `manifestEntry` rows for this subscription:
///      - new `entryKey`s → resolve their metadata, match each against the
///        logbook, and insert only the confident matches (already linked).
///      - existing `entryKey`s with changed fields → patch via
///        `MediaRepository.updateMedia`.
///      - DB rows whose `entryKey` is not in the fetched manifest → flip
///        `isOrphaned = true` via `MediaRepository.markOrphaned`. We do
///        not delete: users may have linked these to dives or added notes.
///    - On success completion, call `recordPollSuccess` with the
///      response's `etag` and `lastModified` so the next round can send
///      conditional `If-None-Match` / `If-Modified-Since` headers.
///
/// Errors thrown during a single subscription's poll are caught and
/// logged so one bad feed does not stop other subscriptions from polling.
class SubscriptionPoller {
  SubscriptionPoller({
    required this.subscriptions,
    required this.mediaRepo,
    required this.fetchService,
    required this.pipeline,
    required this.diveLinkMatcher,
    this.activeDiverId,
  });

  final ManifestSubscriptionRepository subscriptions;
  final MediaRepository mediaRepo;
  final ManifestFetchService fetchService;
  final NetworkFetchPipeline pipeline;
  final DiveLinkMatcher diveLinkMatcher;

  /// The diver whose dives new entries may attach to, read per poll. Null
  /// scopes nothing, which in a multi-diver database could hand a photo to
  /// another diver's dive.
  final String? Function()? activeDiverId;
  final _log = LoggerService.forClass(SubscriptionPoller);

  /// Poll a single subscription right now, ignoring its `nextPollAt`.
  /// Returns `true` if the subscription was found and polled (success, 304,
  /// or recorded failure), `false` if no row matches [subscriptionId].
  ///
  /// Phase 3c seam: needed by the Manifest subscriptions card's "Poll now"
  /// action (Task 7). Mirrors the same error-isolation as [pollAllDue] —
  /// the user can re-trigger from the UI if a transient error occurs.
  Future<bool> pollNow(String subscriptionId, DateTime now) async {
    final sub = await subscriptions.getById(subscriptionId);
    if (sub == null) return false;
    try {
      await _pollOne(sub, now);
    } catch (e, st) {
      _log.error('pollNow failed: $subscriptionId', error: e, stackTrace: st);
      try {
        await subscriptions.recordPollFailure(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          error: '$e',
          now: now,
        );
      } catch (_) {
        // Already in error path; swallow secondary failure.
      }
    }
    return true;
  }

  /// Run one polling cycle. Returns the number of subscriptions visited
  /// (success + 304 + failure all counted). The caller is responsible for
  /// scheduling the next cycle (Task 12).
  Future<int> pollAllDue(DateTime now) async {
    final due = await subscriptions.listActiveDue(now);
    for (final sub in due) {
      try {
        await _pollOne(sub, now);
      } catch (e, st) {
        _log.error(
          'Subscription poll failed (continuing): ${sub.id}',
          error: e,
          stackTrace: st,
        );
        try {
          await subscriptions.recordPollFailure(
            sub.id,
            pollIntervalSeconds: sub.pollIntervalSeconds,
            error: '$e',
            now: now,
          );
        } catch (_) {
          // Already in error path; swallow secondary failure.
        }
      }
    }
    return due.length;
  }

  Future<void> _pollOne(ManifestSubscription sub, DateTime now) async {
    final outcome = await fetchService.fetch(
      Uri.parse(sub.manifestUrl),
      ifNoneMatch: sub.lastEtag,
      ifModifiedSince: sub.lastModified,
      formatOverride: sub.format,
    );
    switch (outcome) {
      case ManifestFetchNotModified():
        await subscriptions.recordPollNotModified(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          now: now,
        );
      case ManifestFetchFailure():
        await subscriptions.recordPollFailure(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          error: outcome.message,
          now: now,
        );
      case ManifestFetchSuccess():
        await _applyDiff(sub, outcome.parsed, now);
        await subscriptions.recordPollSuccess(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          etag: outcome.etag,
          lastModified: outcome.lastModified,
          now: now,
        );
    }
  }

  Future<void> _applyDiff(
    ManifestSubscription sub,
    ManifestParseResult parsed,
    DateTime now,
  ) async {
    final existing = await mediaRepo.getAllBySubscription(sub.id);
    final byKey = <String, MediaItem>{
      for (final m in existing)
        if (m.entryKey != null) m.entryKey!: m,
    };
    final fetchedKeys = parsed.entries.map((e) => e.entryKey).toSet();

    // Walk the manifest. New entries -> pipeline ingest (which inserts +
    // fills metadata). Existing entries -> patch in place if any field
    // changed.
    final newEntries = <ManifestEntry>[];
    for (final entry in parsed.entries) {
      final existingRow = byKey[entry.entryKey];
      if (existingRow == null) {
        newEntries.add(entry);
        continue;
      }
      final patched = existingRow.copyWith(
        url: entry.url,
        takenAt: entry.takenAt ?? existingRow.takenAt,
        caption: entry.caption ?? existingRow.caption,
        latitude: entry.latitude ?? existingRow.latitude,
        longitude: entry.longitude ?? existingRow.longitude,
        width: entry.width ?? existingRow.width,
        height: entry.height ?? existingRow.height,
        durationSeconds: entry.durationSeconds ?? existingRow.durationSeconds,
        // A row that was previously orphaned (because the manifest had
        // dropped it) is no longer orphaned now that it reappeared.
        isOrphaned: false,
      );
      if (patched != existingRow) {
        await mediaRepo.updateMedia(patched);
      }
    }

    // Removed entries: present in DB, absent from the new manifest body.
    for (final m in existing) {
      final key = m.entryKey;
      if (key == null) continue;
      if (!fetchedKeys.contains(key) && !m.isOrphaned) {
        await mediaRepo.markOrphaned(m.id, true);
      }
    }

    // Fresh entries are resolved first and inserted only against a
    // confident dive match: nobody is here to pick a dive, and a row with
    // no dive has no place in the library. Anything skipped is still absent
    // from the DB, so the next poll sees it as new and tries again.
    if (newEntries.isNotEmpty) {
      final resolved = await pipeline.resolveManifestEntries(newEntries);
      final decided = await requestsForConfidentMatches(
        resolved,
        diveLinkMatcher,
        diverId: activeDiverId?.call(),
      );
      final ids = await pipeline.insertResolved(
        decided.requests,
        subscriptionId: sub.id,
      );
      _log.info(
        'Polled ${sub.id} at ${now.toIso8601String()}: '
        '${ids.length} new entries inserted, ${decided.skipped} skipped '
        '(no confident dive)',
      );
    }
  }
}
