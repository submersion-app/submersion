import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
/// neither does a dive with no profile. The leave that follows such an enter
/// writes nothing either: something else may own the cursor then (profile
/// playback drives the same one), and it is not this hover's to clear.
///
/// The returned handler remembers whether its last enter set the cursor, so
/// an enter and its leave must go to the same handler; the media section
/// sees to that.
///
/// It takes the [ProviderContainer], not a `WidgetRef`: a thumbnail removed
/// while hovered reports its leave after the frame, which can be after the
/// page's widgets, and any ref of theirs, are gone. The cursor provider
/// outlives the page, so that leave must still be able to clear it. Once the
/// container itself is disposed there is no cursor left to clear, and the
/// handler does nothing.
void Function(MediaItem? item) mediaHoverCursorHandler(
  ProviderContainer container,
  Dive dive,
) {
  // Whether the cursor is where this handler's last enter put it.
  var setCursor = false;

  // Clears the cursor, but only if this handler's last enter set it.
  void release() {
    if (!setCursor) return;
    setCursor = false;
    setProfileCursorSecondsIn(container, dive.id, const [], null);
  }

  void onHover(MediaItem? item) {
    if (item == null) {
      release();
      return;
    }
    // The series the chart draws, as watchChartProfile resolves it (#543),
    // read now rather than when the handler was made: the diver may have
    // switched source since.
    final profile =
        container.read(activeSourceProfileProvider(dive.id))?.points ??
        dive.profile;
    final marker = profile.isEmpty
        ? null
        : photoMarkerFor(item, maxProfileSeconds: profile.last.timestamp);
    if (marker == null) {
      // No place for this item. An enter is not always preceded by the
      // previous item's leave, so the mark that item set goes now.
      release();
      return;
    }
    setProfileCursorSecondsIn(
      container,
      dive.id,
      profile,
      marker.elapsedSeconds,
    );
    setCursor = true;
  }

  return (item) {
    try {
      onHover(item);
    } on StateError {
      // The container was disposed (the app or a test tore the provider
      // scope down in the frame the thumbnail went away). Reading it is the
      // only way to find that out: Riverpod keeps its disposed flag
      // internal, and a disposed container throws a StateError on any read.
    }
  };
}
