import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Non-blocking warning shown while editing a dive whose end time falls
/// after the latest safe surfacing time for the trip's return flight.
/// Warn, never block: the diver may be logging a past trip or know better.
class FlightWindowWarningBanner extends ConsumerWidget {
  final String? tripId;
  final DateTime? diveEndTime;

  const FlightWindowWarningBanner({
    super.key,
    required this.tripId,
    required this.diveEndTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = tripId;
    final end = diveEndTime;
    if (id == null || end == null) return const SizedBox.shrink();

    final status = ref.watch(tripFlightWindowProvider(id)).valueOrNull;
    if (status == null || !end.isAfter(status.deadline)) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    // Wall-clock-as-UTC deadline: format components directly, no toLocal().
    final time = DateFormat.E().add_jm().format(status.deadline);
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.flight_takeoff, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.diveLog_edit_flightWindowWarning(time),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
