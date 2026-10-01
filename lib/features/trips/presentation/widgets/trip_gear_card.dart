import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearCard');

/// The gear packed for a trip (issue #2338), right after the Cylinders card:
/// Add gear through the equipment picker, and Unpack on each item. Like the
/// Cylinders card it says nothing until the gear loads, and nothing on a
/// past trip with no gear.
class TripGearCard extends ConsumerWidget {
  const TripGearCard({super.key, required this.trip});

  final Trip trip;

  /// The most of the window the card may take before it scrolls, below the
  /// Cylinders card's share so the story keeps room on a phone.
  static const maxHeightFraction = 0.25;

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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.trips_gear_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    key: const Key('trip-gear-add'),
                    onPressed: () => _add(context, ref, items),
                    child: Text(l10n.trips_gear_add),
                  ),
                ],
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
      ),
    );
  }
}
