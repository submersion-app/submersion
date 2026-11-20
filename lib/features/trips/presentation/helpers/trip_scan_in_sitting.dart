import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_dives_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_photos_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
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
  final trips = ref.read(tripRepositoryProvider);
  final trip = session.working;
  final chosen = await chooseTripDives(
    context,
    ref,
    tripId: trip.id,
    startDate: trip.startDate,
    endDate: trip.endDate,
    exclude: {for (final d in scannedDivesOf(session).dives) d.id},
  );
  if (chosen == null || session.isDisposed) return;
  holdScannedDives(session, trips, chosen.candidates, chosen.selectedIds);
}

/// The dives the trip has in [session]: those stored on it and those its
/// scan added (plan 10, Call 10).
Future<List<Dive>> _sittingDives(
  WidgetRef ref,
  EditSession<Trip> session,
) async => [
  ...await ref.read(divesForTripProvider(session.stored.id).future),
  ...scannedDivesOf(session).dives,
];

/// The Photos card's Scan photos (issue #4527, phase 3): the gallery is
/// scanned for the trip's dives as the menu's scan does, and the photos
/// chosen are held in [session], each for its dive, written at its Save.
Future<void> scanTripPhotosInSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Trip> session,
) async {
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final importService = ref.read(mediaImportServiceProvider);
  final chosen = await chooseTripPhotos(
    context,
    ref,
    trip: session.working,
    dives: () => _sittingDives(ref, session),
    // Photos held already are not new: a second scan offers only the rest.
    alsoLinked: heldTripPhotos(session),
  );
  if (chosen == null) return;
  try {
    final rows = <HeldMediaAdd>[
      for (final entry in chosen.entries)
        if (entry.value.isNotEmpty)
          for (final p in await importService.prepareForDive(
            selectedAssets: entry.value,
            dive: entry.key,
          ))
            HeldMediaRow(p),
    ];
    // A sitting that ended while the photos were read takes nothing.
    if (session.isDisposed || session.isFrozen || rows.isEmpty) return;
    addMediaToSitting(session, rows);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to prepare trip photos for a sitting',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_detail_scan_errorScanning)),
    );
  }
}

/// The Photos card's Lightroom scan (issue #4527, phase 3): the catalog's
/// confident matches for the trip's dives are held in [session]; nothing is
/// suggested from a sitting (plan 10, Question 4).
Future<void> scanLightroomForTripInSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Trip> session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final dives = await _sittingDives(ref, session);
  if (!context.mounted) return;
  if (dives.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_detail_scan_addDivesFirst)),
    );
    return;
  }
  await runLightroomScanForDivesInSitting(context, ref, session, dives);
}
