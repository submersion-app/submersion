import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/editing/trip_cylinder_events_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_sitting_host.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

part 'trip_cylinder_board_page_editing.dart';

/// [ids] with the one at [oldIndex] moved to [newIndex], the index
/// ReorderableListView's onReorderItem reports (already adjusted for the
/// removal).
List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  final moved = next.removeAt(oldIndex);
  next.insert(newIndex, moved);
  return next;
}

/// What the board draws with: dive centre names by id, and the diver's
/// units.
typedef BoardLook = ({Map<String, String> centerNames, UnitFormatter units});

/// The trip's cylinder board: every slot with its state (reorderable) or
/// the ledger of every fill and adjustment, with actions to add slots and
/// to fill several at once.
enum _BoardView { board, ledger, record }

/// The board is a satellite page of its trip (issue #4527, decision 9): pushed
/// from an unlocked trip page it joins that page's sitting ([joined]) and
/// finishes with Done; opened otherwise it opens locked, with its own Unlock,
/// Cancel and Save, and its Save writes one History entry on the trip.
class TripCylinderBoardPage extends ConsumerStatefulWidget {
  final String tripId;

  /// The trip page's sitting, when the board was pushed during one.
  final RecordEditController<Trip>? joined;

  const TripCylinderBoardPage({super.key, required this.tripId, this.joined});

  @override
  ConsumerState<TripCylinderBoardPage> createState() =>
      _TripCylinderBoardPageState();
}

class _TripCylinderBoardPageState extends ConsumerState<TripCylinderBoardPage>
    with
        RecordEditHost<TripCylinderBoardPage, Trip>,
        TripSittingHost<TripCylinderBoardPage>,
        _TripCylinderBoardEditing {
  _BoardView _view = _BoardView.board;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripId = widget.tripId;
    // Watched here, in the page's build, and handed down: the held board is
    // drawn by a builder that rebuilds on its own.
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final look = (
      centerNames: {for (final c in centers) c.id: c.name},
      units: ref.watch(unitFormatterProvider),
    );
    followStored(tripByIdProvider(tripId));
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final stored = tripAsync.value;
    if (stored == null) {
      // The board edits its trip: a trip that is gone, or whose read
      // failed, is said so rather than waited for.
      final settled = tripAsync.hasError || tripAsync.hasValue;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trips_cylinders_title)),
        body: Center(
          child: settled
              ? Text(l10n.trips_detail_error_loading)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final shown = shownRecord(stored);
    final session = boardSession;
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(
        title: Text(l10n.trips_cylinders_title),
        actions: [lockButton(shown)],
      ),
      content: session == null
          ? _storedBody(ref.watch(tripCylinderStatesProvider(tripId)), look)
          : heldBoard(session, look),
    );
  }

  /// Fill several and Add, above the board in a sitting, each held in it.
  List<Widget> _actions(List<TripCylinderState> states, TripBoardHold hold) {
    final l10n = context.l10n;
    return [
      IconButton(
        key: const Key('board-fill-several'),
        tooltip: l10n.trips_cylinders_action_fillSeveral,
        icon: const Icon(Icons.local_gas_station_outlined),
        onPressed: states.isEmpty
            ? null
            : () => showTripCylinderFillSheet(
                context,
                slots: states,
                several: true,
                preselected: {
                  for (final s in states)
                    if (s.status != TripCylinderStatus.full) s.cylinder.id,
                },
                hold: hold.fills,
              ),
      ),
      IconButton(
        key: const Key('board-add'),
        tooltip: l10n.trips_cylinders_action_add,
        icon: const Icon(Icons.add),
        onPressed: () => showAddTripCylindersSheet(
          context,
          tripId: widget.tripId,
          existing: [for (final s in states) s.cylinder],
          hold: hold.addSlots,
        ),
      ),
    ];
  }

  /// The board as stored, only shown, on a locked board.
  Widget _storedBody(
    AsyncValue<List<TripCylinderState>> statesAsync,
    BoardLook look,
  ) {
    final l10n = context.l10n;
    final states = statesAsync.value ?? const <TripCylinderState>[];
    if (!statesAsync.hasValue && statesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!statesAsync.hasValue && statesAsync.hasError) {
      return Center(child: Text(l10n.common_label_error));
    }
    return _body(
      states: states,
      look: look,
      forecast: ref.watch(tripFillForecastProvider(widget.tripId)).value,
      readOnly: true,
    );
  }

  /// The board of [states]: the forecast, the view switch and the view.
  /// With [hold] every change is handed to the trip's sitting; with
  /// [ledger] the ledger is the sitting's.
  @override
  Widget _body({
    required List<TripCylinderState> states,
    required BoardLook look,
    required FillForecast? forecast,
    required bool readOnly,
    TripBoardHold? hold,
    List<TripCylinderEvent>? ledger,
    Future<void> Function(DateTime date, int? plannedDives)? holdPlan,
  }) {
    final l10n = context.l10n;
    final tripId = widget.tripId;
    final (:centerNames, :units) = look;
    if (states.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.trips_cylinders_boardEmpty),
            if (!readOnly) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.trips_cylinders_action_add),
                onPressed: () => showAddTripCylindersSheet(
                  context,
                  tripId: tripId,
                  existing: const [],
                  hold: hold?.addSlots,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        if (hold != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _actions(states, hold),
            ),
          ),
        if (forecast != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TripFillForecastBanner(forecast: forecast, units: units),
          ),
          if (forecast.days.isNotEmpty)
            TripFillForecastStrip(
              tripId: tripId,
              days: forecast.days,
              units: units,
              hold: holdPlan,
              // In a sitting with no held days to set (their read failed),
              // the strip only shows: it must not write at once.
              readOnly: readOnly || (hold != null && holdPlan == null),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<_BoardView>(
            key: const Key('board-segment'),
            segments: [
              ButtonSegment(
                value: _BoardView.board,
                label: Text(l10n.trips_cylinders_segment_board),
              ),
              ButtonSegment(
                value: _BoardView.ledger,
                label: Text(l10n.trips_cylinders_segment_ledger),
              ),
              ButtonSegment(
                value: _BoardView.record,
                label: Text(l10n.trips_cylinders_segment_record),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        Expanded(
          child: switch (_view) {
            _BoardView.board => TripCylinderBoardList(
              states: states,
              centerNames: centerNames,
              hold: hold,
              readOnly: readOnly,
            ),
            _BoardView.ledger => TripCylinderLedgerView(
              tripId: tripId,
              states: states,
              centerNames: centerNames,
              hold: hold,
              heldEvents: ledger,
              readOnly: readOnly,
            ),
            // The record and its CSV export read what is stored (plan 10,
            // Call 11).
            _BoardView.record => TripCylinderRecordView(
              tripId: tripId,
              centerNames: centerNames,
            ),
          },
        ),
      ],
    );
  }
}

/// The reorderable list of slot cards. A drop shows the new order at once
/// and writes it through the repository; if the write fails the slots go
/// back and the diver is told.
class TripCylinderBoardList extends ConsumerStatefulWidget {
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  /// The trip's sitting a drop is handed to, rather than written.
  final TripBoardHold? hold;

  /// A board that edits in place and is locked: no reorder, and each
  /// slot's menu offers only Log dive.
  final bool readOnly;

  const TripCylinderBoardList({
    super.key,
    required this.states,
    required this.centerNames,
    this.hold,
    this.readOnly = false,
  });

  @override
  ConsumerState<TripCylinderBoardList> createState() =>
      _TripCylinderBoardListState();
}

class _TripCylinderBoardListState extends ConsumerState<TripCylinderBoardList> {
  /// The order just dropped, shown until the provider reports it.
  List<String>? _pending;

  /// The order the provider reported when the drop happened. A refresh
  /// still carrying it is stale, not an answer.
  List<String>? _before;

  /// Reorder writes not yet finished. While one runs, an order from the
  /// provider may be an earlier drop landing, not the latest.
  int _writing = 0;

  List<String> get _ids => [for (final s in widget.states) s.cylinder.id];

  @override
  void didUpdateWidget(TripCylinderBoardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The provider has caught up (the dropped order) or, once no write is
    // left running, moved on (any order but the one before the drop, say a
    // sync); either way it is the truth. A refresh that still shows the old
    // order, or an earlier drop landing, leaves the latest drop in place.
    final ids = _ids;
    if (_pending != null &&
        (listEquals(ids, _pending) ||
            (_writing == 0 && !listEquals(ids, _before)))) {
      _pending = null;
      _before = null;
    }
  }

  /// The slots in the order to draw: the dropped order while it is pending
  /// and still names exactly the slots on the board.
  List<TripCylinderState> get _ordered {
    final pending = _pending;
    if (pending == null) return widget.states;
    final byId = {for (final s in widget.states) s.cylinder.id: s};
    if (pending.length != byId.length || !pending.every(byId.containsKey)) {
      return widget.states;
    }
    return [for (final id in pending) byId[id]!];
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final shown = [for (final s in _ordered) s.cylinder.id];
    final next = reorderedIds(shown, oldIndex, newIndex);
    if (listEquals(next, shown) || widget.readOnly) return;
    final hold = widget.hold;
    if (hold != null) {
      await hold.reorder(next);
      return;
    }
    setState(() {
      _pending = next;
      _before ??= _ids;
      _writing++;
    });
    try {
      await ref.read(tripCylinderRepositoryProvider).reorderCylinders(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = null;
        _before = null;
      });
      showTripCylinderChangeFailed(context);
    } finally {
      _writing--;
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = _ordered;
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: states.length,
      onReorderItem: _reorder,
      // Each card carries its own drag, inside its border (#2957).
      buildDefaultDragHandles: false,
      itemBuilder: (context, i) => TripCylinderSlotCard(
        key: ValueKey(states[i].cylinder.id),
        state: states[i],
        reorderIndex: i,
        allStates: widget.states,
        centerNames: widget.centerNames,
        hold: widget.hold,
        readOnly: widget.readOnly,
      ),
    );
  }
}
