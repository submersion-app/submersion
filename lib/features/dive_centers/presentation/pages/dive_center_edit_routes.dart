import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old dive centre edit address (`/dive-centers/<id>/edit`)
/// goes (issue #4527, phase 3): the dive centre page opened unlocked.
String diveCenterEditLocation(String centerId) =>
    '/dive-centers/$centerId?mode=edit';

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
/// table mode's `editBuilder`: the dive centre page opened unlocked, back
/// to the centre in view mode ([onCancel]) once its sitting ends.
/// [onSaved] is the scaffold's, and unused: a sitting saves in place.
Widget diveCenterEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => DiveCenterDetailPage(
  centerId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The new-centre address (`/dive-centers/new`; issue #4527, phase 3, plan
/// 11): the centre page opened unlocked on a new centre, which pops its id.
Widget newDiveCenterPage() => const DiveCenterDetailPage.newDiveCenter();

/// The centre list's new-centre pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the centre page on a new centre, whose
/// created id is handed to [onSaved].
Widget newDiveCenterPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => DiveCenterDetailPage.newDiveCenter(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new dive centre from the centre list on a phone, its empty
/// state or the centre map: the centre opens, locked, once created, as a
/// new site does (plan 11, Question 3).
Future<void> openNewDiveCenter(BuildContext context) => openNewRecord(
  context,
  newLocation: '/dive-centers/new',
  recordLocation: (id) => '/dive-centers/$id',
);
