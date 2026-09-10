import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/weight_planner/data/repositories/weight_history_repository.dart';

import '../../../helpers/test_database.dart';

/// Training observations list leaf gear only: an assembly and its parts
/// would otherwise be two features for one object (issue #1487).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const diverId = 'diver-1';

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Eric', 1000, 1000)",
    );
  });

  tearDown(tearDownTestDatabase);

  test('the observation lists the wing but not the assembly', () async {
    final equipment = EquipmentRepository();
    final bcd = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Backplate', type: EquipmentType.bcd),
    );
    final wing = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.wing),
    );
    await DiveRepository().createDive(
      Dive(
        id: '',
        diverId: diverId,
        dateTime: DateTime(2026, 2, 1),
        weightAmount: 6.0,
        gear: gearLinksFor(
          [bcd, wing],
          [GearProvenance(equipmentId: wing.id, viaEquipmentId: bcd.id)],
        ),
      ),
    );

    final observations = await WeightHistoryRepository().observationsForDiver(
      diverId,
    );
    expect(observations.single.equipmentIds, [wing.id]);
  });

  test('a corrupt loop still leaves one id on the observation', () async {
    // A and B each name the other as parent. Every row is a parent, so a
    // naive reading would drop both; the placement walk GearTree uses
    // promotes one to a root and keeps the other as its leaf.
    final equipment = EquipmentRepository();
    final a = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'A', type: EquipmentType.bcd),
    );
    final b = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'B', type: EquipmentType.wing),
    );
    await DiveRepository().createDive(
      Dive(
        id: '',
        diverId: diverId,
        dateTime: DateTime(2026, 2, 1),
        weightAmount: 6.0,
        gear: gearLinksFor(
          [a, b],
          [
            GearProvenance(equipmentId: a.id, viaEquipmentId: b.id),
            GearProvenance(equipmentId: b.id, viaEquipmentId: a.id),
          ],
        ),
      ),
    );

    final observations = await WeightHistoryRepository().observationsForDiver(
      diverId,
    );
    expect(observations.single.equipmentIds, hasLength(1));
  });
}
