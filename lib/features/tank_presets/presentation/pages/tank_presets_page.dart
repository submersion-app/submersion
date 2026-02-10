import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

class TankPresetsPage extends ConsumerWidget {
  const TankPresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(tankPresetListNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tank Presets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tank-presets/new'),
        tooltip: 'Add tank preset',
        child: const Icon(Icons.add),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (presets) {
          final builtInPresets = presets.where((p) => p.isBuiltIn).toList();
          final customPresets = presets.where((p) => !p.isBuiltIn).toList();

          if (presets.isEmpty) {
            return const Center(child: Text('No tank presets available'));
          }

          return ListView(
            children: [
              if (customPresets.isNotEmpty) ...[
                _buildSectionHeader(context, 'Custom Presets'),
                ...customPresets.map(
                  (preset) => _buildPresetTile(
                    context,
                    ref,
                    preset,
                    units,
                    canEdit: true,
                  ),
                ),
                const Divider(),
              ],
              _buildSectionHeader(context, 'Built-in Presets'),
              ...builtInPresets.map(
                (preset) => _buildPresetTile(
                  context,
                  ref,
                  preset,
                  units,
                  canEdit: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPresetTile(
    BuildContext context,
    WidgetRef ref,
    TankPresetEntity preset,
    UnitFormatter units, {
    required bool canEdit,
  }) {
    final volumeStr = units.formatTankVolume(
      preset.volumeLiters,
      preset.workingPressureBar,
      decimals: 0,
    );
    final pressureStr = units.formatPressure(
      preset.workingPressureBar.toDouble(),
      decimals: 0,
    );

    return ListTile(
      leading: Icon(
        canEdit ? Icons.propane_tank_outlined : Icons.propane_tank,
        color: canEdit
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(preset.displayName),
      subtitle: Text(
        '$volumeStr • $pressureStr • ${preset.material.displayName}',
      ),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/tank-presets/${preset.id}/edit'),
                  tooltip: 'Edit preset',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, preset),
                  tooltip: 'Delete preset',
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TankPresetEntity preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tank Preset?'),
        content: Text(
          'Are you sure you want to delete "${preset.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final notifier = ref.read(tankPresetListNotifierProvider.notifier);
        await notifier.deletePreset(preset.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${preset.displayName}"')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting preset: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
