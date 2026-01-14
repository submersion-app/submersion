import 'package:flutter/material.dart';

import '../../../../core/providers/provider.dart';
import '../providers/dive_planner_providers.dart';
import '../widgets/deco_results_panel.dart';
import '../widgets/gas_results_panel.dart';
import '../widgets/plan_profile_chart.dart';
import '../widgets/plan_settings_panel.dart';
import '../widgets/plan_tank_list.dart';
import '../widgets/segment_list.dart';
import '../widgets/simple_plan_dialog.dart';

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
            tooltip: 'Quick Plan',
            onPressed: () => _showSimplePlanDialog(context),
          ),
          // Save button
          IconButton(
            icon: Icon(planState.isDirty ? Icons.save : Icons.save_outlined),
            tooltip: 'Save Plan',
            onPressed: planState.isDirty ? _savePlan : null,
          ),
          // Convert to dive button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
              const PopupMenuItem(
                value: 'convert',
                child: ListTile(
                  leading: Icon(Icons.scuba_diving),
                  title: Text('Convert to Dive'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename Plan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Reset Plan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Plan', icon: Icon(Icons.edit_note)),
            Tab(
              text: 'Results',
              icon: Badge(
                isLabelVisible: hasWarnings,
                label: Text('${results.warnings.length}'),
                child: const Icon(Icons.analytics),
              ),
            ),
            const Tab(text: 'Profile', icon: Icon(Icons.show_chart)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Settings section
              PlanSettingsPanel(),
              SizedBox(height: 16),

              // Tanks section
              PlanTankList(),
              SizedBox(height: 16),

              // Segments section
              SegmentList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Decompression info
              DecoResultsPanel(),
              SizedBox(height: 16),

              // Gas consumption
              GasResultsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: const PlanProfileChart(),
        ),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plan saved')));
  }

  void _convertToDive() {
    final isValid = ref.read(planIsValidProvider);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot convert: plan has critical warnings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Implement convert to dive
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Converting plan to dive...')));
  }

  void _resetPlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Plan'),
        content: const Text(
          'Are you sure you want to reset this plan? All segments and settings will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(divePlanNotifierProvider.notifier).newPlan();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
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
      builder: (context) => AlertDialog(
        title: const Text('Rename Plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Plan Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(divePlanNotifierProvider.notifier)
                  .updateName(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
