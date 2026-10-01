import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import '../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../helpers/fake_hosts.dart';
import '../../helpers/test_database.dart';

/// A Subsurface dive worn with two computers imports as one dive with a
/// source per computer, each with its own profile, pressures and events,
/// asserted through the reads the dive page makes (issue #2672).
void main() {
  late AppDatabase db;

  // The code under test calls Open-Meteo and Nominatim; it answers as
  // offline, as it would on a device without a network.
  setUp(() async {
    serveFakeHost('api.open-meteo.com');
    serveFakeHost('nominatim.openstreetmap.org');
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  String computer({
    required String model,
    String? serial,
    double maxDepth = 30.0,
    double startPressure = 200.0,
    String bookmark = '20:00 min',
    String attributes = '',
  }) =>
      '''
  <divecomputer model='$model'$attributes>
  <depth max='$maxDepth m' mean='18.0 m' />
  <temperature water='22.0 C' />
  ${serial == null ? '' : "<extradata key='Serial' value='$serial' />"}
  <event time='$bookmark' type='8' name='bookmark' />
  <sample time='0:00 min' depth='0.0 m' pressure0='$startPressure bar' />
  <sample time='10:00 min' depth='$maxDepth m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='${startPressure - 140} bar' />
  </divecomputer>''';

  Future<String> importDive(String computers) async {
    final xml =
        '''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-03-10' time='09:00:00' duration='40:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='32.0%' />
$computers
</dive>
</dives>
</divelog>
''';
    final payload = await SubsurfaceXmlParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    // The mapping `UniversalAdapter` applies to a parser payload.
    final data = UddfImportResult(
      dives: payload.entitiesOf(ImportEntityType.dives),
    );
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final dives = await DiveRepository().getAllDives();
    return dives.single.id;
  }

  Future<List<DiveDataSourcesData>> sourcesOf(String diveId) =>
      (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
          .get();

  final twoComputers =
      '${computer(model: 'Shearwater Perdix', serial: 'SN-A')}\n'
      '${computer(model: 'Shearwater Teric', serial: 'SN-B', maxDepth: 30.4, startPressure: 201.0, bookmark: '21:00 min')}';

  test('writes one source per computer, the first primary', () async {
    final diveId = await importDive(twoComputers);

    final rows = await sourcesOf(diveId);
    expect(rows, hasLength(2));
    expect(rows[0].isPrimary, isTrue);
    expect(rows[0].computerModel, 'Shearwater Perdix');
    expect(rows[0].computerSerial, 'SN-A');
    expect(rows[1].isPrimary, isFalse);
    expect(rows[1].computerModel, 'Shearwater Teric');
    expect(rows[1].computerSerial, 'SN-B');
    expect(rows[1].maxDepth, 30.4);
    expect(rows[1].sourceFileFormat, rows[0].sourceFileFormat);
    // Each computer is registered and linked to its own row.
    expect(rows[0].computerId, isNotNull);
    expect(rows[1].computerId, isNotNull);
    expect(rows[1].computerId, isNot(rows[0].computerId));
    expect(await DiveRepository().hasMultipleDataSources(diveId), isTrue);
  });

  test('gives each computer its own profile on the dive page', () async {
    final diveId = await importDive(twoComputers);

    final rows = await sourcesOf(diveId);
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles.keys, unorderedEquals(rows.map((r) => r.id)));
    expect(profiles[rows[0].id]!.points.map((p) => p.depth), [0.0, 30.0, 0.0]);
    expect(profiles[rows[1].id]!.points.map((p) => p.depth), [0.0, 30.4, 0.0]);

    final sources = await DiveRepository().getDataSources(diveId);
    expect(usesPerSourceRendering(sources, profiles.values), isTrue);

    // The primary profile stays the first computer's alone.
    final primary = await DiveRepository().getDiveProfile(diveId);
    expect(primary.map((p) => p.depth), [0.0, 30.0, 0.0]);
  });

  test('keeps the second computer its own tank pressures', () async {
    final diveId = await importDive(twoComputers);

    final rows = await sourcesOf(diveId);
    final repository = TankPressureRepository();
    Future<List<double>> pressuresFor(DiveDataSourcesData row) async {
      final byTank = await repository.getTankPressuresForComputer(
        diveId,
        row.computerId,
        sourceId: row.id,
      );
      return byTank.values.single.map((p) => p.pressure).toList();
    }

    expect((await pressuresFor(rows[0])).first, 200.0);
    expect((await pressuresFor(rows[1])).first, 201.0);
    expect((await pressuresFor(rows[1])).last, 61.0);
  });

  test('attributes the second computer\'s events to it', () async {
    final diveId = await importDive(twoComputers);

    final rows = await sourcesOf(diveId);
    final events = await DiveComputerRepository().getEventsForDive(diveId);
    final byTime = {for (final e in events) e.timestamp: e};
    expect(byTime.keys, unorderedEquals([1200, 1260]));
    expect(byTime[1200]!.computerId, isNull);
    expect(byTime[1260]!.computerId, rows[1].computerId);
  });

  test('re-bases a computer whose clock started later', () async {
    final diveId = await importDive(
      '${computer(model: 'Shearwater Perdix', serial: 'SN-A')}\n'
      '${computer(model: 'Shearwater Teric', serial: 'SN-B', attributes: " date='2025-03-10' time='09:01:30'")}',
    );

    final rows = await sourcesOf(diveId);
    expect(rows[1].timeOffsetSeconds, 90);
    expect(
      rows[1].entryTime!.difference(rows[0].entryTime!),
      const Duration(seconds: 90),
    );
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles[rows[1].id]!.points.map((p) => p.timestamp), [
      90,
      690,
      2490,
    ]);
    final events = await DiveComputerRepository().getEventsForDive(diveId);
    expect(
      events.where((e) => e.computerId == rows[1].computerId).single.timestamp,
      1290,
    );
  });

  test('two computers of one model with no serial stay apart', () async {
    // Both resolve to the same registry entry, and two rows sharing a
    // computer collapse into one source on read. The second must not.
    final diveId = await importDive(
      '${computer(model: 'Shearwater Perdix')}\n'
      '${computer(model: 'Shearwater Perdix', maxDepth: 30.4)}',
    );

    final rows = await sourcesOf(diveId);
    expect(rows, hasLength(2));
    expect(rows[1].computerId, isNull);
    expect(await DiveRepository().hasMultipleDataSources(diveId), isTrue);
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles, hasLength(2));
  });

  test('a dive with one computer keeps a single source', () async {
    final diveId = await importDive(
      computer(model: 'Shearwater Perdix', serial: 'SN-A'),
    );

    expect(await sourcesOf(diveId), hasLength(1));
  });
}
