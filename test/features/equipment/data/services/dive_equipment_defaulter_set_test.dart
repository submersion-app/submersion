import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

/// The defaulter already knows which set won; it now says so on every row
/// (issue #1487), so the dive remembers the set that was applied.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveEquipmentDefaulter defaulter;

  setUp(() async {
    db = await setUpTestDatabase();
    // Junction writes without a full Dive fixture, as in the sibling test.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    sets = EquipmentSetRepository();
    defaulter = DiveEquipmentDefaulter();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['reg', 'fins']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('rows written by the default set carry its id', () async {
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'Default',
        equipmentIds: const ['reg', 'fins'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isTrue);
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('dive1'))).get();
    expect(rows.map((r) => r.equipmentId), unorderedEquals(['reg', 'fins']));
    expect(rows.map((r) => r.viaSetId), everyElement('def'));
  });

  test('a member no longer shared with the diver is not applied', () async {
    // Issue #2046: the set keeps it, a downloaded dive does not get it.
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'theirs',
            name: 'theirs',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d2'),
          ),
        );
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'Default',
        equipmentIds: const ['reg', 'theirs'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isTrue);
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('dive1'))).get();
    expect(rows.map((r) => r.equipmentId), ['reg']);
  });

  group('which set was chosen (issue #4525)', () {
    Future<void> defaultSet({
      List<String> gear = const ['reg'],
      List<String> presets = const [],
    }) async {
      await sets.createSet(
        EquipmentSet(
          id: 'def',
          diverId: 'd1',
          name: 'Default',
          equipmentIds: gear,
          weightPresetIds: presets,
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await sets.setAsDefault('def', diverId: 'd1');
    }

    Future<String?> chosen() => defaulter.applyDefaultSetIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    test('the id of the set it applied comes back', () async {
      await defaultSet();
      expect(await chosen(), 'def');
    });

    test('a default set with no gear but weights is still chosen, and '
        'writes no gear', () async {
      final preset = await WeightPresetRepository().createPreset(
        diverId: 'd1',
        displayName: 'Lead',
        entries: const [
          (weightType: WeightType.belt, amountKg: 4, notes: '', label: ''),
        ],
      );
      await defaultSet(gear: const [], presets: [preset.id]);
      expect(await chosen(), 'def');
      expect(await db.select(db.diveEquipment).get(), isEmpty);
    });

    test('a default set with nothing at all is not chosen', () async {
      await defaultSet(gear: const []);
      expect(await chosen(), isNull);
    });

    test('a dive that already has gear gets nothing', () async {
      await defaultSet();
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'fins'),
          );
      expect(await chosen(), isNull);
    });

    test('no diver means no set', () async {
      await defaultSet();
      expect(
        await defaulter.applyDefaultSetIfEmpty(
          diveId: 'dive1',
          diverId: null,
          divePoints: const [],
        ),
        isNull,
      );
    });
  });
}
