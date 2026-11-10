import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/side_trips.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/providers/trip_list_count_provider.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/widgets/filtered_summary_banner.dart';

/// Summary widget shown when no trip is selected.
///
/// It summarizes the trips the list beside it shows. Under a trip list
/// filter (an equipment item's Trips row opens one) that is the filtered
/// trips alone, with a banner saying so, never every trip (issue #4414).
class TripSummaryWidget extends ConsumerStatefulWidget {
  const TripSummaryWidget({super.key});

  @override
  ConsumerState<TripSummaryWidget> createState() => _TripSummaryWidgetState();
}

class _TripSummaryWidgetState extends ConsumerState<TripSummaryWidget> {
  // The last filtered trips and count shown. A change from one filter to
  // another reloads the filtered trips with no previous value
  // (narrowByIds), so these keep the overview and its banner on screen
  // until the new trips land, as the Dive Log summary keeps its totals,
  // instead of blanking to a spinner. Only a filtered result is kept: an
  // unfiltered overview under a "Filtered" banner would misread as the
  // filter's.
  List<TripWithStats>? _lastTrips;
  ListEntryCount? _lastCount;

  @override
  Widget build(BuildContext context) {
    final isFiltered = ref.watch(tripFilterProvider).hasActiveFilters;
    final tripsAsync = ref.watch(filteredTripsProvider);
    // The list's own entry count, so the banner and the list's "3 of 12
    // trips" subtitle can never disagree.
    final liveCount = ref.watch(tripListCountProvider);
    // A reload of the trip list itself (another diver, say) or an error
    // shows no earlier figures, as the list and its count show none: only
    // a filter's own id query in flight falls back to them.
    final keepLast =
        isFiltered &&
        tripsAsync.isLoading &&
        !ref.watch(tripListNotifierProvider).isLoading;
    if (!isFiltered || tripsAsync.hasError) {
      _lastTrips = null;
      _lastCount = null;
    } else {
      if (tripsAsync.hasValue) _lastTrips = tripsAsync.value;
      if (liveCount != null) _lastCount = liveCount;
    }
    final trips = keepLast ? _lastTrips : tripsAsync.value;
    final count = liveCount ?? (keepLast ? _lastCount : null);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              FilteredSummaryBanner(
                message: count == null
                    ? null
                    : context.l10n.trips_summary_filteredBanner(
                        count.shown,
                        count.total,
                      ),
                clearLabel: context.l10n.trips_list_filters_clearAll,
                onClear: () => clearTripFilter(ref),
              ),
            ],
            const SizedBox(height: 24),
            if (trips != null)
              _buildOverview(context, ref, trips)
            else if (tripsAsync.hasError)
              // The repository logs the failure; the diver gets a plain
              // line.
              Center(child: Text(context.l10n.trips_list_error_loading))
            else
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.trips_summary_header_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.trips_summary_header_subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    WidgetRef ref,
    List<TripWithStats> trips,
  ) {
    // Calculate stats
    var totalDives = 0;
    var totalDays = 0;
    var liveaboardCount = 0;

    // A larger trip's figures already include its side trips' dives, and
    // its dates span theirs, so a side trip adds neither (issue #3658).
    final tripsById = <String, Trip>{for (final t in trips) t.trip.id: t.trip};
    for (final tripWithStats in trips) {
      final trip = tripWithStats.trip;
      final parentId = effectiveParentId(trip, tripsById);
      if (parentId == null) {
        totalDives += tripWithStats.diveCount;
        totalDays += trip.durationDays;
      } else {
        // Only the side trip's days that fall outside its larger trip.
        totalDays += _daysOutside(trip, tripsById[parentId]!);
      }
      if (trip.isLiveaboard) liveaboardCount++;
    }

    // Find upcoming trips
    final now = clock.now();
    final upcomingTrips =
        trips.where((t) => t.trip.startDate.isAfter(now)).toList()
          ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.trips_summary_overview_title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.flight_takeoff,
              value: '${trips.length}',
              label: context.l10n.trips_summary_stat_totalTrips,
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.scuba_diving,
              value: '$totalDives',
              label: context.l10n.trips_summary_stat_totalDives,
              color: Colors.teal,
            ),
            _buildStatCard(
              context,
              icon: Icons.calendar_today,
              value: '$totalDays',
              label: context.l10n.trips_summary_stat_daysDiving,
              color: Colors.green,
            ),
            if (liveaboardCount > 0)
              _buildStatCard(
                context,
                icon: Icons.sailing,
                value: '$liveaboardCount',
                label: context.l10n.trips_summary_stat_liveaboards,
                color: Colors.indigo,
              ),
          ],
        ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTripListPreview(context, ref, trips),
        ],
        if (upcomingTrips.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildUpcomingTrips(context, ref, upcomingTrips),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Semantics(
      label: '$label: $value',
      child: SizedBox(
        width: 120,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripListPreview(
    BuildContext context,
    WidgetRef ref,
    List<TripWithStats> trips,
  ) {
    // Sort by start date descending and take recent 3
    final sortedTrips = List<TripWithStats>.from(trips)
      ..sort((a, b) => b.trip.startDate.compareTo(a.trip.startDate));
    final previewTrips = sortedTrips.take(3).toList();
    final units = ref.watch(unitFormatterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.trips_summary_recentTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewTrips.map((tripWithStats) {
              final trip = tripWithStats.trip;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(trip.name),
                // The separator belongs to the translation, as in the
                // Upcoming card's subtitle: fr joins with a hyphen.
                subtitle: Text(
                  context.l10n.trips_summary_recentSubtitle(
                    units.formatDate(trip.startDate),
                    tripWithStats.diveCount,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.goInPlace('$currentPath?selected=${trip.id}');
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTrips(
    BuildContext context,
    WidgetRef ref,
    List<TripWithStats> upcomingTrips,
  ) {
    final units = ref.watch(unitFormatterProvider);
    final nextTrip = upcomingTrips.first;
    // Whole calendar days to the start date. Subtracting the current instant
    // instead would floor away the rest of today (a trip four calendar days
    // out reads "In 3 days" at any hour past midnight), and would lose a
    // further day whenever a spring-forward falls inside the window.
    final daysUntil = nextTrip.trip.daysUntilStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.trips_summary_upcomingTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                nextTrip.trip.isLiveaboard
                    ? Icons.sailing
                    : Icons.flight_takeoff,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            title: Text(
              nextTrip.trip.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              // The separator belongs to the translation: fr joins the two
              // parts with a hyphen where every other locale uses the bullet.
              // The date leads in every locale. Where the numeral sits is a
              // property of the countdown clause, not of this template, and
              // so belongs to trips_list_countdown: hu and zh lead that
              // clause with the numeral, en and de trail it after "In".
              // One more reason not to restate that wording here.
              context.l10n.trips_summary_upcomingSubtitle(
                units.formatDate(nextTrip.trip.startDate),
                context.l10n.trips_list_countdown(daysUntil),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onTap: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.goInPlace('$currentPath?selected=${nextTrip.trip.id}');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.trips_summary_quickActions_title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.goInPlace('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.trips_summary_quickActions_add),
            ),
          ],
        ),
      ],
    );
  }
}

/// The calendar days of [side] that [larger] does not cover.
int _daysOutside(Trip side, Trip larger) {
  final before = calendarDaysBetween(side.startDate, larger.startDate);
  final after = calendarDaysBetween(larger.endDate, side.endDate);
  final total = side.durationDays;
  final outside = (before > 0 ? before : 0) + (after > 0 ? after : 0);
  return outside > total ? total : outside;
}
