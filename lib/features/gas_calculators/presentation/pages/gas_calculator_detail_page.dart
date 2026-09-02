import 'package:flutter/material.dart';

import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_summary_widget.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mnd_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One gas calculator, in whichever chrome its surroundings need.
///
/// Embedded, it is the Gas Calculators detail pane: a [PlanningToolPane]
/// header and the calculator, with no [AppBar], because the split view
/// already sits inside a [Scaffold]. As a full page it is what a narrow
/// window pushes when a calculator row is tapped, and carries its own app bar
/// with the automatic back button.
///
/// Reset lives on the list, not here: it resets all six calculators at once,
/// so putting it on one of them would misdescribe what it does.
class GasCalculatorDetailPage extends StatelessWidget {
  const GasCalculatorDetailPage({
    super.key,
    required this.toolId,
    this.embedded = false,
  });

  /// One of [kGasCalculatorIds]. Arrives from the URL, so it may be anything.
  final String toolId;

  /// Renders without its own [Scaffold] and [AppBar], for the detail pane.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tool = _toolFor(context, toolId);
    final calculator = _calculatorFor(toolId);

    // Unknown ids land on the summary rather than an error surface: the id
    // comes from the URL, so a stale or hand-edited link should end up
    // somewhere useful. Matches PlanningPage's fallback.
    if (tool == null || calculator == null) {
      return embedded
          ? const GasCalculatorsSummaryWidget()
          : Scaffold(
              appBar: AppBar(title: Text(context.l10n.gasCalculators_title)),
              body: const GasCalculatorsSummaryWidget(),
            );
    }

    if (embedded) {
      return PlanningToolPane(title: tool.title, child: calculator);
    }

    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: calculator,
    );
  }

  PlanningTool? _toolFor(BuildContext context, String id) {
    for (final tool in gasCalculatorToolsOf(context)) {
      if (tool.id == id) return tool;
    }
    return null;
  }

  /// Kept in step with [kGasCalculatorIds] by
  /// `gas_calculator_detail_page_test.dart`, so a calculator cannot be added
  /// to the list and forgotten here.
  Widget? _calculatorFor(String id) {
    switch (id) {
      case 'mod':
        return const ModCalculator();
      case 'best-mix':
        return const BestMixCalculator();
      case 'consumption':
        return const GasConsumptionCalculator();
      case 'rock-bottom':
        return const RockBottomCalculator();
      case 'mnd':
        return const MndCalculator();
      case 'blender':
        return const GasBlenderCalculator();
      default:
        return null;
    }
  }
}
