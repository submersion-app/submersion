import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

/// Issue #4347: a re-parse writes the transmitter slot the computer reports
/// onto the tank it already stores, as it does the serial.
void main() {
  late AppDatabase db;
  final nowMs = DateTime.utc(2026, 10, 20, 9).millisecondsSinceEpoch;
  const unknownGasMixIndex = 4294967295;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(nowMs),
            notes: const Value(''),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('comp-1'),
            name: const Value('Perdix 2'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('tank-1'),
            diveId: Value('dive-1'),
            computerId: Value('comp-1'),
            o2Percent: Value(32.0),
            hePercent: Value(0.0),
            tankOrder: Value(0),
            sourceTankIndex: Value(0),
            transmitterSerial: Value('180777'),
          ),
        );
  });

  tearDown(() => db.close());

  pigeon.ParsedDive parse() => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 10,
    dateTimeDay: 20,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 20.0,
    avgDepthMeters: 12.0,
    durationSeconds: 2400,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
      pigeon.ProfileSample(timeSeconds: 1200, depthMeters: 20.0),
      pigeon.ProfileSample(timeSeconds: 2400, depthMeters: 0.0),
    ],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: unknownGasMixIndex,
        startPressureBar: 200.0,
        endPressureBar: 80.0,
        transmitterSerial: 180777,
        transmitterSlot: 2,
      ),
    ],
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
    events: const [],
  );

  test('a re-parse writes the reported slot onto the stored tank', () async {
    await ReparseService(db: db).applyParsedUpdate(
      diveId: 'dive-1',
      sourceRowId: 'src-1',
      parsed: parse(),
      descriptorVendor: 'Shearwater',
      descriptorProduct: 'Perdix 2',
      descriptorModel: 0,
      libdivecomputerVersion: null,
    );
    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tank-1'))).getSingle();
    expect(tank.transmitterSlot, 2);
    expect(tank.transmitterSerial, '180777');
  });
}
