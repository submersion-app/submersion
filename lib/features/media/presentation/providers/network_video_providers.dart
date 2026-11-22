import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/storage/cache_location.dart';
import 'package:submersion/features/media/data/services/network_video_cache.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// The download cache network videos play from.
final networkVideoCacheProvider = Provider<NetworkVideoCache>((ref) {
  final credentials = ref.watch(networkCredentialsServiceProvider);
  return NetworkVideoCache(
    client: ref.watch(httpClientProvider),
    directory: () async => (await cacheLocation()).networkVideos,
    headersFor: credentials.headersFor,
  );
});

/// Whether the diver chose to play the original of a video whose row points
/// at a smaller conversion (a shared album's 720p stream), by media id.
/// For this session only: the next open plays the conversion again.
final playVideoOriginalProvider = StateProvider.family<bool, String>(
  (ref, mediaId) => false,
);

/// Whether [item] is a network video this app plays through
/// [networkVideoCacheProvider].
bool isNetworkVideo(MediaItem item) =>
    item.isVideo &&
    (item.url?.isNotEmpty ?? false) &&
    (item.sourceType == MediaSourceType.networkUrl ||
        item.sourceType == MediaSourceType.manifestEntry);

/// Whether [item] is a network photo whose original file may be a motion
/// photo: not a rendition (a shared album's xl thumbnail, which is what a
/// live photo or a view-only share's photo points at, carries no clip).
bool mayBeMotionPhoto(MediaItem item) {
  final raw = item.url;
  if (item.mediaType != MediaType.photo || raw == null || raw.isEmpty) {
    return false;
  }
  if (item.sourceType != MediaSourceType.networkUrl &&
      item.sourceType != MediaSourceType.manifestEntry) {
    return false;
  }
  final uri = Uri.tryParse(raw);
  return uri != null && uri.queryParameters['api'] != 'SYNO.Foto.Thumbnail';
}

/// Whether the network photo at the URL is a motion photo, from the first
/// bytes of its file. False when it could not be read: the still shows as
/// before.
final motionPhotoProbeProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, url) async {
      final cache = ref.read(networkVideoCacheProvider);
      return await cache.isMotionPhoto(Uri.parse(url)) ?? false;
    });

/// Whether [item] plays a conversion that has an original to switch to.
bool hasPlayableOriginal(MediaItem item) {
  final raw = item.url;
  if (!isNetworkVideo(item) || raw == null) return false;
  final uri = Uri.tryParse(raw);
  return uri != null && SynologyShareLink.isStream(uri);
}

/// The URL [item] plays from: its own, or the original when the diver chose
/// it and there is one.
Uri? networkVideoUrl(MediaItem item, {required bool original}) {
  final raw = item.url;
  if (raw == null) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (!original) return uri;
  return SynologyShareLink.originalFor(uri) ?? uri;
}
