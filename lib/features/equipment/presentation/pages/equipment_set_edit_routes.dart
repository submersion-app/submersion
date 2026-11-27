import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// The sets pane's edit builder, as the master-detail scaffold takes it.
typedef EquipmentSetPaneEditBuilder =
    Widget Function(
      BuildContext context,
      String setId,
      void Function(String savedId) onSaved,
      VoidCallback onCancel,
    );

/// Where the old set edit address (`/equipment/sets/<id>/edit`) goes (issue
/// #4527, phase 3): the set page opened unlocked.
String equipmentSetEditLocation(String setId) =>
    '/equipment/sets/$setId?mode=edit';

/// The edit route's redirect: [equipmentSetEditLocation] for its address.
String? equipmentSetEditRedirect(BuildContext context, GoRouterState state) =>
    equipmentSetEditLocation(state.pathParameters['setId']!);

/// The sets pane's edit mode (`?setSelected=<id>&mode=edit`): the set page
/// opened unlocked, back to the set in view ([onCancel]) once its sitting
/// ends, saved or cancelled.
EquipmentSetPaneEditBuilder equipmentSetsPaneEditBuilder() =>
    (context, setId, onSaved, onCancel) => EquipmentSetDetailPage(
      setId: setId,
      openUnlocked: true,
      onSittingEnded: onCancel,
    );

/// The new-set address (`/equipment/sets/new`, `?cloneFrom=` for a clone;
/// issue #4527, phase 3, plan 11): the set page opened unlocked on a new
/// set or a clone, which pops its id.
Widget newEquipmentSetPage({String? cloneFromId}) =>
    EquipmentSetDetailPage.newSet(cloneFromId: cloneFromId);

/// Opens a new set from the sets list on a phone or its empty state: the
/// set opens, locked, once created, as a new site does (plan 11,
/// Question 3).
Future<void> openNewEquipmentSet(BuildContext context) => openNewRecord(
  context,
  newLocation: '/equipment/sets/new',
  recordLocation: (id) => '/equipment/sets/$id',
);
