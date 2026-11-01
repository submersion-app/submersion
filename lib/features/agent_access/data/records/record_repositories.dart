import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

/// The repositories the record catalogue reads through.
///
/// Built per MCP request, so everything is lazy: a call that reads one entity
/// constructs one repository. Repositories resolve the database through a
/// getter on each use, so a restore or storage move between calls swaps the
/// handle underneath them, and [db] does the same.
class RecordRepositories {
  AppDatabase get db => DatabaseService.instance.database;

  late final buddies = BuddyRepository();
  late final centerGearNotes = DiveCenterGearNoteRepository();
  late final centers = DiveCenterRepository();
  late final computers = DiveComputerRepository();
  late final dives = DiveRepository();
  late final cylinderConfigs = CylinderConfigRepository();
  late final cylinderFills = CylinderFillRepository();
  late final diveScenarios = DiveScenarioRepository();
  late final diveTypes = DiveTypeRepository();
  late final equipment = EquipmentRepository();
  late final equipmentComponents = EquipmentComponentRepository();
  late final equipmentLocationMoves = EquipmentLocationMoveRepository();
  late final equipmentLocations = EquipmentLocationRepository();
  late final equipmentObservations = EquipmentObservationRepository();
  late final equipmentSets = EquipmentSetRepository();
  late final equipmentShares = EquipmentShareRepository();
  late final equipmentTags = EquipmentTagRepository();
  late final itemShares = ItemSharesRepository();
  late final media = MediaRepository();
  late final serviceKinds = ServiceKindRepository();
  late final serviceRecords = ServiceRecordRepository();
  late final serviceSchedules = ServiceScheduleRepository();
  late final siteClassification = SiteClassificationRepository();
  late final siteFeatures = SiteFeatureRepository();
  late final siteTypes = SiteTypeRepository();
  late final sites = SiteRepository();
  late final species = SpeciesRepository();
  late final transmitters = TransmitterRepository();

  DiveCustomFieldRepository get customFields => DiveCustomFieldRepository(db);
}
