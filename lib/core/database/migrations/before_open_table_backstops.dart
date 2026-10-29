part of 'app_database_migrations.dart';

/// The table-creation backstops from v217 on, run in this order from
/// `_beforeOpen`. Split out of before_open.dart, which reached the 800-line
/// limit (issue #2502). Each one is idempotent, so a database that arrives by
/// restore or sync-adopt, or sits above a rung that a parallel branch shipped
/// later, still gains the tables.
extension TableBackstopsFromV217 on AppDatabase {
  Future<void> _tableBackstopsFromV217() async {
    // v217 backstop: site classification tables, seed and indexes
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertSiteClassificationSchema();

    // v219 backstop: the equipment tag junction and its index
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertEquipmentTagSchema();

    // v221 backstop: the rental gear notes table (parallel-branch
    // version-collision self-heal; createTable is idempotent).
    await _assertDiveCenterGearNotesSchema();

    // v232 backstop: the trip cylinder tables and the dive_tanks link
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertTripCylindersSchema();

    // v234 backstop: the equipment sharing tables and the share pair
    // index (parallel-branch version-collision self-heal; all
    // idempotent).
    await _assertEquipmentSharingSchema();

    // v235 backstop: connection_maps and idx_sightings_dive_id
    // (parallel-branch version-collision self-heal; idempotent).
    await _assertConnectionMapsSchema();

    // v238 backstop: re-assert the saved_queries table. A database that
    // arrives by restore or sync-adopt never runs onUpgrade, and one
    // already at 239 or later skips the v238 rung.
    await _assertSavedQueriesSchema();

    // v242 backstop: the equipment service cache (local, idempotent).
    await _assertEquipmentServiceStatusTable();

    // v245 backstop: the certifications buddy index (idempotent).
    await _assertCertificationsBuddyIndex();
    // v247 backstop: the Explore derived metrics (local, idempotent).
    await _assertDerivedMetricsTable();

    // v248 backstop: trip_equipment and its item index (idempotent).
    await _assertTripEquipmentSchema();

    // v312 backstop: dive_tanks.extra_regulator_ids (idempotent; #3375).
    await _assertTankExtraRegulatorIds();

    // v297 backstop: trip_checklist_sections, trip_checklist_items.section_id
    // and the category backfill+drop (idempotent; issue #3360).
    await _assertAndBackfillTripChecklistSections();

    // v298 backstop: checklist_template_sections,
    // checklist_template_items.section_id and the category backfill+drop
    // (idempotent; issue #3360).
    await _assertAndBackfillChecklistTemplateSections();

    // v299 backstop: pre_dive_checklist_template_sections,
    // pre_dive_checklist_template_items.section_id and the section
    // backfill+drop (idempotent; issue #3360). NOT called here: unlike the
    // other three table groups, pre_dive_checklist_templates/items can be
    // recreated from scratch later in this same beforeOpen by
    // _assertPreDiveChecklistSchema's parallel-branch self-heal (v128),
    // using the current table definitions -- which already bake in
    // section_id's foreign key. Running this backstop here, before that
    // self-heal, would see no templates table yet, skip, and leave that
    // self-heal to create the FK column with no sections table for it to
    // reference. Called from before_open.dart instead, right after that
    // self-heal and before _seedBuiltInPreDiveTemplates.

    // v300 backstop: pre_dive_session_sections,
    // pre_dive_session_items.section_id and the section backfill+drop
    // (idempotent; issue #3360).
    await _assertAndBackfillPreDiveSessionSections();

    // v250 backstop: trip_hides and site_hides (idempotent).
    await _assertTripHidesSchema();
    await _assertSiteHidesSchema();

    // v311 backstop: trip_shares and site_shares (idempotent).
    await _assertTripSharesSchema();
    await _assertSiteSharesSchema();

    // v265 backstop: Insights observation dismissals and muted rules.
    await _assertInsightObservationsSchema();

    // v267 backstop: the custom certification tables (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertCustomCertificationSchema();

    // v268 backstop: the equipment location tables (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertEquipmentLocationSchema();

    // v277 backstop: the documents tables (parallel-branch version-collision
    // self-heal; idempotent, schema only, never data).
    await _assertDocumentsSchema();

    // v279 backstop: dive_computer_connections (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertDiveComputerConnectionSchema();

    // v289 backstop: shared library tables and columns (parallel-branch
    // version-collision self-heal, and the columns added to v289 before it
    // shipped; idempotent).
    await _assertSharedLibrarySchema();

    // v301 backstop: the logbook rules tables and indexes (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertRuleSchema();

    // v309 backstop: the media and document tag junctions and their indexes
    // (parallel-branch version-collision self-heal; all idempotent).
    // _beforeOpen asserts the scope columns earlier.
    await _assertMediaAndDocumentTagSchema();

    // v320 backstop: nearby peers and the relay floor (local, idempotent).
    await _assertNearbySchema();

    // v326 backstop: the media_people table and its indexes (idempotent).
    await _assertMediaPeopleSchema();
  }
}
