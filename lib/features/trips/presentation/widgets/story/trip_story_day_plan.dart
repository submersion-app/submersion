import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_plan_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

/// The plan part of a story day card, on every day: the itinerary notes, the
/// planned dives (as progress once the day has come), and, for a day ahead,
/// the diver's history at its port or site.
class TripStoryDayPlan extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  /// Whether the day's port has dive history to show; the card resolves it
  /// once for its own empty-body guard. Without it the pills are left out
  /// entirely, so the column adds no gap for a widget that draws nothing.
  final bool hasHistory;

  const TripStoryDayPlan({
    super.key,
    required this.day,
    required this.units,
    required this.hasHistory,
  });

  /// Whether the section would draw anything. Blank is not content: sync and
  /// import payloads can write whitespace-only notes or ports, which the edit
  /// sheet would have normalized away. A planned port counts only when
  /// [hasHistory] says its pills will draw: a port the diver has never dived
  /// would otherwise leave an empty card under the header.
  static bool hasContent(TripStoryDay day, {required bool hasHistory}) =>
      (day.itineraryDay?.notes.trim().isNotEmpty ?? false) ||
      _progress(day) != null ||
      (historySite(day) != null && hasHistory);

  /// The port or site a day ahead offers history for, or null.
  static String? historySite(TripStoryDay day) {
    if (day.kind != TripStoryDayKind.future) return null;
    final port = day.itineraryDay?.portName?.trim() ?? '';
    return port.isEmpty ? null : port;
  }

  static DayPlanProgress? _progress(TripStoryDay day) => dayPlanProgress(
    row: day.itineraryDay,
    logged: day.diveCount,
    kind: day.kind,
  );

  @override
  Widget build(BuildContext context) {
    final notes = day.itineraryDay?.notes.trim() ?? '';
    final progress = _progress(day);
    final site = historySite(day);
    // It can lead the card, so no part carries a gap above itself.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        if (notes.isNotEmpty)
          MarkdownNotesView(
            notes,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (progress != null) DayPlanLine(progress: progress),
        if (site != null && hasHistory)
          _HistoryPills(siteName: site, units: units),
      ],
    );
  }
}

class _HistoryPills extends ConsumerWidget {
  final String siteName;
  final UnitFormatter units;

  const _HistoryPills({required this.siteName, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(siteHistoryByNameProvider(siteName));
    final history = historyAsync.valueOrNull;
    if (history == null || history.diveCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Chip(
          label: Text(l10n.trips_story_history_dives(history.diveCount)),
          visualDensity: VisualDensity.compact,
        ),
        if (history.avgWaterTemp != null)
          Chip(
            label: Text(
              l10n.trips_story_history_avgTemp(
                units.formatTemperature(history.avgWaterTemp),
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (history.avgMaxDepth != null)
          Chip(
            label: Text(
              l10n.trips_story_history_avgDepth(
                units.formatDepth(history.avgMaxDepth),
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
