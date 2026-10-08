import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/tag_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/tag_fill.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TagFillImporter importer;
  final fill = TagFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    filledAt: DateTime.utc(2026, 9, 28, 9, 30),
    o2Percent: 32,
    pressureBar: 232,
    filledBy: 'Blue Hole',
  );
  final tag = CylinderPassportPayload(passportId: 'pp-1', fill: fill);

  setUp(() async {
    db = await setUpTestDatabase();
    importer = TagFillImporter();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tank-1',
            name: 'Faber 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('a new fill is stored under the cylinder, as from a tag', () async {
    final stored = await importer.importIfNew(
      tag: tag,
      equipmentId: 'tank-1',
      diverId: 'd1',
    );
    expect(stored!.id, fill.id);
    expect(
      (stored.passportId, stored.equipmentId, stored.source),
      ('pp-1', 'tank-1', FillSource.nfc),
    );
    expect(
      (stored.o2Percent, stored.pressureBar, stored.stationName),
      (32.0, 232.0, 'Blue Hole'),
    );
  });

  test('the same fill twice is stored once', () async {
    await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1');
    expect(
      await importer.importIfNew(
        tag: tag,
        equipmentId: 'tank-1',
        diverId: 'd1',
      ),
      isNull,
    );
    expect(await db.select(db.cylinderFills).get(), hasLength(1));
  });

  test('a deleted fill stays deleted', () async {
    final stored = await importer.importIfNew(
      tag: tag,
      equipmentId: 'tank-1',
      diverId: 'd1',
    );
    await CylinderFillRepository().delete(stored!.id);
    expect(
      await importer.importIfNew(
        tag: tag,
        equipmentId: 'tank-1',
        diverId: 'd1',
      ),
      isNull,
    );
    expect(await db.select(db.cylinderFills).get(), isEmpty);
  });

  test('a tag without a fill adds nothing', () async {
    expect(
      await importer.importIfNew(
        tag: const CylinderPassportPayload(passportId: 'pp-1'),
        equipmentId: 'tank-1',
        diverId: 'd1',
      ),
      isNull,
    );
  });
}
