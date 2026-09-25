import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/test_database.dart';

DiveScenario _scenario(String diveId, {String id = '', String name = 'A'}) =>
    DiveScenario(
      id: id,
      diveId: diveId,
      name: name,
      branchSeconds: 900,
      mode: ScenarioMode.replan,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
      createdAt: DateTime(2026, 8, 21),
      updatedAt: DateTime(2026, 8, 21),
    );

void main() {
  late db.AppDatabase database;
  setUp(() async {
    database = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<String> dive() async => (await DiveRepository().createDive(
    Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
  )).id;

  test(
    'save mints an id, round-trips, and preserves createdAt on update',
    () async {
      final diveId = await dive();
      final repo = DiveScenarioRepository();
      final saved = await repo.saveScenario(_scenario(diveId));
      expect(saved.id, isNotEmpty);
      final loaded = await repo.getScenario(saved.id);
      expect(loaded!.name, 'A');
      expect(loaded.mode, ScenarioMode.replan);
      expect(
        loaded.interventions.single,
        const LoseTankIntervention(tankId: 'deco50'),
      );
      expect(loaded.branchSeconds, 900);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final renamed = await repo.saveScenario(loaded.copyWith(name: 'B'));
      expect(renamed.createdAt, loaded.createdAt);
      expect(renamed.updatedAt.isAfter(loaded.updatedAt), isTrue);
      expect((await repo.getScenariosForDive(diveId)).single.name, 'B');
    },
  );

  test('list is newest first and scoped to the dive', () async {
    final d1 = await dive();
    final d2 = (await DiveRepository().createDive(
      Dive(id: '', diveNumber: 2, dateTime: DateTime(2026, 1, 2)),
    )).id;
    final repo = DiveScenarioRepository();
    await repo.saveScenario(_scenario(d1, name: 'first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.saveScenario(_scenario(d1, name: 'second'));
    await repo.saveScenario(_scenario(d2, name: 'other'));
    final list = await repo.getScenariosForDive(d1);
    expect(list.map((s) => s.name), ['second', 'first']);
  });

  test('delete removes the row and logs a tombstone', () async {
    final diveId = await dive();
    final repo = DiveScenarioRepository();
    final saved = await repo.saveScenario(_scenario(diveId));
    await repo.deleteScenario(saved.id);
    expect(await repo.getScenario(saved.id), isNull);
    final deletions = await database.select(database.deletionLog).get();
    expect(
      deletions.any(
        (d) => d.entityType == 'diveScenarios' && d.recordId == saved.id,
      ),
      isTrue,
    );
  });

  test('duplicate yields a fresh id with the same content', () async {
    final diveId = await dive();
    final repo = DiveScenarioRepository();
    final saved = await repo.saveScenario(_scenario(diveId));
    final copy = await repo.duplicateScenario(saved.id);
    expect(copy, isNotNull);
    expect(copy!.id, isNot(saved.id));
    expect(copy.name, saved.name);
    expect((await repo.getScenariosForDive(diveId)), hasLength(2));
  });

  test('deleting the dive cascades to its scenarios', () async {
    final diveId = await dive();
    final repo = DiveScenarioRepository();
    await repo.saveScenario(_scenario(diveId));
    await DiveRepository().deleteDive(diveId, cascadeMedia: false);
    expect(await repo.getScenariosForDive(diveId), isEmpty);
  });
}
