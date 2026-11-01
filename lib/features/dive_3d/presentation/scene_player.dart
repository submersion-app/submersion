import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Play/pause/rewind-at-end driver for a scene's scrub [position]. Notifies
/// whenever [isPlaying] changes, including when the timeline reaches the end
/// and stops on its own, with no call from its owner.
class ScenePlayer extends ChangeNotifier {
  ScenePlayer({
    required TickerProvider vsync,
    required Duration duration,
    required this.position,
  }) : _controller = AnimationController(
         vsync: vsync,
         duration: duration,
         // Playback is content the diver asked for, not decoration: left at
         // the default, a reduce-motion setting runs it at 5% of [duration].
         animationBehavior: AnimationBehavior.preserve,
       ) {
    _controller
      ..addListener(() => position.value = _controller.value)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) notifyListeners();
      });
  }

  final ValueNotifier<double> position;
  final AnimationController _controller;

  bool get isPlaying => _controller.isAnimating;

  /// Resumes from [position], rewinding to 0 first if it is already at the
  /// end; stops if already playing.
  void togglePlay() {
    if (isPlaying) {
      _controller.stop();
    } else {
      _controller.forward(from: position.value >= 1.0 ? 0 : position.value);
    }
    notifyListeners();
  }

  /// Interrupts playback without resuming it, for a manual scrub.
  void stop() {
    if (!isPlaying) return;
    _controller.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
