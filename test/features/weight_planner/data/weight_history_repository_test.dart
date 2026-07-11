import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/weight_planner/data/repositories/weight_history_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const diverId = 'diver-1';
  late WeightHistoryRepository repository;
  late DiveRepository diveRepository;
  late EquipmentRepository equipmentRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = WeightHistoryRepository();
    diveRepository = DiveRepository();
    equipmentRepository = EquipmentRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Eric', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'assembles observations from weights, equipment, tanks, and feedback',
    () async {
      final suit = await equipmentRepository.createEquipment(
        const EquipmentItem(
          id: '',
          name: '5mm Suit',
          type: EquipmentType.wetsuit,
        ),
      );

      // Dive A: typed weights + equipment + tank + feedback.
      final diveA = await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 2, 1),
          waterType: WaterType.salt,
          equipment: [suit],
          weights: const [
            DiveWeight(
              id: 'w1',
              diveId: '',
              weightType: WeightType.integrated,
              amountKg: 4.0,
            ),
            DiveWeight(
              id: 'w2',
              diveId: '',
              weightType: WeightType.trimWeights,
              amountKg: 2.0,
            ),
          ],
          tanks: const [
            DiveTank(
              id: 't1',
              volume: 11.1,
              workingPressure: 207,
              material: TankMaterial.aluminum,
              gasMix: GasMix(o2: 21),
            ),
          ],
          weightingFeedback: WeightingFeedback.overweighted,
          weightingFeedbackKg: 1.5,
        ),
      );

      // Dive B: legacy scalar weight only, older.
      await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 1, 1),
          weightAmount: 8.0,
        ),
      );

      // Dive C: no weights at all -> excluded.
      await diveRepository.createDive(
        Dive(id: '', diverId: diverId, dateTime: DateTime(2026, 3, 1)),
      );

      final observations = await repository.observationsForDiver(diverId);
      expect(observations, hasLength(2));

      // Oldest first.
      final legacy = observations[0];
      expect(legacy.carriedKg, 8.0);
      expect(legacy.placement, isEmpty);
      expect(legacy.equipmentIds, isEmpty);

      final full = observations[1];
      expect(full.diveId, diveA.id);
      expect(full.carriedKg, 6.0);
      expect(full.placement, {'integrated': 4.0, 'trimWeights': 2.0});
      expect(full.equipmentIds, [suit.id]);
      expect(full.waterType, WaterType.salt);
      expect(full.feedback, 'overweighted');
      expect(full.feedbackKg, 1.5);
      expect(full.tanks.single.volumeL, 11.1);
      expect(full.tanks.single.material, TankMaterial.aluminum);
    },
  );

  test('dives of other divers are excluded', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-2', 'Other', 1000, 1000)",
    );
    await diveRepository.createDive(
      Dive(
        id: '',
        diverId: 'diver-2',
        dateTime: DateTime(2026, 1, 1),
        weightAmount: 5.0,
      ),
    );
    expect(await repository.observationsForDiver(diverId), isEmpty);
  });
}
