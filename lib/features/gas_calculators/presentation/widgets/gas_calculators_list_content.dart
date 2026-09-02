import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_list_content.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Gas Calculators list: the six calculators, then the safety disclaimer.
///
/// Rendered on its own on narrow windows, and as the master pane of the Gas
/// Calculators split view on desktop. [onToolSelected] is supplied only in the
/// second case; when it is null every row navigates as a full page. This is
/// the same contract [PlanningListContent] follows, and the rows are the same
/// [PlanningTile], so the two lists cannot drift apart visually.
class GasCalculatorsListContent extends ConsumerWidget {
  const GasCalculatorsListContent({
    super.key,
    this.onToolSelected,
    this.selectedId,
    this.showAppBar = true,
  });

  /// Called with a calculator id when a row is tapped in split view.
  final void Function(String?)? onToolSelected;

  /// Calculator currently shown in the detail pane, highlighted in the list.
  final String? selectedId;

  /// Whether this is a page in its own right. When false the list is a master
  /// pane and uses the compact [PlanningToolPane] header instead, so it lines
  /// up with the detail pane beside it.
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = gasCalculatorToolsOf(context);

    // Reset belongs to the list rather than to any one calculator: it returns
    // all six to their defaults at once.
    final actions = [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () => resetGasCalculators(ref),
        tooltip: context.l10n.gasCalculators_resetAll,
      ),
    ];

    final list = ListView(
      children: [
        const SizedBox(height: 8),
        ...List.generate(tools.length * 2 - 1, (index) {
          if (index.isOdd) return const Divider(height: 1);
          final tool = tools[index ~/ 2];
          return PlanningTile(
            tool: tool,
            selected: tool.id == selectedId,
            onToolSelected: onToolSelected,
          );
        }),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const _Disclaimer(),
        const SizedBox(height: 16),
      ],
    );

    if (!showAppBar) {
      return PlanningToolPane(
        // The page is pushed from Planning, so there is a route to pop. A
        // cold deep link straight to this URL has none, and an inert back
        // button reads as broken; AppBar makes the same test for its own
        // leading slot.
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: context.l10n.gasCalculators_title,
        actions: actions,
        child: list,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.gasCalculators_title),
        actions: actions,
      ),
      body: list,
    );
  }
}

/// The same planning disclaimer the hub carries. These calculators feed dive
/// plans, so the reminder travels with them.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.onSurfaceVariant,
              ).excludeFromSemantics(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.planning_info_disclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
