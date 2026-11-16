import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the Documents card: documents attached to the dive
/// and detached from it in the sitting.
const String documentLinksKey = 'documentLinks';

const String _noteKey = 'documentLinks.held';
const String _repoKey = 'documentLinks.repo';

/// What a sitting holds for the dive's documents: those to attach (each
/// created as Personal, a record of its own), and the stored ones to
/// detach.
typedef _Held = ({List<Document> attach, Set<String> detach});

_Held _held(EditSession<Dive> session) =>
    session.recall<_Held>(_noteKey) ?? (attach: const [], detach: const {});

/// Keeps the repository the held write uses, read as the sitting starts.
void holdDocumentLinks(EditSession<Dive> session, ProviderRead read) {
  session.remember(_repoKey, read(documentRepositoryProvider));
}

/// The ids to attach and detach, for the page and the tests.
({Set<String> attach, Set<String> detach}) sittingDocumentLinks(
  EditSession<Dive> session,
) {
  final held = _held(session);
  return (
    attach: {for (final d in held.attach) d.id},
    detach: {...held.detach},
  );
}

/// Attaches [document], just created as Personal, to the dive in the
/// sitting.
void attachDocument(EditSession<Dive> session, Document document) {
  final held = _held(session);
  if (held.attach.any((d) => d.id == document.id)) return;
  _set(session, (attach: [...held.attach, document], detach: held.detach));
}

/// Detaches [documentId] in the sitting; one attached in it is dropped.
void detachDocument(EditSession<Dive> session, String documentId) {
  final held = _held(session);
  if (held.attach.any((d) => d.id == documentId)) {
    _set(session, (
      attach: [
        for (final d in held.attach)
          if (d.id != documentId) d,
      ],
      detach: held.detach,
    ));
    return;
  }
  _set(session, (attach: held.attach, detach: {...held.detach, documentId}));
}

void _set(EditSession<Dive> session, _Held next) {
  if (session.isDisposed || session.isFrozen) return;
  final repository = session.recall<DocumentRepository>(_repoKey);
  if (repository == null) return;
  session.remember(_noteKey, next);
  if (next.attach.isEmpty && next.detach.isEmpty) {
    session.releaseWrite(documentLinksKey);
    return;
  }
  session.holdChange(
    documentLinksKey,
    cardId: DiveDetailSectionId.documents.name,
    write: () async {
      final held = _held(session);
      await repository.setDiveOwner([
        for (final d in held.attach) d.id,
      ], session.stored.id);
      await repository.setDiveOwner(held.detach.toList(), null);
    },
  );
}

/// The dive's documents as the sitting has them: [stored] less the
/// detached ones, then the attached ones.
List<Document> documentsInSitting(
  EditSession<Dive> session,
  List<Document> stored,
) {
  final held = _held(session);
  final storedIds = {for (final d in stored) d.id};
  return [
    for (final d in stored)
      if (!held.detach.contains(d.id)) d,
    for (final d in held.attach)
      if (!storedIds.contains(d.id)) d,
  ];
}
