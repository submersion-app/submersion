import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/text_measure.dart';
import 'package:submersion/features/dive_log/presentation/utils/weight_axis.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// This dive's own lead figures, shown after the past dives so it can be read
/// against them.
class BuoyancyHistoryCurrent {
  final double carriedKg;
  final double idealKg;

  const BuoyancyHistoryCurrent({
    required this.carriedKg,
    required this.idealKg,
  });
}

/// Lead carried against the lead the model suggests, dive by dive, across
/// recent dives in the same suit and this one.
///
/// A labelled chart: a caption saying what is compared, a weight axis in the
/// diver's unit, a date under each pair and a readout of the pair picked
/// (this dive, until another is tapped). Renders nothing until at least one
/// past dive in the suit exists. It carries no title of its own: it sits under
/// the Buoyancy card's lead heading.
class BuoyancyHistoryStrip extends ConsumerStatefulWidget {
  final String diveId;
  final UnitFormatter units;

  /// This dive's figures, or null when its lead was not recorded.
  final BuoyancyHistoryCurrent? current;

  const BuoyancyHistoryStrip({
    super.key,
    required this.diveId,
    required this.units,
    this.current,
  });

  @override
  ConsumerState<BuoyancyHistoryStrip> createState() =>
      _BuoyancyHistoryStripState();
}

class _Point {
  /// The dive this pair stands for.
  final String diveId;
  final String label;
  final double carriedKg;
  final double idealKg;
  final bool isCurrent;

  const _Point({
    required this.diveId,
    required this.label,
    required this.carriedKg,
    required this.idealKg,
    required this.isCurrent,
  });
}

class _BuoyancyHistoryStripState extends ConsumerState<BuoyancyHistoryStrip> {
  static const double _plotHeight = 72;
  static const double _axisGap = 6;
  static const double _dateGap = 6;

  /// The dive whose pair was picked by a tap; null follows the last pair.
  /// Held by dive rather than by place, so a history refresh that adds or
  /// drops a dive keeps the readout on the dive that was tapped.
  String? _selectedDiveId;

  @override
  void didUpdateWidget(BuoyancyHistoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pick belongs to the dive page it was made on.
    if (oldWidget.diveId != widget.diveId) _selectedDiveId = null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref
        .watch(buoyancyHistoryProvider(widget.diveId))
        .maybeWhen(
          data: (e) => e,
          orElse: () => const <BuoyancyHistoryEntry>[],
        );
    if (entries.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final units = widget.units;
    final current = widget.current;
    final points = [
      for (final e in entries)
        _Point(
          diveId: e.diveId,
          label: units.formatMonthDay(e.diveDateTime),
          carriedKg: e.carriedKg,
          idealKg: e.idealKg,
          isCurrent: false,
        ),
      if (current != null)
        _Point(
          diveId: widget.diveId,
          label: l10n.buoyancy_historyThisDive,
          carriedKg: current.carriedKg,
          idealKg: current.idealKg,
          isCurrent: true,
        ),
    ];
    // A picked dive that has left the list hands back to the last pair.
    final picked = points.indexWhere((p) => p.diveId == _selectedDiveId);
    final selected = picked >= 0 ? picked : points.length - 1;
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.buoyancy_historyCaption(points.length), style: caption),
        const SizedBox(height: 2),
        Text(
          _readout(points[selected]),
          key: const ValueKey('history-readout'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _chart(context, points, selected),
        const SizedBox(height: 8),
        _legend(context),
        ..._deltaCaption(context, entries),
      ],
    );
  }

  String _readout(_Point p) {
    final l10n = context.l10n;
    final units = widget.units;
    return l10n.buoyancy_historyPoint(
      p.label,
      l10n.buoyancy_partLabel(
        l10n.buoyancy_historyCarried,
        units.formatWeight(p.carriedKg),
      ),
      l10n.buoyancy_partLabel(
        l10n.buoyancy_leadSuggested,
        units.formatWeight(p.idealKg),
      ),
    );
  }

  Widget _chart(BuildContext context, List<_Point> points, int selected) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = widget.units;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Size measure(String text, TextStyle? style) =>
        measureSingleLine(text, style, direction: direction, scaler: scaler);

    final peak = points.fold(
      0.0,
      (m, p) => math.max(
        m,
        math.max(
          units.convertWeight(p.carriedKg),
          units.convertWeight(p.idealKg),
        ),
      ),
    );
    final axis = WeightAxis.covering(peak > 0 ? peak : 1);
    final tickLabels = [
      for (final t in axis.ticks)
        t == 0
            ? formatFixedForDisplay(0, 0)
            : units.formatWeight(units.weightToKg(t), decimals: axis.decimals),
    ];
    final tickSizes = [for (final t in tickLabels) measure(t, labelStyle)];
    final axisWidth =
        tickSizes.fold(0.0, (m, s) => math.max(m, s.width)) + _axisGap;
    final top = axis.top;
    double heightOf(double kg) {
      final v = units.convertWeight(kg);
      if (v <= 0) return 0;
      return math.max(1, v / top * _plotHeight);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = math.max(0.0, constraints.maxWidth - axisWidth);
        final slot = plotWidth / points.length;
        // Two bars and the gap between them always fit their slot, however
        // many dives share a narrow card.
        final barWidth = math.min(
          (slot / 3).clamp(3.0, 10.0).toDouble(),
          math.max(1.0, (slot - 2) / 2),
        );
        final highlight = scheme.surfaceContainerHighest;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _plotHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Each pair below reads its own values to a screen reader, so
                  // the axis and the dates would only repeat them.
                  SizedBox(
                    width: axisWidth,
                    child: ExcludeSemantics(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < axis.ticks.length; i++)
                            PositionedDirectional(
                              end: _axisGap,
                              top:
                                  _plotHeight -
                                  axis.ticks[i] / top * _plotHeight -
                                  tickSizes[i].height / 2,
                              child: Text(
                                tickLabels[i],
                                maxLines: 1,
                                softWrap: false,
                                style: labelStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        for (final t in axis.ticks)
                          PositionedDirectional(
                            start: 0,
                            end: 0,
                            top: math.min(
                              _plotHeight - 1,
                              _plotHeight - t / top * _plotHeight,
                            ),
                            height: 1,
                            child: ColoredBox(color: scheme.outlineVariant),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < points.length; i++)
                              Expanded(
                                child: _pair(
                                  context,
                                  points[i],
                                  index: i,
                                  selected: i == selected,
                                  barWidth: barWidth,
                                  carriedHeight: heightOf(points[i].carriedKg),
                                  idealHeight: heightOf(points[i].idealKg),
                                  highlight: highlight,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: _dates(
                context,
                points,
                axisWidth: axisWidth,
                slot: slot,
                width: constraints.maxWidth,
                style: labelStyle,
                measure: measure,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pair(
    BuildContext context,
    _Point p, {
    required int index,
    required bool selected,
    required double barWidth,
    required double carriedHeight,
    required double idealHeight,
    required Color highlight,
  }) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(String series, double height, Color color) => Container(
      key: ValueKey('history-$series-$index'),
      width: barWidth,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
    );
    void pick() => setState(() => _selectedDiveId = p.diveId);
    // One node per pair, read as its values, rather than two bare bars.
    return Semantics(
      button: true,
      selected: selected,
      label: _readout(p),
      onTap: pick,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('history-dive-$index'),
        excludeFromSemantics: true,
        onTap: pick,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? highlight : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bar('carried', carriedHeight, scheme.primary),
              const SizedBox(width: 2),
              bar('suggested', idealHeight, scheme.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// A date under each pair, thinned from the newest back so neighbours never
  /// overlap on a narrow card; this dive's label always shows.
  Widget _dates(
    BuildContext context,
    List<_Point> points, {
    required double axisWidth,
    required double slot,
    required double width,
    required TextStyle? style,
    required Size Function(String, TextStyle?) measure,
  }) {
    final shown = <(double, _Point, TextStyle?)>[];
    var lineHeight = 0.0;
    double? leftmost;
    for (var i = points.length - 1; i >= 0; i--) {
      final p = points[i];
      final s = p.isCurrent
          ? style?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            )
          : style;
      final size = measure(p.label, s);
      lineHeight = math.max(lineHeight, size.height);
      final centre = axisWidth + slot * (i + 0.5);
      final start = (centre - size.width / 2)
          .clamp(0.0, math.max(0.0, width - size.width))
          .toDouble();
      if (leftmost != null && start + size.width + _dateGap > leftmost) {
        continue;
      }
      shown.add((start, p, s));
      leftmost = start;
    }
    return SizedBox(
      key: const ValueKey('history-dates'),
      height: lineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (start, p, s) in shown)
            PositionedDirectional(
              start: start,
              top: 0,
              child: Text(p.label, maxLines: 1, softWrap: false, style: s),
            ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    Widget swatch(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: c),
        const SizedBox(width: 4),
        // Wraps rather than overflowing a very narrow card.
        Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        swatch(theme.colorScheme.primary, l10n.buoyancy_historyCarried),
        swatch(theme.colorScheme.tertiary, l10n.buoyancy_leadSuggested),
      ],
    );
  }

  /// How the past dives compare, typically: the median gap between what was
  /// carried and what the model suggested.
  List<Widget> _deltaCaption(
    BuildContext context,
    List<BuoyancyHistoryEntry> entries,
  ) {
    final units = widget.units;
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}
