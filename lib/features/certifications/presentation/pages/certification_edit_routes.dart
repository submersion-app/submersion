import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old certification edit address (`/certifications/<id>/edit`)
/// goes (issue #4527, phase 3): with [unlockEditing], the certification
/// page opened unlocked; null, keeping the edit form, otherwise.
String? certificationEditLocation(
  String certificationId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/certifications/$certificationId?mode=edit' : null;

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
/// table mode's `editBuilder`: with [unlockEditing], the certification page
/// opened unlocked, back to the certification in view mode ([onCancel])
/// once its sitting ends; else the edit form as before.
Widget certificationEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return CertificationDetailPage(
      certificationId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return CertificationEditPage(
    certificationId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// The new-certification address (`/certifications/new`; issue #4527,
/// phase 3, plan 11): with [unlockEditing], the certification page opened
/// unlocked on a new certification, which pops its id; else the form.
Widget newCertificationPage({bool unlockEditing = kUnlockRecordEditing}) =>
    unlockEditing
    ? const CertificationDetailPage.newCertification()
    : const CertificationEditPage();

/// The certification list's new-certification pane (`?mode=new`), as the
/// master-detail scaffold's `createBuilder`: with [unlockEditing], the
/// page on a new certification, whose created id is handed to [onSaved];
/// else the form.
Widget newCertificationPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return CertificationDetailPage.newCertification(
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );
  }
  return CertificationEditPage(
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// Opens a new certification from the list on a phone, its empty state or
/// the wallet: with [unlockEditing], the certification opens, locked, once
/// created, as a new site does (plan 11, Question 3); else the form.
Future<void> openNewCertification(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (!unlockEditing) return context.push('/certifications/new');
  return openNewRecord(
    context,
    newLocation: '/certifications/new',
    recordLocation: (id) => '/certifications/$id',
  );
}
