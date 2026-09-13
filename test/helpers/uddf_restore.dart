import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/export/models/uddf_import_result.dart';
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
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

/// Imports the dives in a UDDF [xml] document into the current test
/// database for [diverId], the way the import wizard does.
///
/// The wizard parses with [UddfImportParser] and hands the importer nothing
/// but the payload's entity lists, so anything a test fed the importer
/// straight from the parse result could pass here while a real import lost
/// it. Every dive in the file is selected.
Future<void> restoreUddfDives(String xml, {required String diverId}) async {
  final payload = await UddfImportParser().parse(
    Uint8List.fromList(utf8.encode(xml)),
  );
  final dives = payload.entitiesOf(ImportEntityType.dives);
  await UddfEntityImporter().import(
    data: UddfImportResult(dives: dives),
    selections: UddfImportSelections(
      dives: {for (var i = 0; i < dives.length; i++) i},
    ),
    repositories: ImportRepositories(
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
    ),
    diverId: diverId,
  );
}
