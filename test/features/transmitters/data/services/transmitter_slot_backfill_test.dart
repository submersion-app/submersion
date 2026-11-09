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
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill_memo.dart';

import '../../../../helpers/test_database.dart';

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
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            transmitterSerial: Value(serial),
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
  }) async {
    await computer(computerId);
    await DiveRepository().createDive(
      domain.Dive(
        id: id,
        dateTime: at ?? DateTime.utc(2026, 3, 12, 9),
        maxDepth: maxDepth,
        runtime: runtimeSeconds == null
            ? null
            : Duration(seconds: runtimeSeconds),
      ),
    );
    await db.customStatement(
      "UPDATE dives SET computer_id = '$computerId' WHERE id = '$id'",
    );
  }

  /// The Shearwater Cloud fixture's dive, stored as a file import with two
  /// slot-less tanks written in file order, as the importer leaves them.
  Future<void> cloudDive({int tanks = 2}) async {
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
    for (var i = 0; i < tanks; i++) {
      await tank('cloud-t$i', 'cloud');
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
