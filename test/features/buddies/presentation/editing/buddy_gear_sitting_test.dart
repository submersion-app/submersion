import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Buddy;
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_gear_sitting.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/data/services/equipment_return_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/lend_gear_flow.dart';
import 'package:submersion/features/equipment/presentation/widgets/return_equipment_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// Gear lent and returned on a buddy's page waits for Save (issue #4527,
/// phase 3).
void main() {
  late AppDatabase db;
  final moves = EquipmentLocationMoveRepository();
  final alex = Buddy(
    id: 'b1',
    diverId: 'me',
    name: 'Alex',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Regulator',
    type: EquipmentType.regulator,
    status: EquipmentStatus.active,
  );

  Future<List<String>> buddyPlaces() async => [
    for (final row
        in await db
            .customSelect(
              "SELECT id FROM equipment_locations WHERE buddy_id = 'b1'",
            )
            .get())
      row.read<String>('id'),
  ];

  Future<String> statusOf(String id) async =>
      (await db
              .customSelect(
                'SELECT status FROM equipment WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String>('status');

  HeldLend lend() => HeldLend(
    items: const [reg],
    pick: BuddyPick(alex),
    plan: EquipmentMovePlan(
      items: const {'reg': EquipmentStatus.active},
      movedAt: DateTime(2026, 10, 1),
      status: EquipmentStatus.loaned,
    ),
    diverId: 'me',
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b1', 'me', 'Alex', 0, 0)",
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Regulator',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: 'shelf',
            name: 'Shelf',
            kind: const Value('storage'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shelf',
      movedAt: DateTime(2026, 1, 1),
    );
  });

  tearDown(tearDownTestDatabase);

  test('a held lend is written at Save, place created then', () async {
    final session = EditSession(alex);
    addTearDown(session.dispose);

    holdBuddyLend(session, lend());
    expect(session.changedCardIds, {'gear'});
    expect(await buddyPlaces(), isEmpty);
    await session.runHeldWrites();

    final places = await buddyPlaces();
    expect(places, hasLength(1));
    expect((await moves.getCurrentLocationIds())['reg'], places.single);
    expect(await statusOf('reg'), 'loaned');
  });

  test('gear lent in a sitting, then Cancel', () async {
    final session = EditSession(alex);
    holdBuddyLend(session, lend());

    session.dispose();

    expect(await buddyPlaces(), isEmpty);
    expect((await moves.getCurrentLocationIds())['reg'], 'shelf');
    expect(await statusOf('reg'), 'active');
  });

  test('a held return goes back to the place before the loan', () async {
    final lent = EditSession(alex);
    holdBuddyLend(lent, lend());
    await lent.runHeldWrites();
    lent.dispose();
    final session = EditSession(alex);
    addTearDown(session.dispose);

    holdBuddyReturn(
      session,
      HeldReturn(
        items: const [reg],
        plan: EquipmentReturnPlan(
          items: const {'reg': EquipmentStatus.loaned},
          buddyId: 'b1',
          movedAt: DateTime(2026, 11, 1),
          setActive: true,
        ),
      ),
    );
    await session.runHeldWrites();

    expect((await moves.getCurrentLocationIds())['reg'], 'shelf');
    expect(await statusOf('reg'), 'active');
  });

  test('a lend then its release is no change', () {
    final session = EditSession(alex);
    addTearDown(session.dispose);

    holdBuddyLend(session, lend());
    releaseBuddyGearMove(session, 0);

    expect(session.isDirty, isFalse);
    expect(heldBuddyGearMoves(session), isEmpty);
  });

  group('taking one item out of a held lend', () {
    const torch = EquipmentItem(
      id: 'torch',
      name: 'Torch',
      type: EquipmentType.light,
      status: EquipmentStatus.active,
    );
    HeldLend lendOfTwo({bool withParts = false}) => HeldLend(
      items: const [reg, torch],
      pick: BuddyPick(alex),
      plan: EquipmentMovePlan(
        items: const {
          'reg': EquipmentStatus.active,
          'torch': EquipmentStatus.active,
        },
        movedAt: DateTime(2026, 10, 1),
        withParts: withParts,
        partIds: withParts ? const {'hose', 'clip'} : const {},
        status: EquipmentStatus.loaned,
      ),
      diverId: 'me',
    );
    Future<Map<String, EquipmentStatus>> noParts(Iterable<String> _) async =>
        const {};

    test('keeps the rest of the lend', () async {
      final session = EditSession(alex);
      addTearDown(session.dispose);
      holdBuddyLend(session, lendOfTwo());

      await releaseBuddyLendItem(session, 0, 'torch', partsOf: noParts);

      final held = heldBuddyGearMoves(session).single.lend!;
      expect([for (final i in held.items) i.id], ['reg']);
      expect(held.plan.items.keys, ['reg']);
      expect(held.plan.status, EquipmentStatus.loaned);
      expect(session.changedCardIds, {'gear'});
    });

    test('the last item takes the lend back', () async {
      final session = EditSession(alex);
      addTearDown(session.dispose);
      holdBuddyLend(session, lend());

      await releaseBuddyLendItem(session, 0, 'reg', partsOf: noParts);

      expect(heldBuddyGearMoves(session), isEmpty);
      expect(session.isDirty, isFalse);
    });

    test('the parts are found again for what is left', () async {
      final session = EditSession(alex);
      addTearDown(session.dispose);
      holdBuddyLend(session, lendOfTwo(withParts: true));

      await releaseBuddyLendItem(
        session,
        0,
        'torch',
        partsOf: (ids) async => {
          if (ids.contains('reg')) 'hose': EquipmentStatus.active,
        },
      );

      final held = heldBuddyGearMoves(session).single.lend!;
      expect(held.plan.withParts, isTrue);
      expect(held.plan.partIds, {'hose'});
    });
  });

  test('the sitting lists what it lends and leaves out what it returns', () {
    final session = EditSession(alex);
    addTearDown(session.dispose);
    final place = EquipmentLocation(
      id: 'p',
      name: 'Alex',
      kind: EquipmentLocationKind.person,
      buddyId: 'b1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const bcd = EquipmentItem(
      id: 'bcd',
      name: 'BCD',
      type: EquipmentType.bcd,
      status: EquipmentStatus.loaned,
    );

    holdBuddyLend(session, lend());
    holdBuddyReturn(
      session,
      HeldReturn(
        items: const [bcd],
        plan: EquipmentReturnPlan(
          items: const {'bcd': EquipmentStatus.loaned},
          buddyId: 'b1',
          movedAt: DateTime(2026, 11, 1),
        ),
      ),
    );
    final rows = buddyGearInSitting(session, [(item: bcd, place: place)]);

    expect([for (final r in rows) r.gear.item.id], ['reg']);
    expect(rows.single.heldIndex, 0);
  });

  test('a held return leaves out the parts that go with it', () {
    final session = EditSession(alex);
    addTearDown(session.dispose);
    final place = EquipmentLocation(
      id: 'p',
      name: 'Alex',
      kind: EquipmentLocationKind.person,
      buddyId: 'b1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const second = EquipmentItem(
      id: 'second',
      name: 'Second stage',
      type: EquipmentType.regulator,
      status: EquipmentStatus.loaned,
    );

    holdBuddyReturn(
      session,
      HeldReturn(
        items: const [reg],
        plan: EquipmentReturnPlan(
          items: const {'reg': EquipmentStatus.loaned},
          buddyId: 'b1',
          movedAt: DateTime(2026, 11, 1),
          withParts: true,
          partIds: const {'second'},
        ),
      ),
    );
    final rows = buddyGearInSitting(session, [
      (item: reg, place: place),
      (item: second, place: place),
    ]);

    expect(rows, isEmpty);
  });

  test('a held lend lists the parts that go with it', () {
    final session = EditSession(alex);
    addTearDown(session.dispose);
    const second = EquipmentItem(
      id: 'second',
      name: 'Second stage',
      type: EquipmentType.regulator,
      status: EquipmentStatus.active,
    );
    final withParts = lend();
    holdBuddyLend(
      session,
      HeldLend(
        items: withParts.items,
        pick: withParts.pick,
        plan: EquipmentMovePlan(
          items: withParts.plan.items,
          movedAt: withParts.plan.movedAt,
          withParts: true,
          partIds: const {'second'},
        ),
        diverId: 'me',
      ),
    );

    final rows = buddyGearInSitting(session, const [], items: const [second]);

    expect([for (final r in rows) r.gear.item.id], ['reg', 'second']);
  });

  test(
    "a lend's new place takes the name the sitting gives the buddy",
    () async {
      final session = EditSession(alex);
      addTearDown(session.dispose);
      holdBuddyLend(session, lend());
      session.set(buddyNameField, 'Alexander');

      await session.runHeldWrites();

      final names = [
        for (final row
            in await db
                .customSelect(
                  "SELECT name FROM equipment_locations WHERE buddy_id = 'b1'",
                )
                .get())
          row.read<String>('name'),
      ];
      expect(names, ['Alexander']);
    },
  );
}
