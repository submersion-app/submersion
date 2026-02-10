import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_info_panel.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/depth_slider.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/gas_mix_selector.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/gas_warnings_display.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/time_slider.dart';

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
          Tooltip(
            message: 'Create a dive plan from current parameters',
            child: TextButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Add to Planner'),
              onPressed: () => _addToPlan(context, ref),
            ),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dive Parameters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const DepthSlider(),
                    const SizedBox(height: 16),
                    const TimeSlider(),
                    const SizedBox(height: 16),
                    const GasMixSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const GasWarningsDisplay(),
            const SizedBox(height: 12),
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
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

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
    context.go('/planning/dive-planner');

    // Show confirmation with user's preferred units
    final displayDepth = units.convertDepth(depth);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created plan: ${displayDepth.toStringAsFixed(0)}${units.depthSymbol} for ${time}min on ${gasMix.name}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
