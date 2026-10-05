import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

/// Fullscreen mode for a media viewer page (#1087): the page hides its own
/// overlays while [isFullscreen] is on, and this mixin asks the app shell to
/// hide its navigation too.
///
/// A tap reveals the exit controls ([fullscreenControlsVisible]), which go
/// again after [fullscreenControlsTimeout]. Fullscreen is never persisted,
/// so every viewer opens in normal mode.
mixin MediaFullscreenMixin<T extends StatefulWidget> on State<T> {
  static const fullscreenControlsTimeout = Duration(seconds: 3);

  bool _isFullscreen = false;
  bool _controlsVisible = false;
  Timer? _controlsTimer;

  /// The shell's chrome controller, cached because dispose cannot look up
  /// ancestors. Null when the viewer sits above the shell (pushed on the
  /// root navigator), where there is no shell chrome to hide.
  ShellChromeController? _shellChrome;

  bool get isFullscreen => _isFullscreen;

  /// Whether a tap has revealed the exit button (and, on a video, its
  /// controls bar) while in fullscreen.
  bool get fullscreenControlsVisible => _controlsVisible;

  /// Runs inside the setState that leaves fullscreen, so the page can bring
  /// its own overlays back in the same frame.
  @protected
  void onExitFullscreen() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shellChrome = ShellChromeScope.maybeOf(context);
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    // A viewer closed while fullscreen (swipe-down) gives the chrome back.
    _shellChrome?.releaseHidden(this);
    super.dispose();
  }

  void enterFullscreen() {
    setState(() {
      _isFullscreen = true;
      _controlsVisible = false;
    });
    _shellChrome?.requestHidden(this);
  }

  void exitFullscreen() {
    _controlsTimer?.cancel();
    setState(() {
      _isFullscreen = false;
      _controlsVisible = false;
      onExitFullscreen();
    });
    _shellChrome?.releaseHidden(this);
  }

  /// Shows the fullscreen controls; with [autoHide] they go again after
  /// [fullscreenControlsTimeout] unless another tap restarts the clock.
  void revealFullscreenControls({required bool autoHide}) {
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (!autoHide) return;
    _controlsTimer = Timer(fullscreenControlsTimeout, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  /// A tap on a photo in fullscreen: reveals the controls, or hides them
  /// straight away when they are already showing.
  void toggleFullscreenControls() {
    if (!_controlsVisible) {
      revealFullscreenControls(autoHide: true);
      return;
    }
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  /// Leaves fullscreen when there is nothing left on screen to tap, such as
  /// a gallery a sync emptied, so the shell's navigation comes back.
  void exitFullscreenWhenEmpty() {
    if (!_isFullscreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isFullscreen) exitFullscreen();
    });
  }

  /// Makes Back leave fullscreen first; only the next press closes the
  /// viewer. Wrap the page's Scaffold in this.
  Widget fullscreenPopScope({required Widget child}) => PopScope(
    canPop: !_isFullscreen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _isFullscreen) exitFullscreen();
    },
    child: child,
  );
}

/// The corner button a tap reveals in the viewer's fullscreen mode (#1087).
/// A [Positioned] for the viewer's [Stack], kept inside the safe area.
class MediaFullscreenExitButton extends StatelessWidget {
  const MediaFullscreenExitButton({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const ValueKey('viewer_exit_fullscreen'),
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              tooltip: context.l10n.media_viewer_exitFullscreen,
              onPressed: onExit,
            ),
          ),
        ),
      ),
    );
  }
}
