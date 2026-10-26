import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';

import '../../../../helpers/test_database.dart';

/// Merging two dive computers folds the duplicate's Equipment item into the
/// survivor's (issue #3676): everything the diver kept on it moves, a link
/// the survivor already has is dropped, and the emptied item is deleted.
void main() {
  late AppDatabase db;

  Future<void> item(
    String id, {
    String? diverId = 'd1',
    String? brand,
    String? serial,
    String notes = '',
    String? parentId,
    int? purchaseDate,
    double? purchasePrice,
    String purchaseCurrency = 'USD',
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          diverId: Value(diverId),
          name: id,
          type: 'computer',
          brand: Value(brand),
          serialNumber: Value(serial),
          notes: Value(notes),
          parentEquipmentId: Value(parentId),
          purchaseDate: Value(purchaseDate),
          purchasePrice: Value(purchasePrice),
          purchaseCurrency: Value(purchaseCurrency),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals(entityType))).get())
      r.recordId,
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals(entityType))).get())
      r.recordId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    await item('into');
    await item('from');
    // The fixtures below name parents the test has no reason to build.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  Future<bool> fold() =>
      EquipmentItemFold().fold(fromId: 'from', intoId: 'into');

  test("the item's own records move to the surviving item", () async {
    await db
        .into(db.serviceRecords)
        .insert(
          ServiceRecordsCompanion.insert(
            id: 'rec',
            equipmentId: 'from',
            serviceCategory: 'battery',
            serviceDate: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.serviceSchedules)
        .insert(
          ServiceSchedulesCompanion.insert(
            id: 'sched',
            equipmentId: 'from',
            serviceKindId: 'battery',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.equipmentObservations)
        .insert(
          EquipmentObservationsCompanion.insert(
            id: 'obs',
            equipmentId: 'from',
            observedAt: 1,
            status: 'ok',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.equipmentLocationMoves)
        .insert(
          EquipmentLocationMovesCompanion.insert(
            id: 'move',
            equipmentId: 'from',
            movedAt: 1,
            createdAt: 0,
          ),
        );
    await db
        .into(db.equipmentOwnershipEvents)
        .insert(
          EquipmentOwnershipEventsCompanion.insert(
            id: 'event',
            equipmentId: 'from',
            kind: 'shared',
            occurredAt: 1,
          ),
        );
    await db
        .into(db.incidents)
        .insert(
          IncidentsCompanion.insert(
            id: 'inc',
            equipmentId: const Value('from'),
            occurredAt: 1,
            category: 'equipment',
            severity: 'minor',
            narrative: 'Strap snapped',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    // A battery fitted to the computer, and the computer as a part.
    await item('battery', parentId: 'from');
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'part',
            parentEquipmentId: 'from',
            componentEquipmentId: 'battery',
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    expect(await fold(), isTrue);

    Future<String?> ownerOf(String sql) async =>
        (await db.customSelect(sql).getSingle()).read<String?>('owner');
    expect(
      await ownerOf(
        "SELECT equipment_id AS owner FROM service_records WHERE id = 'rec'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT equipment_id AS owner FROM service_schedules '
        "WHERE id = 'sched'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT equipment_id AS owner FROM equipment_observations '
        "WHERE id = 'obs'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT equipment_id AS owner FROM equipment_location_moves '
        "WHERE id = 'move'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT equipment_id AS owner FROM equipment_ownership_events '
        "WHERE id = 'event'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        "SELECT equipment_id AS owner FROM incidents WHERE id = 'inc'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT parent_equipment_id AS owner FROM equipment '
        "WHERE id = 'battery'",
      ),
      'into',
    );
    expect(
      await ownerOf(
        'SELECT parent_equipment_id AS owner FROM equipment_components '
        "WHERE id = 'part'",
      ),
      'into',
    );
    expect(await pending('serviceRecords'), contains('rec'));
    expect(await pending('serviceSchedules'), contains('sched'));
    expect(await pending('incidents'), contains('inc'));
    expect(await pending('equipmentComponents'), contains('part'));
  });

  test('a link the surviving item already has is dropped and tombstoned; '
      'the rest move', () async {
    for (final (id, owner, tag) in [
      ('tag-into', 'into', 'red'),
      ('tag-dup', 'from', 'red'),
      ('tag-new', 'from', 'blue'),
    ]) {
      await db
          .into(db.equipmentTags)
          .insert(
            EquipmentTagsCompanion.insert(
              id: id,
              equipmentId: owner,
              tagId: tag,
              createdAt: 0,
            ),
          );
    }
    for (final (id, owner, diver) in [
      ('share-into', 'into', 'd2'),
      ('share-dup', 'from', 'd2'),
    ]) {
      await db
          .into(db.equipmentShares)
          .insert(
            EquipmentSharesCompanion.insert(
              id: id,
              equipmentId: owner,
              diverId: diver,
              createdAt: 0,
            ),
          );
    }
    for (final (id, owner, trip) in [
      ('trip-into', 'into', 'trip1'),
      ('trip-dup', 'from', 'trip1'),
      ('trip-new', 'from', 'trip2'),
    ]) {
      await db
          .into(db.tripEquipment)
          .insert(
            TripEquipmentCompanion.insert(
              id: id,
              tripId: trip,
              equipmentId: owner,
              createdAt: 0,
            ),
          );
    }
    for (final (id, owner, key) in [
      ('attr-into', 'into', 'battery'),
      ('attr-dup', 'from', 'battery'),
      ('attr-new', 'from', 'strap'),
    ]) {
      await db
          .into(db.equipmentAttributes)
          .insert(
            EquipmentAttributesCompanion.insert(
              id: id,
              equipmentId: owner,
              attrKey: key,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    await fold();

    Future<Map<String, String>> owners(String table) async => {
      for (final r
          in await db.customSelect('SELECT id, equipment_id FROM $table').get())
        r.read<String>('id'): r.read<String>('equipment_id'),
    };
    expect(await owners('equipment_tags'), {
      'tag-into': 'into',
      'tag-new': 'into',
    });
    expect(await owners('equipment_shares'), {'share-into': 'into'});
    expect(await owners('trip_equipment'), {
      'trip-into': 'into',
      'trip-new': 'into',
    });
    expect(await owners('equipment_attributes'), {
      'attr-into': 'into',
      'attr-new': 'into',
    });
    expect(await tombstones('equipmentTags'), contains('tag-dup'));
    expect(await tombstones('equipmentShares'), contains('share-dup'));
    expect(await tombstones('tripEquipment'), contains('trip-dup'));
    expect(await tombstones('equipmentAttributes'), contains('attr-dup'));
    expect(await pending('equipmentTags'), contains('tag-new'));
  });

  test('set and dive plan rows move, keyed afresh', () async {
    await db
        .into(db.equipmentSetItems)
        .insert(
          EquipmentSetItemsCompanion.insert(setId: 'set1', equipmentId: 'from'),
        );
    await db
        .into(db.divePlanEquipment)
        .insert(
          DivePlanEquipmentCompanion.insert(
            planId: 'plan1',
            equipmentId: 'battery',
            viaEquipmentId: const Value('from'),
          ),
        );
    await db
        .into(db.divePlanEquipment)
        .insert(
          DivePlanEquipmentCompanion.insert(
            planId: 'plan1',
            equipmentId: 'from',
          ),
        );

    await fold();

    final setRows = await db.select(db.equipmentSetItems).get();
    expect(
      [for (final r in setRows) (r.setId, r.equipmentId)],
      [('set1', 'into')],
    );
    final planRows = await db.select(db.divePlanEquipment).get();
    expect(
      {for (final r in planRows) (r.equipmentId, r.viaEquipmentId)},
      {('battery', 'into'), ('into', null)},
    );
    expect(await tombstones('equipmentSetItems'), contains('set1|from'));
    expect(await pending('equipmentSetItems'), contains('set1|into'));
    expect(await tombstones('divePlanEquipment'), contains('plan1|from'));
    expect(await pending('divePlanEquipment'), contains('plan1|into'));
  });

  test('dive gear moves, parts attached through the item included, and '
      'each dive is restamped', () async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'from'),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive1',
            equipmentId: 'battery',
            viaEquipmentId: const Value('from'),
          ),
        );

    await fold();

    final rows = await db.select(db.diveEquipment).get();
    expect(
      {for (final r in rows) (r.equipmentId, r.viaEquipmentId)},
      {('into', null), ('battery', 'into')},
    );
    expect(await tombstones('diveEquipment'), contains('dive1|from'));
    expect(
      await pending('diveEquipment'),
      containsAll(['dive1|into', 'dive1|battery']),
    );
    expect(await pending('dives'), contains('dive1'));
  });

  test('a surviving item fitted inside the folded one is not made its own '
      'part', () async {
    await (db.update(db.equipment)..where((t) => t.id.equals('into'))).write(
      const EquipmentCompanion(parentEquipmentId: Value('from')),
    );

    await fold();

    final into = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('into'))).getSingle();
    expect(into.parentEquipmentId, isNull);
  });

  test('documents and media move', () async {
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'doc',
            diverId: 'd1',
            equipmentId: const Value('from'),
            type: 'receipt',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'pic',
            filePath: '/photos/pic.jpg',
            equipmentId: const Value('from'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    await fold();

    final doc = await (db.select(
      db.documents,
    )..where((t) => t.id.equals('doc'))).getSingle();
    expect(doc.equipmentId, 'into');
    final pic = await (db.select(
      db.media,
    )..where((t) => t.id.equals('pic'))).getSingle();
    expect(pic.equipmentId, 'into');
  });

  test('the emptied item is deleted and tombstoned; the surviving item takes '
      'what it lacked and keeps both sets of notes', () async {
    await (db.update(db.equipment)..where((t) => t.id.equals('into'))).write(
      const EquipmentCompanion(notes: Value('Strap replaced')),
    );
    await (db.update(db.equipment)..where((t) => t.id.equals('from'))).write(
      const EquipmentCompanion(
        brand: Value('Shearwater'),
        serialNumber: Value('A1B2'),
        notes: Value('Bought used'),
        purchaseDate: Value(1700000000000),
        purchasePrice: Value(900),
        purchaseCurrency: Value('EUR'),
      ),
    );

    await fold();

    expect(
      await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('from'))).getSingleOrNull(),
      isNull,
    );
    expect(await tombstones('equipment'), contains('from'));
    final into = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('into'))).getSingle();
    expect(into.brand, 'Shearwater');
    expect(into.serialNumber, 'A1B2');
    expect(into.purchaseDate, 1700000000000);
    expect(into.purchasePrice, 900);
    expect(into.purchaseCurrency, 'EUR');
    expect(into.notes, 'Strap replaced\n\nBought used');
    expect(await pending('equipment'), contains('into'));
  });

  test("a field the surviving item already has is kept", () async {
    await (db.update(db.equipment)..where((t) => t.id.equals('into'))).write(
      const EquipmentCompanion(
        serialNumber: Value('KEEP'),
        purchasePrice: Value(500),
      ),
    );
    await (db.update(db.equipment)..where((t) => t.id.equals('from'))).write(
      const EquipmentCompanion(
        serialNumber: Value('OTHER'),
        purchasePrice: Value(900),
        purchaseCurrency: Value('EUR'),
      ),
    );

    await fold();

    final into = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('into'))).getSingle();
    expect(into.serialNumber, 'KEEP');
    expect(into.purchasePrice, 500);
    expect(into.purchaseCurrency, 'USD');
  });

  test("another diver's item is never folded", () async {
    await (db.update(db.equipment)..where((t) => t.id.equals('from'))).write(
      const EquipmentCompanion(diverId: Value('d2')),
    );

    expect(await fold(), isFalse);
    expect(
      await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('from'))).getSingleOrNull(),
      isNotNull,
    );
  });

  test('an item a device still stands for is never folded', () async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'other',
            name: 'Teric',
            equipmentId: const Value('from'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    expect(await fold(), isFalse);
    expect(
      await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('from'))).getSingleOrNull(),
      isNotNull,
    );
  });
}
