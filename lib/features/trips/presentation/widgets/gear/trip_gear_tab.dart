import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_split.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/open_trip_cylinder_board.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_cylinder_slot_row.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_packed_item_row.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_unslotted_tank_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('tripGearTab');

/// What I'll dive with (#2845): the gear packed for the trip and the
/// cylinder slots on its board, in one list with one Add.
class TripGearTab extends ConsumerWidget {
  final Trip trip;

  /// The trip page's open sitting: the packed gear and the board it holds
  /// are shown, and every change waits for its Save. Null, the page is
  /// locked (issue #4527): the gear only shows, with no Add, unpack or put
  /// on board, and Open board still opens the board.
  final EditSession<Trip>? editing;

  const TripGearTab({super.key, required this.trip, this.editing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = this.editing;
    if (editing != null) return _buildHeld(context, ref, editing);
    final l10n = context.l10n;
    final gearAsync = ref.watch(tripGearProvider(trip.id));
    final statesAsync = ref.watch(tripCylinderStatesProvider(trip.id));
    final gear = gearAsync.value;
    final states = statesAsync.value;
    if (gear == null || states == null) {
      // A failed read has no value either; say so rather than spin. The
      // repositories log the failure.
      if (gearAsync.hasError || statesAsync.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.common_error_tryAgain,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return _buildGear(context, ref, gear: gear, states: states);
  }

  /// The gear and board [editing] holds, drawn as they change.
  Widget _buildHeld(
    BuildContext context,
    WidgetRef ref,
    EditSession<Trip> editing,
  ) {
    final packed = tripPackedGearList(
      read: (id) => ref.read(tripGearProvider(id).future),
      packs: ref.read(tripEquipmentRepositoryProvider),
    );
    final board = tripCylindersList(
      cylinders: ref.read(tripCylinderRepositoryProvider),
      copier: ref.read(tripFillPassportCopierProvider),
    );
    final checklists = tripChecklistsList(
      checklists: ref.read(tripChecklistsRepositoryProvider),
      items: ref.read(tripChecklistRepositoryProvider),
    );
    final checklistWrites = HeldTripChecklistWrites(
      session: editing,
      list: checklists,
      templates: ref.read(checklistTemplateRepositoryProvider),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([
        packed.changes(editing),
        board.changes(editing),
        checklists.changes(editing),
      ]),
      builder: (context, _) {
        final gear = packed.current(editing);
        final held = heldCylindersOf(editing, board);
        // Add can put a set's lead on a checklist: it waits for the held
        // checklists too, so it never takes a trip still being read for
        // one with none. A failed read leaves the lead off, as with none.
        final checklistsPending =
            heldChecklistsOf(editing, checklists) == null &&
            !checklists.failed(editing);
        if (gear == null || held == null || checklistsPending) {
          if (packed.failed(editing) || board.failed(editing)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.common_error_tryAgain,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        // A Consumer of its own, so what the gear watches is watched by the
        // element that rebuilds with the held lists.
        return Consumer(
          builder: (context, ref, _) => _buildGear(
            context,
            ref,
            gear: gear,
            states: held.states,
            writes: HeldTripGearWrites(
              session: editing,
              packed: packed,
              board: board,
            ),
            lead: (
              checklists: () async =>
                  heldChecklistsOf(editing, checklists)?.checklists ?? const [],
              itemsOf: (id) async =>
                  heldChecklistsOf(editing, checklists)?.itemsOf(id) ??
                  const [],
              createItem: checklistWrites.createItem,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGear(
    BuildContext context,
    WidgetRef ref, {
    required List<EquipmentItem> gear,
    required List<TripCylinderState> states,
    TripGearWrites? writes,
    TripLeadChecklists? lead,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final now = clock.now();
    final started = !trip.startsAfter(now);
    final upcoming = trip.isUpcoming;
    // Service and scrubber state plan for a trip still ahead; a trip already
    // dived has nothing left to plan, and today's state says nothing about it
    // (#2485). Checked before the providers are watched, so a past trip
    // computes nothing.
    final ended = trip.endsBefore(now);
    final alerts = ended
        ? const <DueClock>[]
        : ref.watch(tripServiceAlertsProvider(trip.id)).value ?? const [];
    final margins = ended
        ? const <ScrubberMargin>[]
        : ref.watch(tripScrubberMarginsProvider(trip.id)).value ?? const [];
    // The forecast shows only while the trip is under way, so only then is
    // it computed.
    final forecast = trip.isInProgress
        ? ref.watch(tripFillForecastProvider(trip.id)).value
        : null;
    // Each item's blocking clocks, most pressing first: the row shows the
    // first, the sheet lists them all.
    final alertsByItem = {
      for (final id in {for (final a in alerts) a.item.id})
        id:
            [
              for (final a in alerts)
                if (a.item.id == id) a,
            ]..sort(
              (a, b) =>
                  b.status.severity.index.compareTo(a.status.severity.index),
            ),
    };
    final marginByItem = {for (final m in margins) m.item.id: m};
    final slots = [for (final s in states) s.cylinder];
    // An owned cylinder on the board is listed under Cylinders only, and so
    // is a tank packed without a slot (#2873), offered to the board.
    final (:packed, :unslottedTanks) = splitTripGear(gear, slots);

    void openBoard() => openTripCylinderBoard(context, trip.id);
    // Only the open sitting changes the gear: locked, nothing is offered.
    final addButton = writes == null || lead == null || !upcoming
        ? null
        : FilledButton.tonalIcon(
            key: const Key('trip-gear-add'),
            icon: const Icon(Icons.add),
            label: Text(l10n.trips_gear_add_action),
            onPressed: () => showTripGearAddSheet(
              context,
              ref,
              trip: trip,
              packed: gear,
              slots: slots,
              writes: writes,
              lead: lead,
            ),
          );

    if (packed.isEmpty && unslottedTanks.isEmpty && states.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                upcoming
                    ? l10n.trips_gear_empty_upcoming
                    : l10n.trips_gear_empty_past,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (addButton != null) ...[const SizedBox(height: 16), addButton],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (addButton != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: addButton,
            ),
          ),
        if (packed.isNotEmpty) ...[
          _SectionHeader(title: l10n.trips_gear_section_packed),
          for (final item in packed)
            TripPackedItemRow(
              item: item,
              alerts: alertsByItem[item.id] ?? const [],
              margin: marginByItem[item.id],
              onUnpack: writes == null
                  ? null
                  : () => _unpack(context, writes, item.id),
            ),
        ],
        if (states.isNotEmpty || unslottedTanks.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.trips_gear_section_cylinders,
            action: started
                ? TextButton(
                    onPressed: openBoard,
                    child: Text(l10n.trips_gear_openBoard),
                  )
                : null,
          ),
          if (forecast != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TripFillForecastText(forecast: forecast, units: units),
            ),
          for (final s in states)
            TripCylinderSlotRow(
              state: s,
              alerts: alertsByItem[s.cylinder.equipmentId] ?? const [],
              started: started,
              units: units,
              onTap: openBoard,
            ),
          for (final item in unslottedTanks)
            TripUnslottedTankRow(
              // Keyed by tank: the row holds its busy state, which must not
              // pass to another tank's row when the list shifts.
              key: ValueKey(item.id),
              item: item,
              units: units,
              alerts: alertsByItem[item.id] ?? const [],
              // An ended trip's board is history: no prompt to put it on.
              onPutOnBoard: ended || writes == null
                  ? null
                  : () => _putOnBoard(context, writes, item),
              onUnpack: writes == null
                  ? null
                  : () => _unpack(context, writes, item.id),
            ),
        ],
      ],
    );
  }

  /// Puts a packed tank with no slot on the board (#2873): a slot from the
  /// item, as Add makes one, appended after the board's last slot as it is
  /// written (two tanks put on before the board refreshes would otherwise
  /// tie); then its packed link goes, as Add packs none for a cylinder.
  /// Should the unpack fail, the slot still lists the tank once (a slotted
  /// tank's link is not shown), and a repeat adds no second slot (the
  /// append skips a tank already on the board) but retries the unpack.
  Future<void> _putOnBoard(
    BuildContext context,
    TripGearWrites writes,
    EquipmentItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final now = clock.now().toUtc();
      await writes.appendCylinders([
        tripCylinderDraftFromEquipment(
          item,
          tripId: trip.id,
          sortOrder: 0,
          now: now,
        ),
      ]);
      await writes.unpack(item.id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to put a packed tank on the board',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
    }
  }

  Future<void> _unpack(
    BuildContext context,
    TripGearWrites writes,
    String id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await writes.unpack(id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unpack trip gear',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
