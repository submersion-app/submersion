// End-to-end check that a cylinder with no size in a CSV still reaches the
// database with its pressures and gas (#3930): the real CsvPipeline with a
// shipped preset, imported by the real UddfEntityImporter into an in-memory
// AppDatabase.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

import '../../../../../helpers/test_database.dart';

/// The report's dive: 200/80 bar on EAN32 with the given cylinder size cell.
String _subsurfaceCsv({required String size}) =>
    'dive number,date,time,duration [min],maxdepth [m],avgdepth [m],'
    'cylinder size (1) [l],startpressure (1) [bar],endpressure (1) [bar],'
    'o2 (1) [%],he (1) [%],location\n'
    '1,2026-01-01,10:00,40,20,15,$size,200,80,32,0,Test Site\n';

/// Diving Log writes one cylinder's pressures and has no size column at all.
const _divingLogCsv =
    'DiveDate,DiveTime,DiveSite,MaxDepth,Duration,AirTemp,WaterTemp,'
    'Visibility,Notes,Buddy,StartPressure,EndPressure\n'
    '2026-01-01,10:00,Test Site,20,40,28,27,Good,,,200,80\n';

ImportPayload _execute(String csv, String presetId) {
  final pipeline = CsvPipeline();
  final preset = builtInCsvPresets.singleWhere((p) => p.id == presetId);
  return pipeline.execute(
    primaryCsv: pipeline.parse(Uint8List.fromList(utf8.encode(csv))),
    config: ImportConfiguration(
      mappings: preset.mappings,
      entityTypesToImport: preset.supportedEntities,
      sourceApp: preset.sourceApp,
      preset: preset,
    ),
  );
}

ImportRepositories _buildRepositories() {
  return ImportRepositories(
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
  );
}

Map<String, dynamic> _onlyTank(ImportPayload payload) {
  final dive = payload.entitiesOf(ImportEntityType.dives).single;
  final tanks = (dive['tanks'] as List).cast<Map<String, dynamic>>();
  return tanks.single;
}

void main() {
  group('CSV pipeline', () {
    test('a Subsurface cylinder with a blank size keeps its readings', () {
      final payload = _execute(_subsurfaceCsv(size: ''), 'subsurface');

      final tank = _onlyTank(payload);
      expect(tank['volume'], isNull);
      expect(tank['startPressure'], 200.0);
      expect(tank['endPressure'], 80.0);
      expect(tank['gasMix'], const GasMix(o2: 32));
    });

    test('the size is the only difference from a sized cylinder', () {
      final blank = _onlyTank(_execute(_subsurfaceCsv(size: ''), 'subsurface'));
      final sized = _onlyTank(
        _execute(_subsurfaceCsv(size: '12'), 'subsurface'),
      );

      expect(sized['volume'], 12.0);
      expect(blank['startPressure'], sized['startPressure']);
      expect(blank['endPressure'], sized['endPressure']);
      expect(blank['gasMix'], sized['gasMix']);
    });

    test('Diving Log pressures survive having no size column', () {
      final tank = _onlyTank(_execute(_divingLogCsv, 'diving_log'));

      expect(tank['volume'], isNull);
      expect(tank['startPressure'], 200.0);
      expect(tank['endPressure'], 80.0);
    });
  });

  group('import', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
    });

    tearDown(tearDownTestDatabase);

    test('stores a blank-size cylinder with its pressures and gas', () async {
      const diverId = 'diver-csv-unknown-size';
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

      final payload = _execute(_subsurfaceCsv(size: ''), 'subsurface');
      final data = UddfImportResult(
        dives: payload.entitiesOf(ImportEntityType.dives),
        sites: payload.entitiesOf(ImportEntityType.sites),
      );

      final result = await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: _buildRepositories(),
        diverId: diverId,
      );
      expect(result.dives, 1);

      final row = await db.select(db.diveTanks).getSingle();
      expect(row.volume, isNull);
      expect(row.startPressure, 200.0);
      expect(row.endPressure, 80.0);
      expect(row.o2Percent, 32.0);
    });
  });
}
