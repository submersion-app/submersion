import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/units.dart';
import '../../../../core/domain/entities/storage_config.dart';
import '../../../dive_log/presentation/providers/dive_computer_providers.dart';
import '../../../divers/domain/entities/diver.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../providers/api_key_providers.dart';
import '../providers/export_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/storage_providers.dart';
import '../providers/sync_providers.dart';
import '../widgets/import_progress_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Diver Profile'),
          _buildDiverProfileSection(context, ref),
          const Divider(),
          _buildSectionHeader(context, 'Units'),
          _buildUnitPresetSelector(context, ref, settings),
          _buildUnitTile(
            context,
            title: 'Depth',
            value: settings.depthUnit.symbol,
            onTap: () => _showDepthUnitPicker(context, ref, settings.depthUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Temperature',
            value: '°${settings.temperatureUnit.symbol}',
            onTap: () =>
                _showTempUnitPicker(context, ref, settings.temperatureUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Pressure',
            value: settings.pressureUnit.symbol,
            onTap: () =>
                _showPressureUnitPicker(context, ref, settings.pressureUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Volume',
            value: settings.volumeUnit.symbol,
            onTap: () =>
                _showVolumeUnitPicker(context, ref, settings.volumeUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Weight',
            value: settings.weightUnit.symbol,
            onTap: () =>
                _showWeightUnitPicker(context, ref, settings.weightUnit),
          ),
          _buildUnitTile(
            context,
            title: 'SAC Rate',
            value: settings.sacUnit == SacUnit.litersPerMin
                ? '${settings.volumeUnit.symbol}/min'
                : '${settings.pressureUnit.symbol}/min',
            onTap: () => _showSacUnitPicker(context, ref, settings.sacUnit),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme & Display'),
            subtitle: Text(_getThemeModeName(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/appearance'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Manage'),
          ListTile(
            leading: const Icon(Icons.flight_takeoff),
            title: const Text('Trips'),
            subtitle: const Text('Manage your dive trips'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trips'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Buddies'),
            subtitle: const Text('Manage your dive buddies'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/buddies'),
          ),
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('Certifications'),
            subtitle: const Text('Manage your dive certifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/certifications'),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Dive Centers'),
            subtitle: const Text('Manage dive shops and operators'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/dive-centers'),
          ),
          ListTile(
            leading: const Icon(Icons.label),
            title: const Text('Dive Types'),
            subtitle: const Text('Manage custom dive types'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/dive-types'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'API Integrations'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Weather & Tide APIs'),
            subtitle: Consumer(
              builder: (context, ref, child) {
                final apiKeys = ref.watch(apiKeyProvider);
                if (apiKeys.isLoading) {
                  return const Text('Loading...');
                }
                final configured = <String>[];
                if (apiKeys.hasWeatherKey) configured.add('Weather');
                if (apiKeys.hasTideKey) configured.add('Tides');
                return Text(
                  configured.isEmpty
                      ? 'Not configured'
                      : '${configured.join(', ')} configured',
                );
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/api-keys'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Data'),
          Consumer(
            builder: (context, ref, child) {
              final storageState = ref.watch(storageConfigNotifierProvider);
              final isCustomFolder =
                  storageState.config.mode == StorageLocationMode.customFolder;
              return ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Database Storage'),
                subtitle: Text(
                  isCustomFolder ? 'Custom folder' : 'App default location',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/storage'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import'),
            subtitle: const Text('Import dives from file'),
            onTap: () {
              _showImportOptions(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export'),
            subtitle: const Text('Export your data'),
            onTap: () {
              _showExportOptions(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup'),
            subtitle: const Text('Create a backup of your data'),
            onTap: () {
              _handleExport(
                context,
                ref,
                () => ref.read(exportNotifierProvider.notifier).createBackup(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore'),
            subtitle: const Text('Restore from backup'),
            onTap: () {
              _showRestoreConfirmation(context, ref);
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final syncState = ref.watch(syncStateProvider);
              String subtitle;
              if (syncState.status == SyncStatus.syncing) {
                subtitle = 'Syncing...';
              } else if (syncState.lastSync != null) {
                subtitle =
                    'Last synced: ${_formatSyncTime(syncState.lastSync!)}';
              } else {
                subtitle = 'Not configured';
              }
              return ListTile(
                leading: const Icon(Icons.cloud_sync),
                title: const Text('Cloud Sync'),
                subtitle: Text(subtitle),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => context.push('/settings/cloud-sync'),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'Dive Computer'),
          Consumer(
            builder: (context, ref, child) {
              final computersAsync = ref.watch(allDiveComputersProvider);
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Dive Computers'),
                subtitle: computersAsync.when(
                  data: (computers) => Text(
                    computers.isEmpty
                        ? 'No computers connected'
                        : '${computers.length} saved ${computers.length == 1 ? 'computer' : 'computers'}',
                  ),
                  loading: () => const Text('Loading...'),
                  error: (_, _) => const Text('Error loading computers'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/dive-computers'),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Submersion'),
            onTap: () {
              _showAboutDialog(context);
            },
          ),
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

  Widget _buildDiverProfileSection(BuildContext context, WidgetRef ref) {
    final currentDiverAsync = ref.watch(currentDiverProvider);
    final allDiversAsync = ref.watch(diverListNotifierProvider);

    return currentDiverAsync.when(
      data: (diver) {
        if (diver == null) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person_add),
            ),
            title: const Text('No diver profile'),
            subtitle: const Text('Tap to create your profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/divers/new'),
          );
        }

        return Column(
          children: [
            // Current diver tile
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
              subtitle: const Text('Active diver - tap to switch'),
              trailing: const Icon(Icons.swap_horiz),
              onTap: () => _showDiverSwitcher(context, ref, allDiversAsync),
            ),
            // Manage divers link
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Manage Divers'),
              subtitle: const Text('Add or edit diver profiles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/divers'),
            ),
          ],
        );
      },
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Loading...'),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: const Text('Error loading diver'),
        subtitle: Text('$error'),
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

  Widget _buildUnitPresetSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<UnitPreset>(
        segments: const [
          ButtonSegment(value: UnitPreset.metric, label: Text('Metric')),
          ButtonSegment(value: UnitPreset.imperial, label: Text('Imperial')),
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
              // Custom is already selected when units are mixed
              // No action needed - user can adjust individual units
              break;
          }
        },
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

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Import Data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Import from CSV'),
              subtitle: const Text('Import dives from CSV file'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleImport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .importDivesFromCsv(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Import from UDDF'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleImport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .importDivesFromUddf(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Export Data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Logbook'),
              subtitle: const Text('Printable dive logbook'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .exportDivesToPdf(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Dives as CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .exportDivesToCsv(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Sites as CSV'),
              subtitle: const Text('Export dive sites'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .exportSitesToCsv(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Equipment as CSV'),
              subtitle: const Text('Export equipment inventory'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .exportEquipmentToCsv(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('UDDF Export'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  () => ref
                      .read(exportNotifierProvider.notifier)
                      .exportDivesToUddf(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Handle export operations that use Share (no file picker)
  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() exportFn,
  ) async {
    // Show loading indicator using root navigator to avoid conflicts
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
        // Use post-frame callback to safely close dialog after any navigation settles
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

  /// Handle import/restore operations that use native file picker
  /// Shows progress dialog during import to prevent UI appearing frozen
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
      // Set up listener BEFORE starting import to catch all state changes
      final subscription = ref.listenManual(
        exportNotifierProvider,
        (previous, next) => showDialogIfNeeded(next),
        fireImmediately: true,
      );

      // Now start the import
      try {
        await importFn();
      } finally {
        // Always clean up subscription, even on errors.
        subscription.close();
      }

      if (context.mounted) {
        final state = ref.read(exportNotifierProvider);
        // Only show snackbar if not cancelled (idle status means user cancelled)
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Submersion',
      applicationVersion: '0.1.0',
      applicationIcon: Icon(
        Icons.scuba_diving,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: const [
        Text('An open-source dive logging application.'),
        SizedBox(height: 16),
        Text('Track your dives, manage gear, and explore dive sites.'),
      ],
    );
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
}
