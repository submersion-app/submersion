import 'dart:async';

/// Lightweight event bus for local sync triggers.
class SyncEventBus {
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// The zone key under which [holdNotices] keeps the notices it holds.
  static final Object _heldKey = Object();

  static Stream<void> get changes => _controller.stream;

  /// Tells listeners that local data changed. Inside [holdNotices] the
  /// notice is held instead, and sent once that body has finished.
  static void notifyLocalChange() {
    final held = Zone.current[_heldKey];
    if (held is _HeldNotices && held.open) {
      held.pending = true;
      return;
    }
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// Runs [body], holding the notices its writes send: one is sent when it
  /// returns, none when it throws. For writes in one transaction (an editing
  /// sitting, issue #4527), so nothing reacts to rows that are not yet
  /// committed, or that a later write rolls back. A hold inside another
  /// sends its notice on to the outer one. Work [body] started that runs
  /// on after it (a timer, a stream) keeps its zone but holds nothing: its
  /// notices go out at once.
  static Future<R> holdNotices<R>(Future<R> Function() body) async {
    final held = _HeldNotices();
    try {
      final result = await runZoned(body, zoneValues: {_heldKey: held});
      // Sent from the caller's zone: to an outer hold, or out.
      if (held.pending) notifyLocalChange();
      return result;
    } finally {
      held.open = false;
    }
  }

  static Future<void> dispose() async {
    await _controller.close();
  }
}

class _HeldNotices {
  bool pending = false;

  /// Whether the body that holds these notices is still running.
  bool open = true;
}
