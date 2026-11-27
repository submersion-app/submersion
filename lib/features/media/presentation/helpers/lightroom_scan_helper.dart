import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Runs a Lightroom scan over [dives] with progress and summary snackbars.
/// Writes/clears the connector's last-error state (the settings page's
/// needs-reauth chip reads it). No-op when Lightroom is not connected.
Future<void> runLightroomScan(
  BuildContext context,
  WidgetRef ref,
  List<Dive> dives,
) async {
  final account = await ref.read(lightroomAccountProvider.future);
  if (account == null || !context.mounted) return;
  final state = ref.read(lightroomConnectorStateProvider(account.id));
  final service = ref.read(lightroomScanServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settings_lightroom_scan_running)),
  );
  try {
    final summary = await service.scanDives(
      account: account,
      dives: dives,
      state: state,
    );
    await state.setLastError(null);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.settings_lightroom_scan_summary(
            summary.attached,
            summary.suggested,
            summary.skippedExisting,
          ),
        ),
      ),
    );
    for (final dive in dives) {
      ref.invalidate(pendingSuggestionsForDiveProvider(dive.id));
      ref.invalidate(mediaForDiveProvider(dive.id));
    }
    if (context.mounted) {
      await offerSiteReviewAfterImport(context, ref, dives.map((d) => d.id));
    }
  } on Exception catch (e) {
    final message = e is CloudStorageException
        ? e.displayMessage
        : e.toString();
    await state.setLastError(message);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// A trip's Lightroom scan in its sitting (issue #4527, phase 3, plan 10):
/// [runLightroomScanInSitting] for each of [dives], the photos found held
/// in [session] (a trip's) until Save. Like it, it makes no pending
/// suggestion. No-op when Lightroom is not connected.
Future<void> runLightroomScanForDivesInSitting<T>(
  BuildContext context,
  WidgetRef ref,
  EditSession<T> session,
  List<Dive> dives,
) async {
  final account = await ref.read(lightroomAccountProvider.future);
  if (account == null || !context.mounted) return;
  final state = ref.read(lightroomConnectorStateProvider(account.id));
  final service = ref.read(lightroomScanServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settings_lightroom_scan_running)),
  );
  try {
    final rows = [
      for (final dive in dives)
        ...(await service.prepareForDive(
          account: account,
          dive: dive,
          state: state,
        )).rows,
    ];
    await state.setLastError(null);
    messenger.hideCurrentSnackBar();
    if (rows.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_diveScan_noPhotosFound)),
      );
      return;
    }
    if (session.isDisposed || session.isFrozen) return;
    addMediaToSitting(session, [for (final r in rows) HeldMediaRow(r)]);
  } on Exception catch (e) {
    final message = e is CloudStorageException
        ? e.displayMessage
        : e.toString();
    await state.setLastError(message);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The open Media card's Lightroom scan (issue #4527): the photos the
/// catalog holds for the dive of [session] are found and placed as a scan
/// does, then held in it until Save, which writes them and queues their
/// uploads, instead of linked at once. No-op when Lightroom is not
/// connected.
Future<void> runLightroomScanInSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Dive> session,
) =>
    runLightroomScanForDivesInSitting(context, ref, session, [session.working]);
