import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What dive details does when a media thumbnail is hovered (the item) or
/// the pointer leaves it (null): moves [dive]'s shared profile cursor to the
/// moment the item was taken, or clears it (issue #4524).
///
/// The cursor is the one every profile surface follows
/// ([profileTrackingIndexProvider]), so the pinned strip shows its line, dot
/// and tooltip there, and the full chart and the cards that track it follow
/// too, exactly as for a scrub.
///
/// An item with no place on the profile ([photoMarkerFor]: a document, an
/// unmatched photo, a capture time far outside the dive) writes nothing, and
/// neither does a dive with no profile.
///
/// It takes the [ProviderContainer], not a `WidgetRef`: a thumbnail removed
/// while hovered reports its leave after the frame, which can be after the
/// page's widgets, and any ref of theirs, are gone. The cursor provider
/// outlives the page, so that leave must still be able to clear it.
void Function(MediaItem? item) mediaHoverCursorHandler(
  ProviderContainer container,
  Dive dive,
) {
  void write(int? index) {
    final cursor = container.read(
      profileTrackingIndexProvider(dive.id).notifier,
    );
    if (cursor.state != index) cursor.state = index;
  }

  return (item) {
    if (item == null) {
      write(null);
      return;
    }
    // The series the chart draws, as watchChartProfile resolves it (#543),
    // read now rather than when the handler was made: the diver may have
    // switched source since.
    final profile =
        container.read(activeSourceProfileProvider(dive.id))?.points ??
        dive.profile;
    if (profile.isEmpty) return;
    final marker = photoMarkerFor(
      item,
      maxProfileSeconds: profile.last.timestamp,
    );
    if (marker == null) return;
    write(indexForTimestamp(profile, marker.elapsedSeconds));
  };
}
