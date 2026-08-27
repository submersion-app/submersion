import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The classic slate range grid: depth variants (rows) x time variants
/// (columns), each cell the variant's TTS in minutes. Renders nothing when
/// the plan has nothing to vary.
class RangeTableSection extends ConsumerWidget {
  const RangeTableSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(planRangeTableProvider);
    if (table == null) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);

    String depthLabel(double delta) {
      if (delta == 0) return context.l10n.plannerCanvas_range_base;
      final sign = delta > 0 ? '+' : '−';
      return '$sign${units.formatDepth(delta.abs(), decimals: 0)}';
    }

    String timeLabel(int delta) {
      if (delta == 0) return context.l10n.plannerCanvas_range_base;
      final sign = delta > 0 ? '+' : '−';
      return '$sign${delta.abs()}′';
    }

    Widget cell(
      String text, {
      bool header = false,
      bool emphasized = false,
      Color? tint,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style:
                (header
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color:
                          tint ?? (header ? theme.colorScheme.outline : null),
                      fontWeight: emphasized || header ? FontWeight.w600 : null,
                    ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            cell('', header: true),
            for (final timeDelta in table.timeDeltas)
              cell(timeLabel(timeDelta), header: true),
          ],
        ),
        for (var d = 0; d < table.depthDeltas.length; d++)
          Row(
            children: [
              cell(depthLabel(table.depthDeltas[d]), header: true),
              for (final rangeCell in table.cells[d])
                if (rangeCell == null)
                  cell('--')
                else
                  cell(
                    '${(rangeCell.outcome.ttsAtBottom / 60).ceil()}′',
                    emphasized: rangeCell.isBase,
                    tint: rangeCell.outcome.isDiveable
                        ? null
                        : theme.colorScheme.error,
                  ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            context.l10n.plannerCanvas_range_legend,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
