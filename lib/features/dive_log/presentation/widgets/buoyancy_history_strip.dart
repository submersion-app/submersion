import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact carried-vs-modeled lead comparison across recent same-suit dives.
/// Renders nothing until at least one comparable dive exists.
class BuoyancyHistoryStrip extends ConsumerWidget {
  final String diveId;
  final UnitFormatter units;

  const BuoyancyHistoryStrip({
    super.key,
    required this.diveId,
    required this.units,
  });

  static const double _barMaxHeight = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref
        .watch(buoyancyHistoryProvider(diveId))
        .maybeWhen(
          data: (e) => e,
          orElse: () => const <BuoyancyHistoryEntry>[],
        );
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final maxVal = entries
        .expand((e) => [e.carriedKg, e.idealKg])
        .fold(1.0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.buoyancy_historyTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _barMaxHeight + 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in entries.reversed)
                  _entryBars(context, entry, maxVal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _legend(context),
        ..._deltaCaption(context, entries),
      ],
    );
  }

  Widget _entryBars(
    BuildContext context,
    BuoyancyHistoryEntry entry,
    double maxVal,
  ) {
    final theme = Theme.of(context);
    double h(double kg) =>
        (kg / maxVal * _barMaxHeight).clamp(2.0, _barMaxHeight);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(h(entry.carriedKg), theme.colorScheme.primary),
              const SizedBox(width: 2),
              _bar(h(entry.idealKg), theme.colorScheme.tertiary),
            ],
          ),
          const SizedBox(height: 2),
          Icon(
            _feedbackIcon(entry.feedback),
            size: 12,
            color: _feedbackColor(theme, entry.feedback),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color) => Container(
    width: 8,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
    ),
  );

  Widget _legend(BuildContext context) {
    final theme = Theme.of(context);
    Widget swatch(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: c),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
    return Row(
      children: [
        swatch(theme.colorScheme.primary, context.l10n.buoyancy_historyCarried),
        const SizedBox(width: 16),
        swatch(
          theme.colorScheme.tertiary,
          context.l10n.buoyancy_historyModeled,
        ),
      ],
    );
  }

  List<Widget> _deltaCaption(
    BuildContext context,
    List<BuoyancyHistoryEntry> entries,
  ) {
    final diffs = entries.map((e) => e.carriedKg - e.idealKg).toList()..sort();
    final median = diffs[diffs.length ~/ 2];
    if (median.abs() < 0.5) return const [];
    final text = median > 0
        ? context.l10n.buoyancy_historyMore(units.formatWeight(median.abs()))
        : context.l10n.buoyancy_historyLess(units.formatWeight(median.abs()));
    return [
      const SizedBox(height: 6),
      Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    ];
  }

  IconData _feedbackIcon(String? feedback) => switch (feedback) {
    'correct' => Icons.check_circle_outline,
    'overweighted' => Icons.arrow_downward,
    'underweighted' => Icons.arrow_upward,
    _ => Icons.remove,
  };

  Color _feedbackColor(ThemeData theme, String? feedback) => switch (feedback) {
    'correct' => theme.colorScheme.primary,
    'overweighted' || 'underweighted' => theme.colorScheme.error,
    _ => theme.colorScheme.outlineVariant,
  };
}
