import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveEquipmentCompanion,
        EquipmentAttributesCompanion,
        EquipmentCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/test_database.dart';

/// The filtered overview totals and records follow only the dives tick, but
/// an equipment-attribute condition makes them read the gear tables. While a
/// condition is set, an attribute-only write must refresh them (#1805 review).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> setHoseType(String id, String kind) => db
      .into(db.equipmentAttributes)
      .insert(
        EquipmentAttributesCompanion(
          id: Value('attr_${id}_hose_type'),
          equipmentId: Value(id),
          attrKey: const Value('hose_type'),
          valueText: Value(kind),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
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
    final diveRepo = DiveRepository();
    // The untyped hose rides on the deeper dive, so typing it moves the
    // deepest record as well as the total.
    for (final (id, depth, hose) in [
      ('hpDive', 10.0, 'hpHose'),
      ('untypedDive', 30.0, 'untypedHose'),
    ]) {
      await diveRepo.createDive(
        Dive(
          id: id,
          diverId: diver.id,
          dateTime: DateTime(2026, 1, depth.toInt()),
          maxDepth: depth,
        ),
      );
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion(
              id: Value(hose),
              name: Value(hose),
              type: Value(EquipmentType.hose.name),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion(diveId: Value(id), equipmentId: Value(hose)),
          );
    }
    await setHoseType('hpHose', 'hp');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<T?> settle<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
    bool Function(T) done,
  ) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(provider).value;
      if (value != null && done(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(provider).value;
  }

  test(
    'an attribute-only write refreshes the filtered totals and records',
    () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      container
          .read(statisticsFilterProvider.notifier)
          .state = const DiveFilterState(
        equipmentAttrConditions: [
          EquipmentAttrCondition(
            key: 'hose_type',
            choices: {'hp'},
            types: {EquipmentType.hose},
          ),
        ],
      );
      final stats = container.listen(filteredDiveStatisticsProvider, (_, _) {});
      addTearDown(stats.close);
      final records = container.listen(filteredDiveRecordsProvider, (_, _) {});
      addTearDown(records.close);

      expect(
        (await settle(
          container,
          filteredDiveStatisticsProvider,
          (s) => s.totalDives == 1,
        ))?.totalDives,
        1,
      );
      expect(
        (await settle(
          container,
          filteredDiveRecordsProvider,
          (r) => r.deepestDive != null,
        ))?.deepestDive?.diveId,
        'hpDive',
      );

      // Typing the second hose writes equipment_attributes and nothing else.
      await setHoseType('untypedHose', 'hp');

      expect(
        (await settle(
          container,
          filteredDiveStatisticsProvider,
          (s) => s.totalDives == 2,
        ))?.totalDives,
        2,
        reason: 'the dives tick alone never fires for an attribute write',
      );
      expect(
        (await settle(
          container,
          filteredDiveRecordsProvider,
          (r) => r.deepestDive?.diveId == 'untypedDive',
        ))?.deepestDive?.diveId,
        'untypedDive',
      );
    },
  );
}
