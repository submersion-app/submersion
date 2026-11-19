import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// A route as a sitting holds it, for the 3D views to draw while it is open
/// over the track page (issue #4527, plan 5): a correction held in the
/// sitting, or still being made on the align page, is seen in 3D without
/// being written. Null while no view shows one.
///
/// Read only by [navTrackShownIn3dProvider]: the track page follows the
/// route as stored, so a preview never looks to it like a change underneath.
final navTrackPreviewProvider = StateProvider.family<NavTrack?, String>(
  (ref, id) => null,
);

/// The route the 3D views draw: the preview while one is shown, else the
/// route as stored, with its console markers.
final navTrackShownIn3dProvider = FutureProvider.autoDispose
    .family<NavTrack?, String>((ref, id) async {
      final preview = ref.watch(navTrackPreviewProvider(id));
      if (preview != null) return preview;
      return ref.watch(navTrackWithMarkersProvider(id).future);
    });

/// Whether a 3D view would draw [a] differently from [b]: another site
/// (whose terrain the seascape shows), anchor, end, trust, rotation or
/// scale.
bool navTrackShownDifferently(NavTrack a, NavTrack b) =>
    a.siteId != b.siteId ||
    a.anchor != b.anchor ||
    a.endMode != b.endMode ||
    a.endPoint != b.endPoint ||
    a.trustFraction != b.trustFraction ||
    a.headingOffsetDeg != b.headingOffsetDeg ||
    a.scaleFactor != b.scaleFactor;

/// Opens a 3D view with [push] showing [shown], the route as a sitting
/// holds it: when it would be drawn differently from [stored], it is the 3D
/// views' preview until the view closes. Writes nothing.
///
/// The preview is cleared through the provider's own controller, read
/// before the view opens: the page that opened it may be gone by the time
/// the view closes.
Future<void> showNavTrackIn3d(
  WidgetRef ref, {
  required NavTrack shown,
  required NavTrack stored,
  required Future<void> Function() push,
}) async {
  final preview = ref.read(navTrackPreviewProvider(shown.id).notifier);
  final previewing = navTrackShownDifferently(shown, stored);
  if (previewing) preview.state = shown;
  try {
    await push();
  } finally {
    // Only this view's preview: another opened since keeps its own.
    if (previewing && preview.mounted && identical(preview.state, shown)) {
      preview.state = null;
    }
  }
}

/// Drops whatever preview [preview] holds: the track page does so when its
/// sitting ends or the page closes, so a view that never reported closing
/// cannot leave a correction nobody holds any more.
///
/// A controller whose provider has gone (the app closing) holds nothing.
void dropNavTrackPreview(StateController<NavTrack?> preview) {
  if (preview.mounted && preview.state != null) preview.state = null;
}
