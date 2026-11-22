part of 'document_detail_page.dart';

/// The document page's use of the shared editing host (issue #4527, phase
/// 3): what is its own about saving, reading back, its cards and its
/// whole-record operations.
mixin _DocumentDetailPageEditing
    on
        ConsumerState<DocumentDetailPage>,
        RecordEditHost<DocumentDetailPage, DocumentRecord>,
        RecordOpenUnlocked<DocumentDetailPage, DocumentRecord> {
  @override
  String get hostRecordId => widget.documentId;

  @override
  String recordIdOf(DocumentRecord record) => record.id;

  @override
  bool openUnlockedOf(DocumentDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<DocumentRecord>> get hostEditCards =>
      documentEditCards.values;

  @override
  DocumentRecord? get storedForUnlock =>
      ref.read(documentRecordProvider(widget.documentId)).value;

  @override
  String editingTitle(DocumentRecord record) =>
      context.l10n.recordEdit_editingTitle(
        documentDisplayTitle(context.l10n, record.document, ownerLabel: null),
      );

  /// Writes the sitting through the document's save service, in one
  /// transaction and one History entry, then re-arms its expiry reminder,
  /// as the form's save does; a reminder that fails is not a failed save.
  @override
  Future<void> saveSitting(EditSession<DocumentRecord> session) async {
    final service = ref.read(documentEditSaveServiceProvider);
    final mutations = ref.read(documentMutationsProvider);
    final result = await service.save(
      // The document the sitting was opened on, whatever the page shows by
      // the time the write is asked for.
      documentId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
    );
    justSavedRecord = result?.after ?? session.working;
    if (result != null) {
      await mutations.rearmReminders([result.after.document]);
    }
  }

  @override
  Future<DocumentRecord?> rereadStored(
    ProviderContainer container,
    DocumentRecord stored,
  ) {
    container.invalidate(documentRecordProvider(stored.id));
    return container.read(documentRecordProvider(stored.id).future);
  }

  /// Pages, while the document has none and the card is not open.
  @override
  List<AddStripEntry> addStripEntries(DocumentRecord working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    final card = documentEditCards[DocumentCardId.pages]!;
    if (!card.isEmpty(working) || _pagesShownWhileEmpty) return const [];
    return [
      AddStripEntry(
        cardId: card.id,
        label: card.title(context),
        changed: session.changedCardIds.contains(card.id),
      ),
    ];
  }

  /// Whether the Pages card is open or brought in from the strip.
  bool get _pagesShownWhileEmpty {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    final id = DocumentCardId.pages.name;
    return controller.openCardIds.contains(id) ||
        controller.addedCardIds.contains(id);
  }

  /// The Pages card: its header, with the pencil, while unlocked; its
  /// editor once open.
  Widget _framedPages() => RecordCardFrame<DocumentRecord>(
    card: documentEditCards[DocumentCardId.pages]!,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: RecordCardHeader(
        title: DocumentCardId.pages.localizedDisplayName(context.l10n),
      ),
    ),
  );

  /// [details] framed as the Details card.
  Widget _framedDetails(Widget details) => RecordCardFrame<DocumentRecord>(
    card: documentEditCards[DocumentCardId.details]!,
    child: details,
  );

  /// The Details card's pencil.
  Widget _detailsPencil() => RecordCardPencil(
    cardTitle: DocumentCardId.details.localizedDisplayName(context.l10n),
  );

  /// The tags the sitting holds, shown on the closed card until Save; null
  /// when none are held.
  List<Tag>? _heldTags() {
    final session = maybeEditController?.session;
    return session == null ? null : heldDocumentTags(session);
  }

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _documentOperationBlock =>
      recordOperationBlockOf(editController);

  bool get _documentOperationsAvailable {
    final block = _documentOperationBlock;
    return block == null || block == RecordOperationBlock.none;
  }

  /// The caption over the menu's operations while they are unavailable.
  List<PopupMenuEntry<String>> _documentRecordCaption() {
    final reason = recordOperationReason(
      context.l10n,
      _documentOperationBlock,
      plural: true,
    );
    return [
      if (reason != null) recordOperationCaption<String>(context, reason),
    ];
  }

  /// Delete, through the sitting.
  void _requestDelete(Document doc) {
    recordOperationRunnerOf(
      editController,
      record: 'document ${widget.documentId}',
    )(() => _delete(doc));
  }

  Future<bool> _delete(Document doc);
}
