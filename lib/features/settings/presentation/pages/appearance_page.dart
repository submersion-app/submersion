import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_appearance_title),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_theme,
          ),
          _buildThemeSelector(context, ref, settings.themeMode),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_language,
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_appearance_appLanguage),
            subtitle: Text(
              LanguageSettingsPage.getDisplayName(settings.locale),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/language'),
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveLog,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_depthColoredCards),
            subtitle: Text(
              context.l10n.settings_appearance_depthColoredCards_subtitle,
            ),
            secondary: const Icon(Icons.gradient),
            value: settings.showDepthColoredDiveCards,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowDepthColoredDiveCards(value);
            },
          ),
          SwitchListTile(
            title: Text(
              context.l10n.settings_appearance_mapBackgroundDiveCards,
            ),
            subtitle: Text(
              context
                  .l10n
                  .settings_appearance_mapBackgroundDiveCards_subtitleWithNote,
            ),
            secondary: const Icon(Icons.map),
            value: settings.showMapBackgroundOnDiveCards,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowMapBackgroundOnDiveCards(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveSites,
          ),
          SwitchListTile(
            title: Text(
              context.l10n.settings_appearance_mapBackgroundSiteCards,
            ),
            subtitle: Text(
              context
                  .l10n
                  .settings_appearance_mapBackgroundSiteCards_subtitleWithNote,
            ),
            secondary: const Icon(Icons.map),
            value: settings.showMapBackgroundOnSiteCards,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowMapBackgroundOnSiteCards(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveProfile,
          ),
          // Right Y-Axis Metric Selector
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: Text(context.l10n.settings_appearance_rightYAxisMetric),
            subtitle: Text(
              context.l10n.settings_appearance_rightYAxisMetric_subtitle,
            ),
            trailing: DropdownButton<ProfileRightAxisMetric>(
              value: settings.defaultRightAxisMetric,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setDefaultRightAxisMetric(value);
                }
              },
              items: ProfileRightAxisMetric.values.map((metric) {
                return DropdownMenuItem(
                  value: metric,
                  child: Text(metric.displayName),
                );
              }).toList(),
            ),
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_maxDepthMarker),
            subtitle: Text(
              context.l10n.settings_appearance_maxDepthMarker_subtitleFull,
            ),
            secondary: const Icon(Icons.vertical_align_bottom),
            value: settings.showMaxDepthMarker,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowMaxDepthMarker(value);
            },
          ),
          SwitchListTile(
            title: Text(
              context.l10n.settings_appearance_pressureThresholdMarkers,
            ),
            subtitle: Text(
              context
                  .l10n
                  .settings_appearance_pressureThresholdMarkers_subtitleFull,
            ),
            secondary: const Icon(Icons.propane_tank),
            value: settings.showPressureThresholdMarkers,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowPressureThresholdMarkers(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_gasSwitchMarkers),
            subtitle: Text(
              context.l10n.settings_appearance_gasSwitchMarkers_subtitle,
            ),
            secondary: const Icon(Icons.swap_horiz),
            value: settings.defaultShowGasSwitchMarkers,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowGasSwitchMarkers(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(
            context,
            context.l10n.settings_appearance_subsection_defaultVisibleMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_temperature),
            dense: true,
            value: settings.defaultShowTemperature,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowTemperature(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_pressure),
            dense: true,
            value: settings.defaultShowPressure,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPressure(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_heartRate),
            dense: true,
            value: settings.defaultShowHeartRate,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowHeartRate(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_sacRate),
            dense: true,
            value: settings.defaultShowSac,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowSac(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_events),
            dense: true,
            value: settings.defaultShowEvents,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowEvents(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(
            context,
            context.l10n.settings_appearance_subsection_decompressionMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ceiling),
            dense: true,
            value: settings.showCeilingOnProfile,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowCeilingOnProfile(value);
            },
          ),
          SwitchListTile(
            title: Text(
              context.l10n.settings_appearance_metric_ascentRateColors,
            ),
            dense: true,
            value: settings.showAscentRateColors,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowAscentRateColors(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ndl),
            dense: true,
            value: settings.showNdlOnProfile,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowNdlOnProfile(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_tts),
            dense: true,
            value: settings.defaultShowTts,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowTts(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(
            context,
            context.l10n.settings_appearance_subsection_gasAnalysisMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppO2),
            dense: true,
            value: settings.defaultShowPpO2,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpO2(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppN2),
            dense: true,
            value: settings.defaultShowPpN2,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpN2(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_ppHe),
            dense: true,
            value: settings.defaultShowPpHe,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpHe(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_gasDensity),
            dense: true,
            value: settings.defaultShowGasDensity,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowGasDensity(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(
            context,
            context.l10n.settings_appearance_subsection_gradientFactorMetrics,
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_gfPercent),
            dense: true,
            value: settings.defaultShowGf,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowGf(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_surfaceGf),
            dense: true,
            value: settings.defaultShowSurfaceGf,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowSurfaceGf(value);
            },
          ),
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_meanDepth),
            dense: true,
            value: settings.defaultShowMeanDepth,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowMeanDepth(value);
            },
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

  Widget _buildSubsectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    return Column(
      children: ThemeMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return Semantics(
          selected: isSelected,
          child: ListTile(
            leading: Icon(_getThemeModeIcon(mode)),
            title: Text(_getThemeModeName(context, mode)),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: context.l10n.settings_language_selected,
                  )
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(mode);
            },
          ),
        );
      }).toList(),
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.l10n.settings_appearance_theme_system;
      case ThemeMode.light:
        return context.l10n.settings_appearance_theme_light;
      case ThemeMode.dark:
        return context.l10n.settings_appearance_theme_dark;
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}
