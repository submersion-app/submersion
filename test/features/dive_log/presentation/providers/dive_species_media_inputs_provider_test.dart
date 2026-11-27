import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

import '../../../../helpers/test_database.dart';

/// A dive's media, tags and identifications, the inputs that place species
/// on its profile (issue #5092), read from the database and refreshed when
/// a tag changes.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO species (id, common_name, category) VALUES "
      "('shark', 'Shark', 'shark'), ('ray', 'Ray', 'ray')",
    );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'p1',
            diveId: const Value('d1'),
            filePath: '/p1.jpg',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test(
    'reads the dive media and their tags, and refreshes on a new tag',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tags = container.read(mediaSpeciesRepositoryProvider);
      await tags.addTag(mediaId: 'p1', speciesId: 'shark');
      final sub = container.listen(
        diveSpeciesMediaInputsProvider('d1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final first = await container.read(
        diveSpeciesMediaInputsProvider('d1').future,
      );
      expect([for (final m in first.media) m.id], ['p1']);
      expect(
        [for (final t in first.tagsByMedia['p1']!) t.speciesId],
        ['shark'],
      );
      expect(first.identificationsByMedia, isEmpty);

      await tags.addTag(mediaId: 'p1', speciesId: 'ray');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = await container.read(
        diveSpeciesMediaInputsProvider('d1').future,
      );
      expect(
        {for (final t in second.tagsByMedia['p1']!) t.speciesId},
        {'shark', 'ray'},
      );
    },
  );
}
