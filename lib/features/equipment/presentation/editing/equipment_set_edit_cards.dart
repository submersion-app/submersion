import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_editors.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_members_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The equipment set page's cards that can be edited in place (issue
/// #4527, phase 3), by card id, in page order.
final Map<EquipmentSetCardId, EditCard<EquipmentSet>> equipmentSetEditCards = {
  EquipmentSetCardId.header: EditCard<EquipmentSet>(
    id: EquipmentSetCardId.header.name,
    title: (context) =>
        EquipmentSetCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // A name, as the form's validator had it, trimmed.
    isValid: (session) => setNameValid(session.working.name),
    editorBuilder: (context, session) =>
        EquipmentSetHeaderEditor(session: session),
  ),
  EquipmentSetCardId.figure: EditCard<EquipmentSet>(
    id: EquipmentSetCardId.figure.name,
    title: (context) =>
        EquipmentSetCardId.figure.localizedDisplayName(context.l10n),
    // Left out while it is turned off, and offered in the strip.
    isEmpty: (s) => !s.showFigure,
    editorBuilder: (context, session) =>
        EquipmentSetFigureEditor(session: session),
  ),
  EquipmentSetCardId.members: EditCard<EquipmentSet>(
    id: EquipmentSetCardId.members.name,
    title: (context) =>
        EquipmentSetCardId.members.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        EquipmentSetMembersEditor(session: session),
  ),
  EquipmentSetCardId.bundle: EditCard<EquipmentSet>(
    id: EquipmentSetCardId.bundle.name,
    title: (context) =>
        EquipmentSetCardId.bundle.localizedDisplayName(context.l10n),
    isEmpty: (s) => !s.carriesBeyondGear,
    editorBuilder: (context, session) =>
        EquipmentSetBundleEditor(session: session),
  ),
  EquipmentSetCardId.geofences: EditCard<EquipmentSet>(
    id: EquipmentSetCardId.geofences.name,
    title: (context) =>
        EquipmentSetCardId.geofences.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        EquipmentSetGeofencesEditor(session: session),
  ),
};

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<EquipmentSetCardId> equipmentSetOptionalCards = [
  EquipmentSetCardId.figure,
  EquipmentSetCardId.bundle,
];
