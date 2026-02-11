import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/deco_results_panel.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/gas_results_panel.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_profile_chart.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_settings_panel.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';

/// Main dive planner page with three tabs: Plan, Results, Profile.
///
/// The Plan tab contains:
/// - Settings panel (GF, SAC, site)
/// - Tank list (add/edit/remove tanks)
/// - Segment list (add/edit/remove/reorder segments)
///
/// The Results tab contains:
/// - Decompression info (NDL, TTS, ceiling, deco stops)
/// - Gas consumption projections
/// - Warnings and alerts
///
/// The Profile tab shows:
/// - Visual preview of the planned dive profile
class DivePlannerPage extends ConsumerStatefulWidget {
  /// Optional plan ID to load for editing.
  final String? planId;

  const DivePlannerPage({super.key, this.planId});

  @override
  ConsumerState<DivePlannerPage> createState() => _DivePlannerPageState();
}

class _DivePlannerPageState extends ConsumerState<DivePlannerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Sync tab controller with provider
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(plannerTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(divePlanNotifierProvider);
    final results = ref.watch(planResultsProvider);
    final hasWarnings = ref.watch(planHasWarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(planState.name),
        actions: [
          // Quick add button
          IconButton(
            icon: const Icon(Icons.add_chart),
            tooltip: context.l10n.divePlanner_action_quickPlan,
            onPressed: () => _showSimplePlanDialog(context),
          ),
          // Save button
          IconButton(
            icon: Icon(planState.isDirty ? Icons.save : Icons.save_outlined),
            tooltip: context.l10n.divePlanner_action_savePlan,
            onPressed: planState.isDirty ? _savePlan : null,
          ),
          // Convert to dive button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: context.l10n.divePlanner_action_moreOptions,
            onSelected: (value) {
              switch (value) {
                case 'convert':
                  _convertToDive();
                  break;
                case 'reset':
                  _resetPlan();
                  break;
                case 'rename':
                  _showRenameDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'convert',
                child: ListTile(
                  leading: const Icon(Icons.scuba_diving),
                  title: Text(context.l10n.divePlanner_action_convertToDive),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(context.l10n.divePlanner_action_renamePlan),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(context.l10n.divePlanner_action_resetPlan),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: context.l10n.divePlanner_tab_plan,
              icon: const Icon(Icons.edit_note),
            ),
            Tab(
              text: context.l10n.divePlanner_tab_results,
              icon: Semantics(
                label: hasWarnings
                    ? context.l10n.divePlanner_label_resultsWithWarnings(
                        results.warnings.length,
                      )
                    : context.l10n.divePlanner_tab_results,
                child: Badge(
                  isLabelVisible: hasWarnings,
                  label: Text('${results.warnings.length}'),
                  child: const Icon(Icons.analytics),
                ),
              ),
            ),
            Tab(
              text: context.l10n.divePlanner_tab_profile,
              icon: const Icon(Icons.show_chart),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPlanTab(), _buildResultsTab(), _buildProfileTab()],
      ),
    );
  }

  Widget _buildPlanTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanSettingsPanel(),
          SizedBox(height: 16),
          PlanTankList(),
          SizedBox(height: 16),
          SegmentList(),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [DecoResultsPanel(), SizedBox(height: 16), GasResultsPanel()],
      ),
    );
  }

  Widget _buildProfileTab() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: PlanProfileChart(),
    );
  }

  void _showSimplePlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SimplePlanDialog(),
    );
  }

  void _savePlan() {
    // TODO: Implement save to database
    ref.read(divePlanNotifierProvider.notifier).markSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.divePlanner_message_planSaved)),
    );
  }

  void _convertToDive() {
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

    // TODO: Implement convert to dive
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.divePlanner_message_convertingPlan)),
    );
  }

  void _resetPlan() {
    showDialog(
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
    final planState = ref.read(divePlanNotifierProvider);
    final controller = TextEditingController(text: planState.name);

    showDialog(
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
