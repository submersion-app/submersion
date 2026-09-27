import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

/// Applying a set skips a member another profile owns and no longer shares
/// with the dive's diver (issue #2046); everything else applies as before.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'wife']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 0, 0)",
      );
    }
    for (final (id, owner) in [
      ('mine', "'me'"),
      ('shared', "'wife'"),
      ('unshared', "'wife'"),
      ('ownerless', 'NULL'),
    ]) {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at, '
        "diver_id) VALUES ('$id', '$id', 'bcd', 0, 0, $owner)",
      );
    }
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['shared'],
      diverIds: ['me'],
      actingDiverId: 'wife',
    );
  });

  tearDown(tearDownTestDatabase);

  test('drops only members another profile owns and does not share', () async {
    final ids = await EquipmentRepository().usableSetMemberIds([
      'unshared',
      'shared',
      'missing',
      'ownerless',
      'mine',
    ], 'me');
    expect(ids, ['shared', 'missing', 'ownerless', 'mine']);
  });
}
