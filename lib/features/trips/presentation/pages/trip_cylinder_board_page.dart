import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [ids] with the one at [oldIndex] moved to [newIndex], the index
/// ReorderableListView's onReorderItem reports (already adjusted for the
/// removal).
List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  final moved = next.removeAt(oldIndex);
  next.insert(newIndex, moved);
  return next;
}

/// The trip's cylinder board: every slot with its state (reorderable) or
/// the ledger of every fill and adjustment, with actions to add slots and
/// to fill several at once.
enum _BoardView { board, ledger, record }

class TripCylinderBoardPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripCylinderBoardPage({super.key, required this.tripId});

  @override
  ConsumerState<TripCylinderBoardPage> createState() =>
      _TripCylinderBoardPageState();
}

class _TripCylinderBoardPageState extends ConsumerState<TripCylinderBoardPage> {
  _BoardView _view = _BoardView.board;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripId = widget.tripId;
    final statesAsync = ref.watch(tripCylinderStatesProvider(tripId));
    final states = statesAsync.value ?? const <TripCylinderState>[];
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerNames = {for (final c in centers) c.id: c.name};
    final units = UnitFormatter(ref.watch(settingsProvider));
    final forecast = ref.watch(tripFillForecastProvider(tripId)).value;

    final Widget body;
    if (!statesAsync.hasValue && statesAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!statesAsync.hasValue && statesAsync.hasError) {
      body = Center(child: Text(l10n.common_label_error));
    } else if (states.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.trips_cylinders_boardEmpty),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.trips_cylinders_action_add),
              onPressed: () => showAddTripCylindersSheet(
                context,
                tripId: tripId,
                existing: const [],
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
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
              ),
              _BoardView.ledger => TripCylinderLedgerView(
                tripId: tripId,
                states: states,
                centerNames: centerNames,
              ),
              _BoardView.record => TripCylinderRecordView(
                tripId: tripId,
                tripName: ref.watch(tripByIdProvider(tripId)).value?.name ?? '',
                centerNames: centerNames,
              ),
            },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trips_cylinders_title),
        actions: [
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
                  ),
          ),
          IconButton(
            key: const Key('board-add'),
            tooltip: l10n.trips_cylinders_action_add,
            icon: const Icon(Icons.add),
            // New labels and positions follow the slots already on the
            // trip, so adding waits until those are known.
            onPressed: statesAsync.hasValue
                ? () => showAddTripCylindersSheet(
                    context,
                    tripId: tripId,
                    existing: [for (final s in states) s.cylinder],
                  )
                : null,
          ),
        ],
      ),
      body: body,
    );
  }
}

/// The reorderable list of slot cards. A drop shows the new order at once
/// and writes it through the repository; if the write fails the slots go
/// back and the diver is told.
class TripCylinderBoardList extends ConsumerStatefulWidget {
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderBoardList({
    super.key,
    required this.states,
    required this.centerNames,
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
    if (listEquals(next, shown)) return;
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
      itemBuilder: (context, i) => TripCylinderSlotCard(
        key: ValueKey(states[i].cylinder.id),
        state: states[i],
        allStates: widget.states,
        centerNames: widget.centerNames,
      ),
    );
  }
}
