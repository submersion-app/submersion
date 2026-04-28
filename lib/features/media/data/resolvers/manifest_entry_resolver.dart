// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md` Task 9.
// Deviations from the plan code:
//
// - The plan introduces a `NetworkUrlResolverFacade` decoupling interface so
//   3b can be authored before 3a's class names are fixed. By the time this
//   task runs, 3a's `NetworkUrlResolver` is concrete (an HTTP fetch utility
//   that returns `NetworkBytesResult`) and is *not* a `MediaSourceResolver`.
//   The plan's facade signatures (`resolveBytes`, `resolveThumbnail` with
//   `int? maxWidth`, etc.) also do not match the actual
//   `MediaSourceResolver` interface (which exposes `resolve`,
//   `resolveThumbnail({required Size target})`, plus
//   `canResolveOnThisDevice`). The plan explicitly permits skipping the
//   facade in that case, so this implementation calls the concrete
//   `NetworkUrlResolver` (HTTP) and `UrlMetadataExtractor` (EXIF over HTTP)
//   directly.
//
// - The resolver remains intentionally thin in 3b: per the plan, the
//   manifest-aware behaviour (skip EXIF when the manifest already provided
//   `takenAt` / `lat` / `lon`) lives in the eager fetch pipeline (Task 10),
//   not here. `extractMetadata` always runs the network EXIF probe; the
//   pipeline decides whether to call it for a given item.
import 'dart:ui' show Size;

import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolver for [MediaSourceType.manifestEntry] items.
///
/// Manifest entries are HTTP(S) URLs that arrived via a feed (Atom/RSS,
/// JSON, or CSV manifest), so this resolver reuses the Phase 3a HTTP stack:
/// a [NetworkUrlResolver] for byte fetches plus a [UrlMetadataExtractor]
/// for the range-GET + EXIF probe. The only difference between a
/// `networkUrl` item and a `manifestEntry` item is provenance — and the
/// eager fetch pipeline (Task 10) reads that distinction directly off the
/// [MediaItem] to decide whether to skip the EXIF probe.
///
/// `resolve` returns a [NetworkData] handle (URL + auth headers) so that
/// `cached_network_image` handles the actual byte transport and disk
/// cache. `extractMetadata` runs the unconditional EXIF probe; pipeline
/// callers gate it on whether the manifest already supplied the fields.
/// `verify` reuses the same range-fetch path — a 200/206 means the entry
/// is reachable, a 401 means credentials are missing, anything else is
/// treated as `notFound`.
class ManifestEntryResolver implements MediaSourceResolver {
  ManifestEntryResolver({
    required NetworkUrlResolver networkUrlResolver,
    required UrlMetadataExtractor urlMetadataExtractor,
  }) : _networkUrlResolver = networkUrlResolver,
       _urlMetadataExtractor = urlMetadataExtractor;

  final NetworkUrlResolver _networkUrlResolver;
  final UrlMetadataExtractor _urlMetadataExtractor;

  @override
  MediaSourceType get sourceType => MediaSourceType.manifestEntry;

  @override
  bool canResolveOnThisDevice(MediaItem item) {
    // HTTP URLs are reachable from any device with network access; there
    // is no device-local pointer to honour the way `localFile` does.
    return item.url != null && item.url!.isNotEmpty;
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final raw = item.url;
    if (raw == null || raw.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    // Returning [NetworkData] hands transport to `cached_network_image`,
    // which already runs through the auth-header injection wired up by
    // Phase 3a's image-cache provider. We do not pre-fetch bytes here —
    // that would defeat the disk cache.
    return NetworkData(url: uri);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final raw = item.url;
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final result = await _urlMetadataExtractor.extract(uri);
    if (result.failure != null) return null;
    return MediaSourceMetadata(
      takenAt: result.takenAt,
      latitude: result.lat,
      longitude: result.lon,
      width: result.width,
      height: result.height,
      mimeType: result.contentType ?? 'application/octet-stream',
    );
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final raw = item.url;
    if (raw == null || raw.isEmpty) return VerifyResult.notFound;
    final uri = Uri.tryParse(raw);
    if (uri == null) return VerifyResult.notFound;
    // A small range fetch is enough to confirm the entry is reachable
    // without pulling the whole asset. The Phase 3a resolver already
    // collapses 3xx redirects and surfaces 401s as
    // [NetworkBytesUnauthenticated].
    final result = await _networkUrlResolver.fetch(
      uri,
      extraHeaders: const {'Range': 'bytes=0-0'},
    );
    if (result is NetworkBytesOk) return VerifyResult.available;
    if (result is NetworkBytesUnauthenticated) {
      return VerifyResult.unauthenticated;
    }
    return VerifyResult.notFound;
  }
}
