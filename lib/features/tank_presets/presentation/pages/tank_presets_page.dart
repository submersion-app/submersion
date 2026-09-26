import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

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
            padding: kFabListPadding,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.tankPresets_builtInPresets_description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...builtInPresets.map(
                (preset) => _buildPresetTile(
                  context,
                  ref,
                  preset,
                  units,
                  canEdit: false,
                  isDefault: settings.defaultTankPreset == preset.name,
                  isHidden:
                      settings.defaultTankPreset != preset.name &&
                      settings.hiddenTankPresetIds.contains(preset.name),
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
    bool isHidden = false,
  }) {
    final volumeStr = units.formatTankVolume(
      preset.volumeLiters,
      preset.workingPressureBar,
      ratedCapacityCuft: preset.ratedCapacityCuft,
    );
    final pressureStr = units.formatPressure(
      preset.workingPressureBar,
      decimals: 0,
    );

    return ListTile(
      // A hidden built-in preset stays listed so it can be shown again, and
      // only its text and icon are dimmed: the tile is not disabled, since
      // its star and switch stay usable.
      textColor: isHidden ? Theme.of(context).disabledColor : null,
      leading: Icon(
        MdiIcons.divingScubaTank,
        color: isHidden
            ? Theme.of(context).disabledColor
            : canEdit
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      // Only seeded rows resolve through the built-in translation table. A
      // custom preset can slug onto a built-in name (nothing rejects a diver
      // creating their own "AL80"), and its displayName is the diver's, not
      // an identifier to be relabelled.
      title: Text(
        preset.isBuiltIn
            ? builtInTankPresetName(context.l10n, preset.name) ??
                  preset.displayName
            : preset.displayName,
      ),
      subtitle: Text(
        '$volumeStr • $pressureStr • ${preset.material.localizedName(context.l10n)}',
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
          // Built-in presets can be hidden from the pickers (issue #2305),
          // except the default one. Its switch keeps its space so the stars
          // stay aligned down the list.
          if (!canEdit)
            Visibility(
              visible: !isDefault,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Tooltip(
                message: context.l10n.tankPresets_showInPickers,
                child: Switch(
                  key: ValueKey('tank-preset-visible-${preset.name}'),
                  value: !isHidden,
                  onChanged: (visible) => ref
                      .read(settingsProvider.notifier)
                      .setTankPresetHidden(preset.name, !visible),
                ),
              ),
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
