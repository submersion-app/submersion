import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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
  late ServiceScheduleRepository schedules;
  late EquipmentRepository equipment;

  setUp(() async {
    await setUpTestDatabase();
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
}
