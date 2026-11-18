import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the Documents card: documents attached to the record
/// (a dive, a site) and detached from it in the sitting.
const String documentLinksKey = 'documentLinks';

const String _noteKey = 'documentLinks.held';
const String _repoKey = 'documentLinks.repo';
const String _ownerKey = 'documentLinks.owner';

/// What a sitting holds for the record's documents: those to attach (each
/// created as Personal, a record of its own), and the stored ones to
/// detach.
typedef _Held = ({List<Document> attach, Set<String> detach});

_Held _held<T>(EditSession<T> session) =>
    session.recall<_Held>(_noteKey) ?? (attach: const [], detach: const {});

/// What a sitting's document links are filed under: the record, as an
/// owner, and the card a change of them is a change of.
typedef _Owner = ({DocumentOwner owner, String cardId});

/// Keeps the repository the held write uses, read as the sitting starts,
/// and the record the documents are filed under: [owner], whose card
/// [cardId] a change of the links is a change of (issue #4527).
void holdDocumentLinks<T>(
  EditSession<T> session,
  ProviderRead read, {
  required DocumentOwner owner,
  required String cardId,
}) {
  session
    ..remember(_repoKey, read(documentRepositoryProvider))
    ..remember(_ownerKey, (owner: owner, cardId: cardId));
}

/// The ids to attach and detach, for the page and the tests.
({Set<String> attach, Set<String> detach}) sittingDocumentLinks<T>(
  EditSession<T> session,
) {
  final held = _held(session);
  return (
    attach: {for (final d in held.attach) d.id},
    detach: {...held.detach},
  );
}

/// Attaches [document], just created as Personal, to the record in the
/// sitting.
void attachDocument<T>(EditSession<T> session, Document document) {
  final held = _held(session);
  if (held.attach.any((d) => d.id == document.id)) return;
  _set(session, (attach: [...held.attach, document], detach: held.detach));
}

/// Detaches [documentId] in the sitting; one attached in it is dropped.
void detachDocument<T>(EditSession<T> session, String documentId) {
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

void _set<T>(EditSession<T> session, _Held next) {
  if (session.isDisposed || session.isFrozen) return;
  final repository = session.recall<DocumentRepository>(_repoKey);
  final filed = session.recall<_Owner>(_ownerKey);
  if (repository == null || filed == null) return;
  session.remember(_noteKey, next);
  if (next.attach.isEmpty && next.detach.isEmpty) {
    session.releaseWrite(documentLinksKey);
    return;
  }
  session.holdChange(
    documentLinksKey,
    cardId: filed.cardId,
    write: () async {
      final held = _held(session);
      final owner = filed.owner;
      await repository.setOwner(owner.kind, [
        for (final d in held.attach) d.id,
      ], owner.id);
      // Only ones still filed under this record: a document a sync moved
      // to another owner since the sitting read it stays there.
      final onRecord = {
        for (final d in await repository.getForOwner(owner)) d.id,
      };
      await repository.setOwner(owner.kind, [
        for (final id in held.detach)
          if (onRecord.contains(id)) id,
      ], null);
    },
  );
}

/// The record's documents as the sitting has them: [stored] less the
/// detached ones, then the attached ones.
List<Document> documentsInSitting<T>(
  EditSession<T> session,
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
