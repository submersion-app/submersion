part of 'plan_canvas_page.dart';

/// The planner's flow for writing the plan to the log as planned dives
/// (issue #3565): "Create planned dives" until some are there, then "Update
/// planned dives". It replaces Convert to Dive, for one dive or a series.
mixin _PlanCanvasLogFlows on ConsumerState<PlanCanvasPage> {
  /// The menu item's label: create until some dive has an entry still only
  /// planned, then update, worded for one dive or several.
  static String _plannedDivesLabel(
    AppLocalizations l10n, {
    required bool exist,
    required bool isSeries,
  }) => switch ((exist, isSeries)) {
    (false, false) => l10n.plannerSeries_createPlannedDive,
    (false, true) => l10n.plannerSeries_createPlannedDives,
    (true, false) => l10n.plannerSeries_updatePlannedDive,
    (true, true) => l10n.plannerSeries_updatePlannedDives,
  };

  /// Writes the plan's dives to the log as planned entries, or brings the
  /// ones already there up to date. A series needs a start to lay its dives
  /// out on, so one where a dive still to write has none asks for the first
  /// dive's. A dived dive starts when it did, and the dives after it carry
  /// from that, so a series begun by one asks nothing. A single plan
  /// linked to a dived dive asks before a new entry takes its link, as
  /// Convert to Dive did.
  Future<void> _updatePlannedDives() async {
    final l10n = context.l10n;
    final series = ref.read(planSeriesNotifierProvider);
    if (seriesNeedsFirstStart(series, ref.read(planSeriesResultsProvider))) {
      final start = await pickPlanStart(context);
      if (start == null || !mounted) return;
      ref.read(planSeriesNotifierProvider.notifier).setFirstStart(start);
    }

    var result = await updatePlannedDives(ref.container);
    if (!mounted) return;
    if (result.needsLinkMove) {
      final confirmed = await confirmLinkMove(
        context,
        action: l10n.plannerSeries_createPlannedDive,
      );
      if (!confirmed || !mounted) return;
      result = await updatePlannedDives(ref.container, moveDivedLink: true);
      if (!mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (!result.valid) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch ((result.blockedBy, result.blockedEmpty)) {
            (null, false) => l10n.divePlanner_error_cannotConvert,
            (null, true) => l10n.plannerSeries_cannotUpdateEmptyPlan,
            (final dive?, false) => l10n.plannerSeries_cannotUpdate(dive),
            (final dive?, true) => l10n.plannerSeries_cannotUpdateEmpty(dive),
          }),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result.orphans.isNotEmpty) await _offerDeletingOrphans(result.orphans);
    if (!mounted) return;

    if (result.created + result.updated == 0) {
      // Removing a dive's entry was the whole of it: nothing to report.
      if (result.orphans.isNotEmpty) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.plannerSeries_allDived)),
      );
      return;
    }
    final diveId = result.selectedDiveId;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.updated == 0
              ? l10n.plannerSeries_created(result.created)
              : l10n.plannerSeries_updated(result.created + result.updated),
        ),
        persist: false,
        action: diveId == null
            ? null
            : SnackBarAction(
                label: l10n.plannerCanvas_convert_view,
                // push, not go: `go` into the `/dives` child route would
                // rebuild the stack as [dive list, dive detail] and discard
                // this canvas and its editable plan state.
                onPressed: () => context.push('/dives/$diveId'),
              ),
      ),
    );
  }

  /// Offers to delete the planned log entries of dives removed from the
  /// series. Either way they have been offered, so they are not again.
  Future<void> _offerDeletingOrphans(List<Dive> orphans) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.plannerSeries_orphans_title),
        content: Text(
          dialogContext.l10n.plannerSeries_orphans_body(orphans.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.plannerSeries_orphans_keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ref.read(planSeriesNotifierProvider.notifier).clearRemovedLinkedDives();
    if (delete != true) return;
    final log = ref.read(paginatedDiveListProvider.notifier);
    for (final dive in orphans) {
      await log.deleteDive(dive.id);
    }
  }
}
