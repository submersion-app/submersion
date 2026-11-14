import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/presentation/widgets/media_fullscreen_controls.dart';

/// How a media player's controls follow the mouse and the video (#4487):
/// a mouse move brings them up, and while the video plays they go again once
/// the mouse rests for [MediaFullscreenMixin.fullscreenControlsTimeout] or
/// leaves the window. A paused video keeps them, and the controls bar holds
/// them while it is scrubbed or the mouse rests on it.
///
/// Works in both modes: in fullscreen it drives the fullscreen controls, and
/// otherwise the page's overlay through [videoOverlayShown] and
/// [setVideoOverlayShown].
mixin VideoControlsAutoHideMixin<T extends StatefulWidget>
    on MediaFullscreenMixin<T> {
  /// The normal-mode overlay's clock; fullscreen keeps its own.
  Timer? _overlayTimer;

  /// Set by the controls bar while it is scrubbed or under the mouse.
  bool _held = false;

  final Map<VideoPlayerController, VoidCallback> _playListeners = {};

  /// Whether the page's own overlay (outside fullscreen) is showing.
  @protected
  bool get videoOverlayShown;

  /// Shows or hides the page's own overlay (outside fullscreen).
  @protected
  void setVideoOverlayShown(bool shown);

  @override
  void dispose() {
    _overlayTimer?.cancel();
    for (final entry in _playListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    super.dispose();
  }

  // Fullscreen keeps its own clock, so the normal one stops at the switch
  // either way: left running, it would hide the overlay restored on leaving.
  @override
  void enterFullscreen() {
    cancelVideoOverlayClock();
    super.enterFullscreen();
  }

  @override
  void exitFullscreen() {
    cancelVideoOverlayClock();
    super.exitFullscreen();
  }

  bool get _controlsShown =>
      isFullscreen ? fullscreenControlsVisible : videoOverlayShown;

  /// Starts following [controller]'s play state, so a late report from the
  /// platform still sets the controls' clock right.
  void watchVideoPlayState(VideoPlayerController controller) {
    if (_playListeners.containsKey(controller)) return;
    // The last play state seen, so a position tick is told apart from a
    // change of play state.
    var wasPlaying = controller.value.isPlaying;
    void listener() {
      final playing = controller.value.isPlaying;
      if (playing == wasPlaying) return;
      wasPlaying = playing;
      if (!mounted || _held || !_controlsShown) return;
      // Playing: the clock starts. Paused: the controls stay.
      _showVideoControls(autoHide: playing);
    }

    _playListeners[controller] = listener;
    controller.addListener(listener);
  }

  /// Stops following [controller], which the page is releasing.
  void unwatchVideoPlayState(VideoPlayerController controller) {
    final listener = _playListeners.remove(controller);
    if (listener != null) controller.removeListener(listener);
    // A player released mid-scrub never reports the scrub settling.
    _held = false;
  }

  /// The mouse moved over the viewer while [video] is on screen.
  void videoPointerMoved(VideoPlayerController? video) {
    if (video == null) return;
    _showVideoControls(autoHide: video.value.isPlaying && !_held);
  }

  /// The mouse left the viewer (or the window): a playing video's controls
  /// go at once.
  void videoPointerLeft(VideoPlayerController? video) {
    if (video == null || !video.value.isPlaying || _held) return;
    hideVideoControls();
  }

  /// [video]'s controls bar holds the controls (a scrub, or the mouse on
  /// it) or lets them go: up while held, then on the usual clock if the
  /// video plays on.
  void videoHoldChanged(VideoPlayerController video, bool held) {
    // The bar may report after the page has gone.
    if (!mounted) return;
    _held = held;
    // A player already released (its page swiped away) has nothing left
    // to show controls for.
    if (!_playListeners.containsKey(video)) return;
    if (held) {
      _showVideoControls(autoHide: false);
    } else if (_controlsShown) {
      // A release only restarts the clock: controls hidden meanwhile (Space
      // mid-drag) stay hidden.
      _showVideoControls(autoHide: video.value.isPlaying);
    }
  }

  /// Cancels the normal-mode clock, for a page change or a toggle that
  /// decides the overlay itself.
  void cancelVideoOverlayClock() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
  }

  /// Hides the controls now in either mode.
  void hideVideoControls() {
    if (isFullscreen) {
      hideFullscreenControls();
      return;
    }
    cancelVideoOverlayClock();
    if (videoOverlayShown) setVideoOverlayShown(false);
  }

  void _showVideoControls({required bool autoHide}) {
    if (isFullscreen) {
      revealFullscreenControls(autoHide: autoHide);
      return;
    }
    cancelVideoOverlayClock();
    if (!videoOverlayShown) setVideoOverlayShown(true);
    if (!autoHide) return;
    _overlayTimer = Timer(MediaFullscreenMixin.fullscreenControlsTimeout, () {
      _overlayTimer = null;
      if (mounted && !isFullscreen && videoOverlayShown) {
        setVideoOverlayShown(false);
      }
    });
  }
}
