import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
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
