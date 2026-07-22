import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Positions a dive's linked media on the profile chart by computing and
/// saving a [MediaEnrichment] (elapsed seconds + depth) for every item that
/// has a capture time but no enrichment yet.
///
/// The gallery and Lightroom import paths enrich at import time, but the local
/// file/folder linking path only creates the [MediaItem] row. Without an
/// enrichment row the chart's marker builder drops the item
/// (`photo_marker_layout` skips `enrichment == null`), so a linked photo shows
/// in the grid but never on the depth/time chart. This service closes that gap
/// and, being idempotent, doubles as a backfill for already-linked media.
class DiveMediaEnricher {
  DiveMediaEnricher({
    required this.loadDive,
    required this.loadMediaForDive,
    required this.saveEnrichment,
    this.enrichmentService = const EnrichmentService(),
  });

  /// Loads a dive with its profile hydrated (e.g. `DiveRepository.getDiveById`,
  /// which populates `profile`; list queries do not).
  final Future<Dive?> Function(String diveId) loadDive;
  final Future<List<MediaItem>> Function(String diveId) loadMediaForDive;
  final Future<void> Function(MediaEnrichment enrichment) saveEnrichment;
  final EnrichmentService enrichmentService;

  /// Enriches every media item linked to [diveId] that has no enrichment yet.
  /// Idempotent — already-enriched items are skipped — so it is safe to call
  /// after a fresh link and repeatedly as a backfill. Returns the number of
  /// items newly enriched (0 means nothing changed; callers can skip a
  /// refresh).
  Future<int> enrichMissingForDive(String diveId) async {
    final dive = await loadDive(diveId);
    if (dive == null || dive.profile.isEmpty) return 0;

    final media = await loadMediaForDive(diveId);
    var enriched = 0;
    for (final item in media) {
      if (item.enrichment != null) continue;
      // Signatures are attached to a dive but not moments within it, and the
      // chart excludes them regardless — don't fabricate a depth/time for one.
      if (item.mediaType == MediaType.instructorSignature) continue;

      final result = enrichmentService.calculateEnrichment(
        profile: dive.profile,
        diveStartTime: dive.effectiveEntryTime,
        photoTime: item.takenAt,
      );

      // Mirror the gallery path: don't persist a row we couldn't actually
      // place (no depth and no usable profile match).
      if (result.depthMeters == null &&
          result.matchConfidence == MatchConfidence.noProfile) {
        continue;
      }

      await saveEnrichment(
        MediaEnrichment(
          id: '',
          mediaId: item.id,
          diveId: diveId,
          depthMeters: result.depthMeters,
          temperatureCelsius: result.temperatureCelsius,
          elapsedSeconds: result.elapsedSeconds,
          matchConfidence: result.matchConfidence,
          timestampOffsetSeconds: result.timestampOffsetSeconds,
          createdAt: DateTime.now(),
        ),
      );
      enriched++;
    }
    return enriched;
  }
}
