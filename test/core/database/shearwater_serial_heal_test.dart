import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// Issue #3106: libdivecomputer reports a Shearwater serial in decimal while
/// the computer and a Shearwater Cloud export show it in hex, so the same
/// Perdix was registered twice. The heal rewrites the serials that downloads
/// stored to the hex form, and only those.
void main() {
  late AppDatabase db;

  const nowMs = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(
    String id, {
    String? manufacturer,
    String? model,
    String? serial,
    String? connectionType,
    String? hlc,
    int updatedAt = nowMs,
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serial),
            connectionType: Value(connectionType),
            hlc: Value(hlc),
            createdAt: const Value(nowMs),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<void> insertDiveWithSource({
    required String computerId,
    required String sourceFormat,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value('dive-$computerId'),
            diveDateTime: const Value(nowMs),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'source-$computerId',
            diveId: 'dive-$computerId',
            computerId: Value(computerId),
            isPrimary: const Value(true),
            sourceFormat: Value(sourceFormat),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<DiveComputer> read(String id) =>
      (db.select(db.diveComputers)..where((t) => t.id.equals(id))).getSingle();

  test('a downloaded Shearwater decimal serial becomes hex, with no sync '
      'stamp', () async {
    await insertComputer(
      'c1',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      serial: '2712847316',
      connectionType: 'bluetooth',
      hlc: 'h1',
      updatedAt: 5,
    );

    expect(await db.healShearwaterDownloadSerialsForTest(), 1);

    final row = await read('c1');
    expect(row.serialNumber, 'A1B2C3D4');
    expect(row.hlc, 'h1');
    expect(row.updatedAt, 5);
  });

  test('an all-digit file serial is left alone, because it is already '
      'hex', () async {
    await insertComputer('f1', model: 'Perdix 2', serial: '12345678');

    expect(await db.healShearwaterDownloadSerialsForTest(), 0);
    expect((await read('f1')).serialNumber, '12345678');
  });

  test('a row a dive_computer data source points at counts as '
      'downloaded', () async {
    await insertComputer(
      'c2',
      manufacturer: 'Shearwater',
      model: 'Teric',
      serial: '3101949313',
    );
    await insertDiveWithSource(computerId: 'c2', sourceFormat: 'dive_computer');

    expect(await db.healShearwaterDownloadSerialsForTest(), 1);
    expect((await read('c2')).serialNumber, 'B8E3FD81');
  });

  test('healing twice leaves a hex result made only of digits alone', () async {
    // 0x12345678 == 305419896: the hex this build stores is all digits,
    // and the next open must not read it as decimal again.
    await insertComputer(
      'c4',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      serial: '305419896',
      connectionType: 'bluetooth',
    );

    expect(await db.healShearwaterDownloadSerialsForTest(), 1);
    expect(await db.healShearwaterDownloadSerialsForTest(), 0);
    expect((await read('c4')).serialNumber, '12345678');
  });

  test('an 8-digit serial on a downloaded row is left to the one-time '
      'upgrade pass', () async {
    // A file import's all-digit hex can sit on a row a later download
    // rebound to Bluetooth, so on an ordinary open 8 digits are ambiguous.
    await insertComputer(
      'c5',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      serial: '12345678',
      connectionType: 'bluetooth',
    );

    expect(await db.healShearwaterDownloadSerialsForTest(), 0);
    expect((await read('c5')).serialNumber, '12345678');

    // The v279 rung runs once, before this build has written any hex, when
    // every 8-digit download serial is still libdivecomputer's decimal.
    expect(
      await db.healShearwaterDownloadSerialsForTest(includeAmbiguous: true),
      1,
    );
    expect((await read('c5')).serialNumber, '00BC614E');
  });

  test('other brands and hex serials are untouched, and a second run does '
      'nothing', () async {
    await insertComputer(
      'r1',
      manufacturer: 'Ratio',
      model: 'iX3M 2',
      serial: '74691',
      connectionType: 'bluetooth',
    );
    await insertComputer(
      'h1',
      manufacturer: 'Shearwater',
      model: 'Perdix',
      serial: 'A1B2C3D4',
      connectionType: 'bluetooth',
    );
    await insertComputer(
      'c3',
      manufacturer: 'Shearwater',
      model: 'Petrel 3',
      serial: '3101949313',
      connectionType: 'usb',
    );

    expect(await db.healShearwaterDownloadSerialsForTest(), 1);
    expect(await db.healShearwaterDownloadSerialsForTest(), 0);
    expect((await read('r1')).serialNumber, '74691');
    expect((await read('h1')).serialNumber, 'A1B2C3D4');
    expect((await read('c3')).serialNumber, 'B8E3FD81');
  });
}
