import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/data/services/plan_slate_pdf_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/follow_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Mission Control: a thin layout router over the planner's three panes.
/// Editing state lives on [divePlanNotifierProvider]; every displayed number
/// comes from the PlanEngine via [planOutcomeProvider].
///
/// Modes, decided from the space the page is actually given:
/// - >= 1160 px: editor pane, chart column, results pane (side panes
///   collapsible with remembered state)
/// - 760-1160 px: chart column + results pane; the editor lives in a drawer
/// - < 760 px: phone Chart + Tab Deck (Plan / Tanks / Setup / Results)
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
    final planId = widget.planId;
    if (planId != null) {
      // Riverpod 3 forbids provider mutation during widget lifecycle
      // callbacks; defer the load to a microtask.
      Future.microtask(() {
        if (!mounted) return;
        ref.read(divePlanNotifierProvider.notifier).loadPlanById(planId);
      });
    }
  }

  @override
  void dispose() {
    _wideResultsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(divePlanNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: () => _showRenameDialog(context),
                child: Text(planState.name),
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
                value: '${planState.gfLow}/${planState.gfHigh}',
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
            icon: Icon(planState.isDirty ? Icons.save : Icons.save_outlined),
            tooltip: context.l10n.divePlanner_action_savePlan,
            onPressed: planState.isDirty ? _savePlan : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: context.l10n.divePlanner_action_moreOptions,
            onSelected: _onMenu,
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
              ),
              _menuItem(
                'settings',
                Icons.tune,
                context.l10n.divePlanner_label_planSettings,
              ),
              _menuItem(
                'convert',
                Icons.scuba_diving,
                context.l10n.divePlanner_action_convertToDive,
              ),
              _menuItem(
                'slate',
                Icons.picture_as_pdf,
                context.l10n.plannerCanvas_slate_menu,
              ),
              _menuItem(
                'share',
                Icons.ios_share,
                context.l10n.plannerCanvas_share_menu,
              ),
              _menuItem(
                'reset',
                Icons.refresh,
                context.l10n.divePlanner_action_resetPlan,
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= 760) return _buildDesktop(fullWidth: width >= 1160);
          return _buildPhone(constraints);
        },
      ),
    );
  }

  static domain.PlanMode _nextMode(domain.PlanMode mode) => switch (mode) {
    domain.PlanMode.oc => domain.PlanMode.ccr,
    domain.PlanMode.ccr => domain.PlanMode.scr,
    domain.PlanMode.scr => domain.PlanMode.pscr,
    domain.PlanMode.pscr => domain.PlanMode.oc,
  };

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _onMenu(String value) {
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
        _convertToDive();
      case 'slate':
        _exportSlate();
      case 'share':
        _sharePlanFile();
      case 'reset':
        _resetPlan();
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
    final editorCollapsed = ref.watch(editorPaneCollapsedProvider);
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
          const SizedBox(width: 320, child: PlanEditorPane()),
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
          child: ContingencyChips(),
        ),
      ],
    );
  }

  Widget _buildPhone(BoxConstraints constraints) {
    final tab = ref.watch(plannerPhoneTabProvider);
    final tabs = [
      context.l10n.divePlanner_tab_plan,
      context.l10n.divePlanner_label_tanks,
      context.l10n.plannerCanvas_tab_setup,
      context.l10n.divePlanner_tab_results,
    ];
    return Column(
      children: [
        SizedBox(
          height: constraints.maxHeight * 0.40,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: PlanProfileChart(),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  onPressed: () => context.go('/planning/dive-planner/chart'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: PlanStatusChips(
            onIssuesTap: () =>
                ref.read(plannerPhoneTabProvider.notifier).state = 3,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: ContingencyChips(),
        ),
        const SizedBox(height: 8),
        Padding(
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
        const SizedBox(height: 8),
        Expanded(child: _phoneTabBody(tab)),
      ],
    );
  }

  Widget _phoneTabBody(int tab) {
    switch (tab) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [SegmentList()],
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [PlanTankList()],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [PlanSetupAccordion()],
        );
      case 3:
      default:
        return PlanResultsPane(controller: _wideResultsController);
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

  Future<void> _sharePlanFile() async {
    final state = ref.read(divePlanNotifierProvider);
    final json = planToSubplanJson(divePlanFromState(state));
    final safeName = state.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    await saveAndShareFile(
      json,
      '${safeName.isEmpty ? 'dive_plan' : safeName}.$subplanExtension',
      'application/json',
    );
  }

  Future<void> _exportSlate() async {
    final l10n = context.l10n;
    final state = ref.read(divePlanNotifierProvider);
    final labels = PlanSlateLabels(
      runtimeTable: l10n.divePlanner_label_decoSchedule,
      gasPlan: l10n.divePlanner_label_gasConsumption,
      contingencies: l10n.plannerCanvas_contingency_title,
      lostGasLabel: l10n.plannerCanvas_contingency_lostGas,
      rangeTable: l10n.plannerCanvas_range_title,
      bailout: l10n.plannerCanvas_bailout_title,
      stop: l10n.plannerCanvas_table_stop,
      depth: l10n.plannerCanvas_table_depth,
      runtime: l10n.plannerCanvas_table_runtime,
      gas: l10n.plannerCanvas_table_gas,
      turnAt: l10n.plannerCanvas_slate_turn,
      minGas: l10n.plannerCanvas_slate_minGas,
      base: l10n.plannerCanvas_range_base,
    );

    final bytes = await const PlanSlatePdfService().buildSlate(
      plan: divePlanFromState(state),
      outcome: ref.read(planOutcomeProvider),
      deviations: ref.read(planDeviationsProvider),
      lostGas: ref.read(planLostGasProvider),
      rangeTable: ref.read(planRangeTableProvider),
      bailout: ref.read(planBailoutProvider),
      units: UnitFormatter(ref.read(settingsProvider)),
      labels: labels,
    );

    final safeName = state.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    await sharePdfBytes(
      bytes,
      '${safeName.isEmpty ? 'dive_plan' : safeName}_slate.pdf',
    );
  }

  Future<void> _savePlan() async {
    final outcome = ref.read(planOutcomeProvider);
    await ref
        .read(divePlanNotifierProvider.notifier)
        .save(
          summary: PlanSummaryData(
            maxDepth: outcome.maxDepth,
            runtimeSeconds: outcome.runtimeSeconds,
            ttsSeconds: outcome.ttsAtBottom,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.divePlanner_message_planSaved)),
    );
  }

  Future<void> _convertToDive() async {
    final isValid = ref.read(planIsValidProvider);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.divePlanner_error_cannotConvert),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final outcome = ref.read(planOutcomeProvider);
    final series = ref.read(planCanvasSeriesProvider);

    // The state's segments stop at the bottom; the engine computes the
    // ascent. Persist the full computed profile so the logged dive shows
    // the deco schedule the plan produced.
    final dive = notifier.toDive().copyWith(
      profile: [
        for (final point in series.profile)
          DiveProfilePoint(
            timestamp: point.timeSeconds.round(),
            depth: point.depth,
          ),
      ],
      runtime: Duration(seconds: outcome.runtimeSeconds),
      maxDepth: outcome.maxDepth,
      avgDepth: _timeWeightedAverageDepth(series),
    );

    final created = await ref.read(diveRepositoryProvider).createDive(dive);
    notifier.setLinkedDive(created.id);
    await notifier.save(
      summary: PlanSummaryData(
        maxDepth: outcome.maxDepth,
        runtimeSeconds: outcome.runtimeSeconds,
        ttsSeconds: outcome.ttsAtBottom,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.plannerCanvas_convert_success),
        action: SnackBarAction(
          label: context.l10n.plannerCanvas_convert_view,
          onPressed: () => context.go('/dives/${created.id}'),
        ),
      ),
    );
  }

  static double _timeWeightedAverageDepth(PlanCanvasSeries series) {
    final profile = series.profile;
    if (profile.length < 2) return 0;
    double weighted = 0;
    for (var i = 1; i < profile.length; i++) {
      final dt = profile[i].timeSeconds - profile[i - 1].timeSeconds;
      weighted += dt * (profile[i].depth + profile[i - 1].depth) / 2;
    }
    final total = profile.last.timeSeconds - profile.first.timeSeconds;
    return total > 0 ? weighted / total : 0;
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

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(
      text: ref.read(divePlanNotifierProvider).name,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.divePlanner_action_renamePlan),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.divePlanner_field_planName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(divePlanNotifierProvider.notifier)
                  .updateName(controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.common_action_save),
          ),
        ],
      ),
    );
  }
}
