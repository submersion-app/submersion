import 'package:flutter/material.dart';

import '../providers/gas_calculators_providers.dart';
import '../widgets/best_mix_calculator.dart';
import '../widgets/gas_consumption_calculator.dart';
import '../widgets/mod_calculator.dart';
import '../widgets/rock_bottom_calculator.dart';
import 'package:submersion/core/providers/provider.dart';

/// Gas Calculators page with tabbed interface.
///
/// Provides 4 specialized diving gas calculators:
/// - MOD: Maximum Operating Depth for a given gas mix
/// - Best Mix: Ideal O2% for a target depth
/// - Gas Consumption: How much gas a dive will use
/// - Rock Bottom: Minimum reserve for emergency ascent
class GasCalculatorsPage extends ConsumerStatefulWidget {
  const GasCalculatorsPage({super.key});

  @override
  ConsumerState<GasCalculatorsPage> createState() => _GasCalculatorsPageState();
}

class _GasCalculatorsPageState extends ConsumerState<GasCalculatorsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gas Calculators'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => resetGasCalculators(ref),
            tooltip: 'Reset all calculators',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: MediaQuery.of(context).size.width < 500,
          tabAlignment: MediaQuery.of(context).size.width < 500
              ? TabAlignment.start
              : TabAlignment.fill,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_downward), text: 'MOD'),
            Tab(icon: Icon(Icons.science), text: 'Best Mix'),
            Tab(icon: Icon(Icons.local_gas_station), text: 'Consumption'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Rock Bottom'),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ModCalculator(),
          BestMixCalculator(),
          GasConsumptionCalculator(),
          RockBottomCalculator(),
        ],
      ),
    );
  }
}
