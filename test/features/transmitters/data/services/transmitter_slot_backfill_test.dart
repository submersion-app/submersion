import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill_memo.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

import '../../../../helpers/test_database.dart';

class _FakeParser implements ImportParser {
  _FakeParser(this.dive);

  final Map<String, dynamic> dive;

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async => ImportPayload(
    entities: {
      ImportEntityType.dives: [dive],
    },
  );

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.shearwaterDb];
}

/// A `.db` parse with no native parser behind it, as on the web.
class _ThrowingParser implements ImportParser {
  _ThrowingParser([Object? error])
    : error = error ?? PlatformException(code: 'channel-error');

  final Object error;
  var calls = 0;

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    calls++;
    throw error;
  }

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.shearwaterDb];
}

class _MemoryMemo implements TransmitterSlotBackfillMemo {
  final done = <String>{};

  @override
  Future<Set<String>> load() async => {...done};

  @override
  Future<void> add(Iterable<String> keys) async => done.addAll(keys);
}

/// Issue #4347: dives already stored learn their transmitter slots from
/// their raw bytes or their original import file.
void main() {
  const fixture = 'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf';
  late AppDatabase db;
  late _MemoryMemo memo;
  var parses = 0;

  pigeon.ParsedDive parsedWithSlot(int? slot) => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 3,
    dateTimeDay: 12,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 20,
    avgDepthMeters: 12,
    durationSeconds: 2400,
    samples: const [],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: 0,
        transmitterSerial: 180777,
        transmitterSlot: slot,
      ),
    ],
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32, hePercent: 0)],
    events: const [],
  );

  Future<pigeon.ParsedDive> fakeParse(
    String vendor,
    String product,
    int model,
    Uint8List raw,
  ) async {
    parses++;
    return parsedWithSlot(1);
  }

  Future<void> computer(String id) => db.customStatement(
    'INSERT OR IGNORE INTO dive_computers (id, name, connection_type, '
    "created_at, updated_at) VALUES ('$id', '$id', 'ble', 1, 1)",
  );

  Future<void> source(
    String diveId, {
    required String computerId,
    Uint8List? raw,
    String? fileId,
    String? fileFormat,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value('src-$diveId'),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: const Value(true),
          sourceFormat: Value(raw != null ? 'dive_computer' : 'file'),
          importedAt: Value(DateTime.utc(2026)),
          createdAt: Value(DateTime.utc(2026)),
          rawData: Value(raw),
          descriptorVendor: Value(raw != null ? 'Shearwater' : null),
          descriptorProduct: Value(raw != null ? 'Perdix 2' : null),
          descriptorModel: Value(raw != null ? 0 : null),
          importedFileId: Value(fileId),
          sourceFileFormat: Value(fileFormat),
        ),
      );

  Future<void> tank(
    String id,
    String diveId, {
    String? serial,
    int order = 0,
    int? sourceIndex,
    double? start,
    double? end,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            transmitterSerial: Value(serial),
            startPressure: Value(start),
            endPressure: Value(end),
            tankOrder: Value(order),
            sourceTankIndex: Value(sourceIndex),
            tankRole: const Value('backGas'),
            o2Percent: const Value(21),
            hePercent: const Value(0),
          ),
        );
    await TankPressureRepository().insertTankPressures(diveId, {
      id: [(timestamp: 0, pressure: 200.0)],
    });
  }

  Future<void> dive(
    String id,
    String computerId, {
    DateTime? at,
    double? maxDepth,
    int? runtimeSeconds,
    String? diverId,
  }) async {
    await computer(computerId);
    if (diverId != null) {
      await db.customStatement(
        'INSERT OR IGNORE INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$diverId', '$diverId', 1, 1)",
      );
    }
    await DiveRepository().createDive(
      domain.Dive(
        id: id,
        dateTime: at ?? DateTime.utc(2026, 3, 12, 9),
        maxDepth: maxDepth,
        runtime: runtimeSeconds == null
            ? null
            : Duration(seconds: runtimeSeconds),
        diverId: diverId,
      ),
    );
    await db.customStatement(
      "UPDATE dives SET computer_id = '$computerId' WHERE id = '$id'",
    );
  }

  /// The Shearwater Cloud fixture's dive, stored as a file import with two
  /// slot-less tanks written in file order, as the importer leaves them.
  Future<void> cloudDive({int tanks = 2, bool reordered = false}) async {
    final content = File(fixture).readAsStringSync();
    final entry = (await UddfFullImportService().importAllDataFromUddf(
      content,
    )).dives.first;
    await dive(
      'cloud',
      'petrel',
      at: entry['dateTime'] as DateTime,
      maxDepth: (entry['maxDepth'] as num?)?.toDouble(),
      runtimeSeconds: (entry['runtime'] as Duration?)?.inSeconds,
    );
    final fileId = await ImportedFileRepository().store(
      bytes: Uint8List.fromList(content.codeUnits),
      fileName: 'cloud.uddf',
    );
    await source(
      'cloud',
      computerId: 'petrel',
      fileId: fileId,
      fileFormat: 'uddf',
    );
    // The rows carry the file's pressures, as the import wrote them; a
    // reorder (or a delete plus an add) leaves them out of file order.
    final fileTanks = (entry['tanks'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < tanks; i++) {
      final from = i < fileTanks.length
          ? fileTanks[reordered ? fileTanks.length - 1 - i : i]
          : const <String, dynamic>{};
      await tank(
        'cloud-t$i',
        'cloud',
        start: (from['startPressure'] as num?)?.toDouble(),
        end: (from['endPressure'] as num?)?.toDouble(),
      );
    }
  }

  Future<Map<String, int?>> slots() async => {
    for (final r in await db.select(db.diveTanks).get())
      r.id: r.transmitterSlot,
  };

  TransmitterSlotBackfill backfill({RawDiveParseFn? parse}) =>
      TransmitterSlotBackfill(parseRaw: parse ?? fakeParse, memo: memo);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    memo = _MemoryMemo();
    parses = 0;
  });
  tearDown(tearDownTestDatabase);

  test(
    'a download whose tank lacks a slot gets it from its raw bytes',
    () async {
      await dive('bt', 'perdix');
      await source('bt', computerId: 'perdix', raw: Uint8List(8));
      await tank('bt-t', 'bt', serial: '180777', sourceIndex: 0);

      final written = await backfill().run({'perdix'});
      expect(written, 1);
      expect((await slots())['bt-t'], 1);
    },
  );

  test('a Shearwater Cloud dive gets its slots from the stored file', () async {
    await cloudDive();
    await backfill().run({'petrel'});
    expect(await slots(), {'cloud-t0': 0, 'cloud-t1': 1});
  });

  test('a Cloud dive whose tank count no longer matches the file is left '
      'alone', () async {
    await cloudDive(tanks: 3);
    final written = await backfill().run({'petrel'});
    expect(written, 0);
    expect((await slots()).values, everyElement(isNull));
  });

  test('a Cloud dive whose tanks no longer line up with the file is left '
      'alone', () async {
    await cloudDive(reordered: true);
    final written = await backfill().run({'petrel'});
    expect(written, 0);
    expect((await slots()).values, everyElement(isNull));
  });

  test('a stored file not yet on this device is tried again later', () async {
    await dive('cloud', 'petrel');
    await source(
      'cloud',
      computerId: 'petrel',
      fileId: 'not-synced-yet',
      fileFormat: 'uddf',
    );
    await tank('cloud-t0', 'cloud', start: 200, end: 100);

    await backfill().run({'petrel'});
    expect(memo.done, isNot(contains('file:cloud')));
  });

  test('a Shearwater Cloud database dive gains the serial and slot its file '
      'names', () async {
    await dive('db', 'petrel', maxDepth: 30, runtimeSeconds: 3000);
    final fileId = await ImportedFileRepository().store(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'cloud.db',
    );
    await source(
      'db',
      computerId: 'petrel',
      fileId: fileId,
      fileFormat: 'shearwaterDb',
    );
    await tank('db-t0', 'db', start: 200, end: 100);
    final files = DiveResyncOrchestrator(
      db: db,
      parserFor: (_) => _FakeParser({
        'dateTime': DateTime.utc(2026, 3, 12, 9),
        'maxDepth': 30.0,
        'runtime': const Duration(seconds: 3000),
        'tanks': [
          {
            'startPressure': 200.0,
            'endPressure': 100.0,
            'transmitterSlot': 1,
            'transmitterSerial': '109623',
          },
        ],
      }),
    );

    await TransmitterSlotBackfill(
      parseRaw: fakeParse,
      memo: memo,
      files: files,
    ).run({'petrel'});
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('db-t0'))).getSingle();
    expect(row.transmitterSlot, 1);
    expect(row.transmitterSerial, '109623');
  });

  test(
    'computers with a stored Shearwater Cloud database are in scope',
    () async {
      await dive('db', 'teric');
      await source(
        'db',
        computerId: 'teric',
        fileId: 'f',
        fileFormat: 'shearwaterDb',
      );
      await dive('cloud', 'petrel');
      await source(
        'cloud',
        computerId: 'petrel',
        fileId: 'g',
        fileFormat: 'uddf',
      );
      expect(await backfill().dbImportComputers(), {'teric'});
    },
  );

  test(
    'a diver\'s scope leaves other divers\' computers and dives alone',
    () async {
      await dive('db-1', 'teric', diverId: 'diver-1');
      await source(
        'db-1',
        computerId: 'teric',
        fileId: 'f',
        fileFormat: 'shearwaterDb',
      );
      await dive('db-2', 'perdix', diverId: 'diver-2');
      await source(
        'db-2',
        computerId: 'perdix',
        fileId: 'g',
        fileFormat: 'shearwaterDb',
      );
      expect(await backfill().dbImportComputers(diverId: 'diver-1'), {'teric'});

      await dive('bt-1', 'petrel', diverId: 'diver-1');
      await source('bt-1', computerId: 'petrel', raw: Uint8List(8));
      await tank('bt-1-t', 'bt-1', serial: '180777', sourceIndex: 0);
      await dive('bt-2', 'petrel', diverId: 'diver-2');
      await source('bt-2', computerId: 'petrel', raw: Uint8List(8));
      await tank('bt-2-t', 'bt-2', serial: '180777', sourceIndex: 0);

      expect(await backfill().pendingCount({'petrel'}, diverId: 'diver-1'), 1);
      await backfill().run({'petrel'}, diverId: 'diver-1');
      final s = await slots();
      expect(s['bt-1-t'], 1);
      expect(s['bt-2-t'], isNull);
    },
  );

  test('a file pass with no native parser leaves the file for later', () async {
    await dive('db', 'petrel', maxDepth: 30, runtimeSeconds: 3000);
    final fileId = await ImportedFileRepository().store(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'cloud.db',
    );
    await source(
      'db',
      computerId: 'petrel',
      fileId: fileId,
      fileFormat: 'shearwaterDb',
    );
    await tank('db-t0', 'db', start: 200, end: 100);
    final parser = _ThrowingParser();
    final files = DiveResyncOrchestrator(db: db, parserFor: (_) => parser);

    await TransmitterSlotBackfill(
      parseRaw: fakeParse,
      memo: memo,
      files: files,
    ).run({'petrel'});
    expect(parser.calls, 1);
    expect(memo.done, isNot(contains('file:db')));
  });

  group('a file the parser fails on for another reason is not retried', () {
    for (final (name, error) in [
      ('a platform error', PlatformException(code: 'parse-failed')),
      ('any other error', StateError('corrupt file')),
    ]) {
      test(name, () async {
        await dive('db', 'petrel');
        final fileId = await ImportedFileRepository().store(
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'cloud.db',
        );
        await source(
          'db',
          computerId: 'petrel',
          fileId: fileId,
          fileFormat: 'shearwaterDb',
        );
        await tank('db-t0', 'db', start: 200, end: 100);
        final files = DiveResyncOrchestrator(
          db: db,
          parserFor: (_) => _ThrowingParser(error),
        );

        await TransmitterSlotBackfill(
          parseRaw: fakeParse,
          memo: memo,
          files: files,
        ).run({'petrel'});
        expect(memo.done, contains('file:db'));
      });
    }
  });

  group('the raw pass', () {
    Future<void> download() async {
      await dive('bt', 'perdix');
      await source('bt', computerId: 'perdix', raw: Uint8List(8));
      await tank('bt-t', 'bt', serial: '180777', sourceIndex: 0);
    }

    RawDiveParseFn throwing(Object error) =>
        (v, p, m, raw) async => throw error;

    test('leaves a source for later when the parser is missing on this '
        'platform', () async {
      await download();
      await backfill(
        parse: throwing(PlatformException(code: 'channel-error')),
      ).run({'perdix'});
      expect(memo.done, isNot(contains('raw:src-bt')));
    });

    for (final (name, error) in [
      ('a platform error', PlatformException(code: 'parse-failed')),
      ('any other error', StateError('corrupt bytes')),
    ]) {
      test('marks a source it cannot parse for $name as done', () async {
        await download();
        await backfill(parse: throwing(error)).run({'perdix'});
        expect(memo.done, contains('raw:src-bt'));
        expect((await slots())['bt-t'], isNull);
      });
    }
  });

  test('a second run parses nothing again', () async {
    await dive('bt', 'perdix');
    await source('bt', computerId: 'perdix', raw: Uint8List(8));
    await tank('bt-t', 'bt', serial: '180777', sourceIndex: 0);
    Future<pigeon.ParsedDive> noSlot(
      String v,
      String p,
      int m,
      Uint8List raw,
    ) async {
      parses++;
      return parsedWithSlot(null);
    }

    await backfill(parse: noSlot).run({'perdix'});
    await backfill(parse: noSlot).run({'perdix'});
    expect(parses, 1);
  });

  test('no native parser still runs the file pass', () async {
    await dive('bt', 'petrel');
    await source('bt', computerId: 'petrel', raw: Uint8List(8));
    await tank('bt-t', 'bt', serial: '180777', sourceIndex: 0);
    await cloudDive();
    Future<pigeon.ParsedDive> missing(
      String v,
      String p,
      int m,
      Uint8List raw,
    ) => throw MissingPluginException('no plugin');

    await backfill(parse: missing).run({'petrel'});
    final s = await slots();
    expect(s['cloud-t0'], 0);
    expect(s['bt-t'], isNull);
  });

  test('the shared-preferences memo remembers keys across instances', () async {
    await SharedPrefsSlotBackfillMemo().add(['a', 'b']);
    expect(await SharedPrefsSlotBackfillMemo().load(), {'a', 'b'});
  });
}
