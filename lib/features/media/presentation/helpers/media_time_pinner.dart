import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';

/// Applies a [MediaTimeChoice] to a media item (issue #1090).
///
/// One write, to the media row for a pin or to the dive for a shift (issue
/// #4539), then one enrichment pass over the dive. The enricher is the only
/// writer of enrichment rows and reads both on that pass, so the chart, the
/// 3D scene and the viewer all reposition on the next media tick instead of
/// waiting for a later backfill. Rows that already match are left alone by
/// the enricher, so a pin costs one write.
class MediaTimePinner {
  const MediaTimePinner({
    required this.repository,
    required this.enricher,
    required this.setDiveShift,
  });

  final MediaRepository repository;
  final DiveMediaEnricher enricher;

  /// Records a dive's media time shift
  /// (`DiveRepository.setMediaTimeOffsetSeconds`).
  final Future<void> Function(String diveId, int seconds) setDiveShift;

  static final _log = LoggerService.forClass(MediaTimePinner);

  /// What the Set-time dialog needs to offer a dive-wide shift for [item];
  /// null when the item has no place by capture time to shift from.
  ///
  /// A dive that will not load costs the shift, not the dialog: the diver
  /// can still pin the item, which needs only the profile they are shown.
  Future<MediaAutomaticTime?> automaticTimeFor(MediaItem item) async {
    try {
      return await enricher.automaticTimeFor(item);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read the automatic time of media: ${item.id}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> apply(MediaItem item, MediaTimeChoice choice) async {
    final diveId = item.diveId;
    // A moment in a dive needs a dive; nothing to pin against otherwise.
    if (diveId == null) return;
    switch (choice) {
      case MediaTimePinned(:final elapsedSeconds):
        await repository.setManualElapsedSeconds(item.id, elapsedSeconds);
      case MediaTimeReset():
        await repository.setManualElapsedSeconds(item.id, null);
      case MediaTimeDiveShifted(:final shiftSeconds):
        await setDiveShift(diveId, shiftSeconds);
        // The item the diver lined up sits there by the shift now. A pin
        // left on it would hold it still the next time the shift changes.
        if (item.manualElapsedSeconds != null) {
          await repository.setManualElapsedSeconds(item.id, null);
        }
      case MediaTimeDiveShiftRemoved():
        await setDiveShift(diveId, 0);
    }
    await enricher.enrichMissingForDive(diveId);
  }
}
