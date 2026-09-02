import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'a tag written through the repository is fetchable by sync type',
    () async {
      final tag = await MediaSpeciesRepository().addTag(
        mediaId: 'p1',
        speciesId: 'c1',
      );

      final record = await serializer.fetchRecord('mediaSpecies', tag.id);

      expect(record, isNotNull);
      expect(record!['mediaId'], 'p1');
      expect(record['speciesId'], 'c1');
    },
  );

  test('upsertRecord and deleteRecord round-trip a remote tag', () async {
    await serializer.upsertRecord('mediaSpecies', {
      'id': 'mst-remote',
      'mediaId': 'p1',
      'speciesId': 'c1',
      'createdAt': 1000,
    });
    expect(
      await serializer.fetchRecord('mediaSpecies', 'mst-remote'),
      isNotNull,
    );

    await serializer.deleteRecord('mediaSpecies', 'mst-remote');

    expect(await serializer.fetchRecord('mediaSpecies', 'mst-remote'), isNull);
  });

  test('SyncData carries mediaSpecies through toJson and fromJson', () {
    const data = SyncData(
      mediaSpecies: [
        {'id': 'mst-1', 'mediaId': 'p1', 'speciesId': 'c1', 'createdAt': 1},
      ],
    );

    final restored = SyncData.fromJson(data.toJson());

    expect(restored.mediaSpecies.single['id'], 'mst-1');
  });

  test('mediaSpecies merges as a clockless child of media and species', () {
    expect(SyncService.entityHasUpdatedAt['mediaSpecies'], isFalse);
    final refs = SyncService.parentRefs['mediaSpecies']!;
    expect(refs.map((r) => (r.field, r.parent, r.nullable)).toSet(), {
      ('mediaId', 'media', false),
      ('speciesId', 'species', false),
    });
  });
}
