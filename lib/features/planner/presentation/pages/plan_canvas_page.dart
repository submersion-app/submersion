import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_start_field.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_unsaved_dialog.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/chart_mode_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/follow_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_actions.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_files.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_follow_prompt.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_logged_dive_view.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_navigator.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_shortcuts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/log_failure.dart';

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

class _PlanCanvasPageState extends ConsumerState<PlanCanvasPage> {
  /// Owns the always-visible results pane so it is created once (not per
  /// build) and disposed with the page. Shared by the phone Results tab.
  final _wideResultsController = ScrollController();

  @override
  void initState() {
    super.initState();
    // What has actually been dived replaces the plan in the chain.
    ref.listenManual(seriesActualsProvider, (_, next) {
      final actuals = next.value;
      if (actuals == null) return;
      // Deferred: this can fire inside a build, where providers can't change.
      Future.microtask(() {
        if (mounted) {
          ref.read(planSeriesNotifierProvider.notifier).setActuals(actuals);
        }
      });
    }, fireImmediately: true);
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
    final savesAsSeries = ref.watch(planSeriesSavesAsSeriesProvider);
    final plannedDivesExist = ref.watch(plannedDivesExistProvider);
    final isSeries = ref.watch(
      planSeriesNotifierProvider.select((s) => s.isSeries),
    );
    final savedSeriesId = ref.watch(
      planSeriesNotifierProvider.select((s) => s.id),
    );
    final isDirty = ref.watch(planSeriesDirtyProvider);
    _notifier = ref.read(divePlanNotifierProvider.notifier);
    // A series is not a throwaway: leaving must not lose what cannot be saved.
    _replanId = planState.sourceDiveId != null && !savesAsSeries
        ? planState.id
        : null;
    final units = ref.watch(unitFormatterProvider);
    final followAllowed = ref.watch(followAllowedProvider);
    // A plan opened via the :planId route is known-persisted, so short-circuit
    // before watching the (DB-backed) summaries provider; that avoids an
    // avoidable subscription/fetch in the common edit-a-saved-plan case. The
    // summaries watch only runs for a new plan, where it flips the Delete item
    // on once the plan is first saved.
    // A saved series deletes as a whole; one not saved yet has nothing to
    // delete, and the route's plan may not be the dive on screen.
    final canDelete =
        savedSeriesId != null ||
        (!savesAsSeries &&
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
                  _plannedDivesLabel(
                    context.l10n,
                    exist: plannedDivesExist,
                    isSeries: isSeries,
                  ),
                ),
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
        canPop: !(isDirty && ref.watch(planSeriesSavesAsSeriesProvider)),
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

  /// An overflow menu entry. [tooltip] says why a disabled entry is not
  /// available.
  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
    String? tooltip,
  }) {
    final tile = ListTile(
      leading: Icon(icon),
      title: Text(label),
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

  // --- Layout modes ---

  /// Desktop: the editor pane is always visible (collapsible, never hidden
  /// behind a drawer). At full width the results pane shows by default; at
  /// middle widths it defaults to hidden and the right chevron reveals it.
  Widget _buildDesktop({required bool fullWidth}) {
    // A logged dive picked in the series bar is shown read-only in place of
    // the planner, under the same bar.
    if (ref.watch(viewedLoggedDiveProvider) != null) {
      return const Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: PlanSeriesNavigator(),
          ),
          Expanded(child: PlanLoggedDiveView()),
        ],
      );
    }
    final editorCollapsed = ref.watch(editorPaneCollapsedProvider);
    final planDived = ref.watch(selectedDiveActualProvider) != null;
    final resultsVisible = fullWidth
        ? !ref.watch(resultsPaneCollapsedProvider)
        : ref.watch(resultsPaneNarrowExpandedProvider);

    void toggleResults() {
      if (fullWidth) {
        ref.read(resultsPaneCollapsedProvider.notifier).update((v) => !v);
      } else {
        ref.read(resultsPaneNarrowExpandedProvider.notifier).update((v) => !v);
      }
    }

    return Row(
      children: [
        if (!editorCollapsed) ...[
          SizedBox(
            width: 320,
            child: _ReadOnlyWhenDived(
              dived: planDived,
              child: const PlanEditorPane(),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          child: _chartColumn(
            editorCollapsed: editorCollapsed,
            onToggleEditor: () => ref
                .read(editorPaneCollapsedProvider.notifier)
                .update((v) => !v),
            resultsVisible: resultsVisible,
            onToggleResults: toggleResults,
          ),
        ),
        if (resultsVisible) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: PlanResultsPane(controller: _wideResultsController),
          ),
        ],
      ],
    );
  }

  Widget _chartColumn({
    required bool editorCollapsed,
    required VoidCallback onToggleEditor,
    required bool resultsVisible,
    required VoidCallback onToggleResults,
  }) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: PlanSeriesNavigator(),
        ),
        const PlanFollowPrompt(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: PlanActualToggle(),
        ),
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: PlanProfileChart(),
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: IconButton(
                  tooltip: editorCollapsed
                      ? context.l10n.plannerCanvas_pane_expand
                      : context.l10n.plannerCanvas_pane_collapse,
                  icon: Icon(
                    editorCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: onToggleEditor,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  tooltip: resultsVisible
                      ? context.l10n.plannerCanvas_pane_collapse
                      : context.l10n.plannerCanvas_pane_expand,
                  icon: Icon(
                    resultsVisible ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: onToggleResults,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PlanStatusChips(onIssuesTap: _scrollWideToIssues),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [ContingencyChips(), ChartModeToggle()],
          ),
        ),
      ],
    );
  }

  Widget _buildPhone(BoxConstraints constraints) {
    final tab = ref.watch(plannerPhoneTabProvider);
    // Tanks first: the gas is chosen before the profile that breathes it, and
    // the deck's default index of 0 therefore opens on Tanks. Setup and
    // Results keep indices 2 and 3, which _focusSetup and the issues chip
    // write directly.
    final tabs = [
      context.l10n.divePlanner_label_tanks,
      context.l10n.divePlanner_tab_plan,
      context.l10n.plannerCanvas_tab_setup,
      context.l10n.divePlanner_tab_results,
    ];
    // 30% of the body, clamped so the chart neither vanishes on short
    // viewports nor dominates tall ones; the deck gets everything else.
    final chartHeight = (constraints.maxHeight * 0.30)
        .clamp(160.0, 260.0)
        .toDouble();
    // A single CustomScrollView so the chart and tab selector scroll away
    // with the rest of the page instead of staying pinned and eating the
    // viewport (#1428).
    if (ref.watch(viewedLoggedDiveProvider) != null) {
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: PlanSeriesNavigator()),
          SliverToBoxAdapter(
            child: PlanLoggedDiveView(chartHeight: chartHeight),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: PlanSeriesNavigator()),
        const SliverToBoxAdapter(child: PlanFollowPrompt()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: PlanActualToggle(),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: PlanProfileChart(),
                  ),
                ),
                PlanChartReadouts(
                  onIssuesTap: () =>
                      ref.read(plannerPhoneTabProvider.notifier).state = 3,
                ),
                const Positioned(
                  left: 8,
                  right: 56,
                  bottom: 8,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    // Both chip groups scroll together, not just
                    // ContingencyChips' own inner scroll view: nested inside
                    // a plain Row here, that inner view took its full
                    // natural width instead of yielding to the Bailout/CCR
                    // chips, overflowing this bar on a narrow phone (the
                    // combined width of every chip no longer fits #3130).
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ContingencyChips(overlay: true),
                          SizedBox(width: 6),
                          ChartModeToggle(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.open_in_full, size: 18),
                    // PUSH (not go): back returns to this canvas with its
                    // state on the stack, instead of closing the app (#647).
                    onPressed: () =>
                        context.push('/planning/dive-planner/chart'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < tabs.length; i++)
                  ButtonSegment(value: i, label: Text(tabs[i])),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(plannerPhoneTabProvider.notifier).state =
                      selection.first,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: _ReadOnlyWhenDived(
            dived: ref.watch(selectedDiveActualProvider) != null,
            child: _phoneTabBody(tab),
          ),
        ),
      ],
    );
  }

  Widget _phoneTabBody(int tab) {
    switch (tab) {
      case 0:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [PlanDiveDetailsCard(), PlanTankList()]),
        );
      case 1:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SegmentList(),
        );
      case 2:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: PlanSetupAccordion(),
        );
      case 3:
      default:
        return PlanResultsPane(
          controller: _wideResultsController,
          shrinkWrap: true,
        );
    }
  }

  /// The results pane is always visible outside phone mode; scroll it to the
  /// issues section (the last one) when the issues chip is tapped.
  void _scrollWideToIssues() {
    if (!_wideResultsController.hasClients) return;
    _wideResultsController.animateTo(
      _wideResultsController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
    // so does Convert to Dive: that flow is already multi-step and should not
    // grow a modal.
    final series = ref.read(planSeriesNotifierProvider);
    if (!notifier.isPersisted && series.id == null) {
      final l10n = context.l10n;
      final units = UnitFormatter(ref.read(settingsProvider));
      final siteId = ref.read(divePlanNotifierProvider).siteId;
      final site = siteId == null
          ? null
          : await ref.read(siteProvider(siteId).future);
      if (!mounted) return;

      // Re-read after the site lookup rather than before it. No modal is up
      // while that read resolves, so the diver can still edit the plan and the
      // suggested name must describe what the plan is now.
      final planState = ref.read(divePlanNotifierProvider);
      final suggestedDepth = ref.read(planOutcomeProvider).maxDepth;
      // The lookup was keyed on the pre-await id. If the diver switched sites
      // while it resolved, the fetched name describes a site the plan no longer
      // uses, so drop it rather than pair it with fresh depth and date.
      final siteName = planState.siteId == siteId ? site?.name : null;

      final entered = await showPlanNameDialog(
        context,
        initialName: generateDefaultPlanName(
          siteName: siteName,
          depthLabel: suggestedDepth > 0
              ? units.formatDepth(suggestedDepth)
              : null,
          dateLabel: units.formatMonthDay(
            planState.startDateTime ?? DateTime.now(),
          ),
          fallbackLabel: l10n.plannerCanvas_name_defaultFallback,
        ),
        title: l10n.plannerCanvas_name_dialogTitle,
      );
      // Cancel aborts the save entirely: nothing is written and the plan stays
      // dirty, so the diver is never surprised by a name they rejected.
      if (entered == null) return;
      notifier.updateName(entered);
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

  /// Writes the plan's dives to the log as planned entries, or brings the ones
  /// already there up to date. A series needs a start to lay its dives out on,
  /// so one with none asks for the first dive's.
  Future<void> _updatePlannedDives() async {
    final series = ref.read(planSeriesNotifierProvider);
    if (series.isSeries &&
        series.follow == null &&
        series.dives.first.state.startDateTime == null) {
      final start = await pickPlanStart(context);
      if (start == null || !mounted) return;
      ref.read(planSeriesNotifierProvider.notifier).setFirstStart(start);
    }

    final result = await updatePlannedDives(ref.container);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!result.valid) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.blockedBy == null
                ? l10n.divePlanner_error_cannotConvert
                : l10n.plannerSeries_cannotUpdate(result.blockedBy!),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result.orphans.isNotEmpty) await _offerDeletingOrphans(result.orphans);
    if (!mounted) return;

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

  /// Offers to delete planned log entries of dives removed from the series.
  /// Either way they have been offered, so they are not offered again.
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
          await _runSavePlan();
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

  Future<void> _confirmLeavingSeries() async {
    final choice = await showUnsavedPlanDialog(context, isSeries: true);
    if (!mounted) return;
    switch (choice) {
      case UnsavedPlanChoice.save:
        await _runSavePlan();
        // The naming prompt can be cancelled, which leaves it unsaved.
        if (!mounted || ref.read(planSeriesDirtyProvider)) return;
      case UnsavedPlanChoice.discard:
        ref.read(divePlanNotifierProvider.notifier).newPlan();
      case UnsavedPlanChoice.cancel:
        return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteSeries(String seriesId) async {
    final name = ref.read(divePlanNotifierProvider).name;
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
    if (confirmed != true || !mounted) return;

    await ref.read(divePlanSeriesRepositoryProvider).deleteSeries(seriesId);
    if (!mounted) return;
    ref.read(divePlanNotifierProvider.notifier).newPlan();
    context.go('/planning');
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
    if (confirmed != true || !mounted) return;

    await repository.deletePlan(planId);
    if (!mounted) return;

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
        action: captured == null
            ? null
            : SnackBarAction(
                label: undoLabel,
                onPressed: () =>
                    repository.savePlan(captured, summary: capturedSummary),
              ),
      ),
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

/// Keeps the plan of a dive that has been dived from being edited: it is the
/// record of what was planned.
class _ReadOnlyWhenDived extends StatelessWidget {
  const _ReadOnlyWhenDived({required this.dived, required this.child});

  final bool dived;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(ignoring: dived, child: child);
}
