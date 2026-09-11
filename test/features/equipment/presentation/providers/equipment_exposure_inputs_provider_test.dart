import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'ccr',
            name: 'CCR',
            type: 'rebreather',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    // A cell inherits its rebreather's dives from its install date.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'cell',
            name: 'Cell 1',
            type: 'o2Cell',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(parentEquipmentId: const Value('ccr')),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 1, 10).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'ccr'),
        );
  });
  tearDown(tearDownTestDatabase);

  test('an install date edit reaches an open child part', () async {
    // The install date is an attribute, written to equipment_attributes
    // without touching the equipment row, and it decides which of the
    // parent's dives a part inherits. An open card has to see the edit,
    // not wait for a dive.
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      equipmentExposureInputsProvider('cell'),
      (_, _) {},
    );
    addTearDown(sub.close);
    final before = await container.read(
      equipmentExposureInputsProvider('cell').future,
    );
    expect(before!.samples, hasLength(1));

    await EquipmentRepository().saveAttributes('cell', [
      EquipmentAttribute.curated(
        equipmentId: 'cell',
        key: EquipmentAttrKeys.installedDate,
        valueNum: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch.toDouble(),
      ),
    ]);
    var samples = 1;
    for (var i = 0; i < 50 && samples != 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      samples = (await container.read(
        equipmentExposureInputsProvider('cell').future,
      ))!.samples.length;
    }
    expect(samples, 0);
  });
}
