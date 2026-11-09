import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_stream_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// How [MediaItem] plays here (issue #4162): from a file in the installed
/// apps, streamed from the media store in a browser.
///
/// Disposes once answered, as [resolvedFilePathProvider] does: a stream's
/// links are opened by the player, fresh each time, so nothing here goes
/// stale, but the next open should ask again all the same.
final videoPlaybackProvider = FutureProvider.family<VideoPlayback, MediaItem>(
  (ref, item) async {
    final resolving = ref.keepAlive();
    try {
      if (!ref.watch(deviceCapabilitiesProvider).isBrowser) {
        final path = await ref.watch(resolvedFilePathProvider(item).future);
        return path == null
            ? const NoPlayback(NoPlaybackReason.notFound)
            : FilePlayback(path);
      }
      final runtime = await ref.watch(mediaStoreRuntimeProvider.future);
      if (runtime == null) return const NoPlayback(NoPlaybackReason.notFound);
      final relay = await ref.watch(mediaStreamRelayProvider.future);
      return planStoreVideo(item, store: runtime.store, relay: relay);
    } finally {
      resolving.close();
    }
  },
  isAutoDispose: true,
  retry: (_, _) => null,
);
