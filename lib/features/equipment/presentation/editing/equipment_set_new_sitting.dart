import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_clone_seed.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

/// A new equipment set's sitting (issue #4527, phase 3, plan 11): its seed,
/// a clone's copy of another set, the cards laid out open, and the
/// clone's copy put on as changes.

/// A new set's starting record under [id]: the active diver's, with no
/// name, showing the diver figure, as the form started one.
Future<EquipmentSet> newEquipmentSetSeed(
  RecordSeedRead read, {
  required String id,
}) async {
  final diverId = await newRecordDiverId(read, record: 'equipment set');
  final now = DateTime.now();
  return EquipmentSet(
    id: id,
    diverId: diverId,
    name: '',
    createdAt: now,
    updatedAt: now,
  );
}

/// What a clone of [setId] copies ([equipmentSetCloneSeed], named by
/// [copyName]), with only the members the active diver can see; null when
/// the set is gone or not the diver's.
Future<EquipmentSet?> readSetClone(
  RecordSeedRead read,
  String setId, {
  required String Function(String name) copyName,
}) async {
  final source = await read(equipmentSetCloneSourceProvider(setId).future);
  if (source == null) return null;
  final copy = equipmentSetCloneSeed(source, copyName: copyName);
  final visible = {
    for (final item in await read(allEquipmentProvider.future)) item.id,
  };
  return copy.copyWith(
    equipmentIds: [
      for (final id in copy.equipmentIds)
        if (visible.contains(id)) id,
    ],
  );
}

/// The cards a new set opens with: the header block and Members, and the
/// Bundle when a clone carries one.
List<String> newEquipmentSetLaidOut({EquipmentSet? clone}) => [
  EquipmentSetCardId.header.name,
  EquipmentSetCardId.members.name,
  if (clone != null && clone.carriesBeyondGear) EquipmentSetCardId.bundle.name,
];

/// Puts [clone]'s copy on [session], each through its card's field, so
/// each is a change.
void applyNewEquipmentSetPrefill(
  EditSession<EquipmentSet> session,
  EquipmentSet? clone,
) {
  if (clone == null || session.isDisposed || session.isFrozen) return;
  session
    ..set(setNameField, clone.name)
    ..set(setDescriptionField, clone.description)
    ..set(setMembersField, (
      base: session.valueOf(setMembersField).base,
      held: clone.equipmentIds.toSet(),
    ))
    ..set(setIncludedSetsField, clone.includedSetIds)
    ..set(setWeightPresetsField, clone.weightPresetIds)
    ..set(setCylinderConfigsField, clone.cylinderConfigIds)
    ..set(setShowFigureField, clone.showFigure);
}
