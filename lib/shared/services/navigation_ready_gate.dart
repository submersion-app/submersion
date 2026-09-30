import 'dart:async';
import 'dart:collection';

/// Holds work that opens a page until the app can show one.
///
/// A file shared to an app the OS had evicted arrives on the first frame of
/// a cold start, before go_router has built its root navigator (the
/// top-level redirect is async), and on a fresh install while setup is
/// still on screen. Work passed to [run] waits here until [setReady] says
/// the app can show a page, instead of finding no navigator and being
/// dropped without a word (#2690).
///
/// Held work runs one item at a time, in arrival order, and so does work
/// that arrives while earlier work is still running: two files never load
/// into the one import notifier at once.
class NavigationReadyGate {
  final _waiting = Queue<Future<void> Function()>();
  bool _ready = false;
  bool _draining = false;

  /// Runs [action] once the app can show a page and the work ahead of it is
  /// done: at once, when both already hold. The returned future completes
  /// with [action]'s result or error whenever it runs, so a caller that
  /// reports failures still sees one from work that had to wait.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _waiting.add(() async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    unawaited(_drain());
    return completer.future;
  }

  /// Whether the app can show a page now. Work held until then starts.
  void setReady(bool ready) {
    _ready = ready;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_ready && _waiting.isNotEmpty) {
        await _waiting.removeFirst()();
      }
    } finally {
      _draining = false;
    }
  }
}
