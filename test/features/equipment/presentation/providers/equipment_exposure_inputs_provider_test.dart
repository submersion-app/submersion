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

  test('a registry edit reaches an open transmitter', () async {
    // A transmitter's dives are the tanks that carried its registered
    // serials; assigning one writes only the registry, and the exposure
    // card and the trend chart read these inputs.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tx',
            name: 'Tx',
            type: 'transmitter',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, transmitter_serial) "
      "VALUES ('t1', 'd1', '555')",
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      equipmentExposureInputsProvider('tx'),
      (_, _) {},
    );
    addTearDown(sub.close);
    Future<int> samples() async => (await container.read(
      equipmentExposureInputsProvider('tx').future,
    ))!.samples.length;
    expect(await samples(), 0);

    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'r1',
            label: 'Main',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            transmitterSerial: const Value('555'),
            transmitterEquipmentId: const Value('tx'),
          ),
        );
    var now = await samples();
    for (var i = 0; i < 50 && now != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      now = await samples();
    }
    expect(now, 1);
  });

  test('a part with no install date inherits from its creation', () async {
    // Created after the rebreather's dive and never given an install
    // date: that dive happened before the part existed.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'late',
            name: 'Late cell',
            type: 'o2Cell',
            createdAt: DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
            updatedAt: 1,
          ).copyWith(parentEquipmentId: const Value('ccr')),
        );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    final inputs = await container.read(
      equipmentExposureInputsProvider('late').future,
    );
    expect(inputs!.samples, isEmpty);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> part(
    String id,
    String type, {
    required DateTime installed,
    String status = 'active',
    bool active = true,
    int? slot,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            parentEquipmentId: const Value('ccr'),
            status: Value(status),
            isActive: Value(active),
          ),
        );
    await EquipmentRepository().saveAttributes(id, [
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.installedDate,
        valueNum: installed.millisecondsSinceEpoch.toDouble(),
      ),
      if (slot != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.cellSlot,
          valueNum: slot.toDouble(),
        ),
    ]);
  }

  test('a battery retired by status alone is not fitted', () async {
    // A legacy row can be retired with isActive left true. It must not
    // switch the parent's battery-cycle exposure off as if fitted.
    await part(
      'old-battery',
      'battery',
      installed: DateTime.utc(2025),
      status: 'retired',
    );
    final inputs = await container().read(
      equipmentExposureInputsProvider('ccr').future,
    );
    expect(inputs!.classifier.hasBatteryChild, isFalse);
  });

  test('a replaced part stops inheriting at its successor', () async {
    // The old cell's page must not keep growing with every dive its
    // successor makes: it left the slot when the successor went in.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'later',
            diveDateTime: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'later', equipmentId: 'ccr'),
        );
    await part(
      'old',
      'o2Cell',
      installed: DateTime.utc(2025),
      status: 'retired',
      active: false,
      slot: 2,
    );
    await part('new', 'o2Cell', installed: DateTime.utc(2026, 2, 1), slot: 2);
    final c = container();
    final old = await c.read(equipmentExposureInputsProvider('old').future);
    expect(old!.samples.map((s) => s.diveId), ['d1']);
    final fresh = await c.read(equipmentExposureInputsProvider('new').future);
    expect(fresh!.samples.map((s) => s.diveId), ['later']);
  });
}
