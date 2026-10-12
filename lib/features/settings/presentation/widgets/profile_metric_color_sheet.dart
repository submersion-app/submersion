import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The colour choice for one profile metric (issue #3012): Default (or
/// Auto), then every palette swatch. A swatch another metric shows names it,
/// since picking it swaps the two.
Future<void> showProfileMetricColorSheet(
  BuildContext context, {
  required ProfileMetric metric,
  required ProfileMetricPalette palette,
  required ValueChanged<Color?> onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _SheetBody(
          metric: metric,
          palette: palette,
          onPicked: (color) {
            Navigator.of(sheetContext).pop();
            onPicked(color);
          },
        ),
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.metric,
    required this.palette,
    required this.onPicked,
  });

  final ProfileMetric metric;
  final ProfileMetricPalette palette;
  final ValueChanged<Color?> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = palette.overrides.effectiveArgb(metric);
    final onDefault = palette.overrides.argbOf(metric) == null;
    final names = _distinctNames(
      profileMetricSwatches.map((c) => swatchName(l10n, c)).toList(),
    );
    // Default can swap too: another metric may hold this one's default.
    final defaultArgb = metric.defaultColor?.toARGB32();
    final defaultHolder = defaultArgb == null || onDefault
        ? null
        : palette.overrides.holderOf(defaultArgb, except: metric);
    final defaultLabel = metric.isAuto
        ? l10n.settings_metricColors_auto
        : l10n.settings_metricColors_default;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_metricColors_sheetTitle(
            profileMetricLabel(l10n, metric),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _Swatch(
              // The colour Default/Auto gives, not the current choice.
              color:
                  metric.defaultColor ??
                  (metric == ProfileMetric.temperature
                      ? palette.temperatureAuto
                      : ProfileMetricColors.pressure),
              selected: onDefault,
              // Like any held swatch, name the metric it would swap with.
              caption: defaultHolder == null
                  ? defaultLabel
                  : '$defaultLabel · ${profileMetricLabel(l10n, defaultHolder)}',
              semanticsLabel: defaultHolder == null
                  ? defaultLabel
                  : '$defaultLabel, ${l10n.settings_metricColors_swapsWith(profileMetricLabel(l10n, defaultHolder))}',
              onTap: () => onPicked(null),
            ),
            for (var i = 0; i < profileMetricSwatches.length; i++)
              _buildSwatch(
                context,
                profileMetricSwatches[i],
                names[i],
                current,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwatch(
    BuildContext context,
    Color swatch,
    String name,
    int? current,
  ) {
    final l10n = context.l10n;
    final argb = swatch.toARGB32();
    final holder = palette.overrides.holderOf(argb, except: metric);
    final holderLabel = holder == null
        ? null
        : profileMetricLabel(l10n, holder);
    return _Swatch(
      color: swatch,
      selected: argb == current && palette.overrides.argbOf(metric) != null,
      caption: holderLabel,
      semanticsLabel: holderLabel == null
          ? name
          : '$name, ${l10n.settings_metricColors_swapsWith(holderLabel)}',
      onTap: () => onPicked(swatch),
    );
  }
}

/// [names] with a repeated name numbered from its second use ("Green",
/// "Green 2"), so a screen reader can tell swatches with the same nearest
/// colour name apart.
List<String> _distinctNames(List<String> names) {
  final seen = <String, int>{};
  return [
    for (final name in names)
      switch (seen.update(name, (n) => n + 1, ifAbsent: () => 1)) {
        1 => name,
        final n => '$name $n',
      },
  ];
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    this.caption,
  });

  final Color color;
  final bool selected;
  final String semanticsLabel;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: SizedBox(
          // Wide enough for a two-line caption such as "Heart Rate".
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: caption == null
                    ? null
                    : Text(
                        caption!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
