import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
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

/// Opens the upload-quality picker for [item], anchored to the widget
/// [anchorContext] belongs to (the toolbar icon, or the overflow button when
/// picked from the menu), and queues a re-upload at the chosen level,
/// replacing what the store holds.
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
  await ref.read(mediaStoreReuploadProvider)(item.id, level);
  if (!anchorContext.mounted) return;
  ScaffoldMessenger.of(anchorContext).showSnackBar(
    SnackBar(content: Text(l10n.settings_mediaStorage_quality_reuploadQueued)),
  );
}
