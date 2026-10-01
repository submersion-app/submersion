import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/csv_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

import '../../../../helpers/test_database.dart';

/// The CSV twin of TagFillImporter (cylinder passports phase 5): a fill
/// row keeps its id, imports once, and links to the cylinder holding its
/// passport id.
void main() {
  late AppDatabase db;
  late CylinderFillRepository fills;
  late CsvFillImporter importer;
  const fillId = '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11';

  Map<String, dynamic> row({String id = fillId, String passportId = 'pp-1'}) =>
      <String, dynamic>{
        'uddfId': 'f0:$id',
        'id': id,
        'passportId': passportId,
        'filledAt': DateTime(2026, 9, 28, 9, 30),
        'o2Percent': 32.0,
        'hePercent': 0.0,
        'pressureBar': 232.0,
        'stationName': 'Blue Hole',
        'source': 'qr',
        'notes': 'from the sheet',
      };

  setUp(() async {
    db = await setUpTestDatabase();
    fills = CylinderFillRepository();
    importer = CsvFillImporter();
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
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-1',
      diverId: 'd1',
    );
  });
  tearDown(tearDownTestDatabase);

  test('a new fill keeps its id, is stamped with the diver and links to '
      'the cylinder holding its passport id', () async {
    final count = await importer.importRows(
      [row()],
      selected: {0},
      diverId: 'd1',
    );
    expect(count, 1);
    final stored = (await fills.getById(fillId))!;
    expect(stored.id, fillId);
    expect(stored.diverId, 'd1');
    expect(stored.passportId, 'pp-1');
    expect(stored.equipmentId, 'tank-1');
    expect(stored.filledAt, DateTime(2026, 9, 28, 9, 30));
    expect(stored.o2Percent, 32);
    expect(stored.pressureBar, 232);
    expect(stored.stationName, 'Blue Hole');
    // The source is kept as written, not rewritten to "file".
    expect(stored.source, FillSource.qr);
    expect(stored.notes, 'from the sheet');
  });

  test('a fill with no matching cylinder stays unlinked under its passport '
      'id', () async {
    await importer.importRows(
      [row(passportId: 'pp-unknown')],
      selected: {0},
      diverId: 'd1',
    );
    final stored = (await fills.getById(fillId))!;
    expect(stored.equipmentId, isNull);
    expect(stored.passportId, 'pp-unknown');
    expect(stored.diverId, 'd1');
  });

  test(
    'a fill already here is skipped, so the same rows import once',
    () async {
      expect(
        await importer.importRows([row()], selected: {0}, diverId: 'd1'),
        1,
      );
      expect(
        await importer.importRows([row()], selected: {0}, diverId: 'd1'),
        0,
      );
      expect(
        (await fills.getForCylinder(
          passportId: 'pp-1',
          equipmentId: 'tank-1',
        )).map((f) => f.id),
        [fillId],
      );
    },
  );

  test('a fill deleted here is not brought back', () async {
    await importer.importRows([row()], selected: {0}, diverId: 'd1');
    await fills.delete(fillId);
    expect(await importer.importRows([row()], selected: {0}, diverId: 'd1'), 0);
    expect(await fills.getById(fillId), isNull);
  });

  test('unselected and unreadable rows are skipped and never fatal', () async {
    final count = await importer.importRows(
      [row(), row(id: 'second')..remove('o2Percent'), row(id: 'third')],
      selected: {0, 1},
      diverId: 'd1',
    );
    expect(count, 1);
    expect(await fills.getById('second'), isNull);
    expect(await fills.getById('third'), isNull, reason: 'not selected');
  });

  test(
    'a row that cannot be stored is logged and the rest still import',
    () async {
      final seen = <LogEntry>[];
      final sub = LoggerService.logStream.listen(seen.add);
      addTearDown(sub.cancel);
      final failing = CsvFillImporter(fills: _FailingFills('bad'));
      final count = await failing.importRows(
        [row(id: 'bad'), row(id: 'good')],
        selected: {0, 1},
        diverId: 'd1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
      expect(
        seen.where((e) => e.message.contains('Could not import fill bad')),
        hasLength(1),
      );
    },
  );

  test('fromPayload refuses a gas mix the Log fill sheet would', () {
    expect(CsvFillImporter.fromPayload(row()..['o2Percent'] = 320.0), isNull);
    expect(
      CsvFillImporter.fromPayload(
        row()
          ..['o2Percent'] = 18.0
          ..['hePercent'] = 90.0,
      ),
      isNull,
    );
  });

  test('one import looks each passport id up once, however many fills '
      'it holds', () async {
    final passports = _CountingPassports();
    final counting = CsvFillImporter(passports: passports);
    final count = await counting.importRows(
      [
        row(id: 'a'),
        row(id: 'b'),
        row(id: 'c', passportId: 'pp-unknown'),
        row(id: 'd'),
      ],
      selected: {0, 1, 2, 3},
      diverId: 'd1',
    );
    expect(count, 4);
    expect(passports.lookups, ['pp-1', 'pp-unknown']);
    for (final id in ['a', 'b', 'd']) {
      expect((await fills.getById(id))!.equipmentId, 'tank-1');
    }
    expect((await fills.getById('c'))!.equipmentId, isNull);
  });

  test('one import asks which ids are known once, not row by row, and '
      'still stores a repeated id once', () async {
    await importer.importRows(
      [row(id: 'old')],
      selected: {0},
      diverId: 'd1',
    );
    await fills.delete('old');
    final counting = _CountingFills();
    final count = await CsvFillImporter(fills: counting).importRows(
      [row(id: 'a'), row(id: 'old'), row(id: 'b'), row(id: 'a')],
      selected: {0, 1, 2, 3},
      diverId: 'd1',
    );
    expect(count, 2);
    expect(counting.rowLookups, 0);
    expect(counting.knownIdsCalls, 1);
    expect(await fills.getById('old'), isNull);
  });

  test(
    'fromPayload reads an unknown source as manual and a missing He as 0',
    () {
      final fill = CsvFillImporter.fromPayload(
        row()
          ..['source'] = 'teleport'
          ..remove('hePercent'),
      )!;
      expect(fill.source, FillSource.manual);
      expect(fill.hePercent, 0);
      expect(fill.equipmentId, isNull);
    },
  );
}

/// Counts the fill lookups an import makes.
class _CountingFills extends CylinderFillRepository {
  var rowLookups = 0;
  var knownIdsCalls = 0;

  @override
  Future<CylinderFill?> getById(String id) {
    rowLookups++;
    return super.getById(id);
  }

  @override
  Future<bool> wasDeleted(String id) {
    rowLookups++;
    return super.wasDeleted(id);
  }

  @override
  Future<Set<String>> knownIds(Iterable<String> ids) {
    knownIdsCalls++;
    return super.knownIds(ids);
  }
}

/// Counts the passport lookups an import makes.
class _CountingPassports extends CylinderPassportRepository {
  final lookups = <String>[];

  @override
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) {
    lookups.add(passportId);
    return super.findEquipmentIdByPassportId(passportId, diverId: diverId);
  }
}

/// Throws when asked to store the fill [failId], as a locked database would.
class _FailingFills extends CylinderFillRepository {
  _FailingFills(this.failId);

  final String failId;

  @override
  Future<CylinderFill> create(CylinderFill fill) async {
    if (fill.id == failId) throw StateError('database is locked');
    return super.create(fill);
  }
}
