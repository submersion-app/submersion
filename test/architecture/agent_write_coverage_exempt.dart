part of 'agent_write_coverage_test.dart';

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
    // Gives a cylinder the serial a re-download of its computer reports
    // (issue #4388).
    'lib/features/dive_log/data/repositories/stored_tank_serial_fill.dart:writeStoredTankSerial',
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
    'lib/features/nav_track/data/repositories/nav_track_repository_imports.dart:insertImportedRoute',
    'lib/features/nav_track/data/repositories/nav_track_repository.dart:replace',
    // Re-reads a track's recording from the console file it was imported
    // from (issue #4231).
    'lib/features/nav_track/data/repositories/nav_track_repository_imports.dart:updateImportedData',
    'lib/features/rules/data/repositories/rule_run_repository.dart:deleteAllRuns',
    'lib/features/rules/data/repositories/rule_run_repository.dart:deleteRun',
    'lib/features/rules/data/repositories/rule_run_repository.dart:insertRun',
    'lib/features/rules/data/repositories/rule_run_repository.dart:markUndone',
    'lib/features/tides/data/repositories/tide_record_repository.dart:createFromStatus',
    'lib/features/tides/data/repositories/tide_record_repository.dart:deleteTideRecordForDive',
    'lib/features/tides/data/repositories/tide_record_repository.dart:saveTideRecord',
    // Apple Health readings on a dive (issue #637).
    'lib/features/dive_log/data/repositories/dive_health_record_repository.dart:upsert',
    'lib/features/trips/data/repositories/trip_day_weather_repository.dart:upsert',
    // Fills a set-up transmitter onto the dives an import or merge just
    // wrote; applyToExistingDives is the agent's route (issue #4388).
    'lib/features/transmitters/data/repositories/transmitter_repository.dart:applyToDives',
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
    'lib/features/dive_log/data/repositories/duplicate_cylinder_repository.dart:mergeInto',
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
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:replacePlannedProfile',
  ])
    method: 'a planned dive is made and removed by the planner, from its plan',
  // Draft dives (issue #637).
  for (final method in const [
    'lib/features/dive_log/data/repositories/dive_draft_repository.dart:createDraft',
    'lib/features/dive_log/data/repositories/dive_draft_repository.dart:promoteToLoggedDive',
    'lib/features/dive_log/data/repositories/dive_draft_repository.dart:markDraftComplete',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:promoteToLoggedDive',
  ])
    method:
        'a draft is marked at the site and filled by a download, as a plan is '
        'made by the planner; an agent edits the dive itself through the dive '
        'write family',
  // Profile samples.
  for (final method in const [
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:deleteProfileSeriesWithHistoryForDive',
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
    'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteSeriesWithHistory',
    'lib/features/dive_log/data/repositories/profile_series_repository.dart:deleteUndoneEdit',
    'lib/features/dive_log/data/repositories/profile_series_repository.dart:replaceSamples',
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
