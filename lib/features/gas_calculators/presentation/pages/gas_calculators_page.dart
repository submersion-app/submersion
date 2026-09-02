import 'package:flutter/material.dart';

import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_list_content.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_summary_widget.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Gas Calculators hub: the six calculators as a list, the selected one
/// beside it.
///
/// This is a hub one level below Planning and is built the same way, so the
/// two read as the same kind of surface. It takes the whole window rather
/// than a Planning detail pane, for the reason the dive planner does: a split
/// view cannot be nested inside what is left of the window beside a 440px
/// master pane.
///
/// Planning enters it with `go`, not `push`, because the scaffold below
/// selects with `go` and the two verbs key the page differently. See
/// [PlanningToolPresentation.splitViewPage].
///
/// The six calculators used to be tabs here. The strip cost the pane roughly
/// 72px of height on every calculator and crowded six icon-and-text labels
/// into whatever width was left over; the list pays neither price.
class GasCalculatorsPage extends StatelessWidget {
  const GasCalculatorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: kGasCalculatorsToolId,
        // Not the default 'selected': 'calc' keeps the URL self-describing
        // (/planning/gas-calculators?calc=mod), matching the hub above, which
        // uses 'tool' for the same reason.
        queryParamKey: 'calc',
        masterBuilder: (context, onItemSelected, selectedId) =>
            GasCalculatorsListContent(
              onToolSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, toolId) =>
            GasCalculatorDetailPage(toolId: toolId, embedded: true),
        summaryBuilder: (context) => const GasCalculatorsSummaryWidget(),
        mobileDetailRoute: (id) => '$kGasCalculatorsRoutePrefix/$id',
      );
    }

    return const GasCalculatorsListContent();
  }
}
