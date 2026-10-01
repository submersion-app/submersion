// A dive imported from Subsurface before the importer kept every computer
// holds only the first one. "Resync from original file" re-reads the stored
// .ssrf and adds the computers the dive lacks (issue #2672).

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import '../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../helpers/fake_hosts.dart';
import '../../../helpers/test_database.dart';

const _ssrf = '''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-03-10' time='09:00:00' duration='40:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='32.0%' />
  <divecomputer model='Shearwater Perdix'>
  <depth max='30.0 m' mean='18.0 m' />
  <extradata key='Serial' value='SN-A' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.0 bar' />
  <sample time='10:00 min' depth='30.0 m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='60.0 bar' />
  </divecomputer>
  <divecomputer model='Shearwater Teric'>
  <depth max='30.4 m' mean='18.2 m' />
  <extradata key='Serial' value='SN-B' />
  <sample time='0:00 min' depth='0.0 m' pressure0='201.0 bar' />
  <sample time='10:00 min' depth='30.4 m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='61.0 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
''';

void main() {
  late AppDatabase db;

  setUp(() async {
    serveFakeHost('api.open-meteo.com');
    serveFakeHost('nominatim.openstreetmap.org');
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  /// Imports the file's dive the way the importer did before it kept further
  /// computers, storing the file for resync as a real import does.
  Future<String> importTheOldWay() async {
    final bytes = Uint8List.fromList(utf8.encode(_ssrf));
    final parsed = await SubsurfaceXmlParser().parse(bytes);
    final dive = Map<String, dynamic>.of(
      parsed.entitiesOf(ImportEntityType.dives).single,
    )..remove('additionalComputers');
    await UddfEntityImporter(importedFiles: ImportedFileRepository()).import(
      data: UddfImportResult(dives: [dive]),
      selections: const UddfImportSelections(dives: {0}),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
      sourceFormat: ImportFormat.subsurfaceXml,
      sourceFileBytes: bytes,
      sourceFileName: 'log.ssrf',
    );
    return (await db.select(db.dives).get()).single.id;
  }

  Future<List<DiveDataSourcesData>> sourcesOf(String diveId) =>
      (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
          .get();

  test('resync adds the computer the older import dropped', () async {
    final diveId = await importTheOldWay();
    expect(await sourcesOf(diveId), hasLength(1));

    final outcome = await DiveResyncOrchestrator(db: db).resync(diveId);

    expect(outcome.succeeded, isTrue);
    final rows = await sourcesOf(diveId);
    expect(rows.map((r) => r.computerModel), [
      'Shearwater Perdix',
      'Shearwater Teric',
    ]);
    expect(rows[1].sourceFileName, 'log.ssrf');
    expect(rows[1].sourceFileFormat, 'subsurfaceXml');
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles[rows[0].id]!.points.map((p) => p.depth), [0.0, 30.0, 0.0]);
    expect(profiles[rows[1].id]!.points.map((p) => p.depth), [0.0, 30.4, 0.0]);
  });

  test('a second resync adds nothing more', () async {
    final diveId = await importTheOldWay();

    await DiveResyncOrchestrator(db: db).resync(diveId);
    final again = await DiveResyncOrchestrator(db: db).resync(diveId);

    expect(again.succeeded, isTrue);
    expect(await sourcesOf(diveId), hasLength(2));
  });
}
