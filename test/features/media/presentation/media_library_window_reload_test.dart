import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

import '../../../helpers/test_database.dart';
import '../data/repositories/species_photo_fixtures.dart';

class _AllDiversNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _AllDiversNotifier() : super(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The loaded window over the real query and the real, debounced change
/// stream, which the fake repository in media_library_refresh_test.dart
/// stands in for.
void main() {
  const pageSize = MediaLibraryRepository.pageSize;

  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => _AllDiversNotifier()),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  MediaLibraryNotifier notifier() =>
      container.read(mediaLibraryNotifierProvider.notifier);

  List<String> ids() => [
    for (final e in container.read(mediaLibraryNotifierProvider).entries)
      e.item.id,
  ];

  /// Lets a write through the debounce and the read it starts.
  Future<void> settleWrite() => Future<void>.delayed(
    MediaRepository.changeTickDebounce + const Duration(milliseconds: 200),
  );

  /// Rows `m000`, `m001`, ... newest first.
  Future<void> seed(int count) async {
    final newest = DateTime(2026, 6, 1);
    for (var i = 0; i < count; i++) {
      await insertTestMedia(
        id: 'm${i.toString().padLeft(3, '0')}',
        takenAt: newest.subtract(Duration(minutes: i)),
      );
    }
  }

  Future<void> deleteRow(String id) async {
    final db = DatabaseService.instance.database;
    await (db.delete(db.media)..where((t) => t.id.equals(id))).go();
  }

  group('a write under two loaded pages', () {
    setUp(() async {
      await seed(pageSize * 2 + 10);
      await notifier().loadFirstPage();
      await notifier().loadMore();
      expect(ids(), hasLength(pageSize * 2));
    });

    test('keeps both pages, less the deleted row', () async {
      await deleteRow('m070');
      await settleWrite();

      expect(ids(), hasLength(pageSize * 2));
      expect(ids(), isNot(contains('m070')));
    });

    test('takes in a new row at the top', () async {
      await insertTestMedia(id: 'newest', takenAt: DateTime(2026, 7, 1));
      await settleWrite();

      expect(ids().first, 'newest');
      expect(ids(), hasLength(pageSize * 2));
    });

    test('leaves paging with no gap and no repeat', () async {
      await deleteRow('m070');
      await insertTestMedia(id: 'newest', takenAt: DateTime(2026, 7, 1));
      await settleWrite();

      await notifier().loadMore();

      expect(ids().toSet(), hasLength(ids().length), reason: 'no repeats');
      expect(ids(), hasLength(pageSize * 2 + 10), reason: 'every row left');
      expect(container.read(mediaLibraryNotifierProvider).hasMore, isFalse);
    });
  });

  group('a row stops matching the active filter', () {
    setUp(() async {
      await seed(2);
    });

    Future<void> load(MediaLibraryFilter filter) async {
      container.read(mediaLibraryFilterProvider.notifier).state = filter;
      await notifier().loadFirstPage();
    }

    test('when its people tag is removed', () async {
      await insertTestBuddy(id: 'alex', name: 'Alex');
      final people = MediaPeopleRepository();
      final tag = await people.addTag(mediaId: 'm000', buddyId: 'alex');
      await people.addTag(mediaId: 'm001', buddyId: 'alex');
      await load(const MediaLibraryFilter(buddyIds: {'alex'}));
      expect(ids(), ['m000', 'm001']);

      await people.removeTag(tag.id);
      await settleWrite();

      expect(ids(), ['m001']);
    });

    test('when its species tag is removed', () async {
      await insertTestSpecies(id: 'manta', name: 'Manta');
      final species = MediaSpeciesRepository();
      await species.addTag(mediaId: 'm000', speciesId: 'manta');
      await species.addTag(mediaId: 'm001', speciesId: 'manta');
      await load(const MediaLibraryFilter(speciesId: 'manta'));
      expect(ids(), ['m000', 'm001']);

      await species.removeTag(mediaId: 'm000', speciesId: 'manta');
      await settleWrite();

      expect(ids(), ['m001']);
    });
  });
}
