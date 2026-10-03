import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/title_actions_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearCard');

/// The gear packed for a trip (issue #2338), right after the Cylinders card:
/// Add gear through the equipment picker, Use set to pack a whole equipment
/// set (issue #2794), and Unpack on each item. Like the Cylinders card it
/// says nothing until the gear loads, and nothing on a past trip with no
/// gear.
class TripGearCard extends ConsumerWidget {
  const TripGearCard({super.key, required this.trip});

  final Trip trip;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentItem> items,
  ) async {
    final picked = await showModalBottomSheet<EquipmentItem>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: {for (final i in items) i.id},
          onEquipmentSelected: (item) => Navigator.of(sheetContext).pop(item),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _change(
      context,
      () =>
          ref.read(tripEquipmentRepositoryProvider).pack(trip.id, [picked.id]),
    );
  }

  /// Packs the members of a picked set that are not packed yet, merging
  /// into the trip's gear the way every other Use set merges, and says how
  /// many it added.
  Future<void> _useSet(BuildContext context, WidgetRef ref) async {
    final picked =
        await showModalBottomSheet<(EquipmentSet, List<EquipmentItem>)>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => EquipmentSetPickerSheet(
              scrollController: scrollController,
              onSetSelected: (set, items) =>
                  Navigator.of(sheetContext).pop((set, items)),
            ),
          ),
        );
    if (picked == null || !context.mounted) return;
    final (set, items) = picked;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // Everything from ref is read before the first await: the card can be
    // gone by the time the diver resolves.
    final trips = ref.read(tripEquipmentRepositoryProvider);
    final equipment = ref.read(equipmentRepositoryProvider);
    final diverIdFuture = ref.read(validatedCurrentDiverIdProvider.future);
    await _change(context, () async {
      final ids = await _usableIds(equipment, diverIdFuture, items);
      // No member still shared with the diver: nothing to pack, as on the
      // dive edit page.
      if (ids.isEmpty) return;
      final added = await trips.pack(trip.id, ids);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.trips_gear_packedFromSet(added, set.name))),
      );
    });
  }

  /// The set members the current diver may pack: a member no longer shared
  /// with them stays in the set but is not applied (issue #2046). With no
  /// diver yet every member is packed. A diver that cannot be read fails the
  /// pack, said by [_change], rather than packing past the share filter; the
  /// set picker lists sets only once the diver resolves anyway.
  Future<List<String>> _usableIds(
    EquipmentRepository equipment,
    Future<String?> diverIdFuture,
    List<EquipmentItem> items,
  ) async {
    final ids = [for (final item in items) item.id];
    final diverId = await diverIdFuture;
    if (diverId == null) return ids;
    return equipment.usableSetMemberIds(ids, diverId);
  }

  /// Runs a pack or an unpack; a failure is logged and said.
  Future<void> _change(
    BuildContext context,
    Future<void> Function() run,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await run();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to change trip gear',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(tripGearProvider(trip.id)).value;
    if (items == null || (items.isEmpty && !trip.isUpcoming)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Like the Cylinders card it has no scroll view of its own and scrolls
    // with the other header cards (#2653).
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use set and Add gear sit beside the title when they fit and
            // drop under it when a long translation would not (#2794).
            TitleActionsLayout(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.trips_gear_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              // No alignment: with one, OverflowBar takes the full width and
              // the buttons could never sit beside the title. Stacked, on the
              // narrowest phones, they keep to the end edge.
              actions: OverflowBar(
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton(
                    key: const Key('trip-gear-use-set'),
                    onPressed: () => _useSet(context, ref),
                    child: Text(l10n.trips_gear_useSet),
                  ),
                  TextButton(
                    key: const Key('trip-gear-add'),
                    onPressed: () => _add(context, ref, items),
                    child: Text(l10n.trips_gear_add),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Text(l10n.trips_gear_none)
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in items)
                    InputChip(
                      key: Key('trip-gear-${item.id}'),
                      label: Text(item.name),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _change(
                        context,
                        () => ref
                            .read(tripEquipmentRepositoryProvider)
                            .unpack(trip.id, item.id),
                      ),
                      deleteButtonTooltipMessage: l10n.trips_gear_remove,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
