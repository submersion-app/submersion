import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_area_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact card displaying tissue loading visualizations and live data.
///
/// Contains:
/// - Tissue pressure bar chart (Subsurface-style, 16 compartments)
/// - Tissue loading heat map over time
/// - Leading compartment detail panel (updates on hover over either chart)
///
/// This is the "visualization" half of the original CompactDecoPanel,
/// now in its own card that spans the full height of the left column
/// (Deco Status + O2 Toxicity).
class CompactTissueLoadingCard extends ConsumerStatefulWidget {
  /// Current decompression status (for bar chart + detail panel)
  final DecoStatus status;

  /// Full time-series of deco statuses for the heat map
  final List<DecoStatus>? decoStatuses;

  /// Currently selected profile point index (for heat map cursor)
  final int? selectedIndex;

  /// Optional time label (e.g. "at 3:42") shown next to the title on hover
  final String? subtitle;

  /// Called when user hovers over a time index on the heat map.
  final ValueChanged<int?>? onHeatMapHover;

  /// When true, the visualization (heat map / area chart) fills the
  /// remaining vertical space in the card instead of using a fixed height.
  /// Enable this when the card is stretched to match a taller sibling
  /// (e.g. in the wide two-column layout).
  final bool expandVisualization;

  const CompactTissueLoadingCard({
    super.key,
    required this.status,
    this.decoStatuses,
    this.selectedIndex,
    this.subtitle,
    this.onHeatMapHover,
    this.expandVisualization = false,
  });

  @override
  ConsumerState<CompactTissueLoadingCard> createState() =>
      _CompactTissueLoadingCardState();
}

class _CompactTissueLoadingCardState
    extends ConsumerState<CompactTissueLoadingCard> {
  /// Index of the compartment currently hovered on any chart (0-based).
  /// Drives visual emphasis (bar opacity, heat map outline, area chart line).
  int? _hoveredCompartmentIndex;

  /// Whether the current hover originated from the bar chart.
  /// When true, the detail panel shows the hovered compartment.
  /// When false (heat map / area chart), the detail panel shows the leading
  /// compartment instead, since those charts already have their own tooltips
  /// showing per-compartment details.
  bool _hoverFromBarChart = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final vizMode = ref.watch(tissueVizModeProvider);

    final expand = widget.expandVisualization;
    final hasViz =
        widget.decoStatuses != null && widget.decoStatuses!.isNotEmpty;
    final vizWidget = hasViz
        ? switch (vizMode) {
            TissueVizMode.heatMap => _buildHeatMapSection(
              context,
              colorScheme,
              textTheme,
              expandToFill: expand,
            ),
            TissueVizMode.stackedArea => _buildAreaChartSection(
              context,
              colorScheme,
              textTheme,
              expandToFill: expand,
            ),
          }
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.diveLog_deco_sectionTissueLoading,
                  style: textTheme.titleSmall,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '@ ${widget.subtitle!}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                _buildVizModeToggle(colorScheme, vizMode),
                const SizedBox(width: 4),
                _buildColorSchemeSelector(colorScheme),
              ],
            ),
            const SizedBox(height: 14),

            // Compartment detail panel (above charts for proximity to title)
            if (widget.status.compartments.isNotEmpty) ...[
              _buildCompartmentDetail(context, colorScheme, textTheme),
              const SizedBox(height: 6),
            ],

            // Tissue pressure bar chart (with per-bar hover)
            _buildTissuePressureDiagram(context, colorScheme),
            const SizedBox(height: 6),

            // Visualization (expanded to fill remaining space when possible)
            if (vizWidget != null)
              if (expand) Expanded(child: vizWidget) else vizWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildTissuePressureDiagram(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    const chartHeight = 50.0;
    const maxLoadingPercent = 120.0;
    const mValueBottom = chartHeight * (100.0 / maxLoadingPercent);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );

    final highlightedIdx = _barChartDisplayIndex();
    final isDark = colorScheme.brightness == Brightness.dark;
    final outlineColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 1.0 : 0.8,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: chartSummaryLabel(
            chartType: 'Tissue pressure diagram',
            description:
                '${widget.status.compartments.length} compartments showing '
                'nitrogen and helium loading relative to M-value, leading '
                'compartment ${widget.status.leadingCompartmentNumber} at '
                '${widget.status.leadingCompartmentLoading.toStringAsFixed(0)}'
                ' percent',
          ),
          child: SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                MouseRegion(
                  onExit: (_) => _clearHoveredCompartment(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: widget.status.compartments.asMap().entries.map((
                      entry,
                    ) {
                      final idx = entry.key;
                      final comp = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: MouseRegion(
                            onEnter: (_) =>
                                _setHoveredCompartment(idx, fromBarChart: true),
                            child: GestureDetector(
                              onTapDown: (_) => _setHoveredCompartment(
                                idx,
                                fromBarChart: true,
                              ),
                              child: _buildSubsurfaceBar(
                                comp,
                                chartHeight,
                                maxLoadingPercent,
                                outlineColor: idx == highlightedIdx
                                    ? outlineColor
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // M-value reference line
                Positioned(
                  bottom: mValueBottom,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.l10n.diveLog_deco_tissueFast, style: labelStyle),
            Text(context.l10n.diveLog_deco_tissueSlow, style: labelStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildSubsurfaceBar(
    TissueCompartment comp,
    double chartHeight,
    double maxLoading, {
    Color? outlineColor,
  }) {
    final totalLoading = comp.percentLoading.clamp(0.0, maxLoading);
    final barHeight = chartHeight * (totalLoading / maxLoading);

    final totalGas = comp.totalInertGas;
    final heRatio = totalGas > 0 ? comp.currentPHe / totalGas : 0.0;

    final n2Height = barHeight * (1.0 - heRatio);
    final heHeight = barHeight * heRatio;

    final n2Color = _getN2Color(totalLoading);

    final barSegments = <Widget>[
      if (heHeight > 0.5)
        Container(
          height: heHeight,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
          ),
        ),
      Container(
        height: n2Height.clamp(0.0, barHeight),
        decoration: BoxDecoration(
          color: n2Color,
          borderRadius: BorderRadius.vertical(
            top: heHeight > 0.5 ? Radius.zero : const Radius.circular(1),
          ),
        ),
      ),
    ];

    // Wrap bar segments in an outline when highlighted.
    // The outline container is only as tall as the bar itself.
    final bar = outlineColor != null
        ? Container(
            decoration: BoxDecoration(
              border: Border.all(color: outlineColor, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: barSegments,
            ),
          )
        : Column(mainAxisSize: MainAxisSize.min, children: barSegments);

    return Tooltip(
      message:
          'Compartment ${comp.compartmentNumber}\n'
          '${totalLoading.toStringAsFixed(1)}% loaded\n'
          'N\u2082: ${comp.currentPN2.toStringAsFixed(2)} bar'
          '${comp.currentPHe > 0 ? '\nHe: ${comp.currentPHe.toStringAsFixed(2)} bar' : ''}\n'
          'Half-time: ${comp.halfTimeN2.toStringAsFixed(0)} min',
      child: SizedBox(
        height: chartHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [bar],
        ),
      ),
    );
  }

  Widget _buildHeatMapSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    bool expandToFill = false,
  }) {
    final tissueScheme = ref.watch(tissueColorSchemeProvider);
    final colorFn = colorFnForScheme(tissueScheme);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );

    Widget buildStrip({bool flexible = false}) {
      return TissueHeatMapStrip(
        decoStatuses: widget.decoStatuses!,
        selectedIndex: widget.selectedIndex,
        height: 72,
        flexible: flexible,
        colorFn: colorFn,
        hoveredCompartmentIndex: _highlightedCompartmentIndex(),
        onHoverIndexChanged: widget.onHeatMapHover,
        onCompartmentHoverChanged: (compIdx) {
          if (compIdx != null) {
            _setHoveredCompartment(compIdx);
          } else {
            _clearHoveredCompartment();
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.l10n.diveLog_deco_tissueFast, style: labelStyle),
            const Spacer(),
            TissueHeatMapLegend(
              colorScheme: colorScheme,
              textTheme: textTheme,
              colorFn: colorFn,
              leftLabel: tissueScheme.leftLabel,
              rightLabel: tissueScheme.rightLabel,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (expandToFill)
          Expanded(child: buildStrip(flexible: true))
        else
          SizedBox(height: 72, child: buildStrip()),
        Text(context.l10n.diveLog_deco_tissueSlow, style: labelStyle),
      ],
    );
  }

  Widget _buildAreaChartSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    bool expandToFill = false,
  }) {
    final tissueScheme = ref.watch(tissueColorSchemeProvider);
    final colorFn = colorFnForScheme(tissueScheme);

    return TissueAreaChart(
      decoStatuses: widget.decoStatuses!,
      selectedIndex: widget.selectedIndex,
      height: 92,
      isExpanded: true,
      flexible: expandToFill,
      colorFn: colorFn,
      leadingCompartmentIndex: _leadingCompartmentIndex(),
      hoveredCompartmentIndex: _hoveredCompartmentIndex,
      onHoverIndexChanged: widget.onHeatMapHover,
      onCompartmentHoverChanged: (compIdx) {
        if (compIdx != null) {
          _setHoveredCompartment(compIdx);
        } else {
          _clearHoveredCompartment();
        }
      },
    );
  }

  /// Displays one compartment's key values above the charts.
  ///
  /// Bar chart hover shows the specific hovered compartment.
  /// Heat map, area chart, and dive profile hover show the leading
  /// compartment (highest subsurface percentage at depth), since those
  /// charts already provide their own per-compartment tooltips.
  Widget _buildCompartmentDetail(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final comps = widget.status.compartments;
    final ambient = widget.status.ambientPressureBar;
    final leadingIdx = _leadingCompartmentIndex();
    final displayIdx = _barChartDisplayIndex();
    final comp = comps[displayIdx];

    final gf = (comp.gradientFactor(ambient) * 100).clamp(0.0, double.infinity);
    final isOffgassing = comp.totalInertGas > ambient;
    final gfColor = _getGfColor(gf);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    // Show "Leading" when displaying the leading compartment (whether
    // auto-selected or hovered), "Compartment" for any other.
    final titlePrefix = displayIdx == leadingIdx ? 'Leading' : 'Compartment';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 6),
        // Title row
        Row(
          children: [
            Text(
              '$titlePrefix: #${comp.compartmentNumber}',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isOffgassing
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOffgassing ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 9,
                    color: isOffgassing
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isOffgassing ? 'Offgassing' : 'Ongassing',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: isOffgassing
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Values row
        Row(
          children: [
            _buildInfoMetric(
              label: 'Load',
              value: '${comp.percentLoading.toStringAsFixed(0)}%',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _buildInfoMetric(
              label: 'GF',
              value: '${gf.toStringAsFixed(0)}%',
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: gfColor),
            ),
            _buildInfoMetric(
              label: 'N\u2082',
              value: '${comp.currentPN2.toStringAsFixed(2)} bar',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (comp.currentPHe > 0.001)
              _buildInfoMetric(
                label: 'He',
                value: '${comp.currentPHe.toStringAsFixed(2)} bar',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            _buildInfoMetric(
              label: 't\u00BD',
              value: '${comp.halfTimeN2.toStringAsFixed(0)} min',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVizModeToggle(
    ColorScheme colorScheme,
    TissueVizMode currentMode,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeIcon(
          Icons.grid_on,
          TissueVizMode.heatMap,
          currentMode,
          colorScheme,
        ),
        _modeIcon(
          Icons.area_chart,
          TissueVizMode.stackedArea,
          currentMode,
          colorScheme,
        ),
      ],
    );
  }

  Widget _modeIcon(
    IconData icon,
    TissueVizMode mode,
    TissueVizMode currentMode,
    ColorScheme colorScheme,
  ) {
    final isActive = mode == currentMode;
    return GestureDetector(
      onTap: () => ref.read(settingsProvider.notifier).setTissueVizMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          icon,
          size: 16,
          color: isActive
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildColorSchemeSelector(ColorScheme colorScheme) {
    return PopupMenuButton<TissueColorScheme>(
      icon: Icon(
        Icons.palette_outlined,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      itemBuilder: (context) => TissueColorScheme.values.map((scheme) {
        return PopupMenuItem<TissueColorScheme>(
          value: scheme,
          child: Text(scheme.displayName),
        );
      }).toList(),
      onSelected: (scheme) {
        ref.read(settingsProvider.notifier).setTissueColorScheme(scheme);
      },
    );
  }

  /// Returns the 0-based index of the leading compartment using the
  /// depth-aware subsurfacePercentage metric consistent with heat map
  /// coloring and area chart visualization.
  int _leadingCompartmentIndex() {
    final comps = widget.status.compartments;
    final ambient = widget.status.ambientPressureBar;
    int leading = 0;
    double maxPct = -1;
    for (int i = 0; i < comps.length; i++) {
      final pct = subsurfacePercentage(comps[i], ambient);
      if (pct > maxPct) {
        maxPct = pct;
        leading = i;
      }
    }
    return leading;
  }

  /// Returns the compartment index to visually emphasize on cross-chart
  /// widgets (heat map outline, area chart bold line): whichever compartment
  /// is hovered, regardless of source, or the leading compartment.
  int _highlightedCompartmentIndex() {
    return _hoveredCompartmentIndex ?? _leadingCompartmentIndex();
  }

  /// Returns the compartment index for the bar chart and detail panel:
  /// only bar-chart hovers override the leading compartment, since the
  /// heat map and area chart have their own per-compartment tooltips.
  int _barChartDisplayIndex() {
    return (_hoveredCompartmentIndex != null && _hoverFromBarChart)
        ? _hoveredCompartmentIndex!
        : _leadingCompartmentIndex();
  }

  void _setHoveredCompartment(int index, {bool fromBarChart = false}) {
    setState(() {
      _hoveredCompartmentIndex = index;
      _hoverFromBarChart = fromBarChart;
    });
  }

  void _clearHoveredCompartment() {
    setState(() {
      _hoveredCompartmentIndex = null;
      _hoverFromBarChart = false;
    });
  }

  Widget _buildInfoMetric({
    required String label,
    required String value,
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: valueStyle, maxLines: 1),
            ),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }

  Color _getN2Color(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }

  Color _getGfColor(double gfPercent) {
    if (gfPercent >= 100) return Colors.red;
    if (gfPercent >= 80) return Colors.orange;
    if (gfPercent >= 60) return Colors.amber;
    return Colors.green;
  }
}
