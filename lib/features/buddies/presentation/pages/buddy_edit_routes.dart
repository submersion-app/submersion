import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_new_sitting.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old buddy edit address (`/buddies/<id>/edit`) goes (issue
/// #4527, phase 3): the buddy page opened unlocked.
String buddyEditLocation(String buddyId) => '/buddies/$buddyId?mode=edit';

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
/// mode's `editBuilder`: the buddy page opened unlocked, back to the buddy
/// in view mode ([onCancel]) once its sitting ends. [onSaved] is the
/// scaffold's, and unused: a sitting saves in place.
Widget buddyEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => BuddyDetailPage(
  buddyId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The ids a merge address carries (`state.extra`), or none.
List<String> buddyMergeIds(Object? extra) => extra is List
    ? [for (final id in extra) ?(id is String ? id : null)]
    : const [];

/// The merge address's redirect (issue #4527, phase 3): back to the buddy
/// list when it does not carry two or more buddies to merge, as the site
/// merge does.
String? buddyMergeRedirect(BuildContext context, GoRouterState state) =>
    buddyMergeIds(state.extra).length < 2 ? '/buddies' : null;

/// The new-buddy address (`/buddies/new`, with Import from contacts' map
/// as [extra]; issue #4527, phase 3, plan 11): the buddy page opened
/// unlocked on a new buddy, which pops the buddy it created.
Widget newBuddyPage(Object? extra) =>
    BuddyDetailPage.newBuddy(seed: NewBuddySeed.fromRouteExtra(extra));

/// The buddy list's new-buddy pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the buddy page on a new buddy, whose created
/// id is handed to [onSaved].
Widget newBuddyPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => BuddyDetailPage.newBuddy(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new buddy, with [seed] (a contact), from the buddy list on a
/// phone, its empty state or Import from contacts: the buddy opens,
/// locked, once created, as a new site does (plan 11, Question 3).
Future<void> openNewBuddy(BuildContext context, {NewBuddySeed? seed}) {
  final extra = seed == null
      ? null
      : {
          'name': seed.name,
          'email': seed.email,
          'phone': seed.phone,
          'photo': seed.photo,
        };
  return openNewRecord(
    context,
    newLocation: '/buddies/new',
    extra: extra,
    recordLocation: (id) => '/buddies/$id',
    idOf: (popped) => popped is Buddy ? popped.id : poppedId(popped),
  );
}
