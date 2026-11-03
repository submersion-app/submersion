part of 'plan_canvas_page.dart';

/// The planner's flows for a saved repetitive series (issue #3565): opening
/// the route's plan over unsaved work, leaving with unsaved changes, and
/// deleting a series as a whole.
mixin _PlanCanvasSeriesFlows on ConsumerState<PlanCanvasPage> {
  /// The planner pages open, oldest first. The editor is app-wide, so a
  /// planner page under this one on the same navigator still shows the
  /// series once this one goes.
  static final List<_PlanCanvasSeriesFlows> _openPages = [];

  /// This page's navigator, for [_plannerBelow].
  NavigatorState? _navigator;

  /// The page's own Save, guarded against a second save running at once.
  Future<void> _savePlan();

  @override
  void initState() {
    super.initState();
    _openPages.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    _openPages.remove(this);
    super.dispose();
  }

  /// Whether a planner page opened before this one is on the same
  /// navigator, so going back from this one leaves the series on screen
  /// there rather than leaving the planner (a saved plan opened from the
  /// saved plans sheet is pushed over the planner it was opened from).
  bool get _plannerBelow {
    for (final page in _openPages) {
      if (identical(page, this)) return false;
      if (page._navigator != null && page._navigator == _navigator) {
        return true;
      }
    }
    return false;
  }

  /// Opens the saved plan this page was pushed for, asking first when that
  /// would replace unsaved work: the editor is app-wide, so what it holds may
  /// be another plan altogether. A dive of the series being edited is not
  /// another plan, so it is selected, keeping the edits.
  Future<void> _openRoutePlan(String planId) async {
    final series = ref.read(planSeriesNotifierProvider);
    if (series.isDirty) {
      final index = series.dives.indexWhere((d) => d.state.id == planId);
      if (index >= 0) {
        ref.read(planSeriesNotifierProvider.notifier).select(index);
        return;
      }
      final choice = await showUnsavedPlanDialog(
        context,
        isSeries: series.savesAsSeries,
      );
      if (!mounted) return;
      switch (choice) {
        case UnsavedPlanChoice.save:
          await _savePlan();
          if (!mounted) return;
          // The naming prompt can be cancelled, which leaves it unsaved.
          if (ref.read(planSeriesDirtyProvider)) return _leaveUnopenedRoute();
        case UnsavedPlanChoice.discard:
          break;
        case UnsavedPlanChoice.cancel:
          return _leaveUnopenedRoute();
      }
    }
    try {
      await openSavedPlan(ref.container, planId);
    } catch (_) {
      // Not opened, so the editor still holds another plan: staying would
      // show it under this route, whose plan Delete prefers.
      if (mounted) _leaveUnopenedRoute();
      rethrow;
    }
  }

  /// Backs out of a route whose plan was not opened: this page's [widget]
  /// planId names a plan the editor does not hold, and Delete prefers it.
  void _leaveUnopenedRoute() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/planning/dive-planner');
    }
  }

  /// Asks before leaving a series with unsaved changes, and leaves unless
  /// the diver cancels, or cancels the name a first save asks for.
  Future<void> _confirmLeavingSeries() async {
    final choice = await showUnsavedPlanDialog(context, isSeries: true);
    if (!mounted) return;
    switch (choice) {
      case UnsavedPlanChoice.save:
        await _savePlan();
        if (!mounted || ref.read(planSeriesDirtyProvider)) return;
      case UnsavedPlanChoice.discard:
        ref.read(divePlanNotifierProvider.notifier).newPlan();
      case UnsavedPlanChoice.cancel:
        return;
    }
    if (!mounted) return;
    // The planner can be the only page on its navigator, reached by go.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/planning');
    }
  }

  Future<void> _deleteSeries(String seriesId) async {
    final repository = ref.read(divePlanSeriesRepositoryProvider);
    // Read from the store first, as a plan's delete does, so Undo brings
    // back the series as saved rather than any unsaved edits on screen.
    final captured = await repository.getSeries(seriesId);
    if (!mounted) return;
    final name = captured?.name ?? ref.read(divePlanNotifierProvider).name;
    if (!await _confirmDeletePlan(name) || !mounted) return;

    await repository.deleteSeries(seriesId);
    if (!mounted) return;
    ref.read(divePlanNotifierProvider.notifier).newPlan();
    _leaveDeleted(
      undo: captured == null
          ? null
          : () => logFailure(
              repository.restoreSeries(captured),
              PlanCanvasPage,
              'restore a deleted series',
            ),
    );
  }

  /// Leaves for the planning hub saying the plan or series is deleted, with
  /// an Undo running [undo] when there is something to restore.
  void _leaveDeleted({required VoidCallback? undo}) {
    // Capture messenger + strings before navigating; this page is about to be
    // disposed and its context becomes defunct.
    final messenger = ScaffoldMessenger.of(context);
    final deletedLabel = context.l10n.divePlanner_message_planDeleted;
    final undoLabel = context.l10n.divePlanner_undo;
    context.go('/planning');
    messenger.showSnackBar(
      SnackBar(
        content: Text(deletedLabel),
        duration: const Duration(seconds: 5),
        // A SnackBar with an action defaults to persist: true, which makes the
        // auto-dismiss timer a no-op so the banner never hides on its own.
        // Force the 5s auto-dismiss and add a close icon so the banner can be
        // dismissed without tapping Undo (which would restore the plan). #406.
        persist: false,
        showCloseIcon: true,
        action: undo == null
            ? null
            : SnackBarAction(label: undoLabel, onPressed: undo),
      ),
    );
  }

  /// Asks to delete the plan or series named [name]; true when confirmed.
  Future<bool> _confirmDeletePlan(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.divePlanner_action_deletePlan),
        content: Text(
          context.l10n.divePlanner_message_deleteConfirmation(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
