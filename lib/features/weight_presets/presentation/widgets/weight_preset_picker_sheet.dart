import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing the diver's saved weighting rigs so one can be applied
/// to the dive being edited (issue #1609). Pops the chosen [WeightPreset], or
/// null on dismiss.
class WeightPresetPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const WeightPresetPickerSheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presetsAsync = ref.watch(weightPresetsProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.diveLog_edit_weightPreset_pickerTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: presetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('${l10n.common_label_error}: $e')),
            data: (presets) {
              if (presets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.diveLog_edit_weightPreset_empty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: scrollController,
                itemCount: presets.length,
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
                    onTap: () => Navigator.of(context).pop(preset),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
