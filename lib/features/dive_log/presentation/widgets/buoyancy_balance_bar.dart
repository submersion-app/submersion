import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/theme/foreground_on.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/text_measure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_callouts.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_ruler.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A tug-of-war bar: the parts pulling the diver down grow from the centre
/// toward the start edge, the parts holding them up toward the end edge.
///
/// Each side is headed by an arrow, its name and its total. A part too narrow
/// to carry its own figure gets a callout above the bar pointing down at it,
/// and a ruler under the bar gives the scale in the diver's own unit.
///
/// [scaleKg] is the weight one half of the bar stands for. Keeping it fixed
/// across a dive holds the constant parts and the ruler still, so only what
/// really changed moves as the dive is scrubbed.
class BuoyancyBalanceBar extends StatelessWidget {
  final TwinBalance balance;
  final double scaleKg;
  final UnitFormatter units;

  /// Each part's smallest and largest size over the whole dive
  /// ([TwinBalance.partRangesKg]). With it the callout lane keeps room for
  /// every callout the dive will ever need, so the bar and the chart under it
  /// never move while the dive is scrubbed. Pass the same map for the whole
  /// dive: the reserve is worked out once per map.
  final Map<TwinBalancePartKind, (double, double)>? partRangesKg;

  const BuoyancyBalanceBar({
    super.key,
    required this.balance,
    required this.scaleKg,
    required this.units,
    this.partRangesKg,
  });

  /// The reserved rows, kept beside the dive's ranges map so scrubbing reuses
  /// them instead of measuring the same labels on every frame.
  static final Expando<(Object, int)> _reserveCache = Expando();

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

  /// How far a segment's fill moves from its side's container colour toward
  /// that side's strong colour, by its place counting out from the centre.
  /// Going by place, not by part, means no two segments on a side can share a
  /// shade, whichever parts end up there.
  static const List<double> _tones = [0.0, 0.35, 0.7, 0.85, 1.0];

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
    final labelStyle = theme.textTheme.labelMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final halfWidth = (width - _ruleWidth) / 2;
        // Reserve room for the most gaps a side can have, whatever it holds
        // now, so a part appearing or vanishing does not rescale its
        // neighbours (or move the ruler's marks off them).
        final usable =
            halfWidth - _gap * (TwinBalancePartKind.values.length - 1);
        final down = _layout(context, balance.down, usable, labelStyle);
        final up = _layout(context, balance.up, usable, labelStyle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _heading(context, isDown: true)),
                const SizedBox(width: 8),
                Expanded(child: _heading(context, isDown: false)),
              ],
            ),
            const SizedBox(height: 4),
            // Each segment already tells a screen reader its side and figure.
            ExcludeSemantics(
              child: BalanceCalloutLane(
                width: width,
                minRows: _reservedRows(context, usable, width, labelStyle),
                callouts: [
                  ..._callouts(context, down, halfWidth, isDown: true),
                  ..._callouts(context, up, halfWidth, isDown: false),
                ],
              ),
            ),
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
            if (usable >= _minSegmentWidth) ...[
              const SizedBox(height: 2),
              ExcludeSemantics(
                child: BalanceRuler(
                  scaleKg: scaleKg > 0 ? scaleKg : 1.0,
                  halfWidth: halfWidth,
                  usable: usable,
                  ruleWidth: _ruleWidth,
                  units: units,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// One side's heading: its arrow, its name and its total, mirrored on the
  /// holding-up side so each arrow sits at the outer edge of its half.
  Widget _heading(BuildContext context, {required bool isDown}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final arrow = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(
        isDown ? Icons.arrow_downward : Icons.arrow_upward,
        size: 16,
        color: isDown ? scheme.tertiary : scheme.primary,
      ),
    );
    final name = TextSpan(
      text: isDown ? l10n.buoyancy_pullingDown : l10n.buoyancy_holdingUp,
    );
    final total = TextSpan(
      text: units.formatWeight(
        isDown ? balance.downTotalKg : balance.upTotalKg,
      ),
      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
    );
    const space = TextSpan(text: ' ');
    return Text.rich(
      key: ValueKey('balance-heading-${isDown ? 'down' : 'up'}'),
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        children: isDown
            ? [arrow, space, name, space, total]
            : [total, space, name, space, arrow],
      ),
      textAlign: isDown ? TextAlign.start : TextAlign.end,
    );
  }

  /// The callout rows the whole dive will need at this width: a row for every
  /// part that, at its smallest, is too narrow for its label, sized for its
  /// widest label. Parts are assumed never to need more than their own
  /// segment, which holds unless a crowded side has to shrink to fit.
  int _reservedRows(
    BuildContext context,
    double usable,
    double width,
    TextStyle? labelStyle,
  ) {
    final ranges = partRangesKg;
    if (ranges == null || usable < _minSegmentWidth) return 1;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final key = (
      width,
      scaleKg,
      units.settings.weightUnit,
      labelStyle,
      BalanceCalloutLane.styleOf(context),
      direction,
      scaler,
      Localizations.localeOf(context),
    );
    final cached = _reserveCache[ranges];
    if (cached != null && cached.$1 == key) return cached.$2;

    final l10n = context.l10n;
    final scale = scaleKg > 0 ? scaleKg : 1.0;
    final widths = <double>[];
    for (final MapEntry(key: kind, value: (smallest, largest))
        in ranges.entries) {
      final narrowest = (smallest / scale * usable).clamp(
        _minSegmentWidth,
        usable,
      );
      final label = _partLabel(l10n, kind, smallest);
      if (_fitsInBar(label, narrowest, labelStyle, direction, scaler)) continue;
      widths.add(
        math.max(
          BalanceCalloutLane.pillWidth(context, label),
          BalanceCalloutLane.pillWidth(
            context,
            _partLabel(l10n, kind, largest),
          ),
        ),
      );
    }
    final rows = balanceCalloutRowsToHold(widths, laneWidth: width);
    _reserveCache[ranges] = (key, rows);
    return rows;
  }

  String _partLabel(
    AppLocalizations l10n,
    TwinBalancePartKind kind,
    double kg,
  ) => l10n.buoyancy_partLabel(_name(l10n, kind), units.formatWeight(kg.abs()));

  static bool _fitsInBar(
    String text,
    double width,
    TextStyle? style,
    TextDirection direction,
    TextScaler scaler,
  ) =>
      measureSingleLine(
            text,
            style,
            direction: direction,
            scaler: scaler,
          ).width +
          _labelPadding * 2 <=
      width;

  /// Callouts for the side's segments that have no room for their figure,
  /// each anchored at its segment's centre, measured from the bar's start
  /// edge.
  List<BalanceCallout> _callouts(
    BuildContext context,
    List<_Segment> side,
    double halfWidth, {
    required bool isDown,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = isDown ? scheme.tertiary : scheme.primary;
    final callouts = <BalanceCallout>[];
    // Distance from the rule to the segment's inner edge.
    var fromRule = 0.0;
    for (final s in side) {
      final centre = isDown
          ? halfWidth - fromRule - s.width / 2
          : halfWidth + _ruleWidth + fromRule + s.width / 2;
      if (s.inBar == null) {
        callouts.add(
          BalanceCallout(
            id: s.part.kind.name,
            label: s.label,
            anchor: centre,
            color: color,
          ),
        );
      }
      fromRule += s.width + _gap;
    }
    return callouts;
  }

  /// Sizes one side's segments, ordered from the centre outward.
  List<_Segment> _layout(
    BuildContext context,
    List<TwinBalancePart> parts,
    double available,
    TextStyle? labelStyle,
  ) {
    if (parts.isEmpty) return const [];
    final ordered = [
      for (final kind in _fromCentre)
        for (final p in parts)
          if (p.kind == kind) p,
    ];
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
          final label = _partLabel(l10n, ordered[i].kind, ordered[i].kg);
          // The whole label when there is room; otherwise the part's icon
          // when there is room for that, and a callout above the bar names it.
          final inBar =
              _fitsInBar(label, widths[i], labelStyle, direction, scaler)
              ? label
              : null;
          return _Segment(
            part: ordered[i],
            width: widths[i],
            label: label,
            inBar: inBar,
            tone: _tones[i],
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
      segment.tone,
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

  /// Fill and foreground for one segment. The side sets the hue (tertiary
  /// pulls down, primary holds up; neither is an error) and [tone] sets the
  /// shade within it.
  (Color, Color) _colors(ColorScheme scheme, double tone, bool isDown) {
    final container = isDown
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final onContainer = isDown
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
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

  /// [label] when the segment has room for it. Without it, the part gets a
  /// callout above the bar.
  final String? inBar;

  /// Whether the segment, with no room for text, still has room for its icon.
  final bool showsIcon;

  /// The shade for this segment's place on its side (see `_tones`).
  final double tone;

  const _Segment({
    required this.part,
    required this.width,
    required this.label,
    required this.inBar,
    required this.showsIcon,
    required this.tone,
  });
}
