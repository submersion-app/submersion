import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/wait_until.dart';

/// The real repository against the real test database, counting reads so a
/// test can tell one build from a rebuild loop.
class _CountingAlbumRepo extends MediaSmartAlbumRepository {
  int reads = 0;

  @override
  Future<List<MediaSmartAlbum>> getAll() {
    reads++;
    return super.getAll();
  }
}

void main() {
  late _CountingAlbumRepo repo;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    repo = _CountingAlbumRepo();
    container = ProviderContainer(
      overrides: [mediaSmartAlbumRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  // Watching the albums (as the filter sheet does) used to rebuild the
  // provider in an endless loop: its change stream ticked on subscribe, and
  // each tick invalidated the provider into a fresh subscription. Closing
  // the sheet then froze the app while Riverpod tore down every leftover
  // subscription (#2835).
  test('builds once while watched and nothing changes', () async {
    final sub = container.listen(mediaSmartAlbumsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(mediaSmartAlbumsProvider.future), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(repo.reads, 1);
  });

  test('re-reads when an album is created', () async {
    final sub = container.listen(mediaSmartAlbumsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(mediaSmartAlbumsProvider.future);

    await repo.create(name: 'Groupers', filter: MediaLibraryFilter.none);

    await waitUntil(
      () async =>
          (await container.read(mediaSmartAlbumsProvider.future)).isNotEmpty,
    );

    final albums = await container.read(mediaSmartAlbumsProvider.future);
    expect(albums.map((a) => a.name), ['Groupers']);
    expect(repo.reads, 2);
  });
}
