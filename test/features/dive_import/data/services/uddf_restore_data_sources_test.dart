// Restoring `<source>` entries as dive_data_sources rows, losslessly.
//
// Harness copied from test/features/dive_import/uddf_import_source_uuid_test.dart,
// which is the working reference for driving this importer against a real
// in-memory database.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

ImportRepositories buildRepositories() => ImportRepositories(
  tripRepository: TripRepository(),
  equipmentRepository: EquipmentRepository(),
  equipmentSetRepository: EquipmentSetRepository(),
  buddyRepository: BuddyRepository(),
  diveCenterRepository: DiveCenterRepository(),
  certificationRepository: CertificationRepository(),
  tagRepository: TagRepository(),
  diveTypeRepository: DiveTypeRepository(),
  siteRepository: SiteRepository(),
  diveRepository: DiveRepository(),
  tankPressureRepository: TankPressureRepository(),
  courseRepository: CourseRepository(),
  diveComputerRepository: DiveComputerRepository(),
);

Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-restore-sources-test';
  await DiverRepository().createDiver(
    domain.Diver(
      id: diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return diverId;
}

final raw = Uint8List.fromList(List<int>.generate(320, (i) => (i * 7) % 256));

/// A UDDF document with one dive and the given `<source>` entries.
///
/// The dive id carries the `dive_` prefix the real exporter writes, so this
/// fixture exercises the same ref shape a round trip produces.
String buildUddf({String sources = '', String control = ''}) {
  final appData = sources.isEmpty
      ? ''
      : '''
  <applicationdata>
    <submersion version="1.0">
      <datasources>
$sources
      </datasources>
    </submersion>
  </applicationdata>''';
  return '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix1"><name>Air</name><o2>0.21</o2><he>0.00</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive id="dive_DIVE-1">
        <informationbeforedive>
          <datetime>2019-06-02T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>31.5</greatestdepth>
          <diveduration>2400.0</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
$appData
$control
</uddf>''';
}

String entry({
  required int ordinal,
  required bool hasDump,
  required bool primary,
  String computerModel = 'Perdix AI',
  String computerSerial = 'SN-A',
  String importedAt = '2019-06-02T18:41:07.000',
  double maxDepth = 31.5,
  int mergeSourceSlot = 0,
}) {
  return '''        <source diveref="dive_DIVE-1" ordinal="$ordinal" hasdump="$hasDump">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <primary>$primary</primary>
          <mergesourceslot>$mergeSourceSlot</mergesourceslot>
          <computermodel>$computerModel</computermodel>
          <computerserial>$computerSerial</computerserial>
          <importedat>$importedAt</importedat>
          <createdat>$importedAt</createdat>
          <maxdepth>$maxDepth</maxdepth>
        </source>''';
}

String dumpFor(String payload) =>
    '''  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_DIVE-1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''';

void main() {
  late AppDatabase db;
  final importer = UddfEntityImporter();
  final exportService = ExportService();

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> runImport(String xml) async {
    final diverId = await createTestDiver();
    final parsed = await exportService.importAllDataFromUddf(xml);
    await importer.import(
      data: parsed,
      selections: const UddfImportSelections(dives: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  Future<List<DiveDataSourcesData>> sources() => (db.select(
    db.diveDataSources,
  )..orderBy([(t) => OrderingTerm.desc(t.isPrimary)])).get();

  test('restores every source row losslessly, bytes and all', () async {
    // The assertion the whole multi-source design exists to satisfy.
    await runImport(
      buildUddf(
        sources:
            '${entry(ordinal: 0, hasDump: true, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerModel: 'Teric', computerSerial: 'SN-B', maxDepth: 30.9, mergeSourceSlot: 1)}',
        control: dumpFor(UddfDumpCodec.encodeOne(raw)),
      ),
    );

    final rows = await sources();

    expect(rows, hasLength(2));
    expect(rows[0].isPrimary, isTrue);
    expect(rows[1].isPrimary, isFalse);
    expect(rows[0].rawData, equals(raw));
    expect(rows[1].rawData, isNull);
    expect(rows[0].descriptorVendor, 'Shearwater');
    expect(rows[0].descriptorProduct, 'Perdix');
    expect(rows[0].descriptorModel, 5);
    expect(rows[0].mergeSourceSlot, 0);
    expect(rows[1].mergeSourceSlot, 1);
    expect(rows[0].maxDepth, 31.5);
    expect(rows[1].maxDepth, 30.9);
    expect(rows[1].computerModel, 'Teric');
  });

  test('writes no synthesised row alongside the restored ones', () async {
    await runImport(
      buildUddf(sources: entry(ordinal: 0, hasDump: false, primary: true)),
    );

    expect(await sources(), hasLength(1));
  });

  test(
    'a document with no entries keeps the old single row behaviour',
    () async {
      await runImport(buildUddf());

      final rows = await sources();
      expect(rows, hasLength(1));
      expect(rows.single.isPrimary, isTrue);
      expect(rows.single.rawData, isNull);
    },
  );

  test('two entries claiming primary restore exactly one primary', () async {
    await runImport(
      buildUddf(
        sources:
            '${entry(ordinal: 0, hasDump: false, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: true, computerSerial: 'SN-B')}',
      ),
    );

    final rows = await sources();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isPrimary), hasLength(1));
  });

  test('no entry claiming primary promotes the first', () async {
    await runImport(
      buildUddf(
        sources:
            '${entry(ordinal: 0, hasDump: false, primary: false)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerSerial: 'SN-B')}',
      ),
    );

    final rows = await sources();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isPrimary), hasLength(1));
  });

  test('importedAt comes from the entry, not the import clock', () async {
    await runImport(
      buildUddf(sources: entry(ordinal: 0, hasDump: false, primary: true)),
    );

    final rows = await sources();
    expect(
      rows.single.importedAt,
      DateTime.parse('2019-06-02T18:41:07.000'),
      reason:
          'A restore must not relabel a 2019 dive with today, since the data '
          'sources panel shows this value as "Imported".',
    );
  });

  test('each source resolves its own computer from model and serial', () async {
    await runImport(
      buildUddf(
        sources:
            '${entry(ordinal: 0, hasDump: false, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerModel: 'Teric', computerSerial: 'SN-B')}',
      ),
    );

    final rows = await sources();
    final computerIds = rows.map((r) => r.computerId).toSet();
    expect(
      computerIds,
      hasLength(2),
      reason:
          'Two different model plus serial pairs must not collapse onto one '
          'registered computer, and neither may be left unregistered.',
    );
    expect(computerIds.contains(null), isFalse);
  });
}
