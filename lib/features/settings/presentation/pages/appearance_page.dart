import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
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
