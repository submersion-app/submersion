import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item page's check-in list: every observation on the item, newest
/// first, with the dive it was made on (or "Bench"). Adding and editing go
/// through the same sheet the dive page uses, in its no-dive mode so a new
/// row may pick a dive or stay a bench note; deleting asks first, as the
/// sheet does.
class ObservationsCard extends ConsumerWidget {
  final EquipmentItem equipment;

  const ObservationsCard({super.key, required this.equipment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final observationsAsync = ref.watch(
      observationsForEquipmentProvider(equipment.id),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.equipmentObservation_card_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showEquipmentObservationSheet(
                    context,
                    equipment: equipment,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.equipmentObservation_card_add),
                ),
              ],
            ),
            const Divider(),
            observationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (observations) {
                if (observations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipmentObservation_card_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final o in observations)
                      _ObservationRow(equipment: equipment, observation: o),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationRow extends ConsumerWidget {
  final EquipmentItem equipment;
  final EquipmentObservation observation;

  const _ObservationRow({required this.equipment, required this.observation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    final title = observation.displayTitle(l10n);
    final note = observation.noteSummary;
    final when = units.formatDate(observation.observedAt);
    final diveId = observation.diveId;
    // From the card's one batched read, not a dive detail per row.
    final diveNumber = diveId == null
        ? null
        : ref
              .watch(observationDiveNumbersProvider(equipment.id))
              .value?[diveId];
    final where = diveId == null
        ? l10n.equipmentObservation_card_bench
        // Until the dive resolves, a plain label: the id is internal.
        : diveNumber == null
        ? l10n.equipmentObservation_sheet_diveLabel
        : l10n.equipmentObservation_card_onDive(diveNumber);
    final detail = '$when, $where';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        observation.isIssue ? Icons.warning_amber : Icons.check_circle_outline,
        color: observation.isIssue ? scheme.error : scheme.tertiary,
      ),
      title: Text(title),
      subtitle: note.isEmpty
          ? Text(detail)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(detail),
              ],
            ),
      isThreeLine: note.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.equipmentObservation_sheet_edit,
            onPressed: () => showEquipmentObservationSheet(
              context,
              equipment: equipment,
              editing: observation,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.equipmentObservation_sheet_delete,
            onPressed: () =>
                confirmDeleteObservation(context, ref, observation),
          ),
        ],
      ),
    );
  }
}
