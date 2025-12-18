import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/units.dart';
import '../providers/export_providers.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
            onTap: () => _showTempUnitPicker(context, ref, settings.temperatureUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Pressure',
            value: settings.pressureUnit.symbol,
            onTap: () => _showPressureUnitPicker(context, ref, settings.pressureUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Volume',
            value: settings.volumeUnit.symbol,
            onTap: () => _showVolumeUnitPicker(context, ref, settings.volumeUnit),
          ),
          _buildUnitTile(
            context,
            title: 'Weight',
            value: settings.weightUnit.symbol,
            onTap: () => _showWeightUnitPicker(context, ref, settings.weightUnit),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Appearance'),
          _buildThemeSelector(context, ref, settings.themeMode),
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
          const Divider(),

          _buildSectionHeader(context, 'Tools'),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Weight Calculator'),
            subtitle: const Text('Calculate recommended dive weight'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/tools/weight-calculator'),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Data'),
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
              _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).createBackup());
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
          const Divider(),

          _buildSectionHeader(context, 'Dive Computer'),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Connect Dive Computer'),
            subtitle: const Text('Import dives via Bluetooth'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dive computer connection coming soon')),
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
                const SnackBar(content: Text('Visit github.com/submersion/submersion')),
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

  Widget _buildUnitPresetSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<UnitPreset>(
        segments: const [
          ButtonSegment(
            value: UnitPreset.metric,
            label: Text('Metric'),
          ),
          ButtonSegment(
            value: UnitPreset.imperial,
            label: Text('Imperial'),
          ),
          ButtonSegment(
            value: UnitPreset.custom,
            label: Text('Custom'),
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

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeModeName(currentMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemePicker(context, ref, currentMode),
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

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return ListTile(
              leading: Icon(_getThemeModeIcon(mode)),
              title: Text(_getThemeModeName(mode)),
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeMode(mode);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
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

  void _showDepthUnitPicker(BuildContext context, WidgetRef ref, DepthUnit currentUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Depth Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DepthUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(unit == DepthUnit.meters ? 'Meters (m)' : 'Feet (ft)'),
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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

  void _showTempUnitPicker(BuildContext context, WidgetRef ref, TemperatureUnit currentUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Temperature Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TemperatureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(unit == TemperatureUnit.celsius
                  ? 'Celsius (°C)'
                  : 'Fahrenheit (°F)',),
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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

  void _showPressureUnitPicker(BuildContext context, WidgetRef ref, PressureUnit currentUnit) {
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
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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

  void _showVolumeUnitPicker(BuildContext context, WidgetRef ref, VolumeUnit currentUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Volume Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VolumeUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(unit == VolumeUnit.liters ? 'Liters (L)' : 'Cubic Feet (cuft)'),
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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

  void _showWeightUnitPicker(BuildContext context, WidgetRef ref, WeightUnit currentUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Weight Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WeightUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(unit == WeightUnit.kilograms ? 'Kilograms (kg)' : 'Pounds (lbs)'),
              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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
              _handleImport(context, ref, () => ref.read(exportNotifierProvider.notifier).restoreBackup());
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
                _handleImport(context, ref, () => ref.read(exportNotifierProvider.notifier).importDivesFromCsv());
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Import from UDDF'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleImport(context, ref, () => ref.read(exportNotifierProvider.notifier).importDivesFromUddf());
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
                _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).exportDivesToPdf());
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Dives as CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).exportDivesToCsv());
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Sites as CSV'),
              subtitle: const Text('Export dive sites'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).exportSitesToCsv());
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Equipment as CSV'),
              subtitle: const Text('Export equipment inventory'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).exportEquipmentToCsv());
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('UDDF Export'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, () => ref.read(exportNotifierProvider.notifier).exportDivesToUddf());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Handle export operations that use Share (no file picker)
  Future<void> _handleExport(BuildContext context, WidgetRef ref, Future<void> Function() exportFn) async {
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
                backgroundColor: state.status == ExportStatus.success ? Colors.green : Colors.red,
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
  /// Don't show loading dialog before file picker to avoid navigator lock
  Future<void> _handleImport(BuildContext context, WidgetRef ref, Future<void> Function() importFn) async {
    try {
      await importFn();
      if (context.mounted) {
        final state = ref.read(exportNotifierProvider);
        // Only show snackbar if not cancelled (idle status means user cancelled)
        if (state.status != ExportStatus.idle) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? 'Operation completed'),
              backgroundColor: state.status == ExportStatus.success ? Colors.green : Colors.red,
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
        Text(
          'An open-source dive logging application.',
        ),
        SizedBox(height: 16),
        Text(
          'Track your dives, manage gear, and explore dive sites.',
        ),
      ],
    );
  }
}
