import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';

/// Removes unlinked media rows: originally the one-time backlog left by the
/// old FK SET NULL cascade, now the safety net behind the rule that every
/// row carries a dive or site link from its insert.
///
/// Runs on every launch rather than once behind a flag. The query is one
/// indexed SELECT that is empty on a healthy library, and a device that has
/// not upgraded yet can still sync an unlinked row in; a per-launch pass
/// removes it the next day instead of never. Rows younger than 24 hours are
/// left alone so an insert racing this query is never caught mid-flight.
///
/// Runs through the repository layer, not a schema migration: tombstones
/// need the live sync clock, and the coordinator's enqueue-before-delete
/// path needs the transfer queue. Every step is idempotent.
class MediaOrphanBacklogSweep {
  MediaOrphanBacklogSweep({
    required MediaRepository mediaRepository,
    required MediaDeletionCoordinator coordinator,
  }) : _mediaRepository = mediaRepository,
       _coordinator = coordinator;

  static const Duration ageGuard = Duration(hours: 24);

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _coordinator;
  final _log = LoggerService.forClass(MediaOrphanBacklogSweep);

  /// Returns the number of rows swept. Throws on repository failure so the
  /// caller can log it; the next launch simply runs again.
  Future<int> run({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(ageGuard);
    final ids = await _mediaRepository.getSweepableOrphanIds(olderThan: cutoff);
    if (ids.isNotEmpty) {
      _log.info('Sweeping ${ids.length} unlinked media rows');
      await _coordinator.deleteMultipleMedia(ids);
    }
    return ids.length;
  }
}
