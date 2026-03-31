import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_preset_picker.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_summary_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/pages/debug_log_viewer_page.dart';

/// Main settings page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with section list on left,
/// selected section content on right.
/// On narrower screens (<800px): Shows section list with navigation.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'settings',
        masterBuilder: (context, onItemSelected, selectedId) =>
            SettingsListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, sectionId) =>
            _buildSectionContent(context, ref, sectionId),
        summaryBuilder: (context) => const SettingsSummaryWidget(),
      );
    }

    // Mobile: Check for selected section via query param
    String? selectedSection;
    try {
      selectedSection = GoRouterState.of(
        context,
      ).uri.queryParameters['selected'];
    } catch (_) {
      // GoRouter not available (e.g., in tests)
    }

    if (selectedSection != null) {
      // Show section detail page
      return _SettingsSectionDetailPage(sectionId: selectedSection, ref: ref);
    }

    // Mobile: Show section list
    return const SettingsMobileContent();
  }

  /// Builds the appropriate section content based on section ID.
  Widget _buildSectionContent(
    BuildContext context,
    WidgetRef ref,
    String sectionId,
  ) {
    switch (sectionId) {
      case 'profile':
        return const DiverProfileHubPage();
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'decompression':
        return _DecompressionSectionContent(ref: ref);
      case 'appearance':
        return const _AppearanceSectionContent();
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const _ManageSectionContent();
      case 'data':
        return _DataSectionContent(ref: ref);
      case 'dataSources':
        return const _DataSourcesSectionContent();
      case 'about':
        return const _AboutSectionContent();
      case 'debug':
        return const DebugLogViewerPage();
      default:
        return Center(child: Text('Unknown section: $sectionId'));
    }
  }
}

/// Mobile content showing section list for navigation.
class SettingsMobileContent extends ConsumerWidget {
  const SettingsMobileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugEnabled = ref.watch(debugModeNotifierProvider);
    final sections = settingsSections
        .where((s) => s.id != 'dataSources' || Platform.isIOS)
        .toList();

    // Insert Debug section just before About when debug mode is enabled
    if (debugEnabled) {
      final aboutIndex = sections.indexWhere((s) => s.id == 'about');
      final insertIndex = aboutIndex >= 0 ? aboutIndex : sections.length;
      sections.insert(
        insertIndex,
        const SettingsSection(
          id: 'debug',
          icon: Icons.bug_report_outlined,
          title: 'Debug',
          subtitle: 'Logs & diagnostics',
          color: Colors.grey,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_appBar_title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = sections[index];
          return _MobileSettingsTile(section: section);
        },
      ),
    );
  }
}

/// Mobile detail page for settings sections accessed via query params.
class _SettingsSectionDetailPage extends ConsumerWidget {
  final String sectionId;
  final WidgetRef ref;

  const _SettingsSectionDetailPage({
    required this.sectionId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the section title (use localized string)
    final title = _getLocalizedSectionTitle(context, sectionId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.settings_backToSettings_tooltip,
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: _buildContent(context, ref),
    );
  }

  String _getLocalizedSectionTitle(BuildContext context, String id) {
    return switch (id) {
      'profile' => context.l10n.settings_section_diverProfile_title,
      'units' => context.l10n.settings_section_units_title,
      'decompression' => context.l10n.settings_section_decompression_title,
      'appearance' => context.l10n.settings_section_appearance_title,
      'notifications' => context.l10n.settings_section_notifications_title,
      'manage' => context.l10n.settings_section_manage_title,
      'data' => context.l10n.settings_section_data_title,
      'about' => context.l10n.settings_section_about_title,
      'dataSources' => context.l10n.settings_section_dataSources_title,
      'debug' => 'Debug',
      _ => context.l10n.settings_appBar_title,
    };
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (sectionId) {
      case 'profile':
        return const DiverProfileHubPage();
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'decompression':
        return _DecompressionSectionContent(ref: ref);
      case 'appearance':
        return const _AppearanceSectionContent();
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const _ManageSectionContent();
      case 'data':
        return _DataSectionContent(ref: ref);
      case 'dataSources':
        return const _DataSourcesSectionContent();
      case 'about':
        return const _AboutSectionContent();
      case 'debug':
        return const DebugLogViewerPage();
      default:
        return Center(child: Text('Unknown section: $sectionId'));
    }
  }
}

class _MobileSettingsTile extends StatelessWidget {
  final SettingsSection section;

  const _MobileSettingsTile({required this.section});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = section.color ?? colorScheme.primary;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(section.icon, color: color, size: 24),
      ),
      title: Text(
        _getLocalizedTitle(context, section),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getLocalizedSubtitle(context, section),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _navigateToSection(context, section.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _getLocalizedTitle(BuildContext context, SettingsSection section) {
    return switch (section.id) {
      'profile' => context.l10n.settings_section_diverProfile_title,
      'units' => context.l10n.settings_section_units_title,
      'decompression' => context.l10n.settings_section_decompression_title,
      'appearance' => context.l10n.settings_section_appearance_title,
      'notifications' => context.l10n.settings_section_notifications_title,
      'manage' => context.l10n.settings_section_manage_title,
      'data' => context.l10n.settings_section_data_title,
      'about' => context.l10n.settings_section_about_title,
      'dataSources' => context.l10n.settings_section_dataSources_title,
      _ => section.title,
    };
  }

  String _getLocalizedSubtitle(BuildContext context, SettingsSection section) {
    return switch (section.id) {
      'profile' => context.l10n.settings_section_diverProfile_subtitle,
      'units' => context.l10n.settings_section_units_subtitle,
      'decompression' => context.l10n.settings_section_decompression_subtitle,
      'appearance' => context.l10n.settings_section_appearance_subtitle,
      'notifications' => context.l10n.settings_section_notifications_subtitle,
      'manage' => context.l10n.settings_section_manage_subtitle,
      'data' => context.l10n.settings_section_data_subtitle,
      'about' => context.l10n.settings_section_about_subtitle,
      'dataSources' => context.l10n.settings_section_dataSources_subtitle,
      _ => section.subtitle,
    };
  }

  void _navigateToSection(BuildContext context, String sectionId) {
    // Navigate to the appropriate page based on section
    switch (sectionId) {
      case 'profile':
        context.push('/settings/diver-profile');
        break;
      case 'appearance':
        context.push('/settings/appearance');
        break;
      default:
        // For sections that don't have dedicated pages,
        // show them in a detail page using query params
        final state = GoRouterState.of(context);
        final currentPath = state.uri.path;
        context.go('$currentPath?selected=$sectionId');
    }
  }
}

// ============================================================================
// SECTION CONTENT WIDGETS
// ============================================================================

/// Units section content
class _UnitsSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _UnitsSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_units_header_unitSystem,
          ),
          const SizedBox(height: 8),
          _buildUnitPresetSelector(context, ref, settings),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_units_header_individualUnits,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_depth,
                  value: settings.depthUnit.symbol,
                  onTap: () =>
                      _showDepthUnitPicker(context, ref, settings.depthUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_temperature,
                  value: '°${settings.temperatureUnit.symbol}',
                  onTap: () => _showTempUnitPicker(
                    context,
                    ref,
                    settings.temperatureUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_pressure,
                  value: settings.pressureUnit.symbol,
                  onTap: () => _showPressureUnitPicker(
                    context,
                    ref,
                    settings.pressureUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_volume,
                  value: settings.volumeUnit.symbol,
                  onTap: () =>
                      _showVolumeUnitPicker(context, ref, settings.volumeUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_weight,
                  value: settings.weightUnit.symbol,
                  onTap: () =>
                      _showWeightUnitPicker(context, ref, settings.weightUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_sacRate,
                  value: settings.sacUnit == SacUnit.litersPerMin
                      ? '${settings.volumeUnit.symbol}/min'
                      : '${settings.pressureUnit.symbol}/min',
                  onTap: () =>
                      _showSacUnitPicker(context, ref, settings.sacUnit),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_units_header_timeDateFormat,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_timeFormat,
                  value: settings.timeFormat.displayName,
                  onTap: () =>
                      _showTimeFormatPicker(context, ref, settings.timeFormat),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_dateFormat,
                  value: settings.dateFormat.example,
                  onTap: () =>
                      _showDateFormatPicker(context, ref, settings.dateFormat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitPresetSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settings_units_quickSelect,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<UnitPreset>(
              segments: [
                ButtonSegment(
                  value: UnitPreset.metric,
                  label: Text(context.l10n.settings_units_metric),
                ),
                ButtonSegment(
                  value: UnitPreset.imperial,
                  label: Text(context.l10n.settings_units_imperial),
                ),
                ButtonSegment(
                  value: UnitPreset.custom,
                  label: Text(context.l10n.settings_units_custom),
                ),
              ],
              selected: {settings.unitPreset},
              onSelectionChanged: (selected) {
                final preset = selected.first;
                switch (preset) {
                  case UnitPreset.metric:
                    ref.read(settingsProvider.notifier).setMetric();
                    break;
                  case UnitPreset.imperial:
                    ref.read(settingsProvider.notifier).setImperial();
                    break;
                  case UnitPreset.custom:
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTile(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showDepthUnitPicker(
    BuildContext context,
    WidgetRef ref,
    DepthUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_depthUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DepthUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == DepthUnit.meters
                    ? context.l10n.settings_units_depth_meters
                    : context.l10n.settings_units_depth_feet,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setDepthUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTempUnitPicker(
    BuildContext context,
    WidgetRef ref,
    TemperatureUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_temperatureUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TemperatureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == TemperatureUnit.celsius
                    ? context.l10n.settings_units_temperature_celsius
                    : context.l10n.settings_units_temperature_fahrenheit,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setTemperatureUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPressureUnitPicker(
    BuildContext context,
    WidgetRef ref,
    PressureUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_pressureUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PressureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == PressureUnit.bar
                    ? context.l10n.settings_units_pressure_bar
                    : context.l10n.settings_units_pressure_psi,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setPressureUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showVolumeUnitPicker(
    BuildContext context,
    WidgetRef ref,
    VolumeUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_volumeUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VolumeUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == VolumeUnit.liters
                    ? context.l10n.settings_units_volume_liters
                    : context.l10n.settings_units_volume_cubicFeet,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setVolumeUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showWeightUnitPicker(
    BuildContext context,
    WidgetRef ref,
    WeightUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_weightUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WeightUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == WeightUnit.kilograms
                    ? context.l10n.settings_units_weight_kilograms
                    : context.l10n.settings_units_weight_pounds,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setWeightUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSacUnitPicker(
    BuildContext context,
    WidgetRef ref,
    SacUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_sacRateUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.l10n.settings_units_sac_volumePerMinute),
              subtitle: Text(
                context.l10n.settings_units_sac_volumePerMinute_subtitle,
              ),
              trailing: currentUnit == SacUnit.litersPerMin
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setSacUnit(SacUnit.litersPerMin);
                Navigator.of(dialogContext).pop();
              },
            ),
            ListTile(
              title: Text(context.l10n.settings_units_sac_pressurePerMinute),
              subtitle: Text(
                context.l10n.settings_units_sac_pressurePerMinute_subtitle,
              ),
              trailing: currentUnit == SacUnit.pressurePerMin
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setSacUnit(SacUnit.pressurePerMin);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeFormatPicker(
    BuildContext context,
    WidgetRef ref,
    TimeFormat currentFormat,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_timeFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TimeFormat.values.map((format) {
            final isSelected = format == currentFormat;
            return ListTile(
              title: Text(format.displayName),
              subtitle: Text(format.example),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setTimeFormat(format);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDateFormatPicker(
    BuildContext context,
    WidgetRef ref,
    DateFormatPreference currentFormat,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_dateFormat),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DateFormatPreference.values.map((format) {
              final isSelected = format == currentFormat;
              return ListTile(
                title: Text(format.displayName),
                subtitle: Text(format.example),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setDateFormat(format);
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Decompression section content
class _DecompressionSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _DecompressionSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_decompression_header_gradientFactors,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: Text(context.l10n.settings_decompression_currentSettings),
              subtitle: Text(
                context.l10n.settings_decompression_gfValue(
                  settings.gfLow,
                  settings.gfHigh,
                ),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showGradientFactorPicker(context, ref, settings),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            context.l10n.settings_decompression_aboutTitle,
            context.l10n.settings_decompression_aboutContent,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Data Source Preferences'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'When set to Dive Computer, the app uses data reported by the '
              'dive computer when available. Falls back to calculated values '
              'when computer data is not present.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildSourceDropdownTile(
                  context,
                  title: 'NDL Source',
                  value: settings.defaultNdlSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultNdlSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: 'Ceiling Source',
                  value: settings.defaultCeilingSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultCeilingSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: 'TTS Source',
                  value: settings.defaultTtsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultTtsSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: 'CNS Source',
                  value: settings.defaultCnsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultCnsSource(source),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_decompression_header_narcosis,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.air),
                  title: Text(context.l10n.settings_decompression_o2Narcotic),
                  subtitle: Text(
                    context.l10n.settings_decompression_o2Narcotic_subtitle,
                  ),
                  value: settings.o2Narcotic,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setO2Narcotic(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom),
                  title: Text(context.l10n.settings_decompression_endLimit),
                  subtitle: Text(
                    context.l10n.settings_decompression_endLimit_subtitle,
                  ),
                  trailing: Text(
                    UnitFormatter(
                      settings,
                    ).formatDepth(settings.endLimit, decimals: 0),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _showEndLimitDialog(context, ref, settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceDropdownTile(
    BuildContext context, {
    required String title,
    required MetricDataSource value,
    required ValueChanged<MetricDataSource> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      dense: true,
      trailing: DropdownButton<MetricDataSource>(
        value: value,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(
            value: MetricDataSource.calculated,
            child: Text('Calculated'),
          ),
          DropdownMenuItem(
            value: MetricDataSource.computer,
            child: Text('Dive Computer'),
          ),
        ],
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }

  void _showGradientFactorPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _GradientFactorDialog(
        initialGfLow: settings.gfLow,
        initialGfHigh: settings.gfHigh,
        onSave: (low, high) {
          ref.read(settingsProvider.notifier).setGradientFactors(low, high);
        },
      ),
    );
  }

  void _showEndLimitDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final units = UnitFormatter(settings);
    var currentValue = settings.endLimit;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.l10n.settings_decompression_endLimit_dialog_title,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                units.formatDepth(currentValue, decimals: 0),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Slider(
                value: currentValue,
                min: 20.0,
                max: 50.0,
                divisions: 30,
                label: units.formatDepth(currentValue, decimals: 0),
                onChanged: (value) {
                  setDialogState(() => currentValue = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setEndLimit(currentValue);
                Navigator.pop(dialogContext);
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Appearance section content
class _AppearanceSectionContent extends ConsumerStatefulWidget {
  const _AppearanceSectionContent();

  @override
  ConsumerState<_AppearanceSectionContent> createState() =>
      _AppearanceSectionContentState();
}

class _AppearanceSectionContentState
    extends ConsumerState<_AppearanceSectionContent> {
  bool _showLanguageList = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (_showLanguageList) {
      return _buildLanguageSubPage(context, settings);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_theme,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_themes_current),
            subtitle: Text(_resolveCurrentThemeName(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/themes'),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_mode,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: ThemeMode.values.map((mode) {
                final isSelected = mode == settings.themeMode;
                return ListTile(
                  leading: Icon(_getThemeModeIcon(mode)),
                  title: Text(_getThemeModeName(context, mode)),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setThemeMode(mode);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveLog,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text(
                    context.l10n.settings_appearance_cardColorAttribute,
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
                if (settings.cardColorAttribute != CardColorAttribute.none)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Dive List View'),
                  subtitle: const Text('Default layout for the dive list'),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.diveListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setDiveListViewMode(value);
                        ref.read(diveListViewModeProvider.notifier).state =
                            value;
                      }
                    },
                    items: ListViewMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    context.l10n.settings_appearance_mapBackgroundDiveCards,
                  ),
                  subtitle: Text(
                    context
                        .l10n
                        .settings_appearance_mapBackgroundDiveCards_subtitle,
                  ),
                  secondary: const Icon(Icons.map),
                  value: settings.showMapBackgroundOnDiveCards,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setShowMapBackgroundOnDiveCards(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Dive Sites'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Site List View'),
                  subtitle: const Text('Default layout for the site list'),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.siteListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setSiteListViewMode(value);
                        ref.read(siteListViewModeProvider.notifier).state =
                            value;
                      }
                    },
                    items: ListViewMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Trips'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Trip List View'),
                  subtitle: const Text('Default layout for the trip list'),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.tripListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setTripListViewMode(value);
                        ref.read(tripListViewModeProvider.notifier).state =
                            value;
                      }
                    },
                    items: ListViewMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Equipment'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Equipment List View'),
                  subtitle: const Text('Default layout for the equipment list'),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.equipmentListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setEquipmentListViewMode(value);
                        ref.read(equipmentListViewModeProvider.notifier).state =
                            value;
                      }
                    },
                    items: [ListViewMode.detailed, ListViewMode.dense].map((
                      mode,
                    ) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Buddies'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Buddy List View'),
                  subtitle: const Text('Default layout for the buddy list'),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.buddyListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setBuddyListViewMode(value);
                        ref.read(buddyListViewModeProvider.notifier).state =
                            value;
                      }
                    },
                    items: [ListViewMode.detailed, ListViewMode.dense].map((
                      mode,
                    ) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Dive Centers'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.view_list),
                  title: const Text('Dive Center List View'),
                  subtitle: const Text(
                    'Default layout for the dive center list',
                  ),
                  trailing: DropdownButton<ListViewMode>(
                    value: settings.diveCenterListViewMode,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setDiveCenterListViewMode(value);
                        ref
                                .read(diveCenterListViewModeProvider.notifier)
                                .state =
                            value;
                      }
                    },
                    items: ListViewMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getViewModeDisplayName(mode)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveProfile,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                // Right Y-Axis Metric Selector
                ListTile(
                  leading: const Icon(Icons.show_chart),
                  title: Text(
                    context.l10n.settings_appearance_rightYAxisMetric,
                  ),
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
                const Divider(height: 1),
                // Markers section
                SwitchListTile(
                  title: Text(context.l10n.settings_appearance_maxDepthMarker),
                  subtitle: Text(
                    context.l10n.settings_appearance_maxDepthMarker_subtitle,
                  ),
                  secondary: const Icon(Icons.vertical_align_bottom),
                  value: settings.showMaxDepthMarker,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setShowMaxDepthMarker(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    context.l10n.settings_appearance_pressureThresholdMarkers,
                  ),
                  subtitle: Text(
                    context
                        .l10n
                        .settings_appearance_pressureThresholdMarkers_subtitle,
                  ),
                  secondary: Icon(MdiIcons.divingScubaTank),
                  value: settings.showPressureThresholdMarkers,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setShowPressureThresholdMarkers(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    context.l10n.settings_appearance_gasSwitchMarkers,
                  ),
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: Text(
                    context
                        .l10n
                        .settings_appearance_subsection_defaultVisibleMetrics,
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveDetails,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.reorder),
              title: Text(
                context
                    .l10n
                    .settings_appearance_diveDetails_sectionOrderVisibility,
              ),
              subtitle: Text(
                context
                    .l10n
                    .settings_appearance_diveDetails_sectionOrderVisibility_subtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/dive-detail-sections'),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveSites,
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(
                context.l10n.settings_appearance_mapBackgroundSiteCards,
              ),
              subtitle: Text(
                context
                    .l10n
                    .settings_appearance_mapBackgroundSiteCards_subtitle,
              ),
              secondary: const Icon(Icons.map),
              value: settings.showMapBackgroundOnSiteCards,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setShowMapBackgroundOnSiteCards(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_language,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(context.l10n.settings_appearance_header_language),
              subtitle: Text(
                LanguageSettingsPage.getDisplayName(settings.locale),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _showLanguageList = true;
                });
              },
            ),
          ),
        ],
      ),
    );
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

  String _getViewModeDisplayName(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
    };
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

  String _resolveCurrentThemeName(BuildContext context) {
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

  Widget _buildLanguageSubPage(BuildContext context, AppSettings settings) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  setState(() {
                    _showLanguageList = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.settings_language_appBar_title,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: LanguageSettingsPage.supportedLocales.map((option) {
                final isSelected = option.code == settings.locale;
                return Semantics(
                  selected: isSelected,
                  child: ListTile(
                    leading: option.code == 'system'
                        ? const Icon(Icons.phone_android)
                        : null,
                    title: Text(
                      option.code == 'system'
                          ? context.l10n.settings_language_systemDefault
                          : option.nativeName,
                    ),
                    subtitle: option.englishName.isNotEmpty
                        ? Text(option.englishName)
                        : null,
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: theme.colorScheme.primary,
                            semanticLabel:
                                context.l10n.settings_language_selected,
                          )
                        : null,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setLocale(option.code);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notifications section content
class _NotificationsSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _NotificationsSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final permissionAsync = ref.watch(notificationPermissionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_notifications_header_serviceReminders,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    context.l10n.settings_notifications_enableServiceReminders,
                  ),
                  subtitle: Text(
                    context
                        .l10n
                        .settings_notifications_enableServiceReminders_subtitle,
                  ),
                  secondary: const Icon(Icons.notifications_active),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Request permission when enabling
                      final granted = await NotificationService.instance
                          .requestPermission();
                      if (!granted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context
                                  .l10n
                                  .settings_notifications_permissionRequired,
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .setNotificationsEnabled(value);
                  },
                ),
                if (settings.notificationsEnabled) ...[
                  const Divider(height: 1),
                  permissionAsync.when(
                    data: (granted) {
                      if (!granted) {
                        return ListTile(
                          leading: const Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          title: Text(
                            context.l10n.settings_notifications_disabled_title,
                          ),
                          subtitle: Text(
                            context
                                .l10n
                                .settings_notifications_disabled_subtitle,
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await NotificationService.instance
                                  .requestPermission();
                              ref.invalidate(notificationPermissionProvider);
                            },
                            child: Text(
                              context
                                  .l10n
                                  .settings_notifications_disabled_enableButton,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          if (settings.notificationsEnabled) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              context,
              context.l10n.settings_notifications_header_reminderSchedule,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settings_notifications_remindBeforeDue,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [7, 14, 30].map((days) {
                        final isSelected = settings.serviceReminderDays
                            .contains(days);
                        return FilterChip(
                          label: Text(
                            context.l10n.settings_notifications_days(days),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(settingsProvider.notifier)
                                .toggleReminderDay(days);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(context.l10n.settings_notifications_reminderTime),
                subtitle: Text(
                  '${settings.reminderTime.hour.toString().padLeft(2, '0')}:${settings.reminderTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTimePicker(context, ref, settings),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              context.l10n.settings_notifications_howItWorks_title,
              context.l10n.settings_notifications_howItWorks_content,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (time != null) {
      ref.read(settingsProvider.notifier).setReminderTime(time);
    }
  }
}

/// Manage section content
class _ManageSectionContent extends StatelessWidget {
  const _ManageSectionContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_manage_header_manageData,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.label),
                  title: Text(context.l10n.settings_manage_diveTypes),
                  subtitle: Text(
                    context.l10n.settings_manage_diveTypes_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-types'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(MdiIcons.divingScubaTank),
                  title: Text(context.l10n.settings_manage_tankPresets),
                  subtitle: Text(
                    context.l10n.settings_manage_tankPresets_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tank-presets'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(context.l10n.settings_manage_species),
                  subtitle: Text(context.l10n.settings_manage_species_subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/species'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sell),
                  title: Text(context.l10n.settings_manage_tags),
                  subtitle: Text(context.l10n.settings_manage_tags_subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tags'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data section content
class _DataSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _DataSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageState = ref.watch(storageConfigNotifierProvider);
    final isCustomFolder =
        storageState.config.mode == StorageLocationMode.customFolder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_data_header_backupSync,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(context.l10n.settings_data_backup),
                  subtitle: _buildBackupSubtitle(context, ref),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(
            context,
            context.l10n.settings_data_header_storage,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(context.l10n.settings_data_databaseStorage),
                  subtitle: Text(
                    isCustomFolder
                        ? context.l10n.settings_data_customFolder
                        : context.l10n.settings_data_appDefaultLocation,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/storage'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: Text(context.l10n.settings_data_offlineMaps),
                  subtitle: Text(
                    context.l10n.settings_data_offlineMaps_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/offline-maps'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Data Tools'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Fix Dive Times'),
                  subtitle: const Text('Adjust times for imported dives'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/fix-dive-times'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBackupSubtitle(BuildContext context, WidgetRef ref) {
    final lastBackup = ref.watch(lastBackupTimeProvider);
    if (lastBackup == null) {
      return Text(context.l10n.settings_data_backup_subtitle);
    }
    final diff = DateTime.now().difference(lastBackup);
    final String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = context.l10n.backup_time_justNow;
    } else if (diff.inHours < 1) {
      timeAgo = context.l10n.backup_time_minutesAgo(diff.inMinutes);
    } else if (diff.inDays < 1) {
      timeAgo = context.l10n.backup_time_hoursAgo(diff.inHours);
    } else {
      timeAgo = context.l10n.backup_time_daysAgo(diff.inDays);
    }
    return Text(context.l10n.backup_status_lastBackup(timeAgo));
  }
}

/// Data Sources section - surfaces HealthKit integration for App Store compliance.
///
/// Explicitly identifies Apple HealthKit usage per App Store Guideline 2.5.1:
/// - Shows "Apple HealthKit" branding prominently
/// - Lists specific HealthKit data types read (Workouts, Heart Rate)
/// - Displays current HealthKit permission status
/// - Provides clear privacy disclosure
class _DataSourcesSectionContent extends ConsumerWidget {
  const _DataSourcesSectionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final permissionsAsync = ref.watch(healthImportHasPermissionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_dataSources_header,
          ),
          const SizedBox(height: 8),
          // HealthKit branding card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context
                                  .l10n
                                  .settings_dataSources_appleHealth_title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              context
                                  .l10n
                                  .settings_dataSources_appleHealth_subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Permission status
                  permissionsAsync.when(
                    data: (hasPerms) =>
                        _buildPermissionStatus(context, hasPerms: hasPerms),
                    loading: () =>
                        _buildPermissionStatus(context, isLoading: true),
                    error: (_, _) =>
                        _buildPermissionStatus(context, hasPerms: false),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.settings_dataSources_appleHealth_description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Data types card
          _buildSectionHeader(
            context,
            context.l10n.settings_dataSources_appleHealth_dataTypesHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.scuba_diving),
                  title: Text(
                    context
                        .l10n
                        .settings_dataSources_appleHealth_dataTypeWorkouts,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(
                    context
                        .l10n
                        .settings_dataSources_appleHealth_dataTypeHeartRate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Import action card
          Card(
            child: ListTile(
              leading: const Icon(Icons.watch),
              title: Text(
                context.l10n.settings_dataSources_appleHealth_importAction,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/wearable-import'),
            ),
          ),
          const SizedBox(height: 16),
          // Privacy and attribution
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.settings_dataSources_appleHealth_privacy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.settings_dataSources_appleHealth_poweredBy,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatus(
    BuildContext context, {
    bool hasPerms = false,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.settings_dataSources_appleHealth_permissionChecking,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          hasPerms ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: hasPerms ? Colors.green : colorScheme.error,
        ),
        const SizedBox(width: 8),
        Text(
          hasPerms
              ? context.l10n.settings_dataSources_appleHealth_permissionGranted
              : context
                    .l10n
                    .settings_dataSources_appleHealth_permissionNotGranted,
          style: theme.textTheme.bodySmall?.copyWith(
            color: hasPerms ? Colors.green : colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// About section content with optional auto-update controls.
///
/// When [UpdateChannelConfig.isAutoUpdateEnabled] is true (non-store builds),
/// an Updates card is shown with check-for-update, auto-update toggle,
/// and last-checked timestamp.
class _AboutSectionContent extends ConsumerStatefulWidget {
  const _AboutSectionContent();

  @override
  ConsumerState<_AboutSectionContent> createState() =>
      _AboutSectionContentState();
}

class _AboutSectionContentState extends ConsumerState<_AboutSectionContent> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final versionString = packageInfoAsync.when(
      data: (info) {
        final version = info.version.endsWith('.${info.buildNumber}')
            ? info.version
            : '${info.version}.${info.buildNumber}';
        return context.l10n.settings_about_version(version);
      },
      loading: () => '',
      error: (_, _) => '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, context.l10n.settings_about_header),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.l10n.settings_about_aboutSubmersion),
                  onTap: () => _showAboutDialog(context, versionString),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(context.l10n.settings_about_openSourceLicenses),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: context.l10n.settings_about_appName,
                      applicationVersion: versionString,
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: Text(context.l10n.settings_about_reportIssue),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.settings_about_reportIssue_snackbar,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Auto-update section (only for non-store builds)
          if (UpdateChannelConfig.isAutoUpdateEnabled) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Updates'),
            const SizedBox(height: 8),
            _buildUpdatesCard(context),
          ],
          const SizedBox(height: 24),
          // App info card
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.settings_about_appName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    _tapCount++;
                    if (_tapCount >= 5) {
                      _tapCount = 0;
                      ref.read(debugModeNotifierProvider.notifier).enable();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debug mode enabled'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    versionString,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesCard(BuildContext context) {
    final updateStatus = ref.watch(updateStatusProvider);
    final prefs = ref.watch(updatePreferencesProvider);

    final statusText = switch (updateStatus) {
      UpToDate() => 'Up to date',
      Checking() => 'Checking...',
      UpdateAvailable(:final version) => 'Version $version available',
      Downloading(:final progress) =>
        'Downloading... ${(progress * 100).toInt()}%',
      ReadyToInstall(:final version) => 'Version $version ready to install',
      UpdateError(:final message) => 'Error: $message',
    };

    final lastCheck = prefs.lastCheckTime;
    final lastCheckText = lastCheck != null
        ? '${lastCheck.month}/${lastCheck.day}/${lastCheck.year} '
              '${lastCheck.hour.toString().padLeft(2, '0')}:'
              '${lastCheck.minute.toString().padLeft(2, '0')}'
        : 'Never';

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Check for Updates'),
            subtitle: Text(statusText),
            onTap: updateStatus is Checking
                ? null
                : () => ref
                      .read(updateStatusProvider.notifier)
                      .checkForUpdateInteractively(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.auto_mode),
            title: const Text('Automatic updates'),
            subtitle: const Text('Check for updates periodically'),
            value: prefs.autoUpdateEnabled,
            onChanged: (value) async {
              await prefs.setAutoUpdateEnabled(value);
              ref.invalidate(updatePreferencesProvider);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Last checked'),
            subtitle: Text(lastCheckText),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, String versionString) {
    showAboutDialog(
      context: context,
      applicationName: context.l10n.settings_about_appName,
      applicationVersion: versionString,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icon/icon.png', width: 64, height: 64),
      ),
      children: [Text(context.l10n.settings_about_description)],
    );
  }
}

// ============================================================================
// HELPER WIDGETS & FUNCTIONS
// ============================================================================

Widget _buildSectionHeader(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    ),
  );
}

Widget _buildInfoCard(BuildContext context, String title, String content) {
  return Card(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
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

// ============================================================================
// GRADIENT FACTOR DIALOG
// ============================================================================

/// Gradient Factor preset configurations
enum GfPreset {
  high(50, 75, 'High', 'Most conservative, longer deco stops'),
  medium(50, 85, 'Medium', 'Balanced approach'),
  low(50, 95, 'Low', 'Least conservative, shorter deco'),
  custom(0, 0, 'Custom', 'Set your own values');

  final int gfLow;
  final int gfHigh;
  final String name;
  final String description;

  const GfPreset(this.gfLow, this.gfHigh, this.name, this.description);

  bool matches(int low, int high) {
    if (this == GfPreset.custom) return false;
    return gfLow == low && gfHigh == high;
  }

  static GfPreset fromValues(int low, int high) {
    for (final preset in GfPreset.values) {
      if (preset != GfPreset.custom && preset.matches(low, high)) {
        return preset;
      }
    }
    return GfPreset.custom;
  }
}

class _GradientFactorDialog extends StatefulWidget {
  final int initialGfLow;
  final int initialGfHigh;
  final void Function(int low, int high) onSave;

  const _GradientFactorDialog({
    required this.initialGfLow,
    required this.initialGfHigh,
    required this.onSave,
  });

  @override
  State<_GradientFactorDialog> createState() => _GradientFactorDialogState();
}

class _GradientFactorDialogState extends State<_GradientFactorDialog> {
  late int _gfLow;
  late int _gfHigh;
  late GfPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _gfLow = widget.initialGfLow;
    _gfHigh = widget.initialGfHigh;
    _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
  }

  void _selectPreset(GfPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != GfPreset.custom) {
        _gfLow = preset.gfLow;
        _gfHigh = preset.gfHigh;
      }
    });
  }

  void _updateGfLow(int value) {
    setState(() {
      _gfLow = value;
      if (_gfHigh < _gfLow) _gfHigh = _gfLow;
      _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
    });
  }

  void _updateGfHigh(int value) {
    setState(() {
      _gfHigh = value;
      if (_gfLow > _gfHigh) _gfLow = _gfHigh;
      _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
    });
  }

  String _getPresetName(BuildContext context, GfPreset preset) {
    switch (preset) {
      case GfPreset.high:
        return context.l10n.settings_gfPreset_high_name;
      case GfPreset.medium:
        return context.l10n.settings_gfPreset_medium_name;
      case GfPreset.low:
        return context.l10n.settings_gfPreset_low_name;
      case GfPreset.custom:
        return context.l10n.settings_gfPreset_custom_name;
    }
  }

  String _getPresetDescription(BuildContext context, GfPreset preset) {
    switch (preset) {
      case GfPreset.high:
        return context.l10n.settings_gfPreset_high_description;
      case GfPreset.medium:
        return context.l10n.settings_gfPreset_medium_description;
      case GfPreset.low:
        return context.l10n.settings_gfPreset_low_description;
      case GfPreset.custom:
        return context.l10n.settings_gfPreset_custom_description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(context.l10n.settings_decompression_dialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.settings_decompression_dialog_info,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.settings_decompression_dialog_presets,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...GfPreset.values.where((p) => p != GfPreset.custom).map((preset) {
              final isSelected = _selectedPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  label: context.l10n.settings_decompression_preset_selectLabel(
                    _getPresetName(context, preset),
                  ),
                  child: InkWell(
                    onTap: () => _selectPreset(preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getPresetName(context, preset),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _getPresetDescription(context, preset),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${preset.gfLow}/${preset.gfHigh}',
                              style: textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  context.l10n.settings_decompression_dialog_customValues,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'GF $_gfLow/$_gfHigh',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    context.l10n.settings_decompression_dialog_gfLow,
                    style: textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _gfLow.toDouble(),
                    min: 15,
                    max: 100,
                    divisions: 85,
                    label: '$_gfLow',
                    onChanged: (value) => _updateGfLow(value.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$_gfLow',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    context.l10n.settings_decompression_dialog_gfHigh,
                    style: textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _gfHigh.toDouble(),
                    min: 15,
                    max: 100,
                    divisions: 85,
                    label: '$_gfHigh',
                    onChanged: (value) => _updateGfHigh(value.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$_gfHigh',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settings_decompression_dialog_conservatismHint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_gfLow, _gfHigh);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}
