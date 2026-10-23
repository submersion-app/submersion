import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';

/// Brings a freshly built list back to the record the diver last opened.
///
/// Leaving a list for another section disposes it, and with it the scroll
/// offset, so a list returned to would start at the top (#3301). The list
/// instead scrolls to its remembered record, which may not have loaded yet
/// when the list is first built. So [attempt] runs after the first frame and
/// again each time the list's data changes, until it reports that restoring
/// is over.
///
/// The diver comes first: once they scroll the list themselves, a restore
/// still waiting on data is dropped rather than jumping the list away from
/// where they put it.
class ListPositionRestorer {
  ListPositionRestorer({
    required ScrollController controller,
    required bool Function() attempt,
  }) : _controller = controller,
       _attempt = attempt;

  final ScrollController _controller;

  /// Tries to restore; true once restoring is over, whether the list scrolled
  /// to its record or the data loaded without one to scroll to. False only
  /// while it still waits on data.
  final bool Function() _attempt;

  ProviderSubscription<Object?>? _subscription;
  bool _done = false;

  /// Whether restoring is over, done or abandoned.
  bool get isDone => _done;

  /// Tries after the first frame, then on every change of [source] (the
  /// provider the list shows) until done.
  void start(WidgetRef ref, ProviderListenable<Object?> source) {
    _controller.addListener(_onScroll);
    _subscription = ref.listenManual(source, (_, _) => _tryRestore());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestore());
  }

  void _tryRestore() {
    if (_done) return;
    if (_attempt()) _finish();
  }

  /// A programmatic jump leaves the scroll direction idle; a drag, fling or
  /// wheel does not.
  void _onScroll() {
    if (_controller.positions.any(
      (position) => position.userScrollDirection != ScrollDirection.idle,
    )) {
      _finish();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _controller.removeListener(_onScroll);
    _subscription?.close();
    _subscription = null;
  }

  /// Stops listening. Call from the list's `dispose`, before disposing the
  /// controller.
  void dispose() => _finish();
}
