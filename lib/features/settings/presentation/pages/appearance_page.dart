import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_preset_picker.dart';
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
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_themes_current),
            subtitle: Text(_resolveCurrentThemeName(context, ref)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/themes'),
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_mode,
          ),
          _buildThemeSelector(context, ref, settings.themeMode),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveLog,
          ),
          // Card coloring attribute selector
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(context.l10n.settings_appearance_cardColorAttribute),
            subtitle: Text(
              context.l10n.settings_appearance_cardColorAttribute_subtitle,
            ),
            trailing: DropdownButton<CardColorAttribute>(
              value: settings.cardColorAttribute,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorAttribute(value);
                }
              },
              items: CardColorAttribute.values.map((attr) {
                return DropdownMenuItem(
                  value: attr,
                  child: Text(_getAttributeDisplayName(context, attr)),
                );
              }).toList(),
            ),
          ),
          // Gradient picker (visible when coloring is active)
          if (settings.cardColorAttribute != CardColorAttribute.none)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GradientPresetPicker(
                selectedPreset: settings.cardColorGradientPreset,
                customStart: settings.cardColorGradientStart,
                customEnd: settings.cardColorGradientEnd,
                onPresetSelected: (preset) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorGradientPreset(preset);
                },
                onCustomSelected: (start, end) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCardColorGradientCustom(start, end);
                },
              ),
            ),
          // Dive list view mode selector
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('Dive List View'),
            subtitle: const Text('Default layout for the dive list'),
            trailing: DropdownButton<DiveListViewMode>(
              value: settings.diveListViewMode,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setDiveListViewMode(value);
                  // Also update the runtime provider
                  ref.read(diveListViewModeProvider.notifier).state = value;
                }
              },
              items: DiveListViewMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(_getViewModeDisplayName(mode)),
                );
              }).toList(),
            ),
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
          ListTile(
            leading: const Icon(Icons.visibility),
            title: Text(
              context.l10n.settings_appearance_subsection_defaultVisibleMetrics,
            ),
            subtitle: Text(
              context.l10n.settings_appearance_metricsEnabledCount(
                _countEnabledMetrics(settings),
                18,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/default-metrics'),
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

  int _countEnabledMetrics(AppSettings settings) {
    final values = [
      settings.defaultShowTemperature,
      settings.defaultShowPressure,
      settings.defaultShowHeartRate,
      settings.defaultShowSac,
      settings.defaultShowEvents,
      settings.showCeilingOnProfile,
      settings.showAscentRateColors,
      settings.showNdlOnProfile,
      settings.defaultShowTts,
      settings.defaultShowCns,
      settings.defaultShowOtu,
      settings.defaultShowPpO2,
      settings.defaultShowPpN2,
      settings.defaultShowPpHe,
      settings.defaultShowGasDensity,
      settings.defaultShowGf,
      settings.defaultShowSurfaceGf,
      settings.defaultShowMeanDepth,
    ];
    return values.where((v) => v).length;
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

  String _resolveCurrentThemeName(BuildContext context, WidgetRef ref) {
    final presetId = ref.watch(settingsProvider.select((s) => s.themePresetId));
    final preset = AppThemeRegistry.findById(presetId);
    final l10n = context.l10n;
    switch (preset.nameKey) {
      case 'theme_submersion':
        return l10n.theme_submersion;
      case 'theme_console':
        return l10n.theme_console;
      case 'theme_tropical':
        return l10n.theme_tropical;
      case 'theme_minimalist':
        return l10n.theme_minimalist;
      case 'theme_deep':
        return l10n.theme_deep;
      default:
        return preset.nameKey;
    }
  }

  String _getViewModeDisplayName(DiveListViewMode mode) {
    return switch (mode) {
      DiveListViewMode.detailed => 'Detailed',
      DiveListViewMode.compact => 'Compact',
      DiveListViewMode.dense => 'Dense',
    };
  }

  String _getAttributeDisplayName(
    BuildContext context,
    CardColorAttribute attr,
  ) {
    return switch (attr) {
      CardColorAttribute.none =>
        context.l10n.settings_appearance_cardColorAttribute_none,
      CardColorAttribute.depth =>
        context.l10n.settings_appearance_cardColorAttribute_depth,
      CardColorAttribute.duration =>
        context.l10n.settings_appearance_cardColorAttribute_duration,
      CardColorAttribute.temperature =>
        context.l10n.settings_appearance_cardColorAttribute_temperature,
    };
  }
}
