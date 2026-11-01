import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the chart shows before the plan has a profile to draw.
class PlanChartEmptyState extends ConsumerWidget {
  const PlanChartEmptyState({super.key, required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A mission builds its profile from the route, whose card says what is
    // missing; segments and a quick plan (which would end the mission) are
    // not what it needs.
    final missionOn = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
    // Scrollable so the fixed-height content survives the phone layout's
    // 160 px chart floor instead of overflowing on short viewports.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              context.l10n.divePlanner_message_noProfile,
              style: theme.textTheme.titleMedium,
            ),
            if (!missionOn) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.divePlanner_message_addSegmentsForProfile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SimplePlanDialog(),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(context.l10n.divePlanner_action_quickPlan),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
