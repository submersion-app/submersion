import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_service_status_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The service engine's verdicts reach SQL through the local cache (#2365
/// PR 3), and the `serviceDue` field agrees with the row badges.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.now();
  int daysAgo(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final ms = now.millisecondsSinceEpoch;
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
    }
    // One regulator per verdict, each with a single date clock.
    Future<void> item(
      String id, {
      required int days,
      required int anchor,
    }) async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
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
              id: 'sch-$id',
              equipmentId: id,
              serviceKindId: 'regulator-service',
              intervalDays: Value(days),
              anchorDate: Value(daysAgo(anchor)),
              createdAt: ms,
              updatedAt: ms,
            ),
          );
    }

    await item('late', days: 30, anchor: 400);
    await item('soon', days: 30, anchor: 25);
    await item('fresh', days: 365, anchor: 1);
    await prefs.setString(currentDiverIdKey, 'me');
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    // A live listener, as the list page keeps: the cache follows the clocks.
    final sub = container.listen(
      equipmentServiceStatusCacheProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  final equipment = appQueryRegistry.entityFor(QuerySubject.equipment);
  final parser = QueryParser(
    appQueryRegistry,
    equipment,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> sqlIds(String text) async {
    final node = (parser.parse(text) as ParseOk).node;
    expect(validateQuery(node, equipment, appQueryRegistry), isEmpty);
    final q = compileQuery(node, equipment, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test("the cache holds each active item's worst severity", () async {
    await container.read(equipmentServiceStatusCacheProvider.future);
    expect(await EquipmentServiceStatusRepository().severities(), {
      'late': 'overdue',
      'soon': 'dueSoon',
      'fresh': 'ok',
    });
  });

  test("the serviceDue field matches the engine's worst clocks", () async {
    await container.read(equipmentServiceStatusCacheProvider.future);
    // equipmentWorstClockProvider is what the row badges read.
    final worst = await container.read(equipmentWorstClockProvider.future);
    Set<String> having(bool Function(ServiceClockSeverity) keep) => {
      for (final e in worst.entries)
        if (keep(e.value.status.severity)) e.key,
    };
    expect(
      await sqlIds('serviceDue in [dueSoon, overdue]'),
      having((s) => s != ServiceClockSeverity.ok),
    );
    expect(
      await sqlIds('serviceDue = overdue'),
      having((s) => s == ServiceClockSeverity.overdue),
    );
    expect(
      await sqlIds('serviceDue = dueSoon'),
      having((s) => s == ServiceClockSeverity.dueSoon),
    );
  });

  test('a switch mid-evaluation never keeps the old verdicts', () async {
    // The first evaluation (for 'me') is still in flight when the diver
    // changes; whichever finishes last, the cache must end as 'other''s.
    final first = container.read(equipmentServiceStatusCacheProvider.future);
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('other');
    await first.catchError((_) {});
    await container.read(equipmentServiceStatusCacheProvider.future);
    await pumpEventQueue();
    expect(await EquipmentServiceStatusRepository().severities(), isEmpty);
  });

  test('a diver switch rewrites the cache', () async {
    await container.read(equipmentServiceStatusCacheProvider.future);
    // 'other' owns no gear and nothing is shared with them.
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('other');
    await container.read(equipmentServiceStatusCacheProvider.future);
    expect(await EquipmentServiceStatusRepository().severities(), isEmpty);
  });
}
