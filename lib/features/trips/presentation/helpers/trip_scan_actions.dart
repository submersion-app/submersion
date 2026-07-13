import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/scan_results_dialog.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

/// Scan the device gallery for photos taken during the trip and link them to
/// the trip's dives.
Future<void> scanGalleryForTripPhotos(
  BuildContext context,
  WidgetRef ref,
  String tripId,
  Trip trip,
) async {
  final loading = _LoadingDialog(Navigator.of(context, rootNavigator: true));
  showDialog(
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
    final dives = await ref.read(divesForTripProvider(tripId).future);

    if (dives.isEmpty) {
      loading.dismiss();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_detail_scan_addDivesFirst)),
        );
      }
      return;
    }

    final mediaByDive = await ref.read(mediaForTripProvider(tripId).future);
    final existingIds = <String>{};
    for (final mediaList in mediaByDive.values) {
      for (final item in mediaList) {
        if (item.platformAssetId != null) {
          existingIds.add(item.platformAssetId!);
        }
      }
    }

    final photoPickerService = ref.read(photoPickerServiceProvider);
    final result = await TripMediaScanner.scanGalleryForTrip(
      dives: dives,
      tripStartDate: trip.startDate,
      tripEndDate: trip.endDate,
      existingAssetIds: existingIds,
      photoPickerService: photoPickerService,
    );

    loading.dismiss(); // Dismiss loading before any further UI.

    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_detail_scan_accessDenied)),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final dialogResult = await showScanResultsDialog(
      context: context,
      scanResult: result,
    );

    if (dialogResult.confirmed != true || !context.mounted) return;

    await _importPhotos(context, ref, tripId, dialogResult.selectedPhotos);
  } catch (e) {
    loading.dismiss();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.trips_detail_scan_errorScanning('$e')),
        ),
      );
    }
  }
}

Future<void> _importPhotos(
  BuildContext context,
  WidgetRef ref,
  String tripId,
  Map<Dive, List<AssetInfo>> photosByDive,
) async {
  final loading = _LoadingDialog(Navigator.of(context, rootNavigator: true));
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
    ref.invalidate(mediaCountForTripProvider(tripId));
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
  } catch (e) {
    loading.dismiss();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.trips_detail_scan_errorLinking('$e')),
        ),
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
  if (trip.diverId == null) {
    // Both the hero CTA and the overflow item can reach this action; without a
    // diver there's nothing to scan, so tell the user instead of returning
    // silently (an unresponsive-looking tap).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.trips_diveScan_noDiver)),
    );
    return;
  }

  final loading = _LoadingDialog(Navigator.of(context, rootNavigator: true));
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    final candidates = await ref
        .read(tripRepositoryProvider)
        .findCandidateDivesForTrip(
          tripId: trip.id,
          startDate: trip.startDate,
          endDate: trip.endDate,
          diverId: trip.diverId!,
        );

    loading.dismiss(); // Dismiss loading before any further UI.

    if (candidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_diveScan_noMatches)),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final selectedIds = await showDiveAssignmentDialog(
      context: context,
      candidates: candidates,
    );

    if (selectedIds == null || selectedIds.isEmpty || !context.mounted) {
      return;
    }

    final oldTripIds = candidates
        .where((c) => selectedIds.contains(c.dive.id) && !c.isUnassigned)
        .map((c) => c.currentTripId!)
        .toSet();

    await ref
        .read(tripListNotifierProvider.notifier)
        .assignDivesToTrip(selectedIds, trip.id, oldTripIds: oldTripIds);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.trips_diveScan_added(selectedIds.length)),
        ),
      );
    }
  } catch (e) {
    loading.dismiss();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.trips_diveScan_error('$e'))),
      );
    }
  }
}
