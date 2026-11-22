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

  /// The header block and Notes, and a liveaboard's Vessel, laid out as
  /// the trip becomes one.
  @override
  List<String> newRecordLaidOut(Trip seed) => newTripLaidOut(seed);

  @override
  Future<void> applyNewRecordPrefill(EditSession<Trip> session) async =>
      applyNewTripPrefill(session, _draft);

  /// Asks which of its diver's dives in the trip's dates join it, as the
  /// form asked after every create: the diver the page was opened for,
  /// whom the trip keeps after a profile switch. A trip made from selected
  /// dives takes exactly those (issue #3658), so it asks nothing.
  @override
  Future<bool> beforeCreate(EditSession<Trip> session) => askDivesInDates(
    session,
    ask: _draft == null,
    diverId: session.stored.diverId,
  );

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

  /// The story [_newTripStory] made, and the dates and day it was made
  /// for.
  ({DateTime start, DateTime end, DateTime today, TripStory story})? _storyKept;

  /// A new trip's story: its days, from [trip]'s dates as the sitting holds
  /// them, since nothing else is stored to tell. Kept until the dates or
  /// the day change: a page rebuilds on every keystroke, and the days are
  /// one per date of the trip.
  TripStory _newTripStory(Trip trip) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final kept = _storyKept;
    if (kept != null &&
        kept.start == trip.startDate &&
        kept.end == trip.endDate &&
        kept.today == today) {
      return kept.story;
    }
    final story = buildTripStory(
      trip: trip,
      dives: const [],
      itineraryDays: const [],
      mediaByDiveId: const {},
      sightingsByDiveId: const {},
      checklistItems: const [],
      today: now,
    );
    _storyKept = (
      start: trip.startDate,
      end: trip.endDate,
      today: today,
      story: story,
    );
    return story;
  }

  /// The new trip's page: the Overview in the prepare shape, its header
  /// block under the hero, built on [shown], the working trip, reading
  /// nothing by its id; [seed] is the trip as the page opened on it.
  Widget _buildNewTrip(BuildContext context, Trip shown, Trip seed) {
    final slots = _slots(shown, seed);
    final story = _newTripStory(shown);
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
