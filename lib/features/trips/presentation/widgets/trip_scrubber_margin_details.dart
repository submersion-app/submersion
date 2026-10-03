import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Minutes for display. A shortfall rounds away from zero so a margin
/// below zero is never shown as "0 min", which would read as breaking
/// even; every other figure here is non-negative and rounds normally.
String tripScrubberMarginMinutes(double value) =>
    (value < 0 ? value.floor() : value.round()).toString();

/// The banner's one-line summary: the lowest margin, or the count when
/// the diver has several rebreathers. The lowest comes from the rated
/// units; the count names them all, as the details show a block for each.
/// Null when nothing has a rating.
String? tripScrubberMarginSummary(
  AppLocalizations l10n,
  List<ScrubberMargin> margins,
) {
  final rated = margins.where((m) => m.marginAfter != null).toList();
  if (rated.isEmpty) return null;
  rated.sort((a, b) => a.marginAfter!.compareTo(b.marginAfter!));
  final lowest = tripScrubberMarginMinutes(rated.first.marginAfter!);
  return margins.length == 1
      ? l10n.trips_scrubber_bannerMargin(lowest)
      : l10n.trips_scrubber_bannerCount(margins.length, lowest);
}

/// The scrubber margin breakdown on a trip: one block per active
/// rebreather stating the four figures and the n behind each estimate,
/// with a caution line under 20 percent of the rated duration.
class TripScrubberMarginDetails extends StatelessWidget {
  final List<ScrubberMargin> margins;

  const TripScrubberMarginDetails({super.key, required this.margins});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, m) in margins.indexed) ...[
          if (i > 0) const Divider(),
          _MarginBlock(margin: m),
        ],
      ],
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
        Row(
          children: [
            Flexible(
              child: Text(m.item.name, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 6),
            ServiceStatusIndicatorFor(
              equipmentId: m.item.id,
              density: ServiceIndicatorDensity.dot,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (m.ratedMinutes == null)
          Text(l10n.trips_scrubber_noRating, style: body)
        else
          Text(
            // With no repack known the used minutes count every loop dive,
            // which "since the last repack" would misstate.
            (m.consumedSince == null
                ? l10n.trips_scrubber_remainingNoRepack
                : l10n.trips_scrubber_remaining)(
              tripScrubberMarginMinutes(m.remainingBefore),
              tripScrubberMarginMinutes(m.ratedMinutes!),
              tripScrubberMarginMinutes(m.consumedMinutes),
            ),
            style: body,
          ),
        Text(
          '${l10n.trips_scrubber_expectedDives(m.expectedDives)}$divesSource',
          style: body,
        ),
        Text(
          '${l10n.trips_scrubber_perDive(tripScrubberMarginMinutes(m.minutesPerDive))}'
          '$perDiveSource',
          style: body,
        ),
        Text(
          l10n.trips_scrubber_expectedUse(
            tripScrubberMarginMinutes(m.expectedUse),
          ),
          style: body,
        ),
        if (m.marginAfter case final after?)
          Text(
            l10n.trips_scrubber_margin(tripScrubberMarginMinutes(after)),
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
