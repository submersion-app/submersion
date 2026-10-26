import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

import '../../../helpers/test_database.dart';

/// Issue #3662: a tank saved with its last visual inspection and last hydro
/// dates counts its VIP and hydro clocks from them, not from the purchase
/// date.
void main() {
  late AppDatabase db;
  late ServiceScheduleRepository schedules;
  late EquipmentRepository equipment;

  setUp(() async {
    db = await setUpTestDatabase();
    schedules = ServiceScheduleRepository();
    equipment = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final purchase = DateTime(2000, 2, 2);
  final vipDate = DateTime(2026, 10, 1);
  final hydroDate = DateTime(2026, 9, 15);

  EquipmentAttribute dateAttr(String key, DateTime date) =>
      EquipmentAttribute.curated(
        equipmentId: '',
        key: key,
        valueNum: date.millisecondsSinceEpoch.toDouble(),
      );

  EquipmentItem tank({List<EquipmentAttribute> attributes = const []}) =>
      EquipmentItem(
        id: '',
        name: 'AL80',
        type: EquipmentType.tank,
        purchaseDate: purchase,
        attributes: attributes,
      );

  Future<ServiceSchedule> clock(String equipmentId, String kindId) async =>
      (await schedules.getSchedulesForEquipment(
        equipmentId,
      )).singleWhere((s) => s.serviceKindId == kindId);

  test('creating a tank with both dates sets both clock baselines', () async {
    final created = await equipment.createEquipment(
      tank(
        attributes: [
          dateAttr(EquipmentAttrKeys.lastVisualInspection, vipDate),
          dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate),
        ],
      ),
    );

    final vip = await clock(created.id, 'vip');
    final hydro = await clock(created.id, 'hydro');
    expect(vip.anchorDate, vipDate);
    expect(vip.anchorSetAt, isNotNull);
    expect(hydro.anchorDate, hydroDate);
    expect(hydro.anchorSetAt, isNotNull);
  });

  test('a tank created without the dates keeps unanchored clocks', () async {
    final created = await equipment.createEquipment(tank());

    expect((await clock(created.id, 'vip')).anchorDate, isNull);
    expect((await clock(created.id, 'hydro')).anchorDate, isNull);
  });

  test('entering a date on a later edit anchors that clock', () async {
    final created = await equipment.createEquipment(tank());

    await equipment.updateEquipment(
      created.copyWith(
        attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
      ),
    );

    expect((await clock(created.id, 'hydro')).anchorDate, hydroDate);
    expect((await clock(created.id, 'vip')).anchorDate, isNull);
  });

  test('changing a date on an edit moves the clock to it', () async {
    final created = await equipment.createEquipment(
      tank(attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)]),
    );
    final newer = DateTime(2026, 10, 20);

    await equipment.updateEquipment(
      created.copyWith(
        attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, newer)],
      ),
    );

    expect((await clock(created.id, 'hydro')).anchorDate, newer);
  });

  test(
    'saving with the date unchanged leaves a baseline set elsewhere',
    () async {
      final created = await equipment.createEquipment(
        tank(
          attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
        ),
      );
      // The diver moves the clock from its own dialog afterwards.
      final fromDialog = DateTime(2026, 10, 22);
      final hydro = await clock(created.id, 'hydro');
      await schedules.updateSchedule(
        hydro.withBaseline(fromDialog, now: DateTime.now(), picked: true),
      );

      await equipment.updateEquipment(
        created.copyWith(
          name: 'AL80 renamed',
          attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
        ),
      );

      expect((await clock(created.id, 'hydro')).anchorDate, fromDialog);
    },
  );

  test('clearing a date undoes the baseline it set', () async {
    final created = await equipment.createEquipment(
      tank(attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)]),
    );

    await equipment.updateEquipment(created.copyWith(attributes: const []));

    final hydro = await clock(created.id, 'hydro');
    expect(hydro.anchorDate, isNull);
    expect(hydro.anchorSetAt, isNull);
  });

  test(
    'clearing a date leaves a baseline moved since from the clock dialog',
    () async {
      final created = await equipment.createEquipment(
        tank(
          attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
        ),
      );
      final fromDialog = DateTime(2026, 10, 22);
      final hydro = await clock(created.id, 'hydro');
      await schedules.updateSchedule(
        hydro.withBaseline(fromDialog, now: DateTime.now(), picked: true),
      );

      await equipment.updateEquipment(created.copyWith(attributes: const []));

      expect((await clock(created.id, 'hydro')).anchorDate, fromDialog);
    },
  );

  group('when a clock baseline cannot be saved', () {
    Future<void> refuseBaselines() => db.customStatement('''
      CREATE TRIGGER refuse_baseline
      BEFORE UPDATE ON service_schedules
      WHEN NEW.anchor_date IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'no baseline'); END
    ''');

    test('creating the tank still succeeds', () async {
      await refuseBaselines();

      final created = await equipment.createEquipment(
        tank(
          attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
        ),
      );

      expect(await equipment.getEquipmentById(created.id), isNotNull);
      expect((await clock(created.id, 'hydro')).anchorDate, isNull);
    });

    test(
      'an edit rolls back whole, so saving again anchors the clock',
      () async {
        final created = await equipment.createEquipment(tank());
        await refuseBaselines();
        final edited = created.copyWith(
          attributes: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
        );

        await expectLater(equipment.updateEquipment(edited), throwsA(anything));
        expect(
          (await equipment.getAttributesForEquipment(
            created.id,
          )).map((a) => a.key),
          isNot(contains(EquipmentAttrKeys.lastHydroTest)),
        );

        await db.customStatement('DROP TRIGGER refuse_baseline');
        await equipment.updateEquipment(edited);

        expect((await clock(created.id, 'hydro')).anchorDate, hydroDate);
      },
    );
  });
}
