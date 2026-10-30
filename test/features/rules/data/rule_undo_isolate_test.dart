import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../rules_fixture.dart';

/// The app's database runs on a drift worker isolate, where a failed
/// statement reaches the caller wrapped in a DriftRemoteException. Undo
/// (#3513) must tell a refused write from a real failure there too, not
/// only against the in-process test database.
DatabaseConnection _openInMemory() =>
    DatabaseConnection(NativeDatabase.memory(setup: registerAppSqlFunctions));

void main() {
  late AppDatabase db;

  setUp(() async {
    final isolate = await DriftIsolate.spawn(_openInMemory);
    db = AppDatabase(await isolate.connect(singleClientMode: true));
    DatabaseService.instance.setTestDatabase(db);
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35);
    await seedRuleDive(db, 'd40', maxDepth: 40);
  });
  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<String> runRule(RuleAction action) async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Rule',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [action],
    );
    final ran = await RuleEngine(names: (_) async => NameIndex(const [])).run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
    return ran.runId!;
  }

  Future<Object?> column(String diveId, String col) async =>
      (await db
              .customSelect(
                'SELECT $col AS v FROM dives WHERE id = ?',
                variables: [Variable.withString(diveId)],
              )
              .getSingle())
          .data['v'];

  test('a restore the database refuses is skipped, the rest undone', () async {
    await db.customStatement(
      'INSERT INTO trips (id, name, start_date, end_date, created_at, '
      "updated_at) VALUES ('t1', 'Old', 0, 0, 0, 0), ('t2', 'New', 0, 0, 0, 0)",
    );
    await db.customStatement(
      "UPDATE dives SET trip_id = 't1' WHERE id = 'd35'",
    );
    final run = await runRule(
      const SetDiveFieldAction(BulkField.trip, {'tripId': 't2'}),
    );
    // d35's old trip is gone, so putting it back would break the foreign
    // key; d40 had no trip, so its restore still lands.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement("DELETE FROM trips WHERE id = 't1'");
    await db.customStatement('PRAGMA foreign_keys = ON');

    final result = await RuleUndoService().undo(run);

    expect(result.restoredTargets, 1);
    expect(result.skippedEditedTargets, 1);
    expect(await column('d35', 'trip_id'), 't2');
    expect(await column('d40', 'trip_id'), isNull);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isTrue);
  });

  test('any other database failure fails the undo', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    // A change row whose "before" the database cannot hold (dive_type is
    // NOT NULL): not a refused reference, a real failure.
    await db.customStatement(
      'UPDATE rule_run_changes SET '
      "before_json = '{\"dive_type\":null}', "
      "after_json = '{\"dive_type\":\"recreational\"}'",
    );

    await expectLater(RuleUndoService().undo(run), throwsA(anything));
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
    expect(await column('d35', 'water_type'), 'salt');
  });
}
