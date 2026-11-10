import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/next_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/previous_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/surface_interval_result.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/tissue_recovery_chart.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/shared/widgets/safety_note.dart';

/// Surface Interval Tool page for planning repetitive dives.
///
/// Allows divers to:
/// 1. Input first dive parameters (depth, time, gas mix)
/// 2. Input desired second dive parameters (depth, time, gas mix)
/// 3. Calculate the minimum surface interval needed
/// 4. Visualize tissue off-gassing over time
class SurfaceIntervalToolPage extends ConsumerWidget {
  /// Renders without its own Scaffold and AppBar, for the Planning detail
  /// pane. See [PlanningToolPane].
  final bool embedded;

  const SurfaceIntervalToolPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: context.l10n.surfaceInterval_action_resetDefaults,
        onPressed: () => resetSurfaceIntervalInputs(ref),
      ),
    ];

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // First Dive Input
        const PreviousDiveInput(),
        const SizedBox(height: 16),

        // Second Dive Input
        const NextDiveInput(),
        const SizedBox(height: 16),

        // Result Card
        const SurfaceIntervalResult(),
        const SizedBox(height: 16),

        // Tissue Recovery Chart
        const TissueRecoveryChart(),
        const SizedBox(height: 16),

        // The tool's disclaimer stays on the page; the tissue explanation
        // moved to the Tissue Recovery card's info icon.
        SafetyNote(text: context.l10n.surfaceInterval_disclaimer),
        const SizedBox(height: 24),
      ],
    );

    if (embedded) {
      return PlanningToolPane(
        title: context.l10n.surfaceInterval_title,
        actions: actions,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.surfaceInterval_title),
        actions: actions,
      ),
      body: content,
    );
  }
}
