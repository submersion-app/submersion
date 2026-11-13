import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

/// The set the Clone form starts from (issue #2156): [source] with no id or
/// owner (the save assigns them) and the name from [copyName]. The
/// description, members and figure preference are kept.
///
/// What would make the clone compete with its source is left behind: the
/// default flag (one per diver), computer auto-apply (two opted-in sets that
/// share a computer are both applied, so an import would get both rosters)
/// and geofences (a copied fence ties with the source's). The diver can turn
/// any of them on in the form before saving.
EquipmentSet equipmentSetCloneSeed(
  EquipmentSet source, {
  required String Function(String name) copyName,
}) {
  final now = DateTime.now();
  return EquipmentSet(
    id: '',
    name: copyName(source.name),
    description: source.description,
    equipmentIds: List.of(source.equipmentIds),
    showFigure: source.showFigure,
    createdAt: now,
    updatedAt: now,
  );
}
