import 'dart:async';

/// Keeps the shared profile cursor from bouncing between windows (#5078).
///
/// A window that applies a position it received sees its own cursor move
/// and would send that position straight back. The gate drops those echoes,
/// and any repeat of the value last sent. One received position can land
/// more than once (the main window's fullscreen view takes it as sent, the
/// detail chart beneath snaps it to a sample), so each landing is expected.
class CursorEchoGate {
  final _expected = <({String diveId, int? seconds})>{};
  ({String diveId, int? seconds})? _sent;

  /// [seconds] for [diveId] arrived from the other window. Landings still
  /// expected from an earlier position are forgotten.
  void noteReceived(String diveId, int? seconds) {
    _expected
      ..clear()
      ..add((diveId: diveId, seconds: seconds));
  }

  /// The position last received also lands at [seconds] (snapped to a
  /// sample of this window's own series).
  void alsoExpect(String diveId, int? seconds) {
    _expected.add((diveId: diveId, seconds: seconds));
  }

  /// Whether a local cursor at [seconds] on [diveId] should go out.
  bool shouldSend(String diveId, int? seconds) {
    final value = (diveId: diveId, seconds: seconds);
    if (_expected.remove(value)) {
      _sent = value;
      return false;
    }
    if (_sent == value) return false;
    // The diver's own move: nothing still expected is an echo any more.
    _expected.clear();
    _sent = value;
    return true;
  }
}

/// Sends at most one cursor position per [interval]: the latest one.
///
/// Scrubbing and playback move the cursor far faster than another window
/// needs to hear about it; a frame's worth of positions collapses into one.
class CursorCoalescer {
  CursorCoalescer(
    this._send, {
    this.interval = const Duration(milliseconds: 16),
  });

  final void Function(String diveId, int? seconds) _send;
  final Duration interval;

  ({String diveId, int? seconds})? _pending;
  Timer? _timer;

  void push(String diveId, int? seconds) {
    _pending = (diveId: diveId, seconds: seconds);
    _timer ??= Timer(interval, _flush);
  }

  void _flush() {
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) _send(pending.diveId, pending.seconds);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
