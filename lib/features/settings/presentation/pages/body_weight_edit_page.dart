import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/body_weight_entry_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dated body-weight history for the active diver (weight prediction v104):
/// a list of measurements with add/delete.
class BodyWeightEditPage extends ConsumerWidget {
  const BodyWeightEditPage({super.key});

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final draft = await showBodyWeightEntryDialog(context);
    if (draft == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;

    await ref
        .read(diverWeightEntryRepositoryProvider)
        .createEntry(
          DiverWeightEntry(
            id: '',
            diverId: diverId,
            measuredAt: draft.measuredAt,
            weightKg: draft.weightKg,
            heightCm: draft.heightCm,
            bodyFatPercent: draft.bodyFatPercent,
            createdAt: draft.measuredAt,
            updatedAt: draft.measuredAt,
          ),
        );
    ref.invalidate(diverWeightEntriesProvider);
  }

  /// The date, then whichever of height and body fat the entry carries.
  static String _subtitle(
    BuildContext context,
    UnitFormatter units,
    DiverWeightEntry entry,
  ) {
    final bodyFat = entry.bodyFatPercent;
    return [
      units.formatDate(entry.measuredAt),
      if (entry.heightCm != null) units.formatHeight(entry.heightCm),
      if (bodyFat != null)
        context.l10n.bodyWeight_bodyFatValue(formatRoundedForInput(bodyFat, 1)),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(diverWeightEntriesProvider);
    final units = ref.watch(unitFormatterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diverProfile_bodyWeight_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.bodyWeight_addEntry),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text(context.l10n.diverProfile_bodyWeight_empty),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: const Icon(Icons.monitor_weight),
                title: Text(units.formatWeight(entry.weightKg)),
                subtitle: Text(_subtitle(context, units, entry)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.bodyWeight_deleteTooltip,
                  onPressed: () async {
                    await ref
                        .read(diverWeightEntryRepositoryProvider)
                        .deleteEntry(entry.id);
                    ref.invalidate(diverWeightEntriesProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
