import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/scan_results_dialog.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripScanActions');

/// Dismisses a non-dismissible loading dialog exactly once, via a navigator
/// captured before the first await. This survives the initiating widget being
/// disposed mid-scan (when `context.mounted` is false), which would otherwise
/// leave the modal progress overlay stuck on the root navigator.
class _LoadingDialog {
  final NavigatorState _navigator;
  bool _open = true;

  _LoadingDialog(this._navigator);

  void dismiss() {
    if (_open && _navigator.canPop()) {
      _navigator.pop();
      _open = false;
    }
  }
}

/// The gallery's photos taken during [trip], found for [dives] (read once
/// the loading dialog shows), less those stored on it or in [alsoLinked]
/// (a sitting's held photos), and confirmed by the diver dive by dive: the
/// photos chosen, by dive, or null when there is nothing to take (said
/// why). The trip page's sitting holds what is chosen (issue #4527,
/// trip_scan_in_sitting.dart).
Future<Map<Dive, List<AssetInfo>>?> chooseTripPhotos(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required Future<List<Dive>> Function() dives,
  List<MediaItem> alsoLinked = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final loading = _LoadingDialog(Navigator.of(context, rootNavigator: true));
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

/// The dives of the active diver in [startDate] to [endDate] that are not
/// on trip [tripId] (nor in [exclude]), offered for the diver to choose:
/// the candidates and the ids chosen, or null when there is nothing to take
/// (said why). The trip page's sitting holds what is chosen (issue #4527,
/// trip_scan_in_sitting.dart).
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

  final loading = _LoadingDialog(Navigator.of(context, rootNavigator: true));
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
