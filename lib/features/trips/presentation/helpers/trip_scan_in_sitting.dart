import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_dives_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('tripScanInSitting');

/// The Dives card's Scan for dives (issue #4527, phase 3): the dives in the
/// trip's working dates that are not on it are offered as the menu's scan
/// offers them, and the ones chosen are held in [session], to be assigned
/// at its Save. Dives the sitting holds already are not offered again.
Future<void> scanForTripDivesInSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Trip> session,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final activeDiverId = ref.read(currentDiverIdProvider);
  if (activeDiverId == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_diveScan_noDiver)),
    );
    return;
  }
  final trips = ref.read(tripRepositoryProvider);
  final trip = session.working;
  final loading = TripScanLoadingDialog(
    Navigator.of(context, rootNavigator: true),
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final held = {for (final d in scannedDivesOf(session).dives) d.id};
    final candidates = [
      for (final c in await trips.findCandidateDivesForTrip(
        tripId: trip.id,
        startDate: trip.startDate,
        endDate: trip.endDate,
        diverId: activeDiverId,
      ))
        if (!held.contains(c.dive.id)) c,
    ];
    loading.dismiss();
    if (candidates.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.trips_diveScan_noMatches)),
      );
      return;
    }
    if (!context.mounted) return;
    final chosen = await showDiveAssignmentDialog(
      context: context,
      candidates: candidates,
    );
    if (chosen == null || chosen.isEmpty || session.isDisposed) return;
    holdScannedDives(session, trips, candidates, chosen);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to scan for trip dives in a sitting',
      error: e,
      stackTrace: stackTrace,
    );
    loading.dismiss();
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_diveScan_error)));
  }
}
