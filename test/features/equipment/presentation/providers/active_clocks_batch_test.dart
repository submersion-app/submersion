import 'dart:async';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveEquipmentCompanion,
        DiveTanksCompanion,
        DivesCompanion,
        TransmittersCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// The home gauges, the list badges and the trip alerts read the active
/// locker from one batched evaluation, not from a schedule, record and
/// exposure read per item (issue #3830). The single-item provider keeps the
/// per-item path, so it is the oracle these tests compare against.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late EquipmentRepository equipment;
  late String diverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(
      NativeDatabase.memory(
        setup: registerAppSqlFunctions,
        logStatements: true,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    equipment = EquipmentRepository();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    diverId = diver.id;
    await prefs.setString(currentDiverIdKey, diverId);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Runs [body] with drift's statement log discarded, for bulk seeding.
  Future<T> quietly<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
  );

  // Gear bought before the dives below, so its clocks count all of them.
  Future<EquipmentItem> gear(
    String name,
    EquipmentType type, {
    String? owner,
    String? parentId,
    DateTime? installed,
    int? slot,
    bool fitted = true,
  }) => equipment.createEquipment(
    EquipmentItem(
      id: '',
      name: name,
      type: type,
      diverId: owner ?? diverId,
      purchaseDate: DateTime(2015),
      parentEquipmentId: parentId,
      isActive: fitted,
      status: fitted ? EquipmentStatus.active : EquipmentStatus.retired,
      attributes: [
        if (installed != null)
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.installedDate,
            valueNum: installed.millisecondsSinceEpoch.toDouble(),
          ),
        if (slot != null)
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.cellSlot,
            valueNum: slot.toDouble(),
          ),
      ],
    ),
  );

  Future<ServiceSchedule> clock(
    String equipmentId, {
    int? dives,
    double? hours,
    double? cycles,
  }) => ServiceScheduleRepository().createSchedule(
    ServiceSchedule(
      id: '',
      equipmentId: equipmentId,
      serviceKindId: 'regulator-service',
      intervalDives: dives,
      intervalHours: hours,
      exposureIntervals: {ExposureUnit.cycles: ?cycles},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  Future<void> insertDive(String id, DateTime at, {String mode = 'oc'}) {
    final ms = at.millisecondsSinceEpoch;
    return db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600), diveMode: Value(mode)),
        );
  }

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  /// A clock's comparable face; the status itself holds lists.
  List<Object?> face(ServiceClockStatus s) => [
    s.schedule.id,
    s.kind.id,
    s.severity,
    s.dueDate,
    s.anchor,
    for (final e in s.usageByUnit.entries) [e.key, e.value.since],
  ];

  double? since(
    List<ServiceClockStatus> statuses,
    String scheduleId,
    ExposureUnit unit,
  ) => statuses
      .firstWhere((s) => s.schedule.id == scheduleId)
      .usageByUnit[unit]
      ?.since;

  /// Statements the evaluation itself issues, not the bootstrap reads that
  /// land inside or outside the window depending on timing.
  Future<int> statementsToRead(Future<Object?> Function() read) async {
    final logged = <String>[];
    await runZoned(
      read,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    const bootstrap = [
      '"settings"',
      '"divers"',
      '"diver_settings"',
      '"documents"',
      'FROM documents',
    ];
    return logged
        .where((l) => l.startsWith('Drift: Sent'))
        .where((l) => !bootstrap.any(l.contains))
        .length;
  }

  Future<int> statementsForLocker() {
    final container = makeContainer();
    return statementsToRead(
      () => container.read(activeEquipmentClocksProvider.future),
    );
  }

  /// One active item per shape the evaluation has to get right: several
  /// clocks, a rebreather's loop hours, a fitted part replacing a retired
  /// one, a part of an unscheduled parent, a transmitter, and no clock.
  Future<Map<String, EquipmentItem>> seedEveryShape() async {
    final t1 = DateTime.utc(2026, 1, 10);
    final t2 = DateTime.utc(2026, 2, 10);
    final t3 = DateTime.utc(2026, 3, 10);
    await insertDive('d1', t1);
    await insertDive('d2', t2);
    await insertDive('d3', t3, mode: 'ccr');

    final cylinder = await gear('AL80', EquipmentType.tank);
    await link('d1', cylinder.id);
    await link('d2', cylinder.id);

    final ccr = await gear('JJ', EquipmentType.rebreather);
    for (final d in ['d1', 'd2', 'd3']) {
      await link(d, ccr.id);
    }
    await clock(ccr.id, hours: 100, cycles: 50);
    await gear(
      'Old cell',
      EquipmentType.o2Cell,
      parentId: ccr.id,
      installed: DateTime.utc(2025, 6, 1),
      slot: 1,
      fitted: false,
    );
    final newCell = await gear(
      'New cell',
      EquipmentType.o2Cell,
      parentId: ccr.id,
      installed: t2,
      slot: 1,
    );
    await clock(newCell.id, dives: 10);
    final battery = await gear(
      'Battery',
      EquipmentType.battery,
      parentId: ccr.id,
      installed: DateTime.utc(2025, 6, 1),
    );
    await clock(battery.id, cycles: 50);

    final torch = await gear('Torch', EquipmentType.light);
    await link('d1', torch.id);
    final torchCell = await gear(
      'Torch cell',
      EquipmentType.battery,
      parentId: torch.id,
      installed: DateTime.utc(2025, 6, 1),
    );
    await clock(torchCell.id, dives: 10);

    final tx = await gear('Tx', EquipmentType.transmitter);
    await clock(tx.id, dives: 10);
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'r1',
            label: 'Main',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            transmitterSerial: const Value('555'),
            transmitterEquipmentId: Value(tx.id),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'd2',
          ).copyWith(transmitterSerial: const Value('555')),
        );

    final fins = await gear('Fins', EquipmentType.fins);

    return {
      for (final item in [
        cylinder,
        ccr,
        newCell,
        battery,
        torch,
        torchCell,
        tx,
        fins,
      ])
        item.name: item,
    };
  }

  group('activeEquipmentClocksProvider', () {
    test('agrees with the single-item provider on every shape', () async {
      final seeded = await seedEveryShape();
      final container = makeContainer();

      final evaluated = await container.read(
        activeEquipmentClocksProvider.future,
      );

      expect(evaluated.map((e) => e.item.id).toSet(), {
        for (final item in seeded.values) item.id,
      });
      for (final e in evaluated) {
        final single = await container.read(
          serviceClockStatusesProvider(e.item.id).future,
        );
        expect(
          [for (final s in e.statuses) face(s)],
          [for (final s in single) face(s)],
          reason: e.item.name,
        );
      }
    });

    test(
      'the fixture reaches each shape, so agreement means something',
      () async {
        final seeded = await seedEveryShape();
        final schedules = ServiceScheduleRepository();
        Future<String> scheduleOf(String name, String kind) async =>
            (await schedules.getSchedulesForEquipment(
              seeded[name]!.id,
            )).firstWhere((s) => s.serviceKindId == kind).id;

        final evaluated = await makeContainer().read(
          activeEquipmentClocksProvider.future,
        );
        final statuses = {for (final e in evaluated) e.item.name: e.statuses};

        expect(statuses['AL80'], hasLength(2));
        expect(statuses['Fins'], isEmpty);
        const kind = 'regulator-service';
        expect(
          since(
            statuses['JJ']!,
            await scheduleOf('JJ', kind),
            ExposureUnit.hours,
          ),
          1,
          reason: 'only the ccr dive runs the loop',
        );
        expect(
          since(
            statuses['JJ']!,
            await scheduleOf('JJ', kind),
            ExposureUnit.cycles,
          ),
          0,
          reason: 'the fitted battery takes the cycles',
        );
        expect(
          since(
            statuses['Battery']!,
            await scheduleOf('Battery', kind),
            ExposureUnit.cycles,
          ),
          3,
          reason: "a part inherits its parent's dives",
        );
        expect(
          since(
            statuses['New cell']!,
            await scheduleOf('New cell', kind),
            ExposureUnit.dives,
          ),
          2,
          reason: 'a part counts from its install date',
        );
        expect(
          since(
            statuses['Torch cell']!,
            await scheduleOf('Torch cell', kind),
            ExposureUnit.dives,
          ),
          1,
          reason: 'the parent has no clock of its own',
        );
        expect(
          since(
            statuses['Tx']!,
            await scheduleOf('Tx', kind),
            ExposureUnit.dives,
          ),
          1,
          reason: "a transmitter's dives come through its registered serial",
        );
      },
    );

    test('keeps every active item, in list order, clocks or none', () async {
      final seeded = await seedEveryShape();

      final evaluated = await makeContainer().read(
        activeEquipmentClocksProvider.future,
      );

      final active = await equipment.getActiveEquipment(diverId: diverId);
      expect(
        [for (final e in evaluated) e.item.id],
        [for (final item in active) item.id],
      );
      expect(evaluated.map((e) => e.item.name), isNot(contains('Old cell')));
      expect(
        evaluated.firstWhere((e) => e.item.id == seeded['Fins']!.id).statuses,
        isEmpty,
      );
    });

    test('a shared item counts the fitted battery the viewer cannot see, '
        'as its detail page does', () async {
      final owner = await DiverRepository().createDiver(
        Diver(
          id: '',
          name: 'Owner',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      final light = await gear(
        'Shared light',
        EquipmentType.light,
        owner: owner.id,
      );
      await gear(
        'Hidden battery',
        EquipmentType.battery,
        owner: owner.id,
        parentId: light.id,
        installed: DateTime.utc(2025, 6, 1),
      );
      final schedule = await clock(light.id, cycles: 50);
      await insertDive('d1', DateTime.utc(2026, 1, 10));
      await link('d1', light.id);
      await EquipmentShareRepository().shareMany(
        equipmentIds: [light.id],
        diverIds: [diverId],
        actingDiverId: owner.id,
      );
      final container = makeContainer();

      final evaluated = await container.read(
        activeEquipmentClocksProvider.future,
      );

      expect(evaluated.map((e) => e.item.name), ['Shared light']);
      expect(
        since(evaluated.single.statuses, schedule.id, ExposureUnit.cycles),
        0,
      );
      expect(
        since(
          await container.read(serviceClockStatusesProvider(light.id).future),
          schedule.id,
          ExposureUnit.cycles,
        ),
        0,
      );
    });

    test("a registry edit reaches a transmitter's clock", () async {
      // Assigning a serial writes only the registry, so the batch has to
      // subscribe to it as the per-item evaluation did.
      final tx = await gear('Tx', EquipmentType.transmitter);
      final schedule = await clock(tx.id, dives: 10);
      await insertDive('d1', DateTime.utc(2026, 1, 1));
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'k1',
              diveId: 'd1',
            ).copyWith(transmitterSerial: const Value('555')),
          );
      final container = makeContainer();
      final sub = container.listen(activeEquipmentClocksProvider, (_, _) {});
      addTearDown(sub.close);
      Future<double?> dives() async => since(
        (await container.read(
          activeEquipmentClocksProvider.future,
        )).single.statuses,
        schedule.id,
        ExposureUnit.dives,
      );
      expect(await dives(), 0);

      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'r1',
              label: 'Main',
              tankRole: 'backGas',
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(
              transmitterSerial: const Value('555'),
              transmitterEquipmentId: Value(tx.id),
            ),
          );
      var now = await dives();
      for (var i = 0; i < 50 && now != 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        now = await dives();
      }
      expect(now, 1);
    });

    test('costs the same statements for 1, 20, 100 and 300 items, most of '
        'them without a clock', () async {
      final costs = <int, int>{};
      var seeded = 0;
      for (final size in [1, 20, 100, 300]) {
        await quietly(() async {
          for (; seeded < size; seeded++) {
            await gear(
              'Item $seeded',
              seeded % 3 == 0 ? EquipmentType.tank : EquipmentType.fins,
            );
          }
        });
        costs[size] = await statementsForLocker();
      }

      expect(costs.values.toSet(), hasLength(1), reason: '$costs');
      // Gear, its attributes, schedules, kinds, records, parts and exposure.
      expect(costs[300], 7, reason: '$costs');
    });

    test('grows by one exposure statement per 200 scheduled items', () async {
      await quietly(() async {
        for (var i = 0; i < 201; i++) {
          await gear('Tank $i', EquipmentType.tank);
        }
      });

      expect(await statementsForLocker(), 8);
    });

    test('a locker with no clocks stops after the schedules', () async {
      await quietly(() async {
        for (var i = 0; i < 20; i++) {
          await gear('Fins $i', EquipmentType.fins);
        }
      });

      // Gear, its attributes and the schedules that come back empty.
      expect(await statementsForLocker(), 3);
    });
  });

  group('tripServiceAlertsProvider', () {
    Future<Trip> upcomingTrip() {
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

    Future<int> statementsForTrip(String tripId) {
      final container = makeContainer();
      return statementsToRead(
        () => container.read(tripServiceAlertsProvider(tripId).future),
      );
    }

    test(
      'costs the same statements for one packed item as for twenty',
      () async {
        final single = await upcomingTrip();
        await TripEquipmentRepository().pack(single.id, [
          (await gear('Solo', EquipmentType.tank)).id,
        ]);
        final oneCost = await statementsForTrip(single.id);

        final many = await upcomingTrip();
        await quietly(() async {
          await TripEquipmentRepository().pack(many.id, [
            for (var i = 0; i < 20; i++)
              (await gear('Tank $i', EquipmentType.tank)).id,
          ]);
        });

        expect(await statementsForTrip(many.id), oneCost);
      },
    );

    test('an install date edit reaches an open trip', () async {
      // An attribute write touches no equipment row, so only the attribute
      // stream can tell the alert a part now owns different dives.
      final reg = await gear('Reg', EquipmentType.regulator);
      final part = await gear(
        'First stage',
        EquipmentType.regulator,
        parentId: reg.id,
        installed: DateTime.utc(2026, 6, 1),
      );
      final schedule = await ServiceScheduleRepository().createSchedule(
        ServiceSchedule(
          id: '',
          equipmentId: part.id,
          serviceKindId: 'regulator-service',
          intervalDays: 36500,
          intervalDives: 1,
          anchorDate: DateTime(2025),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await insertDive('d1', DateTime.utc(2026, 1, 10));
      await link('d1', reg.id);
      final trip = await upcomingTrip();
      await TripEquipmentRepository().pack(trip.id, [reg.id]);
      final container = makeContainer();
      final sub = container.listen(
        tripServiceAlertsProvider(trip.id),
        (_, _) {},
      );
      addTearDown(sub.close);
      Future<int> alerts() async => (await container.read(
        tripServiceAlertsProvider(trip.id).future,
      )).where((a) => a.status.schedule.id == schedule.id).length;
      expect(await alerts(), 0);

      await db.customUpdate(
        'UPDATE equipment_attributes SET value_num = ? WHERE equipment_id = ?',
        variables: [
          Variable.withReal(
            DateTime.utc(2025, 6, 1).millisecondsSinceEpoch.toDouble(),
          ),
          Variable.withString(part.id),
        ],
        updates: {db.equipmentAttributes},
      );
      var now = await alerts();
      for (var i = 0; i < 50 && now != 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        now = await alerts();
      }
      expect(now, 1);
    });

    test('agrees with the single-item provider on packed gear', () async {
      final seeded = await seedEveryShape();
      final trip = await upcomingTrip();
      await TripEquipmentRepository().pack(trip.id, [
        seeded['AL80']!.id,
        seeded['JJ']!.id,
      ]);
      final container = makeContainer();

      final alerts = await container.read(
        tripServiceAlertsProvider(trip.id).future,
      );

      expect(alerts, isNotEmpty);
      for (final alert in alerts) {
        final single = await container.read(
          serviceClockStatusesProvider(alert.item.id).future,
        );
        expect(
          [for (final s in single) face(s)],
          anyElement(equals(face(alert.status))),
          reason: alert.item.name,
        );
      }
    });
  });
}
