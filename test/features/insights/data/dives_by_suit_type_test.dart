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
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/suit_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository stats;
  late DiveRepository diveRepo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    stats = InsightsRepository();
    diveRepo = DiveRepository();
    equipmentRepo = EquipmentRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> wetsuit(
    String id, {
    String? designation,
    double? mm,
    String? style,
  }) => equipmentRepo.createEquipment(
    EquipmentItem(
      id: id,
      name: 'Suit $id',
      type: EquipmentType.wetsuit,
      attributes: [
        if (mm != null || designation != null)
          EquipmentAttribute.curated(
            equipmentId: id,
            key: 'thickness_mm',
            valueText: designation,
            valueNum: mm,
          ),
        if (style != null)
          EquipmentAttribute.curated(
            equipmentId: id,
            key: 'suit_style',
            valueText: style,
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

  test('groups dives by wetsuit thickness and style (issue #4490)', () async {
    final full5 = await wetsuit('f5', designation: '5/4', mm: 5, style: 'full');
    final shorty3 = await wetsuit('s3', mm: 3, style: 'shorty');
    final full3 = await wetsuit('f3', mm: 3, style: 'full');
    await dive('d1', 1, [full5]);
    await dive('d2', 2, [full5]);
    await dive('d3', 3, [shorty3]);
    await dive('d4', 4, [full3]);
    // A dive without a suit does not appear in any bucket.
    await diveRepo.createDive(
      domain.Dive(id: 'd5', dateTime: DateTime(2026, 1, 5)),
    );

    // Two 3 mm suits of different styles are two bars, not one.
    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 3, style: 'full'), count: 1),
      (type: const SuitType.wetsuit(mm: 3, style: 'shorty'), count: 1),
      (type: const SuitType.wetsuit(mm: 5, style: 'full'), count: 2),
    ]);
  });

  test('a missing thickness or style keeps the rest of the bucket', () async {
    final thicknessOnly = await wetsuit('t', mm: 5);
    final styleOnly = await wetsuit('s', style: 'shorty');
    final bare = await gear('bare', EquipmentType.wetsuit);
    await dive('d1', 1, [thicknessOnly]);
    await dive('d2', 2, [styleOnly]);
    await dive('d3', 3, [bare]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 5), count: 1),
      (type: const SuitType.wetsuit(style: 'shorty'), count: 1),
      (type: const SuitType.wetsuit(), count: 1),
    ]);
  });

  test('drysuit dives get one bucket of their own, last', () async {
    // The attribute catalog gives a drysuit no thickness or style, and
    // legacy or imported data that holds them says nothing about warmth.
    final drysuit = await gear(
      'dry',
      EquipmentType.drysuit,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'dry',
          key: 'thickness_mm',
          valueNum: 4.0,
        ),
        EquipmentAttribute.curated(
          equipmentId: 'dry',
          key: 'suit_style',
          valueText: 'full',
        ),
      ],
    );
    final bareDrysuit = await gear('dry-bare', EquipmentType.drysuit);
    final shorty = await wetsuit('s', mm: 3, style: 'shorty');
    await dive('d1', 1, [drysuit]);
    await dive('d2', 2, [bareDrysuit]);
    await dive('d3', 3, [drysuit, bareDrysuit]);
    await dive('d4', 4, [shorty]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 3, style: 'shorty'), count: 1),
      (type: const SuitType.drysuit(), count: 3),
    ]);
  });

  test('a wetsuit with text-only thickness has no thickness', () async {
    final textOnly = await wetsuit('text', designation: 'thick');
    await dive('d1', 1, [textOnly]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(), count: 1),
    ]);
  });

  test('custom attributes do not place a wetsuit', () async {
    // Only curated attributes are the suit's thickness and style; a custom
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
        const EquipmentAttribute(
          id: 'custom-style',
          equipmentId: 'custom',
          key: 'suit_style',
          isCustom: true,
          valueText: 'shorty',
        ),
      ],
    );
    await dive('d1', 1, [custom]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(), count: 1),
    ]);
  });

  test('a blank style is no style', () async {
    // The repository drops a blank attribute on save, but a sync pull or an
    // import writes rows directly, so write one the same way.
    final blank = await wetsuit('blank', mm: 5);
    await db
        .into(db.equipmentAttributes)
        .insert(
          const EquipmentAttributesCompanion(
            id: Value('blank-style'),
            equipmentId: Value('blank'),
            attrKey: Value('suit_style'),
            valueText: Value('  '),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
    await dive('d1', 1, [blank]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 5), count: 1),
    ]);
  });

  test('a padded style shares the bucket of its catalog key', () async {
    // A sync pull or an import can write the value with stray spaces.
    final padded = await wetsuit('padded', mm: 3);
    await db
        .into(db.equipmentAttributes)
        .insert(
          const EquipmentAttributesCompanion(
            id: Value('padded-style'),
            equipmentId: Value('padded'),
            attrKey: Value('suit_style'),
            valueText: Value(' shorty '),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
    final shorty = await wetsuit('shorty', mm: 3, style: 'shorty');
    await dive('d1', 1, [padded]);
    await dive('d2', 2, [shorty]);

    const type = SuitType.wetsuit(mm: 3, style: 'shorty');
    expect(await stats.getDivesBySuitType(), [(type: type, count: 2)]);
    expect(
      await stats.getSuitTypeDiveIds(type: type),
      unorderedEquals(['d1', 'd2']),
    );
  });

  test('dives excluded from stats leave every bucket', () async {
    final full5 = await wetsuit('f5', mm: 5, style: 'full');
    final drysuit = await gear('dry', EquipmentType.drysuit);
    await dive('kept', 1, [full5, drysuit]);
    await diveRepo.createDive(
      domain.Dive(
        id: 'excluded',
        dateTime: DateTime(2026, 1, 2),
        excludedFromStats: true,
        gear: looseGear([full5, drysuit]),
      ),
    );

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 5, style: 'full'), count: 1),
      (type: const SuitType.drysuit(), count: 1),
    ]);
  });

  test('a dive counts once per bucket it reaches', () async {
    final full5 = await wetsuit('f5', mm: 5, style: 'full');
    final bare = await gear('bare', EquipmentType.wetsuit);
    // Two unrated wetsuits on one dive still make one plain-wetsuit dive.
    final bare2 = await gear('bare2', EquipmentType.wetsuit);
    final drysuit = await gear('dry', EquipmentType.drysuit);
    await dive('d1', 1, [full5, bare, bare2, drysuit]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 5, style: 'full'), count: 1),
      (type: const SuitType.wetsuit(), count: 1),
      (type: const SuitType.drysuit(), count: 1),
    ]);
  });

  test('gear that is not a suit is ignored', () async {
    final fins = await gear('fins', EquipmentType.fins);
    final undersuit = await gear('under', EquipmentType.undersuit);
    await dive('d1', 1, [fins, undersuit]);

    expect(await stats.getDivesBySuitType(), isEmpty);
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

    expect(await stats.getDivesBySuitType(diverId: 'diver-a'), [
      (type: const SuitType.wetsuit(), count: 1),
      (type: const SuitType.drysuit(), count: 1),
    ]);
  });

  test('a vest worn with a wetsuit is not a second suit (#3108)', () async {
    // The diver in #3108 wears a 7 mm suit with a hooded vest. Typed as a
    // vest, it must not open a bucket of its own beside the suit's.
    final suit7 = await wetsuit('s7', mm: 7);
    final vest = await gear(
      'vest',
      EquipmentType.vest,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'vest',
          key: 'thickness_mm',
          valueText: '5',
          valueNum: 5.0,
        ),
      ],
    );
    await dive('d1', 1, [vest, suit7]);
    await dive('d2', 2, [vest]);

    expect(await stats.getDivesBySuitType(), [
      (type: const SuitType.wetsuit(mm: 7), count: 1),
    ]);
  });

  test('a query error is surfaced rather than reported as no data', () async {
    // Returning empty on failure made the card show "no dives" instead of
    // its error state, hiding the fault from the diver.
    await db.customStatement('DROP TABLE equipment_attributes');

    await expectLater(
      stats.getDivesBySuitType(),
      throwsA(isA<SqliteException>()),
    );
  });
}
