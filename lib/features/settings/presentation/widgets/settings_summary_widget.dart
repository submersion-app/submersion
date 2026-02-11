import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
                      context.l10n.settings_summary_title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      context.l10n.settings_summary_subtitle,
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
            context.l10n.settings_summary_currentConfiguration,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                label: context.l10n.settings_summary_activeDiver,
                value: currentDiverAsync.when(
                  data: (diver) =>
                      diver?.name ?? context.l10n.settings_summary_notSet,
                  loading: () => context.l10n.settings_summary_loading,
                  error: (_, _) => context.l10n.settings_summary_error,
                ),
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.straighten,
                label: context.l10n.settings_summary_units,
                value: settings.unitPreset.name.toUpperCase(),
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.timeline,
                label: context.l10n.settings_summary_gradientFactors,
                value: 'GF ${settings.gfLow}/${settings.gfHigh}',
              ),
              _buildQuickStatCard(
                context,
                icon: Icons.palette,
                label: context.l10n.settings_summary_theme,
                value: _getThemeModeName(context, settings.themeMode),
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
                        context.l10n.settings_summary_unitPreferences,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_depth,
                    settings.depthUnit.symbol,
                  ),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_temperature,
                    '°${settings.temperatureUnit.symbol}',
                  ),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_pressure,
                    settings.pressureUnit.symbol,
                  ),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_volume,
                    settings.volumeUnit.symbol,
                  ),
                  _buildUnitRow(
                    context,
                    context.l10n.settings_summary_weight,
                    settings.weightUnit.symbol,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tip card
          Card(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                      context.l10n.settings_summary_tip,
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
    return Semantics(
      label: '$label: $value',
      child: Card(
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitRow(BuildContext context, String label, String value) {
    return Semantics(
      label: '$label unit: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.l10n.settings_summary_theme_system;
      case ThemeMode.light:
        return context.l10n.settings_summary_theme_light;
      case ThemeMode.dark:
        return context.l10n.settings_summary_theme_dark;
    }
  }
}
