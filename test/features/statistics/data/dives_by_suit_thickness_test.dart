import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository stats;
  late DiveRepository diveRepo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    stats = StatisticsRepository();
    diveRepo = DiveRepository();
    equipmentRepo = EquipmentRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> suit(String id, String designation, double mm) =>
      equipmentRepo.createEquipment(
        EquipmentItem(
          id: id,
          name: 'Suit $designation',
          type: EquipmentType.wetsuit,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: id,
              key: 'thickness_mm',
              valueText: designation,
              valueNum: mm,
            ),
          ],
        ),
      );

  Future<EquipmentItem> gear(
    String id,
    EquipmentType type, {
    List<EquipmentAttribute> attributes = const [],
  }) => equipmentRepo.createEquipment(
    EquipmentItem(id: id, name: 'Gear $id', type: type, attributes: attributes),
  );

  Future<void> dive(String id, int day, List<EquipmentItem> items) =>
      diveRepo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, day),
          gear: looseGear(items),
        ),
      );

  test('groups dives by linked suit primary thickness', () async {
    final suit54 = await suit('s54', '5/4', 5.0);
    final suit3 = await suit('s3', '3', 3.0);

    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        gear: looseGear([suit54]),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        gear: looseGear([suit54]),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'd3',
        dateTime: DateTime(2026, 1, 3),
        gear: looseGear([suit3]),
      ),
    );
    // A dive without a suit does not appear in any bucket.
    await diveRepo.createDive(
      domain.Dive(id: 'd4', dateTime: DateTime(2026, 1, 4)),
    );

    final result = await stats.getDivesBySuitThickness();
    expect(result.byThickness, [(mm: 3.0, count: 1), (mm: 5.0, count: 2)]);
    expect(result.unknownThicknessCount, 0);
    expect(result.drysuitCount, 0);
  });

  test('drysuit dives get a bucket of their own', () async {
    // The attribute catalog gives a drysuit no thickness, so a real drysuit
    // carries none of the attribute rows the old inner join required.
    final drysuit = await gear('dry', EquipmentType.drysuit);
    await dive('d1', 1, [drysuit]);
    await dive('d2', 2, [drysuit]);

    final result = await stats.getDivesBySuitThickness();
    expect(result.drysuitCount, 2);
    expect(result.byThickness, isEmpty);
    expect(result.unknownThicknessCount, 0);
  });

  test('a drysuit never lands in a millimetre bucket', () async {
    // Legacy or imported data can hold a curated thickness on a drysuit.
    // Shell thickness says nothing about warmth, so it stays in its bucket.
    final drysuit = await gear(
      'dry',
      EquipmentType.drysuit,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'dry',
          key: 'thickness_mm',
          valueNum: 4.0,
        ),
      ],
    );
    final bareDrysuit = await gear('dry-bare', EquipmentType.drysuit);
    await dive('d1', 1, [drysuit]);
    await dive('d2', 2, [bareDrysuit]);
    await dive('d3', 3, [drysuit, bareDrysuit]);

    // One drysuit bucket of three distinct dives, whichever drysuit carried
    // a thickness.
    final result = await stats.getDivesBySuitThickness();
    expect(result.drysuitCount, 3);
    expect(result.byThickness, isEmpty);
  });

  test('wetsuit dives without a numeric thickness count as unknown', () async {
    final bare = await gear('bare', EquipmentType.wetsuit);
    final textOnly = await gear(
      'text',
      EquipmentType.wetsuit,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'text',
          key: 'thickness_mm',
          valueText: 'thick',
        ),
      ],
    );
    await dive('d1', 1, [bare]);
    await dive('d2', 2, [textOnly]);

    final result = await stats.getDivesBySuitThickness();
    expect(result.unknownThicknessCount, 2);
    expect(result.byThickness, isEmpty);
    expect(result.drysuitCount, 0);
  });

  test('a custom thickness attribute does not place a wetsuit', () async {
    // Only the curated attribute is the suit's primary thickness; a custom
    // row with the same key is free text the diver typed.
    final custom = await gear(
      'custom',
      EquipmentType.wetsuit,
      attributes: [
        const EquipmentAttribute(
          id: 'custom-thickness',
          equipmentId: 'custom',
          key: 'thickness_mm',
          isCustom: true,
          valueNum: 7.0,
        ),
      ],
    );
    await dive('d1', 1, [custom]);

    final result = await stats.getDivesBySuitThickness();
    expect(result.byThickness, isEmpty);
    expect(result.unknownThicknessCount, 1);
  });

  test('dives excluded from stats leave every bucket', () async {
    final suit5 = await suit('s5', '5', 5.0);
    final bare = await gear('bare', EquipmentType.wetsuit);
    final drysuit = await gear('dry', EquipmentType.drysuit);
    await dive('kept', 1, [suit5, bare, drysuit]);
    await diveRepo.createDive(
      domain.Dive(
        id: 'excluded',
        dateTime: DateTime(2026, 1, 2),
        excludedFromStats: true,
        gear: looseGear([suit5, bare, drysuit]),
      ),
    );

    final result = await stats.getDivesBySuitThickness();
    expect(result.byThickness, [(mm: 5.0, count: 1)]);
    expect(result.unknownThicknessCount, 1);
    expect(result.drysuitCount, 1);
  });

  test('a dive counts once per bucket it reaches', () async {
    final suit5 = await suit('s5', '5', 5.0);
    final bare = await gear('bare', EquipmentType.wetsuit);
    final drysuit = await gear('dry', EquipmentType.drysuit);
    // Two unrated wetsuits on one dive still make one unknown dive.
    final bare2 = await gear('bare2', EquipmentType.wetsuit);
    await dive('d1', 1, [suit5, bare, bare2, drysuit]);

    final result = await stats.getDivesBySuitThickness();
    expect(result.byThickness, [(mm: 5.0, count: 1)]);
    expect(result.unknownThicknessCount, 1);
    expect(result.drysuitCount, 1);
  });

  test('gear that is not a suit is ignored', () async {
    final fins = await gear('fins', EquipmentType.fins);
    final undersuit = await gear('under', EquipmentType.undersuit);
    await dive('d1', 1, [fins, undersuit]);

    final result = await stats.getDivesBySuitThickness();
    expect(result.byThickness, isEmpty);
    expect(result.unknownThicknessCount, 0);
    expect(result.drysuitCount, 0);
  });

  test('the diver filter applies to every bucket', () async {
    for (final diverId in ['diver-a', 'diver-b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(diverId),
              name: Value(diverId),
              medicalNotes: const Value(''),
              notes: const Value(''),
              isDefault: const Value(false),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    final drysuit = await gear('dry', EquipmentType.drysuit);
    final bare = await gear('bare', EquipmentType.wetsuit);
    await diveRepo.createDive(
      domain.Dive(
        id: 'mine',
        diverId: 'diver-a',
        dateTime: DateTime(2026, 1, 1),
        gear: looseGear([drysuit, bare]),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'theirs',
        diverId: 'diver-b',
        dateTime: DateTime(2026, 1, 2),
        gear: looseGear([drysuit, bare]),
      ),
    );

    final result = await stats.getDivesBySuitThickness(diverId: 'diver-a');
    expect(result.drysuitCount, 1);
    expect(result.unknownThicknessCount, 1);
  });

  test('a query error is surfaced rather than reported as no data', () async {
    // Returning empty on failure made the card show "no dives" instead of
    // its error state, hiding the fault from the diver.
    await db.customStatement('DROP TABLE equipment_attributes');

    await expectLater(
      stats.getDivesBySuitThickness(),
      throwsA(isA<SqliteException>()),
    );
  });
}
