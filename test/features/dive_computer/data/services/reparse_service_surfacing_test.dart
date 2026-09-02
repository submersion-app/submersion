import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

/// Issue #1092: reparsing stored raw bytes is how an already-imported dive
/// picks up the surfacing-pressure rule, so it has to honor the same setting
/// the live download does.
void main() {
  late AppDatabase db;

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
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
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('source-1'),
            diveId: const Value('dive-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(DateTime.fromMillisecondsSinceEpoch(nowMs)),
            createdAt: Value(DateTime.fromMillisecondsSinceEpoch(nowMs)),
          ),
        );
  });

  tearDown(() => db.close());

  /// The dive from the issue report: an oxygen cylinder reading 41 bar at
  /// 1.2 m, bled to 4 bar by the time the recording stops on the surface.
  pigeon.ParsedDive bleedingOxygenDive() => pigeon.ParsedDive(
    fingerprint: 'test-fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 51.0,
    avgDepthMeters: 30.0,
    durationSeconds: 4140,
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0)],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: 0,
        startPressureBar: 200.0,
        endPressureBar: 4.0,
      ),
    ],
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 3970,
        depthMeters: 1.2,
        pressureBar: 41.0,
        tankIndex: 0,
      ),
      pigeon.ProfileSample(
        timeSeconds: 4140,
        depthMeters: 0.0,
        pressureBar: 4.0,
        tankIndex: 0,
      ),
    ],
    events: const [],
  );

  Future<double?> reparseAndReadEndPressure({required bool trim}) async {
    final service = ReparseService(db: db, trimTankPressureAtSurfacing: trim);
    await service.applyParsedUpdate(
      diveId: 'dive-1',
      sourceRowId: 'source-1',
      parsed: bleedingOxygenDive(),
      descriptorVendor: 'Shearwater',
      descriptorProduct: 'Petrel 3',
      descriptorModel: 42,
      libdivecomputerVersion: '0.9.0',
    );
    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('dive-1'))).getSingle();
    return tank.endPressure;
  }

  test('reparse records the end pressure at surfacing', () async {
    expect(await reparseAndReadEndPressure(trim: true), 41.0);
  });

  test(
    'reparse keeps the computer end pressure when trimming is off',
    () async {
      expect(await reparseAndReadEndPressure(trim: false), 4.0);
    },
  );
}
