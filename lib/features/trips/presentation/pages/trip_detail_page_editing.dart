part of 'trip_detail_page.dart';

/// The trip page's use of the shared editing host and its tabs (issue
/// #4527, phase 3): what is its own about saving, reading back, its cards,
/// the tab each is on and the frames they sit in.
mixin _TripDetailPageEditing
    on
        ConsumerState<TripDetailPage>,
        RecordEditHost<TripDetailPage, Trip>,
        RecordOpenUnlocked<TripDetailPage, Trip>,
        RecordEditTabs<TripDetailPage, Trip> {
  TabController get tabController;

  @override
  String get hostRecordId => widget.tripId;

  @override
  String recordIdOf(Trip record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(TripDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Trip>> get hostEditCards => tripEditCards.values;

  @override
  Trip? get storedForUnlock => ref.read(tripByIdProvider(widget.tripId)).value;

  @override
  String editingTitle(Trip record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  /// Who the trip is shared with is read, and the documents attached and
  /// detached in the sitting are filed under the trip.
  @override
  void onSittingStart(EditSession<Trip> session, ProviderContainer container) {
    // Read now: an owner's Save clears share rows a sync race left beside
    // the Everyone flag, as the form's did, whichever card it changed.
    loadTripSharing(session, container.read);
    tripVesselDetails(
      container.read(liveaboardDetailsRepositoryProvider),
    ).load(session);
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.trip, session.stored.id),
      cardId: TripCardId.documents.name,
    );
  }

  /// Writes the sitting through the trip's save service: its changed values
  /// and its held writes, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Trip> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(tripEditSaveServiceProvider);
    // The profile acting now, which the update checks before it writes the
    // Everyone flag; the sitting never changes that flag on the row itself,
    // so a profile not yet read only keeps the stored one.
    final actingDiverId = ref.read(validatedCurrentDiverIdProvider).value;
    final result = await service.save(
      // The trip the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      tripId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      actingDiverId: actingDiverId,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<Trip?> rereadStored(ProviderContainer container, Trip stored) {
    container.invalidate(tripWithStatsProvider(stored.id));
    container.invalidate(tripByIdProvider(stored.id));
    return container.read(tripByIdProvider(stored.id).future);
  }

  // Tabs.

  @override
  int? tabOfCard(String cardId) =>
      TripCardId.values.asNameMap()[cardId]?.tab?.index;

  @override
  int get tabInView => tabController.index;

  @override
  void showTab(int tab) => tabController.animateTo(tab);

  /// The cards the page leaves out while they are empty, on every tab.
  @override
  List<AddStripEntry> addStripEntriesOnEveryTab(Trip working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in tripOptionalCards)
        if (_offered(id, working) && !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: tripEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether the strip offers [id]: an empty card, or the Plan from the
  /// trip's first day, when the story has no place of its own for it. The
  /// Overview is laid out from the trip as stored while unlocked.
  bool _offered(TripCardId id, Trip working) {
    if (id == TripCardId.plan) {
      final stored = maybeEditController?.session?.stored ?? working;
      return !stored.startsAfter(clock.now());
    }
    return tripEditCards[id]!.isEmpty(working);
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(TripCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// Opens the card [id], unlocking the page on [shown] first when it is
  /// locked.
  void _openCard(TripCardId id, Trip shown) {
    final controller = editController;
    if (!controller.isUnlocked) controller.unlock(shown);
    if (!controller.isUnlocked) return;
    showTab((id.tab ?? TripDetailTab.overview).index);
    controller.openCard(id.name);
  }

  /// What the page hands its tabs: the trip as the cards show it, the trip
  /// the Overview lays itself out from, and the frames.
  TripCardSlots _slots(Trip shown, Trip stored) {
    final session = maybeEditController?.session;
    return TripCardSlots(
      shown: shown,
      layout: session?.stored ?? stored,
      session: session,
      frame: (id, child) {
        final card = tripEditCards[id];
        if (card == null) return child;
        return RecordCardFrame<Trip>(card: card, child: child);
      },
      showsWhileEmpty: _showsWhileEmpty,
      openCard: (id) => _openCard(id, shown),
    );
  }
}
