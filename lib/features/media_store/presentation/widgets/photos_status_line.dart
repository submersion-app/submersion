import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/photos_status.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The one sentence that says what is true of photo copies here (spec
/// section 8.3), including the runtime fact that the store could be opened
/// with this device's keys.
class PhotosStatusLine extends ConsumerWidget {
  const PhotosStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final copies = ref.watch(photosCopiesProvider).value;
    if (copies == null) return const SizedBox.shrink();
    final items = ref.watch(pendingSetupItemsProvider).value ?? const [];
    final status = photosStatus(
      attached: copies.attached,
      announced: copies.store != null,
      reconnect: items.any(
        (i) => !i.dismissed && i.kind == SetupItemKind.mediaStoreReconnect,
      ),
      reachable: copies.attached
          ? ref.watch(photosStoreReachableProvider)
          : null,
      progress: copies.attached
          ? ref.watch(mediaUploadProgressProvider).value
          : null,
      summary: copies.attached
          ? ref.watch(mediaTransferSummaryProvider).value
          : null,
    );
    if (status is PhotosNotSetUp) return const SizedBox.shrink();
    final attention =
        status is PhotosPaused ||
        status is PhotosUnreachable ||
        status is PhotosFinishSettingUp;
    final theme = Theme.of(context);
    return ListTile(
      key: const Key('photos-status'),
      leading: Icon(
        attention ? Icons.error_outline : Icons.cloud_done_outlined,
        color: attention ? theme.colorScheme.error : null,
      ),
      title: Text(photosStatusText(l10n, status, copies.label ?? '')),
      // A mismatch is the one pause the diver resolves: the guided
      // reconnect (issue #2303) says what each way out does.
      subtitle:
          status is PhotosPaused &&
              status.kind == MediaTransferHoldKind.markerMismatch
          ? TileSubtitleAction(
              actionKey: const Key('photos-status-reconnect'),
              label: l10n.settings_setUpDevice_item_reconnectAction,
              onPressed: () => showMediaStoreReconnectSheet(
                context,
                account: copies.label,
                openPhotosPage: false,
              ),
            )
          : null,
    );
  }
}

/// Words for [status]; [account] names the account the copies are in.
String photosStatusText(
  AppLocalizations l10n,
  PhotosStatus status,
  String account,
) => switch (status) {
  PhotosNotSetUp() => l10n.settings_sync_notSetUp,
  PhotosFinishSettingUp() => l10n.settings_photos_status_finishSetup,
  PhotosChecking() => l10n.settings_data_status_checking,
  // A store this device cannot name yet is "the account".
  PhotosUnreachable() =>
    account.isEmpty
        ? l10n.settings_photos_status_pausedUnreachable
        : l10n.settings_photos_status_unreachable(account),
  PhotosPaused(:final kind) => switch (kind) {
    MediaTransferHoldKind.detached =>
      l10n.settings_photos_status_pausedDetached,
    MediaTransferHoldKind.markerMismatch =>
      l10n.settings_photos_status_pausedMismatch,
    MediaTransferHoldKind.storeUnreachable || MediaTransferHoldKind.offline =>
      l10n.settings_photos_status_pausedUnreachable,
  },
  PhotosWaitingConnection() => l10n.settings_photos_status_waitingConnection,
  PhotosWaitingRetry(:final count) => l10n.settings_photos_status_waitingRetry(
    count,
  ),
  PhotosUploading(:final copied?, :final total?, :final count) =>
    l10n.settings_photos_status_uploading(copied, total, count),
  PhotosUploading(:final count) => l10n.settings_photos_status_uploadingOnly(
    count,
  ),
  PhotosAllCopied(:final copied, :final total) =>
    l10n.settings_photos_status_copied(copied, total),
};
