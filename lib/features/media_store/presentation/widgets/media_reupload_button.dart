import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Per-item re-upload action: pick a quality level for a single media item,
/// replacing what the store currently holds. Hidden when no media store is
/// connected on this device (nothing to re-upload to).
class MediaReuploadButton extends ConsumerWidget {
  const MediaReuploadButton({required this.item, this.color, super.key});

  final MediaItem item;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(mediaStoreResolverProvider) == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    String label(MediaUploadQuality q) => switch (q) {
      MediaUploadQuality.original =>
        l10n.settings_mediaStorage_quality_original,
      MediaUploadQuality.high => l10n.settings_mediaStorage_quality_high,
      MediaUploadQuality.balanced =>
        l10n.settings_mediaStorage_quality_balanced,
      MediaUploadQuality.small => l10n.settings_mediaStorage_quality_small,
    };
    return PopupMenuButton<MediaUploadQuality>(
      key: const Key('media-reupload-button'),
      icon: Icon(Icons.tune, color: color),
      tooltip: l10n.settings_mediaStorage_quality_section,
      onSelected: (level) async {
        await ref.read(mediaStoreReuploadProvider)(item.id, level);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.settings_mediaStorage_quality_reuploadQueued),
          ),
        );
      },
      itemBuilder: (context) => MediaUploadQuality.values
          .map((q) => PopupMenuItem(value: q, child: Text(label(q))))
          .toList(),
    );
  }
}
