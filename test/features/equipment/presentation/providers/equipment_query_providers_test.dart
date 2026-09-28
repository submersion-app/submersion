import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The equipment list is the visible gear the compiled query selects
/// (#2365), including the service verdicts the engine caches.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.now();
  final ms = now.millisecondsSinceEpoch;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
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
    Future<void> item(String id, String type, {String status = 'active'}) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            diverId: const Value('me'),
            status: Value(status),
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await item('bcd', 'bcd');
    await item('reg', 'regulator');
    await item('old', 'regulator', status: 'retired');
    // 'reg' is overdue: a 30-day clock anchored 400 days ago.
    await db
        .into(db.serviceSchedules)
        .insert(
          ServiceSchedulesCompanion.insert(
            id: 'sch-reg',
            equipmentId: 'reg',
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
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'Travel',
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            id: 'et1',
            equipmentId: 'bcd',
            tagId: 't1',
            createdAt: ms,
          ),
        );
    await prefs.setString(currentDiverIdKey, 'me');
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final list = container.listen(filteredEquipmentProvider, (_, _) {});
    final emptied = container.listen(equipmentTagsEmptiedProvider, (_, _) {});
    addTearDown(list.close);
    addTearDown(emptied.close);
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<List<EquipmentItem>> settledItems() async {
    for (var i = 0; i < 300; i++) {
      final v = container.read(filteredEquipmentProvider);
      if (!v.isLoading && v.hasValue) return v.value!;
      if (v.hasError) fail('list error: ${v.error}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the list never settled');
  }

  test('the filtered list is the visible gear the query selects', () async {
    container.read(equipmentFilterProvider.notifier).state =
        const EquipmentFilterState(type: EquipmentType.bcd);
    expect((await settledItems()).map((e) => e.id), ['bcd']);
  });

  test('the default view hides retired gear', () async {
    expect((await settledItems()).map((e) => e.id).toSet(), {'bcd', 'reg'});
  });

  test(
    'a service-due filter reads a cache the engine has just written',
    () async {
      container.read(equipmentFilterProvider.notifier).state =
          const EquipmentFilterState(serviceDue: ServiceDueFilter.overdue);
      expect((await settledItems()).map((e) => e.id), ['reg']);
    },
  );

  test('tagsEmptied blames the tags only when they emptied the list', () async {
    container
        .read(equipmentFilterProvider.notifier)
        .state = const EquipmentFilterState(
      type: EquipmentType.regulator,
      tagIds: {'t1'},
    );
    expect(await settledItems(), isEmpty);
    var emptied = false;
    for (var i = 0; i < 300 && !emptied; i++) {
      emptied = container.read(equipmentTagsEmptiedProvider);
      if (!emptied) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    expect(emptied, isTrue);
  });
}
