import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

import '../../../../helpers/test_database.dart';

/// Re-importing a divelogs.de logbook is only idempotent if the source id
/// the mapper writes survives the repository's source-id filter, which the
/// wizard reads before the duplicate checker's exact-match pass. The filter
/// drops keys without a dash, so a colon-joined id would silently turn
/// every re-import into a fuzzy match.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(tearDownTestDatabase);

  test('a divelogs source id survives the repository filter', () async {
    const epoch = 1700000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            isPrimary: const Value(true),
            sourceUuid: Value(DivelogsDiveMapper.sourceUuidFor('4711')),
            importedAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    final byDive = await DiveRepository().getSourceUuidByDiveId();

    expect(byDive, {'dive-1': 'divelogs-4711'});
  });
}
