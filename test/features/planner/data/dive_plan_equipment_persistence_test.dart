import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivePlanRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DivePlanRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'BCD', 'bcd', 1000, 1000), "
      "('e2', 'Wetsuit', 'wetsuit', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DivePlan plan({
    List<String> equipmentIds = const [],
    double? plannedWeightKg,
    Map<String, double>? plannedWeightPlacement,
  }) => DivePlan(
    id: 'p1',
    name: 'Reef plan',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    gfLow: 30,
    gfHigh: 70,
    equipmentIds: equipmentIds,
    plannedWeightKg: plannedWeightKg,
    plannedWeightPlacement: plannedWeightPlacement,
  );

  test(
    'equipment ids and planned weight round-trip through savePlan/getPlan',
    () async {
      await repository.savePlan(
        plan(
          equipmentIds: ['e1', 'e2'],
          plannedWeightKg: 6.5,
          plannedWeightPlacement: {'integrated': 4.5, 'trimWeights': 2.0},
        ),
      );

      final loaded = await repository.getPlan('p1');
      expect(loaded!.equipmentIds.toSet(), {'e1', 'e2'});
      expect(loaded.plannedWeightKg, 6.5);
      expect(loaded.plannedWeightPlacement, {
        'integrated': 4.5,
        'trimWeights': 2.0,
      });
    },
  );

  test('re-saving with fewer items deletes the removed junction row and '
      'writes a tombstone', () async {
    await repository.savePlan(plan(equipmentIds: ['e1', 'e2']));
    await repository.savePlan(plan(equipmentIds: ['e1']));

    final loaded = await repository.getPlan('p1');
    expect(loaded!.equipmentIds, ['e1']);

    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect("SELECT * FROM deletion_log WHERE record_id = 'p1|e2'")
        .get();
    expect(tombstones, isNotEmpty);
  });

  test('watchPlanChanges fires on junction-only changes', () async {
    await repository.savePlan(plan(equipmentIds: ['e1']));

    var fired = false;
    final sub = repository.watchPlanChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);

    await repository.savePlan(plan(equipmentIds: ['e1', 'e2']));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fired, isTrue);
  });

  test('null planned weight round-trips as null', () async {
    await repository.savePlan(plan());
    final loaded = await repository.getPlan('p1');
    expect(loaded!.plannedWeightKg, isNull);
    expect(loaded.plannedWeightPlacement, isNull);
    expect(loaded.equipmentIds, isEmpty);
  });
}
