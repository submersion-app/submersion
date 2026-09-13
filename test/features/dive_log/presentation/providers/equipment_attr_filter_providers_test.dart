import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveEquipmentCompanion,
        DiveTanksCompanion,
        EquipmentAttributesCompanion,
        EquipmentCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The table view and the maps read [filteredDivesProvider], whose dives come
/// from getAllDives. A cylinder matched through the transmitter registry
/// reaches those entities as a bare DiveTank.equipmentId, so the attribute
/// axis must be resolved in SQL to select the same dives as the paginated
/// list (#1805).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertItem(
    String id,
    EquipmentType type,
    String key,
    String text,
  ) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value(id),
            type: Value(type.name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_$key'),
            equipmentId: Value(id),
            attrKey: Value(key),
            valueText: Value(text),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final diveRepo = DiveRepository();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);

    for (final (id, day) in [
      ('hpDive', 1),
      ('lpDive', 2),
      ('steelDive', 3),
      ('bare', 4),
    ]) {
      await diveRepo.createDive(
        Dive(id: id, diverId: diver.id, dateTime: DateTime(2026, 1, day)),
      );
    }
    await insertItem('hpHose', EquipmentType.hose, 'hose_type', 'hp');
    await insertItem('lpHose', EquipmentType.hose, 'hose_type', 'lp');
    await insertItem('steelTank', EquipmentType.tank, 'tank_material', 'steel');
    await db
        .into(db.diveEquipment)
        .insert(
          const DiveEquipmentCompanion(
            diveId: Value('hpDive'),
            equipmentId: Value('hpHose'),
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          const DiveEquipmentCompanion(
            diveId: Value('lpDive'),
            equipmentId: Value('lpHose'),
          ),
        );
    // Linked only through the registry, never through dive_equipment.
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('tank-steel'),
            diveId: Value('steelDive'),
            equipmentId: Value('steelTank'),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  Future<Set<String>> filteredIds(ProviderContainer container) async {
    for (var i = 0; i < 100; i++) {
      final value = container.read(filteredDivesProvider);
      if (value.hasValue) return value.value!.map((d) => d.id).toSet();
      if (value.hasError) fail('filteredDivesProvider failed: ${value.error}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('filteredDivesProvider never produced a value');
  }

  /// A container whose unfiltered list has settled, mirroring a diver turning
  /// a filter on from the already-rendered list.
  Future<ProviderContainer> settled() async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await filteredIds(container), hasLength(4));
    return container;
  }

  const hp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('a registry-linked cylinder matches in the entity views', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    );
    expect(await filteredIds(container), {'steelDive'});
  });

  test('hose type narrows the entity views', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [hp],
    );
    expect(await filteredIds(container), {'hpDive'});
  });

  test('a changed condition set does not reuse the previous ids', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [hp],
    );
    expect(await filteredIds(container), {'hpDive'});
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(key: 'hose_type', choices: {'lp'}),
      ],
    );
    expect(await filteredIds(container), {'lpDive'});
  });

  test('the conditions combine with the in-memory axes', () async {
    final container = await settled();
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      equipmentAttrConditions: const [EquipmentAttrCondition(key: 'hose_type')],
      startDate: DateTime(2026, 1, 2),
    );
    expect(await filteredIds(container), {'lpDive'});
  });
}
