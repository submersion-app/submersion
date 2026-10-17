import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/data/data_facts_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Personal',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's2',
            name: 'Club',
            createdAt: 0,
            updatedAt: 0,
            sharedLibraryId: const Value('lib-1'),
          ),
        );
    // Not photos or videos: the facts line must not count them as such.
    for (final (id, type) in [
      ('sig1', 'instructor_signature'),
      ('doc1', 'document'),
    ]) {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '/x/$id',
              fileType: Value(type),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    for (final id in ['m1', 'm2', 'm3']) {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '/x/$id.jpg',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  }

  test('counts dives, personal sites, photos and videos', () async {
    await seed();

    final facts = await const DataFactsRepository().load(db, null);

    expect(facts.dives, 2);
    expect(facts.sites, 1, reason: 'shared library sites are not counted');
    expect(facts.media, 3);
    expect(facts.databaseBytes, 0);
  });

  test('database size is the main file plus its WAL', () async {
    final dir = await Directory.systemTemp.createTemp('data_facts_');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = p.join(dir.path, 'submersion.db');
    await File(dbPath).writeAsBytes(List.filled(1000, 0));
    await File('$dbPath-wal').writeAsBytes(List.filled(500, 0));

    final facts = await const DataFactsRepository().load(db, dbPath);

    expect(facts.databaseBytes, 1500);
  });

  test('a missing database file reads as zero bytes', () async {
    final facts = await const DataFactsRepository().load(
      db,
      p.join(Directory.systemTemp.path, 'no_such_dir_xyz', 'x.db'),
    );

    expect(facts.databaseBytes, 0);
  });
}
