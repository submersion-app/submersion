import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';

/// Applies a [MediaTimeChoice] to a media item (issue #1090).
///
/// One write to the media row, then one enrichment pass over its dive. The
/// enricher is the only writer of enrichment rows and reads the pin on that
/// pass, so the chart, the 3D scene and the viewer all reposition on the
/// next media tick instead of waiting for a later backfill. Rows that
/// already match are left alone by the enricher, so the pass costs one
/// write.
class MediaTimePinner {
  const MediaTimePinner({required this.repository, required this.enricher});

  final MediaRepository repository;
  final DiveMediaEnricher enricher;

  Future<void> apply(MediaItem item, MediaTimeChoice choice) async {
    final diveId = item.diveId;
    // A moment in a dive needs a dive; nothing to pin against otherwise.
    if (diveId == null) return;
    final elapsedSeconds = switch (choice) {
      MediaTimePinned(:final elapsedSeconds) => elapsedSeconds,
      MediaTimeReset() => null,
    };
    await repository.setManualElapsedSeconds(item.id, elapsedSeconds);
    await enricher.enrichMissingForDive(diveId);
  }
}
