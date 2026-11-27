import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_card_ids.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

const _log = LoggerService('DocumentNewSitting');

/// A new document's sitting (issue #4527, phase 3, plan 11): what its
/// opener asks for, its seed, the cards laid out open, and what the opener
/// brings put on the sitting as changes.

/// What a new document's page was opened with. [owner] and [type] are
/// seeds, changes of the Details card (a filtered list's type, the medical
/// page's clearance, the record whose Documents section asked). With
/// [ownerFixed] (another record's open Documents card, which holds the
/// link itself) the owner is not offered and the document is created as
/// Personal, as the form's `ownerFixed` does.
@immutable
class NewDocumentRequest {
  const NewDocumentRequest({this.owner, this.type, this.ownerFixed = false});

  /// The request in a new document's address, as `/documents/new` reads
  /// it: `ownerKind` with `ownerId`, and `type`.
  factory NewDocumentRequest.fromQuery(Map<String, String> query) {
    final kind = DocumentOwnerKind.fromStorage(query['ownerKind']);
    final ownerId = query['ownerId'];
    return NewDocumentRequest(
      owner: kind == DocumentOwnerKind.personal || ownerId == null
          ? null
          : DocumentOwner(kind, ownerId),
      type: DocumentType.values.asNameMap()[query['type']],
    );
  }

  final DocumentOwner? owner;
  final DocumentType? type;
  final bool ownerFixed;
}

/// A new document's starting record under [id]: the active diver's,
/// Personal, of no particular type, with the default reminder lead, no
/// pages and no tags. It is primary when the diver has no primary
/// insurance yet, which counts only should it become insurance, as the
/// form decides it. A diver that cannot be read leaves no diver, for Save
/// to take the one active then.
Future<DocumentRecord> newDocumentSeed(
  RecordSeedRead read, {
  required String id,
}) async {
  final diverId = await newRecordDiverId(read, record: 'document');
  var primary = false;
  if (diverId != null) {
    try {
      primary = !await read(
        documentRepositoryProvider,
      ).hasPrimaryInsurance(diverId);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not read whether the diver has a primary insurance',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  final now = DateTime.now();
  return DocumentRecord(
    document: Document(
      id: id,
      diverId: diverId ?? '',
      owner: const DocumentOwner.personal(),
      type: DocumentType.other,
      isPrimary: primary,
      createdAt: now,
      updatedAt: now,
    ),
    pages: const [],
    tagIds: const [],
  );
}

/// The cards a new document opens with: Details, then Pages.
final List<String> newDocumentLaidOut = List.unmodifiable([
  DocumentCardId.details.name,
  DocumentCardId.pages.name,
]);

/// Puts what [request] brings on [session]: its owner and type, each
/// through the Details card's own setters, so each is a change; a fixed
/// owner is noted for the card, and changes nothing.
void applyNewDocumentPrefill(
  EditSession<DocumentRecord> session,
  NewDocumentRequest request,
) {
  if (session.isDisposed || session.isFrozen) return;
  if (request.ownerFixed) markDocumentOwnerFixed(session);
  final owner = request.owner;
  if (owner != null && !request.ownerFixed) {
    session.set(documentOwnerField, owner);
  }
  final type = request.type;
  if (type != null) setDocumentType(session, type);
}
