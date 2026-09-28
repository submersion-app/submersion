import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/providers/service_status_keeper.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The service-due cache follows the engine only while a live filter reads
/// it, and a query that reads it waits for the write (#2365).
void main() {
  QueryNode parse(QuerySubject subject, String text) {
    final parser = QueryParser(
      appQueryRegistry,
      appQueryRegistry.entityFor(subject),
      ParseContext(
        prefs: kMetricPrefs,
        now: DateTime(2026, 9, 28),
        names: const MapNameResolver({}),
      ),
    );
    return (parser.parse(text) as ParseOk).node!;
  }

  group('demand', () {
    late ProviderContainer container;
    var writerBuilds = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      writerBuilds = 0;
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          equipmentServiceStatusCacheProvider.overrideWith((ref) async {
            writerBuilds++;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(serviceStatusKeeperProvider, (_, _) {});
      await container.pump();
    });

    test('no filter reads the cache, so the writer never runs', () async {
      await container.read(serviceStatusKeeperProvider.future);
      expect(container.read(serviceStatusDemandProvider), isFalse);
      expect(writerBuilds, 0);
    });

    test('a dive query naming gear.serviceDue starts the writer', () async {
      container.read(diveFilterProvider.notifier).state = DiveFilterState(
        query: parse(QuerySubject.dives, 'gear.serviceDue = overdue'),
      );
      await container.read(serviceStatusKeeperProvider.future);
      expect(container.read(serviceStatusDemandProvider), isTrue);
      expect(writerBuilds, 1);
    });

    test('the writer is released once no filter reads the cache', () async {
      container.read(diveFilterProvider.notifier).state = DiveFilterState(
        query: parse(QuerySubject.dives, 'gear.serviceDue = overdue'),
      );
      await container.read(serviceStatusKeeperProvider.future);
      expect(container.exists(equipmentServiceStatusCacheProvider), isTrue);

      container.read(diveFilterProvider.notifier).state =
          const DiveFilterState();
      await container.read(serviceStatusKeeperProvider.future);
      await container.pump();
      // Disposed, not merely idle: it no longer follows the clocks.
      expect(container.exists(equipmentServiceStatusCacheProvider), isFalse);
    });
  });

  group('readers wait for the write', () {
    late AppDatabase db;
    late ProviderContainer container;
    final now = DateTime.now();

    setUp(() async {
      final ms = now.millisecondsSinceEpoch;
      db = await setUpTestDatabase();
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'me',
              name: 'me',
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'late',
              name: 'late',
              type: 'regulator',
              diverId: const Value('me'),
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.serviceSchedules)
          .insert(
            ServiceSchedulesCompanion.insert(
              id: 'sch-late',
              equipmentId: 'late',
              serviceKindId: 'regulator-service',
              intervalDays: const Value(30),
              anchorDate: Value(
                now.subtract(const Duration(days: 400)).millisecondsSinceEpoch,
              ),
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd1',
              diverId: const Value('me'),
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'late'),
          );
      SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });
    tearDown(() async {
      container.dispose();
      await tearDownTestDatabase();
    });

    test('a dive id set naming gear.serviceDue sees a fresh cache', () async {
      // Nothing else keeps the writer alive: the id set itself must wait.
      final filter = DiveFilterState(
        query: parse(QuerySubject.dives, 'gear.serviceDue = overdue'),
      );
      final sub = container.listen(
        queryFilteredDiveIdsProvider(filter),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(queryFilteredDiveIdsProvider(filter).future),
        {'d1'},
      );
    });
  });
}
