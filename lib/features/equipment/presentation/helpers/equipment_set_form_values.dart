import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// What the set form would save, compared with what it opened with to tell
/// whether Back would lose anything (issue #2156). A change put back as it
/// was is no change.
///
/// Compared as the save writes it: text trimmed, members as a set, and each
/// geofence by what the diver can edit, not by the timestamps the editor
/// stamps on every save of it.
class EquipmentSetFormValues extends Equatable {
  final String name;
  final String description;
  final Set<String> equipmentIds;
  final bool isDefault;
  final bool autoApplyOnComputerImport;
  final bool showFigure;
  final List<EquipmentSetGeofence> geofences;

  const EquipmentSetFormValues({
    required this.name,
    required this.description,
    required this.equipmentIds,
    required this.isDefault,
    required this.autoApplyOnComputerImport,
    required this.showFigure,
    required this.geofences,
  });

  /// A new set's form before anything is entered.
  static const blank = EquipmentSetFormValues(
    name: '',
    description: '',
    equipmentIds: {},
    isDefault: false,
    autoApplyOnComputerImport: false,
    showFigure: true,
    geofences: [],
  );

  /// The form as it opens on [set].
  factory EquipmentSetFormValues.of(EquipmentSet set) => EquipmentSetFormValues(
    name: set.name,
    description: set.description,
    equipmentIds: set.equipmentIds.toSet(),
    isDefault: set.isDefault,
    autoApplyOnComputerImport: set.autoApplyOnComputerImport,
    showFigure: set.showFigure,
    geofences: set.geofences,
  );

  /// These values with only the members [keep] accepts, for when the form
  /// drops gear deleted while it is open: the diver did not remove it, so it
  /// must not count as their change.
  EquipmentSetFormValues retainingEquipment(bool Function(String id) keep) =>
      EquipmentSetFormValues(
        name: name,
        description: description,
        equipmentIds: equipmentIds.where(keep).toSet(),
        isDefault: isDefault,
        autoApplyOnComputerImport: autoApplyOnComputerImport,
        showFigure: showFigure,
        geofences: geofences,
      );

  @override
  List<Object?> get props => [
    name.trim(),
    description.trim(),
    equipmentIds,
    isDefault,
    autoApplyOnComputerImport,
    showFigure,
    [
      for (final g in geofences)
        (g.id, g.label, g.latitude, g.longitude, g.radiusMeters),
    ],
  ];
}
