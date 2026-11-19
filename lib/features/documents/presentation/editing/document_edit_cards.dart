import 'package:submersion/features/documents/presentation/editing/document_card_ids.dart';
import 'package:submersion/features/documents/presentation/editing/document_details_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_pages_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The document page's cards that can be edited in place (issue #4527,
/// phase 3), by card id, in page order.
final Map<DocumentCardId, EditCard<DocumentRecord>> documentEditCards = {
  DocumentCardId.pages: EditCard<DocumentRecord>(
    id: DocumentCardId.pages.name,
    title: (context) => DocumentCardId.pages.localizedDisplayName(context.l10n),
    isEmpty: (r) => r.pages.isEmpty,
    editorBuilder: (context, session) =>
        DocumentPagesCardEditor(session: session),
  ),
  DocumentCardId.details: EditCard<DocumentRecord>(
    id: DocumentCardId.details.name,
    title: (context) =>
        DocumentCardId.details.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DocumentDetailsCardEditor(session: session),
  ),
};
