import 'package:flutter/material.dart';

import '../../../../core/providers/provider.dart';
import '../providers/dive_planner_providers.dart';

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

    return AlertDialog(
      title: const Text('Quick Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create a simple rectangular dive profile',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Depth slider
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('Depth:', style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Slider(
                  value: _depth,
                  min: 5,
                  max: 40,
                  divisions: 35,
                  label: '${_depth.toStringAsFixed(0)}m',
                  onChanged: (v) => setState(() => _depth = v),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${_depth.toStringAsFixed(0)}m',
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
                child: Text('Time:', style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Slider(
                  value: _bottomTime.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$_bottomTime min',
                  onChanged: (v) => setState(() => _bottomTime = v.round()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_bottomTime min',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Preview info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Preview:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '↓ Descent to ${_depth.toStringAsFixed(0)}m',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '● Bottom time: $_bottomTime min',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '↑ Ascent with safety stop',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
          child: const Text('Create'),
        ),
      ],
    );
  }
}
