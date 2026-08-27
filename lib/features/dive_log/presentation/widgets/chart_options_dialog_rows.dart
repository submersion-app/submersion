/// Generic row widgets for [ChartOptionsDialog]'s legend sections.
///
/// Split out of chart_options_dialog.dart, which crossed the project's
/// 800-line file cap: these builders carry no dialog-specific state (no
/// `config`, no anchor geometry), so they extract cleanly as top-level
/// functions.
library;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

Widget buildOptionsSection(
  BuildContext context, {
  required String key,
  required String title,
  required ProfileLegendState legendState,
  required ProfileLegend legendNotifier,
  required List<Widget> children,
}) {
  return Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: PageStorageKey(key),
      title: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      initiallyExpanded: legendState.sectionExpanded[key] ?? false,
      onExpansionChanged: (expanded) =>
          legendNotifier.setSectionExpanded(key, expanded),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: EdgeInsets.zero,
      dense: true,
      children: children,
    ),
  );
}

/// Computer/Calculated segments, shared by every deco source switch.
List<(MetricDataSource, String)> sourceSegments(BuildContext context) => [
  (MetricDataSource.computer, context.l10n.diveLog_legend_source_dc),
  (MetricDataSource.calculated, context.l10n.diveLog_legend_source_calc),
];

/// A toggle row with a segmented mode switch on the right. Generic over the
/// mode enum so every computer-vs-calculated data-source toggle (deco stops,
/// NDL, TTS, CNS) shares one row implementation.
Widget buildToggleWithSource<T>(
  BuildContext context, {
  required String label,
  required Color color,
  required bool isEnabled,
  required VoidCallback onTap,
  required T currentSource,
  required ValueChanged<T> onSourceChanged,
  required List<(T, String)> segments,
  bool isAreaSwatch = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: isEnabled
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          // Area metrics are drawn on the chart as a translucent shaded
          // region rather than a stroked curve, so their swatch is a filled
          // block in the same wash instead of a line.
          if (isAreaSwatch)
            Container(
              width: 16,
              height: 12,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: isEnabled ? decoStopFillAlpha : decoStopFillAlpha / 2,
                ),
                border: Border.all(
                  color: color.withValues(alpha: isEnabled ? 0.5 : 0.2),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          GestureDetector(
            onTap: () {}, // absorb tap to prevent parent InkWell from firing
            child: SizedBox(
              height: 28,
              child: SegmentedButton<T>(
                segments: [
                  for (final (value, text) in segments)
                    ButtonSegment(
                      value: value,
                      label: Text(text, style: const TextStyle(fontSize: 11)),
                    ),
                ],
                selected: {currentSource},
                onSelectionChanged: (selected) =>
                    onSourceChanged(selected.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Variant of [buildToggleItem] for the gas-timeline visibility toggle.
/// Replaces the single-color decoration stripe with four stacked bars in
/// the air → nitrox → oxygen → trimix colors so the indicator visually
/// advertises every gas type the strip can render, not just one.
Widget buildGasToggleItem(
  BuildContext context, {
  required String label,
  required bool isEnabled,
  required VoidCallback onTap,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final iconColor = isEnabled
      ? colorScheme.primary
      : colorScheme.onSurfaceVariant;
  Widget bar(Color color) => Container(
    width: 16,
    height: 3,
    decoration: BoxDecoration(
      color: isEnabled ? color : color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bar(GasColors.air),
              const SizedBox(height: 1),
              bar(GasColors.nitrox),
              const SizedBox(height: 1),
              bar(GasColors.oxygen),
              const SizedBox(height: 1),
              bar(GasColors.trimix),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    ),
  );
}

/// Wraps a hand-rolled check-box row so assistive technology announces it as
/// a checkbox with its state, not as an unlabelled button. The rows draw
/// their own [Icons.check_box] rather than using [Checkbox], which carries no
/// semantics of its own; [MergeSemantics] folds the state onto the same node
/// as the [InkWell]'s tap action so the two are announced together.
Widget _checkboxSemantics({required bool isEnabled, required Widget child}) =>
    MergeSemantics(
      child: Semantics(checked: isEnabled, child: child),
    );

Widget buildToggleItem(
  BuildContext context, {
  required String label,
  required Color color,
  required bool isEnabled,
  required VoidCallback onTap,
}) {
  return _checkboxSemantics(
    isEnabled: isEnabled,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: isEnabled
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}

/// A checkbox row for a rendering-behaviour option. Unlike [buildToggleItem]
/// it carries no series colour swatch, because it does not correspond to a
/// line on the chart.
Widget buildBehaviorItem(
  BuildContext context, {
  required String label,
  required bool isEnabled,
  required VoidCallback onTap,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return _checkboxSemantics(
    isEnabled: isEnabled,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}

Widget buildStaticItem(
  BuildContext context, {
  required String label,
  required Color color,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 12),
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
