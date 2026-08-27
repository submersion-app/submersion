import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';

final mediaSmartAlbumRepositoryProvider = Provider<MediaSmartAlbumRepository>(
  (ref) => MediaSmartAlbumRepository(),
);

/// Every saved album, re-read whenever the set changes (including from a
/// sync pull -- albums are synced, so another device can add one).
final mediaSmartAlbumsProvider = FutureProvider<List<MediaSmartAlbum>>((
  ref,
) async {
  final repo = ref.watch(mediaSmartAlbumRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  return repo.getAll();
});
