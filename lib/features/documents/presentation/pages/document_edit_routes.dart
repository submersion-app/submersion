import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_new_sitting.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old document edit address (`/documents/<id>/edit`) goes (issue
/// #4527, phase 3): the document page opened unlocked.
String documentEditLocation(String documentId) =>
    '/documents/$documentId?mode=edit';

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
/// `editBuilder`: the document page opened unlocked, back to the document
/// in view mode ([onCancel]) once its sitting ends. [onSaved] is the
/// scaffold's, and unused: a sitting saves in place.
Widget documentEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => DocumentDetailPage(
  documentId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The new-document address (`/documents/new`, with `ownerKind`, `ownerId`
/// and `type` in [query]; issue #4527, phase 3, plan 11): the document page
/// opened unlocked on a new document.
Widget newDocumentPage(Map<String, String> query) =>
    DocumentDetailPage.newDocument(
      request: NewDocumentRequest.fromQuery(query),
    );

/// The documents list's new-document pane (`?mode=new`), as the
/// master-detail scaffold's `createBuilder`, of [initialType] when the
/// list is filtered to one: the document page on a new document, whose
/// created id is handed to [onSaved], which selects it.
Widget newDocumentPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  DocumentType? initialType,
}) => DocumentDetailPage.newDocument(
  request: NewDocumentRequest(type: initialType),
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new document, of [type] when given, from the documents list on
/// a phone: the document opens, locked, once created, as a new site does
/// (plan 11, Question 3).
Future<void> openNewDocument(BuildContext context, {DocumentType? type}) {
  final location = type == null
      ? '/documents/new'
      : '/documents/new?type=${type.storage}';
  return openNewRecord(
    context,
    newLocation: location,
    recordLocation: (id) => '/documents/$id',
  );
}
