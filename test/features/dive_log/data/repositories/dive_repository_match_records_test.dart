import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/dive_match_records.dart';
import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// The fields duplicate matching reads, for comparing two records.
List<Object?> factsOf(DiveMatchRecord record) => [
  record.id,
  record.dateTime,
  record.maxDepth,
  record.runtime,
  record.entryTime,
  record.exitTime,
  record.bottomTime,
  record.siteName,
];

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  final epoch = DateTime.utc(2024, 3, 1, 9).millisecondsSinceEpoch;
  const hour = 3600 * 1000;

  Future<void> insertSite(String id, String name) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: name,
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
  }

  Future<void> insertDive(
    String id,
    int at, {
    String? diverId,
    int? diveNumber,
    int? entryTime,
    int? exitTime,
    int? bottomTime,
    int? runtime,
    double? maxDepth,
    String? siteId,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at,
            diverId: Value(diverId),
            diveNumber: Value(diveNumber),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            bottomTime: Value(bottomTime),
            runtime: Value(runtime),
            maxDepth: Value(maxDepth),
            siteId: Value(siteId),
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
  }

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });

  tearDown(tearDownTestDatabase);

  test('returns what getAllDives returns, in the same order', () async {
    await insertSite('site-1', 'Blue Hole');
    await insertDive(
      'full',
      epoch,
      diveNumber: 3,
      entryTime: epoch + 60000,
      exitTime: epoch + 60000 + hour,
      bottomTime: 2400,
      runtime: 3000,
      maxDepth: 31.5,
      siteId: 'site-1',
    );
    await insertDive('bare', epoch + hour);
    await insertDive('no-runtime', epoch + 2 * hour, bottomTime: 1800);
    // A dive naming a site that no longer exists keeps its row.
    await insertDive('lost-site', epoch + 3 * hour, siteId: 'gone');
    // Same start as each other: dive number breaks the tie, newest first, so
    // the insert order here is the reverse of the expected one.
    await insertDive('tied-low', epoch - hour, diveNumber: 1);
    await insertDive('tied-high', epoch - hour, diveNumber: 2);

    final records = await repository.getDiveMatchRecords();
    final dives = await repository.getAllDives();

    expect(records.map((r) => r.id).toList(), dives.map((d) => d.id).toList());
    expect(records.map((r) => r.id).toList().sublist(4), [
      'tied-high',
      'tied-low',
    ]);
    expect(
      records.map(factsOf).toList(),
      dives.map(diveMatchRecordOf).map(factsOf).toList(),
    );
  });

  test('decodes stored times as wall clocks flagged UTC', () async {
    await insertDive('dive', epoch, entryTime: epoch, exitTime: epoch + hour);

    final record = (await repository.getDiveMatchRecords()).single;

    expect(record.dateTime.isUtc, isTrue);
    expect(record.entryTime?.isUtc, isTrue);
    expect(record.exitTime?.isUtc, isTrue);
    expect(record.dateTime, DateTime.utc(2024, 3, 1, 9));
  });

  test('narrows to one diver when asked, and sees all otherwise', () async {
    await insertDive('mine', epoch, diverId: 'me');
    await insertDive('theirs', epoch + hour, diverId: 'them');
    await insertDive('nobodys', epoch + 2 * hour);

    final mine = await repository.getDiveMatchRecords(diverId: 'me');
    final everyone = await repository.getDiveMatchRecords();

    expect(mine.map((r) => r.id), ['mine']);
    expect(everyone.map((r) => r.id).toSet(), {'mine', 'theirs', 'nobodys'});
  });

  test('returns nothing for an empty logbook', () async {
    expect(await repository.getDiveMatchRecords(), isEmpty);
  });

  test('takes one statement and reads no related table', () async {
    await tearDownTestDatabase();
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    repository = DiveRepository();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await insertSite('site-1', 'Blue Hole');
    for (var i = 0; i < 20; i++) {
      await insertDive('dive-$i', epoch + i * hour, siteId: 'site-1');
    }

    final statements = await statementsOf(repository.getDiveMatchRecords);

    expect(statements, hasLength(1));
    expect(statements.single, isNot(contains('dive_tanks')));
  });
}
