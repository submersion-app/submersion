import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_history_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Who used an item, when, and every share and ownership change (issue
/// #2046). Shown only when two or more profiles exist. The active diver's
/// own runs open their dive list filtered to the item; other divers' runs
/// are not tappable, because the dive list shows only the active profile.
class EquipmentHistoryCard extends ConsumerWidget {
  final String equipmentId;

  const EquipmentHistoryCard({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasMultipleDiversProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final entries = ref.watch(equipmentHistoryProvider(equipmentId)).value;

    String nameOf(String? id) => id == null
        ? l10n.equipment_history_deletedProfile
        : names[id] ?? l10n.equipment_owner_unknown;

    Widget tile(EquipmentHistoryEntry entry) => switch (entry) {
      EquipmentUsageRun(
        :final diverId,
        :final first,
        :final last,
        :final diveCount,
      ) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.scuba_diving),
          title: Text(nameOf(diverId)),
          subtitle: Text(
            '${l10n.equipment_history_runDives(diveCount)} · '
            '${first == last ? units.formatDate(first) : l10n.equipment_history_dateRange(units.formatDate(first), units.formatDate(last))}',
          ),
          trailing: diverId == activeDiverId
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: diverId == activeDiverId && diverId != null
              ? () {
                  ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                    equipmentIds: [equipmentId],
                  );
                  context.go('/dives');
                }
              : null,
        ),
      EquipmentEventEntry(:final event) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(switch (event.kind) {
          EquipmentOwnershipEventKind.shared => Icons.share,
          EquipmentOwnershipEventKind.unshared => Icons.person_remove_outlined,
          EquipmentOwnershipEventKind.transferred => Icons.swap_horiz,
        }),
        title: Text(switch (event.kind) {
          EquipmentOwnershipEventKind.shared => l10n.equipment_history_shared(
            nameOf(event.toDiverId),
          ),
          EquipmentOwnershipEventKind.unshared =>
            l10n.equipment_history_unshared(nameOf(event.toDiverId)),
          EquipmentOwnershipEventKind.transferred =>
            l10n.equipment_history_transferred(
              nameOf(event.fromDiverId),
              nameOf(event.toDiverId),
            ),
        }),
        subtitle: Text(units.formatDate(event.occurredAt)),
      ),
      EquipmentAddedEntry(:final ownerId, :final at) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline),
        title: Text(l10n.equipment_history_added(nameOf(ownerId))),
        subtitle: Text(units.formatDate(at)),
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipment_history_title,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            if (entries == null)
              const Center(child: CircularProgressIndicator())
            else if (!entries.any((e) => e is EquipmentUsageRun)) ...[
              Text(
                l10n.equipment_history_empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final e in entries) tile(e),
            ] else
              for (final e in entries) tile(e),
          ],
        ),
      ),
    );
  }
}
