import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings → Management → Weight Presets (issue #1609). Presets are created
/// from the dive editor; this screen only renames and deletes them.
class WeightPresetsPage extends ConsumerWidget {
  const WeightPresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presetsAsync = ref.watch(weightPresetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.weightPresets_page_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.common_label_error}: $e')),
        data: (presets) {
          if (presets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.weightPresets_page_empty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: presets.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final preset = presets[i];
              return ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(preset.displayName),
                subtitle: Text(
                  l10n.diveLog_edit_weightPreset_summary(
                    preset.entries.length,
                    units.formatWeight(preset.totalKg),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      _rename(context, ref, preset);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, preset);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.weightPresets_action_rename),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.common_action_delete),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    WeightPreset preset,
  ) async {
    final name = await NamePromptDialog.show(
      context,
      title: context.l10n.weightPresets_rename_title,
      label: context.l10n.diveLog_edit_weightPreset_nameLabel,
      confirmLabel: context.l10n.common_action_save,
      initialValue: preset.displayName,
    );
    if (name == null || name == preset.displayName) return;
    await ref
        .read(weightPresetRepositoryProvider)
        .renamePreset(id: preset.id, displayName: name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WeightPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.weightPresets_delete_title),
        content: Text(
          context.l10n.weightPresets_delete_body(preset.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(weightPresetRepositoryProvider).deletePreset(preset.id);
  }
}
