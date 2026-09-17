import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The equipment list reads every item's tags in one batch (issue #1942):
/// its statement count must not grow with the number of items. Recipe:
/// a statement-logging database, prints captured in a zone.
void main() {
  tearDown(() async => tearDownTestDatabase());

  test('the list statement count does not grow with the item count', () async {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase.memory(logStatements: true)),
    );
    final equipment = EquipmentRepository();
    final tags = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );

    Future<void> addItem(String name) async {
      final item = await equipment.createEquipment(
        EquipmentItem(id: '', name: name, type: EquipmentType.bcd),
      );
      await tags.replaceTags(item.id, ['t1', 't2']);
    }

    // What one list load runs: the default view's items (attributes are
    // batched, #1805) and the tags of every item.
    Future<int> countStatements() async {
      final logged = <String>[];
      await runZoned(
        () async {
          await equipment.getActiveEquipment();
          await tags.getTagsByEquipment();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      // Count statements, not print calls: a long argument list reaches the
      // zone's print hook in more than one piece.
      return logged.where((line) => line.startsWith('Drift: Sent')).length;
    }

    // Fixtures are written OUTSIDE the zone so their writes are not counted.
    await addItem('One');
    final one = await countStatements();
    for (var i = 0; i < 5; i++) {
      await addItem('More $i');
    }
    final six = await countStatements();

    expect(one, greaterThan(0));
    expect(six, one);
    expect((await tags.getTagsByEquipment()).length, 6);
  });
}
