import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show ServiceRecordsCompanion;
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
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

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
    expect(kinds.where((k) => k.isBuiltIn).length, 12);
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

    await TripEquipmentRepository().pack(trip.id, [tank.id]);

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

  test('tripServiceAlertsProvider refreshes when a service arrives by '
      'sync', () async {
    // A record applied by sync touches no equipment row, so only the
    // service ledger's own change stream can clear a stale trip alert.
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
    await TripEquipmentRepository().pack(trip.id, [tank.id]);
    // A pre-v213 hydro baseline six years back: overdue, and any hydro
    // record takes the clock over.
    final hydro = (await scheduleRepo.getSchedulesForEquipment(
      tank.id,
    )).firstWhere((s) => s.serviceKindId == 'hydro');
    await scheduleRepo.updateSchedule(
      hydro.copyWith(anchorDate: now.subtract(const Duration(days: 2190))),
    );

    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(tripServiceAlertsProvider(trip.id), (_, _) {});
    addTearDown(sub.close);
    final before = await container.read(
      tripServiceAlertsProvider(trip.id).future,
    );
    expect(before.map((a) => a.status.kind.id), contains('hydro'));

    final ms = now.millisecondsSinceEpoch;
    await DatabaseService.instance.database
        .into(DatabaseService.instance.database.serviceRecords)
        .insert(
          ServiceRecordsCompanion.insert(
            id: 'synced-hydro',
            equipmentId: tank.id,
            serviceCategory: ServiceCategory.inspection.name,
            serviceDate: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(serviceKindId: const Value('hydro')),
        );
    await pumpEventQueue();

    final after = await container.read(
      tripServiceAlertsProvider(trip.id).future,
    );
    expect(after.map((a) => a.status.kind.id), isNot(contains('hydro')));
  });

  group('tripServiceAlertsProvider covers only the gear on the trip '
      '(issue #2727)', () {
    Future<Trip> upcomingTrip(String diverId) {
      final now = DateTime.now();
      return TripRepository().createTrip(
        Trip(
          id: '',
          diverId: diverId,
          name: 'Liveaboard',
          startDate: now.add(const Duration(days: 200)),
          endDate: now.add(const Duration(days: 207)),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // A hydro baseline six years back: overdue now, so it blocks any trip
    // the tank goes on.
    Future<void> makeHydroOverdue(String equipmentId) async {
      final hydro = (await scheduleRepo.getSchedulesForEquipment(
        equipmentId,
      )).firstWhere((s) => s.serviceKindId == 'hydro');
      await scheduleRepo.updateSchedule(
        hydro.copyWith(
          anchorDate: DateTime.now().subtract(const Duration(days: 2190)),
        ),
      );
    }

    Future<List<String>> alertedIds(
      ProviderContainer container,
      String tripId,
    ) async => [
      for (final a in await container.read(
        tripServiceAlertsProvider(tripId).future,
      ))
        a.item.id,
    ];

    test('an overdue tank left at home does not warn on the trip', () async {
      final diver = await seedCurrentDiver();
      final tank = await seedTank(diver.id);
      await makeHydroOverdue(tank.id);
      final trip = await upcomingTrip(diver.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await alertedIds(container, trip.id), isEmpty);
      // The home screen still warns: the tank is overdue, just not going.
      final due = await container.read(dueClocksProvider.future);
      expect(due.map((d) => d.item.id), contains(tank.id));
    });

    test('a packed tank warns, and only the packed one', () async {
      final diver = await seedCurrentDiver();
      final packed = await seedTank(diver.id);
      final home = await seedTank(diver.id);
      await makeHydroOverdue(packed.id);
      await makeHydroOverdue(home.id);
      final trip = await upcomingTrip(diver.id);
      await TripEquipmentRepository().pack(trip.id, [packed.id]);

      final container = makeContainer();
      addTearDown(container.dispose);

      expect((await alertedIds(container, trip.id)).toSet(), {packed.id});
    });

    test('a tank on the trip cylinder board warns', () async {
      final diver = await seedCurrentDiver();
      final tank = await seedTank(diver.id);
      await makeHydroOverdue(tank.id);
      final trip = await upcomingTrip(diver.id);
      final now = DateTime.now();
      await TripCylinderRepository().createCylinder(
        TripCylinder(
          id: '',
          tripId: trip.id,
          equipmentId: tank.id,
          label: 'Truck 1',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      expect((await alertedIds(container, trip.id)).toSet(), {tank.id});
    });

    test('a part installed in packed gear warns with it', () async {
      final diver = await seedCurrentDiver();
      final rig = await equipmentRepo.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Sidemount rig',
          type: EquipmentType.harness,
          diverId: diver.id,
        ),
      );
      final tank = await equipmentRepo.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Left AL80',
          type: EquipmentType.tank,
          diverId: diver.id,
          parentEquipmentId: rig.id,
        ),
      );
      await makeHydroOverdue(tank.id);
      final trip = await upcomingTrip(diver.id);
      await TripEquipmentRepository().pack(trip.id, [rig.id]);

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await alertedIds(container, trip.id), contains(tank.id));
    });

    test('packing an overdue tank brings its alert to an open trip', () async {
      final diver = await seedCurrentDiver();
      final tank = await seedTank(diver.id);
      await makeHydroOverdue(tank.id);
      final trip = await upcomingTrip(diver.id);

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        tripServiceAlertsProvider(trip.id),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(await alertedIds(container, trip.id), isEmpty);

      // A pack writes trip_equipment alone: no equipment or ledger change.
      await TripEquipmentRepository().pack(trip.id, [tank.id]);
      await pumpEventQueue();
      expect(await alertedIds(container, trip.id), contains(tank.id));
    });
  });
}
