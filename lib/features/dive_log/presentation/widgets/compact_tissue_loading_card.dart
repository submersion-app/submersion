import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/info/tissue_loading_info.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_area_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_compartment_detail.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// Glyph size for every control in the card header.
const double _headerIconSize = 16;

/// Shared style for every control in the card header.
///
/// The header mixes plain [IconButton]s with a [PopupMenuButton], so the only
/// way the icons stay evenly spaced is for all of them to lay out to the same
/// box. [ButtonStyle.tapTargetSize] is deliberately left unset so it falls
/// back to the theme default of [MaterialTapTargetSize.padded]: that is what
/// gives each control an accessible touch target of
/// `kMinInteractiveDimension` (48) plus the compact density adjustment (-8),
/// i.e. 40x40 around a [_headerIconSize] glyph.
const _headerButtonStyle = ButtonStyle(visualDensity: VisualDensity.compact);

/// Compact card displaying tissue loading visualizations and live data.
///
/// Contains:
/// - Compartment detail panel (load, GF, N2 and He with their directions)
/// - Tissue pressure bar chart (Subsurface-style, 16 compartments) with a
///   surface level marker per bar
/// - Tissue loading heat map or stacked area chart over time
/// - An info icon in the header explaining the values
///
/// Used by the dive detail view and the current dive load page; both show
/// the same card, so every change here reaches both.
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

  /// Opens the 3D tissue saturation view. The button is hidden when null,
  /// keeping this widget free of any dive_3d navigation dependency.
  final VoidCallback? onOpen3dView;

  const CompactTissueLoadingCard({
    super.key,
    required this.status,
    this.decoStatuses,
    this.selectedIndex,
    this.subtitle,
    this.onHeatMapHover,
    this.expandVisualization = false,
    this.onOpen3dView,
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
    // Once per build: the detail panel, the bar chart's screen reader label
    // and both visualizations all name this compartment.
    final leadingIndex = _leadingCompartmentIndex();
    final hasViz =
        widget.decoStatuses != null && widget.decoStatuses!.isNotEmpty;
    final vizWidget = hasViz
        ? switch (vizMode) {
            TissueVizMode.heatMap => _buildHeatMapSection(
              context,
              colorScheme,
              textTheme,
              leadingIndex: leadingIndex,
              expandToFill: expand,
            ),
            TissueVizMode.stackedArea => _buildAreaChartSection(
              leadingIndex: leadingIndex,
              expandToFill: expand,
            ),
          }
        : null;

    final hasCompartments = widget.status.compartments.isNotEmpty;
    final displayIndex = hasCompartments
        ? _barChartDisplayIndex(leadingIndex)
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
                // Every control below shares _headerButtonStyle, so each one
                // lays out to the same box and the gaps stay even. Do not add
                // manual spacers between them: the icons are built from
                // different widget types whose intrinsic widths differ, and
                // uniform spacers on top of non-uniform boxes is exactly what
                // made the spacing drift before.
                //
                // One dropdown picks the view (issue #4437). The colour scheme
                // is a standing preference that also drives Dive Lab and the
                // 3D view, so it lives in Settings > Appearance > Dives.
                _buildViewMenu(vizMode, colorScheme),
                if (widget.onOpen3dView != null)
                  _build3dViewButton(colorScheme),
                // Laid out to the compact buttons' 40 px box, like its
                // neighbours.
                HeaderInfoButton(
                  title: context.l10n.diveLog_deco_sectionTissueLoading,
                  width: 40,
                  height: 40,
                  content: (context) => tissueLoadingInfo(
                    context.l10n,
                    infoUnits(context),
                    view: hasViz ? vizMode : null,
                    hasHelium: widget.status.compartments.any(
                      (c) => c.currentPHe > 0.001,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Compartment detail panel (above charts for proximity to title)
            if (displayIndex != null) ...[
              TissueCompartmentDetail(
                status: widget.status,
                displayIndex: displayIndex,
                isLeading: displayIndex == leadingIndex,
              ),
              const SizedBox(height: 6),
            ],

            // Tissue pressure bar chart (with per-bar hover)
            TissuePressureBarChart(
              status: widget.status,
              highlightedIndex: displayIndex,
              // The compartment the visible "Leading" text names, so the
              // screen reader announces the same one.
              leadingIndex: hasCompartments ? leadingIndex : null,
              onCompartmentHover: (index) =>
                  _setHoveredCompartment(index, fromBarChart: true),
              onHoverExit: _clearHoveredCompartment,
            ),
            const SizedBox(height: 6),

            // Visualization (expanded to fill remaining space when possible)
            if (vizWidget != null)
              if (expand) Expanded(child: vizWidget) else vizWidget,
          ],
        ),
      ),
    );
  }

  /// The heat map with its legend above and the row direction below.
  ///
  /// Its rows run fast to slow from top to bottom. That axis is named once,
  /// in a caption under the strip, rather than with a second "Fast"/"Slow"
  /// pair that read as a duplicate of the bar chart's labels just above.
  Widget _buildHeatMapSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required int leadingIndex,
    bool expandToFill = false,
  }) {
    final l10n = context.l10n;
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
        hoveredCompartmentIndex: _highlightedCompartmentIndex(leadingIndex),
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
        // Trailing end, so it follows the text direction (left in RTL).
        Align(
          alignment: AlignmentDirectional.centerEnd,
          // Names its halves itself; see TissueHeatMapLegend for why.
          child: TissueHeatMapLegend(
            colorScheme: colorScheme,
            textTheme: textTheme,
            colorFn: colorFn,
          ),
        ),
        const SizedBox(height: 4),
        if (expandToFill)
          Expanded(child: buildStrip(flexible: true))
        else
          SizedBox(height: 72, child: buildStrip()),
        const SizedBox(height: 2),
        Text(l10n.diveLog_deco_heatMapRows, style: labelStyle),
      ],
    );
  }

  Widget _buildAreaChartSection({
    required int leadingIndex,
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
      leadingCompartmentIndex: leadingIndex,
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

  /// The header's view dropdown: the current view's icon with a caret,
  /// opening a menu of both views by icon and name, the current one checked.
  Widget _buildViewMenu(TissueVizMode current, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return PopupMenuButton<TissueVizMode>(
      tooltip: l10n.diveLog_tissue_viewMenuTooltip,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _viewIcon(current),
            size: _headerIconSize,
            color: colorScheme.primary,
          ),
          Icon(
            Icons.arrow_drop_down,
            size: _headerIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      // No `constraints:` here. On PopupMenuButton that parameter sizes the
      // popup menu, not the button.
      padding: EdgeInsets.zero,
      style: _headerButtonStyle,
      initialValue: current,
      itemBuilder: (context) => [
        for (final mode in TissueVizMode.values)
          CheckedPopupMenuItem<TissueVizMode>(
            value: mode,
            checked: mode == current,
            child: Row(
              children: [
                Icon(_viewIcon(mode), size: 18),
                const SizedBox(width: 12),
                Text(tissueVizModeLabel(l10n, mode)),
              ],
            ),
          ),
      ],
      onSelected: (mode) =>
          ref.read(settingsProvider.notifier).setTissueVizMode(mode),
    );
  }

  static IconData _viewIcon(TissueVizMode mode) => switch (mode) {
    TissueVizMode.heatMap => Icons.grid_on,
    TissueVizMode.stackedArea => Icons.area_chart,
  };

  Widget _build3dViewButton(ColorScheme colorScheme) {
    return IconButton(
      icon: Icon(
        Icons.view_in_ar,
        size: _headerIconSize,
        color: colorScheme.onSurfaceVariant,
      ),
      tooltip: context.l10n.dive3d_previewTitle,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: _headerButtonStyle,
      onPressed: widget.onOpen3dView,
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
  /// is hovered, regardless of source, or the leading compartment
  /// ([leadingIndex], from [_leadingCompartmentIndex]).
  int _highlightedCompartmentIndex(int leadingIndex) {
    return _hoveredCompartmentIndex ?? leadingIndex;
  }

  /// Returns the compartment index for the bar chart and detail panel:
  /// only bar-chart hovers override the leading compartment
  /// ([leadingIndex]), since the heat map and area chart have their own
  /// per-compartment tooltips.
  int _barChartDisplayIndex(int leadingIndex) {
    return (_hoveredCompartmentIndex != null && _hoverFromBarChart)
        ? _hoveredCompartmentIndex!
        : leadingIndex;
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
}
