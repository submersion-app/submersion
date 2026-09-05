import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_legend_entries.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';

// Re-exported so consumers of the legend keep a single import for the widget
// and its configuration.
export 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart'
    show ProfileLegendConfig, LegendOverlaySource, LegendMetric;

/// Legend row above the dive profile chart.
///
/// Lists the metrics currently drawn on the chart as read-only entries (a
/// dash in the line colour plus a small label), followed by the zoom controls
/// and a button that opens the chart options dropdown. Every toggle, with its
/// checkbox, lives in that dropdown; the entries here only reflect it. The
/// depth trace is the chart itself and is never listed.
class DiveProfileLegend extends ConsumerWidget {
  final ProfileLegendConfig config;
  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final double leftPadding;

  const DiveProfileLegend({
    super.key,
    required this.config,
    required this.zoomLevel,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.leftPadding = 0.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legendState = ref.watch(profileLegendProvider);
    final legendNotifier = ref.read(profileLegendProvider.notifier);

    // Initialize tank pressures if needed
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        legendNotifier.initializeTankPressures(
          config.tankPressures!.keys.toList(),
        );
      });
    }

    final entries = activeLegendEntries(
      context,
      config: config,
      state: legendState,
    );

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 8),
      child: Row(
        children: [
          // One line, scrollable sideways when a multi-source dive lists more
          // entries than fit: the legend keeps a fixed height so it never
          // steals room from the chart below.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _LegendEntry(
                      label: entries[i].label,
                      color: entries[i].color,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          ChartZoomControls(
            zoomLevel: zoomLevel,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
          if (_hasToggles) ...[
            const SizedBox(width: 4),
            _MoreOptionsButton(config: config),
          ],
        ],
      ),
    );
  }

  /// Whether this dive has anything to toggle at all; the options button is
  /// omitted otherwise.
  bool get _hasToggles =>
      config.hasTemperatureData ||
      config.hasPressureData ||
      config.hasEvents ||
      config.hasSecondaryToggles;
}

/// A read-only legend entry: a [LegendDash] in the line colour and the label.
/// Deliberately not tappable; toggling happens in the options dropdown.
class _LegendEntry extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendEntry({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LegendDash(color: color),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          style: labelSmall?.copyWith(
            fontSize: (labelSmall.fontSize ?? 11) - 1,
          ),
        ),
      ],
    );
  }
}

/// The short horizontal dash that stands for a chart line in the legend, in
/// that line's colour.
class LegendDash extends StatelessWidget {
  final Color color;

  const LegendDash({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Opens the chart options dialog, where every metric toggle lives.
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;

  const _MoreOptionsButton({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _showMoreOptions(context),
      icon: const Icon(Icons.tune, size: 18),
      tooltip: context.l10n.diveLog_profile_tooltip_moreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => ChartOptionsDialog(
        config: config,
        anchorOffset: buttonOffset,
        anchorSize: buttonSize,
      ),
    );
  }
}
