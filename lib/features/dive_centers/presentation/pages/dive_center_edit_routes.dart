import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old dive centre edit address (`/dive-centers/<id>/edit`)
/// goes (issue #4527, phase 3): with [unlockEditing], the dive centre page
/// opened unlocked; null, keeping the edit form, otherwise.
String? diveCenterEditLocation(
  String centerId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/dive-centers/$centerId?mode=edit' : null;

/// The edit route's redirect: [diveCenterEditLocation] for its address.
String? diveCenterEditRedirect(BuildContext context, GoRouterState state) =>
    diveCenterEditLocation(state.pathParameters['centerId']!);

/// Where a full dive centre page reached directly moves to on a wide
/// screen: the list's pane, still asking to open unlocked when it was
/// ([openUnlocked]), so the unlock is not lost in the move.
String diveCenterPaneLocation(String centerId, {required bool openUnlocked}) =>
    openUnlocked
    ? '/dive-centers?selected=$centerId&mode=edit'
    : '/dive-centers?selected=$centerId';

/// The dive centres list's edit pane, as the master-detail scaffold's and
/// table mode's `editBuilder`: with [unlockEditing], the dive centre page
/// opened unlocked, back to the centre in view mode ([onCancel])
/// once its sitting ends; else the edit form as before.
Widget diveCenterEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return DiveCenterDetailPage(
      centerId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return DiveCenterEditPage(
    centerId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// The new-centre address (`/dive-centers/new`; issue #4527, phase 3, plan
/// 11): with [unlockEditing], the centre page opened unlocked on a new
/// centre, which pops its id; else the form, as before.
Widget newDiveCenterPage({bool unlockEditing = kUnlockRecordEditing}) =>
    unlockEditing
    ? const DiveCenterDetailPage.newDiveCenter()
    : const DiveCenterEditPage();

/// The centre list's new-centre pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: with [unlockEditing], the centre page on a
/// new centre, whose created id is handed to [onSaved]; else the form.
Widget newDiveCenterPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return DiveCenterDetailPage.newDiveCenter(
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );
  }
  return DiveCenterEditPage(
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// Opens a new dive centre from the centre list on a phone, its empty
/// state or the centre map: with [unlockEditing], the centre opens,
/// locked, once created, as a new site does (plan 11, Question 3); else
/// the form, as before.
Future<void> openNewDiveCenter(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  return openNewRecord(
    context,
    newLocation: '/dive-centers/new',
    recordLocation: (id) => '/dive-centers/$id',
    openCreated: unlockEditing,
  );
}
