import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Minutes for display. A shortfall rounds away from zero so a margin
/// below zero is never shown as "0 min", which would read as breaking
/// even; every other figure here is non-negative and rounds normally.
String _minutes(double value) =>
    (value < 0 ? value.floor() : value.round()).toString();

/// The banner's one-line summary: the lowest margin, or the count when
/// the diver has several rebreathers. Null when nothing has a rating.
String? tripScrubberMarginSummary(
  AppLocalizations l10n,
  List<ScrubberMargin> margins,
) {
  final rated = margins.where((m) => m.marginAfter != null).toList();
  if (rated.isEmpty) return null;
  rated.sort((a, b) => a.marginAfter!.compareTo(b.marginAfter!));
  final lowest = _minutes(rated.first.marginAfter!);
  return rated.length == 1
      ? l10n.trips_scrubber_bannerMargin(lowest)
      : l10n.trips_scrubber_bannerCount(rated.length, lowest);
}

/// The scrubber margin card on a trip: one block per active rebreather
/// stating the four figures and the n behind each estimate, with a
/// caution line under 20 percent of the rated duration. A past trip
/// reads as of its start. Renders nothing without a rebreather.
class TripScrubberMarginCard extends ConsumerWidget {
  final Trip trip;

  const TripScrubberMarginCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margins =
        ref.watch(tripScrubberMarginsProvider(trip.id)).value ?? const [];
    if (margins.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final isPast = !trip.isUpcoming && !trip.isInProgress;
    final title = isPast
        ? '${l10n.trips_scrubber_title} '
              '(${l10n.trips_scrubber_asOfStart(units.formatDate(trip.startDate))})'
        : l10n.trips_scrubber_title;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.air, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            for (final m in margins) ...[
              const Divider(),
              _MarginBlock(margin: m),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarginBlock extends StatelessWidget {
  final ScrubberMargin margin;

  const _MarginBlock({required this.margin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final m = margin;
    // An n of zero is not an override: a default with no history to
    // average has none either, and claiming the diver set it would credit
    // them with a number they never entered. With neither, the figure
    // stands unattributed.
    final divesSource = m.divesFromOverride
        ? ' ${l10n.trips_scrubber_fromOverride}'
        : m.expectedDivesN == 0
        ? ''
        : ' ${l10n.trips_scrubber_fromTrips(m.expectedDivesN)}';
    final perDiveSource = m.minutesFromOverride
        ? ' ${l10n.trips_scrubber_fromOverride}'
        : m.minutesPerDiveN == 0
        ? ''
        : ' ${l10n.trips_scrubber_fromDives(m.minutesPerDiveN)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(m.item.name, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (m.ratedMinutes == null)
          Text(l10n.trips_scrubber_noRating, style: body)
        else
          Text(
            l10n.trips_scrubber_remaining(
              _minutes(m.remainingBefore),
              _minutes(m.ratedMinutes!),
              _minutes(m.consumedMinutes),
            ),
            style: body,
          ),
        Text(
          '${l10n.trips_scrubber_expectedDives(m.expectedDives)}$divesSource',
          style: body,
        ),
        Text(
          '${l10n.trips_scrubber_perDive(_minutes(m.minutesPerDive))}'
          '$perDiveSource',
          style: body,
        ),
        Text(
          l10n.trips_scrubber_expectedUse(_minutes(m.expectedUse)),
          style: body,
        ),
        if (m.marginAfter case final after?)
          Text(
            l10n.trips_scrubber_margin(_minutes(after)),
            style: body?.copyWith(
              fontWeight: FontWeight.bold,
              color: m.caution ? theme.colorScheme.error : null,
            ),
          ),
        if (m.caution)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.trips_scrubber_caution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
