import 'dart:async';

/// Decides when the diver has left the app, with a pop-out open (#5078).
///
/// App Lock and the work the app does on resume (sync, the stale-drafts
/// check, the health import) treat the main window losing focus as leaving
/// the app. On Windows and Linux each window has its own engine, so a click
/// into the pop-out also takes focus from the main window. That hand-off is
/// staying in the app: leaving is reported only when, [grace] after a window
/// lost focus, neither window holds it. Returning is reported only after a
/// reported leave.
///
/// With no pop-out open, the main window's own changes pass straight
/// through, every one of them, exactly as before pop-outs existed.
class WindowFocusArbiter {
  WindowFocusArbiter({
    required void Function() onLeft,
    required void Function() onReturned,
    this.grace = const Duration(milliseconds: 300),
  }) : _onLeft = onLeft,
       _onReturned = onReturned;

  final void Function() _onLeft;
  final void Function() _onReturned;
  final Duration grace;

  bool _popOutOpen = false;
  bool _mainFocused = true;
  bool _popOutFocused = false;
  bool _left = false;
  Timer? _check;

  set popOutOpen(bool open) {
    _popOutOpen = open;
    if (!open) {
      _popOutFocused = false;
      _scheduleCheck();
    }
  }

  void mainLeft() {
    _mainFocused = false;
    if (!_popOutOpen) {
      _left = true;
      _onLeft();
      return;
    }
    _scheduleCheck();
  }

  void mainReturned() {
    _mainFocused = true;
    _check?.cancel();
    if (!_popOutOpen) {
      _left = false;
      _onReturned();
      return;
    }
    _reportReturned();
  }

  void popOutFocus(bool focused) {
    _popOutFocused = focused;
    if (focused) {
      _check?.cancel();
      _reportReturned();
    } else {
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    _check?.cancel();
    if (_mainFocused || _popOutFocused) return;
    _check = Timer(grace, () {
      _check = null;
      if (!_mainFocused && !_popOutFocused) _reportLeft();
    });
  }

  void _reportLeft() {
    if (_left) return;
    _left = true;
    _onLeft();
  }

  void _reportReturned() {
    if (!_left) return;
    _left = false;
    _onReturned();
  }

  void dispose() {
    _check?.cancel();
    _check = null;
  }
}
