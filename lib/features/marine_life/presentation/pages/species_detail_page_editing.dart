part of 'species_detail_page.dart';

/// The species page's use of the shared editing host (issue #4527, phase
/// 3): what is its own about saving, reading back and its cards.
mixin _SpeciesDetailPageEditing
    on
        ConsumerState<SpeciesDetailPage>,
        RecordEditHost<SpeciesDetailPage, Species>,
        RecordOpenUnlocked<SpeciesDetailPage, Species> {
  @override
  String get hostRecordId => widget.speciesId;

  @override
  String recordIdOf(Species record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(SpeciesDetailPage widget) => widget.openUnlocked;

  /// The species page is never a pane: nothing waits for its sitting's end.
  @override
  VoidCallback? get onOpenedSittingEnded => null;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Species>> get hostEditCards => speciesEditCards.values;

  @override
  Species? get storedForUnlock =>
      ref.read(speciesProvider(widget.speciesId)).value;

  @override
  String editingTitle(Species record) => context.l10n.recordEdit_editingTitle(
    record.localizedCommonName(context.l10n),
  );

  /// Writes the sitting through the species' save service: its changed
  /// values and its held writes (photos tagged and added), in one
  /// transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Species> session) async {
    final service = ref.read(speciesEditSaveServiceProvider);
    final result = await service.save(
      // The species the sitting was opened on, whatever the page shows by
      // the time the write is asked for.
      speciesId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<Species?> rereadStored(ProviderContainer container, Species stored) {
    container.invalidate(speciesProvider(stored.id));
    return container.read(speciesProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty: Description.
  @override
  List<AddStripEntry> addStripEntries(Species working) {
    final controller = maybeEditController;
    final session = controller?.session;
    if (controller == null || session == null) return const [];
    final card = speciesEditCards[SpeciesCardId.description]!;
    if (!card.isEmpty(working) || _showsWhileEmpty(SpeciesCardId.description)) {
      return const [];
    }
    return [
      AddStripEntry(
        cardId: card.id,
        label: card.title(context),
        changed: session.changedCardIds.contains(card.id),
      ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(SpeciesCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place while the page
  /// offers it; as it is otherwise.
  Widget _framed(SpeciesCardId id, Widget child) {
    if (!hostsEditing) return child;
    return RecordCardFrame<Species>(card: speciesEditCards[id]!, child: child);
  }

  /// [child], a section the page calculates, faded and labelled
  /// "Calculated" while unlocked.
  Widget _calculated(Widget child) {
    if (!hostsEditing) return child;
    return RecordCardFade<Species>(
      reason: RecordCardFadeReason.calculated,
      child: child,
    );
  }
}
