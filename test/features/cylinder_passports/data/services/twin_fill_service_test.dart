import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderFillRepository fills;
  late CylinderPassportRepository passports;
  late TwinFillService service;
  final at = DateTime(2026, 11, 2, 9, 30);

  Future<void> seedCylinder(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  CylinderFill fillFor(String passportId, String equipmentId) => CylinderFill(
    id: '',
    diverId: 'd1',
    passportId: passportId,
    equipmentId: equipmentId,
    filledAt: at,
    o2Percent: 32,
    pressureBar: 220,
    temperatureC: 24,
    analyzer: 'Divesoft',
    stationName: 'Blue Water Fills',
    notes: 'manifold open',
    createdAt: at,
    updatedAt: at,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await seedCylinder('A');
    await seedCylinder('B');
    fills = CylinderFillRepository();
    passports = CylinderPassportRepository();
    service = TwinFillService(fills: fills, passports: passports);
  });
  tearDown(tearDownTestDatabase);

  test('recordTwinFill writes the same fill on both cylinders, tied', () async {
    final passportA = await passports.ensurePassportId('A', diverId: 'd1');
    final saved = await service.recordTwinFill(
      fillFor(passportA, 'A'),
      partnerEquipmentId: 'B',
    );
    final passportB = await passports.getPassportId('B');
    expect(passportB, isNotNull, reason: 'the partner gets a passport id');

    final a = (await fills.getForCylinder(
      passportId: passportA,
      equipmentId: 'A',
    )).single;
    final b = (await fills.getForCylinder(
      passportId: passportB,
      equipmentId: 'B',
    )).single;
    expect(a.id, saved.fill.id);
    expect(b.id, saved.partnerFill.id);
    expect(a.id, isNot(b.id));
    expect(a.filledTogetherId, isNotNull);
    expect(b.filledTogetherId, a.filledTogetherId);
    expect(b.passportId, passportB);
    expect(b.equipmentId, 'B');
    for (final f in [a, b]) {
      expect(f.filledAt, at);
      expect(f.o2Percent, 32);
      expect(f.pressureBar, 220);
      expect(f.temperatureC, 24);
      expect(f.analyzer, 'Divesoft');
      expect(f.stationName, 'Blue Water Fills');
      expect(f.notes, 'manifold open');
      expect(f.source, FillSource.manual);
    }
    expect((await fills.tiedFillOf(a))!.id, b.id);
    expect((await fills.tiedFillOf(b))!.id, a.id);
  });

  test(
    'tiedFillsOf gives the other fill of every twin fill in one read',
    () async {
      final passportA = await passports.ensurePassportId('A', diverId: 'd1');
      final first = await service.recordTwinFill(
        fillFor(passportA, 'A'),
        partnerEquipmentId: 'B',
      );
      final second = await service.recordTwinFill(
        fillFor(passportA, 'A'),
        partnerEquipmentId: 'B',
      );
      final gone = await service.recordTwinFill(
        fillFor(passportA, 'A'),
        partnerEquipmentId: 'B',
      );
      await fills.delete(gone.partnerFill.id);
      final single = await fills.create(fillFor(passportA, 'A'));

      final tied = await fills.tiedFillsOf([
        first.fill,
        second.fill,
        gone.fill,
        single,
      ]);
      expect(tied.keys, unorderedEquals([first.fill.id, second.fill.id]));
      expect(tied[first.fill.id]!.id, first.partnerFill.id);
      expect(tied[second.fill.id]!.id, second.partnerFill.id);
      expect(await fills.tiedFillsOf([single]), isEmpty);
    },
  );

  test('a single fill has no tied fill', () async {
    final single = await fills.create(fillFor('pp', 'A'));
    expect(await fills.tiedFillOf(single), isNull);
  });

  test('applyEdit to the tied fill changes both, or only one', () async {
    final saved = await service.recordTwinFill(
      fillFor('pp-a', 'A'),
      partnerEquipmentId: 'B',
    );
    await service.applyEdit(
      saved.fill.copyWith(pressureBar: 230, o2Percent: 30),
      toTied: true,
    );
    expect((await fills.getById(saved.partnerFill.id))!.pressureBar, 230);
    expect((await fills.getById(saved.partnerFill.id))!.o2Percent, 30);

    await service.applyEdit(
      saved.fill.copyWith(pressureBar: 200),
      toTied: false,
    );
    expect((await fills.getById(saved.fill.id))!.pressureBar, 200);
    expect((await fills.getById(saved.partnerFill.id))!.pressureBar, 230);
  });

  test('applyEdit with the tied fill already gone updates one', () async {
    final saved = await service.recordTwinFill(
      fillFor('pp-a', 'A'),
      partnerEquipmentId: 'B',
    );
    await fills.delete(saved.partnerFill.id);
    await service.applyEdit(
      saved.fill.copyWith(pressureBar: 210),
      toTied: true,
    );
    expect((await fills.getById(saved.fill.id))!.pressureBar, 210);
  });

  test('delete removes both, or only one, with tombstones', () async {
    final saved = await service.recordTwinFill(
      fillFor('pp-a', 'A'),
      partnerEquipmentId: 'B',
    );
    await service.delete(saved.fill, tiedToo: false);
    expect(await fills.getById(saved.fill.id), isNull);
    expect(await fills.getById(saved.partnerFill.id), isNotNull);

    final again = await service.recordTwinFill(
      fillFor('pp-a', 'A'),
      partnerEquipmentId: 'B',
    );
    await service.delete(again.fill, tiedToo: true);
    expect(await fills.getById(again.fill.id), isNull);
    expect(await fills.getById(again.partnerFill.id), isNull);
    final tombstones = await db
        .customSelect(
          'SELECT record_id FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString('cylinderFills')],
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      containsAll([again.fill.id, again.partnerFill.id]),
    );
  });

  group('isEditableFill', () {
    final manual = fillFor('pp', 'A').copyWith(id: 'f1');

    test('a manual fill is editable', () {
      expect(isEditableFill(manual, tripCopyIds: const {}), isTrue);
    });

    test('a signed, tagged or trip-copied fill is not', () {
      expect(
        isEditableFill(
          manual.copyWith(signedRecord: 'jws'),
          tripCopyIds: const {},
        ),
        isFalse,
      );
      expect(
        isEditableFill(
          manual.copyWith(source: FillSource.nfc),
          tripCopyIds: const {},
        ),
        isFalse,
      );
      expect(isEditableFill(manual, tripCopyIds: {'f1'}), isFalse);
    });
  });

  test('tripCopyIds names the copies of trip fills on the cylinder', () async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('trip', 'Trip', $t, $t, $t, $t)",
    );
    await db.customStatement(
      "INSERT INTO trip_cylinders (id, trip_id, equipment_id, created_at, "
      "updated_at) VALUES ('slot', 'trip', 'A', $t, $t)",
    );
    for (final (id, kind) in [('ev-fill', 'fill'), ('ev-adj', 'adjustment')]) {
      await db.customStatement(
        "INSERT INTO trip_cylinder_events (id, trip_cylinder_id, kind, "
        "occurred_at, created_at, updated_at) "
        "VALUES ('$id', 'slot', '$kind', $t, $t, $t)",
      );
    }
    expect(await fills.tripCopyIds('A'), {tripFillPassportCopyId('ev-fill')});
    expect(await fills.tripCopyIds('B'), isEmpty);
  });
}
