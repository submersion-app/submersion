import 'dart:io';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every editable record must be writable by an agent before release (spec,
/// "Coverage and release gate"), so every repository method whose name says
/// it writes ([isWriteName]: create, update and delete, and rename, assign,
/// link, reorder and the rest) is accounted for: reached by a write entity,
/// or listed in the baseline as not reached yet. The baseline only shrinks. A new method
/// that a write entity does not reach fails here, which is what keeps "any
/// record" true.
///
/// After covering a method, move it to [covered] and regenerate the baseline:
/// `UPDATE_AGENT_WRITE_BASELINE=1 flutter test
/// test/architecture/agent_write_coverage_test.dart`
void main() {
  const gear = 'lib/features/equipment/data/repositories';
  const passports = 'lib/features/cylinder_passports/data/repositories';
  const trips = 'lib/features/trips/data/repositories';
  const checklists = 'lib/features/checklists/data/repositories';
  const divers = 'lib/features/divers/data/repositories';
  const certs = 'lib/features/certifications/data/repositories';
  const courses = 'lib/features/courses/data/repositories';
  const planner = 'lib/features/planner/data/repositories';
  const safety = 'lib/features/safety/data/repositories';
  const diveLog = 'lib/features/dive_log/data/repositories';
  const media = 'lib/features/media/data/repositories';
  const baselinePath = 'test/architecture/agent_write_coverage_baseline.txt';

  /// `repository file:method`, and the write entity that reaches it.
  final covered = <String, String>{
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createDive':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateFields':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkShiftDiveTimes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkDeleteDives':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkSetSite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddDiveTypes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveDiveTypes':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:createBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:updateFields':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:deleteBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkAddBuddies':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkRemoveBuddies':
        'dives',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:createSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:deleteSite':
        'sites',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddEquipment':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveEquipment':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddCourses':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveCourses':
        'dives',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addWeight':
        'dive_weights',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateWeight':
        'dive_weights',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteWeight':
        'dive_weights',
    'lib/features/marine_life/data/repositories/species_repository.dart:addSighting':
        'sightings',
    'lib/features/marine_life/data/repositories/species_repository.dart:updateSighting':
        'sightings',
    'lib/features/marine_life/data/repositories/species_repository.dart:deleteSighting':
        'sightings',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addCustomField':
        'dive_custom_fields',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateCustomField':
        'dive_custom_fields',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteCustomField':
        'dive_custom_fields',
    'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:writeDiverRoles':
        'dives',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:addAnnotation':
        'dive_events',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:moveAnnotation':
        'dive_events',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:removeAnnotation':
        'dive_events',
    'lib/features/dive_lab/data/repositories/dive_scenario_repository.dart:saveScenario':
        'dive_scenarios',
    'lib/features/dive_lab/data/repositories/dive_scenario_repository.dart:deleteScenario':
        'dive_scenarios',
    'lib/features/tags/data/repositories/tag_repository.dart:createTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:updateTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:deleteTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:mergeTags': 'tags',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:createDiveType':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:updateDiveType':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:setDiveTypeVisibility':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:deleteDiveType':
        'dive_types',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:createDiveRole':
        'dive_roles',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:renameDiveRole':
        'dive_roles',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:deleteDiveRole':
        'dive_roles',
    'lib/features/site_types/data/repositories/site_type_repository.dart:createSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:updateSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:deleteSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:deleteSiteTypesWithLinks':
        'site_types',
    'lib/features/marine_life/data/repositories/species_repository.dart:createSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:updateSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:deleteSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:addExpectedSpecies':
        'sites',
    'lib/features/marine_life/data/repositories/species_repository.dart:removeExpectedSpecies':
        'sites',
    'lib/features/dive_sites/data/repositories/site_classification_repository.dart:replaceTags':
        'sites',
    'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTagsToSites':
        'sites',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:createDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:updateDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:deleteDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:create':
        'center_gear_notes',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:update':
        'center_gear_notes',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:delete':
        'center_gear_notes',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:createAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:updateAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:deleteAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:createLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:updateLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:deleteLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:reorderProgression':
        'custom_levels',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:createPreset':
        'tank_presets',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:updatePreset':
        'tank_presets',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:deletePreset':
        'tank_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:createPreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:updatePreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:renamePreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:deletePreset':
        'weight_presets',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:createConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:updateConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:deleteConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:saveItems':
        'cylinder_configs',
    for (final method in const [
      'createEquipment',
      'updateEquipment',
      'deleteEquipment',
      'deleteOwnedEquipment',
      'saveAttributes',
    ])
      '$gear/equipment_repository_impl.dart:$method': 'equipment',
    '$gear/equipment_share_repository.dart:setShares': 'equipment',
    for (final method in const [
      'createSet',
      'updateSet',
      'deleteSet',
      'setAsDefault',
      'clearDefault',
      'setShowFigure',
      'addGeofence',
      'updateGeofence',
      'removeGeofence',
    ])
      '$gear/equipment_set_repository_impl.dart:$method': 'equipment_sets',
    for (final method in const [
      'createLocation',
      'updateLocation',
      'setArchived',
      'deleteLocation',
    ])
      '$gear/equipment_location_repository.dart:$method': 'equipment_locations',
    for (final method in const [
      'addComponent',
      'updateRole',
      'replaceComponent',
      'reorder',
      'removeComponent',
    ])
      '$gear/equipment_component_repository.dart:$method':
          'equipment_components',
    for (final method in const ['recordMoves', 'updateMove', 'deleteMove'])
      '$gear/equipment_location_move_repository.dart:$method':
          'equipment_location_moves',
    'lib/features/tags/data/repositories/tag_link_repository.dart:replaceTags':
        'equipment',
    for (final method in const ['createKind', 'updateKind', 'deleteKind'])
      '$gear/service_kind_repository.dart:$method': 'service_kinds',
    for (final method in const [
      'createSchedule',
      'updateSchedule',
      'deleteSchedule',
    ])
      '$gear/service_schedule_repository.dart:$method': 'service_schedules',
    // The item save calls it with the baselines its attributes name.
    '$gear/service_schedule_repository.dart:applyBaselines': 'equipment',
    for (final method in const ['createRecord', 'updateRecord', 'deleteRecord'])
      '$gear/service_record_repository.dart:$method': 'service_records',
    '$gear/equipment_repository_impl.dart:replaceChild': 'equipment',
    for (final method in const ['create', 'update', 'delete'])
      '$gear/equipment_observation_repository.dart:$method':
          'equipment_observations',
    for (final method in const ['create', 'update', 'delete'])
      '$passports/cylinder_fill_repository.dart:$method': 'cylinder_fills',
    '$passports/cylinder_passport_repository.dart:assignPassportId':
        'equipment',
    for (final method in const [
      'create',
      'update',
      'delete',
      'saveSetup',
      'applyToExistingDives',
    ])
      'lib/features/transmitters/data/repositories/transmitter_repository.dart:$method':
          'transmitters',
    for (final method in const [
      'createTrip',
      'updateTrip',
      'deleteTrip',
      'assignDivesToTrip',
    ])
      '$trips/trip_repository.dart:$method': 'trips',
    for (final method in const ['pack', 'unpack'])
      '$trips/trip_equipment_repository.dart:$method': 'trips',
    '$trips/liveaboard_details_repository.dart:createOrUpdate':
        'liveaboard_details',
    for (final method in const ['saveAll', 'updateDay', 'setPlannedDives'])
      '$trips/itinerary_day_repository.dart:$method': 'itinerary_days',
    for (final method in const [
      'createCylinder',
      'createCylinders',
      'updateCylinder',
      'deleteCylinder',
      'reorderCylinders',
    ])
      '$trips/trip_cylinder_repository.dart:$method': 'trip_cylinders',
    '$trips/trip_cylinder_repository.dart:deleteByTripId': 'trips',
    for (final method in const [
      'createEvent',
      'createEvents',
      'updateEvent',
      'deleteEvent',
    ])
      '$trips/trip_cylinder_repository.dart:$method': 'trip_cylinder_events',
    for (final method in const [
      'createChecklist',
      'renameChecklist',
      'reorderChecklists',
      'deleteChecklist',
    ])
      '$checklists/trip_checklists_repository.dart:$method': 'trip_checklists',
    '$checklists/trip_checklists_repository.dart:deleteAllForTrip': 'trips',
    for (final method in const [
      'applyTemplate',
      'replaceWithTemplate',
      'saveAsTemplate',
    ])
      '$checklists/trip_checklist_repository.dart:$method': 'trip_checklists',
    for (final file in const [
      'trip_checklist_repository.dart',
      'trip_checklist_section_repository.dart',
    ])
      for (final method in const [
        'createSection',
        'renameSection',
        'reorderSections',
        'deleteSection',
      ])
        '$checklists/$file:$method': 'trip_checklist_sections',
    '$checklists/trip_checklist_section_repository.dart:createSectionRow':
        'trip_checklists',
    for (final method in const [
      'createItem',
      'updateItem',
      'toggleDone',
      'moveItem',
      'deleteItem',
      'clearItems',
    ])
      '$checklists/trip_checklist_repository.dart:$method':
          'trip_checklist_items',
    for (final method in const [
      'createDiver',
      'updateDiver',
      'setDefaultDiver',
    ])
      '$divers/diver_repository.dart:$method': 'divers',
    for (final method in const ['createEntry', 'updateEntry', 'deleteEntry'])
      '$divers/diver_weight_entry_repository.dart:$method': 'weight_entries',
    for (final method in const [
      'createCertification',
      'updateCertification',
      'deleteCertification',
      'replaceBuddyCertifications',
    ])
      '$certs/certification_repository.dart:$method': 'certifications',
    for (final (method, entity) in const [
      ('createRule', 'currency_rules'),
      ('updateRule', 'currency_rules'),
      ('deleteRule', 'currency_rules'),
      ('upsertPref', 'currency_prefs'),
      ('deletePref', 'currency_prefs'),
      ('createEvent', 'currency_events'),
      ('deleteEvent', 'currency_events'),
    ])
      '$certs/certification_currency_repository.dart:$method': entity,
    for (final method in const [
      'createCourse',
      'updateCourse',
      'deleteCourse',
      'linkDiveToCourse',
      'unlinkDiveFromCourse',
      'setCourseCertifications',
    ])
      '$courses/course_repository.dart:$method': 'courses',
    '$courses/course_requirement_repository.dart:applyTemplate': 'courses',
    for (final method in const [
      'createRequirement',
      'updateRequirement',
      'deleteRequirement',
      'setChecklistComplete',
      'linkDive',
      'unlinkDive',
    ])
      '$courses/course_requirement_repository.dart:$method':
          'course_requirements',
    // A dive's buddy list, as the edit page sets it whole and the bulk form
    // adds, removes and re-roles buddies.
    for (final method in const [
      'setBuddiesForDive',
      'bulkUpdateBuddyRoles',
      'bulkReplaceBuddies',
      'addBuddyToDive',
      'addBuddyToDiveWithRoles',
      'removeBuddyFromDive',
    ])
      'lib/features/buddies/data/repositories/buddy_repository.dart:$method':
          'dives',
    for (final method in const [
      'replaceTypes',
      'addTypes',
      'addTypesToSites',
      'removeTypesFromSites',
      'addTags',
      'removeTagsFromSites',
    ])
      'lib/features/dive_sites/data/repositories/'
              'site_classification_repository.dart:$method':
          'sites',
    for (final method in const ['setSharing', 'shareWith', 'addSharing'])
      '$divers/item_shares_repository.dart:$method': 'trips',
    for (final method in const ['hide', 'hideAll', 'unhide'])
      '$divers/profile_hides_repository.dart:$method': 'sites',
    // Templates are written whole; the editor's one-section steps reach the
    // same lists.
    for (final method in const [
      'createTemplate',
      'updateTemplate',
      'deleteTemplate',
      'saveSections',
      'saveItems',
      'createSection',
      'renameSection',
      'reorderSections',
      'deleteSection',
    ]) ...{
      '$checklists/checklist_template_repository.dart:$method':
          'checklist_templates',
      'lib/features/pre_dive/data/repositories/'
              'pre_dive_template_repository.dart:$method':
          'pre_dive_templates',
    },
    for (final method in const [
      'startSession',
      'completeSession',
      'abortSession',
      'linkToDive',
      'unlinkFromDive',
      'deleteSession',
    ])
      'lib/features/pre_dive/data/repositories/'
              'pre_dive_session_repository.dart:$method':
          'pre_dive_sessions',
    'lib/features/pre_dive/data/repositories/'
            'pre_dive_session_repository.dart:updateItemState':
        'pre_dive_session_items',
    for (final method in const [
      'savePlan',
      'deletePlan',
      'duplicatePlan',
      'linkPlanToDive',
      'unlinkPlan',
    ])
      '$planner/dive_plan_repository.dart:$method': 'dive_plans',
    // The scooter mission rows a plan save and delete write with the plan.
    for (final method in const [
      'write',
      'recordWrite',
      'deleteAll',
      'recordDeletion',
    ])
      '$planner/dive_plan_mission_store.dart:$method': 'dive_plans',
    '$planner/dive_plan_dive_links.dart:clearPlanLinksToDives': 'dives',
    '$planner/dive_plan_dive_links.dart:clearPlanLinksToSites': 'sites',
    for (final method in const [
      'saveSeries',
      'renameSeries',
      'deleteSeries',
      'duplicateSeries',
      'dissolveSeries',
    ])
      '$planner/dive_plan_series_repository.dart:$method': 'dive_plan_series',
    for (final method in const [
      'create',
      'update',
      'delete',
      'duplicate',
      'reorder',
      'setEnabled',
    ])
      'lib/features/rules/data/repositories/rule_repository.dart:$method':
          'rules',
    for (final method in const [
      'create',
      'rename',
      'updateQuery',
      'reorder',
      'delete',
    ])
      'lib/features/query/data/repositories/saved_query_repository.dart:'
              '$method':
          'saved_queries',
    for (final method in const ['create', 'rename', 'updateSpec', 'delete'])
      'lib/features/connections/data/repositories/'
              'connection_map_repository.dart:$method':
          'connection_maps',
    for (final method in const ['addFeature', 'updateFeature', 'deleteFeature'])
      'lib/features/dive_sites/data/repositories/site_feature_repository.dart:'
              '$method':
          'site_features',
    for (final method in const [
      'createIncident',
      'updateIncident',
      'deleteIncident',
    ])
      '$safety/incident_repository.dart:$method': 'incidents',
    // An item's delete takes it off its incidents.
    '$safety/incident_repository.dart:unlinkFromDeletedEquipment': 'equipment',
    for (final method in const ['createChamber', 'deleteChamber'])
      '$safety/emergency_chamber_repository.dart:$method': 'emergency_chambers',
    for (final method in const [
      'setFavoriteComputer',
      'setAutoDownloadDisabled',
    ])
      '$diveLog/dive_computer_repository_impl.dart:$method': 'dive_computers',
    // A computer's record is its gear item's: made, renamed and deleted
    // with it.
    for (final method in const [
      'createComputer',
      'updateComputer',
      'deleteComputer',
    ])
      '$diveLog/dive_computer_repository_impl.dart:$method': 'equipment',
    for (final method in const ['setDismissed', 'setDismissedForDives'])
      '$diveLog/safety_findings_repository.dart:$method': 'safety_findings',
    for (final method in const [
      'setTrimBounds',
      'clearTrim',
      'splitTrack',
      'deleteTrack',
    ])
      'lib/features/gps_log/data/repositories/gps_track_repository.dart:'
              '$method':
          'gps_tracks',
    for (final method in const [
      'rename',
      'setSite',
      'setEquipment',
      'updateCorrection',
      'setPrimary',
      'link',
      'unlink',
      'relink',
      'delete',
    ])
      'lib/features/nav_track/data/repositories/nav_track_repository.dart:'
              '$method':
          'nav_tracks',
    for (final method in const [
      'save',
      'delete',
      'deleteForOwner',
      'deleteForOwners',
    ])
      'lib/features/documents/data/repositories/document_repository.dart:'
              '$method':
          'documents',
    // A card's images ride on its certification's save.
    'lib/features/documents/data/repositories/document_repository.dart:'
            'saveCardImages':
        'certifications',
    for (final method in const ['create', 'rename', 'delete'])
      'lib/features/media/data/repositories/media_smart_album_repository.dart:'
              '$method':
          'smart_albums',
    // A tag merge moves the smart albums that name the merged tag.
    for (final method in const ['repointSmartAlbumTags', 'repointSmartAlbums'])
      'lib/features/media/data/repositories/smart_album_tag_repoint.dart:'
              '$method':
          'tags',
    for (final (file, method) in const [
      ('media_repository.dart', 'setManualElapsedSeconds'),
      ('media_repository.dart', 'reassignMediaToDive'),
      ('media_repository.dart', 'unlinkFromDive'),
      ('media_repository.dart', 'deleteMedia'),
      ('media_repository.dart', 'deleteMultipleMedia'),
      ('media_people_repository.dart', 'addTag'),
      ('media_people_repository.dart', 'updateTag'),
      ('media_people_repository.dart', 'removeTag'),
      ('media_species_repository.dart', 'addTag'),
      ('media_species_repository.dart', 'removeTag'),
      ('media_color_adjustment_repository.dart', 'setColorAdjustment'),
      ('media_color_adjustment_repository.dart', 'applySlidersToDive'),
      ('site_attachment_repository.dart', 'setAttachmentDetails'),
      ('site_attachment_repository.dart', 'setSiteCategory'),
    ])
      '$media/$file:$method': 'media',
    // Merges, as their pages merge: the merge and the helpers it calls.
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:'
            'mergeSites':
        'sites',
    'lib/features/dive_sites/data/repositories/'
            'site_classification_repository.dart:relinkForMerge':
        'sites',
    for (final file in const [
      'buddy_repository.dart',
      'buddy_merge_repository.dart',
    ])
      'lib/features/buddies/data/repositories/$file:mergeBuddies': 'buddies',
    for (final method in const [
      'repointMediaPeopleForMerge',
      'repointSmartAlbumBuddies',
    ])
      '$media/media_people_buddy_merge.dart:$method': 'buddies',
    '$diveLog/dive_computer_merge_repository.dart:mergeComputers':
        'dive_computers',
    for (final method in const ['cloneTemplate', 'updateItemEquipment'])
      'lib/features/pre_dive/data/repositories/'
              'pre_dive_template_repository.dart:$method':
          'pre_dive_templates',
    // The same record changed by another path the app also takes.
    'lib/features/buddies/data/repositories/buddy_repository.dart:setFavorite':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:toggleFavorite':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:updateBuddy':
        'buddies',
    'lib/features/dive_log/data/repositories/dive_custom_field_repository.dart:replaceFieldsForDive':
        'dive_custom_fields',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createGasSwitch':
        'gas_switches',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteDive':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteGasSwitch':
        'gas_switches',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:insertGasSwitches':
        'gas_switches',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setFavorite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setSite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:shiftDiveTimes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:toggleFavorite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:updateDive':
        'dives',
    'lib/features/tags/data/repositories/tag_link_repository.dart:addTags':
        'dives',
    'lib/features/tags/data/repositories/tag_link_repository.dart:removeTags':
        'dives',
    'lib/features/tags/data/repositories/tag_repository.dart:addTagToDive':
        'dives',
    'lib/features/tags/data/repositories/tag_repository.dart:removeTagFromDive':
        'dives',
    'lib/features/tags/data/repositories/tag_repository.dart:setTagsForDive':
        'dives',
    'lib/features/trips/data/repositories/trip_repository.dart:assignDiveToTrip':
        'trips',
  };

  /// Writes that change no record a diver keeps, so no change set entity
  /// covers them, each with the reason. `path:*` exempts a whole repository
  /// file. Anything a diver edits as a record of their diving stays out of
  /// here, however small.
  final exempt = <String, String>{
    // Decided 2026-11-04: an agent neither deletes nor merges a profile.
    for (final path in const [
      'diver_delete_steps.dart:*',
      'diver_location_retirement.dart:*',
      'diver_merge_repository.dart:*',
      'diver_owned_rows.dart:*',
      'diver_repository.dart:deleteDiver',
      'diver_repository.dart:deleteDiverWithReassignment',
    ])
      '$divers/$path':
          'deleting or merging a profile is done in the app, which offers '
          'to move its dives first',
    '$divers/diver_repository.dart:setActiveDiverIdInSettings':
        'which profile this device shows, an app preference',
    'lib/features/settings/data/repositories/app_settings_repository.dart:*':
        'app preferences, not logbook records',
    'lib/features/settings/data/repositories/diver_settings_repository.dart:*':
        'a diver\'s preferences, not logbook records',
    'lib/features/auto_update/data/repositories/update_preferences.dart:*':
        'app preferences',
    'lib/features/backup/data/repositories/backup_preferences.dart:*':
        'app preferences and backup bookkeeping',
    'lib/features/change_log/data/repositories/change_log_preferences.dart:*':
        'app preferences',
    'lib/features/change_log/data/repositories/change_log_repository.dart:*':
        'the log of changes itself, written by every write',
    'lib/features/notifications/data/repositories/scheduled_notification_repository.dart:*':
        'reminders scheduled from records, rewritten when they change',
    'lib/features/maps/data/repositories/offline_map_repository.dart:*':
        'map downloads kept on this device',
    'lib/features/reef/data/repositories/reef_cache_dao.dart:*': 'a cache',
    'lib/features/tides/data/repositories/noaa_station_cache_repository.dart:*':
        'a cache',
    'lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart:*':
        'a cache',
    'lib/features/insights/data/repositories/deco_classification_cache.dart:*':
        'a cache',
    'lib/features/insights/data/repositories/observation_dismissals_repository.dart:*':
        'the state of derived findings, recomputed from records',
    'lib/features/data_quality/data/repositories/quality_findings_repository.dart:*':
        'the state of derived findings, recomputed from records',
    'lib/features/dive_computer/data/repositories/dive_computer_connection_repository.dart:*':
        'this device\'s pairing with a dive computer',
    'lib/features/marine_life/data/repositories/species_repository.dart:resetBuiltInSpecies':
        'restores the bundled catalogue; the edits it undoes are species '
        'updates',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:createFromWeights':
        'a shortcut for a create with entries, which weight_presets covers',
    for (final method in const [
      'retireEquipment',
      'setStatusForMany',
      'markEquipmentPurchased',
    ])
      '$gear/equipment_repository_impl.dart:$method':
          'a shortcut for a status change, which equipment covers through '
          'updateEquipment',
    for (final method in const [
      'createEquipmentWithTags',
      'updateEquipmentWithTags',
    ])
      '$gear/equipment_repository_impl.dart:$method':
          'the edit page\'s save, which equipment covers as fields and a tags '
          'relation',
    '$gear/dive_sensor_summary_repository.dart:*':
        'a summary derived from dives, recomputed when they change',
    '$gear/equipment_service_status_repository.dart:*':
        'a status derived from the service ledger, recomputed from it',
    '$gear/equipment_findings_repository.dart:*':
        'the review state of derived findings, recomputed from records',
    for (final step in const [
      'cylinder_gear_links.dart:*',
      'equipment_location_buddy_links.dart:*',
      'equipment_location_center_links.dart:*',
      'equipment_tag_repository.dart:deleteLinksForEquipment',
      'equipment_share_repository.dart:deleteForEquipment',
      'equipment_location_move_repository.dart:deleteForEquipment',
    ])
      '$gear/$step': 'an inner step of a delete of its owner',
    '$gear/equipment_location_move_repository.dart:recordMoveGroups':
        'a bulk shortcut for moves, which equipment_location_moves covers '
        'one move at a time through recordMoves',
    for (final method in const ['addItemToSet', 'removeItemFromSet'])
      '$gear/equipment_set_repository_impl.dart:$method':
          'a shortcut for a member change, which equipment_sets covers as '
          'equipment_ids through updateSet',
    for (final method in const ['shareMany', 'unshare', 'shareAllForDiver'])
      '$gear/equipment_share_repository.dart:$method':
          'a bulk shortcut for a share change, which equipment covers as '
          'shared_with through setShares',
    '$gear/equipment_repository_impl.dart:markAsServiced':
        'a legacy field with no caller in the app, and a write that skips '
        'sync; service_records covers servicing',
    // Imports, devices and derived values.
    for (final method in const [
      'lib/features/buddies/data/repositories/buddy_conversion_repository.dart:apply',
      'lib/features/buddies/data/repositories/buddy_conversion_repository.dart:undo',
      'lib/features/buddies/data/repositories/buddy_repository.dart:applyLegacyConversion',
      'lib/features/dive_log/data/repositories/derived_metrics_repository.dart:saveMetrics',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:addProfileEvent',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:clearEventsForDive',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:clearSourceAndProfiles',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:insertTanks',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:updateLastDownload',
      'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:updateLastFingerprint',
      'lib/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart:addCustomFieldsIfMissing',
      'lib/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart:fillCurrentStrengthIfEmpty',
      'lib/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart:fillVisibilityRangeIfEmpty',
      'lib/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart:linkDiveCenterIfNone',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:addWeightIfNone',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:applyImportedMetadata',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteComputerReading',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:fillDiveConditions',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:fillNotesIfEmpty',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:insertProfileEvents',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:saveAdditionalComputerReading',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:saveComputerReading',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:saveComputerReadings',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setDiveGps',
      'lib/features/dive_log/data/repositories/safety_findings_repository.dart:saveReview',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:applyImportedMetadata',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:applyLocationDetails',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSiteAltitude',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSiteCoordinates',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSiteWithImportedMetadata',
      'lib/features/gps_log/data/repositories/gps_track_repository.dart:insertImportedTrack',
      'lib/features/gps_log/data/repositories/gps_track_repository.dart:startTrack',
      'lib/features/media/data/repositories/media_repository.dart:applyRepairWrites',
      'lib/features/media/data/repositories/media_repository.dart:createPendingSuggestion',
      'lib/features/media/data/repositories/media_repository.dart:deleteOrphanedMedia',
      'lib/features/media/data/repositories/media_repository.dart:deleteSuggestionsForRemoteAsset',
      'lib/features/media/data/repositories/media_repository.dart:markAsOrphaned',
      'lib/features/media/data/repositories/media_repository.dart:markAsVerified',
      'lib/features/media/data/repositories/media_repository.dart:markOrphaned',
      'lib/features/media/data/repositories/media_repository.dart:markVerified',
      'lib/features/media/data/repositories/media_repository.dart:saveEnrichment',
      'lib/features/media/data/repositories/media_repository.dart:saveEnrichments',
      'lib/features/nav_track/data/repositories/nav_track_repository.dart:insertImportedRoute',
      'lib/features/nav_track/data/repositories/nav_track_repository.dart:replace',
      'lib/features/rules/data/repositories/rule_run_repository.dart:deleteAllRuns',
      'lib/features/rules/data/repositories/rule_run_repository.dart:deleteRun',
      'lib/features/rules/data/repositories/rule_run_repository.dart:insertRun',
      'lib/features/rules/data/repositories/rule_run_repository.dart:markUndone',
      'lib/features/tides/data/repositories/tide_record_repository.dart:createFromStatus',
      'lib/features/tides/data/repositories/tide_record_repository.dart:deleteTideRecordForDive',
      'lib/features/tides/data/repositories/tide_record_repository.dart:saveTideRecord',
      'lib/features/trips/data/repositories/trip_day_weather_repository.dart:upsert',
    ])
      method:
          'written by an import, a download, a device or the app\'s own derivation, not a diver\'s edit',
    // Bulk shortcuts.
    for (final method in const [
      'lib/features/buddies/data/repositories/buddy_merge_repository.dart:bulkDeleteBuddies',
      'lib/features/buddies/data/repositories/buddy_repository.dart:bulkDeleteBuddies',
      'lib/features/dive_lab/data/repositories/dive_scenario_repository.dart:duplicateScenario',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:assignMissingDiveNumbers',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTank',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTanks',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddWeights',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAppendNotes',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceCourses',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceDiveTypes',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceEquipment',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceTags',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceTanks',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkReplaceWeights',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRestoreTankRows',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateTankSpecs',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateTrip',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setSingleWeightAmount',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setTankRoles',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:updateTankRecordPressures',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:bulkDeleteSites',
      'lib/features/marine_life/data/repositories/species_repository.dart:bulkAddSightings',
      'lib/features/marine_life/data/repositories/species_repository.dart:bulkReplaceSightings',
      'lib/features/marine_life/data/repositories/species_repository.dart:removeAllExpectedSpeciesForSite',
    ])
      method: 'a bulk shortcut for a write an agent makes record by record',
    // Inner steps.
    for (final method in const [
      'lib/features/buddies/data/repositories/buddy_merge_repository.dart:undoMerge',
      'lib/features/buddies/data/repositories/buddy_repository.dart:undoLegacyConversion',
      'lib/features/buddies/data/repositories/buddy_repository.dart:undoMerge',
      'lib/features/connections/data/repositories/connection_map_repository.dart:restore',
      'lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart:relinkToEquipment',
      'lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart:unlinkFromDeletedEquipment',
      'lib/features/dive_log/data/repositories/dive_parent_links.dart:clearDiveCenterLinks',
      'lib/features/dive_log/data/repositories/dive_parent_links.dart:clearDiveSiteLinks',
      'lib/features/dive_log/data/repositories/dive_parent_links.dart:clearDiveTripLinks',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteGasSwitchesForDive',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteProfileEventsForDive',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:replaceGearRows',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:replaceSetEquipment',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:restoreDiveTimes',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:restoreOriginalProfile',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:restoreSourceProfiles',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:restoreTankAttribution',
      'lib/features/dive_log/data/repositories/source_clock_repository.dart:restore',
      'lib/features/dive_log/data/repositories/source_clock_repository.dart:shift',
      'lib/features/dive_log/data/repositories/tank_computer_links.dart:clearTankComputerLinks',
      'lib/features/dive_log/data/repositories/tank_role_repair_repository.dart:undoUseAsBailout',
      'lib/features/dive_log/data/repositories/tank_source_links.dart:clearTankSourceLinks',
      'lib/features/dive_log/data/repositories/tank_source_links.dart:restoreTankLinks',
      'lib/features/dive_log/data/repositories/trip_cylinder_links.dart:clearForeignTripCylinderLinks',
      'lib/features/dive_log/data/repositories/trip_cylinder_links.dart:clearTripCylinderEquipmentLinks',
      'lib/features/dive_log/data/repositories/trip_cylinder_links.dart:clearTripCylinderEventCenterLinks',
      'lib/features/dive_log/data/repositories/trip_cylinder_links.dart:clearTripCylinderLinks',
      'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:deleteBuddyRoles',
      'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:deleteBuddyRolesOnDives',
      'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:restoreRows',
      'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:writeBuddyRoles',
      'lib/features/dive_sites/data/repositories/site_children.dart:restore',
      'lib/features/dive_sites/data/repositories/site_children.dart:restoreSiteChildren',
      'lib/features/dive_sites/data/repositories/site_links.dart:restoreLinksToSites',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:relinkSiteReferences',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:restoreSiteLinks',
      'lib/features/dive_sites/data/repositories/site_repository_impl.dart:undoMerge',
      'lib/features/divers/data/repositories/item_shares_repository.dart:deleteShares',
      'lib/features/divers/data/repositories/item_shares_repository.dart:restoreShares',
      'lib/features/divers/data/repositories/profile_hides_repository.dart:deleteHides',
      'lib/features/divers/data/repositories/profile_hides_repository.dart:restoreHides',
      'lib/features/documents/data/repositories/document_repository.dart:reassignOwner',
      'lib/features/documents/data/repositories/document_repository.dart:restoreOwners',
      'lib/features/documents/data/repositories/document_repository.dart:restoreSnapshot',
      'lib/features/equipment/data/repositories/equipment_observation_repository.dart:unlinkFromDeletedDives',
      'lib/features/marine_life/data/repositories/species_repository.dart:deleteSightingsForDive',
      'lib/features/media/data/repositories/media_color_adjustment_repository.dart:restoreColorAdjustments',
      'lib/features/media/data/repositories/media_parent_cascade.dart:unlinkMediaFromDeletedParents',
      'lib/features/media/data/repositories/media_people_buddy_merge.dart:undoMediaPeopleMerge',
      'lib/features/media/data/repositories/media_people_repository.dart:deleteForBuddies',
      'lib/features/media/data/repositories/media_people_repository.dart:deleteForMedia',
      'lib/features/media/data/repositories/media_repository.dart:unlinkMediaFromDeletedDives',
      'lib/features/media/data/repositories/media_repository.dart:unlinkMediaFromDeletedEquipment',
      'lib/features/media/data/repositories/media_repository.dart:unlinkMediaFromDeletedSites',
      'lib/features/media/data/repositories/media_row_restore.dart:relinkMediaToSites',
      'lib/features/media/data/repositories/media_row_restore.dart:restoreMediaRows',
      'lib/features/nav_track/data/repositories/nav_track_repository.dart:moveLinks',
      'lib/features/nav_track/data/repositories/nav_track_repository.dart:restoreLinks',
      'lib/features/planner/data/repositories/dive_plan_dive_links.dart:clearPlanLinksToDiverRows',
      'lib/features/planner/data/repositories/dive_plan_dive_links.dart:clearPlanLinksToDiverSeries',
      'lib/features/planner/data/repositories/dive_plan_series_repository.dart:restoreSeries',
      'lib/features/tags/data/repositories/tag_link_repository.dart:deleteLinksFor',
      'lib/features/transmitters/data/repositories/transmitter_repository.dart:detachFromDeletedComputer',
      'lib/features/transmitters/data/repositories/transmitter_repository.dart:unlinkFromDeletedEquipment',
      'lib/features/trips/data/repositories/itinerary_day_repository.dart:deleteBarePlanDaysOutside',
      'lib/features/trips/data/repositories/itinerary_day_repository.dart:deleteByTripId',
      'lib/features/trips/data/repositories/liveaboard_details_repository.dart:deleteByTripId',
      'lib/features/trips/data/repositories/side_trip_links.dart:detachSideTripsForDelete',
      'lib/features/trips/data/repositories/trip_date_stretch.dart:restoreStretchedTripDates',
      'lib/features/trips/data/repositories/trip_day_weather_repository.dart:deleteByTripId',
      'lib/features/trips/data/repositories/trip_equipment_repository.dart:deleteByTripId',
      'lib/features/trips/data/repositories/trip_equipment_repository.dart:deleteForEquipment',
    ])
      method:
          'an inner step of another write, run by the repository an agent write calls',
    // Planned dives.
    for (final method in const [
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createPlannedDive',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deletePlannedDive',
    ])
      method:
          'a planned dive is made and removed by the planner, from its plan',
    // Profile samples.
    for (final method in const [
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:saveEditedProfile',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:saveEditedProfileWithKind',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setActiveProfileSeries',
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setPrimaryDataSource',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:clearComputer',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:clearComputersOfDiverForForeignDives',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:clearSource',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteByComputer',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteByIds',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteEditedSeries',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteForDive',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteOwnedBy',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteRevisionsForDives',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteUndoneEdit',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:insertSeries',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:promoteAll',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:promoteByComputer',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:promoteOwnedBy',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:promoteWinnerOwnedBy',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:relinkComputer',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:repointComputer',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:restoreRevisions',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:restoreSeriesRow',
      'lib/features/dive_log/data/repositories/profile_series_repository.dart:shiftSamples',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:deleteTankPressuresForDive',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:insertTankPressures',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:insertTankSeries',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:reassignTankPressureSeries',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:replaceTankPressures',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:replaceTankSeriesForTanks',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:stampSourceWhereNull',
      'lib/features/dive_log/data/repositories/tank_pressure_repository.dart:swapTankPressureSeries',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:clearComputer',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:clearComputersOfDiverForForeignDives',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:deleteByIds',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:deleteForDive',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:deleteForTank',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:deleteOwnedByComputer',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:insertSeries',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:reassignTank',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:repointComputer',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:restoreSeriesRow',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:shiftSamples',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:stampComputerWhereNull',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:stampSourceWhereNull',
      'lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart:swapTanks',
    ])
      method:
          'a dive profile\'s samples, edited in the profile editor; samples are not agent fields',
    // Settings and view state.
    for (final method in const [
      'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setSiteSuggestionDismissed',
      'lib/features/dive_log/data/repositories/view_config_repository.dart:deletePreset',
      'lib/features/dive_log/data/repositories/view_config_repository.dart:saveCardConfig',
      'lib/features/dive_log/data/repositories/view_config_repository.dart:savePreset',
      'lib/features/dive_log/data/repositories/view_config_repository.dart:saveRawConfig',
      'lib/features/dive_log/data/repositories/view_config_repository.dart:saveTableConfig',
      'lib/features/universal_import/data/repositories/csv_preset_repository.dart:deletePreset',
      'lib/features/universal_import/data/repositories/csv_preset_repository.dart:savePreset',
    ])
      method: 'app settings and view state, not logbook records',
    // Device storage and bookkeeping.
    for (final method in const [
      'lib/features/media/data/repositories/local_asset_cache_repository.dart:applyResolutionHints',
      'lib/features/media/data/repositories/local_asset_cache_repository.dart:clearEntries',
      'lib/features/media/data/repositories/local_asset_cache_repository.dart:clearEntry',
      'lib/features/media/data/repositories/local_asset_cache_repository.dart:clearUnresolved',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:createSubscription',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:deleteById',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:recordPollFailure',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:recordPollNotModified',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:recordPollSuccess',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:setActive',
      'lib/features/media/data/repositories/manifest_subscription_repository.dart:updateUrlAndDisplayName',
      'lib/features/media/data/repositories/media_repair_log_repository.dart:record',
      'lib/features/media/data/repositories/media_repository.dart:clearRemoteCompressed',
      'lib/features/media/data/repositories/media_repository.dart:clearRemoteThumbUploaded',
      'lib/features/media/data/repositories/media_repository.dart:clearRemoteUploaded',
      'lib/features/media/data/repositories/media_repository.dart:stampCloudAssetIds',
      'lib/features/media/data/repositories/media_repository.dart:stampContentIdentity',
      'lib/features/media/data/repositories/media_repository.dart:stampOriginDevice',
      'lib/features/media/data/repositories/media_repository.dart:stampRemoteCompressedUploaded',
      'lib/features/media/data/repositories/media_repository.dart:stampRemoteThumbUploaded',
      'lib/features/media/data/repositories/media_repository.dart:stampRemoteUploaded',
      'lib/features/media/data/repositories/media_repository.dart:stampVerification',
      'lib/features/media/data/repositories/network_credentials_repository.dart:delete',
      'lib/features/media/data/repositories/network_credentials_repository.dart:updateDisplayName',
      'lib/features/media/data/repositories/network_credentials_repository.dart:upsert',
      'lib/features/media/data/repositories/watched_folder_repository.dart:addRoot',
      'lib/features/media/data/repositories/watched_folder_repository.dart:deleteIndexed',
      'lib/features/media/data/repositories/watched_folder_repository.dart:removeRoot',
      'lib/features/media/data/repositories/watched_folder_repository.dart:stampScanned',
      'lib/features/media/data/repositories/watched_folder_repository.dart:upsertIndexed',
    ])
      method:
          'device storage, credentials and sync bookkeeping, which an agent does not change',
    // Media attached in the app.
    for (final method in const [
      'lib/features/media/data/repositories/media_repository.dart:createMedia',
      'lib/features/media/data/repositories/media_repository.dart:dismissPendingSuggestion',
      'lib/features/media/data/repositories/media_repository.dart:linkMediaToEquipment',
      'lib/features/media/data/repositories/media_repository.dart:linkMediaToSite',
      'lib/features/media/data/repositories/media_repository.dart:unlinkFromEquipment',
      'lib/features/media/data/repositories/media_repository.dart:unlinkFromSite',
      'lib/features/media/data/repositories/media_repository.dart:updateMedia',
    ])
      method:
          'media is attached, linked to gear or a site, and captioned in the app; an agent edits what the media writer lists',
    // Trip removal.
    for (final method in const [
      'lib/features/trips/data/repositories/trip_repository.dart:removeDiveFromTrip',
    ])
      method:
          'a dive leaves its trip through the dive\'s trip link; this path does not mark the dive for sync',
  };

  /// A public `Future` method on a repository. The return type may sit on the
  /// line above the name. The type stops at `=` and at the end of its line, or
  /// on a line ending in `=>` it would run to that arrow and take the method
  /// the body calls on the next line for this one.
  final futureMethod = RegExp(
    r'^\s*Future<[^=;\n]*>\s+(?:\n\s*)?([a-z]\w*)\s*[(<]',
    multiLine: true,
  );

  Set<String> scanRepositories() {
    final found = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/data/repositories/')) continue;
      for (final match in futureMethod.allMatches(entity.readAsStringSync())) {
        final name = match.group(1)!;
        if (isWriteName(name)) found.add('$path:$name');
      }
    }
    return found;
  }

  test('a write is known by every verb repositories use for one', () {
    for (final name in [
      'createDive',
      'renameDiveRole',
      'assignDivesToTrip',
      'linkDiveToCourse',
      'unlinkDive',
      'reorderCylinders',
      'markAsServiced',
      'clearDefault',
      'replaceBuddyCertifications',
      'retireEquipment',
      'shareWith',
      'shiftDiveTimes',
      'fillNotesIfEmpty',
      'recordConnection',
      'startSession',
      'completeSession',
      'abortSession',
      'cloneTemplate',
      'dissolveSeries',
      'pack',
      'unpack',
      'splitTrack',
    ]) {
      expect(isWriteName(name), isTrue, reason: name);
    }
    for (final name in [
      'getDiveById',
      'recordExists',
      'countDives',
      'watchAll',
      'partitionMediaForDiveDeletion',
    ]) {
      expect(isWriteName(name), isFalse, reason: name);
    }
  });

  Set<String> readBaseline() => File(baselinePath)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();

  /// Whether [method] is exempt, by name or with its whole repository file.
  bool isExempt(String method) =>
      exempt.containsKey(method) ||
      exempt.containsKey('${method.substring(0, method.lastIndexOf(':'))}:*');

  test('every exempt entry names an existing write and a reason', () {
    final found = scanRepositories();
    for (final MapEntry(:key, :value) in exempt.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
      if (key.endsWith(':*')) {
        final file = key.substring(0, key.length - 1);
        expect(found.any((m) => m.startsWith(file)), isTrue, reason: key);
      } else {
        expect(found, contains(key));
      }
    }
  });

  test('no method is both covered and exempt', () {
    expect(covered.keys.where(isExempt), isEmpty);
  });

  test('every repository write is covered or in the baseline', () {
    final found = scanRepositories().where((m) => !isExempt(m)).toSet();
    if (Platform.environment['UPDATE_AGENT_WRITE_BASELINE'] == '1') {
      final lines = found.difference(covered.keys.toSet()).toList()..sort();
      File(baselinePath).writeAsStringSync('${lines.join('\n')}\n');
    }

    final unaccounted = found
        .difference(covered.keys.toSet())
        .difference(readBaseline());

    expect(
      unaccounted,
      isEmpty,
      reason:
          'A repository gained a write no agent can reach. Add a change set '
          'entity for it and list it in covered.',
    );
  });

  test('the baseline names no method that has gone or been covered', () {
    final found = scanRepositories();

    expect(readBaseline().difference(found), isEmpty);
    expect(readBaseline().intersection(covered.keys.toSet()), isEmpty);
    expect(readBaseline().where(isExempt), isEmpty);
  });

  test('every covered method exists', () {
    expect(covered.keys.toSet().difference(scanRepositories()), isEmpty);
  });

  // Every write is covered or exempt, so a new one fails here until it is
  // given a change set entity or a reason.
  test('the baseline is empty', () {
    expect(readBaseline(), isEmpty);
  });

  test('every covered method names an entity an agent can write', () {
    final writable = {
      for (final entry in WriteCatalog(RecordRepositories()).all) entry.name,
    };

    expect(covered.values.toSet().difference(writable), isEmpty);
  });
}

/// Whether a repository method's name says it writes. The verbs are the ones
/// repositories here use for a write, so a new method under any of them is
/// either reached by a write entity or listed in the baseline.
bool isWriteName(String name) =>
    !_readsNamedLikeWrites.contains(name) &&
    RegExp('^(?:${_writeVerbs.join('|')})(?:[A-Z]\\w*)?\$').hasMatch(name);

const _writeVerbs = [
  'create',
  'start',
  'complete',
  'abort',
  'clone',
  'dissolve',
  'pack',
  'unpack',
  'split',
  'add',
  'insert',
  'update',
  'set',
  'save',
  'delete',
  'remove',
  'upsert',
  'bulk',
  'merge',
  'clear',
  'restore',
  'link',
  'unlink',
  'relink',
  'repoint',
  'apply',
  'replace',
  'rename',
  'reorder',
  'undo',
  'mark',
  'write',
  'assign',
  'reassign',
  'unassign',
  'fill',
  'shift',
  'retire',
  'share',
  'unshare',
  'record',
  'stamp',
  'promote',
  'archive',
  'unarchive',
  'toggle',
  'hide',
  'unhide',
  'move',
  'attach',
  'detach',
  'swap',
  'duplicate',
  'reset',
  'dismiss',
  'pin',
  'unpin',
  'purge',
  'prune',
  'wipe',
];

/// Methods whose name starts with a write verb but which only read.
const _readsNamedLikeWrites = {'recordExists'};
