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

/// Whether [a] and [b] are placed differently: another anchor, end,
/// trust, rotation or scale.
bool navTrackPlacedDifferently(NavTrack a, NavTrack b) =>
    a.anchor != b.anchor ||
    a.endMode != b.endMode ||
    a.endPoint != b.endPoint ||
    a.trustFraction != b.trustFraction ||
    a.headingOffsetDeg != b.headingOffsetDeg ||
    a.scaleFactor != b.scaleFactor;

/// Opens a 3D view with [push] showing [shown], the route as a sitting
/// holds it: when it is placed differently from [stored], it is the 3D
/// views' preview until the view closes. Writes nothing.
Future<void> showNavTrackIn3d(
  WidgetRef ref, {
  required NavTrack shown,
  required NavTrack stored,
  required Future<void> Function() push,
}) async {
  final preview = navTrackPreviewProvider(shown.id).notifier;
  final previewing = navTrackPlacedDifferently(shown, stored);
  if (previewing) ref.read(preview).state = shown;
  try {
    await push();
  } finally {
    if (previewing) ref.read(preview).state = null;
  }
}
