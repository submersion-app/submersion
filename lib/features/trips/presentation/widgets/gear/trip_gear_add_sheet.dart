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
import 'package:submersion/features/gear_passports/presentation/utils/scan_owned_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/services/trip_set_bundle.dart';

const _log = LoggerService('tripGearAddSheet');

enum _Way { equipment, set, scan, rental }

/// The Gear tab's one Add (#2845): a chooser that opens the equipment
/// picker, the set picker, a tag scan (#2652), or the rental cylinder form. A cylinder picked
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
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(l10n.trips_gear_add_scan),
            onTap: () => Navigator.of(sheet).pop(_Way.scan),
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
      final picked = await _pickItems(context, packed, slots);
      if (picked == null || picked.isEmpty || !context.mounted) return;
      await _apply(context, ref, trip, slots, picked, setName: null);
    case _Way.set:
      final picked = await _pickSet(context);
      if (picked == null || !context.mounted) return;
      final (set, items) = picked;
      // What the set carries besides gear (issue #4525): its cylinders are
      // slotted and its lead goes on the trip's checklist.
      SetBundle? bundle;
      try {
        bundle = await ref.read(setBundleProvider(set.id).future);
      } catch (_) {
        bundle = null;
      }
      if (!context.mounted) return;
      await _apply(
        context,
        ref,
        trip,
        slots,
        items,
        setName: set.name,
        bundle: bundle,
      );
    case _Way.scan:
      final item = await scanOwnedItem(context, ref);
      if (item == null || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final already =
          packed.any((p) => p.id == item.id) ||
          slots.any((s) => s.equipmentId == item.id);
      if (already) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.gearPassport_scan_alreadyOnTrip(item.name)),
          ),
        );
        return;
      }
      final added = await _apply(context, ref, trip, slots, [
        item,
      ], setName: null);
      // A failure already said so. Nothing new written means the item got
      // onto the trip after this tab last loaded.
      if (added == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? l10n.gearPassport_scan_added(item.name)
                : l10n.gearPassport_scan_alreadyOnTrip(item.name),
          ),
        ),
      );
    case _Way.rental:
      await showAddTripCylindersSheet(
        context,
        tripId: trip.id,
        existing: slots,
        rentalOnly: true,
      );
  }
}

/// The diver's gear not yet on the trip, ticked several at a time as in the
/// dive editor (#4205). Null when cancelled. Assembly parts are hidden, as a
/// packed assembly takes its parts along (#2727); retired gear is not
/// offered, since a trip looks ahead.
Future<List<EquipmentItem>?> _pickItems(
  BuildContext context,
  List<EquipmentItem> packed,
  List<TripCylinder> slots,
) => showModalBottomSheet<List<EquipmentItem>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
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
      hideAssemblyParts: true,
      onEquipmentConfirmed: (items) => Navigator.of(sheetContext).pop(items),
    ),
  ),
);

Future<(EquipmentSet, List<EquipmentItem>)?> _pickSet(BuildContext context) =>
    showModalBottomSheet<(EquipmentSet, List<EquipmentItem>)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
/// with the packed items (#2877). A failure is logged and said. Returns
/// how many items it packed or slotted, or null after a failure.
Future<int?> _apply(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  List<TripCylinder> slots,
  List<EquipmentItem> items, {
  required String? setName,
  SetBundle? bundle,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final checklists = ref.read(tripChecklistsRepositoryProvider);
  final checklistItems = ref.read(tripChecklistRepositoryProvider);
  final leadTitle = bundle == null || bundle.weights.isEmpty
      ? ''
      : l10n.trips_gear_leadItem(
          UnitFormatter(
            ref.read(settingsProvider),
          ).formatWeight(bundle.totalWeightKg),
        );
  final container = ProviderScope.containerOf(context);
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
    var leadSkipped = false;
    if (bundle != null) {
      final applied = await applySetBundleToTrip(
        bundle: bundle,
        tripId: trip.id,
        leadTitle: leadTitle,
        cylinders: cylinders,
        checklists: checklists,
        items: checklistItems,
        // The sheet is long gone; the tab's context asks, when it is still
        // there.
        pickChecklist: (all) async =>
            context.mounted ? pickTripChecklist(context, all) : null,
        now: DateTime.now().toUtc(),
      );
      addedCount += applied.slotted;
      leadSkipped = applied.lead == TripLeadOutcome.noChecklist;
      if (applied.lead == TripLeadOutcome.added) {
        // The lead item is something the set put on the trip too: without
        // it a set that carries only lead would report nothing to pack.
        addedCount += 1;
        container.invalidate(tripChecklistProvider);
        container.invalidate(tripChecklistAllItemsProvider);
      }
      if (applied.slotted > 0) container.invalidate(tripCylindersProvider);
    }
    if (setName != null) {
      final packed = l10n.trips_gear_packedFromSet(addedCount, setName);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            leadSkipped ? '$packed ${l10n.trips_gear_leadNoChecklist}' : packed,
          ),
        ),
      );
    }
    return addedCount;
  } catch (e, stackTrace) {
    _log.error('Failed to add trip gear', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
    return null;
  }
}

/// Asks which of the trip's [checklists] a set's lead goes on (issue #4525).
/// Null when the diver backs out.
Future<String?> pickTripChecklist(
  BuildContext context,
  List<TripChecklist> checklists,
) => showDialog<String>(
  context: context,
  builder: (dialogContext) => SimpleDialog(
    title: Text(dialogContext.l10n.trips_gear_pickChecklist),
    children: [
      for (final checklist in checklists)
        SimpleDialogOption(
          key: Key('trip-lead-checklist-${checklist.id}'),
          onPressed: () => Navigator.of(dialogContext).pop(checklist.id),
          child: Text(checklist.name),
        ),
    ],
  ),
);
