import 'package:flutter/material.dart';

import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/tide_state_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tide at a dive's entry as three readings: its state, its height and
/// how fast it was changing.
///
/// Side by side when there is room. In a narrow card (the half-width column
/// of a section pair, or a phone) the state takes a row of its own, because
/// "High Tide (Slack)" does not fit a third of that width.
class TideStatTiles extends StatelessWidget {
  const TideStatTiles({super.key, required this.record, required this.units});

  final TideRecord record;
  final UnitFormatter units;

  /// Below this width the state tile moves to its own row.
  static const double narrowWidth = 400;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (stateIcon, stateColor) = _stateMark(record.tideState);

    final state = _Tile(
      label: l10n.diveLog_detail_label_state,
      value: record.tideState.localizedName(l10n),
      icon: stateIcon,
      iconColor: stateColor,
      wraps: true,
    );
    final readings = [
      _Tile(
        label: l10n.diveLog_detail_label_height,
        value: units.formatDepth(record.heightMeters, decimals: 2),
      ),
      if (record.rateOfChange != null)
        _Tile(
          label: l10n.diveLog_detail_label_rateOfChange,
          value: units.formatTideRate(record.rateOfChange),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < narrowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              state,
              const SizedBox(height: _gap),
              _row(readings),
            ],
          );
        }
        return _row([state, ...readings]);
      },
    );
  }

  /// [tiles] at equal widths and equal heights.
  static Widget _row(List<Widget> tiles) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  /// The icon and colour that stand for [state], as elsewhere on the card.
  static (IconData, Color) _stateMark(TideState state) => switch (state) {
    TideState.rising => (Icons.trending_up, Colors.blue),
    TideState.falling => (Icons.trending_down, Colors.orange),
    TideState.slackHigh => (Icons.horizontal_rule, Colors.green),
    TideState.slackLow => (Icons.horizontal_rule, Colors.amber),
  };
}

/// One reading: its value over its name.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.wraps = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  /// A worded value may run to a second line; a number is scaled down to
  /// fit instead, so it is never broken across lines.
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final valueText = Text(
      value,
      maxLines: wraps ? 2 : 1,
      softWrap: wraps,
      overflow: wraps ? TextOverflow.ellipsis : TextOverflow.visible,
      style: valueStyle,
    );

    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: wraps
                        ? valueText
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: valueText,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
