import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
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

  final _depthField = GlobalKey<PlanNumberFieldState>();
  final _timeField = GlobalKey<PlanNumberFieldState>();

  // The band the quick plan covers, in metres and minutes. Anything outside
  // it is a dive that wants real segments rather than a rectangle.
  static const _minDepthMeters = 5.0;
  static const _maxDepthMeters = 40.0;
  static const _minBottomTime = 5.0;
  static const _maxBottomTime = 120.0;

  void _create() {
    // Tapping Create on a touch screen leaves focus in whichever box was
    // being edited, so settle both the way leaving them would before reading
    // _depth and _bottomTime.
    _depthField.currentState?.commit();
    _timeField.currentState?.commit();
    ref
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: _depth, bottomTimeMinutes: _bottomTime);
    Navigator.pop(context);
  }

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

          // Depth and bottom time as number boxes, on the same two columns
          // as the Setup accordion's rows.
          PlanNumberField(
            key: _depthField,
            label: l10n.divePlanner_quickPlan_depthLabel,
            value: units.convertDepth(_depth),
            hintValue: units.convertDepth(_depth),
            suffixText: units.depthSymbol,
            isInteger: true,
            allowEmpty: false,
            // Narrowed inward so every whole number the box accepts is inside
            // 5-40 m: 16.4-131.2 ft becomes 17-131 ft, never 16 (4.88 m).
            min: units.convertDepth(_minDepthMeters).ceilToDouble(),
            max: units.convertDepth(_maxDepthMeters).floorToDouble(),
            semanticsLabel: l10n.divePlanner_quickPlan_depthSemantics(
              units.formatDepth(_depth),
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _depth = units.depthToMeters(v));
            },
          ),
          PlanNumberField(
            key: _timeField,
            label: l10n.divePlanner_quickPlan_timeLabel,
            value: _bottomTime.toDouble(),
            hintValue: _bottomTime.toDouble(),
            suffixText: l10n.divePlanner_label_minutesUnit,
            isInteger: true,
            allowEmpty: false,
            min: _minBottomTime,
            max: _maxBottomTime,
            semanticsLabel: l10n.divePlanner_quickPlan_bottomTimeSemantics(
              _bottomTime,
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _bottomTime = v.round());
            },
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
          onPressed: _create,
          child: Text(l10n.divePlanner_quickPlan_create),
        ),
      ],
    );
  }
}
