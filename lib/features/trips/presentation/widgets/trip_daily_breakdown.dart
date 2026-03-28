import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Daily breakdown table for liveaboard trip overview.
///
/// Shows a compact collapsible table with one row per itinerary day,
/// displaying: day number, day type, dive count, total bottom time,
/// and unique site count. Dives are grouped by date and joined with
/// itinerary days.
class TripDailyBreakdown extends ConsumerWidget {
  final String tripId;

  const TripDailyBreakdown({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraryAsync = ref.watch(itineraryDaysProvider(tripId));
    final divesAsync = ref.watch(divesForTripProvider(tripId));

    return itineraryAsync.when(
      data: (days) => divesAsync.when(
        data: (dives) => _buildBreakdown(context, days, dives),
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(context, e),
      ),
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(context, e),
    );
  }

  Widget _buildLoading() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${context.l10n.common_label_error}: $error',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdown(
    BuildContext context,
    List<ItineraryDay> days,
    List<Dive> dives,
  ) {
    if (days.isEmpty) return const SizedBox.shrink();

    final divesByDate = _groupDivesByDate(dives);
    final rows = _buildDayRows(days, divesByDate);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        title: Text(
          context.l10n.trips_detail_sectionTitle_dailyBreakdown,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 34,
              ),
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                horizontalMargin: 12,
                columnSpacing: 16,
                headingTextStyle: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
                dataTextStyle: theme.textTheme.bodySmall,
                columns: [
                  DataColumn(
                    label: Text(context.l10n.trips_breakdown_column_day),
                  ),
                  DataColumn(
                    label: Text(context.l10n.trips_breakdown_column_type),
                  ),
                  DataColumn(
                    label: Text(context.l10n.trips_breakdown_column_dives),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(context.l10n.trips_breakdown_column_bottomTime),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(context.l10n.trips_breakdown_column_sites),
                    numeric: true,
                  ),
                ],
                rows: rows,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Group dives by calendar date (year-month-day) for fast lookup.
  Map<String, List<Dive>> _groupDivesByDate(List<Dive> dives) {
    return groupBy(dives, (Dive dive) {
      final dt = dive.dateTime;
      return '${dt.year}-${dt.month}-${dt.day}';
    });
  }

  /// Build a DataRow for each itinerary day, joining with grouped dives.
  List<DataRow> _buildDayRows(
    List<ItineraryDay> days,
    Map<String, List<Dive>> divesByDate,
  ) {
    final sortedDays = List<ItineraryDay>.of(days)
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    return sortedDays.map((day) {
      final dateKey = '${day.date.year}-${day.date.month}-${day.date.day}';
      final dayDives = divesByDate[dateKey] ?? const [];
      final diveCount = dayDives.length;
      final bottomTimeMinutes = _totalBottomTimeMinutes(dayDives);
      final siteCount = _uniqueSiteCount(dayDives);

      return DataRow(
        cells: [
          DataCell(Text('${day.dayNumber}')),
          DataCell(Text(day.dayType.displayName)),
          DataCell(Text('$diveCount')),
          DataCell(
            Text(bottomTimeMinutes > 0 ? '${bottomTimeMinutes}min' : '-'),
          ),
          DataCell(Text(siteCount > 0 ? '$siteCount' : '-')),
        ],
      );
    }).toList();
  }

  /// Sum of dive durations in minutes for a list of dives.
  int _totalBottomTimeMinutes(List<Dive> dives) {
    return dives
        .where((dive) => dive.bottomTime != null)
        .fold(0, (sum, dive) => sum + dive.bottomTime!.inMinutes);
  }

  /// Count of unique dive sites in a list of dives.
  int _uniqueSiteCount(List<Dive> dives) {
    return dives
        .where((dive) => dive.site != null)
        .map((dive) => dive.site!.id)
        .toSet()
        .length;
  }
}
