import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  late LocalCacheDatabase db;
  late RecentQueryRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = RecentQueryRepository();
  });
  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  const parsed = ParsedQuery(subject: QuerySubject.dives);

  test('records and lists newest first', () async {
    await repo.record('a', 'en', parsed);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.record('b', 'en', parsed);
    final list = await repo.list();
    expect(list.map((r) => r.sentence), ['b', 'a']);
    expect(list.first.parsed.subject, QuerySubject.dives);
  });

  test(
    're-recording the same sentence bumps it instead of duplicating',
    () async {
      await repo.record('Turtles in Bonaire', 'en', parsed);
      await repo.record('a', 'en', parsed);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.record('turtles  in bonaire', 'en', parsed);
      final list = await repo.list();
      expect(list, hasLength(2));
      expect(list.first.sentence, 'turtles  in bonaire');
    },
  );

  test('the cap keeps the twenty newest', () async {
    for (var i = 0; i < 25; i++) {
      await repo.record('q$i', 'en', parsed);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final list = await repo.list();
    expect(list, hasLength(RecentQueryRepository.cap));
    expect(list.first.sentence, 'q24');
    expect(list.last.sentence, 'q5');
  });

  test('rows from an older schema are skipped and deleted', () async {
    await repo.record('old', 'en', parsed);
    await db.customStatement('UPDATE recent_queries SET schema_version = 0');
    expect(await repo.list(), isEmpty);
    final rows = await db
        .customSelect('SELECT COUNT(*) AS n FROM recent_queries')
        .getSingle();
    expect(rows.read<int>('n'), 0);
  });
}
