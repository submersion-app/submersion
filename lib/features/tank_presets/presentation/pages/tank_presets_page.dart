import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class TankPresetsPage extends ConsumerWidget {
  const TankPresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(tankPresetListNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tankPresets_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: context.l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tank-presets/new'),
        tooltip: context.l10n.tankPresets_addPreset,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.tankPresets_addPreset),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text(context.l10n.tankPresets_error(e.toString()))),
        data: (presets) {
          final builtInPresets = presets.where((p) => p.isBuiltIn).toList();
          final customPresets = presets.where((p) => !p.isBuiltIn).toList();

          if (presets.isEmpty) {
            return Center(child: Text(context.l10n.tankPresets_noPresets));
          }

          return ListView(
            children: [
              _buildSectionHeader(
                context,
                context.l10n.tankPresets_defaultSettings,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.tankPresets_defaultSettings_description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(context.l10n.tankPresets_applyToImports),
                subtitle: Text(
                  context.l10n.tankPresets_applyToImports_subtitle,
                ),
                value: settings.applyDefaultTankToImports,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setApplyDefaultTankToImports(value);
                },
              ),
              const Divider(),
              if (customPresets.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  context.l10n.tankPresets_customPresets,
                ),
                ...customPresets.map(
                  (preset) => _buildPresetTile(
                    context,
                    ref,
                    preset,
                    units,
                    canEdit: true,
                    isDefault: settings.defaultTankPreset == preset.name,
                  ),
                ),
                const Divider(),
              ],
              _buildSectionHeader(
                context,
                context.l10n.tankPresets_builtInPresets,
              ),
              ...builtInPresets.map(
                (preset) => _buildPresetTile(
                  context,
                  ref,
                  preset,
                  units,
                  canEdit: false,
                  isDefault: settings.defaultTankPreset == preset.name,
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
    required bool isDefault,
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
        MdiIcons.divingScubaTank,
        color: canEdit
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(preset.displayName),
      subtitle: Text(
        '$volumeStr • $pressureStr • ${preset.material.displayName}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isDefault ? Icons.star : Icons.star_outline,
              color: isDefault ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: isDefault
                ? null
                : () => ref
                      .read(settingsProvider.notifier)
                      .setDefaultTankPreset(preset.name),
            tooltip: isDefault
                ? context.l10n.tankPresets_currentDefault
                : context.l10n.tankPresets_setAsDefault,
          ),
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/tank-presets/${preset.id}/edit'),
              tooltip: context.l10n.tankPresets_editPreset,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, preset),
              tooltip: context.l10n.tankPresets_deletePreset,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TankPresetEntity preset,
  ) async {
    final settings = ref.read(settingsProvider);
    final isDefault = settings.defaultTankPreset == preset.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tankPresets_deleteTitle),
        content: Text(
          isDefault
              ? context.l10n.tankPresets_deleteDefaultMessage(
                  preset.displayName,
                )
              : context.l10n.tankPresets_deleteMessage(preset.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final notifier = ref.read(tankPresetListNotifierProvider.notifier);
        await notifier.deletePreset(preset.id);
        if (context.mounted) {
          if (isDefault) {
            ref.read(settingsProvider.notifier).setDefaultTankPreset('al80');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.tankPresets_deleted(preset.displayName),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.tankPresets_errorDeleting(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
