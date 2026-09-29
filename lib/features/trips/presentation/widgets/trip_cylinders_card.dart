import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The cylinders card in the trip story: a count of full, partial and
/// empty slots and a chip per slot (bottle, mix, pressure). Tapping it
/// opens the board. An upcoming or current trip with no slots offers to set
/// them up; a past trip with none shows nothing.
class TripCylindersCard extends ConsumerWidget {
  final Trip trip;

  const TripCylindersCard({super.key, required this.trip});

  /// The most of the window the card may take before it scrolls, below the
  /// gear alerts panel's share (TripGearAlertsPanel.maxHeightFraction) so
  /// both fit above the story on a phone.
  static const maxHeightFraction = 0.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripCylinderStatesProvider(trip.id));
    // Until the slots load there is nothing true to say: an empty list here
    // would offer set-up to a trip that already has cylinders.
    final states = async.value;
    if (states == null || (states.isEmpty && !trip.isUpcoming)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final forecast = ref.watch(tripFillForecastProvider(trip.id)).value;
    void open() => context.push('/trips/${trip.id}/cylinders');

    final List<Widget> content;
    if (states.isEmpty) {
      content = [
        Text(l10n.trips_cylinders_setUpHint, style: theme.textTheme.bodyMedium),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('cylinders-set-up'),
            onPressed: open,
            child: Text(l10n.trips_cylinders_setUp),
          ),
        ),
      ];
    } else {
      final counts = tripCylinderCounts(states);
      final summary = l10n.trips_cylinders_summary(
        counts.full,
        counts.partial,
        counts.empty,
      );
      content = [
        Text(
          counts.unknown == 0
              ? summary
              : '$summary · '
                    '${l10n.trips_cylinders_summaryUnfilled(counts.unknown)}',
          style: theme.textTheme.bodyMedium,
        ),
        if (forecast != null) ...[
          const SizedBox(height: 4),
          TripFillForecastText(
            key: const Key('trip-cylinders-forecast'),
            forecast: forecast,
            units: units,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in states)
              Chip(
                key: Key('cylinder-chip-${s.cylinder.id}'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: tripCylinderStatusColor(theme.colorScheme, s.status),
                  semanticLabel: tripCylinderStatusLabel(l10n, s.status),
                ),
                label: Text(
                  '${s.bottleLabel} · '
                  '${s.mix == null ? '--' : tripCylinderMixLabel(l10n, s.mix!)} · '
                  '${s.pressure == null ? '--' : units.formatPressure(s.pressure)}',
                ),
              ),
          ],
        ),
      ];
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('trip-cylinders-card'),
          onTap: open,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      MdiIcons.divingScubaTank,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.trips_cylinders_title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                ...content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
