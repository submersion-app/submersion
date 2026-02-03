import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/import_progress_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_summary_widget.dart';

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
        return _ProfileSectionContent(ref: ref);
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'decompression':
        return _DecompressionSectionContent(ref: ref);
      case 'appearance':
        return _AppearanceSectionContent(ref: ref);
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const _ManageSectionContent();
      case 'data':
        return _DataSectionContent(ref: ref);
      case 'about':
        return const _AboutSectionContent();
      default:
        return Center(child: Text('Unknown section: $sectionId'));
    }
  }
}

/// Mobile content showing section list for navigation.
class SettingsMobileContent extends StatelessWidget {
  const SettingsMobileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: settingsSections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = settingsSections[index];
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
    // Find the section title
    final section = settingsSections
        .where((s) => s.id == sectionId)
        .firstOrNull;
    final title = section?.title ?? 'Settings';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (sectionId) {
      case 'profile':
        return _ProfileSectionContent(ref: ref);
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'decompression':
        return _DecompressionSectionContent(ref: ref);
      case 'appearance':
        return _AppearanceSectionContent(ref: ref);
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const _ManageSectionContent();
      case 'data':
        return _DataSectionContent(ref: ref);
      case 'about':
        return const _AboutSectionContent();
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
        section.title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        section.subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _navigateToSection(context, section.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToSection(BuildContext context, String sectionId) {
    // Navigate to the appropriate page based on section
    switch (sectionId) {
      case 'profile':
        context.push('/divers');
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

/// Profile section content
class _ProfileSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _ProfileSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDiverAsync = ref.watch(currentDiverProvider);
    final allDiversAsync = ref.watch(diverListNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Active Diver'),
          const SizedBox(height: 8),
          currentDiverAsync.when(
            data: (diver) =>
                _buildDiverCard(context, ref, diver, allDiversAsync),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Error loading diver'),
                subtitle: Text('$error'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Manage Divers'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts),
                  title: const Text('View All Divers'),
                  subtitle: const Text('Add or edit diver profiles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/divers'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Add New Diver'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/divers/new'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiverCard(
    BuildContext context,
    WidgetRef ref,
    Diver? diver,
    AsyncValue<List<Diver>> allDiversAsync,
  ) {
    if (diver == null) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.person_add),
          ),
          title: const Text('No diver profile'),
          subtitle: const Text('Tap to create your profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/divers/new'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: diver.photoPath != null
              ? AssetImage(diver.photoPath!)
              : null,
          child: diver.photoPath == null
              ? Text(
                  diver.initials,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(diver.name),
        subtitle: const Text('Active diver - tap to switch'),
        trailing: const Icon(Icons.swap_horiz),
        onTap: () => _showDiverSwitcher(context, ref, allDiversAsync),
      ),
    );
  }

  void _showDiverSwitcher(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Diver>> diversAsync,
  ) {
    final currentDiverId = ref.read(currentDiverIdProvider);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Switch Diver',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            diversAsync.when(
              data: (divers) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: divers.length,
                  itemBuilder: (context, index) {
                    final diver = divers[index];
                    final isCurrentDiver = diver.id == currentDiverId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: diver.photoPath != null
                            ? AssetImage(diver.photoPath!)
                            : null,
                        child: diver.photoPath == null
                            ? Text(
                                diver.initials,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(diver.name),
                      trailing: isCurrentDiver
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () async {
                        if (!isCurrentDiver) {
                          await ref
                              .read(currentDiverIdProvider.notifier)
                              .setCurrentDiver(diver.id);
                        }
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (context.mounted && !isCurrentDiver) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Switched to ${diver.name}'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $error'),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/divers/new');
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Diver'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

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
          _buildSectionHeader(context, 'Unit System'),
          const SizedBox(height: 8),
          _buildUnitPresetSelector(context, ref, settings),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Individual Units'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: 'Depth',
                  value: settings.depthUnit.symbol,
                  onTap: () =>
                      _showDepthUnitPicker(context, ref, settings.depthUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: 'Temperature',
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
                  title: 'Pressure',
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
                  title: 'Volume',
                  value: settings.volumeUnit.symbol,
                  onTap: () =>
                      _showVolumeUnitPicker(context, ref, settings.volumeUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: 'Weight',
                  value: settings.weightUnit.symbol,
                  onTap: () =>
                      _showWeightUnitPicker(context, ref, settings.weightUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: 'SAC Rate',
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
          _buildSectionHeader(context, 'Time & Date Format'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: 'Time Format',
                  value: settings.timeFormat.displayName,
                  onTap: () =>
                      _showTimeFormatPicker(context, ref, settings.timeFormat),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: 'Date Format',
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
            Text('Quick Select', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SegmentedButton<UnitPreset>(
              segments: const [
                ButtonSegment(value: UnitPreset.metric, label: Text('Metric')),
                ButtonSegment(
                  value: UnitPreset.imperial,
                  label: Text('Imperial'),
                ),
                ButtonSegment(value: UnitPreset.custom, label: Text('Custom')),
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
        title: const Text('Depth Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DepthUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == DepthUnit.meters ? 'Meters (m)' : 'Feet (ft)',
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
        title: const Text('Temperature Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TemperatureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == TemperatureUnit.celsius
                    ? 'Celsius (°C)'
                    : 'Fahrenheit (°F)',
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
        title: const Text('Pressure Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PressureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(unit == PressureUnit.bar ? 'Bar' : 'PSI'),
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
        title: const Text('Volume Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VolumeUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == VolumeUnit.liters ? 'Liters (L)' : 'Cubic Feet (cuft)',
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
        title: const Text('Weight Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WeightUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == WeightUnit.kilograms
                    ? 'Kilograms (kg)'
                    : 'Pounds (lbs)',
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
        title: const Text('SAC Rate Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Volume per minute'),
              subtitle: const Text('Requires tank volume (L/min or cuft/min)'),
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
              title: const Text('Pressure per minute'),
              subtitle: const Text(
                'No tank volume needed (bar/min or psi/min)',
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
        title: const Text('Time Format'),
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
        title: const Text('Date Format'),
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
          _buildSectionHeader(context, 'Gradient Factors'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Current Settings'),
              subtitle: Text('GF ${settings.gfLow}/${settings.gfHigh}'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showGradientFactorPicker(context, ref, settings),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'About Gradient Factors',
            'Gradient Factors (GF) control how conservative your decompression calculations are. '
                'GF Low affects deep stops, while GF High affects shallow stops.\n\n'
                'Lower values = more conservative = longer deco stops\n'
                'Higher values = less conservative = shorter deco stops',
          ),
        ],
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
}

/// Appearance section content
class _AppearanceSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _AppearanceSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Theme'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: ThemeMode.values.map((mode) {
                final isSelected = mode == settings.themeMode;
                return ListTile(
                  leading: Icon(_getThemeModeIcon(mode)),
                  title: Text(_getThemeModeName(mode)),
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
          _buildSectionHeader(context, 'Dive Log'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
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
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Map background on dive cards'),
                  subtitle: const Text(
                    'Show dive site map as background on dive cards',
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
            child: SwitchListTile(
              title: const Text('Map background on site cards'),
              subtitle: const Text('Show map as background on dive site cards'),
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
          _buildSectionHeader(context, 'Dive Profile'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Max depth marker'),
                  subtitle: const Text(
                    'Show a marker at the maximum depth point on dive profiles',
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
                  title: const Text('Pressure threshold markers'),
                  subtitle: const Text(
                    'Show markers when tank pressure crosses thresholds',
                  ),
                  secondary: const Icon(Icons.propane_tank),
                  value: settings.showPressureThresholdMarkers,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setShowPressureThresholdMarkers(value);
                  },
                ),
              ],
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
          _buildSectionHeader(context, 'Service Reminders'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Service Reminders'),
                  subtitle: const Text(
                    'Get notified when equipment service is due',
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
                          const SnackBar(
                            content: Text(
                              'Please enable notifications in system settings',
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
                          title: const Text('Notifications Disabled'),
                          subtitle: const Text(
                            'Enable in system settings to receive reminders',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await NotificationService.instance
                                  .requestPermission();
                              ref.invalidate(notificationPermissionProvider);
                            },
                            child: const Text('Enable'),
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
            _buildSectionHeader(context, 'Reminder Schedule'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remind me before service is due:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [7, 14, 30].map((days) {
                        final isSelected = settings.serviceReminderDays
                            .contains(days);
                        return FilterChip(
                          label: Text('$days days'),
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
                title: const Text('Reminder Time'),
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
              'How it works',
              'Notifications are scheduled when the app launches and refresh '
                  'periodically in the background. You can customize reminders '
                  'for individual equipment items in their edit screen.',
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
          _buildSectionHeader(context, 'Manage Data'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flight_takeoff),
                  title: const Text('Trips'),
                  subtitle: const Text('Manage your dive trips'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/trips'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Buddies'),
                  subtitle: const Text('Manage your dive buddies'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/buddies'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.card_membership),
                  title: const Text('Certifications'),
                  subtitle: const Text('Manage your dive certifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/certifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('Dive Centers'),
                  subtitle: const Text('Manage dive shops and operators'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-centers'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.label),
                  title: const Text('Dive Types'),
                  subtitle: const Text('Manage custom dive types'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-types'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.propane_tank),
                  title: const Text('Tank Presets'),
                  subtitle: const Text('Manage custom tank configurations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tank-presets'),
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
    final syncState = ref.watch(syncStateProvider);
    final isCustomFolder =
        storageState.config.mode == StorageLocationMode.customFolder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Storage'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Database Storage'),
                  subtitle: Text(
                    isCustomFolder ? 'Custom folder' : 'App default location',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/storage'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Offline Maps'),
                  subtitle: const Text('Download maps for offline use'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/offline-maps'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Backup & Sync'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('Cloud Sync'),
                  subtitle: Text(_getSyncSubtitle(syncState)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (syncState.conflicts > 0)
                        Badge(
                          label: Text('${syncState.conflicts}'),
                          child: const Icon(
                            Icons.warning,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                      if (syncState.pendingChanges > 0 &&
                          syncState.conflicts == 0)
                        Badge(
                          label: Text('${syncState.pendingChanges}'),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/settings/cloud-sync'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup'),
                  subtitle: const Text('Create a backup of your data'),
                  onTap: () => _handleExport(
                    context,
                    ref,
                    () => ref
                        .read(exportNotifierProvider.notifier)
                        .createBackup(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore'),
                  subtitle: const Text('Restore from backup'),
                  onTap: () => _showRestoreConfirmation(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncSubtitle(SyncState syncState) {
    if (syncState.status == SyncStatus.syncing) {
      return 'Syncing...';
    } else if (syncState.lastSync != null) {
      return 'Last synced: ${_formatSyncTime(syncState.lastSync!)}';
    }
    return 'Not configured';
  }

  void _showRestoreConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Warning: Restoring from a backup will replace ALL current data with the backup data. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _handleImport(
                context,
                ref,
                () => ref.read(exportNotifierProvider.notifier).restoreBackup(),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() exportFn,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Exporting...'),
          ],
        ),
      ),
    );

    try {
      await exportFn();
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            final state = ref.read(exportNotifierProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Export completed'),
                backgroundColor: state.status == ExportStatus.success
                    ? Colors.green
                    : Colors.red,
              ),
            );
            ref.read(exportNotifierProvider.notifier).reset();
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Export failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() importFn,
  ) async {
    var dialogShown = false;

    void showDialogIfNeeded(ExportState state) {
      if (!dialogShown &&
          state.importPhase != null &&
          state.status == ExportStatus.exporting &&
          context.mounted) {
        dialogShown = true;
        ImportProgressDialog.show(context);
      }
    }

    try {
      final subscription = ref.listenManual(
        exportNotifierProvider,
        (previous, next) => showDialogIfNeeded(next),
        fireImmediately: true,
      );

      try {
        await importFn();
      } finally {
        subscription.close();
      }

      if (context.mounted) {
        final state = ref.read(exportNotifierProvider);
        if (state.status != ExportStatus.idle) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? 'Operation completed'),
              backgroundColor: state.status == ExportStatus.success
                  ? Colors.green
                  : Colors.red,
            ),
          );
        }
        ref.read(exportNotifierProvider.notifier).reset();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// About section content
class _AboutSectionContent extends StatelessWidget {
  const _AboutSectionContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'About'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Submersion'),
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Open Source Licenses'),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Submersion',
                      applicationVersion: '0.1.0',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Report an Issue'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Visit github.com/submersion/submersion'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
                  'Submersion',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 0.1.0',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Submersion',
      applicationVersion: '0.1.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icon/icon.png', width: 64, height: 64),
      ),
      children: const [
        Text('Track your dives, manage gear, and explore dive sites.'),
      ],
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

String _formatSyncTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Gradient Factors'),
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
                      'GF Low/High control how conservative your NDL and deco calculations are.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presets',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...GfPreset.values.where((p) => p != GfPreset.custom).map((preset) {
              final isSelected = _selectedPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                                preset.name,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                preset.description,
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
              );
            }),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Custom Values',
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
                  child: Text('GF Low', style: textTheme.bodyMedium),
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
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text('GF High', style: textTheme.bodyMedium),
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
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lower values = more conservative (longer NDL/more deco)',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_gfLow, _gfHigh);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
