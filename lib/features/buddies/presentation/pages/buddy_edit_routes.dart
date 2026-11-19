import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old buddy edit address (`/buddies/<id>/edit`) goes (issue
/// #4527, phase 3): with [unlockEditing], the buddy page opened unlocked;
/// null, keeping the edit form, otherwise.
String? buddyEditLocation(
  String buddyId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/buddies/$buddyId?mode=edit' : null;

/// The edit route's redirect: [buddyEditLocation] for its address.
String? buddyEditRedirect(BuildContext context, GoRouterState state) =>
    buddyEditLocation(state.pathParameters['buddyId']!);

/// Where a full buddy page reached directly moves to on a wide screen: the
/// list's pane, still asking to open unlocked when it was ([openUnlocked]).
String buddyPaneLocation(String buddyId, {required bool openUnlocked}) =>
    openUnlocked
    ? '/buddies?selected=$buddyId&mode=edit'
    : '/buddies?selected=$buddyId';

/// The buddies list's edit pane, as the master-detail scaffold's and table
/// mode's `editBuilder`: with [unlockEditing], the buddy page opened
/// unlocked, back to the buddy in view mode ([onCancel]) once its sitting
/// ends; else the edit form as before.
Widget buddyEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return BuddyDetailPage(
      buddyId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return BuddyEditPage(
    buddyId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// The ids a merge address carries (`state.extra`), or none.
List<String> buddyMergeIds(Object? extra) => extra is List
    ? [for (final id in extra) ?(id is String ? id : null)]
    : const [];

/// The merge address's redirect (issue #4527, phase 3): back to the buddy
/// list when it does not carry two or more buddies to merge, as the site
/// merge does.
String? buddyMergeRedirect(BuildContext context, GoRouterState state) =>
    buddyMergeIds(state.extra).length < 2 ? '/buddies' : null;
