import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// The sets pane's edit builder, as the master-detail scaffold takes it.
typedef EquipmentSetPaneEditBuilder =
    Widget Function(
      BuildContext context,
      String setId,
      void Function(String savedId) onSaved,
      VoidCallback onCancel,
    );

/// Where the old set edit address (`/equipment/sets/<id>/edit`) goes (issue
/// #4527, phase 3): with [unlockEditing], the set page opened unlocked;
/// null, keeping the edit form, otherwise.
String? equipmentSetEditLocation(
  String setId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/equipment/sets/$setId?mode=edit' : null;

/// The edit route's redirect: [equipmentSetEditLocation] for its address.
String? equipmentSetEditRedirect(BuildContext context, GoRouterState state) =>
    equipmentSetEditLocation(state.pathParameters['setId']!);

/// The sets pane's edit mode (`?setSelected=<id>&mode=edit`): with
/// [unlockEditing], the set page opened unlocked, back to the set in view
/// ([onCancel]) once its sitting ends, saved or cancelled. Without it the
/// pane has no edit mode, as before: its Edit pushes the form.
EquipmentSetPaneEditBuilder? equipmentSetsPaneEditBuilder({
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing
    ? (context, setId, onSaved, onCancel) => EquipmentSetDetailPage(
        setId: setId,
        unlockEditing: unlockEditing,
        openUnlocked: true,
        onSittingEnded: onCancel,
      )
    : null;

/// The new-set address (`/equipment/sets/new`, `?cloneFrom=` for a clone;
/// issue #4527, phase 3, plan 11): with [unlockEditing], the set page
/// opened unlocked on a new set or a clone, which pops its id; else the
/// form, as before.
Widget newEquipmentSetPage({
  String? cloneFromId,
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing
    ? EquipmentSetDetailPage.newSet(cloneFromId: cloneFromId)
    : EquipmentSetEditPage(cloneFromId: cloneFromId);

/// Opens a new set from the sets list on a phone or its empty state: with
/// [unlockEditing], the set opens, locked, once created, as a new site
/// does (plan 11, Question 3); else the form, as before.
Future<void> openNewEquipmentSet(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) => openNewRecord(
  context,
  newLocation: '/equipment/sets/new',
  recordLocation: (id) => '/equipment/sets/$id',
  openCreated: unlockEditing,
);
