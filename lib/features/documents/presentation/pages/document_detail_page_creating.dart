part of 'document_detail_page.dart';

/// A new document on the document page (issue #4527, phase 3, plan 11):
/// the page's hooks for the shared [RecordCreating]. It opens unlocked on
/// a seed ([newDocumentSeed]) with Details and Pages laid out open, puts
/// the opener's owner and type on as changes, and at Save creates the
/// document, its pages and its tags in one transaction, then re-arms its
/// reminders as the form does.
mixin _DocumentDetailPageCreating
    on
        ConsumerState<DocumentDetailPage>,
        RecordEditHost<DocumentDetailPage, DocumentRecord>,
        RecordCreating<DocumentDetailPage, DocumentRecord> {
  @override
  bool get isCreating => widget.newDocument != null;

  @override
  Future<DocumentRecord?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newDocumentSeed(read, id: id);

  @override
  List<String> newRecordLaidOut(DocumentRecord seed) => newDocumentLaidOut;

  @override
  Future<void> applyNewRecordPrefill(
    EditSession<DocumentRecord> session,
  ) async {
    final request = widget.newDocument;
    if (request != null) applyNewDocumentPrefill(session, request);
  }

  /// The document, its pages and its tags, in one transaction. A seed made
  /// with no diver takes the one active now, as the form does at Save.
  @override
  Future<DocumentRecord> createRecord(
    EditSession<DocumentRecord> session,
  ) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(documentEditSaveServiceProvider);
    var record = session.applyTo(session.stored);
    if (record.document.diverId.isEmpty) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) throw StateError('No active diver');
      record = record.copyWith(
        document: record.document.copyWith(diverId: diverId),
      );
    }
    return service.create(
      record: record,
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// Re-arms the new document's reminders, as the form's save does.
  @override
  Future<void> Function(DocumentRecord created) captureAfterRecordCreated() {
    final mutations = ref.read(documentMutationsProvider);
    return (created) => mutations.rearmReminders([created.document]);
  }

  @override
  String newRecordTitle(BuildContext context) =>
      context.l10n.documents_edit_newTitle;

  @override
  String get newRecordLeaveLocation => '/documents';

  @override
  bool get newRecordEmbedded => widget.embedded;

  @override
  void Function(String id)? get onNewRecordCreated => widget.onCreated;

  @override
  VoidCallback? get onNewRecordCancelled => widget.onCreateCancelled;

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.documents_edit_newTitle,
    body: context.l10n.documents_error_load('$error'),
  );
}
