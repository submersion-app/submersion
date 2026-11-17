import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What the Set-time dialog needs to place a media item in its dive (issue
/// #1090). The diver's choice is held in the photo's sitting, and written
/// by its Save (issue #4527).
class MediaTimePinner {
  const MediaTimePinner({required this.enricher});

  final DiveMediaEnricher enricher;

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
}
