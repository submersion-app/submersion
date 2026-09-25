import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Newest dive photos and videos for the dashboard ribbon.
///
/// Self-invalidates on the media-table change tick so the ribbon reflects
/// deletions, imports and syncs without a pull-to-refresh. An item deleted
/// from the dive gallery, the files tab, or a dive-deletion cascade removes
/// its `media` row directly, and none of those paths knows about this
/// dashboard provider; before the tick subscription the ribbon kept rendering
/// the deleted item as a dead tile until the app restarted.
///
/// Scoped to the active diver, and rebuilt when the diver switches, so a
/// secondary profile never shows another diver's photos.
final recentMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  return repository.getRecentMedia(limit: 12, diverId: diverId);
});
