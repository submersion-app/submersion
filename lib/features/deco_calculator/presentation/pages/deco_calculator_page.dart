import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../dive_log/domain/entities/dive.dart';
import '../../../dive_log/presentation/widgets/deco_info_panel.dart';
import '../../../dive_planner/presentation/providers/dive_planner_providers.dart';
import '../providers/deco_calculator_providers.dart';
import '../widgets/depth_slider.dart';
import '../widgets/gas_mix_selector.dart';
import '../widgets/gas_warnings_display.dart';
import '../widgets/time_slider.dart';

/// Interactive deco calculator page with real-time calculations.
///
/// Provides sliders for depth, time, and gas mix with instant feedback
/// on NDL, ceiling, TTS, and tissue loading.
class DecoCalculatorPage extends ConsumerWidget {
  const DecoCalculatorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decoStatus = ref.watch(calcDecoStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deco Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => resetCalculator(ref),
            tooltip: 'Reset to defaults',
          ),
          TextButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Add to Planner'),
            onPressed: () => _addToPlan(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input parameters card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dive Parameters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Depth slider
                    const DepthSlider(),
                    const SizedBox(height: 24),

                    // Time slider
                    const TimeSlider(),
                    const SizedBox(height: 24),

                    // Gas mix selector
                    const GasMixSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gas warnings
            const GasWarningsDisplay(),
            const SizedBox(height: 16),

            // Deco status panel (reusing existing widget)
            DecoInfoPanel(
              status: decoStatus,
              showTissueChart: true,
              showDecoStops: true,
              showHeader: true,
              useCard: true,
            ),
          ],
        ),
      ),
    );
  }

  void _addToPlan(BuildContext context, WidgetRef ref) {
    final depth = ref.read(calcDepthProvider);
    final time = ref.read(calcTimeProvider);
    final o2 = ref.read(calcO2Provider);
    final he = ref.read(calcHeProvider);
    final gasMix = GasMix(o2: o2, he: he);

    // Get the planner notifier
    final planNotifier = ref.read(divePlanNotifierProvider.notifier);
    final planState = ref.read(divePlanNotifierProvider);

    // Update the first tank's gas mix if there is one
    if (planState.tanks.isNotEmpty) {
      final firstTank = planState.tanks.first;
      planNotifier.updateTank(firstTank.id, firstTank.copyWith(gasMix: gasMix));
    }

    // Add the simple plan with calculator values
    planNotifier.addSimplePlan(maxDepth: depth, bottomTimeMinutes: time);

    // Navigate to planner
    context.go('/planner');

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created plan: ${depth.toStringAsFixed(0)}m for ${time}min on ${gasMix.name}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
