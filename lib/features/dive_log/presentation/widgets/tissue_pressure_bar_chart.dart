import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/highlight_outline.dart';
import 'package:submersion/features/dive_log/presentation/widgets/loading_severity_color.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_tooltip_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Subsurface-style bar chart of the 16 compartments' loading, fast to slow.
///
/// Each bar carries a marker at the loading that compartment settles at when
/// fully equilibrated with air at the surface (issue #4228): a desaturated
/// compartment stands at its marker, never at 0%, so the marker is what shows
/// whether a bar still holds load left over from diving. The red line is the
/// surface M-value (100%).
///
/// Used by the tissue loading card and the deco calculator's panel, so both
/// draw, label and explain the same chart.
class TissuePressureBarChart extends StatefulWidget {
  final DecoStatus status;

  /// Compartment (0-based) drawn with an outline, or null for none.
  final int? highlightedIndex;

  /// Compartment (0-based) the screen reader names as leading. The host
  /// passes the one its visible "Leading" text shows, so both name the same
  /// compartment; null falls back to [DecoStatus.leadingCompartment].
  final int? leadingIndex;

  /// Called with a compartment's index when it is hovered or tapped; null
  /// when the host has nothing to follow the hover (deco calculator).
  final ValueChanged<int>? onCompartmentHover;

  /// Called when the pointer leaves the chart.
  final VoidCallback? onHoverExit;

  /// Height of the bars' area.
  final double chartHeight;

  const TissuePressureBarChart({
    super.key,
    required this.status,
    this.highlightedIndex,
    this.leadingIndex,
    this.onCompartmentHover,
    this.onHoverExit,
    this.chartHeight = 50.0,
  });

  static const double maxLoadingPercent = 120.0;

  /// Height of the surface level marker drawn across each bar.
  static const double markerHeight = 2.0;

  /// Thickness of the M-value line at 100%: whole pixels, since a
  /// fractional height antialiases into a fainter smear at 1.0 DPR.
  static const double mValueLineHeight = 2.0;

  /// Bottom offset of a band [height] high centered on [percent] of a chart
  /// [chartHeight] high, rounded to whole pixels so the band covers full
  /// pixel rows instead of antialiasing across three.
  ///
  /// Rounded on the device pixel grid ([devicePixelRatio]), not to whole
  /// logical pixels, which at a fractional ratio still straddle device rows.
  /// Kept inside the chart, and at 0 when the chart is shorter than the band.
  static double bandBottom({
    required double chartHeight,
    required double percent,
    required double height,
    double devicePixelRatio = 1.0,
  }) {
    final center =
        chartHeight *
        (percent.clamp(0.0, maxLoadingPercent) / maxLoadingPercent);
    final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final snapped = ((center - height / 2) * dpr).roundToDouble() / dpr;
    final top = chartHeight - height;
    if (top <= 0) return 0.0;
    return snapped.clamp(0.0, top);
  }

  /// Color of the surface level marker: high contrast against both the
  /// green-to-red bars and the card, in light and dark mode.
  static Color surfaceLevelMarkerColor(ColorScheme colorScheme) =>
      colorScheme.onSurface.withValues(alpha: 0.85);

  /// Color of the M-value line: the theme's full error color. At half
  /// opacity it all but vanished against the dark card (issue #4228).
  static Color mValueLineColor(ColorScheme colorScheme) => colorScheme.error;

  @override
  State<TissuePressureBarChart> createState() => _TissuePressureBarChartState();
}

class _TissuePressureBarChartState extends State<TissuePressureBarChart> {
  /// Every bar's tooltip, built once for the status on screen: the chart
  /// rebuilds on each hover with the same status, while a new status (a
  /// profile scrub) replaces them. Only the current status is kept, so
  /// scrubbing a long dive does not retain the text of every sample passed.
  DecoStatus? _tooltipStatus;
  AppLocalizations? _tooltipL10n;
  String? _tooltipLocale;
  List<String> _tooltips = const [];

  List<String> _tooltipsFor(DecoStatus status, AppLocalizations l10n) {
    // The decimals follow Intl's locale, the words follow l10n.
    final locale = Intl.getCurrentLocale();
    if (!identical(status, _tooltipStatus) ||
        !identical(l10n, _tooltipL10n) ||
        locale != _tooltipLocale) {
      _tooltipStatus = status;
      _tooltipL10n = l10n;
      _tooltipLocale = locale;
      _tooltips = List.unmodifiable([
        for (final comp in status.compartments)
          tissueCompartmentTooltip(l10n, status, comp),
      ]);
    }
    return _tooltips;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final chartHeight = widget.chartHeight;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final comps = status.compartments;
    final tooltips = _tooltipsFor(status, l10n);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final outlineColor = HighlightOutline.colorOf(colorScheme);
    final markerColor = TissuePressureBarChart.surfaceLevelMarkerColor(
      colorScheme,
    );
    final mValueColor = TissuePressureBarChart.mValueLineColor(colorScheme);
    const markerHeight = TissuePressureBarChart.markerHeight;
    const mValueLineHeight = TissuePressureBarChart.mValueLineHeight;
    final equilibriumN2 = status.surfaceEquilibriumN2Bar;

    final leadingIdx = widget.leadingIndex;
    final leading = comps.isEmpty
        ? null
        : (leadingIdx != null && leadingIdx >= 0 && leadingIdx < comps.length)
        ? comps[leadingIdx]
        : status.leadingCompartment;

    final hover = widget.onCompartmentHover;
    final exit = widget.onHoverExit;
    final highlightedIndex = widget.highlightedIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: leading == null
              ? null
              : l10n.diveLog_deco_barChartSemantics(
                  comps.length,
                  leading.compartmentNumber,
                  leading.percentLoading.toStringAsFixed(0),
                ),
          child: SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                MouseRegion(
                  onExit: exit == null ? null : (_) => exit(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in comps.asMap().entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.5,
                            ),
                            child: MouseRegion(
                              onEnter: hover == null
                                  ? null
                                  : (_) => hover(entry.key),
                              child: GestureDetector(
                                onTapDown: hover == null
                                    ? null
                                    : (_) => hover(entry.key),
                                child: Tooltip(
                                  message: tooltips[entry.key],
                                  child: _CompartmentBar(
                                    comp: entry.value,
                                    chartHeight: chartHeight,
                                    equilibriumPercent: entry.value
                                        .equilibriumLoadingPercent(
                                          equilibriumN2,
                                        ),
                                    markerColor: markerColor,
                                    outlineColor: entry.key == highlightedIndex
                                        ? outlineColor
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // M-value reference line, centered on 100%. IgnorePointer so
                // hovering a bar at that height still reaches its tooltip.
                Positioned(
                  key: const ValueKey('tissue-m-value-line'),
                  bottom: TissuePressureBarChart.bandBottom(
                    chartHeight: chartHeight,
                    percent: 100,
                    height: mValueLineHeight,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  left: 0,
                  right: 0,
                  height: mValueLineHeight,
                  child: IgnorePointer(child: ColoredBox(color: mValueColor)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.diveLog_deco_tissueFast, style: labelStyle),
            Text(l10n.diveLog_deco_tissueSlow, style: labelStyle),
          ],
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            _LegendItem(
              key: const ValueKey('tissue-legend-surface-level'),
              color: markerColor,
              swatchHeight: markerHeight,
              label: l10n.diveLog_deco_surfaceLevel,
              style: labelStyle,
            ),
            _LegendItem(
              key: const ValueKey('tissue-legend-m-value'),
              color: mValueColor,
              swatchHeight: mValueLineHeight,
              label: l10n.diveLog_deco_mValue,
              style: labelStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompartmentBar extends StatelessWidget {
  final TissueCompartment comp;
  final double chartHeight;
  final double equilibriumPercent;
  final Color markerColor;

  /// Colour of the highlight outline, or null when this bar is not the
  /// highlighted one.
  final Color? outlineColor;

  const _CompartmentBar({
    required this.comp,
    required this.chartHeight,
    required this.equilibriumPercent,
    required this.markerColor,
    required this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    const maxLoading = TissuePressureBarChart.maxLoadingPercent;
    const markerHeight = TissuePressureBarChart.markerHeight;

    final totalLoading = comp.percentLoading.clamp(0.0, maxLoading);
    final barHeight = chartHeight * (totalLoading / maxLoading);

    final totalGas = comp.totalInertGas;
    final heRatio = totalGas > 0 ? comp.currentPHe / totalGas : 0.0;
    final n2Height = barHeight * (1.0 - heRatio);
    final heHeight = barHeight * heRatio;

    final barColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heHeight > 0.5)
          Container(
            height: heHeight,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(1),
              ),
            ),
          ),
        Container(
          height: n2Height.clamp(0.0, barHeight),
          decoration: BoxDecoration(
            color: loadingSeverityColor(totalLoading),
            borderRadius: BorderRadius.vertical(
              top: heHeight > 0.5 ? Radius.zero : const Radius.circular(1),
            ),
          ),
        ),
      ],
    );

    // Highlight with a foreground painter so the outline is painted OVER the
    // bar, inside its box, without enlarging it. A decoration border would
    // inset the child and add its width to the box on every side, making the
    // bar taller than its fixed-height slot (overflowing when the bar is
    // already full height) and wider than its unhighlighted neighbours (hover
    // jitter).
    final outline = outlineColor;
    final bar = outline != null
        ? CustomPaint(
            foregroundPainter: HighlightOutlinePainter(color: outline),
            child: barColumn,
          )
        : barColumn;

    return SizedBox(
      height: chartHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [bar],
            ),
          ),
          Positioned(
            key: ValueKey('tissue-surface-marker-${comp.compartmentNumber}'),
            left: 0,
            right: 0,
            bottom: TissuePressureBarChart.bandBottom(
              chartHeight: chartHeight,
              percent: equilibriumPercent,
              height: markerHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
            height: markerHeight,
            child: IgnorePointer(child: ColoredBox(color: markerColor)),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final double swatchHeight;
  final String label;
  final TextStyle? style;

  const _LegendItem({
    super.key,
    required this.color,
    required this.swatchHeight,
    required this.label,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(width: 12, height: swatchHeight, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}
