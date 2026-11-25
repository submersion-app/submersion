import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_stream_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// The copies of each video that [videoPlaybackProvider] holds a playback
/// for now, by media id (issue #4958).
///
/// The playback is keyed by the whole item, and an item's copy changes
/// while it plays: the Media library's items arrive without their dive
/// enrichment, which the viewer fills in, and any write to the row moves
/// its update time. The fish scan asks with the copy on screen, so it
/// finds the player's playback here rather than under that exact key.
class LiveVideoPlaybacks {
  /// Replaced whole on every change, never changed in place.
  var _live = const <String, List<MediaItem>>{};

  void _add(MediaItem item) => _live = {
    ..._live,
    item.id: List.unmodifiable([...?_live[item.id], item]),
  };

  void _remove(MediaItem item) {
    final rest = [
      for (final copy in _live[item.id] ?? const <MediaItem>[])
        if (copy != item) copy,
    ];
    _live = {
      for (final MapEntry(:key, :value) in _live.entries)
        if (key != item.id) key: value,
      if (rest.isNotEmpty) item.id: List.unmodifiable(rest),
    };
  }

  /// The copies of the video [mediaId] with a playback held now, the most
  /// recently resolved last.
  List<MediaItem> of(String mediaId) => _live[mediaId] ?? const <MediaItem>[];
}

final liveVideoPlaybacksProvider = Provider<LiveVideoPlaybacks>(
  (ref) => LiveVideoPlaybacks(),
);

/// How [MediaItem] plays here (issue #4162): from a file in the installed
/// apps, streamed from the media store in a browser.
///
/// Disposes once answered, as [resolvedFilePathProvider] does: a stream's
/// links are opened by the player, fresh each time, so nothing here goes
/// stale, but the next open should ask again all the same.
final videoPlaybackProvider = FutureProvider.family<VideoPlayback, MediaItem>(
  (ref, item) async {
    // Listed while it exists, for a reader asking with a later copy.
    final live = ref.read(liveVideoPlaybacksProvider).._add(item);
    ref.onDispose(() => live._remove(item));
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
      final store = runtime.store;
      // Only a store read a range at a time streams through the worker; an
      // S3 or Dropbox video never waits on it starting.
      final relay = store is RangeReadStore && store is! DirectLinkStore
          ? await ref.watch(mediaStreamRelayProvider.future)
          : null;
      return planStoreVideo(
        await withProbedStamps(item, store: store),
        store: store,
        relay: relay,
      );
    } finally {
      resolving.close();
    }
  },
  isAutoDispose: true,
  retry: (_, _) => null,
);
