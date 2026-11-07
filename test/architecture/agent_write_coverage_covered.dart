part of 'agent_write_coverage_test.dart';

/// Covered methods no writer names, and the call in a writer that runs
/// them or makes the same edit: the bulk dive edit service the dive page
/// saves through, or the writer's own path for the same record. The guard
/// checks each call is still made, so a writer that stops calling it, or
/// calls another, fails here.
final reachedThrough = <String, String>{
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateFields':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkSetSite':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTags':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveTags':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddDiveTypes':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveDiveTypes':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:bulkAddBuddies':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:bulkRemoveBuddies':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddEquipment':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveEquipment':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddCourses':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveCourses':
      'BulkDiveEditService',
  'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:writeDiverRoles':
      'BulkDiveEditService',
  'lib/features/site_types/data/repositories/site_type_repository.dart:deleteSiteTypesWithLinks':
      'deleteSiteType',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTagsToSites':
      'replaceTags',
  'lib/features/buddies/data/repositories/buddy_repository.dart:setFavorite':
      'updateFields',
  'lib/features/buddies/data/repositories/buddy_repository.dart:toggleFavorite':
      'updateFields',
  'lib/features/buddies/data/repositories/buddy_repository.dart:updateBuddy':
      'updateFields',
  'lib/features/dive_log/data/repositories/dive_custom_field_repository.dart:replaceFieldsForDive':
      'updateCustomField',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createGasSwitch':
      'DiverGasSwitchWriter',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteDive':
      'bulkDeleteDives',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteGasSwitch':
      'DiverGasSwitchWriter',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:insertGasSwitches':
      'DiverGasSwitchWriter',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:setFavorite':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:shiftDiveTimes':
      'bulkShiftDiveTimes',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:toggleFavorite':
      'BulkDiveEditService',
  'lib/features/dive_log/data/repositories/dive_repository_impl.dart:updateDive':
      'BulkDiveEditService',
  'lib/features/tags/data/repositories/tag_link_repository.dart:addTags':
      'BulkDiveEditService',
  'lib/features/tags/data/repositories/tag_link_repository.dart:removeTags':
      'BulkDiveEditService',
  'lib/features/tags/data/repositories/tag_repository.dart:addTagToDive':
      'BulkDiveEditService',
  'lib/features/tags/data/repositories/tag_repository.dart:removeTagFromDive':
      'BulkDiveEditService',
  'lib/features/tags/data/repositories/tag_repository.dart:setTagsForDive':
      'BulkDiveEditService',
  'lib/features/trips/data/repositories/trip_repository.dart:assignDiveToTrip':
      'assignDivesToTrip',
  'lib/features/buddies/data/repositories/buddy_repository.dart:addBuddyToDive':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:addBuddyToDiveWithRoles':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:bulkReplaceBuddies':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:bulkUpdateBuddyRoles':
      'BulkDiveEditService',
  'lib/features/buddies/data/repositories/buddy_repository.dart:removeBuddyFromDive':
      'BulkDiveEditService',
  'lib/features/certifications/data/repositories/certification_repository.dart:replaceBuddyCertifications':
      'createCertification',
  'lib/features/checklists/data/repositories/trip_checklist_repository.dart:clearItems':
      'deleteItem',
  'lib/features/checklists/data/repositories/trip_checklist_section_repository.dart:createSectionRow':
      'applyTemplate',
  'lib/features/checklists/data/repositories/trip_checklists_repository.dart:deleteAllForTrip':
      'deleteTrip',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTags':
      'replaceTags',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTypes':
      'replaceTypes',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTypesToSites':
      'replaceTypes',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:removeTagsFromSites':
      'replaceTags',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:removeTypesFromSites':
      'replaceTypes',
  'lib/features/divers/data/repositories/item_shares_repository.dart:addSharing':
      'setShares',
  'lib/features/divers/data/repositories/item_shares_repository.dart:shareWith':
      'setShares',
  'lib/features/divers/data/repositories/profile_hides_repository.dart:hideAll':
      'hide',
  'lib/features/equipment/data/repositories/equipment_repository_impl.dart:deleteEquipment':
      'deleteOwnedEquipment',
  'lib/features/equipment/data/repositories/equipment_repository_impl.dart:saveAttributes':
      'updateEquipment',
  'lib/features/equipment/data/repositories/service_schedule_repository.dart:applyBaselines':
      'createEquipment',
  'lib/features/planner/data/repositories/dive_plan_mission_store.dart:deleteAll':
      'deletePlan',
  'lib/features/planner/data/repositories/dive_plan_mission_store.dart:recordWrite':
      'savePlan',
  'lib/features/trips/data/repositories/trip_cylinder_repository.dart:createCylinder':
      'createCylinders',
  'lib/features/trips/data/repositories/trip_cylinder_repository.dart:createEvents':
      'writeFills',
  'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:createComputer':
      'createEquipment',
  'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:deleteComputer':
      'deleteOwnedEquipment',
  'lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:updateComputer':
      'updateEquipment',
  'lib/features/dive_log/data/repositories/safety_findings_repository.dart:setDismissedForDives':
      'setDismissed',
  'lib/features/dive_sites/data/repositories/site_classification_repository.dart:relinkForMerge':
      'mergeSites',
  'lib/features/documents/data/repositories/document_repository.dart:deleteForOwner':
      'deleteTrip',
  'lib/features/documents/data/repositories/document_repository.dart:deleteForOwners':
      'deleteBuddy',
  'lib/features/documents/data/repositories/document_repository.dart:saveCardImages':
      'updateCertification',
  'lib/features/gps_log/data/repositories/gps_track_repository.dart:clearTrim':
      'setTrimBounds',
  'lib/features/media/data/repositories/media_color_adjustment_repository.dart:applySlidersToDive':
      'setColorAdjustment',
  'lib/features/media/data/repositories/media_people_buddy_merge.dart:repointMediaPeopleForMerge':
      'mergeBuddies',
  'lib/features/media/data/repositories/media_people_buddy_merge.dart:repointSmartAlbumBuddies':
      'mergeBuddies',
  'lib/features/media/data/repositories/media_repository.dart:deleteMedia':
      'deleteMediaItems',
  'lib/features/media/data/repositories/media_repository.dart:deleteMultipleMedia':
      'deleteMediaItems',
  'lib/features/media/data/repositories/site_attachment_repository.dart:setSiteCategory':
      'setAttachmentDetails',
  'lib/features/media/data/repositories/smart_album_tag_repoint.dart:repointSmartAlbumTags':
      'mergeTags',
  'lib/features/media/data/repositories/smart_album_tag_repoint.dart:repointSmartAlbums':
      'mergeTags',
  'lib/features/planner/data/repositories/dive_plan_dive_links.dart:clearPlanLinksToDives':
      'bulkDeleteDives',
  'lib/features/planner/data/repositories/dive_plan_dive_links.dart:clearPlanLinksToSites':
      'deleteSite',
  'lib/features/planner/data/repositories/dive_plan_mission_store.dart:recordDeletion':
      'deletePlan',
  'lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart:updateItemEquipment':
      'updateTemplate',
  'lib/features/safety/data/repositories/incident_repository.dart:unlinkFromDeletedEquipment':
      'deleteOwnedEquipment',
};

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
    '$gear/equipment_component_repository.dart:$method': 'equipment_components',
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
  for (final method in const ['createPairing', 'deletePairing'])
    '$passports/cylinder_pairing_repository.dart:$method': 'cylinder_pairings',
  '$passports/cylinder_passport_repository.dart:assignPassportId': 'equipment',
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
  for (final method in const ['createDiver', 'updateDiver', 'setDefaultDiver'])
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
  for (final method in const ['setFavoriteComputer', 'setAutoDownloadDisabled'])
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
