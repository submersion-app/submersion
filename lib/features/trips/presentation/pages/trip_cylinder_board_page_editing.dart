part of 'trip_cylinder_board_page.dart';

const _uuid = Uuid();

/// The board's use of the shared editing host (issue #4527, phase 3): a
/// satellite of its trip, holding the board and the forecast's planned
/// dives in the trip's sitting.
mixin _TripCylinderBoardEditing
    on
        ConsumerState<TripCylinderBoardPage>,
        RecordEditHost<TripCylinderBoardPage, Trip> {
  @override
  String get hostRecordId => widget.tripId;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  RecordEditController<Trip>? get joinedSitting => widget.joined;

  /// The board's cards are drawn in place, with no frame: its slots and
  /// ledger are lists, as the trip page's Itinerary tab is.
  @override
  Iterable<EditCard<Trip>> get hostEditCards => const [];

  @override
  List<AddStripEntry> addStripEntries(Trip working) => const [];

  /// The board of [states], drawn by the page.
  Widget _body({
    required List<TripCylinderState> states,
    required FillForecast? forecast,
    required bool readOnly,
    TripBoardHold? hold,
    List<TripCylinderEvent>? ledger,
    Future<void> Function(DateTime date, int? plannedDives)? holdPlan,
  });

  /// The open sitting, joined or the board's own; null while locked.
  EditSession<Trip>? get boardSession {
    final controller = maybeEditController;
    return controller != null && controller.isUnlocked
        ? controller.session
        : null;
  }

  /// The board as [session] holds it, drawn as it changes: its slots'
  /// states and ledger folded from the held fills, and the forecast from
  /// the held days and the working trip (plan 10, Question 8).
  Widget heldBoard(EditSession<Trip> session) {
    final board = tripCylindersList(
      cylinders: ref.read(tripCylinderRepositoryProvider),
      copier: ref.read(tripFillPassportCopierProvider),
    );
    final days = tripItineraryDays(ref.read(itineraryDayRepositoryProvider));
    final hold = TripBoardHold(session: session, board: board);
    Future<void> holdPlan(DateTime date, int? planned) async {
      final current = days.current(session);
      if (current == null) return;
      days.set(
        session,
        withPlannedDives(
          current,
          session.working,
          date,
          planned,
          newId: _uuid.v4,
          now: DateTime.now(),
        ),
      );
    }

    final logged = ref.watch(tripDiveRoundsTodayProvider(widget.tripId));
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    return ListenableBuilder(
      listenable: Listenable.merge([
        board.changes(session),
        days.changes(session),
        session,
      ]),
      builder: (context, _) {
        final held = heldCylindersOf(session, board);
        if (held == null) {
          return Center(
            child: board.failed(session)
                ? Text(context.l10n.common_label_error)
                : const CircularProgressIndicator(),
          );
        }
        final states = held.states;
        final trip = session.working;
        final centerId = lastTripFillCenter(states);
        final now = clock.now();
        final forecast = trip.endsBefore(now)
            ? null
            : tripFillForecastOf(
                trip: trip,
                states: states,
                itinerary: days.current(session) ?? const [],
                loggedToday: logged.value ?? 0,
                center: centers.where((c) => c.id == centerId).firstOrNull,
                now: now,
              );
        return _body(
          states: states,
          forecast: forecast,
          readOnly: false,
          hold: hold,
          ledger: orderTripLedger(held.events, held.slots),
          holdPlan: holdPlan,
        );
      },
    );
  }
}
