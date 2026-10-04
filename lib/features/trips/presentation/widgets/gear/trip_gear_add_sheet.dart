import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearAddSheet');

enum _Way { equipment, set, rental }

/// The Gear tab's one Add (#2845): a chooser that opens the equipment
/// picker, the set picker, or the rental cylinder form. A cylinder picked
/// from the diver's equipment becomes a slot on the board; anything else is
/// packed.
Future<void> showTripGearAddSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required List<EquipmentItem> packed,
  required List<TripCylinder> slots,
}) async {
  final l10n = context.l10n;
  final way = await showModalBottomSheet<_Way>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.trips_gear_add_fromEquipment),
            onTap: () => Navigator.of(sheet).pop(_Way.equipment),
          ),
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(l10n.trips_gear_add_fromSet),
            onTap: () => Navigator.of(sheet).pop(_Way.set),
          ),
          ListTile(
            leading: const Icon(MdiIcons.divingScubaTank),
            title: Text(l10n.trips_gear_add_rental),
            onTap: () => Navigator.of(sheet).pop(_Way.rental),
          ),
        ],
      ),
    ),
  );
  if (way == null || !context.mounted) return;
  switch (way) {
    case _Way.equipment:
      final picked = await _pickItem(context, packed, slots);
      if (picked == null || !context.mounted) return;
      await _apply(context, ref, trip, slots, [picked], setName: null);
    case _Way.set:
      final picked = await _pickSet(context);
      if (picked == null || !context.mounted) return;
      final (set, items) = picked;
      await _apply(context, ref, trip, slots, items, setName: set.name);
    case _Way.rental:
      await showAddTripCylindersSheet(
        context,
        tripId: trip.id,
        existing: slots,
        rentalOnly: true,
      );
  }
}

Future<EquipmentItem?> _pickItem(
  BuildContext context,
  List<EquipmentItem> packed,
  List<TripCylinder> slots,
) => showModalBottomSheet<EquipmentItem>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => DraggableScrollableSheet(
    initialChildSize: 0.7,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, scrollController) => EquipmentPickerSheet(
      scrollController: scrollController,
      selectedEquipmentIds: {
        for (final i in packed) i.id,
        for (final s in slots)
          if (s.equipmentId != null) s.equipmentId!,
      },
      hideSpare: true,
      onEquipmentSelected: (item) => Navigator.of(sheetContext).pop(item),
    ),
  ),
);

Future<(EquipmentSet, List<EquipmentItem>)?> _pickSet(BuildContext context) =>
    showModalBottomSheet<(EquipmentSet, List<EquipmentItem>)>(
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

/// Packs the non-cylinder items the diver may use and slots the cylinders
/// not already on the board; says how many a set added, counting the slots
/// with the packed items (#2877). A failure is logged and said.
Future<void> _apply(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  List<TripCylinder> slots,
  List<EquipmentItem> items, {
  required String? setName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // Everything from ref is read before the first await: the tab can be gone
  // by the time the diver resolves.
  final packs = ref.read(tripEquipmentRepositoryProvider);
  final cylinders = ref.read(tripCylinderRepositoryProvider);
  final equipment = ref.read(equipmentRepositoryProvider);
  final diverIdFuture = ref.read(validatedCurrentDiverIdProvider.future);
  try {
    final diverId = await diverIdFuture;
    var ids = [for (final i in items) i.id];
    // A member no longer shared with the diver stays in the set but is not
    // applied (issue #2046). With no diver yet every member is used.
    if (diverId != null) {
      ids = await equipment.usableSetMemberIds(ids, diverId);
    }
    final usable = [
      for (final i in items)
        if (ids.contains(i.id)) i,
    ];
    final slotted = {
      for (final s in slots)
        if (s.equipmentId != null) s.equipmentId!,
    };
    final tanks = [
      for (final i in usable)
        if (i.type == EquipmentType.tank && !slotted.contains(i.id)) i,
    ];
    final others = [
      for (final i in usable)
        if (i.type != EquipmentType.tank) i,
    ];
    var addedCount = 0;
    if (others.isNotEmpty) {
      addedCount = await packs.pack(trip.id, [for (final i in others) i.id]);
    }
    if (tanks.isNotEmpty) {
      final now = DateTime.now().toUtc();
      // Appended after the board's last slot as it is written, skipping a
      // tank already on it: [slots] is the board as the tab last built it,
      // which an Add opened again before it refreshed would not show. Only
      // the slots written are counted.
      final created = await cylinders.appendCylinders(trip.id, [
        for (final t in tanks)
          tripCylinderDraftFromEquipment(
            t,
            tripId: trip.id,
            sortOrder: 0,
            now: now,
          ),
      ]);
      addedCount += created.length;
    }
    if (setName != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.trips_gear_packedFromSet(addedCount, setName)),
        ),
      );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to add trip gear', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
  }
}
