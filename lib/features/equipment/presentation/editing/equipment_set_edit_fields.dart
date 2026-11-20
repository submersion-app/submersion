import 'package:flutter/foundation.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_ids.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The equipment set page's values a sitting edits, and the rules its form
/// keeps (issue #4527, phase 3).

final String _header = EquipmentSetCardId.header.name;
final String _figure = EquipmentSetCardId.figure.name;
final String _members = EquipmentSetCardId.members.name;
final String _bundle = EquipmentSetCardId.bundle.name;
final String _geofences = EquipmentSetCardId.geofences.name;

/// The cards that draw the set's gear: the figure, the members and the
/// header's count follow any change to what the set applies.
final Set<String> _showsGear = {_header, _figure, _members};

/// Whether [name] can be saved: something besides spaces, since it is
/// stored trimmed.
bool setNameValid(String name) => name.trim().isNotEmpty;

/// The set's members as the diver left them, put onto the members as
/// stored at Save ([atSave]): only what the sitting added to or removed
/// from [atStart] is applied, so a member another device added meanwhile
/// stays. [atSave]'s order is kept, the sitting's additions after it.
List<String> rebasedSetMembers({
  required Iterable<String> atStart,
  required Iterable<String> held,
  required Iterable<String> atSave,
}) {
  final start = atStart.toSet();
  final kept = held.toSet();
  final removed = start.difference(kept);
  final result = [
    for (final id in atSave)
      if (!removed.contains(id)) id,
  ];
  final present = result.toSet();
  return [
    ...result,
    for (final id in held)
      if (!start.contains(id) && present.add(id)) id,
  ];
}

bool _sameGeofences(
  List<EquipmentSetGeofence> a,
  List<EquipmentSetGeofence> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].sameEdit(b[i])) return false;
  }
  return true;
}

/// The geofences as the diver left them, put onto those stored at Save
/// ([atSave]): fences the sitting removed from [atStart] go, those it
/// edited replace theirs by id, those it added follow. A fence deleted
/// underneath stays deleted, edited or not; one added underneath stays.
List<EquipmentSetGeofence> rebasedGeofences({
  required List<EquipmentSetGeofence> atStart,
  required List<EquipmentSetGeofence> held,
  required List<EquipmentSetGeofence> atSave,
}) {
  final startById = {for (final g in atStart) g.id: g};
  final heldById = {for (final g in held) g.id: g};
  final result = <EquipmentSetGeofence>[];
  for (final g in atSave) {
    final wasThere = startById[g.id];
    final mine = heldById[g.id];
    if (wasThere != null && mine == null) continue;
    final edited = wasThere != null && mine != null && !wasThere.sameEdit(mine);
    result.add(edited ? mine : g);
  }
  final present = {for (final g in result) g.id};
  return [
    ...result,
    for (final g in held)
      if (!startById.containsKey(g.id) && present.add(g.id)) g,
  ];
}

/// The set's own members in a sitting: what the diver holds ([held]), and
/// the members as stored when they first changed them ([base]), so Save
/// can apply only their change.
typedef SetMembersEdit = ({Set<String> base, Set<String> held});

/// The set's geofences in a sitting, held the same way as its members.
typedef SetGeofencesEdit = ({
  List<EquipmentSetGeofence> base,
  List<EquipmentSetGeofence> held,
});

/// The set's name, required, shown in the bar and the header block.
final setNameField = EditField<EquipmentSet, String>(
  id: 'name',
  cardId: _header,
  alsoShownOn: {_figure},
  read: (s) => s.name,
  write: (s, v) => s.copyWith(name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final setDescriptionField = EditField<EquipmentSet, String>(
  id: 'description',
  cardId: _header,
  read: (s) => s.description,
  write: (s, v) => s.copyWith(description: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// Whether this is the diver's default set. Turning it on demotes their
/// other default at Save.
final setDefaultField = EditField<EquipmentSet, bool>(
  id: 'isDefault',
  cardId: _header,
  read: (s) => s.isDefault,
  write: (s, v) => s.copyWith(isDefault: v),
);

final setAutoApplyField = EditField<EquipmentSet, bool>(
  id: 'autoApplyOnComputerImport',
  cardId: _header,
  read: (s) => s.autoApplyOnComputerImport,
  write: (s, v) => s.copyWith(autoApplyOnComputerImport: v),
);

final setShowFigureField = EditField<EquipmentSet, bool>(
  id: 'showFigure',
  cardId: _figure,
  alsoShownOn: {_members},
  read: (s) => s.showFigure,
  write: (s, v) => s.copyWith(showFigure: v),
);

/// The set's own members. Their order carries no meaning.
final setMembersField = EditField<EquipmentSet, SetMembersEdit>(
  id: 'equipmentIds',
  cardId: _members,
  alsoShownOn: _showsGear,
  read: (s) {
    final ids = s.equipmentIds.toSet();
    return (base: ids, held: ids);
  },
  write: (s, v) => s.copyWith(
    equipmentIds: rebasedSetMembers(
      atStart: v.base,
      held: v.held,
      atSave: s.equipmentIds,
    ),
  ),
  equals: (a, b) => setEquals(a.held, b.held),
);

/// The sets this set includes, in order. With the weight presets and the
/// cylinder configurations, the Bundle card's lists. Each is a field of its
/// own, so one the diver did not touch keeps what another device wrote; a
/// list they changed is written as they left it, its order mattering.
final setIncludedSetsField = EditField<EquipmentSet, List<String>>(
  id: 'includedSetIds',
  cardId: _bundle,
  // What a set includes is gear it applies.
  alsoShownOn: _showsGear,
  read: (s) => s.includedSetIds,
  write: (s, v) => s.copyWith(includedSetIds: v),
  equals: listEquals,
);

final setWeightPresetsField = EditField<EquipmentSet, List<String>>(
  id: 'weightPresetIds',
  cardId: _bundle,
  read: (s) => s.weightPresetIds,
  write: (s, v) => s.copyWith(weightPresetIds: v),
  equals: listEquals,
);

final setCylinderConfigsField = EditField<EquipmentSet, List<String>>(
  id: 'cylinderConfigIds',
  cardId: _bundle,
  read: (s) => s.cylinderConfigIds,
  write: (s, v) => s.copyWith(cylinderConfigIds: v),
  equals: listEquals,
);

/// The Bundle card's three lists as [session] holds them.
SetBundleListValues bundleListsOf(EditSession<EquipmentSet> session) =>
    SetBundleListValues(
      includedSetIds: session.valueOf(setIncludedSetsField),
      weightPresetIds: session.valueOf(setWeightPresetsField),
      cylinderConfigIds: session.valueOf(setCylinderConfigsField),
    );

/// Holds [lists], the Bundle editor's change, list by list.
void setBundleLists(
  EditSession<EquipmentSet> session,
  SetBundleListValues lists,
) {
  session
    ..set(setIncludedSetsField, lists.includedSetIds)
    ..set(setWeightPresetsField, lists.weightPresetIds)
    ..set(setCylinderConfigsField, lists.cylinderConfigIds);
}

final setGeofencesField = EditField<EquipmentSet, SetGeofencesEdit>(
  id: 'geofences',
  cardId: _geofences,
  read: (s) => (base: s.geofences, held: s.geofences),
  write: (s, v) => s.copyWith(
    geofences: rebasedGeofences(
      atStart: v.base,
      held: v.held,
      atSave: s.geofences,
    ),
  ),
  equals: (a, b) => _sameGeofences(a.held, b.held),
);

/// The members [session] holds with [equipmentId] ticked or not, keeping
/// the base the sitting's first change took.
SetMembersEdit membersTicked(
  EditSession<EquipmentSet> session,
  String equipmentId,
  bool ticked,
) {
  final current = session.valueOf(setMembersField);
  return (
    base: current.base,
    held: {
      for (final id in current.held)
        if (id != equipmentId) id,
      if (ticked) equipmentId,
    },
  );
}

/// The geofences [session] holds replaced by [next], keeping the base the
/// sitting's first change took.
SetGeofencesEdit geofencesEdited(
  EditSession<EquipmentSet> session,
  List<EquipmentSetGeofence> next,
) => (base: session.valueOf(setGeofencesField).base, held: next);

/// The gear [working] applies, as a sitting has it (Question 4): its own
/// members and those of the sets it includes, in the order the set page
/// reads them. Each is read from [everyItem], the diver's gear, or else
/// from [storedItems], what the stored set applies (a member no longer
/// shared with the diver is only there); one found in neither is left out.
List<EquipmentItem> setItemsInSitting(
  EquipmentSet working, {
  required List<EquipmentItem> storedItems,
  required List<EquipmentItem> everyItem,
  required List<EquipmentSet> allSets,
}) {
  final setsById = {for (final s in allSets) s.id: s, working.id: working};
  final every = {for (final item in everyItem) item.id: item};
  final kept = {for (final item in storedItems) item.id: item};
  return [
    for (final id in SetBundleResolver.effectiveGearIds(working, setsById))
      ?(every[id] ?? kept[id]),
  ];
}
