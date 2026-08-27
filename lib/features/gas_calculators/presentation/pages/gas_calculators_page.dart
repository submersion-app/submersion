import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mnd_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/core/providers/provider.dart';

/// Gas Calculators page with tabbed interface.
///
/// Provides 6 specialized diving gas calculators:
/// - MOD: Maximum Operating Depth for a given gas mix
/// - Best Mix: Ideal O2% for a target depth
/// - Gas Consumption: How much gas a dive will use
/// - Rock Bottom: Minimum reserve for emergency ascent
/// - MND/END: Maximum Narcotic Depth / Equivalent Narcotic Depth
/// - Blender: Partial-pressure fill procedure for a target mix
class GasCalculatorsPage extends ConsumerStatefulWidget {
  /// Renders without its own Scaffold and AppBar, for the Planning detail
  /// pane. See [PlanningToolPane].
  final bool embedded;

  const GasCalculatorsPage({super.key, this.embedded = false});

  @override
  ConsumerState<GasCalculatorsPage> createState() => _GasCalculatorsPageState();
}

class _GasCalculatorsPageState extends ConsumerState<GasCalculatorsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () => resetGasCalculators(ref),
        tooltip: context.l10n.gasCalculators_resetAll,
      ),
    ];

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: MediaQuery.of(context).size.width < 500,
      tabAlignment: MediaQuery.of(context).size.width < 500
          ? TabAlignment.start
          : TabAlignment.fill,
      tabs: [
        Tab(
          icon: const Icon(Icons.arrow_downward),
          text: context.l10n.gasCalculators_tab_mod,
        ),
        Tab(
          icon: const Icon(Icons.science),
          text: context.l10n.gasCalculators_tab_bestMix,
        ),
        Tab(
          icon: const Icon(Icons.local_gas_station),
          text: context.l10n.gasCalculators_tab_consumption,
        ),
        Tab(
          icon: const Icon(Icons.warning_amber),
          text: context.l10n.gasCalculators_tab_rockBottom,
        ),
        Tab(
          icon: const Icon(Icons.psychology),
          text: context.l10n.gasCalculators_tab_mnd,
        ),
        Tab(
          icon: const Icon(Icons.gas_meter),
          text: context.l10n.gasCalculators_tab_blender,
        ),
      ],
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
    );

    final body = TabBarView(
      controller: _tabController,
      children: const [
        ModCalculator(),
        BestMixCalculator(),
        GasConsumptionCalculator(),
        RockBottomCalculator(),
        MndCalculator(),
        GasBlenderCalculator(),
      ],
    );

    if (widget.embedded) {
      // The pane has no AppBar to hang the TabBar off, so it becomes an
      // ordinary first row above the tab views.
      return PlanningToolPane(
        title: context.l10n.gasCalculators_title,
        actions: actions,
        child: Column(
          children: [
            tabBar,
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.gasCalculators_title),
        actions: actions,
        bottom: tabBar,
      ),
      body: body,
    );
  }
}
