import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// The media viewer's sound: whether its videos are muted, and how loud they
/// play when they are not (issue #4817).
///
/// Most dive video carries only water, bubbles and breathing, so it starts
/// muted. The viewer page owns one for as long as it is open: an unmute
/// carries on to the next video swiped to, and the next viewer opened starts
/// muted again. Nothing is persisted.
class ViewerAudio extends ChangeNotifier {
  bool _muted = true;
  double _level = 1.0;

  /// The last level above zero, which an unmute from zero goes back to.
  double _lastAudible = 1.0;

  /// Whether the videos play silent: muted, or turned down to zero.
  bool get muted => _muted;

  /// How loud the videos play when not muted, from 0 to 1. Kept while muted.
  double get level => _level;

  /// The volume to give a player: 0 when muted, else [level].
  double get effectiveVolume => _muted ? 0.0 : _level;

  /// Mutes, or unmutes at [level]; from a level of zero, at the last level
  /// above zero instead, so the unmute is heard.
  void toggleMute() {
    if (_muted) {
      _muted = false;
      if (_level == 0) _level = _lastAudible;
    } else {
      _muted = true;
    }
    notifyListeners();
  }

  /// Sets the level, clamped to 0..1. A level above zero unmutes; zero
  /// counts as muted.
  void setLevel(double level) {
    final clamped = level.clamp(0.0, 1.0);
    final muted = clamped == 0;
    if (clamped == _level && muted == _muted) return;
    _level = clamped;
    _muted = muted;
    if (clamped > 0) _lastAudible = clamped;
    notifyListeners();
  }

  /// Gives [controller] the viewer's volume.
  Future<void> applyTo(VideoPlayerController controller) =>
      controller.setVolume(effectiveVolume);
}
