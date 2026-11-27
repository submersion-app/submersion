import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/service_clock_snapshot_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// One read of an item's clocks, which the Service clocks card draws its
/// rows and verdicts from, and evaluates the clocks a sitting holds over
/// (issue #5042).
void main() {
  final at = DateTime(2026, 1, 1);
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, default_interval_days, "
      "created_at, updated_at) VALUES "
      "('k-annual', 'Yearly check', 365, 0, 0), "
      "('k-batt', 'Battery swap', 730, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Stores [item] with no clock but the ones a test adds: creating it
  /// attaches the built-in ones.
  Future<void> create(EquipmentItem item) async {
    await EquipmentRepository().createEquipment(item);
    await db.customStatement('DELETE FROM service_schedules');
  }

  ServiceSchedule clock(String id, String itemId, String kindId) =>
      ServiceSchedule(
        id: id,
        equipmentId: itemId,
        serviceKindId: kindId,
        createdAt: at,
        updatedAt: at,
      );

  test('an item with no row reads as none', () async {
    final c = await container();

    expect(
      await c.read(serviceClockSnapshotProvider('missing').future),
      isNull,
    );
  });

  test('the stored verdicts are those of the single-item clocks', () async {
    const reg = EquipmentItem(
      id: 'reg',
      name: 'Apex',
      type: EquipmentType.regulator,
    );
    await create(reg);
    await ServiceScheduleRepository().createSchedule(
      clock('s1', 'reg', 'k-annual'),
    );
    final c = await container();

    final snapshot = (await c.read(
      serviceClockSnapshotProvider('reg').future,
    ))!;
    final oracle = await c.read(serviceClockStatusesProvider('reg').future);

    expect(snapshot.schedules.map((s) => s.id), ['s1']);
    expect(
      snapshot.statuses.map((s) => (s.schedule.id, s.dueDate)),
      oracle.map((s) => (s.schedule.id, s.dueDate)),
    );
  });

  test('a transmitter\'s clocks are read, and a clock held beside them is '
      'evaluated over the same read', () async {
    const tx = EquipmentItem(
      id: 'tx',
      name: 'Swift',
      type: EquipmentType.transmitter,
    );
    await create(tx);
    await ServiceScheduleRepository().createSchedule(
      clock('s1', 'tx', 'k-annual'),
    );
    final c = await container();

    final snapshot = (await c.read(serviceClockSnapshotProvider('tx').future))!;
    final held = snapshot.statusesFor(
      schedules: [...snapshot.schedules, clock('s2', 'tx', 'k-batt')],
    );

    expect(snapshot.statuses.map((s) => s.schedule.id), ['s1']);
    expect(held.map((s) => s.schedule.id), unorderedEquals(['s1', 's2']));
    expect(snapshot.statusesFor(), same(snapshot.statuses));
  });
}
