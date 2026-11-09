import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/source_computer_relink.dart';

import '../../helpers/test_database.dart';

/// Issue #4368: a sync apply that ended with the computer row missing had
/// its foreign-key repair clear the downloaded sources' computer link, and
/// nothing restored it once the computer arrived. The relink restores it
/// only where the source's own dive names the computer.
void main() {
  late AppDatabase db;

  const nowMs = 1750000000000;
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(
    String id, {
    String model = 'Teric',
    String? serial = '8629AC48',
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            manufacturer: const Value('Shearwater'),
            model: Value(model),
            serialNumber: Value(serial),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(nowMs),
            computerId: Value(computerId),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertSource(
    String id, {
    required String diveId,
    String? computerId,
    String? model = 'Shearwater Teric',
    String? serial,
    String sourceFormat = 'dive_computer',
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            computerModel: Value(model),
            computerSerial: Value(serial),
            sourceFormat: Value(sourceFormat),
            hlc: const Value('source-hlc'),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<DiveDataSourcesData> source(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  test('a downloaded source on a dive attributed to its computer gets the '
      'link back, with no sync stamp', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1');
    await insertDive('d2', computerId: 'sw');
    await insertSource('s2', diveId: 'd2', serial: '2250878024');

    expect(await relinkDiveAttributedSources(db), 2);
    expect(await relinkDiveAttributedSources(db), 0);

    final s1 = await source('s1');
    expect(s1.computerId, 'sw');
    expect(s1.hlc, 'source-hlc');
    expect((await source('s2')).computerId, 'sw');
  });

  test('the source\'s profile and tank pressure series follow it, and an '
      'empty serial copy takes the computer\'s', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1');
    await db.customStatement(
      'INSERT INTO dive_profile_series (id, dive_id, source_id, '
      'sample_count, start_timestamp, end_timestamp, max_depth, '
      'first_depth, last_depth, codec_version, samples, created_at, '
      "updated_at) VALUES ('p1', 'd1', 's1', 0, 0, 0, 0, 0, 0, 1, x'', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1')",
    );
    await db.customStatement(
      'INSERT INTO tank_pressure_series (id, dive_id, tank_id, source_id, '
      'sample_count, start_timestamp, end_timestamp, codec_version, samples, '
      "created_at, updated_at) VALUES ('tp1', 'd1', 't1', 's1', 0, 0, 0, 1, "
      "x'', 1, 1)",
    );

    expect(await relinkDiveAttributedSources(db), 1);

    Future<String?> seriesComputer(String table, String id) async =>
        (await db
                .customSelect("SELECT computer_id FROM $table WHERE id = '$id'")
                .getSingle())
            .read<String?>('computer_id');
    expect(await seriesComputer('dive_profile_series', 'p1'), 'sw');
    expect(await seriesComputer('tank_pressure_series', 'tp1'), 'sw');
    expect((await source('s1')).computerSerial, '8629AC48');
  });

  test('the every-open heal relinks first, so the source takes its '
      'computer\'s serial in the same open', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1');

    await db.healDownloadedComputerSerialsForTest();

    final s1 = await source('s1');
    expect(s1.computerId, 'sw');
    expect(s1.computerSerial, '8629AC48');
  });

  test('a dive with no computer of its own is never guessed at', () async {
    await insertComputer('sw');
    await insertDive('d1');
    await insertSource('s1', diveId: 'd1');

    expect(await relinkDiveAttributedSources(db), 0);
    expect((await source('s1')).computerId, isNull);
  });

  test('another model or another serial stays detached', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1', model: 'Shearwater Perdix 2');
    await insertDive('d2', computerId: 'sw');
    await insertSource('s2', diveId: 'd2', serial: '8C4FE663');

    expect(await relinkDiveAttributedSources(db), 0);
    expect((await source('s1')).computerId, isNull);
    expect((await source('s2')).computerId, isNull);
  });

  test('a dive that already has a source of that computer keeps the other '
      'detached', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('linked', diveId: 'd1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1');

    expect(await relinkDiveAttributedSources(db), 0);
    expect((await source('s1')).computerId, isNull);
  });

  test('two fitting sources on one dive are ambiguous', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1');
    await insertSource('s2', diveId: 'd1');

    expect(await relinkDiveAttributedSources(db), 0);
  });

  test('a file import\'s source is not relinked', () async {
    await insertComputer('sw');
    await insertDive('d1', computerId: 'sw');
    await insertSource('s1', diveId: 'd1', sourceFormat: 'uddf');

    expect(await relinkDiveAttributedSources(db), 0);
  });
}
