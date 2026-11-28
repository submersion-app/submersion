import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/data/services/bulk_gear_link_service.dart';

import '../../../../helpers/test_database.dart';

/// Link to gear on a Library selection (issue #5046): one write for every
/// selected photo, with undo.
void main() {
  late AppDatabase db;
  final gear = MediaGearRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['m1', 'm2']) {
      await db.customStatement(
        'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
        "VALUES ('$id', '', 'photo', 1, 1)",
      );
    }
    for (final id in ['e1', 'e2']) {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES ('$id', '$id', 'other', 0, 0)",
      );
    }
  });
  tearDown(tearDownTestDatabase);

  test(
    'apply adds to every selected photo and removes from every one',
    () async {
      await gear.addGear(['m1'], ['e2']);
      final service = BulkGearLinkService(gear);

      await service.apply(
        mediaIds: ['m1', 'm2'],
        addGearIds: {'e1'},
        removeGearIds: {'e2'},
      );

      expect(await gear.gearIdsFor('m1'), ['e1']);
      expect(await gear.gearIdsFor('m2'), ['e1']);
    },
  );

  test("undo restores each photo's prior links", () async {
    await gear.addGear(['m1'], ['e2']);
    final service = BulkGearLinkService(gear);

    final prior = await service.apply(
      mediaIds: ['m1', 'm2'],
      addGearIds: {'e1'},
      removeGearIds: {'e2'},
    );
    await service.undo(prior);

    expect(await gear.gearIdsFor('m1'), ['e2']);
    expect(await gear.gearIdsFor('m2'), isEmpty);
  });
}
