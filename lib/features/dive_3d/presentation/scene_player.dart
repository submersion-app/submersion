import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Shared play/pause/reset-at-end timeline driver for a seascape or scene
/// scrub position, replacing the identical `AnimationController` +
/// toggle logic that used to live separately in `SiteTerrainPane`,
/// `SpatialSitePage`, `NavTrackSeascapePage`, `Dive3dPage` and
/// `NavTrack3dPage` (issue #2771).
class ScenePlayer {
  ScenePlayer({
    required TickerProvider vsync,
    required Duration duration,
    required ValueNotifier<double> position,
    VoidCallback? onEdgeReached,
  }) : _position = position,
       controller = AnimationController(vsync: vsync, duration: duration) {
    controller.addListener(() => _position.value = controller.value);
    if (onEdgeReached != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          onEdgeReached();
        }
      });
    }
  }

  final AnimationController controller;
  final ValueNotifier<double> _position;

  bool get isPlaying => controller.isAnimating;

  /// Resumes from the current position, wrapping back to 0 first if
  /// playback had already reached the end; stops if already playing.
  void togglePlay() {
    if (controller.isAnimating) {
      controller.stop();
    } else {
      if (_position.value >= 1.0) controller.value = 0;
      controller.forward(from: _position.value);
    }
  }

  /// Interrupts playback without resuming it, for a manual scrub.
  void stop() => controller.stop();

  void dispose() => controller.dispose();
}
