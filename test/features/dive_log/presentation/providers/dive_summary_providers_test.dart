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
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1078: the Dive Log Summary pane beside the dive list describes the
/// dives the list shows, so its statistics and records follow the dive list's
/// filter ([diveFilterProvider]), not the whole log and not the Insights tab's
/// independent filter.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

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
    for (final (id, depth, minutes) in [
      ('shallow', 10.0, 70),
      ('deep', 40.0, 30),
    ]) {
      await diveRepo.createDive(
        Dive(
          id: id,
          diverId: diver.id,
          dateTime: DateTime(2026, 1, depth.toInt()),
          maxDepth: depth,
          runtime: Duration(minutes: minutes),
        ),
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

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

  group('diveListScopedStatisticsProvider', () {
    test('covers the whole log while the dive list is unfiltered', () async {
      final container = makeContainer();

      final stats = await container.read(
        diveListScopedStatisticsProvider.future,
      );

      expect(stats.totalDives, 2);
      expect(stats.maxDepth, 40.0);
    });

    test('covers only the dives the dive list filter keeps', () async {
      final container = makeContainer();
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        maxDepth: 20,
      );

      final stats = await container.read(
        diveListScopedStatisticsProvider.future,
      );

      expect(stats.totalDives, 1);
      expect(stats.maxDepth, 10.0);
    });

    test('ignores the Insights tab filter', () async {
      final container = makeContainer();
      container.read(insightsFilterProvider.notifier).state =
          const DiveFilterState(maxDepth: 20);

      final stats = await container.read(
        diveListScopedStatisticsProvider.future,
      );

      expect(
        stats.totalDives,
        2,
        reason: 'the Insights filter scopes the Insights tab only',
      );
    });
  });

  group('diveListScopedRecordsProvider', () {
    test('covers the whole log while the dive list is unfiltered', () async {
      final container = makeContainer();

      final records = await container.read(
        diveListScopedRecordsProvider.future,
      );

      expect(records.deepestDive!.diveId, 'deep');
    });

    test('takes its records from the filtered dives only', () async {
      final container = makeContainer();
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        minDepth: 20,
      );

      final records = await container.read(
        diveListScopedRecordsProvider.future,
      );

      expect(records.deepestDive!.diveId, 'deep');
      expect(
        records.longestDive!.diveId,
        'deep',
        reason:
            'the 70-minute shallow dive is filtered out, so it must not be '
            'the longest dive in the summary',
      );
    });
  });

  test('a write to a table only the filter joins refreshes both', () async {
    // An equipment-attribute condition makes the compiled filter read the
    // gear tables; typing a hose writes equipment_attributes and never
    // touches dives, so a dives-only tick would leave the summary stale.
    Future<void> setHoseType(String id) => db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_hose_type'),
            equipmentId: Value(id),
            attrKey: const Value('hose_type'),
            valueText: const Value('hp'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (diveId, hose) in [
      ('shallow', 'hpHose'),
      ('deep', 'untypedHose'),
    ]) {
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
            DiveEquipmentCompanion(
              diveId: Value(diveId),
              equipmentId: Value(hose),
            ),
          );
    }
    await setHoseType('hpHose');

    final container = makeContainer();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
    );
    final stats = container.listen(diveListScopedStatisticsProvider, (_, _) {});
    addTearDown(stats.close);
    final records = container.listen(diveListScopedRecordsProvider, (_, _) {});
    addTearDown(records.close);

    expect(
      (await settle(
        container,
        diveListScopedStatisticsProvider,
        (s) => s.totalDives == 1,
      ))?.totalDives,
      1,
    );
    expect(
      (await settle(
        container,
        diveListScopedRecordsProvider,
        (r) => r.deepestDive != null,
      ))?.deepestDive?.diveId,
      'shallow',
    );

    await setHoseType('untypedHose');

    expect(
      (await settle(
        container,
        diveListScopedStatisticsProvider,
        (s) => s.totalDives == 2,
      ))?.totalDives,
      2,
    );
    expect(
      (await settle(
        container,
        diveListScopedRecordsProvider,
        (r) => r.deepestDive?.diveId == 'deep',
      ))?.deepestDive?.diveId,
      'deep',
    );
  });
}
