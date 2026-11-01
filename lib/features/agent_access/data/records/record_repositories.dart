import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
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
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

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
  late final diveScenarios = DiveScenarioRepository();
  late final diveTypes = DiveTypeRepository();
  late final itemShares = ItemSharesRepository();
  late final media = MediaRepository();
  late final siteClassification = SiteClassificationRepository();
  late final siteFeatures = SiteFeatureRepository();
  late final siteTypes = SiteTypeRepository();
  late final sites = SiteRepository();
  late final species = SpeciesRepository();

  DiveCustomFieldRepository get customFields => DiveCustomFieldRepository(db);
}
