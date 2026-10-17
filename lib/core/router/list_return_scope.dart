import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';

/// What a pushed list puts back when it goes away: the filter and highlight
/// that were in place before it opened (#3292, #3350).
///
/// Carried as the list route's `extra`.
abstract interface class ListReturn {
  /// Captures the providers this snapshot restores from [ref], while the
  /// page is mounted, and returns the write that puts the snapshot back.
  ///
  /// The write must check that each captured controller is still mounted:
  /// it can run after the page is gone.
  VoidCallback bindRestore(WidgetRef ref);
}

/// Puts back the filter and highlight a pushed list replaced, once that list
/// goes away (#3292, #3350).
///
/// Wraps the list page for its whole life. [returnTo] is read once: a
/// selection on a pushed page replaces the route, which rebuilds the page
/// without its `extra`, but this State lives on. A null [returnTo] (the
/// section's own tab) restores nothing.
class ListReturnScope extends ConsumerStatefulWidget {
  const ListReturnScope({
    super.key,
    required this.returnTo,
    required this.child,
  });

  final ListReturn? returnTo;
  final Widget child;

  @override
  ConsumerState<ListReturnScope> createState() => _ListReturnScopeState();
}

class _ListReturnScopeState extends ConsumerState<ListReturnScope> {
  VoidCallback? _write;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _write = widget.returnTo?.bindRestore(ref);
  }

  void _restore() {
    final write = _write;
    if (_restored || write == null) return;
    _restored = true;
    write();
  }

  @override
  void dispose() {
    // Not popped (a sidebar tap replaced the stack): restore anyway, once the
    // tree has finished tearing down.
    if (_write != null && !_restored) scheduleMicrotask(_restore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_write == null) return widget.child;
    // Restore at pop time, before the page underneath rebuilds: a table-mode
    // list there replays the global highlight into its own URL once
    // uncovered, so a late restore would land it on the wrong item. A go()
    // that replaces the stack reports the pop from inside the Navigator's
    // build, where providers must not change; nothing is uncovered then, so
    // the restore waits for the build to finish.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          scheduleMicrotask(_restore);
        } else {
          _restore();
        }
      },
      child: widget.child,
    );
  }
}
