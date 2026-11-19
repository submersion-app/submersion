import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// Moving a gear item and editing its past moves, held in its page's sitting
/// (issue #4527, phase 3, plan 6).
void main() {
  late EquipmentRepository items;
  late EquipmentLocationRepository places;
  late EquipmentLocationMoveRepository moves;
  late EquipmentLocation home;
  final changeLog = ChangeLogRepository();
  final sam = Buddy(
    id: 'b1',
    name: 'Sam',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'D', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
      "VALUES ('b1', 'd1', 'Sam', 0, 0)",
    );
    items = EquipmentRepository();
    places = EquipmentLocationRepository();
    moves = EquipmentLocationMoveRepository();
    await items.createEquipment(
      const EquipmentItem(
        id: 'h1',
        diverId: 'd1',
        name: 'Torch',
        type: EquipmentType.light,
      ),
    );
    await items.createEquipment(
      const EquipmentItem(
        id: 'p1',
        diverId: 'd1',
        name: 'Cell',
        type: EquipmentType.battery,
        parentEquipmentId: 'h1',
      ),
    );
    home = await places.createLocation(
      diverId: 'd1',
      name: 'Home',
      kind: EquipmentLocationKind.storage,
    );
    await moves.recordMoves(
      equipmentIds: ['h1', 'p1'],
      locationId: home.id,
      movedAt: DateTime(2026, 1, 1),
    );
    await changeLog.settleAll();
    await DatabaseService.instance.database.customStatement(
      'DELETE FROM change_log_operations',
    );
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> stored(String id) async =>
      (await items.getEquipmentById(id))!;

  Future<String?> placeOf(String id) async =>
      (await moves.getMovesFor(id)).firstOrNull?.locationId;

  Future<int> buddyPlaces() async => [
    for (final l in await places.getLocations())
      if (l.buddyId == 'b1') l,
  ].length;

  /// A lend of the torch to Sam with its battery, the diver agreeing to
  /// mark both loaned.
  Future<HeldGearItemMove> lendToSam() async {
    final torch = await stored('h1');
    final plan =
        await EquipmentMoveFlow(
          moves: moves,
          askMoveParts: (_) async => true,
          askStatus: (_, _) async => true,
          setStatus: (_, _) async {},
        ).plan(
          items: [torch],
          targetKind: EquipmentLocationKind.person,
          movedAt: DateTime(2026, 6, 1),
          note: 'Night dive',
        );
    return HeldGearItemMove(pick: BuddyPick(sam), plan: plan, diverId: 'd1');
  }

  Future<({EquipmentItem before, EquipmentItem after})?> save(
    EditSession<EquipmentItem> session,
  ) => GearItemEditSaveService(items, GearPhotoRepository()).save(
    equipmentId: session.stored.id,
    apply: (s) => gearItemToSave(s, session.applyTo(s)),
    changedCardIds: session.changedCardIds,
    alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  test('holding a move writes nothing, and its status is the item\'s in '
      'the sitting', () async {
    final session = EditSession(await stored('h1'));
    addTearDown(session.dispose);

    holdGearItemMove(session, await lendToSam());

    expect(session.working.status, EquipmentStatus.loaned);
    expect(session.changedCardIds, {'location', 'details'});
    expect(await placeOf('h1'), home.id);
    expect(await buddyPlaces(), 0);
  });

  test('a move with parts and a status change, then Cancel: nothing moved, '
      'no place created', () async {
    final session = EditSession(await stored('h1'));
    holdGearItemMove(session, await lendToSam());

    session.dispose();

    expect(await placeOf('h1'), home.id);
    expect(await placeOf('p1'), home.id);
    expect((await stored('h1')).status, EquipmentStatus.active);
    expect((await stored('p1')).status, EquipmentStatus.active);
    expect(await buddyPlaces(), 0);
  });

  test('the same, then Save: one entry, and reverting restores every place '
      'and status', () async {
    final session = EditSession(await stored('h1'));
    addTearDown(session.dispose);
    holdGearItemMove(session, await lendToSam());

    await save(session);

    final buddyPlace = (await places.getLocations()).singleWhere(
      (l) => l.buddyId == 'b1',
    );
    expect(await placeOf('h1'), buddyPlace.id);
    expect(await placeOf('p1'), buddyPlace.id);
    expect((await stored('h1')).status, EquipmentStatus.loaned);
    expect((await stored('p1')).status, EquipmentStatus.loaned);
    await changeLog.settleAll();
    final ops = await DatabaseService.instance.database
        .customSelect('SELECT id, label FROM change_log_operations')
        .get();
    expect(ops, hasLength(1));
    expect(ops.single.data['label'], startsWith('record_edit:equipment:h1:'));

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single.data['id']! as String),
    );

    expect(await placeOf('h1'), home.id);
    expect(await placeOf('p1'), home.id);
    expect((await stored('h1')).status, EquipmentStatus.active);
    expect((await stored('p1')).status, EquipmentStatus.active);
  });

  test(
    'a second move replaces the first, and takes back a status it set',
    () async {
      final session = EditSession(await stored('h1'));
      addTearDown(session.dispose);
      holdGearItemMove(session, await lendToSam());
      final torch = await stored('h1');
      final plan =
          await EquipmentMoveFlow(
            moves: moves,
            askMoveParts: (_) async => false,
            askStatus: (_, _) async => false,
            setStatus: (_, _) async {},
          ).plan(
            items: [torch],
            targetKind: EquipmentLocationKind.storage,
            movedAt: DateTime(2026, 6, 2),
          );

      holdGearItemMove(
        session,
        HeldGearItemMove(pick: PlacePick(home), plan: plan),
      );

      expect(session.working.status, EquipmentStatus.active);
      expect(heldGearItemMove(session)!.pick, isA<PlacePick>());
      expect(session.changedCardIds, {'location'});
    },
  );

  test('a second move leaves a status the diver set by hand', () async {
    final session = EditSession(await stored('h1'));
    addTearDown(session.dispose);
    holdGearItemMove(session, await lendToSam());
    session.set(gearStatusField, EquipmentStatus.inService);
    final plan =
        await EquipmentMoveFlow(
          moves: moves,
          askMoveParts: (_) async => false,
          askStatus: (_, _) async => false,
          setStatus: (_, _) async {},
        ).plan(
          items: [session.working],
          targetKind: EquipmentLocationKind.storage,
          movedAt: DateTime(2026, 6, 2),
        );

    holdGearItemMove(
      session,
      HeldGearItemMove(pick: PlacePick(home), plan: plan),
    );

    expect(session.working.status, EquipmentStatus.inService);
  });

  test('a past move edited and one deleted are written at Save', () async {
    await moves.recordMoves(
      equipmentIds: ['h1'],
      locationId: null,
      movedAt: DateTime(2026, 2, 1),
    );
    final session = EditSession(await stored('h1'));
    addTearDown(session.dispose);
    await gearItemMovesList.load(session);
    final rows = gearItemMovesList.current(session)!;
    final latest = rows.first;
    final first = rows.last;

    gearItemMovesList.set(session, [first.copyWith(note: 'Moved in')]);
    expect((await moves.getMovesFor('h1')), hasLength(2));
    await session.runHeldWrites();

    final after = await moves.getMovesFor('h1');
    expect(after.map((m) => m.id), [first.id]);
    expect(after.single.note, 'Moved in');
    expect(after.any((m) => m.id == latest.id), isFalse);
  });
}
