part of 'trip_detail_page.dart';

/// A new trip on the trip page (issue #4527, phase 3, plan 11): the page's
/// hooks for the shared [RecordCreating]. It opens unlocked on a seed
/// ([newTripSeed]) with the header block and Notes laid out open, puts
/// what a trip made from selected dives suggests on as changes, and at
/// Save asks which dives in its dates join it (never for a trip made from
/// selected dives, which takes exactly those), then creates the trip, its
/// held writes, a liveaboard's days and the draft's dives in one
/// transaction. Its Overview is the prepare page built on the working
/// trip, with no other tab: nothing is stored yet for them to show
/// (Question 6).
mixin _TripDetailPageCreating
    on
        ConsumerState<TripDetailPage>,
        RecordEditHost<TripDetailPage, Trip>,
        RecordOpenUnlocked<TripDetailPage, Trip>,
        RecordEditTabs<TripDetailPage, Trip>,
        TripSittingHost<TripDetailPage>,
        _TripDetailPageEditing,
        RecordCreating<TripDetailPage, Trip> {
  @override
  bool get isCreating => widget.newTrip != null;

  TripDraft? get _draft => widget.newTrip?.draft;

  @override
  Future<Trip?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newTripSeed(read, id: id);

  @override
  List<String> newRecordLaidOut(Trip seed) => newTripLaidOut(seed);

  @override
  Future<void> applyNewRecordPrefill(EditSession<Trip> session) async =>
      applyNewTripPrefill(session, _draft);

  /// Asks which dives in the trip's dates join it, as the form asked after
  /// every create; a trip made from selected dives takes exactly those
  /// (issue #3658), so it asks nothing.
  @override
  Future<bool> beforeCreate(EditSession<Trip> session) =>
      askDivesInDates(session, ask: _draft == null);

  /// The trip and its held writes in one transaction, for the diver the
  /// page was opened for, whose trips it offered as a larger one and who
  /// acts on its sharing; the diver active at Save when the seed could
  /// read none, as the form's create took it.
  @override
  Future<Trip> createRecord(EditSession<Trip> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(tripEditSaveServiceProvider);
    final read = ref.read;
    final dives = _draft?.diveIds ?? const <String>[];
    final trip = session.applyTo(session.stored);
    final diverId =
        trip.diverId ?? await newRecordDiverId(read, record: 'trip');
    return service.create(
      trip: trip.copyWith(diverId: diverId),
      changedCardIds: session.changedCardIds,
      draftDiveIds: dives,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The trips the dives left, and the new one, read again, and how many
  /// dives the question added, as a trip's Save says it.
  @override
  Future<void> Function(Trip created) captureAfterRecordCreated() {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final session = maybeEditController?.session;
    final chosen = session == null ? null : divesChosenAtSave(session);
    final left = {...?chosen?.oldTripIds, ...?_draft?.sourceTripIds};
    return (created) async {
      for (final id in {created.id, ...left}) {
        container
          ..invalidate(tripWithStatsProvider(id))
          ..invalidate(diveIdsForTripProvider(id))
          ..invalidate(divesForTripProvider(id));
      }
      if (chosen != null) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.trips_diveScan_added(chosen.count))),
        );
      }
    };
  }

  /// Lays out what a new trip's type brings as it changes to it: a
  /// liveaboard's Vessel, whose name Save requires. Heard from the sitting
  /// itself: the controller tells only when the changed cards move, and a
  /// header already changed (its name typed) does not move them.
  @override
  void onSittingStart(EditSession<Trip> session, ProviderContainer container) {
    super.onSittingStart(session, container);
    if (!isCreating) return;
    var seen = session.working.tripType;
    session.addListener(() {
      if (session.isDisposed) return;
      final type = session.working.tripType;
      if (type == seen) return;
      seen = type;
      _layOutForType(session);
    });
  }

  /// Opens the cards [session]'s working trip lays out that its seed did
  /// not, once this change has been told.
  void _layOutForType(EditSession<Trip> session) {
    final controller = maybeEditController;
    if (controller == null) return;
    final atOpen = newTripLaidOut(session.stored);
    final now = newTripLaidOut(session.working);
    // Opening a card tells again: not from inside this notice.
    Future.microtask(() {
      if (!mounted || controller.session != session) return;
      for (final id in now) {
        if (!atOpen.contains(id) && !controller.openCardIds.contains(id)) {
          controller.openCard(id);
        }
      }
    });
  }

  @override
  String newRecordTitle(BuildContext context) =>
      context.l10n.trips_edit_appBar_add;

  @override
  String get newRecordLeaveLocation => '/trips';

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
    title: context.l10n.trips_detail_appBar_title,
    body: context.l10n.trips_detail_error_loading,
  );

  /// The new trip's page: its header block over the Overview in the
  /// prepare shape, built on [shown], the working trip, reading nothing by
  /// its id; [seed] is the trip as the page opened on it.
  Widget _buildNewTrip(BuildContext context, Trip shown, Trip seed) {
    final slots = _slots(shown, seed);
    // Its days, from the dates as the sitting holds them: nothing else is
    // stored to tell.
    final story = buildTripStory(
      trip: shown,
      dives: const [],
      itineraryDays: const [],
      mediaByDiveId: const {},
      sightingsByDiveId: const {},
      checklistItems: const [],
      today: clock.now(),
    );
    final body = TripCardSlotsScope(
      slots: slots,
      child: Column(
        children: [
          // Its larger trip, as the sitting holds it: the stored page's
          // link reads the trip's own row, which a new trip does not have.
          if (shown.parentTripId case final parentId?)
            PartOfTripLink.toParent(
              parentId: parentId,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            ),
          slots.frame(TripCardId.header, TripHeaderRows(trip: shown)),
          Expanded(child: TripPrepareOverview(story: story, tabRows: false)),
        ],
      ),
    );
    if (widget.embedded) {
      // No locked row to lay the editing one over: a new trip is never
      // shown locked.
      return editPane(
        header: isSittingOpen
            ? editingPaneRow(seed, menu: const SizedBox.shrink())
            : const SizedBox.shrink(),
        shown: shown,
        content: body,
      );
    }
    return editScaffold(
      record: seed,
      shown: shown,
      lockedBar: AppBar(title: Text(newRecordTitle(context))),
      content: body,
    );
  }
}
