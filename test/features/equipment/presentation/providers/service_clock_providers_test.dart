import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;
  late EquipmentRepository equipmentRepo;
  late ServiceScheduleRepository scheduleRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    equipmentRepo = EquipmentRepository();
    scheduleRepo = ServiceScheduleRepository();
    diverRepo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<Diver> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  Future<EquipmentItem> seedTank(String diverId) =>
      equipmentRepo.createEquipment(
        EquipmentItem(
          id: '',
          name: 'AL80',
          type: EquipmentType.tank,
          diverId: diverId,
        ),
      );

  test('serviceClockStatusesProvider returns auto-attached clocks', () async {
    final diver = await seedCurrentDiver();
    final tank = await seedTank(diver.id);

    final container = makeContainer();
    addTearDown(container.dispose);

    final statuses = await container.read(
      serviceClockStatusesProvider(tank.id).future,
    );
    expect(
      statuses.map((s) => s.kind.id).toSet(),
      containsAll(['hydro', 'vip']),
    );
  });

  test('dueClocksProvider surfaces an overdue hydro clock', () async {
    final diver = await seedCurrentDiver();
    final tank = await seedTank(diver.id);

    // Push the hydro clock 6 years into the past: overdue.
    final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
    final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
    await scheduleRepo.updateSchedule(
      hydro.copyWith(
        anchorDate: DateTime.now().subtract(const Duration(days: 2190)),
      ),
    );

    final container = makeContainer();
    addTearDown(container.dispose);

    final due = await container.read(dueClocksProvider.future);
    expect(due, isNotEmpty);
    final hydroDue = due.firstWhere((d) => d.status.kind.id == 'hydro');
    expect(hydroDue.item.id, tank.id);
    expect(hydroDue.status.severity, ServiceClockSeverity.overdue);
  });

  test('tripServiceAlertsProvider returns empty for an unknown trip', () async {
    await seedCurrentDiver();
    final container = makeContainer();
    addTearDown(container.dispose);

    final alerts = await container.read(
      tripServiceAlertsProvider('no-such-trip').future,
    );
    expect(alerts, isEmpty);
  });

  test('equipmentWorstClockProvider maps one worst clock per item', () async {
    final diver = await seedCurrentDiver();
    final tank = await seedTank(diver.id);

    // Both clocks overdue: the map should hold ONE entry for the tank, and
    // it should be the overdue clock that sorts first.
    final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
    for (final s in schedules) {
      await scheduleRepo.updateSchedule(
        s.copyWith(
          anchorDate: DateTime.now().subtract(const Duration(days: 2190)),
        ),
      );
    }

    final container = makeContainer();
    addTearDown(container.dispose);

    final worst = await container.read(equipmentWorstClockProvider.future);
    expect(worst.keys, [tank.id]);
    expect(worst[tank.id]!.status.severity, ServiceClockSeverity.overdue);
  });

  test(
    'serviceDueSoonWindowDaysProvider reads the widest reminder day',
    () async {
      final diver = await seedCurrentDiver();
      // createDiver auto-seeds diver_settings; widen the reminder window.
      await DatabaseService.instance.database.customStatement(
        "UPDATE diver_settings SET service_reminder_days = '[7, 60]' "
        "WHERE diver_id = '${diver.id}'",
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      final window = await container.read(
        serviceDueSoonWindowDaysProvider.future,
      );
      expect(window, 60);
    },
  );

  test('serviceKindsProvider lists built-ins for the current diver', () async {
    await seedCurrentDiver();
    final container = makeContainer();
    addTearDown(container.dispose);

    final kinds = await container.read(serviceKindsProvider.future);
    expect(kinds.where((k) => k.isBuiltIn).length, 9);
  });

  test('tripServiceAlertsProvider gates on trip end date', () async {
    final diver = await seedCurrentDiver();
    final tank = await seedTank(diver.id);
    final now = DateTime.now();

    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        diverId: diver.id,
        name: 'Bonaire',
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 17)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // hydro due mid-trip (day 12); vip due in ~1 year (after the trip).
    final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
    final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
    await scheduleRepo.updateSchedule(
      hydro.copyWith(anchorDate: now.add(const Duration(days: 12 - 1825))),
    );
    final vip = schedules.firstWhere((s) => s.serviceKindId == 'vip');
    await scheduleRepo.updateSchedule(
      vip.copyWith(anchorDate: now.subtract(const Duration(days: 1))),
    );

    final container = makeContainer();
    addTearDown(container.dispose);

    final alerts = await container.read(
      tripServiceAlertsProvider(trip.id).future,
    );
    expect(alerts.map((a) => a.status.kind.id), contains('hydro'));
    expect(alerts.map((a) => a.status.kind.id), isNot(contains('vip')));
  });
}
