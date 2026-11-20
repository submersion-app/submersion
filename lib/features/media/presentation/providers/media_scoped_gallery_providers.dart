import 'package:meta/meta.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';

/// What a focused gallery shows (issue #4741): the rows [filter] selects,
/// laid out in [mode]. Compares by value, so a gallery reopened on the same
/// scope shares one walk.
@immutable
class MediaGalleryScope {
  const MediaGalleryScope({
    required this.filter,
    this.mode = MediaLibraryViewMode.grid,
  });

  final MediaLibraryFilter filter;

  /// Grid, by dive or timeline. A focused gallery offers no map.
  final MediaLibraryViewMode mode;

  @override
  bool operator ==(Object other) =>
      other is MediaGalleryScope &&
      other.filter == filter &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(filter, mode);
}

/// The paged rows of a focused gallery, such as the one a site's photo card
/// opens (issue #4741). The same notifier as the library's, but over its own
/// [MediaGalleryScope] rather than the Media screen's filter and view, so
/// opening one never changes what the Media screen shows. It takes the
/// library's sort, and is released when the gallery closes.
final mediaScopedLibraryProvider = StateNotifierProvider.autoDispose
    .family<MediaLibraryNotifier, MediaLibraryState, MediaGalleryScope>((
      ref,
      scope,
    ) {
      final sort = ref.watch(mediaLibrarySortProvider);
      return MediaLibraryNotifier(
        ref.watch(mediaLibraryRepositoryProvider),
        ref.watch(currentDiverIdProvider),
        scope.filter,
        sort,
        grouping: scope.mode.grouping.forSort(sort.field),
      );
    });
