import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../providers/settings_providers.dart';

/// Summary widget displayed when no settings section is selected.
/// Shows a quick overview of current settings.
class SettingsSummaryWidget extends ConsumerWidget {
  const SettingsSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentDiverAsync = ref.watch(currentDiverProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.settings,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Select a category to configure',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Current Configuration Summary
          Text(
            'Current Configuration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Quick stats cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickStatCard(
                context,
                icon: Icons.person,
                label: 'Active Diver',
                value: currentDiverAsync.when(
                  data: (diver) => diver?.name ?? 'Not set',
                  loading: () => 'Loading...',
                  error: (_, _) => 'Error',
                ),
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.straighten,
                label: 'Units',
                value: settings.unitPreset.name.toUpperCase(),
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.timeline,
                label: 'Gradient Factors',
                value: 'GF ${settings.gfLow}/${settings.gfHigh}',
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.palette,
                label: 'Theme',
                value: _getThemeModeName(settings.themeMode),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Unit details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Unit Preferences',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildUnitRow(context, 'Depth', settings.depthUnit.symbol),
                  _buildUnitRow(
                    context,
                    'Temperature',
                    '°${settings.temperatureUnit.symbol}',
                  ),
                  _buildUnitRow(context, 'Pressure', settings.pressureUnit.symbol),
                  _buildUnitRow(context, 'Volume', settings.volumeUnit.symbol),
                  _buildUnitRow(context, 'Weight', settings.weightUnit.symbol),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tip card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Use the Data section to backup your dive logs regularly.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}
