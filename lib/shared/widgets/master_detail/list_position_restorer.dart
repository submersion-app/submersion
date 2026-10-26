import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/pushed_route.dart';

/// Whether [position] is moving because of the diver rather than a jump.
bool isScrolledByDiver(ScrollPosition position) =>
    position.userScrollDirection != ScrollDirection.idle ||
    position.isScrollingNotifier.value;

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
    _subscription = ref.listenManual(source, (_, _) => _tryAfterFrame());
    _tryAfterFrame();
  }

  /// The list rebuilds from new data in the frame after it arrives, so an
  /// attempt made straight away would find the old rows (or a spinner with
  /// nothing to scroll). Tried once that frame is laid out instead.
  void _tryAfterFrame() {
    if (_done) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestore());
    WidgetsBinding.instance.scheduleFrame();
  }

  void _tryRestore() {
    if (_done) return;
    if (_attempt()) _finish();
  }

  /// The restore only ever jumps, which neither sets a scroll direction nor
  /// starts a scroll activity. A drag, fling or wheel sets the direction; a
  /// keyboard scroll (Page Down, the arrow keys) animates.
  void _onScroll() {
    if (_controller.positions.any(isScrolledByDiver)) _finish();
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

/// One [ListPositionRestorer] attempt for a list showing [items]: true once
/// there is nothing left to wait for.
///
/// The target is the record the list's address names ([selectedId]) or,
/// failing that, the one last opened ([rememberedId]), except in a list
/// pushed over another page, which starts at its top. A target the list does
/// not hold (deleted, filtered out) ends the restore; one it holds is
/// scrolled to with [scrollTo] once the list is laid out on [controller].
bool restoreListPosition<T>(
  BuildContext context, {
  required AsyncValue<List<T>> items,
  required String? selectedId,
  required String? rememberedId,
  required String Function(T item) idOf,
  required ScrollController controller,
  required void Function(String id) scrollTo,
}) {
  if (items.hasError) return true;
  // A reload still carries the rows it replaces; wait for the new ones.
  if (items.isLoading || !items.hasValue) return false;
  final target =
      selectedId ?? (isImperativelyPushed(context) ? null : rememberedId);
  if (target == null) return true;
  if (!items.value!.any((item) => idOf(item) == target)) return true;
  // Not laid out yet: try again once the list is on screen.
  if (!controller.hasClients) return false;
  scrollTo(target);
  return true;
}
