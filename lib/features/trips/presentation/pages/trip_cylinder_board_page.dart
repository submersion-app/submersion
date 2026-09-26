import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
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
class TripCylinderBoardPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripCylinderBoardPage({super.key, required this.tripId});

  @override
  ConsumerState<TripCylinderBoardPage> createState() =>
      _TripCylinderBoardPageState();
}

class _TripCylinderBoardPageState extends ConsumerState<TripCylinderBoardPage> {
  bool _showLedger = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripId = widget.tripId;
    final statesAsync = ref.watch(tripCylinderStatesProvider(tripId));
    final states = statesAsync.value ?? const <TripCylinderState>[];
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerNames = {for (final c in centers) c.id: c.name};

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              key: const Key('board-segment'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.trips_cylinders_segment_board),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.trips_cylinders_segment_ledger),
                ),
              ],
              selected: {_showLedger},
              onSelectionChanged: (s) => setState(() => _showLedger = s.first),
            ),
          ),
          Expanded(
            child: _showLedger
                ? TripCylinderLedgerView(
                    tripId: tripId,
                    states: states,
                    centerNames: centerNames,
                  )
                : TripCylinderBoardList(
                    states: states,
                    centerNames: centerNames,
                  ),
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
            onPressed: () => showAddTripCylindersSheet(
              context,
              tripId: tripId,
              existing: [for (final s in states) s.cylinder],
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// The reorderable list of slot cards. Dragging a card writes the new board
/// order through the repository; the list redraws from the provider.
class TripCylinderBoardList extends ConsumerWidget {
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderBoardList({
    super.key,
    required this.states,
    required this.centerNames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: states.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final s in states) s.cylinder.id];
        ref
            .read(tripCylinderRepositoryProvider)
            .reorderCylinders(reorderedIds(ids, oldIndex, newIndex));
      },
      itemBuilder: (context, i) => TripCylinderSlotCard(
        key: ValueKey(states[i].cylinder.id),
        state: states[i],
        allStates: states,
        centerNames: centerNames,
      ),
    );
  }
}
