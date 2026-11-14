import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A tug-of-war bar: the parts pulling the diver down grow from the centre
/// toward the start edge, the parts holding them up toward the end edge.
///
/// [scaleKg] is the weight one half of the bar stands for. Keeping it fixed
/// across a dive holds the constant parts still, so only what really changed
/// moves as the dive is scrubbed.
class BuoyancyBalanceBar extends StatelessWidget {
  final TwinBalance balance;
  final double scaleKg;
  final UnitFormatter units;

  const BuoyancyBalanceBar({
    super.key,
    required this.balance,
    required this.scaleKg,
    required this.units,
  });

  static const double _segmentHeight = 34;
  static const double _gap = 2;
  static const double _ruleWidth = 2;
  static const double _labelPadding = 8;
  static const double _minSegmentWidth = 2;

  /// Order from the centre outward: constant parts first, so the parts that
  /// change through a dive (suit, tanks) never push a constant one sideways.
  static const List<TwinBalancePartKind> _fromCentre = [
    TwinBalancePartKind.lead,
    TwinBalancePartKind.body,
    TwinBalancePartKind.gear,
    TwinBalancePartKind.suit,
    TwinBalancePartKind.tanks,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labelStyle = theme.textTheme.labelMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - _ruleWidth) / 2;
        final down = _layout(context, balance.down, halfWidth, labelStyle);
        final up = _layout(context, balance.up, halfWidth, labelStyle);
        // In the bar's own reading order, so an entry can be matched to its
        // segment by position: down side from the outer edge in, then up side
        // from the centre out.
        final legend = [
          for (final s in [...down.reversed, ...up])
            if (s.inBar != s.label) s,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.buoyancy_pullingDown, style: captionStyle),
                ),
                Expanded(
                  child: Text(
                    l10n.buoyancy_holdingUp,
                    style: captionStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: halfWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    // Listed outermost first, so the last one meets the rule.
                    children: _spaced([
                      for (final s in down.reversed)
                        _segment(context, s, isDown: true, style: labelStyle),
                    ]),
                  ),
                ),
                Container(
                  width: _ruleWidth,
                  height: _segmentHeight + 8,
                  color: theme.colorScheme.outline,
                ),
                SizedBox(
                  width: halfWidth,
                  child: Row(
                    children: _spaced([
                      for (final s in up)
                        _segment(context, s, isDown: false, style: labelStyle),
                    ]),
                  ),
                ),
              ],
            ),
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                key: const ValueKey('balance-legend'),
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final s in legend)
                    _legendEntry(context, s, isDown: s.part.kg < 0),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// Sizes one side's segments, ordered from the centre outward.
  List<_Segment> _layout(
    BuildContext context,
    List<TwinBalancePart> parts,
    double halfWidth,
    TextStyle? labelStyle,
  ) {
    if (parts.isEmpty || halfWidth <= 0) return const [];
    final ordered = [
      for (final kind in _fromCentre)
        for (final p in parts)
          if (p.kind == kind) p,
    ];
    // Reserve room for the most gaps a side can have, whatever it holds now,
    // so a part appearing or vanishing does not rescale its neighbours.
    final available =
        halfWidth - _gap * (TwinBalancePartKind.values.length - 1);
    if (available <= 0) return const [];
    final scale = scaleKg > 0 ? scaleKg : 1.0;
    var widths = [
      for (final p in ordered)
        (p.kg.abs() / scale * available).clamp(_minSegmentWidth, available),
    ];
    // The minimum width can tip a full side over its half; shrink to fit.
    final total = widths.fold(0.0, (s, w) => s + w);
    if (total > available && total > 0) {
      widths = [for (final w in widths) w * available / total];
    }

    final l10n = context.l10n;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return [
      for (var i = 0; i < ordered.length; i++)
        () {
          final name = _name(l10n, ordered[i].kind);
          final label = l10n.buoyancy_partLabel(
            name,
            units.formatWeight(ordered[i].kg.abs()),
          );
          bool fits(String text) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: labelStyle),
              textDirection: direction,
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width + _labelPadding * 2 <= widths[i];
          }

          // The whole label when there is room, else the name alone so the
          // segment can still be told apart, else nothing.
          final String? inBar;
          if (fits(label)) {
            inBar = label;
          } else if (fits(name)) {
            inBar = name;
          } else {
            inBar = null;
          }
          return _Segment(
            part: ordered[i],
            width: widths[i],
            label: label,
            inBar: inBar,
          );
        }(),
    ];
  }

  List<Widget> _spaced(List<Widget> segments) => [
    for (var i = 0; i < segments.length; i++) ...[
      if (i > 0) const SizedBox(width: _gap),
      segments[i],
    ],
  ];

  Widget _segment(
    BuildContext context,
    _Segment segment, {
    required bool isDown,
    required TextStyle? style,
  }) {
    final (fill, ink) = _colors(Theme.of(context).colorScheme, isDown);
    final l10n = context.l10n;
    // The side is the point of the bar, so a screen reader hears it too.
    final side = isDown ? l10n.buoyancy_pullingDown : l10n.buoyancy_holdingUp;
    return Tooltip(
      message: segment.label,
      child: Semantics(
        label: '$side: ${segment.label}',
        excludeSemantics: true,
        child: Container(
          key: ValueKey('balance-${segment.part.kind.name}'),
          width: segment.width,
          height: _segmentHeight,
          alignment: AlignmentDirectional.centerStart,
          padding: segment.inBar != null
              ? const EdgeInsets.symmetric(horizontal: _labelPadding)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
          child: segment.inBar != null
              ? Text(
                  segment.inBar!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: style?.copyWith(color: ink),
                )
              : null,
        ),
      ),
    );
  }

  Widget _legendEntry(
    BuildContext context,
    _Segment segment, {
    required bool isDown,
  }) {
    final theme = Theme.of(context);
    final (fill, _) = _colors(theme.colorScheme, isDown);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(segment.label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// Fill and text colour for one side. Neither side is an error, so both use
  /// container pairs, which every theme preset keeps readable.
  (Color, Color) _colors(ColorScheme scheme, bool isDown) => isDown
      ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
      : (scheme.primaryContainer, scheme.onPrimaryContainer);

  String _name(AppLocalizations l10n, TwinBalancePartKind kind) =>
      switch (kind) {
        TwinBalancePartKind.lead => l10n.buoyancy_leadTerm,
        TwinBalancePartKind.tanks => l10n.diveDetailSection_tanks_name,
        TwinBalancePartKind.gear => l10n.buoyancy_partGear,
        TwinBalancePartKind.suit => l10n.buoyancy_suitTerm,
        TwinBalancePartKind.body => l10n.buoyancy_partBody,
      };
}

class _Segment {
  final TwinBalancePart part;
  final double width;

  /// The part's name and figure.
  final String label;

  /// What the segment has room to show: [label], the name alone, or nothing.
  /// Anything short of [label] sends the part to the legend.
  final String? inBar;

  const _Segment({
    required this.part,
    required this.width,
    required this.label,
    required this.inBar,
  });
}
