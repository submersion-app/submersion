import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
  } on Exception catch (e) {
    final message = e is CloudStorageException
        ? e.displayMessage
        : e.toString();
    await state.setLastError(message);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
