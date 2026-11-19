import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old document edit address (`/documents/<id>/edit`) goes (issue
/// #4527, phase 3): with [unlockEditing], the document page opened
/// unlocked; null, keeping the edit form, otherwise.
String? documentEditLocation(
  String documentId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/documents/$documentId?mode=edit' : null;

/// The edit route's redirect: [documentEditLocation] for its address.
String? documentEditRedirect(BuildContext context, GoRouterState state) =>
    documentEditLocation(state.pathParameters['documentId']!);

/// Where a full document page reached directly moves to on a wide screen:
/// the list's pane, still asking to open unlocked when it was
/// ([openUnlocked]), so the unlock is not lost in the move.
String documentPaneLocation(String documentId, {required bool openUnlocked}) =>
    openUnlocked
    ? '/documents?selected=$documentId&mode=edit'
    : '/documents?selected=$documentId';

/// The documents list's edit pane, as the master-detail scaffold's
/// `editBuilder`: with [unlockEditing], the document page opened unlocked,
/// back to the document in view mode ([onCancel]) once its sitting ends;
/// else the edit form as before.
Widget documentEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return DocumentDetailPage(
      documentId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
    );
  }
  return DocumentEditPage(
    documentId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}
