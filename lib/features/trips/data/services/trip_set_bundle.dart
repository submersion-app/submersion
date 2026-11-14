import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

/// What became of a set's lead when the set was added to a trip.
enum TripLeadOutcome {
  /// The set carries no lead, or the diver backed out of choosing a
  /// checklist.
  none,
  added,

  /// The checklist already lists it.
  alreadyListed,

  /// The trip has no checklist to put it on.
  noChecklist,
}

/// What adding a set's bundle to a trip did.
typedef TripSetBundleResult = ({int slotted, TripLeadOutcome lead});

/// Cylinder slots for what [bundle] carries: each described by its label
/// (else its mix), size, pressure and material, with no link to a gear
/// item. A cylinder the board already has as such a slot is left out, one
/// for one, so adding a set twice adds nothing.
List<TripCylinder> tripCylinderDraftsFromBundle(
  SetBundle bundle, {
  required String tripId,
  required List<TripCylinder> existing,
  required DateTime now,
}) {
  // Only slots that are not one of the diver's own tanks can be the set's.
  final unclaimed = [
    for (final slot in existing)
      if (slot.equipmentId == null) slot,
  ];
  final drafts = <TripCylinder>[];
  for (final item in bundle.cylinders) {
    final draft = TripCylinder(
      id: '',
      tripId: tripId,
      label: _labelOf(item),
      volume: item.volumeL,
      workingPressure: item.workingPressureBar,
      material: item.tankMaterial,
      createdAt: now,
      updatedAt: now,
    );
    final match = unclaimed.indexWhere((slot) => _sameSlot(slot, draft));
    if (match >= 0) {
      unclaimed.removeAt(match);
    } else {
      drafts.add(draft);
    }
  }
  return drafts;
}

String _labelOf(CylinderConfigItem item) {
  final label = item.label?.trim() ?? '';
  return label.isNotEmpty
      ? label
      : GasMix(o2: item.o2Percent, he: item.hePercent).name;
}

bool _sameSlot(TripCylinder a, TripCylinder b) =>
    a.label == b.label &&
    a.material == b.material &&
    _near(a.volume, b.volume, 0.01) &&
    _near(a.workingPressure, b.workingPressure, 0.5);

bool _near(double? a, double? b, double tolerance) =>
    a == null || b == null ? a == b : (a - b).abs() <= tolerance;

/// Puts what [bundle] carries on trip [tripId] (issue #4525): its
/// cylinders as slots after the board's last, and its lead as an item
/// titled [leadTitle] on the trip's checklist. With several checklists
/// [pickChecklist] chooses one (null backs out); with none the lead is
/// left off, since a trip's packing list holds only gear items.
Future<TripSetBundleResult> applySetBundleToTrip({
  required SetBundle bundle,
  required String tripId,
  required String leadTitle,
  required TripCylinderRepository cylinders,
  required TripChecklistsRepository checklists,
  required TripChecklistRepository items,
  required Future<String?> Function(List<TripChecklist> checklists)
  pickChecklist,
  required DateTime now,
}) async {
  var slotted = 0;
  if (bundle.cylinders.isNotEmpty) {
    final drafts = tripCylinderDraftsFromBundle(
      bundle,
      tripId: tripId,
      existing: await cylinders.getCylindersForTrip(tripId),
      now: now,
    );
    if (drafts.isNotEmpty) {
      slotted = (await cylinders.appendCylinders(tripId, drafts)).length;
    }
  }
  if (bundle.weights.isEmpty) {
    return (slotted: slotted, lead: TripLeadOutcome.none);
  }
  final all = await checklists.getChecklistsForTrip(tripId);
  if (all.isEmpty) {
    return (slotted: slotted, lead: TripLeadOutcome.noChecklist);
  }
  final checklistId = all.length == 1
      ? all.single.id
      : await pickChecklist(all);
  if (checklistId == null) {
    return (slotted: slotted, lead: TripLeadOutcome.none);
  }
  final listed = await items.getByChecklistId(checklistId);
  if (listed.any((item) => item.title == leadTitle)) {
    return (slotted: slotted, lead: TripLeadOutcome.alreadyListed);
  }
  await items.createItem(
    TripChecklistItem(
      id: '',
      checklistId: checklistId,
      title: leadTitle,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return (slotted: slotted, lead: TripLeadOutcome.added);
}
