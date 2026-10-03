import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Replace Source on a dive more than one computer recorded (issue #2582):
/// only the re-imported computer's reading is refreshed. The other
/// computers' tank pressure series, events and gas switches stay, and each
/// computer keeps its primary or secondary role.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repo;

  final start = DateTime(2026, 6, 1, 9, 0);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveComputerRepository();
    for (final id in const ['comp-a', 'comp-b']) {
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, created_at, updated_at) '
        "VALUES (?, ?, 1, 1)",
        [id, id],
      );
    }
  });
  tearDown(() => tearDownTestDatabase());

  List<ProfilePointData> points(double startBar) => [
    ProfilePointData(timestamp: 0, depth: 0, pressure: startBar, tankIndex: 0),
    ProfilePointData(
      timestamp: 600,
      depth: 20,
      pressure: startBar - 50,
      tankIndex: 0,
    ),
    ProfilePointData(
      timestamp: 1200,
      depth: 5,
      pressure: startBar - 80,
      tankIndex: 0,
    ),
  ];

  /// Computer A logs the dive first, so it is the primary reading.
  Future<String> downloadA({bool isPrimary = true}) => repo.importProfile(
    computerId: 'comp-a',
    profileStartTime: start,
    points: points(200),
    durationSeconds: 1800,
    maxDepth: 20,
    isPrimary: isPrimary,
    tanks: const [TankData(index: 0, o2Percent: 21)],
    events: const [EventData(timestamp: 300, type: 'safetystop')],
    gasSwitches: const [GasSwitchData(timestamp: 0, depth: 0, toTankIndex: 0)],
    addMissingTanks: true,
  );

  /// Computer B's reading of the same dive, on its own EAN32 cylinder, the
  /// way a replace-source re-import attaches it.
  Future<String> downloadB({bool isPrimary = false}) => repo.importProfile(
    computerId: 'comp-b',
    profileStartTime: start,
    points: points(210),
    durationSeconds: 1800,
    maxDepth: 20,
    isPrimary: isPrimary,
    tanks: const [TankData(index: 0, o2Percent: 32)],
    events: const [EventData(timestamp: 900, type: 'safetystop')],
    gasSwitches: const [GasSwitchData(timestamp: 0, depth: 0, toTankIndex: 0)],
    addMissingTanks: true,
  );

  /// A two-computer dive: A primary, B secondary on its own tank.
  Future<String> twoComputerDive() async {
    final diveId = await downloadA();
    expect(await downloadB(), diveId, reason: 'B matches A\'s dive');
    return diveId;
  }

  Future<String> tankOf(String diveId, String computerId) async =>
      (await (db.select(db.diveTanks)..where(
                (t) =>
                    t.diveId.equals(diveId) & t.computerId.equals(computerId),
              ))
              .getSingle())
          .id;

  Future<List<TankPressureSeriesRow>> tankSeries(String diveId) => (db.select(
    db.tankPressureSeries,
  )..where((t) => t.diveId.equals(diveId))).get();

  Future<List<DiveProfileEvent>> events(String diveId) => (db.select(
    db.diveProfileEvents,
  )..where((t) => t.diveId.equals(diveId))).get();

  Future<List<GasSwitche>> switches(String diveId) =>
      (db.select(db.gasSwitches)..where((t) => t.diveId.equals(diveId))).get();

  /// Replace Source as DiveImportService runs it: clear, then re-import with
  /// the role the cleared reading held.
  Future<void> replace(
    String diveId,
    String computerId,
    Future<String> Function({bool isPrimary}) download,
  ) async {
    final wasPrimary = await repo.clearSourceAndProfiles(
      diveId: diveId,
      computerId: computerId,
    );
    expect(await download(isPrimary: wasPrimary), diveId);
  }

  test('gas switches carry the computer that recorded them', () async {
    final diveId = await twoComputerDive();

    final rows = await switches(diveId);
    expect(
      rows.map((s) => s.computerId),
      unorderedEquals(['comp-a', 'comp-b']),
    );
    for (final s in rows) {
      expect(s.tankId, await tankOf(diveId, s.computerId!));
    }
  });

  group('replacing a secondary computer', () {
    test(
      'keeps the other computer\'s pressure, events and gas switches',
      () async {
        final diveId = await twoComputerDive();
        final aTank = await tankOf(diveId, 'comp-a');
        final aSeries = (await tankSeries(
          diveId,
        )).singleWhere((s) => s.computerId == 'comp-a');
        final aEvent = (await events(
          diveId,
        )).singleWhere((e) => e.computerId == 'comp-a');
        final aSwitch = (await switches(
          diveId,
        )).singleWhere((s) => s.computerId == 'comp-a');

        await replace(diveId, 'comp-b', downloadB);

        final series = await tankSeries(diveId);
        expect(series.where((s) => s.computerId == 'comp-a').map((s) => s.id), [
          aSeries.id,
        ]);
        expect(aSeries.tankId, aTank);
        expect(
          (await events(
            diveId,
          )).where((e) => e.computerId == 'comp-a').map((e) => e.id),
          [aEvent.id],
        );
        expect(
          (await switches(
            diveId,
          )).where((s) => s.computerId == 'comp-a').map((s) => s.id),
          [aSwitch.id],
        );
      },
    );

    test('refreshes its own reading once, onto its own tank', () async {
      final diveId = await twoComputerDive();
      final bTank = await tankOf(diveId, 'comp-b');

      await replace(diveId, 'comp-b', downloadB);

      final bSeries = (await tankSeries(
        diveId,
      )).where((s) => s.computerId == 'comp-b').toList();
      expect(bSeries, hasLength(1));
      expect(bSeries.single.tankId, bTank);
      expect(
        (await events(diveId)).where((e) => e.computerId == 'comp-b'),
        hasLength(1),
      );
      final bSwitches = (await switches(
        diveId,
      )).where((s) => s.computerId == 'comp-b').toList();
      expect(bSwitches, hasLength(1));
      expect(bSwitches.single.tankId, bTank);
    });

    test('stays secondary, leaving one primary reading', () async {
      final diveId = await twoComputerDive();

      await replace(diveId, 'comp-b', downloadB);

      final profiles = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(profiles.where((p) => p.isPrimary).map((p) => p.computerId), [
        'comp-a',
      ]);
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources.where((s) => s.isPrimary).map((s) => s.computerId), [
        'comp-a',
      ]);
    });

    test('tombstones only its own events and gas switches', () async {
      final diveId = await twoComputerDive();
      final bSwitch = (await switches(
        diveId,
      )).singleWhere((s) => s.computerId == 'comp-b');

      await repo.clearSourceAndProfiles(diveId: diveId, computerId: 'comp-b');

      final log = await db.select(db.deletionLog).get();
      expect(
        [
          for (final t in log)
            if (t.entityType == EventScopeTombstone.entityType) t.recordId,
        ],
        [EventScopeTombstone(diveId: diveId, computerId: 'comp-b').encode()],
      );
      expect(
        [
          for (final t in log)
            if (t.entityType == 'gasSwitches') t.recordId,
        ],
        [bSwitch.id],
      );
    });
  });

  group('replacing the primary computer', () {
    test('does not duplicate a switch the v258 backfill left unattributed '
        'on its cylinder', () async {
      final diveId = await twoComputerDive();
      final aTank = await tankOf(diveId, 'comp-a');
      // A switch to the primary's cylinder could have been either
      // computer's, so the backfill left it without one.
      await db.customStatement(
        "UPDATE gas_switches SET computer_id = NULL WHERE computer_id = 'comp-a'",
      );

      await replace(diveId, 'comp-a', downloadA);

      final onATank = (await switches(
        diveId,
      )).where((s) => s.tankId == aTank).toList();
      expect(onATank, hasLength(1));
      expect(onATank.single.computerId, isNull);
    });

    test('restores the role a replace before #2582 left on its series '
        'alone', () async {
      final diveId = await twoComputerDive();
      // The old Replace Source of the primary kept its series primary but
      // wrote its source row secondary.
      await db.customStatement(
        'UPDATE dive_data_sources SET is_primary = 0 WHERE dive_id = ?',
        [diveId],
      );

      await replace(diveId, 'comp-a', downloadA);

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources.where((s) => s.isPrimary).map((s) => s.computerId), [
        'comp-a',
      ]);
      final profiles = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(profiles.where((p) => p.isPrimary).map((p) => p.computerId), [
        'comp-a',
      ]);
    });

    test('keeps it primary and the secondary\'s reading intact', () async {
      final diveId = await twoComputerDive();
      final bSeries = (await tankSeries(
        diveId,
      )).singleWhere((s) => s.computerId == 'comp-b');

      await replace(diveId, 'comp-a', downloadA);

      final profiles = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(profiles.where((p) => p.isPrimary).map((p) => p.computerId), [
        'comp-a',
      ]);
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources.where((s) => s.isPrimary).map((s) => s.computerId), [
        'comp-a',
      ]);
      expect(
        (await tankSeries(
          diveId,
        )).where((s) => s.computerId == 'comp-b').map((s) => s.id),
        [bSeries.id],
      );
      expect(
        (await events(diveId)).where((e) => e.computerId == 'comp-b'),
        hasLength(1),
      );
    });
  });

  test('a reading asking for primary on a dive that already has one is '
      'secondary, series and source row alike', () async {
    final diveId = await downloadA();

    expect(await downloadB(isPrimary: true), diveId);

    final profiles = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(profiles.where((p) => p.isPrimary).map((p) => p.computerId), [
      'comp-a',
    ]);
  });

  test('a reading whose summary-only source row survives on a dive with no '
      'series takes that row\'s role', () async {
    final diveId = await downloadA();
    // A's samples gone, its primary summary row kept, and a secondary
    // summary-only row for B, as a restore without samples can leave.
    await db.customStatement(
      'DELETE FROM dive_profile_series WHERE dive_id = ?',
      [diveId],
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: Value(diveId),
            computerId: const Value('comp-b'),
            isPrimary: const Value(false),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(DateTime(2026)),
            createdAt: Value(DateTime(2026)),
          ),
        );

    expect(await downloadB(isPrimary: true), diveId);

    final profiles = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(profiles.single.computerId, 'comp-b');
    expect(profiles.single.isPrimary, isFalse);
    final sources = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(sources.where((s) => s.isPrimary).map((s) => s.computerId), [
      'comp-a',
    ]);
  });

  test('a single-computer dive still clears every event and gas switch of '
      'the dive', () async {
    final diveId = await downloadA();
    // A switch a pre-v258 database left without a computer.
    await db.customStatement(
      'UPDATE gas_switches SET computer_id = NULL WHERE dive_id = ?',
      [diveId],
    );

    await replace(diveId, 'comp-a', downloadA);

    expect(await switches(diveId), hasLength(1));
    expect(await events(diveId), hasLength(1));
    expect(await tankSeries(diveId), hasLength(1));
  });
}
