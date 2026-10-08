import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The dive detail page hydrates each gear item with its attributes, and the
/// diver figure in its equipment card is tinted by the `color` attribute
/// (issue #2326). A synced colour edit writes only `equipment_attributes`,
/// so the detail change tick must fire on that table too, or an open dive
/// keeps showing the old colour.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'fins',
            name: 'Jets',
            type: 'fins',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('an attribute-only write ticks the dive detail stream', () async {
    final ticked = Completer<void>();
    final sub = DiveRepository().watchDiveDetailChanges().listen((_) {
      if (!ticked.isCompleted) ticked.complete();
    });
    addTearDown(sub.cancel);

    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'attr_fins_color',
            equipmentId: 'fins',
            attrKey: 'color',
            valueText: const Value('#EAB308'),
            createdAt: t,
            updatedAt: t,
          ),
        );

    await ticked.future.timeout(DiveRepository.changeTickDebounce * 20);
  });
}
