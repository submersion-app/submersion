import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Presentational card for a [FlightWindowStatus]. Parents own the ticking:
/// re-build (NoFlyPage's minute timer, the trip story wrapper's timer) and
/// the countdown re-renders against the current wall-clock.
class FlightWindowCard extends ConsumerWidget {
  final FlightWindowStatus status;

  const FlightWindowCard({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final now = NoFlyService.wallClockNowUtc();
    // Wall-clock-as-UTC values format their components directly -- no
    // toLocal(), matching how dive times are displayed everywhere. The weekday
    // has no ordering to respect, so it stays locale-derived; the clock half
    // goes through the diver's 12h/24h preference.
    final units = UnitFormatter(ref.watch(settingsProvider));
    final weekdayFormat = DateFormat.E();
    String formatWhen(DateTime value) =>
        '${weekdayFormat.format(value)} ${units.formatTime(value)}';

    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) = switch (status.state) {
      FlightWindowState.open => (
        Icons.flight_takeoff,
        scheme.primary,
        l10n.flightWindow_openTitle(
          formatNoFlyRemaining(status.remaining(now)),
        ),
        l10n.flightWindow_surfaceBy(formatWhen(status.deadline)),
      ),
      FlightWindowState.closed => (
        Icons.airplanemode_inactive,
        scheme.tertiary,
        l10n.flightWindow_closed,
        l10n.flightWindow_departs(formatWhen(status.flightAt)),
      ),
      FlightWindowState.conflict => (
        Icons.warning_amber,
        scheme.error,
        l10n.flightWindow_conflict,
        l10n.flightWindow_departs(formatWhen(status.flightAt)),
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
