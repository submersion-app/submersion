import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_scope.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_cylinder_slot_row.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_packed_item_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripGearTab');

/// What I'll dive with (#2845): the gear packed for the trip and the
/// cylinder slots on its board, in one list with one Add.
class TripGearTab extends ConsumerWidget {
  final Trip trip;

  const TripGearTab({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
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
    // An owned cylinder on the board is listed under Cylinders only.
    final packed = packedOffBoard(gear, [for (final s in states) s.cylinder]);

    Future<void> add() => showTripGearAddSheet(
      context,
      ref,
      trip: trip,
      packed: gear,
      slots: [for (final s in states) s.cylinder],
    );
    void openBoard() => context.push('/trips/${trip.id}/cylinders');
    final addButton = FilledButton.tonalIcon(
      key: const Key('trip-gear-add'),
      icon: const Icon(Icons.add),
      label: Text(l10n.trips_gear_add_action),
      onPressed: add,
    );

    if (packed.isEmpty && states.isEmpty) {
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
              if (upcoming) ...[const SizedBox(height: 16), addButton],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (upcoming)
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
              onUnpack: () => _unpack(context, ref, item.id),
            ),
        ],
        if (states.isNotEmpty) ...[
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
        ],
      ],
    );
  }

  Future<void> _unpack(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(tripEquipmentRepositoryProvider).unpack(trip.id, id);
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
