import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

/// A diver who edited a dive's gas switches owns that list (issue #32): a
/// re-parse rewrites the dive's events, cylinders and pressure as before
/// but leaves every switch row alone. A dive the diver never touched still
/// takes the computer's switches.
void main() {
  late AppDatabase db;
  late ReparseService service;

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    service = ReparseService(db: db);

    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('comp-1'),
            name: const Value('Test Computer'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> seedDive({required bool edited}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(nowMs),
            notes: const Value(''),
            gasSwitchesEdited: Value(edited),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(DateTime.fromMillisecondsSinceEpoch(nowMs)),
            createdAt: Value(DateTime.fromMillisecondsSinceEpoch(nowMs)),
          ),
        );
    for (final (id, index, o2) in [('tank-0', 0, 21.0), ('tank-1', 1, 50.0)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value(id),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              o2Percent: Value(o2),
              hePercent: const Value(0.0),
              tankOrder: Value(index),
              sourceTankIndex: Value(index),
              tankRole: Value(index == 0 ? 'backGas' : 'deco'),
            ),
          );
    }
    // What the computer logged, and the switch the diver added by hand.
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: const Value('gs-dc'),
            diveId: const Value('dive-1'),
            timestamp: const Value(120),
            tankId: const Value('tank-1'),
            computerId: const Value('comp-1'),
            createdAt: Value(nowMs),
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: const Value('gs-mine'),
            diveId: const Value('dive-1'),
            timestamp: const Value(900),
            tankId: const Value('tank-0'),
            createdAt: Value(nowMs),
          ),
        );
  }

  /// Two gases, the second breathed from 120 s: the parse resolves to one
  /// switch at 120 s onto cylinder 1.
  pigeon.ParsedDive parsed() => pigeon.ParsedDive(
    fingerprint: 'test-fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 25.0,
    avgDepthMeters: 14.0,
    durationSeconds: 1200,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0, gasMixIndex: 0),
      pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10.0, gasMixIndex: 0),
      pigeon.ProfileSample(timeSeconds: 120, depthMeters: 25.0, gasMixIndex: 1),
      pigeon.ProfileSample(timeSeconds: 1200, depthMeters: 0.0, gasMixIndex: 1),
    ],
    tanks: [
      pigeon.TankInfo(index: 0, gasMixIndex: 0),
      pigeon.TankInfo(index: 1, gasMixIndex: 1),
    ],
    gasMixes: [
      pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
      pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
    ],
    events: [],
  );

  Future<void> reparse() => service.applyParsedUpdate(
    diveId: 'dive-1',
    sourceRowId: 'src-1',
    parsed: parsed(),
    descriptorVendor: null,
    descriptorProduct: null,
    descriptorModel: null,
    libdivecomputerVersion: null,
  );

  Future<List<GasSwitche>> switches() =>
      (db.select(db.gasSwitches)
            ..where((t) => t.diveId.equals('dive-1'))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<int> tombstones() async => (await (db.select(
    db.deletionLog,
  )..where((t) => t.entityType.equals('gasSwitches'))).get()).length;

  Future<int> staged() async => (await (db.select(
    db.syncRecords,
  )..where((t) => t.entityType.equals('gasSwitches'))).get()).length;

  test('an edited dive keeps its switches through a re-parse', () async {
    await seedDive(edited: true);

    await reparse();

    final rows = await switches();
    expect(rows.map((s) => s.id), ['gs-dc', 'gs-mine']);
    expect(rows.map((s) => s.timestamp), [120, 900]);
    expect(rows.map((s) => s.tankId), ['tank-1', 'tank-0']);
    expect(await tombstones(), 0);
    expect(await staged(), 0);
  });

  test("an unedited dive still takes the computer's switches", () async {
    await seedDive(edited: false);

    await reparse();

    final rows = await switches();
    expect(rows.map((s) => s.id), isNot(contains('gs-mine')));
    expect(rows, hasLength(1));
    expect(rows.single.timestamp, 120);
    expect(rows.single.tankId, 'tank-1');
    expect(rows.single.computerId, 'comp-1');
  });
}
