part of 'plan_canvas_page.dart';

/// The planner's flows for a saved repetitive series (issue #3565): opening
/// the route's plan over unsaved work, leaving with unsaved changes, and
/// deleting a series as a whole.
mixin _PlanCanvasSeriesFlows on ConsumerState<PlanCanvasPage> {
  /// The page's own Save, guarded against a second save running at once.
  Future<void> _savePlan();

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
    await openSavedPlan(ref.container, planId);
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
    final name = ref.read(divePlanNotifierProvider).name;
    if (!await _confirmDeletePlan(name) || !mounted) return;

    await ref.read(divePlanSeriesRepositoryProvider).deleteSeries(seriesId);
    if (!mounted) return;
    ref.read(divePlanNotifierProvider.notifier).newPlan();
    context.go('/planning');
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
