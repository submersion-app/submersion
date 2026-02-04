import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Theme'),
          _buildThemeSelector(context, ref, settings.themeMode),
          const Divider(),
          _buildSectionHeader(context, 'Dive Log'),
          SwitchListTile(
            title: const Text('Depth-colored dive cards'),
            subtitle: const Text(
              'Show dive cards with ocean-colored backgrounds based on depth',
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
            title: const Text('Map background on dive cards'),
            subtitle: const Text(
              'Show dive site map as background on dive cards (requires site location)',
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
          _buildSectionHeader(context, 'Dive Sites'),
          SwitchListTile(
            title: const Text('Map background on site cards'),
            subtitle: const Text(
              'Show map as background on dive site cards (requires site location)',
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
          _buildSectionHeader(context, 'Dive Profile'),
          // Right Y-Axis Metric Selector
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Right Y-axis metric'),
            subtitle: const Text('Default metric shown on right axis'),
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
            title: const Text('Max depth marker'),
            subtitle: const Text(
              'Show a marker at the maximum depth point on dive profiles',
            ),
            secondary: const Icon(Icons.vertical_align_bottom),
            value: settings.showMaxDepthMarker,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowMaxDepthMarker(value);
            },
          ),
          SwitchListTile(
            title: const Text('Pressure threshold markers'),
            subtitle: const Text(
              'Show markers when tank pressure crosses 2/3, 1/2, and 1/3 thresholds',
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
            title: const Text('Gas switch markers'),
            subtitle: const Text('Show markers for gas switches'),
            secondary: const Icon(Icons.swap_horiz),
            value: settings.defaultShowGasSwitchMarkers,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowGasSwitchMarkers(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(context, 'Default Visible Metrics'),
          SwitchListTile(
            title: const Text('Temperature'),
            dense: true,
            value: settings.defaultShowTemperature,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowTemperature(value);
            },
          ),
          SwitchListTile(
            title: const Text('Pressure'),
            dense: true,
            value: settings.defaultShowPressure,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPressure(value);
            },
          ),
          SwitchListTile(
            title: const Text('Heart Rate'),
            dense: true,
            value: settings.defaultShowHeartRate,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowHeartRate(value);
            },
          ),
          SwitchListTile(
            title: const Text('SAC Rate'),
            dense: true,
            value: settings.defaultShowSac,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowSac(value);
            },
          ),
          SwitchListTile(
            title: const Text('Events'),
            dense: true,
            value: settings.defaultShowEvents,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowEvents(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(context, 'Decompression Metrics'),
          SwitchListTile(
            title: const Text('Ceiling'),
            dense: true,
            value: settings.showCeilingOnProfile,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowCeilingOnProfile(value);
            },
          ),
          SwitchListTile(
            title: const Text('Ascent Rate Colors'),
            dense: true,
            value: settings.showAscentRateColors,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowAscentRateColors(value);
            },
          ),
          SwitchListTile(
            title: const Text('NDL'),
            dense: true,
            value: settings.showNdlOnProfile,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowNdlOnProfile(value);
            },
          ),
          SwitchListTile(
            title: const Text('TTS (Time to Surface)'),
            dense: true,
            value: settings.defaultShowTts,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowTts(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(context, 'Gas Analysis Metrics'),
          SwitchListTile(
            title: const Text('ppO2'),
            dense: true,
            value: settings.defaultShowPpO2,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpO2(value);
            },
          ),
          SwitchListTile(
            title: const Text('ppN2'),
            dense: true,
            value: settings.defaultShowPpN2,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpN2(value);
            },
          ),
          SwitchListTile(
            title: const Text('ppHe'),
            dense: true,
            value: settings.defaultShowPpHe,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowPpHe(value);
            },
          ),
          SwitchListTile(
            title: const Text('Gas Density'),
            dense: true,
            value: settings.defaultShowGasDensity,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowGasDensity(value);
            },
          ),
          const SizedBox(height: 8),
          _buildSubsectionHeader(context, 'Gradient Factor Metrics'),
          SwitchListTile(
            title: const Text('GF%'),
            dense: true,
            value: settings.defaultShowGf,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDefaultShowGf(value);
            },
          ),
          SwitchListTile(
            title: const Text('Surface GF'),
            dense: true,
            value: settings.defaultShowSurfaceGf,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultShowSurfaceGf(value);
            },
          ),
          SwitchListTile(
            title: const Text('Mean Depth'),
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
        return ListTile(
          leading: Icon(_getThemeModeIcon(mode)),
          title: Text(_getThemeModeName(mode)),
          trailing: isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            ref.read(settingsProvider.notifier).setThemeMode(mode);
          },
        );
      }).toList(),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
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
