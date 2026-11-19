import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_add.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Where a document page's new pages come from; a seam for tests.
final documentPageCaptureProvider = Provider<DocumentPageCapture>(
  (ref) => DocumentPageCapture(),
);

/// The document's Pages card editor (issue #4527, phase 3): the page strip
/// over the sitting's pages. Adding, reordering and removing are held until
/// Save; a card or an insurance keeps its front and back slots.
class DocumentPagesCardEditor extends ConsumerWidget {
  const DocumentPagesCardEditor({super.key, required this.session});

  final EditSession<DocumentRecord> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capture = ref.watch(documentPageCaptureProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final type = session.valueOf(documentTypeField);
        return DocumentPageStrip(
          pages: session.valueOf(documentPagesField),
          cardSlots:
              type == DocumentType.insurance ||
              type == DocumentType.certificationCard,
          onChanged: (pages) => session.set(documentPagesField, pages),
          onAdd: (side) async {
            final next = await addDocumentPage(
              context,
              capture: capture,
              pages: session.valueOf(documentPagesField),
              side: side,
            );
            if (next != null && !session.isDisposed) {
              session.set(documentPagesField, next);
            }
          },
        );
      },
    );
  }
}
