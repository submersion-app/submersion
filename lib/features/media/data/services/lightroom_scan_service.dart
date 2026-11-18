import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/dive_media_clock.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Counters describing one scan run, for the summary snackbar and the
/// settings status line.
class LightroomScanSummary {
  int examined = 0;
  int attached = 0;
  int suggested = 0;
  int skippedExisting = 0;
  int skippedNoCaptureTime = 0;
}

/// A dive's profile and the clock its media is placed against.
typedef _DivePlacement = ({
  List<DiveProfilePoint> profile,
  DiveMediaClock clock,
});

/// Matches Lightroom catalog assets to dives by capture time.
///
/// Confident matches become `serviceConnector` media rows (enriched from
/// the dive profile, then enqueued into the media store transfer queue);
/// ambiguous matches become pending suggestions, one row per candidate
/// dive. Dedup happens BEFORE row creation against remote asset ids on
/// synced media rows, which is what makes re-scans and second-device
/// scans idempotent.
class LightroomScanService {
  LightroomScanService({
    required LightroomApiClient api,
    required MediaRepository mediaRepository,
    required DiveRepository diveRepository,
    required void Function(String mediaId) enqueueUpload,
    EnrichmentService enrichmentService = const EnrichmentService(),
    DivePhotoMatcher matcher = const DivePhotoMatcher(),
    DateTime Function()? now,
  }) : _api = api,
       _mediaRepository = mediaRepository,
       _diveRepository = diveRepository,
       _enqueueUpload = enqueueUpload,
       _enrichmentService = enrichmentService,
       _matcher = matcher,
       _now = now ?? DateTime.now;

  /// How far back [poll] looks for dives whose windows may have gained
  /// new Lightroom uploads. Old photos uploaded later than this are
  /// caught by a manual scan.
  static const Duration pollLookback = Duration(days: 90);

  final LightroomApiClient _api;
  final MediaRepository _mediaRepository;
  final DiveRepository _diveRepository;
  final void Function(String mediaId) _enqueueUpload;
  final EnrichmentService _enrichmentService;
  final DivePhotoMatcher _matcher;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(LightroomScanService);

  /// Merged capture-time query spans from dive windows (entry - preBuffer
  /// to exit + postBuffer), so a day of repetitive dives is one API query
  /// instead of one per dive.
  static List<({DateTime start, DateTime end})> mergeWindows(
    List<DiveBounds> bounds,
  ) {
    if (bounds.isEmpty) return const [];
    final windows =
        bounds
            .map(
              (b) => (
                start: b.entryTime.subtract(DivePhotoMatcher.preBuffer),
                end: b.exitTime.add(DivePhotoMatcher.postBuffer),
              ),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final merged = [windows.first];
    for (final w in windows.skip(1)) {
      final last = merged.last;
      if (!w.start.isAfter(last.end)) {
        if (w.end.isAfter(last.end)) {
          merged[merged.length - 1] = (start: last.start, end: w.end);
        }
      } else {
        merged.add(w);
      }
    }
    return merged;
  }

  /// Scans the catalog for assets matching [dives] and attaches or
  /// suggests them. Assets already linked or suggested (on any device;
  /// media rows sync) are skipped.
  Future<LightroomScanSummary> scanDives({
    required ConnectedAccount account,
    required List<Dive> dives,
    required LightroomConnectorState state,
  }) async {
    final summary = LightroomScanSummary();
    final bounds = [for (final dive in dives) _boundsFor(dive)];
    final matched = await _matched(
      account: account,
      bounds: bounds,
      state: state,
      summary: summary,
    );
    // A card of photos lands on a handful of dives. Each dive is read once
    // for the scan, not once per photo placed on it.
    final placements = <String, Future<_DivePlacement?>>{};
    for (final (asset, match) in matched) {
      switch (match.kind) {
        case TimestampMatchKind.none:
          break;
        case TimestampMatchKind.confident:
          await _attach(
            asset,
            diveId: match.diveId!,
            account: account,
            placements: placements,
          );
          summary.attached++;
        case TimestampMatchKind.ambiguous:
          for (final diveId in match.candidateDiveIds) {
            await _mediaRepository.createPendingSuggestion(
              domain.PendingPhotoSuggestion(
                id: '',
                diveId: diveId,
                platformAssetId: asset.id,
                takenAt: asset.captureDate!,
                createdAt: _now(),
                connectorAccountId: account.id,
                remoteAssetId: asset.id,
              ),
            );
          }
          summary.suggested++;
      }
    }
    _log.info(
      'Lightroom scan: ${summary.examined} examined, '
      '${summary.attached} attached, ${summary.suggested} suggested, '
      '${summary.skippedExisting} already linked',
    );
    return summary;
  }

  /// The rows a scan of [dive] would attach, built and placed but not
  /// written, for a sitting on the dive that holds them until its Save
  /// (issue #4527); Save also queues their uploads. A scan of one dive
  /// only ever matches it confidently, so it suggests nothing. [dive] is
  /// the sitting's, whose profile and media clock place the rows.
  Future<({List<PreparedMedia> rows, LightroomScanSummary summary})>
  prepareForDive({
    required ConnectedAccount account,
    required Dive dive,
    required LightroomConnectorState state,
  }) async {
    final summary = LightroomScanSummary();
    final matched = await _matched(
      account: account,
      bounds: [_boundsFor(dive)],
      state: state,
      summary: summary,
    );
    // Read only when there is something to place.
    final placement = dive.profile.isEmpty || matched.isEmpty
        ? null
        : (
            profile: dive.profile,
            clock: DiveMediaClock.forDive(
              dive,
              primarySourceEntry: await _diveRepository.getPrimarySourceEntry(
                dive.id,
              ),
            ),
          );
    final rows = [
      for (final (asset, match) in matched)
        if (match.kind == TimestampMatchKind.confident)
          _prepare(asset, diveId: dive.id, account: account, at: placement),
    ];
    summary.attached = rows.length;
    return (rows: rows, summary: summary);
  }

  /// The catalog assets [bounds] may take, each with its match: fetched for
  /// their windows (or from the chosen albums), once each, skipping those
  /// with no capture time and those already linked or suggested (on any
  /// device; media rows sync). [summary] counts what was skipped.
  Future<List<(LightroomAsset, TimestampMatch)>> _matched({
    required ConnectedAccount account,
    required List<DiveBounds> bounds,
    required LightroomConnectorState state,
    required LightroomScanSummary summary,
  }) async {
    final catalogId = account.accountIdentifier;
    if (catalogId == null || bounds.isEmpty) return const [];
    final spans = mergeWindows(bounds);

    final existing = await _mediaRepository.getConnectorRemoteAssetIds();
    final suggested = await _mediaRepository
        .getPendingSuggestionRemoteAssetIds();
    final albumIds = await state.albumIds();

    final assets = albumIds.isEmpty
        ? await _fetchCatalogAssets(catalogId, spans)
        : await _fetchAlbumAssets(catalogId, albumIds);

    final seenThisScan = <String>{};
    final matched = <(LightroomAsset, TimestampMatch)>[];
    for (final asset in assets) {
      if (!seenThisScan.add(asset.id)) continue;
      summary.examined++;
      if (asset.captureDate == null) {
        summary.skippedNoCaptureTime++;
        continue;
      }
      if (existing.contains(asset.id) || suggested.contains(asset.id)) {
        summary.skippedExisting++;
        continue;
      }
      matched.add((
        asset,
        _matcher.matchTimestamp(takenAt: asset.captureDate!, dives: bounds),
      ));
    }
    return matched;
  }

  /// Scans dives from the last [pollLookback] and stamps the poll time.
  /// Runs the same pipeline as a manual scan, so a failure mid-way leaves
  /// no partial state that a re-run would not reconcile (dedup).
  Future<LightroomScanSummary> poll({
    required ConnectedAccount account,
    required LightroomConnectorState state,
  }) async {
    final until = _now();
    final dives = await _diveRepository.getDivesInRange(
      until.subtract(pollLookback),
      until,
    );
    final summary = await scanDives(
      account: account,
      dives: dives,
      state: state,
    );
    await state.setLastPollAt(until);
    return summary;
  }

  /// Confirms an ambiguous suggestion: creates the media row for the
  /// suggestion's dive and removes every candidate row for the asset.
  /// Filename/GPS/duration are not stored on suggestions; the row carries
  /// the identity fields, and the store pipeline supplies display bytes.
  Future<void> confirmSuggestion({
    required ConnectedAccount account,
    required domain.PendingPhotoSuggestion suggestion,
  }) async {
    final remoteAssetId = suggestion.remoteAssetId;
    if (remoteAssetId == null) return;
    await _attach(
      LightroomAsset(
        id: remoteAssetId,
        subtype: 'image',
        captureDate: suggestion.takenAt,
      ),
      diveId: suggestion.diveId,
      account: account,
    );
    await _mediaRepository.deleteSuggestionsForRemoteAsset(remoteAssetId);
  }

  Future<List<LightroomAsset>> _fetchCatalogAssets(
    String catalogId,
    List<({DateTime start, DateTime end})> spans,
  ) async {
    final assets = <LightroomAsset>[];
    for (final span in spans) {
      // captured_after/captured_before are mutually exclusive on the assets
      // endpoint, so query the lower bound only and page `next`. Adobe lists
      // assets coarsely oldest-first (ascending by day, unordered within a
      // day), so querying captured_after=window start puts the window's assets
      // on the first pages; page until an entire page falls past the window end
      // (see the per-page stop below) rather than trusting a strict order.
      _log.info(
        '[LR-SCAN] span ${span.start.toIso8601String()} .. '
        '${span.end.toIso8601String()} '
        '(query captured_after=${span.start.toIso8601String()})',
      );
      String? next;
      var reachedEnd = false;
      var pageNum = 0;
      do {
        final page = await _api.listAssets(
          catalogId,
          capturedAfter: span.start,
          nextUrl: next,
        );
        pageNum++;
        // Per-page detail (including capture timestamps) is verbose and would
        // flood logs on large catalogs -- keep it at debug; the span and
        // summary lines below stay at info.
        _log.debug(
          '[LR-SCAN] page $pageNum: got=${page.assets.length} '
          'firstDates=[${page.assets.take(4).map((a) => a.captureDate?.toIso8601String() ?? 'null').join(' | ')}] '
          'lastDate=${page.assets.isEmpty ? 'n/a' : page.assets.last.captureDate?.toIso8601String()} '
          'hasNext=${page.nextUrl != null}',
        );
        var sawWithinWindow = false;
        for (final asset in page.assets) {
          final captureDate = asset.captureDate;
          if (captureDate == null) {
            // The catalog path is capture-date filtered so nulls should not
            // surface, but keep any that slip through for summary accounting.
            // They cannot fall in a window and must not drive the stop below.
            assets.add(asset);
            continue;
          }
          if (captureDate.isAfter(span.end)) {
            // Past the window end. The endpoint orders assets only coarsely
            // (ascending by day, unordered within a day), so a later asset on
            // this same page can still sit inside the window -- skip this one
            // but keep scanning the rest of the page rather than stopping.
            continue;
          }
          // captured_after already bounds the low end, so this is in-window.
          assets.add(asset);
          sawWithinWindow = true;
        }
        // Stop only once an entire page falls beyond the window end: pages run
        // coarsely oldest-first, so once none of a page's assets reach back
        // into the window, no later page will either. Stopping on the first
        // past-end asset (the previous behaviour) dropped in-window assets that
        // trailed an out-of-window one within the same page.
        reachedEnd = page.assets.isNotEmpty && !sawWithinWindow;
        next = reachedEnd ? null : page.nextUrl;
      } while (next != null);
      if (reachedEnd) {
        _log.info('[LR-SCAN] early-stop fired (asset newer than window end)');
      }
    }
    _log.info('[LR-SCAN] total collected within windows=${assets.length}');
    return assets;
  }

  Future<List<LightroomAsset>> _fetchAlbumAssets(
    String catalogId,
    List<String> albumIds,
  ) async {
    final assets = <LightroomAsset>[];
    for (final albumId in albumIds) {
      String? next;
      do {
        final page = await _api.listAlbumAssets(
          catalogId,
          albumId,
          nextUrl: next,
        );
        assets.addAll(page.assets);
        next = page.nextUrl;
      } while (next != null);
    }
    return assets;
  }

  /// What placing media on a dive needs: its profile and its media clock.
  /// Null when the dive is gone or has no profile to place anything on.
  Future<_DivePlacement?> _placementFor(String diveId) async {
    final dive = await _diveRepository.getDiveById(diveId);
    if (dive == null || dive.profile.isEmpty) return null;
    return (
      profile: dive.profile,
      clock: DiveMediaClock.forDive(
        dive,
        primarySourceEntry: await _diveRepository.getPrimarySourceEntry(diveId),
      ),
    );
  }

  /// Creates the media row for [asset] on [diveId] and places it.
  ///
  /// [placements] is a scan's per-dive cache of [_placementFor]; without one
  /// (a single confirmed suggestion) the dive is read for this asset alone.
  Future<void> _attach(
    LightroomAsset asset, {
    required String diveId,
    required ConnectedAccount account,
    Map<String, Future<_DivePlacement?>>? placements,
  }) async {
    final placement = await (placements == null
        ? _placementFor(diveId)
        : placements.putIfAbsent(diveId, () => _placementFor(diveId)));
    final row = _prepare(
      asset,
      diveId: diveId,
      account: account,
      at: placement,
    );
    final saved = await _mediaRepository.createMedia(row.item);
    final enrichment = row.enrichment;
    if (enrichment != null) {
      await _mediaRepository.saveEnrichment(enrichment);
    }
    _enqueueUpload(saved.id);
  }

  /// The media row [asset] becomes on [diveId], under a fresh id of its
  /// own, with its place in the dive when [at] gives one.
  PreparedMedia _prepare(
    LightroomAsset asset, {
    required String diveId,
    required ConnectedAccount account,
    required _DivePlacement? at,
  }) {
    final now = _now();
    final item = domain.MediaItem(
      id: const Uuid().v4(),
      diveId: diveId,
      mediaType: asset.isVideo
          ? domain.MediaType.video
          : domain.MediaType.photo,
      takenAt: asset.captureDate!,
      originalFilename: asset.fileName,
      latitude: asset.latitude,
      longitude: asset.longitude,
      durationSeconds: asset.videoDurationSeconds,
      sourceType: MediaSourceType.serviceConnector,
      connectorAccountId: account.id,
      remoteAssetId: asset.id,
      createdAt: now,
      updatedAt: now,
    );
    if (at == null) return (item: item, enrichment: null);
    final result = _enrichmentService.calculateEnrichment(
      profile: at.profile,
      diveStartTime: at.clock.countsFrom,
      photoTime: asset.captureDate!,
    );
    if (result.depthMeters == null &&
        result.matchConfidence == domain.MatchConfidence.noProfile) {
      return (item: item, enrichment: null);
    }
    return (
      item: item,
      enrichment: domain.MediaEnrichment(
        id: '',
        mediaId: item.id,
        diveId: diveId,
        depthMeters: result.depthMeters,
        temperatureCelsius: result.temperatureCelsius,
        elapsedSeconds: result.elapsedSeconds,
        matchConfidence: result.matchConfidence,
        timestampOffsetSeconds: result.timestampOffsetSeconds,
        createdAt: now,
      ),
    );
  }

  /// Dive time bounds with the gallery scanner's fallbacks: entry falls
  /// back to the dive's dateTime; exit to entry + runtime, or one hour.
  ///
  /// The window is the dive's as its camera reads it, so an asset is
  /// matched, and fetched, on the clock [_placementFor] then places it by
  /// (issue #4539).
  DiveBounds _boundsFor(Dive dive) {
    final entry = dive.entryTime ?? dive.dateTime;
    final exit =
        dive.exitTime ??
        (dive.effectiveRuntime != null
            ? entry.add(dive.effectiveRuntime!)
            : entry.add(const Duration(minutes: 60)));
    return DiveBounds(
      diveId: dive.id,
      entryTime: DiveMediaClock.onCameraClock(dive, entry),
      exitTime: DiveMediaClock.onCameraClock(dive, exit),
    );
  }
}
