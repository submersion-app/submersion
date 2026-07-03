import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sub-page for configuring which metrics are visible on the dive profile.
///
/// Organized into four groups: primary metrics, decompression, gas analysis,
/// and gradient factor metrics.
class DefaultVisibleMetricsPage extends ConsumerWidget {
  const DefaultVisibleMetricsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.settings_appearance_subsection_defaultVisibleMetrics,
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_subsection_standardMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_temperature),
            value: settings.defaultShowTemperature,
            onChanged: notifier.setDefaultShowTemperature,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_pressure),
            value: settings.defaultShowPressure,
            onChanged: notifier.setDefaultShowPressure,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_heartRate),
            value: settings.defaultShowHeartRate,
            onChanged: notifier.setDefaultShowHeartRate,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_sacRate),
            value: settings.defaultShowSac,
            onChanged: notifier.setDefaultShowSac,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_events),
            value: settings.defaultShowEvents,
            onChanged: notifier.setDefaultShowEvents,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_photoMarkers),
            value: settings.defaultShowPhotoMarkers,
            onChanged: notifier.setDefaultShowPhotoMarkers,
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_subsection_decompressionMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ceiling),
            value: settings.showCeilingOnProfile,
            onChanged: notifier.setShowCeilingOnProfile,
          ),
          SwitchListTile(
            title: Text(context.l10n.diveLog_legend_label_ascentRate),
            value: settings.showAscentRateColors,
            onChanged: notifier.setShowAscentRateColors,
          ),
          SwitchListTile(
            title: Text(context.l10n.diveLog_legend_label_ascentRateLine),
            value: settings.defaultShowAscentRateLine,
            onChanged: notifier.setDefaultShowAscentRateLine,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ndl),
            value: settings.showNdlOnProfile,
            onChanged: notifier.setShowNdlOnProfile,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_tts),
            value: settings.defaultShowTts,
            onChanged: notifier.setDefaultShowTts,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_cns),
            value: settings.defaultShowCns,
            onChanged: notifier.setDefaultShowCns,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_otu),
            value: settings.defaultShowOtu,
            onChanged: notifier.setDefaultShowOtu,
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_subsection_gasAnalysisMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppO2),
            value: settings.defaultShowPpO2,
            onChanged: notifier.setDefaultShowPpO2,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppN2),
            value: settings.defaultShowPpN2,
            onChanged: notifier.setDefaultShowPpN2,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppHe),
            value: settings.defaultShowPpHe,
            onChanged: notifier.setDefaultShowPpHe,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_gasDensity),
            value: settings.defaultShowGasDensity,
            onChanged: notifier.setDefaultShowGasDensity,
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_subsection_gradientFactorMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_gfPercent),
            value: settings.defaultShowGf,
            onChanged: notifier.setDefaultShowGf,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_surfaceGf),
            value: settings.defaultShowSurfaceGf,
            onChanged: notifier.setDefaultShowSurfaceGf,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_meanDepth),
            value: settings.defaultShowMeanDepth,
            onChanged: notifier.setDefaultShowMeanDepth,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
