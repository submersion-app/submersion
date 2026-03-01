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

  const CompactTissueLoadingCard({
    super.key,
    required this.status,
    this.decoStatuses,
    this.selectedIndex,
    this.subtitle,
    this.onHeatMapHover,
  });

  @override
  ConsumerState<CompactTissueLoadingCard> createState() =>
      _CompactTissueLoadingCardState();
}

class _CompactTissueLoadingCardState
    extends ConsumerState<CompactTissueLoadingCard> {
  /// Index of the compartment currently hovered on either chart (0-based).
  /// When null, the detail panel shows the leading compartment (highest GF).
  int? _hoveredCompartmentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final vizMode = ref.watch(tissueVizModeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // Tissue pressure bar chart (with per-bar hover)
            _buildTissuePressureDiagram(context, colorScheme),
            const SizedBox(height: 6),

            // Visualization (switches by mode)
            if (widget.decoStatuses != null &&
                widget.decoStatuses!.isNotEmpty) ...[
              switch (vizMode) {
                TissueVizMode.heatMap => _buildHeatMapSection(
                  context,
                  colorScheme,
                  textTheme,
                ),
                TissueVizMode.stackedArea => _buildAreaChartSection(
                  context,
                  colorScheme,
                  textTheme,
                ),
              },
              const SizedBox(height: 6),
            ],

            // Compartment detail panel
            if (widget.status.compartments.isNotEmpty)
              _buildCompartmentDetail(context, colorScheme, textTheme),
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
                Row(
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
                          onEnter: (_) => _setHoveredCompartment(idx),
                          onExit: (_) => _clearHoveredCompartment(),
                          child: GestureDetector(
                            onTapDown: (_) => _setHoveredCompartment(idx),
                            child: _buildSubsurfaceBar(
                              comp,
                              chartHeight,
                              maxLoadingPercent,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
    double maxLoading,
  ) {
    final totalLoading = comp.percentLoading.clamp(0.0, maxLoading);
    final barHeight = chartHeight * (totalLoading / maxLoading);

    final totalGas = comp.totalInertGas;
    final n2Ratio = totalGas > 0 ? comp.currentPN2 / totalGas : 1.0;
    final heRatio = totalGas > 0 ? comp.currentPHe / totalGas : 0.0;

    final n2Height = barHeight * n2Ratio;
    final heHeight = barHeight * heRatio;

    final n2Color = _getN2Color(totalLoading);

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
                color: n2Color,
                borderRadius: BorderRadius.vertical(
                  top: heHeight > 0.5 ? Radius.zero : const Radius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMapSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final tissueScheme = ref.watch(tissueColorSchemeProvider);
    final colorFn = colorFnForScheme(tissueScheme);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        Row(
          children: [
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fast', style: labelStyle),
                const SizedBox(height: 44),
                Text('Slow', style: labelStyle),
              ],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TissueHeatMapStrip(
                decoStatuses: widget.decoStatuses!,
                selectedIndex: widget.selectedIndex,
                height: 72,
                colorFn: colorFn,
                onHoverIndexChanged: widget.onHeatMapHover,
                onCompartmentHoverChanged: (compIdx) {
                  if (compIdx != null) {
                    _setHoveredCompartment(compIdx);
                  } else {
                    _clearHoveredCompartment();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaChartSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final tissueScheme = ref.watch(tissueColorSchemeProvider);
    final colorFn = colorFnForScheme(tissueScheme);

    return TissueAreaChart(
      decoStatuses: widget.decoStatuses!,
      selectedIndex: widget.selectedIndex,
      height: 92,
      isExpanded: true,
      colorFn: colorFn,
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

  /// Displays one compartment's key values below the charts.
  ///
  /// Shows whichever compartment is being hovered on either chart,
  /// or falls back to the leading compartment (highest GF at depth).
  Widget _buildCompartmentDetail(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final comps = widget.status.compartments;

    // Use hovered compartment if valid, otherwise leading compartment
    final TissueCompartment comp;
    final bool isHovered;
    if (_hoveredCompartmentIndex != null &&
        _hoveredCompartmentIndex! < comps.length) {
      comp = comps[_hoveredCompartmentIndex!];
      isHovered = true;
    } else {
      comp = comps.reduce(
        (a, b) => a.percentLoading > b.percentLoading ? a : b,
      );
      isHovered = false;
    }

    final gf = (comp.gradientFactor(widget.status.ambientPressureBar) * 100)
        .clamp(0.0, double.infinity);
    final isOffgassing = comp.totalInertGas > widget.status.ambientPressureBar;
    final gfColor = _getGfColor(gf);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final titlePrefix = isHovered ? 'Compartment' : 'Leading';

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

  void _setHoveredCompartment(int index) {
    setState(() {
      _hoveredCompartmentIndex = index;
    });
  }

  void _clearHoveredCompartment() {
    setState(() {
      _hoveredCompartmentIndex = null;
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
