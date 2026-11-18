import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/sql/dive_weight_sql.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

import '../../../../helpers/test_database.dart';

/// Lead carried as weights gear counts toward the dive's recorded weight,
/// beside the Weights rows (issue #4442). The SQL and the Dart spelling must
/// agree on it, read back from the database as every surface reads a dive.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    equipmentRepo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> item(
    String id, {
    EquipmentType type = EquipmentType.weights,
    double? dryKg,
    double? buoyancyKg,
    bool custom = false,
  }) => equipmentRepo.createEquipment(
    EquipmentItem(
      id: id,
      name: 'Gear $id',
      type: type,
      attributes: [
        if (dryKg != null)
          EquipmentAttribute(
            id: '$id-dry',
            equipmentId: id,
            key: EquipmentAttrKeys.dryWeightKg,
            isCustom: custom,
            valueNum: dryKg,
          ),
        if (buoyancyKg != null)
          EquipmentAttribute(
            id: '$id-buoy',
            equipmentId: id,
            key: EquipmentAttrKeys.buoyancyKg,
            isCustom: custom,
            valueNum: buoyancyKg,
          ),
      ],
    ),
  );

  Future<void> agree({
    List<double> rows = const [],
    double? scalar,
    List<GearLink> gear = const [],
    required double? kg,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd',
        dateTime: DateTime.utc(2026),
        weightAmount: scalar,
        weights: [
          for (final (i, amount) in rows.indexed)
            domain.DiveWeight(
              id: 'w$i',
              diveId: 'd',
              weightType: WeightType.belt,
              amountKg: amount,
            ),
        ],
        gear: gear,
      ),
    );
    final row = await db
        .customSelect(
          'SELECT ${recordedWeightKgSql('d')} AS kg '
          "FROM dives d WHERE d.id = 'd'",
        )
        .getSingle();
    final dive = await diveRepo.getDiveById('d');
    // The dive list hydrates in a batch, apart from getDiveById; its dives
    // must carry the weight rows too, or the gear share reads as the total.
    final listed = (await diveRepo.getDiveListSnapshot()).dives.single;

    expect(row.read<double?>('kg'), closeToOrNull(kg), reason: 'SQL');
    expect(dive!.recordedWeightKg, closeToOrNull(kg), reason: 'Dart');
    expect(listed.recordedWeightKg, closeToOrNull(kg), reason: 'dive list');
  }

  test('weights gear alone is recorded weight', () async {
    await agree(gear: looseGear([await item('plate', dryKg: 3)]), kg: 3);
  });

  test('weights gear adds to the Weights rows', () async {
    await agree(
      rows: [4, 2],
      gear: looseGear([await item('plate', dryKg: 3)]),
      kg: 9,
    );
  });

  test('weights gear adds to a legacy scalar', () async {
    await agree(
      scalar: 6,
      gear: looseGear([await item('plate', dryKg: 3)]),
      kg: 9,
    );
  });

  test('negative buoyancy stands in when no dry weight is set', () async {
    await agree(gear: looseGear([await item('block', buoyancyKg: -2)]), kg: 2);
  });

  test('positive buoyancy is not lead', () async {
    await agree(
      gear: looseGear([await item('block', buoyancyKg: 2)]),
      kg: null,
    );
  });

  test('a non-finite dry weight falls back to buoyancy', () async {
    await agree(
      gear: looseGear([
        await item('block', dryKg: double.infinity, buoyancyKg: -2),
      ]),
      kg: 2,
    );
  });

  test('weights gear with no numbers records nothing', () async {
    await agree(gear: looseGear([await item('plate')]), kg: null);
  });

  test('a custom attribute is not the curated dry weight', () async {
    await agree(
      gear: looseGear([await item('plate', dryKg: 3, custom: true)]),
      kg: null,
    );
  });

  test('other gear with a dry weight is not lead', () async {
    await agree(
      rows: [4],
      gear: looseGear([await item('bcd', type: EquipmentType.bcd, dryKg: 3)]),
      kg: 4,
    );
  });

  test('an assembly counts through its parts only', () async {
    final rig = await item('rig', dryKg: 5);
    final trim = await item('trim', dryKg: 2);
    await agree(
      gear: [
        GearLink(item: rig),
        GearLink(item: trim, viaEquipmentId: rig.id),
      ],
      kg: 2,
    );
  });

  test('rows totalling zero with no gear lead stay zero', () async {
    await agree(rows: [0], gear: looseGear([await item('plate')]), kg: 0);
  });
}

Matcher closeToOrNull(double? kg) => kg == null ? isNull : closeTo(kg, 1e-9);
