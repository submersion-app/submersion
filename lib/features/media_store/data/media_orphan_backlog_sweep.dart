import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';

/// One-time cleanup of the orphaned-media-row backlog (orphan-prevention
/// spec 4.3): rows unlinked from any dive or site by past dive deletions
/// (the FK's silent SET NULL), which the dive-deletion cascade now
/// prevents going forward. Library-level source types and rows younger
/// than 24 hours are never touched (spec section 3, gate audit).
///
/// Runs through the repository layer, not a schema migration: tombstones
/// need the live sync clock, and the coordinator's enqueue-before-delete
/// path needs the transfer queue. The persisted flag is set only on
/// success, giving at-least-once execution; every step is idempotent, so
/// at-least-once is safe.
class MediaOrphanBacklogSweep {
  MediaOrphanBacklogSweep({
    required MediaRepository mediaRepository,
    required MediaDeletionCoordinator coordinator,
    required Future<SharedPreferences> Function() prefs,
  }) : _mediaRepository = mediaRepository,
       _coordinator = coordinator,
       _prefs = prefs;

  static const flagKey = 'media_orphan_backlog_swept_v1';

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _coordinator;
  final Future<SharedPreferences> Function() _prefs;
  final _log = LoggerService.forClass(MediaOrphanBacklogSweep);

  /// Runs at most once per device (persisted flag). Returns the number of
  /// rows swept (0 on skip). Throws on repository failure so the flag
  /// stays unset and the next launch retries.
  Future<int> runIfNeeded({DateTime? now}) async {
    final p = await _prefs();
    if (p.getBool(flagKey) ?? false) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(hours: 24));
    final ids = await _mediaRepository.getSweepableOrphanIds(olderThan: cutoff);
    if (ids.isNotEmpty) {
      _log.info('Sweeping ${ids.length} orphaned media rows');
      await _coordinator.deleteMultipleMedia(ids);
    }
    await p.setBool(flagKey, true);
    return ids.length;
  }
}
