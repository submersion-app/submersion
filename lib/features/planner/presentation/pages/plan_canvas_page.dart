import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_settings_panel.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/follow_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_canvas_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The Live Profile Canvas: a chart-centric dive planner. Editing state lives
/// on [divePlanNotifierProvider]; every displayed number comes from the
/// PlanEngine via [planOutcomeProvider].
class PlanCanvasPage extends ConsumerStatefulWidget {
  const PlanCanvasPage({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<PlanCanvasPage> createState() => _PlanCanvasPageState();
}

class _PlanCanvasPageState extends ConsumerState<PlanCanvasPage> {
  final _sheetController = DraggableScrollableController();

  /// Owns the always-visible results pane on wide layouts so it is created
  /// once (not per build) and disposed with the page.
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
    _sheetController.dispose();
    _wideResultsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(divePlanNotifierProvider);
    final isWide = ResponsiveBreakpoints.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
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
            // State-derived OC/CCR toggle (replaces the phase-3 placeholder).
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref
                  .read(divePlanNotifierProvider.notifier)
                  .updateMode(
                    planState.mode == domain.PlanMode.ccr
                        ? domain.PlanMode.oc
                        : domain.PlanMode.ccr,
                  ),
              child: PlanChip(
                label: planState.mode == domain.PlanMode.ccr ? 'CCR' : 'OC',
                emphasized: planState.mode == domain.PlanMode.ccr,
              ),
            ),
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
                'reset',
                Icons.refresh,
                context.l10n.divePlanner_action_resetPlan,
              ),
            ],
          ),
        ],
      ),
      body: isWide ? _buildWide() : _buildPhone(),
    );
  }

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
        _showSettingsSheet(context);
      case 'convert':
        _convertToDive();
      case 'reset':
        _resetPlan();
    }
  }

  // --- Phone: chart + chips + editor list, results in a draggable sheet ---

  Widget _buildPhone() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.42,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: PlanCanvasChart(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PlanStatusChips(onIssuesTap: _openResultsSheet),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: ContingencyChips(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
                    children: const [SegmentList(), PlanTankList()],
                  ),
                ),
              ],
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              minChildSize: 0.08,
              initialChildSize: 0.08,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.08, 0.5, 0.85],
              builder: (context, scrollController) => Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: PlanResultsSheet(controller: scrollController),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openResultsSheet() {
    _sheetController.animateTo(
      0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// On wide layouts the results pane is always visible; scroll it to the
  /// issues section (the last one) when the issues chip is tapped.
  void _scrollWideToIssues() {
    if (!_wideResultsController.hasClients) return;
    _wideResultsController.animateTo(
      _wideResultsController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // --- Wide: editor column, chart + chips, always-visible results pane ---

  Widget _buildWide() {
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const PlanSettingsPanel(),
              if (ref.watch(divePlanNotifierProvider).mode ==
                  domain.PlanMode.ccr)
                const CcrSettingsSection(),
              const ContingencySettingsSection(),
              const SizedBox(height: 12),
              const PlanTankList(),
              const SizedBox(height: 12),
              const SegmentList(),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: PlanCanvasChart(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PlanStatusChips(onIssuesTap: _scrollWideToIssues),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: ContingencyChips(),
              ),
              SizedBox(
                height: 260,
                child: PlanResultsSheet(controller: _wideResultsController),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Actions ---

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

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Consumer(
            builder: (context, ref, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PlanSettingsPanel(),
                if (ref.watch(divePlanNotifierProvider).mode ==
                    domain.PlanMode.ccr)
                  const CcrSettingsSection(),
                const ContingencySettingsSection(),
              ],
            ),
          ),
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
