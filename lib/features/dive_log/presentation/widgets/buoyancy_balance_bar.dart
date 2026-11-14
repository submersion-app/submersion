import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/theme/foreground_on.dart';
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
  // Small enough that a typical cylinder segment on a phone (about 20 px:
  // an aluminium 80 swings only a couple of kilos either side of neutral)
  // still has room for its icon.
  static const double _iconSize = 14;
  static const double _iconPadding = 2;

  /// How far each part's fill moves from its side's container colour toward
  /// that side's strong colour. Parts that share a side differ, so a legend
  /// swatch can be matched to its segment by shade as well as by icon.
  static const Map<TwinBalancePartKind, double> _tone = {
    TwinBalancePartKind.lead: 0.0,
    TwinBalancePartKind.body: 0.0,
    TwinBalancePartKind.gear: 0.35,
    TwinBalancePartKind.suit: 0.35,
    TwinBalancePartKind.tanks: 0.7,
  };

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
    // Narrower than one segment's minimum, there is nothing sensible to draw
    // (and clamping to a minimum above the maximum would throw).
    if (available < _minSegmentWidth) return const [];
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

          // The whole label when there is room, else the name alone, else
          // the part's icon, else nothing: a sliver is named by the legend.
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
            showsIcon:
                inBar == null && widths[i] >= _iconSize + _iconPadding * 2,
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
    final (fill, ink) = _colors(
      Theme.of(context).colorScheme,
      segment.part.kind,
      isDown,
    );
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
          alignment: segment.showsIcon
              ? Alignment.center
              : AlignmentDirectional.centerStart,
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
              : segment.showsIcon
              ? Icon(_icon(segment.part.kind), size: _iconSize, color: ink)
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
    final kind = segment.part.kind;
    final (fill, ink) = _colors(theme.colorScheme, kind, isDown);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The segment in miniature: its shade and its icon.
        Container(
          key: ValueKey('balance-legend-${kind.name}'),
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(_icon(kind), size: 12, color: ink),
        ),
        const SizedBox(width: 5),
        Text(segment.label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// Fill and foreground for one part. The side sets the hue (tertiary pulls
  /// down, primary holds up; neither is an error) and the part sets the tone
  /// within it.
  (Color, Color) _colors(
    ColorScheme scheme,
    TwinBalancePartKind kind,
    bool isDown,
  ) {
    final container = isDown
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final onContainer = isDown
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    final tone = _tone[kind]!;
    if (tone == 0) return (container, onContainer);
    final strong = isDown ? scheme.tertiary : scheme.primary;
    final fill = Color.lerp(container, strong, tone)!;
    // The container's own foreground stops being readable as the fill moves
    // toward the strong colour, so fall back to black or white when it does.
    final ink = contrastRatio(onContainer, fill) >= 4.5
        ? onContainer
        : blackOrWhiteOn(fill);
    return (fill, ink);
  }

  IconData _icon(TwinBalancePartKind kind) => switch (kind) {
    TwinBalancePartKind.lead => SubmersionIcons.weightPocket,
    TwinBalancePartKind.tanks => SubmersionIcons.tankBackGas,
    TwinBalancePartKind.gear => SubmersionIcons.bcd,
    TwinBalancePartKind.suit => SubmersionIcons.wetsuit,
    TwinBalancePartKind.body => Icons.accessibility_new,
  };

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

  /// Whether the segment, with no room for text, still has room for its icon.
  final bool showsIcon;

  const _Segment({
    required this.part,
    required this.width,
    required this.label,
    required this.inBar,
    required this.showsIcon,
  });
}
