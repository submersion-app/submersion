import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaAspectCacheRepository repository;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repository = MediaAspectCacheRepository(database: db);
  });

  tearDown(() => db.close());

  test('stored shapes load back, with or without a stored size', () async {
    await repository.putAll({
      'a': (ratio: 0.75, width: 4000, height: 3000),
      'b': (ratio: 0.5, width: null, height: null),
    });

    expect(await repository.loadAll(), {
      'a': (ratio: 0.75, width: 4000, height: 3000),
      'b': (ratio: 0.5, width: null, height: null),
    });
  });

  test('a new shape for the same item replaces the old', () async {
    await repository.putAll({'a': (ratio: 0.75, width: 4000, height: 3000)});
    await repository.putAll({'a': (ratio: 1.5, width: 3000, height: 2000)});

    expect(await repository.loadAll(), {
      'a': (ratio: 1.5, width: 3000, height: 2000),
    });
  });

  test('nothing stored loads an empty map', () async {
    expect(await repository.loadAll(), isEmpty);
  });
}
