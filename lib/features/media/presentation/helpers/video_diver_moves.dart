import 'package:video_player/video_player.dart';

/// Players the diver has moved by hand: a scrub, a tap on the bar, a step
/// or a Next sighting. The viewer's own start seek (a species' first
/// sighting, issue #5084) leaves them where the diver put them, even back
/// at 0:00. Weak, so a released player is forgotten with it.
final Expando<bool> _moved = Expando<bool>('diverMovedVideo');

/// Records that the diver moved [controller] by hand.
void markDiverMoved(VideoPlayerController controller) =>
    _moved[controller] = true;

/// Whether the diver has moved [controller] by hand.
bool diverMoved(VideoPlayerController controller) =>
    _moved[controller] ?? false;
