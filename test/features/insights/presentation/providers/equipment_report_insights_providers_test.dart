import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_report_insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const tick = Duration(milliseconds: 500);

  Future<void> item(String id, {double? price, int? bought}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'other',
          createdAt: 1,
          updatedAt: 1,
          purchasePrice: Value(price),
          purchaseDate: Value(bought),
        ),
      );

  Future<void> dive(String id, DateTime when) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: when.millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(runtime: const Value(3600)),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  ProviderContainer build({DiveFilterState? filter}) {
    final made = ProviderContainer(
      overrides: [
        ...overridesForContainer,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        if (filter != null)
          insightsFilterProvider.overrideWith((ref) => filter),
      ].cast(),
    );
    addTearDown(made.dispose);
    return made;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    overridesForContainer = await getBaseOverrides();
    container = build();
  });
  tearDown(tearDownTestDatabase);

  test('cost refreshes when gear changes', () async {
    await item('a', price: 100);
    container.listen(costOfOwnershipProvider, (_, _) {});
    final first = await container.read(costOfOwnershipProvider.future);
    expect(first.byCurrency.single.total, 100);

    await item('b', price: 50);
    await Future<void>.delayed(tick);

    final next = await container.read(costOfOwnershipProvider.future);
    expect(next.byCurrency.single.total, 150);
  });

  test('cost refreshes when a service record changes', () async {
    await item('a', price: 100);
    container.listen(costOfOwnershipProvider, (_, _) {});
    await container.read(costOfOwnershipProvider.future);

    await db
        .into(db.serviceRecords)
        .insert(
          ServiceRecordsCompanion.insert(
            id: 'r1',
            equipmentId: 'a',
            serviceCategory: 'annual',
            serviceDate: 1000,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(cost: const Value(25)),
        );
    await Future<void>.delayed(tick);

    final next = await container.read(costOfOwnershipProvider.future);
    expect(next.byCurrency.single.total, 125);
  });

  test('cost refreshes when a dive links to gear', () async {
    await item('a', price: 100);
    await dive('d1', DateTime.utc(2026, 1, 1));
    container.listen(costOfOwnershipProvider, (_, _) {});
    final first = await container.read(costOfOwnershipProvider.future);
    expect(first.byCurrency.single.rows.single.diveCount, 0);

    await link('d1', 'a');
    await Future<void>.delayed(tick);

    final next = await container.read(costOfOwnershipProvider.future);
    expect(next.byCurrency.single.rows.single.diveCount, 1);
  });

  test('idle follows the chosen period', () async {
    final nowMs = DateTime.now();
    await item('a');
    await dive('d1', DateTime(nowMs.year - 1, nowMs.month - 6, 1));
    await link('d1', 'a');
    container.listen(idleGearProvider, (_, _) {});

    expect(await container.read(idleGearProvider.future), hasLength(1));

    container.read(idlePeriodProvider.notifier).state = IdlePeriod.twoYears;

    expect(await container.read(idleGearProvider.future), isEmpty);
  });

  test('neither provider follows the Insights filter', () async {
    await item('a', price: 100);
    await dive('d1', DateTime.utc(2020, 1, 1));
    await link('d1', 'a');
    final filtered = build(
      filter: DiveFilterState(startDate: DateTime.utc(2026, 1, 1)),
    );

    final cost = await filtered.read(costOfOwnershipProvider.future);
    expect(cost.byCurrency.single.rows.single.diveCount, 1);
    final idle = await filtered.read(idleGearProvider.future);
    expect(idle.single.lastDive, DateTime.utc(2020, 1, 1));
  });
}

List<Object> overridesForContainer = const [];
