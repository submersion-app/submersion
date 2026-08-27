import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/current_tide_indicator.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_source_badge.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_times_table.dart';

/// A complete tide information section for a dive site.
///
/// Shows current tide status, 24-hour tide chart, and upcoming
/// high/low tide times when tide data is available for the location.
class TideSection extends ConsumerWidget {
  /// The location to show tide data for.
  final GeoPoint location;

  /// Whether to show in compact mode (less detail).
  final bool compact;

  const TideSection({super.key, required this.location, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTideDataAsync = ref.watch(hasTideDataProvider(location));

    return hasTideDataAsync.when(
      data: (hasTideData) {
        if (!hasTideData) {
          return _buildNoDataCard(context);
        }
        return _TideSectionContent(location: location, compact: compact);
      },
      loading: () => _buildLoadingCard(context),
      error: (_, _) => _buildErrorCard(context),
    );
  }

  Widget _buildNoDataCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tides_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.waves_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tides_noDataForLocation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tides_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tides_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                context.l10n.tides_error_unableToLoad,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TideSectionContent extends ConsumerWidget {
  final GeoPoint location;
  final bool compact;

  const _TideSectionContent({required this.location, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final statusAsync = ref.watch(currentTideStatusProvider(location));
    final predictionsAsync = ref.watch(tidePredictionsProvider(location));
    final extremesAsync = ref.watch(tideExtremesProvider(location));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.waves, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tides_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(currentTideStatusProvider(location));
                    ref.invalidate(tidePredictionsProvider(location));
                    ref.invalidate(tideExtremesProvider(location));
                  },
                  tooltip: context.l10n.tides_action_refresh,
                ),
              ],
            ),

            // Data provenance (NOAA station vs ocean-model estimate)
            TideSourceBadge(location: location),
            const SizedBox(height: 12),

            // Current Status
            statusAsync.when(
              data: (status) {
                if (status == null) {
                  return const SizedBox.shrink();
                }
                return CurrentTideIndicator(
                  status: status,
                  compact: compact,
                  depthUnit: settings.depthUnit,
                );
              },
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            if (!compact) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Tide Chart header with date/time extent
              Row(
                children: [
                  Text(
                    context.l10n.tides_chart_24hourForecast,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  extremesAsync.when(
                    data: (extremes) => _buildChartTimeRange(
                      context,
                      extremes,
                      settings.timeFormat,
                      settings.dateFormat,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              predictionsAsync.when(
                data: (predictions) {
                  if (predictions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return extremesAsync.when(
                    data: (extremes) => TideChart(
                      predictions: predictions,
                      extremes: extremes,
                      height: 180,
                      timeFormat: settings.timeFormat,
                      depthUnit: settings.depthUnit,
                      dateFormat: settings.dateFormat,
                    ),
                    loading: () => TideChart(
                      predictions: predictions,
                      height: 180,
                      timeFormat: settings.timeFormat,
                      depthUnit: settings.depthUnit,
                      dateFormat: settings.dateFormat,
                    ),
                    error: (_, _) => TideChart(
                      predictions: predictions,
                      height: 180,
                      timeFormat: settings.timeFormat,
                      depthUnit: settings.depthUnit,
                      dateFormat: settings.dateFormat,
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      context.l10n.tides_error_unableToLoadChart,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Tide Times
              Text(
                context.l10n.tides_label_upcomingTides,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              extremesAsync.when(
                data: (extremes) {
                  if (extremes.isEmpty) {
                    return Center(
                      child: Text(
                        context.l10n.tides_noTideTimesAvailable,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return TideTimesTable(
                    extremes: extremes,
                    maxItems: 4,
                    showPast: false,
                    compact: true,
                    depthUnit: settings.depthUnit,
                    timeFormat: settings.timeFormat,
                    dateFormat: settings.dateFormat,
                  );
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a date and time range label matching the TideChart's visible window.
  Widget _buildChartTimeRange(
    BuildContext context,
    List<TideExtreme> extremes,
    TimeFormat timeFormat,
    DateFormatPreference dateFormat,
  ) {
    if (extremes.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();

    // Replicate TideChart's window calculation from extremes
    final pastExtremes = extremes.where((e) => e.time.isBefore(now)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    final futureExtremes = extremes.where((e) => !e.time.isBefore(now)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final DateTime windowStart;
    if (pastExtremes.isNotEmpty) {
      windowStart = pastExtremes.first.time.subtract(
        const Duration(minutes: 30),
      );
    } else {
      windowStart = now.subtract(const Duration(hours: 6));
    }

    final DateTime windowEnd;
    if (futureExtremes.length >= 2) {
      windowEnd = futureExtremes[1].time.add(const Duration(minutes: 30));
    } else if (futureExtremes.isNotEmpty) {
      windowEnd = futureExtremes.first.time.add(const Duration(hours: 6));
    } else {
      windowEnd = now.add(const Duration(hours: 12));
    }

    // Window bounds are stored wall-clock instants, not device-local times:
    // format them verbatim without any timezone conversion.
    final dateStr = DateFormat(
      UnitFormatter.weekdayMonthDayPattern(dateFormat),
    ).format(windowStart);
    final startTimeStr = DateFormat(timeFormat.pattern).format(windowStart);
    final endTimeStr = DateFormat(timeFormat.pattern).format(windowEnd);
    final spansNewDay =
        windowStart.year != windowEnd.year ||
        windowStart.month != windowEnd.month ||
        windowStart.day != windowEnd.day;
    final endDateStr = DateFormat(
      UnitFormatter.monthDayPattern(dateFormat),
    ).format(windowEnd);
    final timeRange = spansNewDay
        ? '$startTimeStr - $endTimeStr ($endDateStr)'
        : '$startTimeStr - $endTimeStr';

    return Text(
      '$dateStr | $timeRange',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A compact tide summary widget for list views or cards.
class TideSummaryWidget extends ConsumerWidget {
  /// The location to show tide data for.
  final GeoPoint location;

  const TideSummaryWidget({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(currentTideStatusProvider(location));

    return statusAsync.when(
      data: (status) {
        if (status == null) {
          return const SizedBox.shrink();
        }
        return TideStateBadge(state: status.state);
      },
      loading: () => const SizedBox(
        width: 80,
        height: 24,
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
