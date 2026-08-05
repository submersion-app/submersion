import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Newest dive photos for the dashboard ribbon. Refreshed by the
/// dashboard's pull-to-refresh invalidation (the media repository has no
/// change stream to self-invalidate on).
final recentPhotosProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getRecentPhotos(limit: 12);
});
