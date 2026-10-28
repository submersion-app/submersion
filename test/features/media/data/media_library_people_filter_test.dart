import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';
import 'repositories/species_photo_fixtures.dart';

/// The library's people facet (issue #1745): any of the selected buddies or
/// the viewing diver's own Me tags, each item once.
void main() {
  final repo = MediaLibraryRepository();
  final people = MediaPeopleRepository();

  setUp(() async {
    await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestDiver('B');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'bea', name: 'Bea', diverId: 'A');
    // No dive, so every profile can see each of these.
    await insertTestMedia(id: 'alex-photo', takenAt: DateTime(2024, 1, 4));
    await insertTestMedia(id: 'both-photo', takenAt: DateTime(2024, 1, 3));
    await insertTestMedia(id: 'selfie-a', takenAt: DateTime(2024, 1, 2));
    await insertTestMedia(id: 'selfie-b', takenAt: DateTime(2024, 1, 1));
    await insertTestMedia(id: 'plain', takenAt: DateTime(2024, 1, 0));
    await people.addTag(mediaId: 'alex-photo', buddyId: 'alex');
    await people.addTag(mediaId: 'both-photo', buddyId: 'alex');
    await people.addTag(mediaId: 'both-photo', buddyId: 'bea');
    await people.addTag(mediaId: 'selfie-a', diverId: 'A');
    await people.addTag(mediaId: 'selfie-b', diverId: 'B');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> ids(
    MediaLibraryFilter filter, {
    String? diverId = 'A',
  }) async => [
    for (final e in (await repo.getPage(
      diverId: diverId,
      filter: filter,
    )).entries)
      e.item.id,
  ];

  test('buddyIds matches media tagged with any of them, once each', () async {
    expect(await ids(const MediaLibraryFilter(buddyIds: {'alex', 'bea'})), [
      'alex-photo',
      'both-photo',
    ]);
    expect(
      await repo.countInScope(
        diverId: 'A',
        filter: const MediaLibraryFilter(buddyIds: {'alex', 'bea'}),
      ),
      2,
    );
  });

  test("includeMe matches the viewing diver's Me tags only", () async {
    expect(await ids(const MediaLibraryFilter(includeMe: true)), ['selfie-a']);
  });

  test("Me for diver A does not match diver B's Me tags", () async {
    expect(await ids(const MediaLibraryFilter(includeMe: true), diverId: 'B'), [
      'selfie-b',
    ]);
  });

  test(
    'with no current diver, Me is the default diver as tagging uses',
    () async {
      await DatabaseService.instance.database.customStatement(
        "UPDATE divers SET is_default = 1 WHERE id = 'B'",
      );

      expect(
        await ids(const MediaLibraryFilter(includeMe: true), diverId: null),
        ['selfie-b'],
      );
    },
  );

  test('Me and a buddy together match either', () async {
    expect(
      await ids(const MediaLibraryFilter(includeMe: true, buddyIds: {'bea'})),
      ['both-photo', 'selfie-a'],
    );
  });

  test('a filter naming only deleted buddies drops the facet', () async {
    expect(
      await ids(const MediaLibraryFilter(buddyIds: {'gone'})),
      hasLength(5),
    );
    // With a live buddy beside it, only the live buddy filters.
    expect(await ids(const MediaLibraryFilter(buddyIds: {'gone', 'bea'})), [
      'both-photo',
    ]);
  });

  test('watchMapChanges ticks on a media_people write', () async {
    final ticks = <void>[];
    final sub = repo.watchMapChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await people.addTag(mediaId: 'plain', buddyId: 'bea');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(ticks, isNotEmpty);
  });

  test('watchMediaChanges ticks on a media_people write', () async {
    final ticks = <void>[];
    final sub = repo.watchMediaChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await people.addTag(mediaId: 'plain', buddyId: 'bea');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(ticks, isNotEmpty);
  });

  test(
    "another profile's buddy in a shared album matches nothing for B",
    () async {
      await insertTestBuddy(id: 'zed', name: 'Zed', diverId: 'B');
      await people.addTag(mediaId: 'plain', buddyId: 'zed');

      // A's album names A's buddy Alex: for B that buddy is not theirs, so
      // the facet drops as for a deleted buddy rather than leaking A's tags.
      expect(
        await ids(const MediaLibraryFilter(buddyIds: {'alex'}), diverId: 'B'),
        hasLength(5),
      );
      expect(
        await ids(
          const MediaLibraryFilter(buddyIds: {'alex', 'zed'}),
          diverId: 'B',
        ),
        ['plain'],
      );
    },
  );
}
