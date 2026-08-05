import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Transfer status of one media item, for tile overlays. Quiet on
/// success: an item that is backed up, or that has no store to back up
/// to, renders nothing (design spec section 9).
enum MediaBadgeState { none, queued, transferring, failed, notBackedUp }

class MediaStoreBadge extends ConsumerWidget {
  const MediaStoreBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(mediaBadgeStateProvider(item)).value ?? MediaBadgeState.none;
    if (state == MediaBadgeState.none) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (state) {
      MediaBadgeState.failed => (Icons.error_outline, scheme.errorContainer),
      MediaBadgeState.transferring => (
        Icons.cloud_upload,
        scheme.primaryContainer,
      ),
      MediaBadgeState.notBackedUp => (
        Icons.cloud_off,
        scheme.surfaceContainerHighest,
      ),
      _ => (Icons.schedule, scheme.surfaceContainerHighest),
    };
    return CircleAvatar(
      key: const Key('media-store-badge'),
      radius: 10,
      backgroundColor: background.withValues(alpha: 0.9),
      child: Icon(icon, size: 13),
    );
  }
}
