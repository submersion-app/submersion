import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';

/// The library's Attached to facet (issue #4224): rows by what they are
/// attached to, by their own links, any of the picked kinds, ANDed with the
/// other facets.
void main() {
  late AppDatabase db;
  final repo = MediaLibraryRepository();
  const now = 1;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver'),
            name: Value('Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (id, name) in [('s1', 'Blue Hole'), ('s2', 'Canyon')]) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: Value(id),
              name: Value(name),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive'),
            diverId: Value('diver'),
            siteId: Value('s1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          const EquipmentCompanion(
            id: Value('light'),
            name: Value('Primary light'),
            type: Value('light'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    // taken_at descending is the default sort, so the ids come back in this
    // order.
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, taken_at, created_at, '
      'updated_at, dive_id, site_id, equipment_id) VALUES '
      "('dive-photo', 'a', 'photo', 5, 1, 1, 'dive', 's1', NULL), "
      "('site1-map', 'b', 'photo', 4, 1, 1, NULL, 's1', NULL), "
      "('site2-map', 'c', 'photo', 3, 1, 1, NULL, 's2', NULL), "
      "('gear-photo', 'd', 'photo', 2, 1, 1, NULL, NULL, 'light'), "
      "('loose', 'e', 'photo', 1, 1, 1, NULL, NULL, NULL)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> ids(MediaLibraryFilter filter) async => [
    for (final e in (await repo.getPage(diverId: null, filter: filter)).entries)
      e.item.id,
  ];

  MediaLibraryFilter attachedTo(Set<MediaAttachmentKind> kinds) =>
      MediaLibraryFilter(attachedTo: kinds);

  test('each kind selects the rows attached to it, by precedence', () async {
    // dive-photo also carries a site link of its own: it is still a dive
    // photo, never a site picture.
    expect(await ids(attachedTo({MediaAttachmentKind.dive})), ['dive-photo']);
    expect(await ids(attachedTo({MediaAttachmentKind.site})), [
      'site1-map',
      'site2-map',
    ]);
    expect(await ids(attachedTo({MediaAttachmentKind.equipment})), [
      'gear-photo',
    ]);
    expect(await ids(attachedTo({MediaAttachmentKind.unlinked})), ['loose']);
  });

  test('several kinds match any of them', () async {
    expect(
      await ids(
        attachedTo({MediaAttachmentKind.site, MediaAttachmentKind.equipment}),
      ),
      ['site1-map', 'site2-map', 'gear-photo'],
    );
  });

  test('no kind picked leaves the library unfiltered', () async {
    expect(await ids(MediaLibraryFilter.none), hasLength(5));
  });

  test(
    'Site with a site filter keeps only that site\'s own pictures',
    () async {
      // The site filter alone matches dive-photo through its dive's site.
      expect(await ids(const MediaLibraryFilter(siteId: 's1')), [
        'dive-photo',
        'site1-map',
      ]);
      expect(
        await ids(
          const MediaLibraryFilter(
            siteId: 's1',
            attachedTo: {MediaAttachmentKind.site},
          ),
        ),
        ['site1-map'],
      );
    },
  );

  test('the count agrees with the page', () async {
    final filter = attachedTo({MediaAttachmentKind.site});
    expect(await repo.countInScope(diverId: null, filter: filter), 2);
    expect(
      await repo.countInScope(diverId: 'diver', filter: filter),
      (await repo.getPage(diverId: 'diver', filter: filter)).entries.length,
    );
  });
}
