import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/maintenance/startup_maintenance_task.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// One-shot backfill for photo/video profile markers (issue #511).
///
/// Media linked to a dive before the profile-marker feature shipped never had
/// their [MediaEnrichment] computed, so no marker renders on the dive profile
/// chart — unlinking and relinking the media is currently the only way to make
/// the marker appear. This service computes the missing enrichment for
/// existing dive-linked media using the same [EnrichmentService] the
/// import/link path uses, so backfilled markers match relinked ones exactly.
///
/// It is safe to run on every launch (see [StartupMaintenanceTask]): the
/// candidate query only returns dives that still have unenriched media *and* a
/// profile to enrich against, so each item enriched drops out of the set and
/// the work naturally converges to zero.
class MediaEnrichmentBackfillService implements StartupMaintenanceTask {
  final MediaRepository _mediaRepository;
  final DiveRepository _diveRepository;
  final EnrichmentService _enrichmentService;
  final _log = LoggerService.forClass(MediaEnrichmentBackfillService);

  MediaEnrichmentBackfillService({
    required MediaRepository mediaRepository,
    required DiveRepository diveRepository,
    EnrichmentService enrichmentService = const EnrichmentService(),
  }) : _mediaRepository = mediaRepository,
       _diveRepository = diveRepository,
       _enrichmentService = enrichmentService;

  @override
  String get name => 'photo-enrichment-backfill';

  /// [StartupMaintenanceTask] entry point; delegates to [backfill], discarding
  /// the count the runner has no use for.
  @override
  Future<void> run() => backfill();

  /// Computes and saves enrichment for every dive-linked media item that lacks
  /// it, on dives that have a profile. Best-effort per dive: an error on one
  /// dive is logged and does not abort the rest. Returns the number of media
  /// items enriched.
  Future<int> backfill() async {
    final diveIds = await _mediaRepository.diveIdsNeedingEnrichmentBackfill();
    if (diveIds.isEmpty) return 0;

    var enriched = 0;
    for (final diveId in diveIds) {
      try {
        enriched += await _backfillDive(diveId);
      } catch (e, stackTrace) {
        // One bad dive must not stop the rest; a later launch retries it.
        _log.error(
          'Enrichment backfill failed for dive $diveId',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (enriched > 0) {
      _log.info('Backfilled enrichment for $enriched media item(s)');
    }
    return enriched;
  }

  Future<int> _backfillDive(String diveId) async {
    final dive = await _diveRepository.getDiveById(diveId);
    if (dive == null || dive.profile.isEmpty) return 0;

    final media = await _mediaRepository.getMediaForDive(diveId);
    var enriched = 0;
    for (final item in media) {
      if (item.enrichment != null) continue;
      // Signatures are not dive-moment media and never get a marker.
      if (item.mediaType == MediaType.instructorSignature) continue;

      final result = _enrichmentService.calculateEnrichment(
        profile: dive.profile,
        diveStartTime: dive.effectiveEntryTime,
        photoTime: item.takenAt,
      );
      // Mirror the import path: don't persist a row we couldn't position.
      if (result.depthMeters == null &&
          result.matchConfidence == MatchConfidence.noProfile) {
        continue;
      }

      await _mediaRepository.saveEnrichment(
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
