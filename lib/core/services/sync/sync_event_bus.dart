import 'dart:async';

/// Lightweight event bus for local sync triggers.
class SyncEventBus {
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _controller.stream;

  static void notifyLocalChange() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  static Future<void> dispose() async {
    await _controller.close();
  }
}
