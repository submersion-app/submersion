import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Trip;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/editing/trip_cylinder_events_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../helpers/test_database.dart';

/// A copier that refuses every copy, as one whose cylinder lost its
/// passport would.
class _RefusingCopier extends TripFillPassportCopier {
  @override
  Future<void> afterSave(
    TripCylinderEvent event,
    TripCylinder slot, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async => throw StateError('no passport');
}

/// A trip's cylinder fills and adjustments held in its sitting, written at
/// Save with their passport copies as one History entry (issue #4527).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripCylinderRepository cylinders;
  late TripEditSaveService service;
  late SittingList<Trip, TripCylindersHeld> board;
  final changeLog = ChangeLogRepository();
  final fills = CylinderFillRepository();
  final at = DateTime.utc(2030, 6, 2, 9);
  const note = (diverId: 'me', stationName: 'Blue Bay', stationResolved: true);

  TripCylinderEvent fill(String slot, {double pressure = 200}) =>
      TripCylinderEvent(
        id: '',
        tripCylinderId: slot,
        kind: TripCylinderEventKind.fill,
        occurredAt: at,
        pressure: pressure,
        o2Percent: 32,
        createdAt: at,
        updatedAt: at,
      );

  Future<EditSession<Trip>> open() async {
    final session = EditSession<Trip>((await trips.getTripById('t1'))!);
    await board.load(session);
    return session;
  }

  TripCylindersHeld heldOf(EditSession<Trip> session) =>
      heldCylindersOf(session, board)!;

  Future<void> save(EditSession<Trip> session) => service.save(
    tripId: 't1',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
    actingDiverId: 'me',
    alsoWrite: session.runHeldWrites,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  Future<String> onlyOperation() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id FROM change_log_operations')
        .get();
    return rows.single.read<String>('id');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    final days = ItineraryDayRepository();
    trips = TripRepository(itineraryDays: days);
    cylinders = TripCylinderRepository();
    service = TripEditSaveService(trips, days, LiveaboardDetailsRepository());
    board = tripCylindersList(
      cylinders: cylinders,
      copier: TripFillPassportCopier(),
    );
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: 'tank',
        diverId: 'me',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );
    await trips.createTrip(
      Trip(
        id: 't1',
        diverId: 'me',
        name: 'Red Sea',
        startDate: DateTime(2030, 6, 1),
        endDate: DateTime(2030, 6, 8),
        createdAt: at,
        updatedAt: at,
      ),
    );
    await cylinders.createCylinders([
      TripCylinder(
        id: 'own',
        tripId: 't1',
        equipmentId: 'tank',
        label: 'Steel 12',
        sortOrder: 0,
        createdAt: at,
        updatedAt: at,
      ),
      TripCylinder(
        id: 'rent',
        tripId: 't1',
        label: 'Truck 1',
        sortOrder: 1,
        createdAt: at,
        updatedAt: at,
      ),
    ]);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('a fill logged and edited in one sitting is one new event', () async {
    final session = await open();
    final hold = TripBoardHold(session: session, board: board);
    await hold.fills([fill('own')], note);
    final logged = heldOf(session).events.single;
    await hold.fills([logged.copyWith(pressure: 180.0)], note);

    expect(heldOf(session).events.single.id, logged.id);
    expect(heldOf(session).events.single.pressure, 180);
    expect(session.changedCardIds, {'cylinders'});
  });

  test('the folded state follows the held fills', () async {
    final session = await open();
    await TripBoardHold(
      session: session,
      board: board,
    ).fills([fill('own', pressure: 210)], note);

    final own = heldOf(session).states.first;
    expect(own.status, TripCylinderStatus.full);
    expect(own.pressure, 210);
  });

  test(
    'Save writes the fills and the owned cylinder passport copy in one '
    'entry, the rental fill has none, and a revert takes them back',
    () async {
      final session = await open();
      await TripBoardHold(
        session: session,
        board: board,
      ).fills([fill('own'), fill('rent')], note);
      final ownFill = heldOf(
        session,
      ).events.firstWhere((e) => e.tripCylinderId == 'own');
      final rentFill = heldOf(
        session,
      ).events.firstWhere((e) => e.tripCylinderId == 'rent');

      await save(session);

      final events = await cylinders.getEventsForTrip('t1');
      expect(events['own']!.single.id, ownFill.id);
      expect(events['rent']!.single.id, rentFill.id);
      final copy = await fills.getById(tripFillPassportCopyId(ownFill.id));
      expect(copy, isNotNull);
      expect(copy!.stationName, 'Blue Bay');
      expect(await fills.getById(tripFillPassportCopyId(rentFill.id)), isNull);

      final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
      await revert.execute(await revert.planOperation(await onlyOperation()));

      expect(await cylinders.getEventsForTrip('t1'), isEmpty);
      expect(await fills.getById(tripFillPassportCopyId(ownFill.id)), isNull);
    },
  );

  test('a refused copy fails the Save and writes nothing', () async {
    final refusing = tripCylindersList(
      cylinders: cylinders,
      copier: _RefusingCopier(),
    );
    final session = EditSession<Trip>((await trips.getTripById('t1'))!);
    await refusing.load(session);
    await TripBoardHold(
      session: session,
      board: refusing,
    ).fills([fill('own')], note);

    await expectLater(save(session), throwsStateError);

    expect(await cylinders.getEventsForTrip('t1'), isEmpty);
  });

  test(
    'a slot made, filled and deleted in one sitting writes nothing',
    () async {
      final session = await open();
      final hold = TripBoardHold(session: session, board: board);
      await hold.addSlots([
        TripCylinder(
          id: '',
          tripId: 't1',
          label: 'Truck 2',
          sortOrder: 2,
          createdAt: at,
          updatedAt: at,
        ),
      ]);
      final added = heldOf(session).slots.last;
      await hold.fills([fill(added.id)], note);
      await hold.deleteSlot(added.id);

      expect(session.changedCardIds, isEmpty);
      expect(heldOf(session).events, isEmpty);
    },
  );

  test('a fill another device logged on the slot during the sitting '
      'survives Save', () async {
    final session = await open();
    await TripBoardHold(
      session: session,
      board: board,
    ).fills([fill('own')], note);
    await cylinders.createEvents([
      fill(
        'own',
        pressure: 150,
      ).copyWith(id: 'other', occurredAt: at.add(const Duration(hours: 3))),
    ]);

    await save(session);

    final own = (await cylinders.getEventsForTrip('t1'))['own']!;
    expect(own, hasLength(2));
    expect(own.map((e) => e.id), contains('other'));
  });

  test('a slot edited, reordered and an adjustment deleted are written; a '
      'deleted slot goes with its fills', () async {
    await cylinders.createEvents([fill('rent').copyWith(id: 'f1')]);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final session = await open();
    final hold = TripBoardHold(session: session, board: board);
    await hold.editSlot(heldOf(session).slots.first.copyWith(label: 'Mine'));
    await hold.reorder(['rent', 'own']);
    await hold.deleteEvent('f1');

    await save(session);

    final slots = await cylinders.getCylindersForTrip('t1');
    expect([for (final s in slots) s.label], ['Truck 1', 'Mine']);
    expect(await cylinders.getEventsForTrip('t1'), isEmpty);
  });
}
