import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/flight_window_card.dart';

/// Trip story wrapper around [FlightWindowCard]: watches the trip's flight
/// window and re-renders each minute so the countdown stays current.
class TripFlightCountdownCard extends ConsumerStatefulWidget {
  final String tripId;

  const TripFlightCountdownCard({super.key, required this.tripId});

  @override
  ConsumerState<TripFlightCountdownCard> createState() =>
      _TripFlightCountdownCardState();
}

class _TripFlightCountdownCardState
    extends ConsumerState<TripFlightCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(tripFlightWindowProvider(widget.tripId));
    final status = statusAsync.valueOrNull;
    if (status == null) return const SizedBox.shrink();
    return FlightWindowCard(status: status);
  }
}
