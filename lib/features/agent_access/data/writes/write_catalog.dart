import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/annotation_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/buddy_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/center_gear_note_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/center_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/custom_certification_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/custom_field_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/cylinder_config_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/cylinder_fill_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_role_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_type_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_component_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_location_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_observation_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_set_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/gas_switch_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/preset_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/scenario_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/sighting_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_type_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/species_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/tag_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_kind_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_record_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_schedule_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/transmitter_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/certification_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_template_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/course_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/media_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/pre_dive_session_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/rule_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/saved_view_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/safety_finding_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/safety_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_computer_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_feature_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/track_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/pre_dive_template_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/currency_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_series_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/diver_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/document_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/smart_album_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_checklist_part_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/weight_entry_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_checklist_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_cylinder_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_day_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/weight_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';

/// Every entity an agent can change, by the read catalogue's names.
class WriteCatalog {
  /// [refreshReminders] re-arms an item's service reminders after a write
  /// to its clocks or history, as the service dialogs do.
  WriteCatalog(
    RecordRepositories repositories, {
    LibraryEditStamper? stamper,
    GearReminderRefresh? refreshReminders,
    ConditionFindingsRefresh? refreshFindings,
    DocumentRearm? rearmDocuments,
  }) : all = _entries(
         repositories,
         stamper,
         refreshReminders,
         refreshFindings,
         rearmDocuments,
       );

  /// A catalog of exactly [entries], for a test that swaps one writer.
  @visibleForTesting
  WriteCatalog.of(List<WritableEntry> entries)
    : all = List.unmodifiable(entries);

  /// Built per request, so the row writers share one repository.
  static List<WritableEntry> _entries(
    RecordRepositories repositories,
    LibraryEditStamper? stamper,
    GearReminderRefresh? refreshReminders,
    ConditionFindingsRefresh? refreshFindings,
    DocumentRearm? rearmDocuments,
  ) {
    final rows = DiveChildRowRepository();
    return List.unmodifiable(<WritableEntry>[
      DiveWrites(repositories),
      BuddyWrites(repositories),
      SiteWrites(repositories, stamper: stamper),
      TankWrites(rows: rows),
      WeightWrites(rows: rows),
      SightingWrites(repositories),
      CustomFieldWrites(rows: rows),
      GasSwitchWrites(repositories),
      AnnotationWrites(repositories),
      ScenarioWrites(repositories),
      TagWrites(repositories),
      DiveTypeWrites(repositories),
      DiveRoleWrites(repositories),
      SiteTypeWrites(repositories),
      SpeciesWrites(repositories),
      CenterWrites(repositories),
      CenterGearNoteWrites(repositories),
      CustomAgencyWrites(repositories),
      CustomLevelWrites(repositories),
      TankPresetWrites(repositories),
      WeightPresetWrites(repositories),
      CylinderConfigWrites(repositories),
      EquipmentWrites(repositories),
      EquipmentSetWrites(repositories),
      EquipmentLocationWrites(repositories),
      EquipmentLocationMoveWrites(repositories),
      EquipmentComponentWrites(repositories),
      ServiceKindWrites(repositories),
      ServiceScheduleWrites(repositories, refreshReminders: refreshReminders),
      ServiceRecordWrites(repositories, refreshReminders: refreshReminders),
      EquipmentObservationWrites(
        repositories,
        refreshFindings: refreshFindings,
      ),
      CylinderFillWrites(repositories),
      TransmitterWrites(repositories, refreshFindings: refreshFindings),
      TripWrites(repositories),
      LiveaboardDetailsWrites(repositories),
      ItineraryDayWrites(repositories),
      TripCylinderWrites(repositories),
      TripCylinderEventWrites(repositories),
      TripChecklistWrites(repositories),
      TripChecklistSectionWrites(repositories),
      TripChecklistItemWrites(repositories),
      DiverWrites(repositories),
      WeightEntryWrites(repositories),
      CertificationWrites(repositories),
      CurrencyRuleWrites(repositories),
      CurrencyPrefWrites(repositories),
      CurrencyEventWrites(repositories),
      CourseWrites(repositories),
      CourseRequirementWrites(repositories),
      ChecklistTemplateWrites(repositories),
      PreDiveTemplateWrites(repositories),
      PreDiveSessionWrites(repositories),
      PreDiveSessionItemWrites(repositories),
      DivePlanWrites(repositories),
      DivePlanSeriesWrites(repositories),
      RuleWrites(repositories),
      SavedQueryWrites(repositories),
      ConnectionMapWrites(repositories),
      SiteFeatureWrites(repositories, stamper: stamper),
      IncidentWrites(repositories, refreshFindings: refreshFindings),
      EmergencyChamberWrites(repositories),
      DiveComputerWrites(repositories),
      SafetyFindingWrites(repositories),
      GpsTrackWrites(repositories),
      NavTrackWrites(repositories),
      DocumentWrites(repositories, rearm: rearmDocuments),
      SmartAlbumWrites(repositories),
      MediaWrites(repositories),
    ]);
  }

  final List<WritableEntry> all;

  WritableEntry? named(String name) {
    for (final entry in all) {
      if (entry.name == name) return entry;
    }
    return null;
  }
}
