import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide Trip, TripChecklistItem;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/data/services/trip_set_bundle.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_cylinder_events_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../helpers/test_database.dart';

/// A trip's packed gear and cylinder board held in its sitting and written
/// at Save, as one History entry (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripEquipmentRepository packs;
  late TripCylinderRepository cylinders;
  late TripEditSaveService service;
  late SittingList<Trip, EquipmentItem> packed;
  late SittingList<Trip, TripCylindersHeld> board;
  final changeLog = ChangeLogRepository();
  final at = DateTime.utc(2026);

  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const wing = EquipmentItem(id: 'wing', name: 'Wing', type: EquipmentType.bcd);
  const tank = EquipmentItem(
    id: 'tank',
    name: 'Steel 12',
    type: EquipmentType.tank,
  );
  final catalogue = {
    for (final i in [fins, wing, tank]) i.id: i,
  };

  Future<List<String>> labels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT label FROM change_log_operations')
        .get();
    return [for (final r in rows) r.read<String?>('label') ?? ''];
  }

  Future<EditSession<Trip>> open() async {
    final session = EditSession<Trip>((await trips.getTripById('t1'))!);
    await packed.load(session);
    await board.load(session);
    return session;
  }

  HeldTripGearWrites writesOf(EditSession<Trip> session) =>
      HeldTripGearWrites(session: session, packed: packed, board: board);

  Future<void> save(EditSession<Trip> session) => service.save(
    tripId: 't1',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
    actingDiverId: 'me',
    alsoWrite: session.runHeldWrites,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    final days = ItineraryDayRepository();
    trips = TripRepository(itineraryDays: days);
    packs = TripEquipmentRepository();
    cylinders = TripCylinderRepository();
    service = TripEditSaveService(trips, days, LiveaboardDetailsRepository());
    packed = tripPackedGearList(
      read: (id) async => [
        for (final i in await packs.equipmentIdsForTrip(id)) catalogue[i]!,
      ],
      packs: packs,
    );
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
    final equipment = EquipmentRepository();
    for (final item in catalogue.values) {
      await equipment.createEquipment(item.copyWith(diverId: 'me'));
    }
    await packs.pack('t1', ['fins', 'tank']);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('packing and unpacking the same item holds nothing', () async {
    final session = await open();
    final writes = writesOf(session);

    expect(await writes.pack([wing]), 1);
    await writes.unpack('wing');

    expect(session.changedCardIds, isEmpty);
  });

  test(
    'putting a tank on board moves it from packed gear to the board',
    () async {
      final session = await open();
      final writes = writesOf(session);

      await writes.appendCylinders([
        tripCylinderDraftFromEquipment(
          tank,
          tripId: 't1',
          sortOrder: 0,
          now: at,
        ),
      ]);
      await writes.unpack('tank');

      expect([for (final i in packed.current(session)!) i.id], ['fins']);
      final slot = heldCylindersOf(session, board)!.slots.single;
      expect(slot.equipmentId, 'tank');
      expect(slot.id, isNotEmpty);
      expect(session.changedCardIds, {'packedGear', 'cylinders'});
      // Nothing is written before Save.
      expect(await cylinders.getCylindersForTrip('t1'), isEmpty);
    },
  );

  test('Save packs, unpacks and makes slots with the sitting ids as one '
      'History entry, and reverting it takes them back', () async {
    final session = await open();
    final writes = writesOf(session);
    await writes.pack([wing]);
    final added = await writes.appendCylinders([
      tripCylinderDraftFromEquipment(tank, tripId: 't1', sortOrder: 0, now: at),
    ]);
    await writes.unpack('tank');

    await save(session);

    expect(
      await packs.equipmentIdsForTrip('t1'),
      unorderedEquals(['fins', 'wing']),
    );
    final stored = await cylinders.getCylindersForTrip('t1');
    expect([for (final c in stored) c.id], [added.single.id]);
    expect(await labels(), ['record_edit:trips:t1:cylinders,packedGear']);

    await changeLog.settleAll();
    final op =
        (await db
                .customSelect('SELECT id FROM change_log_operations')
                .getSingle())
            .read<String>('id');
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(op));

    expect(
      await packs.equipmentIdsForTrip('t1'),
      unorderedEquals(['fins', 'tank']),
    );
    expect(await cylinders.getCylindersForTrip('t1'), isEmpty);
  });

  test("a set's bundle in a sitting holds its slots and its lead item on the "
      'held checklist', () async {
    final lists = TripChecklistsRepository();
    final listItems = TripChecklistRepository();
    await lists.createChecklist(tripId: 't1', name: 'Packing', id: 'c1');
    final checklistList = tripChecklistsList(
      checklists: lists,
      items: listItems,
    );
    final session = await open();
    await checklistList.load(session);
    final writes = writesOf(session);
    final checklistWrites = HeldTripChecklistWrites(
      session: session,
      list: checklistList,
      templates: ChecklistTemplateRepository(),
    );

    final result = await applySetBundle(
      bundle: const SetBundle(
        setId: 's',
        weights: [
          (weightType: WeightType.belt, amountKg: 4, notes: '', label: ''),
        ],
      ),
      tripId: 't1',
      leadTitle: 'Lead: 4 kg',
      slots: writes.slots,
      appendSlots: writes.appendCylinders,
      checklists: () async =>
          heldChecklistsOf(session, checklistList)!.checklists,
      itemsOf: (id) async =>
          heldChecklistsOf(session, checklistList)!.itemsOf(id),
      createItem: checklistWrites.createItem,
      pickChecklist: (_) async => fail('one checklist, nothing to choose'),
      now: at,
    );

    expect(result.lead, TripLeadOutcome.added);
    expect(
      heldChecklistsOf(session, checklistList)!.itemsOf('c1').single.title,
      'Lead: 4 kg',
    );
    expect(await listItems.getByChecklistId('c1'), isEmpty);
    expect(session.changedCardIds, {'checklists'});
  });

  test('rental slots keep their order and get ids', () async {
    final session = await open();

    await writesOf(session).createCylinders([
      TripCylinder(
        id: '',
        tripId: 't1',
        label: 'Rental 1',
        sortOrder: 0,
        createdAt: at,
        updatedAt: at,
      ),
    ]);

    final slot = heldCylindersOf(session, board)!.slots.single;
    expect(slot.id, isNotEmpty);
    expect(slot.label, 'Rental 1');
  });

  test('a slot moved and moved back is no change, gaps and all', () async {
    await cylinders.createCylinders([
      for (final (id, order) in [('a', 0), ('b', 3)])
        TripCylinder(
          id: id,
          tripId: 't1',
          label: id,
          sortOrder: order,
          createdAt: at,
          updatedAt: at,
        ),
    ]);
    final session = await open();
    final hold = TripBoardHold(session: session, board: board);

    await hold.reorder(['b', 'a']);
    expect(session.changedCardIds, {'cylinders'});
    await hold.reorder(['a', 'b']);

    expect(session.changedCardIds, isEmpty);
  });

  test(
    'packing before the packed gear is read holds nothing and says so',
    () async {
      final session = EditSession<Trip>((await trips.getTripById('t1'))!);

      expect(await writesOf(session).pack([wing]), 0);
      expect(session.changedCardIds, isEmpty);
    },
  );

  test(
    'adding tanks before the board is read holds nothing and says so',
    () async {
      final session = EditSession<Trip>((await trips.getTripById('t1'))!);

      final added = await writesOf(session).appendCylinders([
        tripCylinderDraftFromEquipment(
          tank,
          tripId: 't1',
          sortOrder: 0,
          now: at,
        ),
      ]);

      expect(added, isEmpty);
      expect(session.changedCardIds, isEmpty);
    },
  );
}
