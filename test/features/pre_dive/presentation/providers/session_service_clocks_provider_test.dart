import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, TransmittersCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The session runner reads every row's live clocks from ONE batched
/// evaluation instead of one provider per row (issue #2260 left the per-row
/// family in place because the batch providers it had cover active gear
/// only, and keep only the worst clock).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late EquipmentRepository equipment;
  late String diverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
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

  /// A tank, whose hydro and visual inspection clocks attach on creation.
  /// Bought long ago, so both are overdue.
  Future<EquipmentItem> tank(String name, {bool retired = false}) =>
      equipment.createEquipment(
        EquipmentItem(
          id: '',
          name: name,
          type: EquipmentType.tank,
          diverId: diverId,
          purchaseDate: DateTime(2015),
          isActive: !retired,
          status: retired ? EquipmentStatus.retired : EquipmentStatus.active,
        ),
      );

  Future<PreDiveSession> sessionLinking(List<String?> equipmentIds) {
    final now = DateTime.now();
    return PreDiveSessionRepository().startSession(
      template: PreDiveChecklistTemplate(
        id: '',
        name: 'T',
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        for (final (i, id) in equipmentIds.indexed)
          PreDiveSessionItem(
            id: '',
            sessionId: '',
            title: 'Item $i',
            sortOrder: i,
            equipmentId: id,
            createdAt: now,
            updatedAt: now,
          ),
      ],
    );
  }

  /// A clock's comparable face; the status itself holds lists.
  List<Object?> face(ServiceClockStatus s) => [
    s.schedule.id,
    s.kind.id,
    s.severity,
    s.dueDate,
    s.anchor,
    for (final e in s.usageByUnit.entries) [e.key, e.value.since],
  ];

  test('a row linked to RETIRED gear still has its clocks', () async {
    // The session sheet offers every item, not just active gear, so a
    // checklist row can name a retired cylinder. The active-gear batch
    // providers would silently drop its clocks.
    final retired = await tank('Old steel', retired: true);
    final session = await sessionLinking([retired.id]);

    final clocks = await makeContainer().read(
      sessionServiceClocksProvider(session.id).future,
    );

    expect([for (final s in clocks[retired.id]!) s.kind.id]..sort(), [
      'hydro',
      'vip',
    ]);
  });

  test('keeps EVERY clock on an item, not only the worst', () async {
    final cylinder = await tank('AL80');
    final session = await sessionLinking([cylinder.id]);

    final clocks = await makeContainer().read(
      sessionServiceClocksProvider(session.id).future,
    );

    final statuses = clocks[cylinder.id]!;
    expect(statuses, hasLength(2));
    expect(
      statuses.every((s) => s.severity == ServiceClockSeverity.overdue),
      isTrue,
    );
  });

  test('agrees with the single-item provider on every row', () async {
    final active = await tank('AL80');
    final retired = await tank('Old steel', retired: true);
    final fins = await equipment.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Fins',
        type: EquipmentType.fins,
        diverId: diverId,
      ),
    );
    final session = await sessionLinking([
      active.id,
      retired.id,
      fins.id,
      null,
    ]);

    final container = makeContainer();
    final clocks = await container.read(
      sessionServiceClocksProvider(session.id).future,
    );

    for (final item in [active, retired, fins]) {
      final single = await container.read(
        serviceClockStatusesProvider(item.id).future,
      );
      expect(
        [for (final s in clocks[item.id] ?? const []) face(s)],
        [for (final s in single) face(s)],
        reason: item.name,
      );
    }
    // Gear with no clocks, and a row with no gear, contribute nothing.
    expect(clocks.keys.toSet(), {active.id, retired.id});
  });

  Future<int> statementsToRead(ProviderContainer c, String sessionId) async {
    final logged = <String>[];
    await runZoned(
      () => c.read(sessionServiceClocksProvider(sessionId).future),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    // The diver and settings reads are SettingsNotifier's own unawaited
    // load, which lands inside or outside this window depending on timing.
    // Count the statements the evaluation itself issues.
    const bootstrap = ['"settings"', '"divers"', '"diver_settings"'];
    return logged
        .where((l) => l.startsWith('Drift: Sent'))
        .where((l) => !bootstrap.any(l.contains))
        .length;
  }

  test('costs the same statements for one row as for twenty', () async {
    // Measured before the fix: the per-row family cost ~14.6 statements a
    // row, 291 for twenty rows.
    final one = await sessionLinking([(await tank('Solo')).id]);
    final many = await sessionLinking([
      for (var i = 0; i < 20; i++) (await tank('Tank $i')).id,
    ]);

    final oneCost = await statementsToRead(makeContainer(), one.id);
    final manyCost = await statementsToRead(makeContainer(), many.id);

    expect(manyCost, oneCost);
    // The session rows, then schedules, gear, its attributes, kinds,
    // records, parts and exposure: one statement each.
    expect(manyCost, 8);
  });

  test('a schedule edit made anywhere refreshes the clocks', () async {
    // A schedule write touches only service_schedules, so no equipment or
    // dive stream fires for it: the service ledger streams are the only
    // thing that refreshes the per-row family after one made by sync or
    // another screen, and the batch must keep them.
    final cylinder = await tank('AL80');
    final session = await sessionLinking([cylinder.id]);
    final container = makeContainer();
    final sub = container.listen(
      sessionServiceClocksProvider(session.id),
      (_, _) {},
    );
    addTearDown(sub.close);

    ServiceClockSeverity hydro(Map<String, List<ServiceClockStatus>> m) =>
        m[cylinder.id]!.firstWhere((s) => s.kind.id == 'hydro').severity;
    expect(
      hydro(
        await container.read(sessionServiceClocksProvider(session.id).future),
      ),
      ServiceClockSeverity.overdue,
    );

    // Restart the hydro clock today, straight through the repository.
    final repo = ServiceScheduleRepository();
    final schedule = (await repo.getSchedulesForEquipment(
      cylinder.id,
    )).firstWhere((s) => s.serviceKindId == 'hydro');
    final today = DateTime.now();
    await repo.updateSchedule(schedule.withBaseline(today, now: today));

    var severity = ServiceClockSeverity.overdue;
    for (var i = 0; i < 50 && severity == ServiceClockSeverity.overdue; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      severity = hydro(
        await container.read(sessionServiceClocksProvider(session.id).future),
      );
    }
    expect(severity, isNot(ServiceClockSeverity.overdue));
  });

  test("a registry edit reaches a transmitter row's clocks", () async {
    // A transmitter's dives are the tanks that carried its registered
    // serials, and assigning a serial writes only the registry, so the
    // batch must subscribe to it as the per-item family does.
    final tx = await equipment.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Tx',
        type: EquipmentType.transmitter,
        diverId: diverId,
        purchaseDate: DateTime(2025, 1, 1),
      ),
    );
    final schedule = await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: '',
        equipmentId: tx.id,
        serviceKindId: 'regulator-service',
        exposureIntervals: const {ExposureUnit.dives: 10},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600)),
        );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, transmitter_serial) "
      "VALUES ('t1', 'd1', '555')",
    );
    final session = await sessionLinking([tx.id]);
    final container = makeContainer();
    final sub = container.listen(
      sessionServiceClocksProvider(session.id),
      (_, _) {},
    );
    addTearDown(sub.close);
    Future<double?> since() async =>
        (await container.read(
              sessionServiceClocksProvider(session.id).future,
            ))[tx.id]!
            .firstWhere((s) => s.schedule.id == schedule.id)
            .usageByUnit[ExposureUnit.dives]
            ?.since;
    expect(await since(), 0);

    // Through drift, so the registry's change stream ticks as the app's
    // own writes do.
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
    var now = await since();
    for (var i = 0; i < 50 && now != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      now = await since();
    }
    expect(now, 1);
  });

  test('ticking a row off does not re-evaluate the clocks', () async {
    // The provider depends on WHICH gear the session links, not on the
    // rows' state: every tap rewrites the session, and re-evaluating every
    // clock per tap would trade the N+1 for a per-tap cost the per-row
    // family never had.
    final cylinder = await tank('AL80');
    final session = await sessionLinking([cylinder.id]);
    final container = makeContainer();
    final first = await container.read(
      sessionServiceClocksProvider(session.id).future,
    );
    final sub = container.listen(
      sessionServiceClocksProvider(session.id),
      (_, _) {},
    );
    addTearDown(sub.close);

    final items = await container.read(
      preDiveSessionItemsProvider(session.id).future,
    );
    await PreDiveSessionRepository().updateItemState(
      sessionId: session.id,
      itemId: items.single.id,
      state: PreDiveItemState.done,
    );
    // Wait for the items provider to see the write.
    for (var i = 0; i < 50; i++) {
      final now = await container.read(
        preDiveSessionItemsProvider(session.id).future,
      );
      if (now.single.state == PreDiveItemState.done) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final after = await container.read(
      sessionServiceClocksProvider(session.id).future,
    );
    expect(identical(after, first), isTrue);
  });
}
