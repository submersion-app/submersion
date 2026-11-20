import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_new_sitting.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
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
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return DocumentDetailPage(
      documentId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return DocumentEditPage(
    documentId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// The new-document address (`/documents/new`, with `ownerKind`, `ownerId`
/// and `type` in [query]; issue #4527, phase 3, plan 11): with
/// [unlockEditing], the document page opened unlocked on a new document;
/// else the form, as before.
Widget newDocumentPage(
  Map<String, String> query, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  final request = NewDocumentRequest.fromQuery(query);
  if (unlockEditing) return DocumentDetailPage.newDocument(request: request);
  return DocumentEditPage(
    owner: request.owner ?? const DocumentOwner.personal(),
    initialType: request.type,
  );
}

/// The documents list's new-document pane (`?mode=new`), as the
/// master-detail scaffold's `createBuilder`, of [initialType] when the
/// list is filtered to one: with [unlockEditing], the document page on a
/// new document, whose created id is handed to [onSaved], which selects it;
/// else the form, as before.
Widget newDocumentPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  DocumentType? initialType,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return DocumentDetailPage.newDocument(
      request: NewDocumentRequest(type: initialType),
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );
  }
  return DocumentEditPage(
    embedded: true,
    initialType: initialType,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// Opens a new document, of [type] when given, from the documents list on
/// a phone: with [unlockEditing], the document opens, locked, once created,
/// as a new site does (plan 11, Question 3); else the form, as before.
Future<void> openNewDocument(
  BuildContext context, {
  DocumentType? type,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  final location = type == null
      ? '/documents/new'
      : '/documents/new?type=${type.storage}';
  if (!unlockEditing) return context.push(location);
  return openNewRecord(
    context,
    newLocation: location,
    recordLocation: (id) => '/documents/$id',
  );
}
