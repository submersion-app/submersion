import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Simple dialog for creating a basic rectangular dive plan.
///
/// This dialog allows users to quickly create a dive plan by specifying
/// just two parameters:
/// - Maximum depth (5-40m)
/// - Bottom time (5-120 minutes)
///
/// The planner will automatically generate:
/// - A descent segment at 18 m/min
/// - A bottom segment at the specified depth
/// - An ascent segment at 9 m/min
/// - A safety stop at 5m for 3 minutes
class SimplePlanDialog extends ConsumerStatefulWidget {
  const SimplePlanDialog({super.key});

  @override
  ConsumerState<SimplePlanDialog> createState() => _SimplePlanDialogState();
}

class _SimplePlanDialogState extends ConsumerState<SimplePlanDialog> {
  double _depth = 18;
  int _bottomTime = 45;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.divePlanner_action_quickPlan),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.divePlanner_quickPlan_subtitle,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Depth slider
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  l10n.divePlanner_quickPlan_depthLabel,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: Semantics(
                  label: l10n.divePlanner_quickPlan_depthSemantics(
                    units.formatDepth(_depth),
                  ),
                  child: Slider(
                    value: _depth,
                    min: 5,
                    max: 40,
                    divisions: 35,
                    label: units.formatDepth(_depth),
                    onChanged: (v) => setState(() => _depth = v),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  units.formatDepth(_depth),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Time slider
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  l10n.divePlanner_quickPlan_timeLabel,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: Semantics(
                  label: l10n.divePlanner_quickPlan_bottomTimeSemantics(
                    _bottomTime,
                  ),
                  child: Slider(
                    value: _bottomTime.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: l10n.divePlanner_quickPlan_minutes(_bottomTime),
                    onChanged: (v) => setState(() => _bottomTime = v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  l10n.divePlanner_quickPlan_minutes(_bottomTime),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Preview info
          Semantics(
            label: l10n.divePlanner_quickPlan_previewSemantics(
              units.formatDepth(_depth),
              _bottomTime,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.divePlanner_quickPlan_previewTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Text(
                      l10n.divePlanner_quickPlan_previewDescent(
                        units.formatDepth(_depth),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      l10n.divePlanner_quickPlan_previewBottomTime(_bottomTime),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      l10n.divePlanner_quickPlan_previewAscent,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () {
            ref
                .read(divePlanNotifierProvider.notifier)
                .addSimplePlan(
                  maxDepth: _depth,
                  bottomTimeMinutes: _bottomTime,
                );
            Navigator.pop(context);
          },
          child: Text(l10n.divePlanner_quickPlan_create),
        ),
      ],
    );
  }
}
