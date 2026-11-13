import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/widgets/geofence_editor_sheet.dart';

/// The set form's geofences with [draft] added as a new fence of [setId]
/// (empty for a set not saved yet; the save fills it in).
List<EquipmentSetGeofence> withAddedGeofence(
  List<EquipmentSetGeofence> fences,
  GeofenceDraft draft, {
  required String setId,
}) {
  final now = DateTime.now();
  return [
    ...fences,
    EquipmentSetGeofence(
      id: const Uuid().v4(),
      setId: setId,
      label: draft.label,
      latitude: draft.latitude,
      longitude: draft.longitude,
      radiusMeters: draft.radiusMeters,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

/// The set form's geofences with the one at [index] replaced by [draft].
/// Its id, set and creation time are kept, so the save treats it as an
/// update, not a new fence. Rebuilt rather than copied, so a cleared label
/// (`draft.label == null`) is honoured instead of keeping the old one.
List<EquipmentSetGeofence> withEditedGeofence(
  List<EquipmentSetGeofence> fences,
  int index,
  GeofenceDraft draft,
) {
  return [
    for (var i = 0; i < fences.length; i++)
      if (i == index)
        EquipmentSetGeofence(
          id: fences[i].id,
          setId: fences[i].setId,
          label: draft.label,
          latitude: draft.latitude,
          longitude: draft.longitude,
          radiusMeters: draft.radiusMeters,
          createdAt: fences[i].createdAt,
          updatedAt: DateTime.now(),
        )
      else
        fences[i],
  ];
}

/// The set form's geofences without the one at [index].
List<EquipmentSetGeofence> withoutGeofence(
  List<EquipmentSetGeofence> fences,
  int index,
) => [
  for (var i = 0; i < fences.length; i++)
    if (i != index) fences[i],
];
