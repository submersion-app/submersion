import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/maintenance/maintenance_ledger_repository.dart';
import 'package:submersion/core/services/maintenance/startup_maintenance_task.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// One-shot backfill for photo/video profile markers (issues #511, #524).
///
/// Media linked to a dive before the profile-marker feature shipped never had
/// their [MediaEnrichment] computed, so no marker renders on the dive profile
/// chart. This task computes the missing enrichment using the same
/// [EnrichmentService] the import/link path uses, so backfilled markers match
/// relinked ones exactly.
///
/// Convergence (issue #524): every candidate media item it visits is recorded
/// in the maintenance ledger (whether it was enriched or the attempt failed
/// deterministically), so it drops out of [pendingWork] and the backlog reaches
/// zero. Combined with the runner's cheap [pendingWork] gate, a caught-up launch
/// does no per-dive work at all - only a single indexed COUNT.
class MediaEnrichmentBackfillService implements StartupMaintenanceTask {
  final MediaRepository _mediaRepository;
  final DiveRepository _diveRepository;
  final MaintenanceLedgerRepository _ledger;
  final EnrichmentService _enrichmentService;
  final _log = LoggerService.forClass(MediaEnrichmentBackfillService);

  MediaEnrichmentBackfillService({
    required MediaRepository mediaRepository,
    required DiveRepository diveRepository,
    MaintenanceLedgerRepository? ledger,
    EnrichmentService enrichmentService = const EnrichmentService(),
  }) : _mediaRepository = mediaRepository,
       _diveRepository = diveRepository,
       _ledger = ledger ?? MaintenanceLedgerRepository(),
       _enrichmentService = enrichmentService;

  // Single source of truth shared with the candidate queries, so the ledger
  // task_name written here always matches the one the queries exclude on.
  @override
  String get name => MediaRepository.enrichmentBackfillTaskName;

  @override
  String get progressLabel => 'Optimizing dive data';

  @override
  Future<int> pendingWork() =>
      _mediaRepository.countEnrichmentBackfillCandidates();

  @override
  Future<void> run({MaintenanceProgressCallback? onProgress}) =>
      backfill(onProgress: onProgress);

  /// Enriches every candidate media item. Best-effort per item: a failure is
  /// logged, the item is still recorded in the ledger (a deterministic failure
  /// must not re-qualify forever), and the rest proceed. Returns the number of
  /// items for which enrichment was persisted.
  Future<int> backfill({MaintenanceProgressCallback? onProgress}) async {
    final dives = await _mediaRepository.divesNeedingEnrichmentBackfill();
    if (dives.isEmpty) return 0;

    var enriched = 0;
    var processed = 0;
    for (final d in dives) {
      // Profile-only load (not the full dive graph): enrichment needs just the
      // primary profile points and the effective entry time.
      final profile = await _diveRepository.getDiveProfile(d.diveId);
      if (profile.isEmpty) continue; // defensive; candidates have a profile
      final start = DateTime.fromMillisecondsSinceEpoch(
        d.diveStartMs,
        isUtc: true,
      );
      final media = await _mediaRepository.candidateEnrichmentMediaForDive(
        d.diveId,
      );
      for (final item in media) {
        try {
          final result = _enrichmentService.calculateEnrichment(
            profile: profile,
            diveStartTime: start,
            photoTime: item.takenAt,
          );
          // Mirror the import path: don't persist a row we couldn't position.
          final unpositioned =
              result.depthMeters == null &&
              result.matchConfidence == MatchConfidence.noProfile;
          if (!unpositioned) {
            await _mediaRepository.saveEnrichment(
              MediaEnrichment(
                id: '',
                mediaId: item.id,
                diveId: d.diveId,
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
          // Terminal: recorded whether enriched or unpositioned, so it drops
          // out of pendingWork on the next launch.
          await _ledger.markProcessed(name, [item.id]);
        } catch (e, stackTrace) {
          // A deterministic failure (e.g. a constraint) would otherwise re-run
          // every launch (issue #524). Record it so the backlog still
          // converges; the loud log surfaces the data-quality issue.
          _log.error(
            'Enrichment failed for media ${item.id} on dive ${d.diveId}; '
            'recording as processed to avoid a launch-time re-scan loop',
            error: e,
            stackTrace: stackTrace,
          );
          await _ledger.markProcessed(name, [item.id]);
        }
        processed++;
        onProgress?.call(processed);
      }
    }

    if (enriched > 0) {
      _log.info('Backfilled enrichment for $enriched media item(s)');
    }
    return enriched;
  }
}
