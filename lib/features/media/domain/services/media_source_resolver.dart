import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves a [MediaItem] of a particular [sourceType] to displayable data.
///
/// Each [MediaSourceType] is handled by a single concrete implementation.
/// The [MediaSourceResolverRegistry] dispatches `MediaItem`s to the
/// resolver registered for their `sourceType`.
///
/// Implementations must:
///   * Be cheap to construct — they're held as singletons by the registry.
///   * Never throw from [resolve]; return [UnavailableData] on any failure.
///   * Be safe to call concurrently for different items.
abstract class MediaSourceResolver {
  /// The [MediaSourceType] this resolver handles.
  MediaSourceType get sourceType;

  /// Whether this resolver can read [item] on the current device.
  ///
  /// Returns `false` when [MediaItem.originDeviceId] points to a different
  /// device for source types whose pointer is device-local (filesystem
  /// paths, iOS bookmarks, Android persistable URIs, service connector
  /// accounts not yet signed in here).
  bool canResolveOnThisDevice(MediaItem item);

  /// Resolves [item] to a displayable handle.
  ///
  /// Never throws — returns an [UnavailableData] with a reason on failure
  /// so the UI can render the appropriate placeholder.
  Future<MediaSourceData> resolve(MediaItem item);

  /// Resolves a thumbnail-sized representation of [item].
  ///
  /// The default implementation returns the same handle as [resolve];
  /// resolvers with native thumbnail APIs (e.g., photo_manager) override.
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);

  /// Extracts EXIF / format metadata from [item].
  ///
  /// Called once at link time; results are stored on the [MediaItem] row
  /// by the calling repository. Returns `null` on failure rather than
  /// throwing — failed extraction is non-fatal.
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item);

  /// Performs a lightweight existence check against [item]'s source.
  ///
  /// Used by the user-triggered scan and (for filesystem sources) during
  /// display when read attempts fail.
  Future<VerifyResult> verify(MediaItem item);
}
