// Re-importing a Subsurface logbook whose dives were imported before the
// importer kept every computer, with the duplicates set to Consolidate: each
// older dive gains the computers it lacks, and no second copy is left behind
// (issue #2672). A fold alone is refused here, because both copies share the
// first computer.

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/missing_computer_attacher.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart';

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
  <sample time='0:00 min' depth='0.0 m' />
  <sample time='10:00 min' depth='30.0 m' />
  <sample time='40:00 min' depth='0.0 m' />
  </divecomputer>
  <divecomputer model='Shearwater Teric'>
  <depth max='30.4 m' mean='18.2 m' />
  <extradata key='Serial' value='SN-B' />
  <sample time='0:00 min' depth='0.0 m' />
  <sample time='10:00 min' depth='30.4 m' />
  <sample time='40:00 min' depth='0.0 m' />
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

  test('Consolidate gives the older dive its second computer', () async {
    final payload = await SubsurfaceXmlParser().parse(
      Uint8List.fromList(utf8.encode(_ssrf)),
    );
    final dive = payload.entitiesOf(ImportEntityType.dives).single;
    final diverId = await createTestDiver();

    // The dive as the importer stored it before it kept every computer.
    final old = Map<String, dynamic>.of(dive)..remove('additionalComputers');
    final oldData = UddfImportResult(dives: [old]);
    await UddfEntityImporter().import(
      data: oldData,
      selections: UddfImportSelections.selectAll(oldData),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final existingId = (await db.select(db.dives).get()).single.id;

    // The re-import: Consolidate-flagged dives are imported standalone first.
    final newData = UddfImportResult(dives: [dive]);
    final imported = await UddfEntityImporter().import(
      data: newData,
      selections: UddfImportSelections.selectAll(newData),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final attacher = MissingComputerAttacher(db: db);
    final summary = await performConsolidations(
      indices: {0},
      diveIdByIndex: imported.diveIdByIndex,
      duplicateResult: ImportDuplicateResult(
        diveMatches: {
          0: DiveMatchResult(diveId: existingId, score: 1, timeDifferenceMs: 0),
        },
      ),
      consolidationService: DiveConsolidationService(DiveRepository()),
      diveRepository: DiveRepository(),
      attachMissingComputers: (index, targetDiveId) => attacher.attachToMatch(
        targetDiveId: targetDiveId,
        diveData: dive,
        sourceFileName: 'log.ssrf',
        sourceFileFormat: 'subsurfaceXml',
      ),
    );

    expect(summary.consolidated, 1);
    expect(summary.failed, 0);
    final dives = await DiveRepository().getAllDives();
    expect(dives.map((d) => d.id), [existingId]);
    final sources =
        await (db.select(db.diveDataSources)
              ..where((t) => t.diveId.equals(existingId))
              ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
            .get();
    expect(sources.map((s) => s.computerModel), [
      'Shearwater Perdix',
      'Shearwater Teric',
    ]);
  });
}
