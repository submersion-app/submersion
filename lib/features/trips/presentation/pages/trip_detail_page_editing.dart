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

  /// The cards only the story's Trip page draws, of those the Overview has:
  /// all of its cards but Notes, which a day page draws too, as its Day
  /// plan.
  static final _onStoryTripPage = tripStoryTripPageCards.difference({
    TripCardId.notes,
  });

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
  /// Overview is laid out from the trip as stored while unlocked; a new
  /// trip's always has the Plan row.
  bool _offered(TripCardId id, Trip working) {
    if (id == TripCardId.plan) {
      // A new trip's Overview always draws its Plan row (plan 11).
      if (isCreating) return false;
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
      isOpen: (id) =>
          maybeEditController?.openCardIds.contains(id.name) ?? false,
      openCard: (id) => _openCard(id, shown),
      unlockAt: (id) {
        final controller = editController;
        if (!controller.isUnlocked) controller.unlock(shown);
        if (!controller.isUnlocked) return null;
        showTab((id.tab ?? TripDetailTab.overview).index);
        return controller.session;
      },
    );
  }
}
