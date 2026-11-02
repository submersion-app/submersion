import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Clears index rows whose file the OS has taken, for the daily storage
/// cleanup (issue #3341).
///
/// A partial purge leaves a pool's directory in place, so nothing else can see
/// it: those rows would go on counting towards the pool's size and its cap. It
/// runs here rather than with the media cache's eviction because that needs a
/// media store attached, and a diver with only local photos has a thumbnail
/// pool too.
///
/// Phones only, since only there does the OS empty these directories.
class MediaCacheIndexSweep {
  MediaCacheIndexSweep({
    required Future<bool> Function() osManagesCaches,
    required Future<MediaCacheStore> Function() store,
  }) : _osManagesCaches = osManagesCaches,
       _store = store;

  final Future<bool> Function() _osManagesCaches;
  final Future<MediaCacheStore> Function() _store;
  final _log = LoggerService.forClass(MediaCacheIndexSweep);

  /// Always reports nothing reclaimed: the files had already gone, so removing
  /// their rows gives back no space. A dry run has nothing to measure.
  Future<ScratchSweepReport> run({required bool dryRun}) async {
    if (dryRun || !await _osManagesCaches()) return ScratchSweepReport.empty;
    final dropped = await (await _store()).dropMissingEntries();
    if (dropped > 0) _log.info('Dropped $dropped dead media cache rows');
    return ScratchSweepReport.empty;
  }
}
