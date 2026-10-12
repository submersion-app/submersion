import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';

/// Puts back the dive-list filter and highlight a pushed dive list replaced,
/// once that list goes away (#3292).
///
/// Wraps the list page for its whole life. [returnTo] is read once: a
/// selection on a pushed page replaces the route, which rebuilds the page
/// without its `extra`, but this State lives on. A null [returnTo] (the Dives
/// tab itself) restores nothing.
class DiveListReturnScope extends ConsumerStatefulWidget {
  const DiveListReturnScope({
    super.key,
    required this.returnTo,
    required this.child,
  });

  final DiveListReturn? returnTo;
  final Widget child;

  @override
  ConsumerState<DiveListReturnScope> createState() =>
      _DiveListReturnScopeState();
}

class _DiveListReturnScopeState extends ConsumerState<DiveListReturnScope> {
  DiveListReturn? _returnTo;
  StateController<DiveFilterState>? _filter;
  StateController<String?>? _highlight;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _returnTo = widget.returnTo;
    if (_returnTo != null) {
      _filter = ref.read(diveFilterProvider.notifier);
      _highlight = ref.read(highlightedDiveIdProvider.notifier);
    }
  }

  void _restore() {
    final returnTo = _returnTo;
    if (_restored || returnTo == null) return;
    _restored = true;
    if (_filter?.mounted ?? false) _filter!.state = returnTo.filter;
    if (_highlight?.mounted ?? false) {
      _highlight!.state = returnTo.highlightedDiveId;
    }
  }

  @override
  void dispose() {
    // Not popped (a sidebar tap replaced the stack): restore anyway, once the
    // tree has finished tearing down.
    if (_returnTo != null && !_restored) scheduleMicrotask(_restore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_returnTo == null) return widget.child;
    // Restore at pop time, before the page underneath rebuilds: a table-mode
    // list there replays the global highlight into its own URL once
    // uncovered, so a late restore would land it on the wrong dive. A go()
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
