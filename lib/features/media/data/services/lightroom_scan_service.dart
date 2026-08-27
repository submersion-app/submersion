import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
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
    final catalogId = account.accountIdentifier;
    if (catalogId == null || dives.isEmpty) return summary;

    final bounds = [for (final dive in dives) _boundsFor(dive)];
    final spans = mergeWindows(bounds);

    final existing = await _mediaRepository.getConnectorRemoteAssetIds();
    final suggested = await _mediaRepository
        .getPendingSuggestionRemoteAssetIds();
    final albumIds = await state.albumIds();

    final assets = albumIds.isEmpty
        ? await _fetchCatalogAssets(catalogId, spans)
        : await _fetchAlbumAssets(catalogId, albumIds);

    final seenThisScan = <String>{};
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
      final match = _matcher.matchTimestamp(
        takenAt: asset.captureDate!,
        dives: bounds,
      );
      switch (match.kind) {
        case TimestampMatchKind.none:
          break;
        case TimestampMatchKind.confident:
          await _attach(asset, diveId: match.diveId!, account: account);
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

  Future<void> _attach(
    LightroomAsset asset, {
    required String diveId,
    required ConnectedAccount account,
  }) async {
    final now = _now();
    final saved = await _mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
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
      ),
    );

    final dive = await _diveRepository.getDiveById(diveId);
    final profile = dive?.profile ?? const [];
    if (dive != null && profile.isNotEmpty) {
      final result = _enrichmentService.calculateEnrichment(
        profile: profile,
        diveStartTime: dive.effectiveEntryTime,
        photoTime: asset.captureDate!,
      );
      if (result.depthMeters != null ||
          result.matchConfidence != domain.MatchConfidence.noProfile) {
        await _mediaRepository.saveEnrichment(
          domain.MediaEnrichment(
            id: '',
            mediaId: saved.id,
            diveId: dive.id,
            depthMeters: result.depthMeters,
            temperatureCelsius: result.temperatureCelsius,
            elapsedSeconds: result.elapsedSeconds,
            matchConfidence: result.matchConfidence,
            timestampOffsetSeconds: result.timestampOffsetSeconds,
            createdAt: now,
          ),
        );
      }
    }
    _enqueueUpload(saved.id);
  }

  /// Dive time bounds with the gallery scanner's fallbacks: entry falls
  /// back to the dive's dateTime; exit to entry + runtime, or one hour.
  DiveBounds _boundsFor(Dive dive) {
    final entry = dive.entryTime ?? dive.dateTime;
    final exit =
        dive.exitTime ??
        (dive.effectiveRuntime != null
            ? entry.add(dive.effectiveRuntime!)
            : entry.add(const Duration(minutes: 60)));
    return DiveBounds(diveId: dive.id, entryTime: entry, exitTime: exit);
  }
}
