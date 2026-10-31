// Restoring each depth profile under the source that recorded it (issue
// #3965), through the real export reads and the parse the import wizard runs.
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

void main() {
  const diverId = 'diver-restore-source-profiles';
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(
        id: diverId,
        name: 'Test Diver',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  final stamp = DateTime.utc(2026, 3, 1, 12);

  List<domain.DiveProfilePoint> points(List<(int, double)> samples) => [
    for (final (timestamp, depth) in samples)
      domain.DiveProfilePoint(timestamp: timestamp, depth: depth),
  ];

  DiveDataSourcesCompanion reading(
    String id, {
    required bool primary,
    String? computerId,
    String? serial,
    int order = 0,
  }) => DiveDataSourcesCompanion(
    id: Value(id),
    diveId: const Value('dive-a'),
    isPrimary: Value(primary),
    computerId: Value(computerId),
    computerModel: Value(serial == null ? null : 'Perdix'),
    computerSerial: Value(serial),
    sourceFileName: Value('$id.uddf'),
    importedAt: Value(stamp),
    createdAt: Value(stamp.add(Duration(seconds: order))),
  );

  Future<void> seedDive(
    List<(int, double)> primarySamples, {
    List<domain.DiveTank> tanks = const [],
  }) async {
    await repository.createDive(
      domain.Dive(
        id: 'dive-a',
        diveNumber: 1,
        diverId: diverId,
        dateTime: DateTime.utc(2026, 3, 1, 9),
        tanks: tanks,
        profile: points(primarySamples),
      ),
    );
  }

  Future<String> registerComputer(String serial) async {
    final computer = await DiveComputerRepository().createComputer(
      domain.DiveComputer(
        id: '',
        name: serial,
        model: 'Perdix',
        serialNumber: serial,
        diverId: diverId,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    return computer.id;
  }

  /// A full backup of the logbook, read the way the app reads it.
  Future<String> backup({
    Map<String, List<GasSwitchWithTank>>? gasSwitches,
  }) async {
    final dives = await attachMergedProfiles(
      repository,
      await repository.getAllDives(diverId: diverId),
    );
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: dives,
      diveGasSwitches: gasSwitches,
      dataSources: await repository.getSourcesForExport([
        for (final dive in dives) dive.id,
      ]),
    );
  }

  Future<String> restoredDiveId() async {
    final rows = await db.select(db.dives).get();
    return rows.singleWhere((row) => row.id != 'dive-a').id;
  }

  /// Each restored source's samples as `seconds:metres`, by its file name.
  Future<Map<String?, String>> restoredProfiles() async {
    final diveId = await restoredDiveId();
    final names = {
      for (final row in await (db.select(
        db.diveDataSources,
      )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
        row.id: row.sourceFileName,
    };
    final profiles = await repository.getProfilesByDataSource(diveId);
    return {
      for (final entry in profiles.entries)
        names[entry.key]: [
          for (final p in entry.value.points) '${p.timestamp}:${p.depth}',
        ].join(' '),
    };
  }

  test('each restored file import owns its own samples', () async {
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    await repository.saveComputerReading(reading('src-a', primary: true));
    await repository.saveAdditionalComputerReading(
      reading: reading('src-b', primary: false, order: 1),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );

    final xml = await backup();
    await restoreUddfDives(xml, diverId: diverId);

    expect(await restoredProfiles(), {
      'src-a.uddf': '0:0.0 30:10.0 60:0.0',
      'src-b.uddf': '10:0.0 40:20.0 70:0.0',
    });
  });

  test('each restored computer owns its own samples', () async {
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );

    await restoreUddfDives(await backup(), diverId: diverId);

    expect(await restoredProfiles(), {
      'src-a.uddf': '0:0.0 30:10.0 60:0.0',
      'src-b.uddf': '10:0.0 40:20.0 70:0.0',
    });
    final diveId = await restoredDiveId();
    final series = await ProfileSeriesRepository().getSeriesForDive(diveId);
    final sources = await repository.getProfilesByDataSource(diveId);
    final primary = series.singleWhere((s) => s.isPrimary);
    final other = series.singleWhere((s) => !s.isPrimary);
    // Each keeps the computer it was exported with: the imported primary
    // series named none, and the other its restored computer.
    expect(primary.computerId, isNull);
    expect(other.computerId, sources[other.sourceId]!.computerId);
    expect(other.computerId, isNotNull);
  });

  test('every field of a sample survives the round trip', () async {
    const sample = domain.DiveProfilePoint(
      timestamp: 12,
      depth: 21.37,
      temperature: 15.2,
      heartRate: 71,
      heartRateSource: 'watch',
      heading: 181.5,
      setpoint: 1.2,
      ppO2: 1.19,
      o2Sensor1: 1.1,
      o2Sensor2: 1.2,
      o2Sensor3: 1.3,
      o2SensorMv1: 45,
      o2SensorMv2: 46,
      o2SensorMv3: 47,
      cns: 7.5,
      ndl: 900,
      ceiling: 3.2,
      ascentRate: 8.1,
      rbt: 1200,
      decoType: 2,
      tts: 300,
      gf99: 55,
      n2Load: 40,
    );
    await seedDive([(0, 0), (30, 10)]);
    await repository.saveComputerReading(reading('src-a', primary: true));
    await repository.saveAdditionalComputerReading(
      reading: reading('src-b', primary: false, order: 1),
      profile: const [sample],
    );

    await restoreUddfDives(await backup(), diverId: diverId);

    final diveId = await restoredDiveId();
    final profiles = await repository.getProfilesByDataSource(diveId);
    expect(profiles.values.last.points, const [sample]);
  });

  test('an edited primary restores as the edit alone', () async {
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );
    await repository.saveEditedProfile(
      'dive-a',
      points([(0, 0), (30, 9), (60, 0)]),
    );

    await restoreUddfDives(await backup(), diverId: diverId);

    expect(await restoredProfiles(), {
      'src-a.uddf': '0:0.0 30:9.0 60:0.0',
      'src-b.uddf': '10:0.0 40:20.0 70:0.0',
    });
  });

  test('each gas switch keeps the computer that logged it', () async {
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await seedDive(
      [(0, 0), (30, 10), (60, 0)],
      tanks: const [
        domain.DiveTank(id: 'tank-1', gasMix: domain.GasMix(o2: 32)),
      ],
    );
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );
    GasSwitch gasSwitch(String id, int timestamp, String? computerId) =>
        GasSwitch(
          id: id,
          diveId: 'dive-a',
          timestamp: timestamp,
          tankId: 'tank-1',
          createdAt: stamp,
          computerId: computerId,
        );
    await repository.insertGasSwitches([
      // The same second on both computers, and one on neither.
      gasSwitch('gs-a', 20, first),
      gasSwitch('gs-b', 20, second),
      gasSwitch('gs-c', 25, null),
    ]);

    final xml = await backup(
      gasSwitches: {'dive-a': await repository.getGasSwitchesForDive('dive-a')},
    );
    await restoreUddfDives(xml, diverId: diverId);

    final restored = await repository.getGasSwitchesForDive(
      await restoredDiveId(),
    );
    expect(
      {
        for (final s in restored)
          (s.gasSwitch.timestamp, s.gasSwitch.computerId),
      },
      {(20, first), (20, second), (25, null)},
    );
    expect(restored, hasLength(3));
  });

  test('a series naming no source restores naming none', () async {
    await seedDive([(0, 0), (30, 10)]);
    await repository.saveComputerReading(reading('src-a', primary: true));
    await repository.saveAdditionalComputerReading(
      reading: reading('src-b', primary: false, order: 1),
      profile: points([(10, 0), (40, 20)]),
    );
    // A Combine's surface filler: no computer and no source.
    await ProfileSeriesRepository().insertSeries(
      diveId: 'dive-a',
      samples: const [ProfileSample(timestamp: 100, depth: 0)],
    );

    await restoreUddfDives(await backup(), diverId: diverId);

    final diveId = await restoredDiveId();
    final series = await ProfileSeriesRepository().getSeriesForDive(diveId);
    expect(series, hasLength(3));
    expect(
      series.singleWhere((s) => s.samples.first.timestamp == 100).sourceId,
      isNull,
    );
  });

  test('a series write that fails keeps the merged samples', () async {
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );

    final xml = await backup();
    // Refuses a series with a source, which only the restored ones have.
    await db.customStatement('''
      CREATE TRIGGER refuse_owned_series
      BEFORE INSERT ON dive_profile_series
      WHEN NEW.source_id IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'series write failed'); END
    ''');
    await restoreUddfDives(xml, diverId: diverId);

    final merged = await repository.getMergedProfile(await restoredDiveId());
    expect(merged.map((p) => p.timestamp), [0, 10, 30, 40, 60, 70]);
  });

  test('a single source restores as it always has', () async {
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    await repository.saveComputerReading(reading('src-a', primary: true));

    await restoreUddfDives(await backup(), diverId: diverId);

    expect(await restoredProfiles(), {'src-a.uddf': '0:0.0 30:10.0 60:0.0'});
  });

  test('an older backup without the block keeps its samples', () async {
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );

    final xml = await backup();
    final older = xml.replaceAll(
      RegExp(r'<sourceprofiles>.*</sourceprofiles>', dotAll: true),
      '',
    );
    expect(older, isNot(contains('<sourceprofiles>')));
    await restoreUddfDives(older, diverId: diverId);

    // Which source recorded what was never in such a file, so the merged
    // samples stay whole rather than being dropped.
    final diveId = await restoredDiveId();
    final merged = await repository.getMergedProfile(diveId);
    expect(merged.map((p) => p.timestamp), [0, 10, 30, 40, 60, 70]);
  });

  test('one unreadable series falls back to the merged samples', () async {
    await seedDive([(0, 0), (30, 10), (60, 0)]);
    final first = await registerComputer('111');
    final second = await registerComputer('222');
    await repository.saveComputerReading(
      reading('src-a', primary: true, computerId: first, serial: '111'),
    );
    await repository.saveAdditionalComputerReading(
      reading: reading(
        'src-b',
        primary: false,
        computerId: second,
        serial: '222',
        order: 1,
      ),
      profile: points([(10, 0), (40, 20), (70, 0)]),
    );

    final xml = await backup();
    var seen = 0;
    final damaged = xml.replaceAllMapped(
      RegExp(r'(<series [^>]*primary="false"[^>]*>)[^<]+(</series>)'),
      (match) {
        seen++;
        return '${match[1]}not-a-series${match[2]}';
      },
    );
    expect(seen, 1);
    await restoreUddfDives(damaged, diverId: diverId);

    final diveId = await restoredDiveId();
    final merged = await repository.getMergedProfile(diveId);
    expect(merged.map((p) => p.timestamp), [0, 10, 30, 40, 60, 70]);
  });
}
