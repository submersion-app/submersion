import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_number_badge.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/editing/trip_dives_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_in_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/side_trip_tag.dart';

/// The Dives tab: every dive on the trip in time order, each opening its
/// dive (#2845 put it on every trip; it was the liveaboard layout's).
///
/// On a trip page that edits in place (issue #4527) it is the Dives card:
/// it offers Scan for dives, which unlocks a locked page first, and lists
/// the dives the scan added in the sitting, marked and with Take out.
class TripDivesTab extends ConsumerWidget {
  final String tripId;

  const TripDivesTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = TripCardSlotsScope.maybeOf(context);
    final session = slots?.session;
    if (session == null) return _build(context, ref, slots, null);
    // A Consumer of its own, so what the list watches is watched by the
    // element that rebuilds with the sitting.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) => _build(context, ref, slots, session),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    TripCardSlots? slots,
    EditSession<Trip>? session,
  ) {
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    // A larger trip lists its side trips' dives too, each tagged with its
    // side trip (issue #3658).
    final sideTripNames = {
      for (final t in ref.watch(sideTripsProvider(tripId)).value ?? const [])
        t.id: t.name,
    };
    final held = session == null
        ? const <Dive>[]
        : scannedDivesOf(session).dives;
    final heldIds = {for (final d in held) d.id};
    void scan() {
      final open = slots?.session ?? slots?.unlockAt(TripCardId.dives);
      if (open != null) scanForTripDivesInSitting(context, ref, open);
    }

    final scanButton = slots == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('trip-dives-scan'),
                icon: const Icon(Icons.playlist_add),
                label: Text(context.l10n.trips_diveScan_findButton),
                onPressed: scan,
              ),
            ),
          );

    return divesAsync.when(
      data: (stored) {
        final dives = [...stored, ...held];
        if (dives.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.trips_detail_dives_empty),
                ?scanButton,
              ],
            ),
          );
        }
        // Entry-time order, as the story and the dive list order them.
        final sortedDives = List.of(
          dives,
        )..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: sortedDives.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return scanButton ?? const SizedBox(height: 16);
            }
            final dive = sortedDives[index - 1];
            final isHeld = heldIds.contains(dive.id);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DiveRow(
                dive: dive,
                sideTripName: sideTripNames[dive.tripId],
                onTakeOut: isHeld && session != null
                    ? () => takeOutScannedDive(
                        session,
                        ref.read(tripRepositoryProvider),
                        dive.id,
                      )
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) =>
          Center(child: Text(context.l10n.trips_detail_dives_errorLoading)),
    );
  }
}

/// One dive of the trip, opening its page. With [onTakeOut] it is one the
/// trip's sitting added: marked as not saved, with Take out.
class _DiveRow extends ConsumerWidget {
  const _DiveRow({required this.dive, this.sideTripName, this.onTakeOut});

  final Dive dive;
  final String? sideTripName;
  final VoidCallback? onTakeOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final takeOut = onTakeOut;
    return InkWell(
      key: Key('trip-dive-${dive.id}'),
      onTap: () => context.push('/dives/${dive.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            DiveNumberBadge(diveNumber: dive.diveNumber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dive.site?.name ??
                        context.l10n.trips_detail_dives_unknownSite,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(units.formatMonthDay(dive.dateTime), style: small),
                      if (sideTripName case final name?)
                        Flexible(child: SideTripTag(name: name)),
                    ],
                  ),
                  if (takeOut != null)
                    Text(
                      context.l10n.trips_sitting_notSaved,
                      style: small?.copyWith(
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (dive.maxDepth != null)
                  Text(
                    units.formatDepth(dive.maxDepth),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                // Measured runtime, matching the trip totals so these rows
                // add up to the figure the Overview tab reports (issue
                // #889).
                if (dive.measuredRuntime case final runtime?)
                  Text(
                    context.l10n.diveLog_sources_minutes(runtime.inMinutes),
                    style: small,
                  ),
              ],
            ),
            const SizedBox(width: 4),
            if (takeOut != null)
              TextButton(
                key: Key('trip-dive-takeOut-${dive.id}'),
                onPressed: takeOut,
                child: Text(context.l10n.trips_sitting_takeOut),
              )
            else
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
