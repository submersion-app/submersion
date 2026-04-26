import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';

/// Routes a [MediaSourceType] to its concrete [MediaSourceResolver].
///
/// Constructed once at app startup with all registered resolvers and held
/// as a Riverpod singleton. Lookup is O(1).
class MediaSourceResolverRegistry {
  final Map<MediaSourceType, MediaSourceResolver> _resolvers;

  MediaSourceResolverRegistry(
    Map<MediaSourceType, MediaSourceResolver> resolvers,
  ) : _resolvers = Map.unmodifiable(resolvers);

  /// Returns the resolver registered for [type].
  ///
  /// Throws [UnsupportedError] when no resolver is registered — this is a
  /// programmer error and indicates a missing entry in the app-startup
  /// registration.
  MediaSourceResolver resolverFor(MediaSourceType type) {
    final resolver = _resolvers[type];
    if (resolver == null) {
      throw UnsupportedError(
        'No MediaSourceResolver registered for $type. '
        'Register the resolver in app startup.',
      );
    }
    return resolver;
  }
}
