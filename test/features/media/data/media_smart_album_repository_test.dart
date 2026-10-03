import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaSmartAlbumRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaSmartAlbumRepository();
  });
  tearDown(tearDownTestDatabase);

  test('create stores the serialized filter and reads it back', () async {
    final album = await repo.create(
      name: 'Blue Hole videos',
      filter: const MediaLibraryFilter(
        siteId: 's1',
        mediaType: MediaType.video,
      ),
    );

    final all = await repo.getAll();
    expect(all.single.id, album.id);
    expect(all.single.name, 'Blue Hole videos');
    expect(all.single.filter.siteId, 's1');
    expect(all.single.filter.mediaType, MediaType.video);
  });

  test('a species facet survives the album round trip', () async {
    await repo.create(
      name: 'Groupers',
      filter: const MediaLibraryFilter(speciesId: 'sp1'),
    );

    final all = await repo.getAll();
    expect(all.single.filter.speciesId, 'sp1');
  });

  test('create marks the row pending for sync', () async {
    final album = await repo.create(name: 'x', filter: MediaLibraryFilter.none);

    final pending = await db
        .customSelect(
          "SELECT record_id FROM sync_records "
          "WHERE entity_type = 'mediaSmartAlbums'",
        )
        .get();
    expect(pending.map((r) => r.read<String>('record_id')), contains(album.id));
  });

  test('delete removes the row and writes a tombstone', () async {
    final album = await repo.create(name: 'x', filter: MediaLibraryFilter.none);

    await repo.delete(album.id);

    expect(await repo.getAll(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'mediaSmartAlbums'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains(album.id),
    );
  });

  test('rename updates the name', () async {
    final album = await repo.create(
      name: 'old',
      filter: MediaLibraryFilter.none,
    );
    await repo.rename(album.id, 'new');
    expect((await repo.getAll()).single.name, 'new');
  });

  test('getAll orders by sortOrder then name', () async {
    await repo.create(name: 'Zulu', filter: MediaLibraryFilter.none);
    await repo.create(name: 'Alpha', filter: MediaLibraryFilter.none);
    expect((await repo.getAll()).map((a) => a.name), ['Alpha', 'Zulu']);
  });

  // mediaSmartAlbumsProvider invalidates itself on every tick. A query
  // stream emits its current result the moment it is listened to, so a
  // tick on subscribe rebuilt the provider, which subscribed again, which
  // ticked again: an endless loop for as long as the filter sheet was open,
  // then a multi-second freeze when it closed (#2835).
  group('watchChanges', () {
    test('stays quiet when nothing is written', () async {
      var ticks = 0;
      final sub = repo.watchChanges().listen((_) => ticks++);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(ticks, 0);
    });

    test('ticks when an album is created', () async {
      final tick = repo.watchChanges().first;

      await repo.create(name: 'x', filter: MediaLibraryFilter.none);

      await tick.timeout(const Duration(seconds: 5));
    });

    test('ticks when an album is deleted', () async {
      final album = await repo.create(
        name: 'x',
        filter: MediaLibraryFilter.none,
      );
      final tick = repo.watchChanges().first;

      await repo.delete(album.id);

      await tick.timeout(const Duration(seconds: 5));
    });
  });
}
