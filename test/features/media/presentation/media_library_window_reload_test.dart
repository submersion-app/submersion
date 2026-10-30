import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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

class _ViewingDiverNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _ViewingDiverNotifier(super.diverId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The loaded window over the real query and the real, debounced change
/// stream, which the fake repository in media_library_refresh_test.dart
/// stands in for.
void main() {
  const pageSize = MediaLibraryRepository.pageSize;

  late ProviderContainer container;

  /// The active diver the notifier builds with; null shows every diver's.
  String? viewingDiver;

  setUp(() async {
    await setUpTestDatabase();
    viewingDiver = null;
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => _ViewingDiverNotifier(viewingDiver),
        ),
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

  test('a new row leaves a fully loaded library whole', () async {
    await seed(pageSize + 5);
    await notifier().loadFirstPage();
    await notifier().loadMore();
    expect(container.read(mediaLibraryNotifierProvider).hasMore, isFalse);

    await insertTestMedia(id: 'newest', takenAt: DateTime(2026, 7, 1));
    await settleWrite();

    expect(ids().first, 'newest');
    expect(ids().last, 'm064', reason: 'the oldest row is still there');
    expect(container.read(mediaLibraryNotifierProvider).hasMore, isFalse);
  });

  group('a write to the dive behind a row', () {
    setUp(() async {
      await insertTestSite('reef', 'Blue Reef');
      await insertTestSite('wreck', 'Old Wreck');
      await insertTestDive(
        id: 'dive',
        at: DateTime(2026, 6, 1),
        siteId: 'reef',
        number: 7,
      );
      await insertTestMedia(id: 'photo', diveId: 'dive');
    });

    Future<void> writeDive(DivesCompanion change) {
      final db = DatabaseService.instance.database;
      return (db.update(
        db.dives,
      )..where((t) => t.id.equals('dive'))).write(change);
    }

    MediaLibraryEntry row() =>
        container.read(mediaLibraryNotifierProvider).entries.single;

    test('renumbers its header', () async {
      await notifier().loadFirstPage();

      await writeDive(const DivesCompanion(diveNumber: Value(8)));
      await settleWrite();

      expect(row().diveNumber, 8);
    });

    test('renames its header when the site is renamed', () async {
      await notifier().loadFirstPage();

      final db = DatabaseService.instance.database;
      await (db.update(db.diveSites)..where((t) => t.id.equals('reef'))).write(
        const DiveSitesCompanion(name: Value('Coral Reef')),
      );
      await settleWrite();

      expect(row().siteName, 'Coral Reef');
    });

    test('drops the row when the dive leaves the filtered site', () async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(siteId: 'reef');
      await notifier().loadFirstPage();
      expect(ids(), ['photo']);

      await writeDive(const DivesCompanion(siteId: Value('wreck')));
      await settleWrite();

      expect(ids(), isEmpty);
    });
  });

  group('a write to what a filter names', () {
    setUp(() async {
      await seed(2);
    });

    Future<void> load(MediaLibraryFilter filter) async {
      container.read(mediaLibraryFilterProvider.notifier).state = filter;
      await notifier().loadFirstPage();
    }

    Future<void> insertTag(String id) {
      final db = DatabaseService.instance.database;
      return db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
              appliesToMedia: const Value(true),
            ),
          );
    }

    test('deleting a selected tag no link names drops the facet', () async {
      await insertTag('unused');
      await load(const MediaLibraryFilter(tagIds: {'unused'}));
      expect(ids(), isEmpty);

      final db = DatabaseService.instance.database;
      await (db.delete(db.tags)..where((t) => t.id.equals('unused'))).go();
      await settleWrite();

      expect(ids(), ['m000', 'm001']);
    });

    test('a selected tag arriving later applies the facet', () async {
      // An album can name a tag this device has not synced yet.
      await load(const MediaLibraryFilter(tagIds: {'later'}));
      expect(ids(), ['m000', 'm001']);

      await insertTag('later');
      await settleWrite();

      expect(ids(), isEmpty);
    });

    test('deleting a selected buddy no photo names drops the facet', () async {
      await insertTestBuddy(id: 'alex', name: 'Alex');
      await load(const MediaLibraryFilter(buddyIds: {'alex'}));
      expect(ids(), isEmpty);

      final db = DatabaseService.instance.database;
      await (db.delete(db.buddies)..where((t) => t.id.equals('alex'))).go();
      await settleWrite();

      expect(ids(), ['m000', 'm001']);
    });

    test('a selected buddy arriving later applies the facet', () async {
      await load(const MediaLibraryFilter(buddyIds: {'later'}));
      expect(ids(), ['m000', 'm001']);

      await insertTestBuddy(id: 'later', name: 'Later');
      await settleWrite();

      expect(ids(), isEmpty);
    });

    test('a selected buddy moving to another diver drops the facet', () async {
      viewingDiver = 'A';
      await insertTestDiver('A');
      await insertTestDiver('B');
      await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
      await MediaPeopleRepository().addTag(mediaId: 'm000', buddyId: 'alex');
      await load(const MediaLibraryFilter(buddyIds: {'alex'}));
      expect(ids(), ['m000']);

      final db = DatabaseService.instance.database;
      await (db.update(db.buddies)..where((t) => t.id.equals('alex'))).write(
        const BuddiesCompanion(diverId: Value('B')),
      );
      await settleWrite();

      expect(ids(), ['m000', 'm001']);
    });

    test('a new default diver changes who Me names', () async {
      await insertTestDiver('A');
      await insertTestDiver('B');
      final people = MediaPeopleRepository();
      await people.addTag(mediaId: 'm000', diverId: 'A');
      await people.addTag(mediaId: 'm001', diverId: 'B');
      final db = DatabaseService.instance.database;
      Future<void> setDefault(String id, bool isDefault) =>
          (db.update(db.divers)..where((t) => t.id.equals(id))).write(
            DiversCompanion(isDefault: Value(isDefault)),
          );
      await setDefault('A', true);
      await load(const MediaLibraryFilter(includeMe: true));
      expect(ids(), ['m000']);

      await setDefault('A', false);
      await setDefault('B', true);
      await settleWrite();

      expect(ids(), ['m001']);
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
