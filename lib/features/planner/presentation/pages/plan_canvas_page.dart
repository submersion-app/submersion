import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/plan_link_actions.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/chart_mode_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/follow_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_actions.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_files.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_first_save_name.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_unsaved_dialog.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_state.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_start_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_follow_prompt.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_results.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_tanks_card.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/plan_actual_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_navigator.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_shortcuts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/log_failure.dart';

part 'plan_canvas_layouts.dart';
part 'plan_canvas_log_flows.dart';
part 'plan_canvas_series_flows.dart';

/// Whether [id] refers to a plan that already exists in the store. Drives the
/// visibility of the destructive "Delete plan" action: a brand-new, never-saved
/// plan has nothing to delete (Reset covers clearing it).
@visibleForTesting
bool planIsPersisted(String id, List<domain.DivePlanSummary> summaries) =>
    summaries.any((s) => s.id == id);

/// Mission Control: a thin layout router over the planner's three panes.
/// Editing state lives on [divePlanNotifierProvider]; every displayed number
/// comes from the PlanEngine via [planOutcomeProvider].
///
/// Modes, decided from the space the page is actually given:
/// - >= 1160 px: editor pane, chart column, results pane (side panes
///   collapsible with remembered state)
/// - 760-1160 px: chart column + results pane; the editor lives in a drawer
/// - < 760 px: phone Chart + Tab Deck (Tanks / Plan / Setup / Results)
class PlanCanvasPage extends ConsumerStatefulWidget {
  const PlanCanvasPage({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<PlanCanvasPage> createState() => _PlanCanvasPageState();
}

class _PlanCanvasPageState extends ConsumerState<PlanCanvasPage>
    with _PlanCanvasSeriesFlows, _PlanCanvasLayouts, _PlanCanvasLogFlows {
  /// Owns the always-visible results pane so it is created once (not per
  /// build) and disposed with the page. Shared by the phone Results tab.
  @override
  final _wideResultsController = ScrollController();

  @override
  void initState() {
    super.initState();
    final planId = widget.planId;
    if (planId != null) {
      // Riverpod 3 forbids provider mutation during widget lifecycle
      // callbacks; defer the load to a microtask.
      Future.microtask(() {
        if (!mounted) return;
        logFailure(
          _openRoutePlan(planId),
          _PlanCanvasPageState,
          'open a saved plan',
        );
      });
    }
    // What has actually been dived replaces the plan in the chain (issue
    // #3565). Deferred: this can fire inside a build, where providers cannot
    // be changed.
    ref.listenManual(seriesActualsProvider, (_, next) {
      final actuals = next.value;
      if (actuals == null) return;
      Future.microtask(() {
        if (mounted) {
          ref.read(planSeriesNotifierProvider.notifier).setActuals(actuals);
        }
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _wideResultsController.dispose();
    // A replan opened from a logged dive is a throwaway experiment: once the
    // diver leaves, the planner forgets it and the next visit starts on a
    // fresh plan rather than the leftovers of someone else's dive. Saved
    // replans are still in the list. Ordinary plans keep today's behaviour of
    // surviving navigation. The notifier is app-wide, so touching it after
    // this element is gone is safe; the microtask keeps the mutation out of
    // the dispose frame. Only that replan goes: this snapshot can be a frame
    // old, and a plan that replaced it on the way out is the diver's next one.
    final notifier = _notifier;
    final replanId = _replanId;
    super.dispose();
    if (replanId != null && notifier != null) {
      Future.microtask(() {
        if (notifier.mounted && notifier.planId == replanId) {
          notifier.newPlan();
        }
      });
    }
  }

  /// Snapshot for [dispose], which may not touch `ref`: the notifier and the
  /// id of the plan on screen when it is a replan of a logged dive. Refreshed
  /// on every build so it tracks loads, resets and saves.
  DivePlanNotifier? _notifier;
  String? _replanId;

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(divePlanNotifierProvider);
    // A series of dives, or a plan following a logged dive, cannot be logged
    // yet (issue #3565).
    final convertAllowed = ref.watch(planConvertAllowedProvider);
    final savedSeriesId = ref.watch(
      planSeriesNotifierProvider.select((s) => s.id),
    );
    final isDirty = ref.watch(planSeriesDirtyProvider);
    _notifier = ref.read(divePlanNotifierProvider.notifier);
    // A series is not a throwaway: leaving must not lose what cannot be saved.
    _replanId = planState.sourceDiveId != null && convertAllowed
        ? planState.id
        : null;
    final units = ref.watch(unitFormatterProvider);
    final followAllowed = ref.watch(followAllowedProvider);
    // Watched here rather than in the menu's builder: an open menu does not
    // rebuild, so it must open on a value already settled.
    final logState =
        ref.watch(plannedDivesLogStateProvider).valueOrNull ??
        PlannedDivesLogState.unsettled(
          linked: ref.watch(
            planSeriesNotifierProvider.select(
              (s) => s.dives.any((d) => d.state.linkedDiveId != null),
            ),
          ),
        );
    final isSeries = ref.watch(
      planSeriesNotifierProvider.select((s) => s.isSeries),
    );
    // A plan opened via the :planId route is known-persisted, so short-circuit
    // before watching the (DB-backed) summaries provider; that avoids an
    // avoidable subscription/fetch in the common edit-a-saved-plan case. The
    // summaries watch only runs for a new plan, where it flips the Delete item
    // on once the plan is first saved.
    // A saved series deletes as a whole; one not saved yet has nothing to
    // delete, and the route's plan may not be the dive on screen.
    final canDelete =
        savedSeriesId != null ||
        (convertAllowed &&
            (widget.planId != null ||
                planIsPersisted(
                  planState.id,
                  ref.watch(divePlanSummariesProvider).valueOrNull ??
                      const <domain.DivePlanSummary>[],
                )));

    return Scaffold(
      appBar: AppBar(
        // Opened as a nav shortcut (#2936) the planner is the only page, and
        // an inert back arrow reads as broken; AppBar makes the same test.
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: () => _showRenameDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The inner Flexible is what keeps a long plan name
                    // ellipsizing once the pencil takes fixed width.
                    Flexible(
                      child: Text(
                        planState.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // State-derived mode toggle: tap cycles OC -> CCR -> SCR.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref
                  .read(divePlanNotifierProvider.notifier)
                  .updateMode(_nextMode(planState.mode)),
              child: PlanChip(
                label: planState.mode.name.toUpperCase(),
                emphasized: planState.mode != domain.PlanMode.oc,
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 560) ...[
              const SizedBox(width: 6),
              PlanChip(
                label: 'GF',
                // The plan's own factors, else the diver's Settings (#3552).
                value: () {
                  final resolved = ref.watch(resolvedPlanEngineConfigProvider);
                  return '${resolved.gfLow}/${resolved.gfHigh}';
                }(),
                onTap: () => _focusSetup('deco'),
              ),
              const SizedBox(width: 6),
              PlanChip(
                label:
                    '${units.convertAltitude(planState.altitude ?? 0).toStringAsFixed(0)} ${units.altitudeSymbol}',
                onTap: () => _focusSetup('environment'),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDirty ? Icons.save : Icons.save_outlined),
            tooltip: context.l10n.divePlanner_action_savePlan,
            onPressed: isDirty ? _savePlan : null,
          ),
          // A Builder so the share anchor resolves to the overflow button
          // rather than the whole app bar: it contributes no render object, so
          // findRenderObject descends to the PopupMenuButton below it. The
          // button is still mounted when the share sheet opens; the menu item
          // the user actually tapped is not.
          Builder(
            builder: (menuContext) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: context.l10n.divePlanner_action_moreOptions,
              onSelected: (value) =>
                  _onMenu(value, shareAnchorFrom(menuContext)),
              itemBuilder: (context) => [
                _menuItem(
                  'quickPlan',
                  Icons.auto_awesome,
                  context.l10n.divePlanner_action_quickPlan,
                ),
                _menuItem(
                  'saved',
                  Icons.folder_open,
                  context.l10n.plannerCanvas_saved_title,
                ),
                _menuItem(
                  'follow',
                  Icons.history,
                  context.l10n.plannerCanvas_follow_title,
                  enabled: followAllowed,
                  tooltip: followAllowed
                      ? null
                      : context.l10n.plannerSeries_followUnavailableInReplan,
                ),
                _menuItem(
                  'settings',
                  Icons.tune,
                  context.l10n.divePlanner_label_planSettings,
                ),
                _menuItem(
                  'convert',
                  Icons.scuba_diving,
                  _PlanCanvasLogFlows._plannedDivesLabel(
                    context.l10n,
                    exist: logState.entriesExist,
                    isSeries: isSeries,
                  ),
                  // Nothing to write while the log matches the plan.
                  enabled: logState.outOfDate,
                ),
                ..._linkMenuItems(context),
                _menuItem(
                  'slate',
                  Icons.picture_as_pdf,
                  context.l10n.plannerCanvas_slate_menu,
                  // The slate prints the computed schedule, and a plan with
                  // no segments has none: it would be a header over empty
                  // tables (#3795).
                  enabled: planState.segments.isNotEmpty,
                ),
                _menuItem(
                  'share',
                  Icons.upload_file,
                  context.l10n.plannerCanvas_share_menu,
                ),
                _menuItem(
                  'reset',
                  Icons.refresh,
                  context.l10n.divePlanner_action_resetPlan,
                ),
                if (canDelete) _deleteMenuItem(context),
              ],
            ),
          ),
        ],
      ),
      // Leaving a series with unsaved changes asks first (issue #3565).
      body: PopScope(
        // Not over another planner page, which still shows the series.
        canPop:
            !(isDirty &&
                ref.watch(planSeriesSavesAsSeriesProvider) &&
                !_plannerBelow),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            logFailure(
              _confirmLeavingSeries(),
              _PlanCanvasPageState,
              'leave an unsaved series',
            );
          }
        },
        child: PlanSeriesShortcuts(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 760) return _buildDesktop(fullWidth: width >= 1160);
              return _buildPhone(constraints);
            },
          ),
        ),
      ),
    );
  }

  static domain.PlanMode _nextMode(domain.PlanMode mode) => switch (mode) {
    domain.PlanMode.oc => domain.PlanMode.ccr,
    domain.PlanMode.ccr => domain.PlanMode.scr,
    domain.PlanMode.scr => domain.PlanMode.pscr,
    domain.PlanMode.pscr => domain.PlanMode.oc,
  };

  /// Link to a logged dive, or Change and Unlink with what the plan was dived
  /// as. A plan has to be saved before anything can name it.
  List<PopupMenuItem<String>> _linkMenuItems(BuildContext context) {
    final l10n = context.l10n;
    final plan = ref.read(divePlanNotifierProvider);
    final summaries = ref.read(divePlanSummariesProvider).value;
    final summary = summaries?.where((s) => s.id == plan.id).firstOrNull;
    // A dive of a saved series is loaded into the editor without being its
    // persisted plan, so its saved row is what says it can be named.
    final saved =
        ref.read(divePlanNotifierProvider.notifier).isPersisted ||
        (ref.read(planSeriesNotifierProvider).id != null && summary != null);
    final tooltip = saved ? null : l10n.plannerCanvas_link_saveFirst;
    if (plan.linkedDiveId == null) {
      return [
        _menuItem(
          'linkDive',
          Icons.link,
          l10n.plannerCanvas_link_action,
          enabled: saved,
          tooltip: tooltip,
        ),
      ];
    }
    return [
      // The dive's entry in the log, planned or dived (issue #3565).
      _menuItem('openInLog', Icons.open_in_new, l10n.plannerSeries_openInLog),
      _menuItem(
        'linkDive',
        Icons.link,
        l10n.plannerCanvas_link_changeAction,
        enabled: saved,
        tooltip: tooltip,
      ),
      _menuItem(
        'unlinkDive',
        Icons.link_off,
        l10n.plannerCanvas_unlink_action,
        enabled: saved,
        tooltip: tooltip,
        subtitle: summary == null
            ? null
            : planLinkBadge(l10n, summary, ref.read(unitFormatterProvider)),
      ),
    ];
  }

  /// An overflow menu entry. [tooltip] says why a disabled entry is not
  /// available; [subtitle] adds a line under the label.
  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
    String? tooltip,
    String? subtitle,
  }) {
    final tile = ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: tooltip == null ? tile : Tooltip(message: tooltip, child: tile),
    );
  }

  PopupMenuItem<String> _deleteMenuItem(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(Icons.delete_outline, color: error),
        title: Text(
          context.l10n.divePlanner_action_deletePlan,
          style: TextStyle(color: error),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _onMenu(String value, Rect? shareAnchor) {
    switch (value) {
      case 'quickPlan':
        showDialog<void>(
          context: context,
          builder: (_) => const SimplePlanDialog(),
        );
      case 'saved':
        showSavedPlansSheet(context);
      case 'follow':
        showFollowDiveSheet(context);
      case 'settings':
        _focusSetup('deco');
      case 'convert':
        logFailure(
          _updatePlannedDives(),
          _PlanCanvasPageState,
          'update planned dives',
        );
      case 'linkDive':
        logFailure(
          pickDiveAndLink(
            context,
            ref,
            planId: ref.read(divePlanNotifierProvider).id,
          ),
          _PlanCanvasPageState,
          'link plan to dive',
        );
      case 'unlinkDive':
        logFailure(
          unlinkPlanWithConfirm(
            context,
            ref,
            planId: ref.read(divePlanNotifierProvider).id,
          ),
          _PlanCanvasPageState,
          'unlink plan',
        );
      case 'openInLog':
        if (ref.read(divePlanNotifierProvider).linkedDiveId case final id?) {
          // push, not go: the planner and its unsaved edits stay underneath.
          context.push('/dives/$id');
        }
      case 'slate':
        logFailure(
          _exportSlate(shareAnchor),
          _PlanCanvasPageState,
          'export slate',
        );
      case 'share':
        logFailure(
          _exportPlanFile(shareAnchor),
          _PlanCanvasPageState,
          'export plan file',
        );
      case 'reset':
        _resetPlan();
      case 'delete':
        logFailure(_deletePlan(), _PlanCanvasPageState, 'delete plan');
    }
  }

  /// Reveal a Setup accordion section in whatever layout mode is active.
  void _focusSetup(String section) {
    if (MediaQuery.sizeOf(context).width < 760) {
      ref.read(plannerPhoneTabProvider.notifier).state = 2;
    } else {
      ref.read(editorPaneCollapsedProvider.notifier).state = false;
    }
    ref.read(setupFocusSectionProvider.notifier).state = section;
  }

  // --- Actions ---

  Future<void> _exportPlanFile(Rect? shareAnchor) {
    final l10n = context.l10n;
    return deliverPlanExport(
      context,
      title: l10n.plannerCanvas_share_menu,
      savedMessage: l10n.plannerCanvas_share_saved,
      shareAnchor: shareAnchor,
      build: () async {
        if (!mounted) return null;
        // One dive is shared as the plan it is; a series goes together, with
        // what each dive carries from the one before.
        if (!ref.read(planSeriesNotifierProvider).isSeries) {
          return planFileExport(ref);
        }
        return seriesExport(await currentStoredSeries(ref.container));
      },
    );
  }

  Future<void> _exportSlate(Rect? shareAnchor) {
    final l10n = context.l10n;
    final labels = planSlateLabels(l10n);
    final localization = PdfLocalization.forLanguageCode(
      Localizations.localeOf(context).languageCode,
    );
    return deliverPlanExport(
      context,
      title: l10n.plannerCanvas_slate_menu,
      savedMessage: l10n.plannerCanvas_slate_saved,
      shareAnchor: shareAnchor,
      build: () async => mounted
          ? planSlateExport(ref, labels: labels, localization: localization)
          : null,
    );
  }

  /// Guards [_savePlan] against re-entry.
  ///
  /// The save button stays enabled across the naming flow's async gaps - the
  /// site lookup and the write itself both run with no modal up and isDirty
  /// still true - so a second tap could start a concurrent save. Worse than
  /// stacked dialogs: [DivePlanNotifier.save] only sets its loaded plan after
  /// the write completes, so a concurrent call still reads isPersisted as false
  /// and prompts for a name on a plan that is already being saved.
  bool _saveInFlight = false;

  @override
  Future<void> _savePlan() async {
    if (_saveInFlight) return;
    _saveInFlight = true;
    try {
      await _runSavePlan();
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _runSavePlan() async {
    final notifier = ref.read(divePlanNotifierProvider.notifier);

    // Prompt for a name the first time a plan is persisted, so the saved-plans
    // list is not a wall of identically-named rows. Re-saves stay silent, and
    // so does writing the planned dives: that flow is already multi-step and
    // should not grow a modal.
    final series = ref.read(planSeriesNotifierProvider);
    if (!notifier.isPersisted && series.id == null) {
      if (!await nameFirstSave(context, ref) || !mounted) return;
    }

    // Build the summary last so the denormalized depth/runtime always describe
    // the plan actually being persisted, never whatever it looked like before
    // the naming flow's async gaps.
    final outcome = ref.read(planOutcomeProvider);
    if (ref.read(planSeriesNotifierProvider).savesAsSeries) {
      await saveCurrentSeries(ref.container);
    } else {
      await notifier.save(
        summary: PlanSummaryData(
          maxDepth: outcome.maxDepth,
          runtimeSeconds: outcome.runtimeSeconds,
          ttsSeconds: outcome.ttsAtBottom,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.divePlanner_message_planSaved)),
    );
  }

  Future<void> _deletePlan() async {
    final seriesId = ref.read(planSeriesNotifierProvider).id;
    if (seriesId != null) return _deleteSeries(seriesId);
    // Prefer the route's planId. During the loadPlanById() window the notifier
    // state still holds a freshly generated placeholder id, so reading it here
    // could target (and tombstone) the wrong plan. widget.planId is the
    // authoritative plan being edited; fall back to the notifier id only for a
    // routeless plan saved this session.
    final repository = ref.read(divePlanRepositoryProvider);
    final planId = widget.planId ?? ref.read(divePlanNotifierProvider).id;

    // Read the authoritative plan (and its persisted summary numbers) from the
    // store first, so the confirm dialog, the deletion, and the undo snapshot
    // all refer to the same real plan. Capturing the summary from the store
    // (not planOutcomeProvider, which reflects transient in-memory edits) keeps
    // the restored saved-plans list numbers consistent with the restored plan.
    // A null plan means it was already deleted elsewhere (e.g. via sync); we
    // still delete and navigate so the user is never stranded on a dead
    // :planId route, but omit Undo since there is no snapshot to restore.
    final captured = await repository.getPlan(planId);
    if (!mounted) return;
    final capturedSummary = captured == null
        ? null
        : await repository.getPlanSummary(planId);
    if (!mounted) return;
    final name = captured?.name ?? ref.read(divePlanNotifierProvider).name;

    if (!await _confirmDeletePlan(name) || !mounted) return;

    await repository.deletePlan(planId);
    if (!mounted) return;

    _leaveDeleted(
      undo: captured == null
          ? null
          : () => repository.savePlan(captured, summary: capturedSummary),
    );
  }

  void _resetPlan() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.divePlanner_action_resetPlan),
        content: Text(context.l10n.divePlanner_message_resetConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(divePlanNotifierProvider.notifier).newPlan();
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.divePlanner_action_reset),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final entered = await showPlanNameDialog(
      context,
      initialName: ref.read(divePlanNotifierProvider).name,
      title: context.l10n.divePlanner_action_renamePlan,
    );
    if (entered == null) return;
    notifier.updateName(entered);
  }
}
