import 'dart:async';
import 'dart:collection';

/// Holds items that open a page until an app root that can show one takes
/// them.
///
/// A file shared to an app the OS had evicted arrives on the first frame of
/// a cold start, before go_router has built its root navigator (the
/// top-level redirect is async), and on a fresh install while setup is
/// still on screen. Items passed to [run] wait here until the attached
/// owner says it can show a page, instead of finding no navigator and being
/// dropped without a word (#2690).
///
/// Items are data, not callbacks into whoever received them: a soft restart
/// (`restartApp`) replaces the app root, and an item held across it must be
/// opened by the root that replaced it. The app keeps one gate for the life
/// of the process and each root [attach]es to it in turn.
///
/// Items are handled one at a time, in arrival order, including ones that
/// arrive while an earlier one is still being handled: two files never load
/// into the one import notifier at once. An owner that cannot finish an item
/// (it was replaced while opening it) hands it back, and it stays first in
/// line for whichever owner is ready next.
class NavigationReadyGate<T> {
  final _waiting = Queue<(T, Completer<void>)>();
  NavigationReadyGateOwner<T>? _owner;
  bool _draining = false;

  /// Hands [item] to the owner once it can show a page and the items ahead
  /// of it are done: at once, when both already hold. The returned future
  /// completes when the owner has handled it, or with the owner's error.
  Future<void> run(T item) {
    final done = Completer<void>();
    _waiting.add((item, done));
    unawaited(_drain());
    return done.future;
  }

  /// Makes [handle] the owner of every item, held or still to come, in
  /// place of any earlier owner. The new owner starts out not ready.
  ///
  /// [handle] returns whether it finished the item. False hands it back
  /// unfinished, to be offered again: to a newer owner at once if one is
  /// ready, otherwise at this owner's next readiness or the next owner's.
  NavigationReadyGateOwner<T> attach(Future<bool> Function(T item) handle) {
    final owner = NavigationReadyGateOwner<T>._(this, handle);
    _owner = owner;
    return owner;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_waiting.isNotEmpty) {
        final owner = _owner;
        if (owner == null || !owner._ready) return;
        final held = _waiting.removeFirst();
        final (item, done) = held;
        try {
          if (!await owner._handle(item)) {
            _waiting.addFirst(held);
            // The same owner, still current, will not finish it on another
            // pass now; a newer one that became ready meanwhile can.
            if (identical(_owner, owner)) return;
            continue;
          }
          done.complete();
        } catch (error, stackTrace) {
          done.completeError(error, stackTrace);
        }
      }
    } finally {
      _draining = false;
    }
  }
}

/// One app root's hold on a [NavigationReadyGate]. Once a newer owner has
/// attached, this one's calls do nothing: during a soft restart the new
/// root attaches before the old one is disposed.
class NavigationReadyGateOwner<T> {
  NavigationReadyGateOwner._(this._gate, this._handle);

  final NavigationReadyGate<T> _gate;
  final Future<bool> Function(T item) _handle;
  bool _ready = false;

  bool get _current => identical(_gate._owner, this);

  /// Whether this owner can show a page now. Items held until then start.
  void setReady(bool ready) {
    if (!_current) return;
    _ready = ready;
    unawaited(_gate._drain());
  }

  /// Lets go of the gate. Items arriving afterwards wait for the next owner.
  void release() {
    if (_current) _gate._owner = null;
  }
}
