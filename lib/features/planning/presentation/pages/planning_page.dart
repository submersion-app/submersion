import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculators_page.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_list_content.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_summary_widget.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/surface_interval_tool/presentation/pages/surface_interval_tool_page.dart';
import 'package:submersion/features/weight_planner/presentation/pages/weight_planner_page.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Planning hub page: the planner (new plan + recent saved plans) front and
/// center, calculators as a tools list below.
///
/// On desktop (>=1100px) the calculators open in a detail pane so the hub
/// list stays visible, matching Settings and Statistics. The dive planner is
/// the exception and always takes the whole window; see [kDivePlannerToolId].
class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'planning',
        // Not the default 'selected': the planning hub shares no route with
        // another scaffold today, but 'tool' keeps the URL self-describing
        // (/planning?tool=deco-calculator).
        queryParamKey: 'tool',
        masterBuilder: (context, onItemSelected, selectedId) =>
            PlanningListContent(
              onToolSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, toolId) => _buildTool(context, toolId),
        summaryBuilder: (context) => const PlanningSummaryWidget(),
        mobileDetailRoute: (id) => '/planning/$id',
      );
    }

    return const PlanningListContent();
  }

  /// The embedded form of each tool. Unknown ids fall back to the summary
  /// rather than an error surface: the id comes from the URL, so a stale or
  /// hand-edited link should land somewhere useful.
  Widget _buildTool(BuildContext context, String toolId) {
    switch (toolId) {
      case 'deco-calculator':
        return const DecoCalculatorPage(embedded: true);
      case 'gas-calculators':
        return const GasCalculatorsPage(embedded: true);
      case 'weight-calculator':
        return const WeightPlannerPage(embedded: true);
      case 'surface-interval':
        return const SurfaceIntervalToolPage(embedded: true);
      case 'no-fly':
        return const NoFlyPage(embedded: true);
      default:
        return const PlanningSummaryWidget();
    }
  }
}
