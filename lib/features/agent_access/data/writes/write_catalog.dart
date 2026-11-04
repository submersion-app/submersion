import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/annotation_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/buddy_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/center_gear_note_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/center_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/custom_certification_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/custom_field_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/cylinder_config_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_role_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_type_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/gas_switch_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/preset_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/scenario_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/sighting_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_type_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/site_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/species_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/tag_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/weight_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';

/// Every entity an agent can change, by the read catalogue's names.
class WriteCatalog {
  WriteCatalog(RecordRepositories repositories, {LibraryEditStamper? stamper})
    : all = _entries(repositories, stamper);

  /// Built per request, so the row writers share one repository.
  static List<WritableEntry> _entries(
    RecordRepositories repositories,
    LibraryEditStamper? stamper,
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
