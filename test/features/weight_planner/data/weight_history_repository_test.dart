import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
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

  test(
    'duplicate weight types accumulate and null tank material survives',
    () async {
      await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 1, 1),
          weights: const [
            DiveWeight(
              id: 'a',
              diveId: '',
              weightType: WeightType.belt,
              amountKg: 3.0,
            ),
            DiveWeight(
              id: 'b',
              diveId: '',
              weightType: WeightType.belt,
              amountKg: 2.0,
            ),
          ],
          tanks: const [DiveTank(id: 't1', volume: 12.0)],
        ),
      );
      final observation = (await repository.observationsForDiver(
        diverId,
      )).single;
      expect(observation.placement, {'belt': 5.0});
      expect(observation.carriedKg, 5.0);
      expect(observation.waterType, isNull);
      expect(observation.tanks.single.material, isNull);
    },
  );

  group('gear-carried lead (issue #1103)', () {
    Future<EquipmentItem> createWeights(
      String name, {
      double? dryWeightKg,
      double? buoyancyKg,
      String? style,
    }) => equipmentRepository.createEquipment(
      EquipmentItem(
        id: '',
        name: name,
        type: EquipmentType.weights,
        attributes: [
          if (dryWeightKg != null)
            EquipmentAttribute.curated(
              equipmentId: '',
              key: EquipmentAttrKeys.dryWeightKg,
              valueNum: dryWeightKg,
            ),
          if (buoyancyKg != null)
            EquipmentAttribute.curated(
              equipmentId: '',
              key: EquipmentAttrKeys.buoyancyKg,
              valueNum: buoyancyKg,
            ),
          if (style != null)
            EquipmentAttribute.curated(
              equipmentId: '',
              key: EquipmentAttrKeys.weightStyle,
              valueText: style,
            ),
        ],
      ),
    );

    test(
      'a dive whose only lead is weighted gear becomes an observation',
      () async {
        final plate = await createWeights('Weighted BPW', dryWeightKg: 3.63);
        final sta = await createWeights('Weighted STA', buoyancyKg: -4.17);

        await diveRepository.createDive(
          Dive(
            id: '',
            diverId: diverId,
            dateTime: DateTime(2026, 1, 1),
            equipment: [plate, sta],
          ),
        );

        // Before #1103 this dive carried 0 and was dropped by the
        // `carried <= 0` gate, so the diver had no training data at all.
        final observation = (await repository.observationsForDiver(
          diverId,
        )).single;
        expect(observation.carriedKg, closeTo(7.8, 1e-9));
        // Neither item names a weight_style, so no placement is invented.
        expect(observation.placement, isEmpty);
      },
    );

    test('gear ballast adds to typed rows and merges into placement', () async {
      final belt = await createWeights(
        'Belt blocks',
        dryWeightKg: 1.0,
        style: 'belt',
      );

      await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 1, 1),
          equipment: [belt],
          weights: const [
            DiveWeight(
              id: 'w1',
              diveId: '',
              weightType: WeightType.belt,
              amountKg: 3.0,
            ),
          ],
        ),
      );

      final observation = (await repository.observationsForDiver(
        diverId,
      )).single;
      expect(observation.carriedKg, closeTo(4.0, 1e-9));
      expect(observation.placement, {'belt': closeTo(4.0, 1e-9)});
    });

    test('weights gear with no declared mass leaves a dive excluded', () async {
      final bare = await createWeights('Unspecified weights');
      await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 1, 1),
          equipment: [bare],
        ),
      );
      expect(await repository.observationsForDiver(diverId), isEmpty);
    });

    test('non-weights gear contributes no lead', () async {
      final bcd = await equipmentRepository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Wing',
          type: EquipmentType.bcd,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: '',
              key: EquipmentAttrKeys.dryWeightKg,
              valueNum: 3.5,
            ),
          ],
        ),
      );
      await diveRepository.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 1, 1),
          equipment: [bcd],
        ),
      );
      expect(await repository.observationsForDiver(diverId), isEmpty);
    });
  });

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
