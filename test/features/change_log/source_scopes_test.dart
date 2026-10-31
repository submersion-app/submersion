import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

import '../../core/database/change_log/change_log_support.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDive(db, 'one', diverId: 'me');
    await insertDive(db, 'two', diverId: 'me');
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<List<ChangeLogOperationRow>> operations() async {
    await ChangeLogSettler(db).settle();
    return db.select(db.changeLogOperations).get();
  }

  test('a bulk delete is one operation', () async {
    await DiveRepository().bulkDeleteDives(['one', 'two']);

    final operation = (await operations()).single;
    expect(operation.source, 'manual');
    expect(operation.label, ChangeLogLabels.bulkDelete);
    expect(operation.rootId, isNull);
  });

  test('a bulk field update is one operation', () async {
    await DiveRepository().bulkUpdateFields([
      'one',
      'two',
    ], const DivesCompanion(notes: Value('Both')));

    final operation = (await operations()).single;
    expect(operation.label, ChangeLogLabels.bulkEdit);
    expect(operation.eventCount, 2);
  });

  test('a merge is one operation', () async {
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at) VALUES '
      "('keep', 'me', 'Keep', 0, 0), ('gone', 'me', 'Gone', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt', 'one', 'gone', 0)",
    );
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await TagRepository().mergeTags(
      sourceTagIds: ['gone'],
      survivingTagId: 'keep',
      name: 'Keep',
      colorHex: null,
    );

    final operation = (await operations()).single;
    expect(operation.label, ChangeLogLabels.merge);
  });

  test('a bulk site delete is one operation', () async {
    for (final id in ['s1', 's2']) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
              diverId: const Value('me'),
            ),
          );
    }
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await SiteRepository().bulkDeleteSites(['s1', 's2']);

    expect((await operations()).single.label, ChangeLogLabels.bulkDelete);
  });

  test('a rule run is one operation', () async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Tag all',
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      actions: const [AppendDiveNotesAction('checked')],
    );
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await RuleEngine(names: (_) async => NameIndex(const [])).run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
        sourceLabel: 'On demand',
      ),
    );

    final operation = (await operations()).single;
    expect(operation.source, 'rule');
    expect(operation.label, 'On demand');
    expect(operation.eventCount, 2);
  });

  test('a download is one operation named for the computer', () async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final computer = domain.DiveComputer.create(id: 'perdix', name: 'Perdix');
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await DiveImportService(
      repository: DiveComputerRepository(),
      diveRepository: DiveRepository(),
    ).importDives(
      dives: [
        for (final minute in [0, 90])
          DownloadedDive(
            fingerprint: 'fp$minute',
            startTime: DateTime(2026, 4, 1, 9, minute),
            durationSeconds: 1800,
            maxDepth: 18.0,
            profile: const [],
          ),
      ],
      computer: computer,
      diverId: 'me',
    );

    final operation = (await operations()).single;
    expect(operation.source, 'download');
    expect(operation.label, 'Perdix');
  });
}
