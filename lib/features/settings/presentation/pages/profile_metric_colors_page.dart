import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/profile_metric_color_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Appearance > Dives > Metric Colors (issue #3012).
class ProfileMetricColorsPage extends ConsumerWidget {
  const ProfileMetricColorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overrides = ref.watch(
      settingsProvider.select((s) => s.profileMetricColors),
    );
    final palette = ProfileMetricPalette(
      overrides: overrides,
      temperatureAuto: Theme.of(context).colorScheme.tertiary,
    );
    final notifier = ref.read(settingsProvider.notifier);

    Widget row(ProfileMetric metric) => _MetricRow(
      key: ValueKey('metricColorRow-${metric.name}'),
      metric: metric,
      palette: palette,
      onTap: () => showProfileMetricColorSheet(
        context,
        metric: metric,
        palette: palette,
        onPicked: (color) => notifier.setProfileMetricColor(metric, color),
      ),
    );

    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_appearance_metricColors),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.settings_metricColors_resetAll,
            onPressed: overrides.isEmpty
                ? null
                : () => _confirmReset(context, notifier),
          ),
        ],
      ),
      body: ListView(
        children: [
          row(ProfileMetric.depth),
          header(l10n.diveLog_chartSection_overlays),
          for (final m in const [
            ProfileMetric.temperature,
            ProfileMetric.pressure,
            ProfileMetric.heartRate,
            ProfileMetric.sac,
          ])
            row(m),
          header(l10n.diveLog_chartSection_markers),
          row(ProfileMetric.maxDepth),
          header(l10n.diveLog_chartSection_decompression),
          for (final m in const [
            ProfileMetric.ceiling,
            ProfileMetric.ndl,
            ProfileMetric.tts,
            ProfileMetric.gtr,
            ProfileMetric.cns,
            ProfileMetric.otu,
          ])
            row(m),
          header(l10n.diveLog_chartSection_gasAnalysis),
          for (final m in const [
            ProfileMetric.ppO2,
            ProfileMetric.ppN2,
            ProfileMetric.ppHe,
            ProfileMetric.mod,
            ProfileMetric.density,
          ])
            row(m),
          header(l10n.diveLog_chartSection_other),
          for (final m in const [
            ProfileMetric.gf,
            ProfileMetric.surfaceGf,
            ProfileMetric.meanDepth,
          ])
            row(m),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_metricColors_resetAllTitle),
        content: Text(l10n.settings_metricColors_resetAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_metricColors_reset),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.resetProfileMetricColors();
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    super.key,
    required this.metric,
    required this.palette,
    required this.onTap,
  });

  final ProfileMetric metric;
  final ProfileMetricPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = palette.overrides.argbOf(metric) != null;
    final subtitle = switch (metric) {
      ProfileMetric.temperature when !custom =>
        l10n.settings_metricColors_autoTemperature,
      ProfileMetric.pressure when !custom =>
        l10n.settings_metricColors_autoPressure,
      ProfileMetric.pressure => l10n.settings_metricColors_pressureCustom,
      _ => null,
    };
    return ListTile(
      title: Text(profileMetricLabel(l10n, metric)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.colorOf(metric),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
