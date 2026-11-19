import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
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
