import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// Removing a key (the key editor's Remove this key, issue #4527, phase 4)
/// is an entry in History of its own, as a record page's Delete is.
void main() {
  late AppDatabase db;
  final repo = TransmitterRepository();
  final changeLog = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    await repo.create(
      Transmitter(
        id: 'k1',
        diverId: 'diver-1',
        transmitterSerial: '804512',
        label: 'Back gas tx',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    // The key above is setup, not what is under test.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String?>> operationLabels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  test('removing a key is an entry in History of its own', () async {
    await repo.delete('k1');

    expect(await repo.getById('k1'), isNull);
    expect(await operationLabels(), [ChangeLogLabels.deletedRecord]);
  });

  test('a key removed inside another operation is part of it', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.bulkDelete,
      body: () => repo.delete('k1'),
    );

    expect(await operationLabels(), [ChangeLogLabels.bulkDelete]);
  });
}
