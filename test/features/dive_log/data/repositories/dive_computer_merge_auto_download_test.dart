import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3361: merging duplicates keeps the opt-out from auto-connect that
/// any of them carried, on the surviving record.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-1'),
            name: Value('Diver'),
            createdAt: Value(1000),
            updatedAt: Value(1000),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(String id, {bool optedOut = false}) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          diverId: const Value('diver-1'),
          name: Value(id),
          manufacturer: const Value('Shearwater'),
          model: const Value('Perdix 2'),
          autoDownloadDisabled: Value(optedOut),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  Future<bool> survivorOptedOut() async {
    final row = await (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals('survivor'))).getSingle();
    return row.autoDownloadDisabled;
  }

  test("keeps a duplicate's opt-out", () async {
    await insertComputer('survivor');
    await insertComputer('dup', optedOut: true);

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: const ['dup'],
    );

    expect(await survivorOptedOut(), isTrue);
  });

  test('leaves the survivor included when no record opted out', () async {
    await insertComputer('survivor');
    await insertComputer('dup');

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: const ['dup'],
    );

    expect(await survivorOptedOut(), isFalse);
  });
}
