import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/scan_results_dialog.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';

const _log = LoggerService('tripScanActions');

/// Dismisses a non-dismissible loading dialog exactly once, via a navigator
/// captured before the first await. This survives the initiating widget being
/// disposed mid-scan (when `context.mounted` is false), which would otherwise
/// leave the modal progress overlay stuck on the root navigator.
class TripScanLoadingDialog {
  final NavigatorState _navigator;
  bool _open = true;

  TripScanLoadingDialog(this._navigator);

  void dismiss() {
    if (_open && _navigator.canPop()) {
      _navigator.pop();
      _open = false;
    }
  }
}

/// Scan the device gallery for photos taken during the trip and link them to
/// the trip's dives.
Future<void> scanGalleryForTripPhotos(
  BuildContext context,
  WidgetRef ref,
  String tripId,
  Trip trip,
) async {
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) {
    return;
  }
  final chosen = await chooseTripPhotos(
    context,
    ref,
    trip: trip,
    dives: () => ref.read(divesForTripProvider(tripId).future),
  );
  if (chosen == null || !context.mounted) return;
  await _importPhotos(context, ref, tripId, chosen);
}

/// The gallery's photos taken during [trip], found for [dives] (read once
/// the loading dialog shows), less those stored on it or in [alsoLinked]
/// (a sitting's held photos), and confirmed by the diver dive by dive: the
/// photos chosen, by dive, or null when there is nothing to take (said
/// why). Shared by the menu's scan and a trip page sitting's (issue
/// #4527).
Future<Map<Dive, List<AssetInfo>>?> chooseTripPhotos(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required Future<List<Dive>> Function() dives,
  List<MediaItem> alsoLinked = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final loading = TripScanLoadingDialog(
    Navigator.of(context, rootNavigator: true),
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    // canPop:false so a system back can't pop this dialog (barrierDismissible
    // only blocks barrier taps); otherwise a later dismiss() could pop the
    // underlying page instead.
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    final found = await dives();
    if (found.isEmpty) {
      loading.dismiss();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.trips_detail_scan_addDivesFirst)),
      );
      return null;
    }

    // From the repository, not mediaForTripProvider: nothing on the trip page
    // watches that provider, so it could dispose mid-read.
    final linked = await ref
        .read(tripMediaRepositoryProvider)
        .getMediaForTrip(
          trip.id,
          diverId: await ref.read(validatedCurrentDiverIdProvider.future),
        );

    final photoPickerService = ref.read(photoPickerServiceProvider);
    final result = await TripMediaScanner.scanGalleryForTrip(
      dives: found,
      tripStartDate: trip.startDate,
      tripEndDate: trip.endDate,
      linked: [...linked, ...alsoLinked],
      linkedGalleryAssets: ref.read(linkedGalleryAssetsProvider),
      photoPickerService: photoPickerService,
    );

    loading.dismiss(); // Dismiss loading before any further UI.

    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.trips_detail_scan_accessDenied)),
      );
      return null;
    }

    if (!context.mounted) return null;
    final dialogResult = await showScanResultsDialog(
      context: context,
      scanResult: result,
    );

    if (dialogResult.confirmed != true) return null;
    return dialogResult.selectedPhotos;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to scan for trip photos',
      error: e,
      stackTrace: stackTrace,
    );
    loading.dismiss();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_detail_scan_errorScanning)),
    );
    return null;
  }
}

Future<void> _importPhotos(
  BuildContext context,
  WidgetRef ref,
  String tripId,
  Map<Dive, List<AssetInfo>> photosByDive,
) async {
  final loading = TripScanLoadingDialog(
    Navigator.of(context, rootNavigator: true),
  );
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(context.l10n.trips_detail_scan_linkingPhotos),
          ],
        ),
      ),
    ),
  );

  try {
    final importService = ref.read(mediaImportServiceProvider);
    int totalImported = 0;

    for (final entry in photosByDive.entries) {
      final dive = entry.key;
      final assets = entry.value;

      final result = await importService.importPhotosForDive(
        selectedAssets: assets,
        dive: dive,
      );

      totalImported += result.imported.length;

      ref.invalidate(mediaForDiveProvider(dive.id));
      ref.invalidate(mediaCountForDiveProvider(dive.id));
    }

    ref.invalidate(mediaForTripProvider(tripId));
    ref.invalidate(tripMediaPreviewProvider(tripId));
    ref.invalidate(flatMediaListForTripProvider(tripId));

    loading.dismiss(); // Dismiss progress.

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.trips_detail_scan_linkedPhotos(totalImported),
          ),
        ),
      );
    }
    if (context.mounted) {
      await offerSiteReviewAfterImport(
        context,
        ref,
        photosByDive.keys.map((d) => d.id),
      );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to link trip photos', error: e, stackTrace: stackTrace);
    loading.dismiss();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.trips_detail_scan_errorLinking)),
      );
    }
  }
}

/// Scan the diver's Lightroom catalog for photos matching the trip's dives.
Future<void> scanLightroomForTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  final dives = await ref.read(divesForTripProvider(tripId).future);
  if (!context.mounted) return;
  if (dives.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.trips_detail_scan_addDivesFirst)),
    );
    return;
  }
  await runLightroomScan(context, ref, dives);
}

/// Find dives whose date falls within the trip range and offer to assign them.
Future<void> scanForTripDives(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final chosen = await chooseTripDives(
    context,
    ref,
    tripId: trip.id,
    startDate: trip.startDate,
    endDate: trip.endDate,
  );
  if (chosen == null || !context.mounted) return;
  final (:candidates, :selectedIds) = chosen;
  final oldTripIds = candidates
      .where((c) => selectedIds.contains(c.dive.id) && !c.isUnassigned)
      .map((c) => c.currentTripId!)
      .toSet();
  try {
    await ref
        .read(tripListNotifierProvider.notifier)
        .assignDivesToTrip(selectedIds, trip.id, oldTripIds: oldTripIds);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_diveScan_added(selectedIds.length))),
    );
  } catch (e, stackTrace) {
    _log.error(
      'Failed to assign scanned dives to the trip',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_diveScan_error)));
  }
}

/// The dives of the active diver in [startDate] to [endDate] that are not
/// on trip [tripId] (nor in [exclude]), offered for the diver to choose:
/// the candidates and the ids chosen, or null when there is nothing to take
/// (said why). Shared by the menu's scan and a trip page sitting's (issue
/// #4527).
Future<({List<DiveCandidate> candidates, List<String> selectedIds})?>
chooseTripDives(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required DateTime startDate,
  required DateTime endDate,
  Set<String> exclude = const {},
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final activeDiverId = ref.read(currentDiverIdProvider);
  if (activeDiverId == null) {
    // Both the hero CTA and the overflow item can reach this action; without a
    // diver there's nothing to scan, so tell the user instead of returning
    // silently (an unresponsive-looking tap).
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trips_diveScan_noDiver)),
    );
    return null;
  }

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
    final candidates = [
      for (final c
          in await ref
              .read(tripRepositoryProvider)
              .findCandidateDivesForTrip(
                tripId: tripId,
                startDate: startDate,
                endDate: endDate,
                diverId: activeDiverId,
              ))
        if (!exclude.contains(c.dive.id)) c,
    ];

    loading.dismiss(); // Dismiss loading before any further UI.

    if (candidates.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.trips_diveScan_noMatches)),
      );
      return null;
    }

    if (!context.mounted) return null;
    final selectedIds = await showDiveAssignmentDialog(
      context: context,
      candidates: candidates,
    );
    if (selectedIds == null || selectedIds.isEmpty) return null;
    return (candidates: candidates, selectedIds: selectedIds);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to scan for trip dives',
      error: e,
      stackTrace: stackTrace,
    );
    loading.dismiss();
    messenger.showSnackBar(SnackBar(content: Text(l10n.trips_diveScan_error)));
    return null;
  }
}
