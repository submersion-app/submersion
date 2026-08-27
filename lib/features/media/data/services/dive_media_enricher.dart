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
    required this.saveEnrichments,
    this.enrichmentService = const EnrichmentService(),
  });

  /// Loads a dive with its profile hydrated (e.g. `DiveRepository.getDiveById`,
  /// which populates `profile`; list queries do not).
  final Future<Dive?> Function(String diveId) loadDive;
  final Future<List<MediaItem>> Function(String diveId) loadMediaForDive;

  /// Persists a whole dive's new/changed rows in one call
  /// (`MediaRepository.saveEnrichments`: one transaction, one table tick).
  /// Per-row saves here committed once per photo, and the backfill runs
  /// from the OPEN media viewer: whenever the burst outlasted the 300ms
  /// tick debounce, the library query and the other media providers re-ran
  /// while the user was mid-swipe.
  final Future<void> Function(List<MediaEnrichment> enrichments)
  saveEnrichments;
  final EnrichmentService enrichmentService;

  /// Enriches every media item linked to [diveId] whose stored enrichment is
  /// missing, or disagrees with what the dive's profile says it should be.
  ///
  /// Recomputing every item and writing only on a difference is what makes
  /// this a repair as well as a backfill. Skipping anything that merely HAD a
  /// row meant two classes of wrong data could never heal: rows surviving a
  /// re-link still pointing at the previous dive, and rows written before the
  /// taken_at wall-clock-UTC fix, whose elapsed time is skewed by the host's
  /// offset and whose depth is clamped to the first profile point. The only
  /// remedy used to be unlinking and re-adding the photo.
  ///
  /// Rows that already match are left untouched. That matters beyond saving a
  /// query: mediaEnrichment is an HLC-synced entity, so rewriting an unchanged
  /// row would bump its clock and ship a no-op to every other device.
  ///
  /// Returns the number of rows written (0 means nothing changed, so callers
  /// can skip a refresh).
  Future<int> enrichMissingForDive(String diveId) async {
    final dive = await loadDive(diveId);
    if (dive == null || dive.profile.isEmpty) return 0;

    final media = await loadMediaForDive(diveId);
    final toSave = <MediaEnrichment>[];
    for (final item in media) {
      // Signatures are attached to a dive but not moments within it, and the
      // chart excludes them regardless — don't fabricate a depth/time for one.
      if (item.mediaType == MediaType.instructorSignature) continue;

      // A pinned item (issue #1090) is positioned from the diver's offset,
      // never from its capture time, so a backfill converges on the pin
      // instead of reverting it.
      final manual = item.manualElapsedSeconds;
      final result = manual != null
          ? enrichmentService.calculateEnrichmentAtElapsed(
              profile: dive.profile,
              elapsedSeconds: manual,
            )
          : enrichmentService.calculateEnrichment(
              profile: dive.profile,
              diveStartTime: dive.effectiveEntryTime,
              photoTime: item.takenAt,
            );

      // Mirror the gallery path: don't persist a row we couldn't actually
      // place (no depth and no usable profile match). An existing row is left
      // alone rather than overwritten with the unplaceable result.
      if (result.depthMeters == null &&
          result.matchConfidence == MatchConfidence.noProfile) {
        continue;
      }

      final existing = item.enrichment;
      if (existing != null && _matches(existing, result, diveId)) continue;

      toSave.add(
        MediaEnrichment(
          // Keep the row's identity so the repository updates in place
          // instead of minting a second row for the same media.
          id: existing?.id ?? '',
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
    }
    // One batched save for the whole dive; skipped entirely when nothing
    // changed, so the idempotent re-run costs no write and no tick.
    if (toSave.isNotEmpty) {
      await saveEnrichments(toSave);
    }
    return toSave.length;
  }

  /// Whether [existing] already records exactly what [result] computes for
  /// [diveId].
  ///
  /// Compares the computed values and the dive they belong to, not the row's
  /// own identity or bookkeeping: `id` and `createdAt` are persisted but say
  /// nothing about whether the enrichment is correct, and the repository's
  /// update path does not rewrite them either. A partial match still counts
  /// as a mismatch, since a stored row disagreeing on any value is wrong.
  bool _matches(
    MediaEnrichment existing,
    EnrichmentResult result,
    String diveId,
  ) =>
      existing.diveId == diveId &&
      existing.depthMeters == result.depthMeters &&
      existing.temperatureCelsius == result.temperatureCelsius &&
      existing.elapsedSeconds == result.elapsedSeconds &&
      existing.matchConfidence == result.matchConfidence &&
      existing.timestampOffsetSeconds == result.timestampOffsetSeconds;
}
