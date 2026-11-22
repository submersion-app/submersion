import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old certification edit address (`/certifications/<id>/edit`)
/// goes (issue #4527, phase 3): the certification page opened unlocked.
String certificationEditLocation(String certificationId) =>
    '/certifications/$certificationId?mode=edit';

/// The edit route's redirect: [certificationEditLocation] for its address.
String? certificationEditRedirect(BuildContext context, GoRouterState state) =>
    certificationEditLocation(state.pathParameters['certificationId']!);

/// Where a full certification page reached directly moves to on a wide
/// screen: the list's pane, still asking to open unlocked when it was
/// ([openUnlocked]), so the unlock is not lost in the move.
String certificationPaneLocation(
  String certificationId, {
  required bool openUnlocked,
}) => openUnlocked
    ? '/certifications?selected=$certificationId&mode=edit'
    : '/certifications?selected=$certificationId';

/// The certifications list's edit pane, as the master-detail scaffold's and
/// table mode's `editBuilder`: the certification page opened unlocked, back
/// to the certification in view mode ([onCancel]) once its sitting ends.
/// [onSaved] is the scaffold's, and unused: a sitting saves in place.
Widget certificationEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => CertificationDetailPage(
  certificationId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The new-certification address (`/certifications/new`; issue #4527,
/// phase 3, plan 11): the certification page opened unlocked on a new
/// certification, which pops its id.
Widget newCertificationPage() =>
    const CertificationDetailPage.newCertification();

/// The certification list's new-certification pane (`?mode=new`), as the
/// master-detail scaffold's `createBuilder`: the page on a new
/// certification, whose created id is handed to [onSaved].
Widget newCertificationPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => CertificationDetailPage.newCertification(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new certification from the list on a phone, its empty state or
/// the wallet: the certification opens, locked, once created, as a new
/// site does (plan 11, Question 3).
Future<void> openNewCertification(BuildContext context) => openNewRecord(
  context,
  newLocation: '/certifications/new',
  recordLocation: (id) => '/certifications/$id',
);
