part of 'certification_detail_page.dart';

/// The certification page's use of the shared editing host (issue #4527,
/// phase 3): what is its own about saving, reading back, its cards and the
/// frames its sections sit in.
mixin _CertificationDetailPageEditing
    on
        ConsumerState<CertificationDetailPage>,
        RecordEditHost<CertificationDetailPage, Certification>,
        RecordOpenUnlocked<CertificationDetailPage, Certification> {
  @override
  String get hostRecordId => widget.certificationId;

  @override
  String recordIdOf(Certification record) => record.id;

  @override
  bool openUnlockedOf(CertificationDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Certification>> get hostEditCards =>
      certificationEditCards.values;

  @override
  Certification? get storedForUnlock =>
      ref.read(certificationByIdProvider(widget.certificationId)).value;

  @override
  String editingTitle(Certification record) =>
      context.l10n.recordEdit_editingTitle(
        certificationTitleL10n(
          record,
          context.l10n,
          catalog: context.certificationCatalog,
        ),
      );

  /// The documents attached and detached in the sitting are filed under the
  /// certification.
  @override
  void onSittingStart(
    EditSession<Certification> session,
    ProviderContainer container,
  ) {
    // Read now, so the Currency card shows the sitting's list once it
    // changes.
    certificationEventsList.load(session);
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.certification, session.stored.id),
      cardId: CertificationCardId.documents.name,
    );
  }

  /// Writes the sitting through the certification's save service: its
  /// changed values, its card images and its held writes, in one
  /// transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Certification> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(certificationEditSaveServiceProvider);
    final result = await service.save(
      // The certification the sitting was opened on, whatever the page
      // shows by the time the write is asked for.
      certificationId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<Certification?> rereadStored(
    ProviderContainer container,
    Certification stored,
  ) {
    container.invalidate(certificationByIdProvider(stored.id));
    return container.read(certificationByIdProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty: Instructor, Card
  /// photos and Notes.
  @override
  List<AddStripEntry> addStripEntries(Certification working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in certificationOptionalCards)
        if (certificationEditCards[id]!.isEmpty(working) &&
            !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: certificationEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(CertificationCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(CertificationCardId id, Widget child) =>
      RecordCardFrame<Certification>(
        card: certificationEditCards[id]!,
        child: child,
      );
}

/// A section's title row: its title, and the card's pencil.
Widget _sectionTitle(BuildContext context, String title) => Row(
  children: [
    Expanded(
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    RecordCardPencil(cardTitle: title),
  ],
);

/// [child], a section the page calculates, faded and labelled
/// "Calculated" while unlocked.
Widget _calculated(Widget child) => RecordCardFade<Certification>(
  reason: RecordCardFadeReason.calculated,
  child: child,
);
