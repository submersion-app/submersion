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

  /// Which page of the Overview's story shows.
  ValueNotifier<TripStorySelection?> get storySelection;

  /// The cards only the story's Trip page draws, of those the Overview has.
  static const _onStoryTripPage = {
    TripCardId.vessel,
    TripCardId.plan,
    TripCardId.documents,
  };

  /// Shows the story's Trip page, where [id] is drawn, when the story is on
  /// a day: a card asked to show itself there (a Save refused for it, one
  /// brought in from the strip, an edit address naming it) would otherwise
  /// be opened out of sight.
  void showStoryPageOf(TripCardId id) {
    if (!_onStoryTripPage.contains(id)) return;
    const tripPage = TripStorySelection.trip();
    if (storySelection.value != tripPage) storySelection.value = tripPage;
  }

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
    final request = maybeEditController?.revealRequest;
    if (request == null) return;
    final id = TripCardId.values.asNameMap()[request.cardId];
    if (id != null) showStoryPageOf(id);
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
    tripItineraryDays(
      container.read(itineraryDayRepositoryProvider),
    ).load(session);
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.trip, session.stored.id),
      cardId: TripCardId.documents.name,
    );
  }

  /// The held write that assigns the dives the diver chose at Save.
  static const _assignDivesKey = 'trip.assignDives';

  /// What that write assigns, for the notice and the old trips' pages once
  /// it has been written.
  ({int count, Set<String> oldTripIds})? _assigned;

  /// When the dates changed in the sitting, the dives in the new dates that
  /// are not on the trip are offered before anything is written, as the
  /// form offered them after its save. The ones chosen are assigned in the
  /// sitting's transaction, so Cancel or a failed Save assigns none and one
  /// History entry holds them. Asked once per Save: the answer replaces any
  /// earlier one, and dates put back drop it. Dismissing the question saves
  /// with no dives, as the form did.
  @override
  Future<bool> beforeSave() async {
    final session = maybeEditController?.session;
    if (session == null) return true;
    session.releaseWrite(_assignDivesKey);
    _assigned = null;
    final stored = session.stored;
    final working = session.working;
    if (stored.startDate == working.startDate &&
        stored.endDate == working.endDate) {
      return true;
    }
    final trips = ref.read(tripRepositoryProvider);
    final List<DiveCandidate> candidates;
    try {
      // The profile may still be being read just after the page opened;
      // the form waited for it, and so does this.
      final diverId =
          ref.read(validatedCurrentDiverIdProvider).value ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null || !mounted || session.isDisposed) {
        return mounted && !session.isDisposed;
      }
      candidates = await trips.findCandidateDivesForTrip(
        tripId: stored.id,
        startDate: working.startDate,
        endDate: working.endDate,
        diverId: diverId,
      );
    } catch (e, stackTrace) {
      // The question is an offer: a read that fails asks nothing, and the
      // dates are saved as the diver set them.
      _log.error(
        'Failed to find the dives in trip ${stored.id}\'s new dates',
        error: e,
        stackTrace: stackTrace,
      );
      return mounted && !session.isDisposed;
    }
    if (!mounted || session.isDisposed) return false;
    if (candidates.isEmpty) return true;
    final chosen = await showDiveAssignmentDialog(
      context: context,
      candidates: candidates,
    );
    if (!mounted || session.isDisposed) return false;
    if (chosen == null || chosen.isEmpty) return true;
    final picked = chosen.toSet();
    _assigned = (
      count: chosen.length,
      oldTripIds: {
        for (final c in candidates)
          if (picked.contains(c.dive.id) && !c.isUnassigned) c.currentTripId!,
      },
    );
    session.holdWrite(
      _assignDivesKey,
      () => trips.assignDivesToTrip(chosen, stored.id),
    );
    return true;
  }

  /// Writes the sitting through the trip's save service: its changed values
  /// and its held writes, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Trip> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final assigned = session.isHeld(_assignDivesKey) ? _assigned : null;
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
    if (assigned != null) {
      _assigned = null;
      // The dives' old trips count them no more.
      final tripId = session.stored.id;
      for (final id in {tripId, ...assigned.oldTripIds}) {
        container
          ..invalidate(tripWithStatsProvider(id))
          ..invalidate(diveIdsForTripProvider(id))
          ..invalidate(divesForTripProvider(id));
      }
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.trips_diveScan_added(assigned.count))),
      );
    }
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
      dayPlanFrame: (day, child) {
        final notes = tripEditCards[TripCardId.notes]!;
        return RecordCardFrame<Trip>(
          card: EditCard<Trip>(
            id: notes.id,
            title: notes.title,
            isEmpty: notes.isEmpty,
            editorBuilder: (context, session) =>
                TripDayPlanCardEditor(session: session, day: day),
          ),
          child: child,
        );
      },
      showsWhileEmpty: _showsWhileEmpty,
      openCard: (id) => _openCard(id, shown),
    );
  }
}
