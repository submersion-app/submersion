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
/// circle in the line colour plus a small label). A button that opens the
/// chart options dropdown is pinned to the legend's trailing edge, beside
/// the zoom controls. Every toggle, with its
/// checkbox, lives in that dropdown; the entries here only reflect it. Depth
/// leads the row and is always listed.
///
/// Entries that do not fit are not rendered at all, and their number is
/// badged on the options button, so the row truncates cleanly rather than
/// clipping a label part-way through.
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
      padding: EdgeInsets.only(left: leftPadding, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Only entries that fit whole are rendered; the rest are
                // reported as a count on the options button. Measuring here
                // rather than letting the row overflow is what keeps a label
                // from being sliced through the middle at the right edge.
                final layout = _layoutRows(
                  context,
                  entries: entries,
                  maxWidth: constraints.maxWidth,
                );

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in layout.rows) _buildRow(row),
                        ],
                      ),
                    ),
                    // Anchored to the trailing edge of the legend, next to
                    // the zoom controls, rather than trailing the last entry:
                    // a button that moves whenever a metric is toggled is a
                    // button the diver has to hunt for.
                    if (_hasToggles)
                      _MoreOptionsButton(
                        config: config,
                        hiddenCount: layout.hiddenCount,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          ChartZoomControls(
            dense: true,
            zoomLevel: zoomLevel,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
        ],
      ),
    );
  }

  /// One rendered row of entries.
  Widget _buildRow(List<ActiveLegendEntry> entries) {
    // The admitted set is measured to fit, so this scroll view never actually
    // scrolls; it exists to clip gracefully in degenerate over-constrained
    // layouts instead of throwing RenderFlex overflow errors.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: _itemSpacing),
            _LegendEntry(label: entries[i].label, color: entries[i].color),
          ],
        ],
      ),
    );
  }

  /// Lays [entries] out into at most [_maxRows] rows of [maxWidth].
  ///
  /// A single row is tried first, so a legend that fits on one line keeps the
  /// options button immediately beside its entries. Only when something would
  /// otherwise be dropped does the legend take a second line; the button then
  /// trails that line, and its width is reserved there.
  _LegendRowLayout _layoutRows(
    BuildContext context, {
    required List<ActiveLegendEntry> entries,
    required double maxWidth,
  }) {
    final style = legendEntryLabelStyle(context);
    final widths = [
      for (final entry in entries)
        _entryChromeWidth + _labelWidth(context, entry.label, style),
    ];
    // The button sits beside the rows, so every row loses the same width to
    // it: its own, plus the gap before it.
    final button = _hasToggles ? _moreButtonWidth + _itemSpacing : 0.0;
    final rowWidth = maxWidth - _safetyMargin - button;

    final single = _fillRows(entries, widths, [rowWidth]);
    if (single.hiddenCount == 0) return single;
    return _fillRows(entries, widths, [rowWidth, rowWidth]);
  }

  /// Greedily fills [rowWidths] in display order.
  ///
  /// An entry too wide for what is left of its row moves to the next row; on
  /// the last row it is skipped and the shorter entries after it are still
  /// considered. Stopping instead of skipping would let one long label
  /// swallow everything behind it, so switching on a tank whose label carries
  /// its gas mix would appear to remove the ceiling and NDL entries after it.
  _LegendRowLayout _fillRows(
    List<ActiveLegendEntry> entries,
    List<double> widths,
    List<double> rowWidths,
  ) {
    final rows = [
      for (var i = 0; i < rowWidths.length; i++) <ActiveLegendEntry>[],
    ];
    final used = List<double>.filled(rowWidths.length, 0);
    var row = 0;
    var hidden = 0;

    for (var i = 0; i < entries.length; i++) {
      var placed = false;
      while (true) {
        final width = (rows[row].isEmpty ? 0.0 : _itemSpacing) + widths[i];
        if (used[row] + width <= rowWidths[row]) {
          used[row] += width;
          rows[row].add(entries[i]);
          placed = true;
          break;
        }
        // Move down only if this row has something in it. An entry that will
        // not fit an empty row will not fit the next one either (which is no
        // wider), so skip it rather than stranding an empty row above it.
        if (rows[row].isNotEmpty && row < rowWidths.length - 1) {
          row++;
          continue;
        }
        break;
      }
      if (!placed) hidden++;
    }

    while (rows.length > 1 && rows.last.isEmpty) {
      rows.removeLast();
    }
    return _LegendRowLayout(rows, hidden);
  }

  // Geometry of one entry as built by _LegendEntry below: swatch 10, gap 3,
  // then the label text. _entryChromeWidth MUST change in lockstep with any
  // visual edit to _LegendEntry or LegendSwatch.
  static const double _entryChromeWidth = LegendSwatch.size + 3;

  static const double _itemSpacing = 10;

  /// Side of the options button. The row reserves exactly this much for it,
  /// so the button must render at this size - see the tapTargetSize note in
  /// [_MoreOptionsButton].
  static const double optionsButtonSize = 32;

  static const double _moreButtonWidth = optionsButtonSize;
  static const double _safetyMargin = 8;

  double _labelWidth(BuildContext context, String label, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Whether this dive has anything to toggle at all; the options button is
  /// omitted otherwise.
  bool get _hasToggles =>
      config.hasTemperatureData ||
      config.hasPressureData ||
      config.hasEvents ||
      config.hasSecondaryToggles;
}

/// Entries laid out into rows, plus how many did not fit at all.
@immutable
class _LegendRowLayout {
  final List<List<ActiveLegendEntry>> rows;
  final int hiddenCount;

  const _LegendRowLayout(this.rows, this.hiddenCount);
}

/// Text style for an inline legend label.
///
/// Shared with the legend's width measurement: measuring with a different
/// style than the one rendered would hide entries that actually fit, or admit
/// entries that then overflow.
TextStyle? legendEntryLabelStyle(BuildContext context) {
  final labelSmall = Theme.of(context).textTheme.labelSmall;
  return labelSmall?.copyWith(fontSize: (labelSmall.fontSize ?? 11) - 1);
}

/// A read-only legend entry: a [LegendSwatch] in the line colour and the label.
/// Deliberately not tappable; toggling happens in the options dropdown.
class _LegendEntry extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendEntry({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LegendSwatch(color: color),
        const SizedBox(width: 3),
        Text(label, maxLines: 1, style: legendEntryLabelStyle(context)),
      ],
    );
  }
}

/// The small dot that stands for a chart line in the legend, in that line's
/// colour.
///
/// A filled circle rather than a dash: at legend size a 3px-tall dash carries
/// too few pixels of colour to tell two similar hues apart at a glance, which
/// is the one job this mark has.
class LegendSwatch extends StatelessWidget {
  final Color color;

  const LegendSwatch({super.key, required this.color});

  /// Diameter. [DiveProfileLegend._entryChromeWidth] is derived from this, so
  /// the row measurement follows any change here.
  static const double size = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Opens the chart options dialog, where every metric toggle lives.
///
/// Carries a badge counting the drawn metrics that did not fit the inline
/// row, so a truncated legend still says how much it is not showing.
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;
  final int hiddenCount;

  const _MoreOptionsButton({required this.config, required this.hiddenCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () => _showMoreOptions(context),
      icon: Badge(
        isLabelVisible: hiddenCount > 0,
        label: Text(
          hiddenCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.tune, size: 20),
      ),
      tooltip: context.l10n.diveLog_profile_tooltip_moreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: DiveProfileLegend.optionsButtonSize,
        minHeight: DiveProfileLegend.optionsButtonSize,
      ),
      style: IconButton.styleFrom(
        // Without this the button keeps Material's padded 48px tap target,
        // renders 16px wider than the row reserved for it, and is sliced in
        // half by the clip at the end of the row.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: hiddenCount > 0
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
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
