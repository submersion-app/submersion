import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether a per-item re-upload can be offered: only when a media store is
/// connected on this device, since otherwise there is nothing to re-upload
/// to.
bool mediaReuploadAvailable(WidgetRef ref) =>
    ref.watch(mediaStoreResolverProvider) != null;

String _qualityLabel(
  AppLocalizations l10n,
  MediaUploadQuality q,
) => switch (q) {
  MediaUploadQuality.original => l10n.settings_mediaStorage_quality_original,
  MediaUploadQuality.high => l10n.settings_mediaStorage_quality_high,
  MediaUploadQuality.balanced => l10n.settings_mediaStorage_quality_balanced,
  MediaUploadQuality.small => l10n.settings_mediaStorage_quality_small,
};

/// Whether re-uploading [item] at [level] drops its full-quality copy from
/// the store [storeId] this device is attached to: a compressed level for an
/// original uploaded there replaces it, and the original's object is
/// deleted once no row uses it (`MediaUploadPipeline.process`). Stamps made
/// in another store say nothing about this one, as the pipeline reads them.
bool reuploadDropsOriginal(
  MediaItem item,
  MediaUploadQuality level, {
  String? storeId,
}) =>
    level != MediaUploadQuality.original &&
    stampsInStore(item, storeId).remoteUploadedAt != null;

/// Opens the upload-quality picker for [item], anchored to the widget
/// [anchorContext] belongs to (the toolbar icon, or the overflow button when
/// picked from the menu), and queues a re-upload at the chosen level,
/// replacing what the store holds. A downgrade of an uploaded original asks
/// first (issue #4527, media library decision 4).
Future<void> showMediaReuploadMenu(
  BuildContext anchorContext,
  WidgetRef ref,
  MediaItem item,
) async {
  final l10n = anchorContext.l10n;
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
  final level = await showMenu<MediaUploadQuality>(
    context: anchorContext,
    position: position,
    items: [
      for (final q in MediaUploadQuality.values)
        PopupMenuItem(value: q, child: Text(_qualityLabel(l10n, q))),
    ],
  );
  if (level == null || !anchorContext.mounted) return;
  // Read now: the button the menu hangs from can go from here on (the
  // viewer's controls hide), and a level the diver picked must still be
  // asked about and queued. The dialog hangs from the navigator instead.
  final reupload = ref.read(mediaStoreReuploadProvider);
  final messenger = ScaffoldMessenger.of(anchorContext);
  final navigator = Navigator.of(anchorContext);
  final storeId = level == MediaUploadQuality.original
      ? null
      : await ref.read(mediaAttachedStoreIdProvider.future);
  if (reuploadDropsOriginal(item, level, storeId: storeId)) {
    if (!navigator.mounted) return;
    final confirmed = await _confirmDowngrade(
      navigator.context,
      _qualityLabel(l10n, level),
    );
    if (!confirmed) return;
  }
  await reupload(item.id, level);
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settings_mediaStorage_quality_reuploadQueued)),
  );
}

Future<bool> _confirmDowngrade(BuildContext context, String level) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.settings_mediaStorage_quality_downgradeTitle),
      content: Text(l10n.settings_mediaStorage_quality_downgradeBody(level)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.settings_mediaStorage_quality_downgradeConfirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}
