# MCP Server Final PR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every repository write a diver can make in the app is an agent write or a reasoned exemption, and agent access ships without the debug gate.

**Architecture:** One `WritableEntry` per entity in `lib/features/agent_access/data/writes/families/`, registered in `WriteCatalog`, writing through the repository call the app's page uses; shared rules in small `*_rules.dart` files beside the writers. The coverage guard (`test/architecture/agent_write_coverage_test.dart`) covers or exempts every method, and its baseline ends empty.

**Tech Stack:** Dart, Flutter, Drift, flutter_test.

**Spec:** `docs/design/specs/2026-11-04-mcp-server-final-pr-design.md` (approved 2026-11-04), on top of `docs/design/specs/2026-11-01-mcp-server-design.md`.

## Global Constraints

- Issue #4071 (`Refs #4071`), release v1.8.4. Branch `ericgriffin/feat-4071-final`, stacked on #4202, PR to main.
- Every write goes through the repository call the app's page uses (named per task); never a raw SQL write.
- The preview lists exactly what the apply writes: `SideEffects.fields` and `touched`, `createTouched`, `DeleteReach.touched`, `alsoCreates`, `createDefaults` (all from 5c and 5d). A case the preview can see is refused at plan, never thrown at apply.
- Rules read the set as it stands (`SetSoFar`); a change the stored state cannot judge is refused "in a change set of its own".
- Diver delete and diver merge are never agent writes. Credentials, media feed subscriptions, watched folders, media caches and upload or scan stamps are never agent writes.
- Units are stored metric. Calendar days are local midnight (`calendarDay`, `today` in `service_ledger_rules.dart`); true moments are UTC (`FieldCodec.instant`); wall-clock times keep the form each table stores (noted per task).
- No em-dashes or en-dash prose punctuation anywhere, comments and commit messages included. No mention of Claude or Anthropic in repo or GitHub text.
- Files 200 to 400 lines, 800 max; `write_planner.dart` is near 700, so new planner code goes in a part file.
- One commit per task, `feat(agent-access): ...`, body ending `Refs #4071`.
- Before every commit: `dart format` on touched files, `flutter analyze lib/features/agent_access test/features/agent_access` (whole repo before pushing), the task's tests and `test/features/agent_access`.

## Review Focus

1. A writer reached through the wrong repository call (a covered method used where the page uses another, as `dive_writes` does with `bulkUpdateFields`): the coverage guard's `covered` entry names the call each writer makes; Task 23's guard test pins that every `covered` method is called from its writer file.
2. A destructive op previewed without its reach (trip delete cascade, course delete, site merge, media delete with its cloud copy): each delete task has a test that the plan's reach lists the cascaded and unlinked rows the repository removes.
3. A value the store holds in another unit or form than the wire (trip cylinder gas as percent vs fraction, weights in kg, pressures in bar, wall-clock trip return flight): each such task has a round-trip test (write the read value back, plan unchanged).
4. Ownership: a record another profile owns, written by the agent acting as its owner, where the page gates on the active diver (trip `is_shared`, site features `mayEdit`, documents): tests per task.
5. The gate removal: `agentAccessAvailableProvider` true on desktop with debug mode off; Task 24 pins it.

---

### Task 1: Read side fixes and the guard's verbs

**Files:**
- Modify: `lib/features/agent_access/data/documents/media_document.dart` (drop `file_path`, `local_path`, `thumbnail_path`)
- Modify: `lib/features/agent_access/data/documents/track_documents.dart` (add `scale_factor` to nav tracks)
- Modify: `lib/features/agent_access/data/documents/catalog_documents.dart` (add `source_item_id` to pre-dive template items)
- Modify: `lib/features/agent_access/data/documents/training_documents.dart` (add `dive_ids` credited to a course requirement)
- Create: a `safety_findings` read entity in `lib/features/agent_access/data/records/families/dive_records.dart` (child of `dives`; keys `id`, `dive_id`, `rule_id`, `severity`, `dismissed_at` as an instant, plus what the review row holds, read from `safety_findings_repository.dart`)
- Modify: `test/architecture/agent_write_coverage_test.dart` (`isWriteName` also matches `start`, `complete`, `abort`, `clone`, `dissolve`, `pack`, `unpack`, `split`), then regenerate the baseline
- Test: `test/features/agent_access/data/records/` (the matching records tests), `test/architecture/agent_write_coverage_test.dart`

- [ ] Step 1: Failing tests: a media read has no `file_path`, `local_path` or `thumbnail_path`; a nav track read has `scale_factor`; a pre-dive cell linearity item has `source_item_id`; a requirement read lists its credited `dive_ids`; a dive's safety findings read with `dismissed_at`.
- [ ] Step 2: Run them. Expected: FAIL.
- [ ] Step 3: Implement; widen `isWriteName`; run `UPDATE_AGENT_WRITE_BASELINE=1 flutter test test/architecture/agent_write_coverage_test.dart` and check the new baseline lines are exactly `startSession`, `completeSession`, `abortSession` (pre_dive_session_repository), `cloneTemplate` (pre_dive_template_repository), `dissolveSeries` (dive_plan_series_repository), `pack`, `unpack` (trip_equipment_repository), `splitTrack` (gps_track_repository), plus any other a new verb catches (each one is then covered or exempted by a later task).
- [ ] Step 4: Run the records tests and the guard. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): read side fixes for the final writes`.

### Task 2: Equipment observations (gear 5e)

**Files:** Create `families/equipment_observation_writes.dart`; Test `test/features/agent_access/data/writes/equipment_observation_writes_test.dart`.

**Interfaces:** entity `equipment_observations`, `ChildOf(entity: 'equipment', field: 'equipment_id')`; repository `EquipmentObservationRepository` `create`, `update`, `delete` (`lib/features/equipment/data/repositories/equipment_observation_repository.dart`).

Fields: `equipment_id`, `dive_id` (reference `dives`, nullable), `status` (`ok` or `issue`), `issue_tags` (`FieldCodec.textList`, each one of `observationTagsFor(item.type)`), `note` (trim, blank allowed), `observed_at` (the stored wall-clock-as-UTC form; default the dive's `defaultObservedAt` when a dive is named, else now as wall clock; `equipment_observation_sheet.dart:204-206`).

Rules:
- An issue names at least one tag; ok carries none (refuse tags on ok) (`equipment_observation_sheet.dart:224-235`).
- `diver_id` is the owner on create; an update keeps it.
- `createDefaults`: `observed_at` when not named.
- `touched` (update to ok) and `DeleteReach.touched`: the incidents `_unlinkIncidents` clears (`equipment_observation_repository.dart:169-190`), as `{'incidents': n}`.
- `afterApply`: `scheduleConditionFindingsRefresh` for each item once per run (`ApplyRun.once`), as the sheet does after every save and delete (`:263`, `:82`); pass the scheduler in as a callback built in the provider layer, like `GearReminderRefresh`.

- [ ] Step 1: Failing tests: `an observation is logged, edited and deleted`; `an issue needs a tag of the item's type` (no tags, and a tag of another type, are `invalidValue`); `turning an issue to ok lists the incidents it unlinks`; `observed_at defaults to the dive's exit time`; `the findings refresh runs once per item`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement and register.
- [ ] Step 4: Run, with `test/features/agent_access`. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for equipment observations`.

### Task 3: Cylinder fills and passport ids (gear 5e)

**Files:** Create `families/cylinder_fill_writes.dart`; modify `families/equipment_writes.dart` (a `passport_id` field); Test `cylinder_fill_writes_test.dart`, `equipment_passport_test.dart`.

**Interfaces:**
- Entity `cylinder_fills`, `ChildOf(entity: 'equipment', field: 'equipment_id')`; `CylinderFillRepository` `create`, `update`, `delete` (`lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart`).
- `passport_id` on equipment through `CylinderPassportRepository.assignPassportId` (`cylinder_passport_repository.dart:136-197`); `ensurePassportId` when a fill's tank has none.

Fill fields: `o2_percent` and `he_percent` (`CylinderFill.isPossibleMix`: 0 < O2 <= 100, 0 <= He <= 100, sum <= 100; required on create, defaults 21 and 0 as `createDefaults`), `filled_at` (local moment as the store keeps it, `cylinder_fill_repository.dart:315`; default now as `createDefaults`), `pressure_bar` (0 to 400, nullable), `temperature_c` (-30 to 60, nullable), `analyzer`, `station_name` (trim, blank = null), `notes` (trim). `source` is `manual`.

Rules:
- The item is a tank (`type == tank`), else `invalidValue`.
- A tank with no passport id: `alsoCreates` lists `{'equipment_attributes': 1}` and `create` calls `ensurePassportId` first, as the blender does (`blender_procedure_card.dart:134-137`).
- `passport_id` on an equipment update: a lower-case UUID (`passport_payload_codec.dart:67-73`), tank items only; refused (`duplicateRecord`) while another in-service item the owner sees holds it (`PassportIdInUse` rule, `cylinder_passport_repository.dart:116-157`); `touched` lists the fills it relinks and the holders it releases. It is a system attribute, so 5c's attribute list keeps leaving it out.

- [ ] Step 1: Failing tests: `a fill is logged, edited and deleted`; `an impossible mix is refused` (O2 0, sum 101); `a fill on a tank with no passport mints one, listed`; `a fill on a non-tank is refused`; `a passport id is assigned and its fills follow`; `a passport id another in-service tank holds is refused`; `a pressure above 400 bar is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for cylinder fills and passport ids`.

### Task 4: Transmitter keys (gear 5e)

**Files:** Create `families/transmitter_writes.dart`, `families/transmitter_rules.dart`; Test `transmitter_writes_test.dart`.

**Interfaces:** entity `transmitters`, `ChildOf(entity: 'equipment', field: 'transmitter_equipment_id')`; `saveTransmitterKey` (`lib/features/transmitters/data/services/transmitter_key_adoption.dart:17-30`) then `TransmitterRepository.saveSetup(..., exceptKeyId:)` (`transmitter_repository.dart:81-110`), as the edit page saves (`transmitter_edit_page.dart:331-350`); `delete` (`:358-364`); `applyToExistingDives` (`:446-523`) and `previewApplyToExistingDives` (`:428-437`).

Fields: `serial` (trim; blank or all zeros = none), `dive_computer_id` (reference `dive_computers`, the owner's), `channel` (1-based on the wire, 0-based in the store, `transmitter_edit_page.dart:136,314`), `role`, `equipment_id` (the cylinder: an in-kit tank, `equipment_picker_sheet.dart:210-224`), `volume_l`, `working_pressure_bar` (> 0 when named), `material`, `preset_name`, `apply_to_existing_dives` (flag, write-only).

Rules:
- A key is a serial or a computer with a channel >= 1 (`transmitter_edit_page.dart:282-288`), else `invalidValue`.
- The item is a transmitter (`type == transmitter`).
- `uniqueKey`: the normalized serial per owner, and `computer/channel` per owner; stored conflicts (`_checkConflicts`, `transmitter_repository.dart:605-623`) are `duplicateRecord` naming the holder, including an unconfigured key (no takeover; the agent updates that key instead).
- `label` is not writable (it follows the item name).
- Setup fields apply to every key of the item: `touched` lists `{'transmitters': n}` for the other keys `saveSetup` rewrites.
- An empty item serial takes the key's serial (`transmitter_edit_page.dart:369-372,431-450`): listed as `{'equipment': 1}`.
- `apply_to_existing_dives: true`: `touched` adds `{'dive_tanks': n}` from `previewApplyToExistingDives`; `update` runs `applyToExistingDives` for every key of the item inside the apply (so the change log reverts it).
- `afterApply`: the condition findings refresh for the item (`transmitter_edit_page.dart:331-350`), once per run.

- [ ] Step 1: Failing tests: `a key is added, edited and removed`; `a key needs a serial or a computer channel`; `a serial another key holds is a duplicate, unconfigured too`; `setup fields apply to every key of the item, listed`; `an empty item serial takes the key's`; `apply to existing dives fills past tanks and is listed and revertible`; `channel 1 on the wire is 0 in the store`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for transmitter keys`.

### Task 5: Trips

**Files:** Create `families/trip_writes.dart`, `families/trip_rules.dart`; Test `trip_writes_test.dart`.

**Interfaces:** entity `trips`; `TripRepository.createTrip`, `updateTrip`, `deleteTrip` (`lib/features/trips/data/repositories/trip_repository.dart:128,197,331`); relations `dive_ids` (`assignDivesToTrip` :614; removal through the dive's trip field, Task 12) and `equipment_ids` (`TripEquipmentRepository.pack` :40 and `unpack` :69).

Fields as `tripDocument` keys: `name` (required, trim), `trip_type`, `start_date` and `end_date` (the form the document writes; 1950 to 2100; end not before start, a dayTrip has end = start, `trip_edit_page.dart:357,939-953`), `location`, `resort_name`, `liveaboard_name` (blank = null), `notes` (trim, blank kept), `expected_dives`, `expected_runtime_minutes`, `dives_per_day_target` (integers > 0 or null), `divers_sharing_cylinders` (integer >= 1, default 1 as `createDefaults`), `return_flight_time` (wall-clock-as-UTC, `trip_edit_page.dart:984`), `parent_trip_id` (reference `trips`; refused where `side_trip_links.dart:94-112` would null it: itself, a side trip, a trip with side trips), `is_shared` (only the owner; refused otherwise, `trip_repository.dart:203-211`).

Rules:
- Delete as the owner (`shared_item_policy.dart:27-33`); `DeleteReach` lists the cascade of `trip_repository.dart:354-380` (itinerary days, liveaboard details, checklists, cylinders, events, weather, equipment links, side trips detached, dives unlinked).
- `dive_ids` add: `touched` lists the date stretch (`trip_date_stretch.dart:25-75`) as `{'trips': n}` when it moves the trip's or its parent's dates, and cleared foreign cylinder links as `{'dive_tanks': n}`.
- An update with a new parent lists cleared foreign cylinder links (`:253-263`); a date change lists plan-only itinerary days it deletes (`:274-278`) under `DeleteReach`-style `touched`.
- A trip type change away from liveaboard deletes its liveaboard details, as the save does (`trip_edit_page.dart:1176-1182`): listed; a new liveaboard trip generates its itinerary days (`:1130-1175`): `alsoCreates`.
- No implicit dive assignment (the page's candidate scan is the diver's choice).

- [ ] Step 1: Failing tests: `a trip is created, edited and deleted with its cascade listed`; `end before start is refused`; `a side trip cannot have side trips`; `only the owner changes is_shared`; `assigning dives stretches the trip, listed`; `a new liveaboard trip lists the days it generates`; `the return flight round-trips as wall clock`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for trips`.

### Task 6: Liveaboard details and itinerary days

**Files:** Create `families/trip_day_writes.dart`; Test `trip_day_writes_test.dart`.

**Interfaces:**
- `liveaboard_details`, child of `trips` (`trip_id`); `LiveaboardDetailsRepository.createOrUpdate` (:47), as one record per trip: create when none, update otherwise; refused unless the trip is a liveaboard.
- `itinerary_days`, child of `trips`; `ItineraryDayRepository.updateDay` (:115), `setPlannedDives` (:161), and create through `saveAll` (:56) for a date the trip has no day for.

Rules:
- Liveaboard: `vessel_name` required; `vessel_type` one of catamaran, motorYacht, sailingYacht, other; `capacity` integer > 0 or null; other text blank = null (`trip_edit_page.dart:566-616,1144-1157`). The embark and disembark coordinates are not writable (the page clears them on every save; filed as an app bug), so a save writes what the page writes.
- Itinerary: `day_type` travel, diveDay, rest for every trip, plus embark, disembark, seaDay, portDay on a liveaboard (`itinerary_day_edit_sheet.dart:86-96`); `planned_dives` 0 to 12 (`kMaxPlannedDivesPerDay`); rest forces 0 (a derived field listed); `port_name` blank = null; `notes` trim. `date`, `day_number` and coordinates are not writable on update.
- A create names `date`, a day of the trip with no row yet (no duplicate dates), `day_number` derived as days from the trip start plus 1 (`trip_fill_forecast_strip.dart:213-237`).

- [ ] Step 1: Failing tests: `a liveaboard's details are written and edited`; `details on a non-liveaboard trip are refused`; `a day is edited and rest forces no dives, listed`; `a liveaboard-only day type on a dive trip is refused`; `a day is added for a trip date with none, and a second for that date is a duplicate`; `planned dives above 12 are refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for liveaboard details and itinerary days`.

### Task 7: Trip cylinders and their events

**Files:** Create `families/trip_cylinder_writes.dart`; Test `trip_cylinder_writes_test.dart`.

**Interfaces:** `trip_cylinders` (child of `trips`): `TripCylinderRepository.createCylinders` (:296, one per create), `updateCylinder` (:202), `deleteCylinder` (:244), `reorderCylinders` (:397, through `sort_order` as 5c's components do). `trip_cylinder_events` (child of `trip_cylinders`): `createEvents` (:379) for a fill, `createEvent` (:509) for an adjustment, `updateEvent` (:529), `deleteEvent` (:579).

Rules:
- Cylinder: `label` required; size and working pressure > 0 when named, stored litres and bar (`trip_cylinder_specs_input.dart:53-71`); an owned tank is an in-kit `tank` item not already on the board (`add_trip_cylinders_sheet.dart:118-121`); `sort_order` a position the board holds, refused on create.
- Event: gas on the wire as fractions 0 to 1 (as `trip_documents.dart:82-85` reads), stored as percent; a fill needs pressure >= 1 bar, O2 1 to 100, He 0 to 99, sum <= 100, defaults O2 21 He 0, analysed He needs analysed O2 (`trip_cylinder_fill_sheet.dart:26-27,265-292`); an adjustment's mix is optional, He without O2 refused (`trip_cylinder_adjust_sheet.dart:89-118`); `currency` only with a cost, upper-cased, default USD; `occurred_at` wall-clock-as-UTC, 2000 to 2100.
- A fill on the owner's own cylinder copies to its passport (`trip_cylinder_fill_sheet.dart:337-343`): `alsoCreates` `{'cylinder_fills': 1}`; deleting such a fill deletes the copy: `DeleteReach.records`.
- A cylinder delete lists its tank links and events (`:244-268`).

- [ ] Step 1: Failing tests: `a cylinder is added, edited, moved and removed with its events listed`; `a fill writes percent from fractions and round-trips unchanged`; `a fill below 1 bar is refused`; `analysed helium without oxygen is refused`; `a fill on an own cylinder lists its passport copy`; `an owned tank already on the board is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for trip cylinders and fills`.

### Task 8: Trip checklists

**Files:** Create `families/trip_checklist_writes.dart`, `families/checklist_rules.dart`; Test `trip_checklist_writes_test.dart`.

**Interfaces:**
- `trip_checklists` (child of `trips`): `TripChecklistsRepository.createChecklist` (appends), `renameChecklist`, `deleteChecklist` (cascade listed), `reorderChecklists` through `sort_order`.
- `trip_checklist_sections` (child of `trip_checklists`): `createSection`, `renameSection` (blank or unchanged refused), `reorderSections` through `sort_order`, `deleteSection` (refused for the last section; a delete moves the items to the adjacent section unless `delete_items: true`, as `section_list_editor.dart:264-304`).
- `trip_checklist_items` (child of `trip_checklists`): `createItem` (appends), `updateItem`, `toggleDone` through `is_done` (stamps `completed_at`, listed), `moveItem` through `sort_order` and `section_id`, `deleteItem`.
- Template ops on `trip_checklists`: create with `from_template_id` (`applyTemplate`, idempotent per (title, section), items' due dates from the trip start minus the offset, `trip_checklist_repository.dart:454-528`), update with `replace_with_template_id` (`replaceWithTemplate`, lists the items and sections it drops), and `save_as_template_name` on update (`saveAsTemplate`: `alsoCreates` a `checklist_templates` record).

Rules: names and titles required and trimmed; a section is named by its id on the wire (the page's find-or-create by title is a UI convenience).

- [ ] Step 1: Failing tests: `a checklist is created, renamed, reordered and deleted with its items listed`; `an item is added, done, moved and deleted`; `the last section cannot be deleted`; `applying a template twice adds nothing the second time`; `replacing with a template lists what it drops`; `saving as a template lists the template it adds`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for trip checklists`.

### Task 9: Divers and weight entries

**Files:** Create `families/diver_writes.dart`, `families/weight_entry_writes.dart`; Test `diver_writes_test.dart`, `weight_entry_writes_test.dart`.

**Interfaces:** `divers`: `DiverRepository.createDiver`, `updateDiver` (writes the whole row: read, change, write back, `diver_repository.dart:386-411`); `is_default` through `setDefaultDiver` only (true only; clears the others: `touched`). No delete (refused `notPermitted`: "deleting a profile is done in the app"). `weight_entries` (child of `divers`): `DiverWeightEntryRepository.createEntry`, `deleteEntry`; `updateEntry` too (no UI caller: a ruling to allow it as the same row).

Rules:
- Diver: `name` required, trim; `email` contains "@" and "." when named; email, phone, handle, emergency contacts, blood type, allergies, medications trim, blank = null; `medical_notes` and `notes` trim, never null; `prior_dive_count` >= 0; prior time as seconds from hours >= 0 and minutes 0 to 59; `diving_since` a year 1900 to now (`prior_experience_edit_page.dart:117-127,236-284`). Create makes its diver_settings in the same transaction (`alsoCreates` `{'diver_settings': 1}`). The photo is not writable (bytes).
- Weight entry: `weight_kg` required, > 0; `height_cm` optional; `measured_at` 1950 to today, in the form the store holds (local midnight when picked; the read document prints an instant: a ruling to write the day as local midnight and read it back as the document does).

- [ ] Step 1: Failing tests: `a diver is created with settings listed, and edited`; `a diver delete is refused`; `making a diver the default lists the one it takes over from`; `an email without a dot is refused`; `minutes above 59 are refused`; `a weight entry is logged, edited and deleted`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for divers and weight entries`.

### Task 10: Certifications and currency

**Files:** Create `families/certification_writes.dart`, `families/currency_writes.dart`; Test `certification_writes_test.dart`, `currency_writes_test.dart`.

**Interfaces:** `certifications`: `CertificationRepository.createCertification`, `updateCertification`, `deleteCertification`. `currency_rules`: `createRule`, `updateRule`, `deleteRule`. `currency_prefs`: `upsertPref` (one per certification and rule; a reset writes nulls). `currency_events`: `createEvent`, `deleteEvent` (no update).

Rules:
- Certification: a title or a level required; agency default PADI (`createDefaults`); card and instructor fields trim, blank = null; issue and expiry days 1950 to 2100 (local midnight); a diver's or a buddy's, never both (`certification_repository.dart:244-248`); `instructor_id` one of the owner's buddies, copying name and card number (listed as derived fields); card photos not writable. Delete lists currency prefs, events and documents (`:375-399`) and the course refresh.
- Currency rule: name required; lapse integer >= 1; lead integer 0 to lapse; dive types and modes only for the activity clock; a built-in rule is never edited or deleted: an update of a built-in creates the custom copy that supersedes it, as the page does (`currency_rule_edit_dialog.dart:54,118-140`): listed as `alsoCreates`.
- Currency pref: lapse >= 1 and not shorter than the rule's lead when lead is blank, lead <= lapse; `card_expiry` has no lapse; muted flag.
- Currency event: type default refresher (activity) or renewal (date); date 1950 to today; provider trim, blank = null.

- [ ] Step 1: Failing tests: `a certification is created, edited and deleted with its currency listed`; `a certification with neither title nor level is refused`; `an instructor copies the buddy's name`; `editing a built-in rule adds its custom copy`; `a lead above the lapse is refused`; `an event in the future is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for certifications and currency`.

### Task 11: Courses and requirements

**Files:** Create `families/course_writes.dart`; Test `course_writes_test.dart`.

**Interfaces:** `courses`: `CourseRepository.createCourse`, `updateCourse`, `deleteCourse`; relation `certification_ids` (`setCourseCertifications`, which can move a certificate off another course: listed). `course_requirements` (child of `courses`): `createRequirement`, `updateRequirement`, `deleteRequirement`, `setChecklistComplete` through `completed_at`; relation `dive_ids` (`linkDive`, `unlinkDive`; a dive credits at most one requirement per course, of the course's diver, `course_requirement_repository.dart:353-382,505-545`); course create with `from_template` (`applyTemplate`, appends; refused when the course already has requirements, since a second apply duplicates).

Rules: course name required; agency default PADI; completion not before start; instructor from the owner's buddies; delete lists documents, dive links, certification course ids and requirements (`course_repository.dart:420-497`). Requirement name required; kind dive or checklist; `target_count` >= 1 for dive only; kind to dive clears `completed_at` (derived, listed).

- [ ] Step 1: Failing tests: `a course is created, edited and deleted with its reach listed`; `completion before start is refused`; `a requirement is added, credited a dive and ticked`; `a dive credits one requirement per course`; `certifications moved off another course are listed`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for courses and requirements`.

### Task 12: Dive and site relations the writers lack

**Files:** Modify `families/dive_writes.dart`, `families/site_writes.dart`, `families/trip_writes.dart`; create `families/item_share_rules.dart`; Test `dive_relation_writes_test.dart`, `site_relation_writes_test.dart`.

**Interfaces:**
- Dives: `buddy_roles` (an object of buddy id to role list, through `setBuddiesForDive` semantics as the dive edit page saves, `dive_edit_page.dart:6562`; `bulkUpdateBuddyRoles` covers the bulk form); `trip_id` field (through `updateDive`'s trip with `stretchToCoverDives`, `dive_edit_page.dart:1669,6674-6683`, listed).
- Sites: `site_type_ids` relation (`replaceTypes` through `updateSite`'s classification, `site_repository_impl.dart:89`).
- Trips and sites: `shared_with` relation (`ItemSharesRepository.setSharing`, refused when the acting owner may not change it, `item_shares_repository.dart:178-191`) and `hidden_for` (per profile, `ProfileHidesRepository.hide`/`unhide`; refused on the owner's own or unshared items).

- [ ] Step 1: Failing tests: `a dive's buddies are set with roles`; `moving a dive to a trip stretches the trip, listed`; `a site's types are replaced`; `a trip is shared and a site hidden for a profile`; `hiding an unshared site is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): dive, site and trip relations for agents`.

### Task 13: Checklist and pre-dive templates

**Files:** Create `families/checklist_template_writes.dart`, `families/pre_dive_template_writes.dart`; Test matching tests.

**Interfaces:** `checklist_templates`: `ChecklistTemplateRepository.createTemplate`, `updateTemplate`, `deleteTemplate`, with sections and items as whole lists (`saveSections` then `saveItems`, replace-all in display order, `checklist_template_edit_page.dart:202-217`), as 5c's attributes and geofences are. `pre_dive_templates`: the same shape through `PreDiveTemplateRepository`, plus create with `clone_of` (`cloneTemplate`).

Rules: names and item titles required; checklist `due_offset_days` integer >= 0; pre-dive built-ins read-only (`_assertNotBuiltIn`, `pre_dive_template_repository.dart:631-637`) except clone; pre-dive value bounds numeric and only for value and cellLinearity items, min <= max (a ruling: the editor does not check it, the agent does); cellLinearity needs `source_item_id`; equipment links only on equipment items; `strict_order` flag.

- [ ] Step 1: Failing tests: `a checklist template is written with sections and items in order`; `a pre-dive built-in is refused but can be cloned`; `a cell linearity item needs its source item`; `bounds on a check item are refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for checklist and pre-dive templates`.

### Task 14: Pre-dive sessions

**Files:** Create `families/pre_dive_session_writes.dart`; Test `pre_dive_session_writes_test.dart`.

**Interfaces:** `pre_dive_sessions`: create through `startSession` from `template_id` (with `equipment_set_id`; a fresh snapshot through `SessionItemComposer`, `start_session_sheet.dart:121-162`; the remembered equipment written back to a non-built-in template: listed), update `status` to completed (`completeSession`, every required item done or flagged, `checklist_session_engine.dart:33`) or aborted (`abortSession`), `dive_id` (`linkToDive`, `unlinkFromDive`; allowed when locked; a dive with a run already is refused), `deleteSession`. Session items through an `items` whole-state list on update, each through `updateItemState` (refused once locked, `pre_dive_session_repository.dart:615-621`; strict order: only the next pending item).

- [ ] Step 1: Failing tests: `a session starts from a template and runs to complete`; `completing with a required item pending is refused`; `a locked session refuses item changes but links to a dive`; `strict order refuses an item out of turn`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for pre-dive sessions`.

### Task 15: Dive plans and series

**Files:** Create `families/dive_plan_writes.dart`; Test `dive_plan_writes_test.dart`.

**Interfaces:** `dive_plans`: `DivePlanRepository.savePlan` (create and update, whole plan with `tanks` and `segments` as lists in the document's shape; summary numbers come from the planner's outcome as `createDefaults`/derived fields, computed through the planner service the canvas uses, `plan_canvas_page.dart:572-582`), `deletePlan`, create with `duplicate_of` (`duplicatePlan`), `linked_dive_id` (`linkPlanToDive`; one plan per dive: other plans on that dive listed as `touched`; `unlinkPlan`). `dive_plan_series`: `saveSeries`, `renameSeries`, `deleteSeries`, create with `duplicate_of` (`duplicateSeries`), and `dissolveSeries` on update `dissolve: true`.

Rules: plan name required (trim); no gas or deco validation, as the app; references to a site or dive that no longer exist are refused at plan rather than dropped silently by the save (`dive_plan_repository.dart:381-421`); a series' removed dives are listed as deleted.

- [ ] Step 1: Failing tests: `a plan is saved, renamed, duplicated and deleted`; `linking a plan to a dive lists the plan it takes the dive from`; `a series removing a dive lists that plan's delete`; `a plan naming a missing site is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for dive plans and series`.

### Task 16: Rules, saved queries and connection maps

**Files:** Create `families/rule_writes.dart`, `families/saved_view_writes.dart`; Test matching tests.

**Interfaces:** `rules`: `RuleRepository.create`, `update`, `delete`, `setEnabled` through `enabled`, `reorder` through `sort_order`, create with `duplicate_of`. `saved_queries`: `create`, `rename`, `updateQuery` (through `query`), `reorder`, `delete`. `connection_maps`: `create`, `rename`, `updateSpec`, `delete`.

Rules:
- Rule: name required; at least one action; condition parsed and validated as the editor does (versioned query-node JSON, empty = match all); subject fixed after create; triggers subset of afterImport, afterManualCreate (default afterImport); a read-only rule (newer version or unknown action) is refused (`rule_edit_page.dart:61-70`). Saving never runs a rule.
- Saved query: name required; `query` text parsed and checked with `validateQuery` (`core/query/presentation/query_text_field.dart:260-271`), stored flattened (`save_query_flow.dart:45`).
- Connection map: name required; `spec` as `MapSpec` (minSharedDives 1 to 10; links of unselected kinds dropped, as derived fields).

- [ ] Step 1: Failing tests: `a rule is created, disabled, reordered and deleted`; `a rule with no action is refused`; `a rule's condition that does not parse is refused`; `a saved query that does not validate is refused`; `a connection map's spec is clamped, listed`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for rules, saved queries and connection maps`.

### Task 17: Site features, incidents and emergency chambers

**Files:** Create `families/site_feature_writes.dart`, `families/safety_writes.dart`; Test matching tests.

**Interfaces:** `site_features` (child of `sites`): `SiteFeatureRepository.addFeature`, `updateFeature`, `deleteFeature`. `incidents`: `IncidentRepository.createIncident`, `updateIncident`, `deleteIncident`. `emergency_chambers`: `createChamber`, `deleteChamber` (no update).

Rules:
- Feature: `type` from `SiteFeatureType` (default wreck), `latitude` and `longitude` required on create and not writable after, name and notes trim, bearing normalized `% 360` (derived), depth metres; `mayEdit` on the site (`site_feature_repository.dart:40,183,216`): refused at plan, never a silent no-op.
- Incident: narrative required; category default other, severity default minor; `occurred_at` a day 1970 to today; contributing factors and lessons blank = null; an observation link only while that check-in is an issue; `afterApply` the condition findings refresh for old and new items.
- Chamber: name, country (2 letters, upper-cased), phone required; city and notes blank = null; a built-in is never deleted (hidden in Settings instead).

- [ ] Step 1: Failing tests: `a feature is added, edited and removed`; `a feature on a site the owner may not edit is refused`; `an incident is logged, edited and deleted`; `an incident linked to an ok check-in is refused`; `a chamber is added and deleted; a built-in is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for site features, incidents and chambers`.

### Task 18: Dive computer settings and safety finding dismissals

**Files:** Create `families/dive_computer_writes.dart`, `families/safety_finding_writes.dart`; Test matching tests.

**Interfaces:** `dive_computers` update only: `is_favorite` true through `setFavoriteComputer` (clears the owner's others: `touched`; false refused, as the star has no un-favourite), `auto_download_disabled` through `setAutoDownloadDisabled`; rename, notes and delete stay with the gear item (refused naming the gear item). `safety_findings` (Task 1's read entity) update only: `dismissed` flag through `setDismissed` (marks the dive pending: listed).

- [ ] Step 1: Failing tests: `a computer becomes the favourite, listing the one it replaces`; `renaming a computer points to its gear item`; `a finding is dismissed and restored`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for computer settings and finding dismissals`.

### Task 19: GPS tracks and nav tracks

**Files:** Create `families/track_writes.dart`; Test `track_writes_test.dart`.

**Interfaces:** `gps_tracks` update and delete: `trim_start` and `trim_end` through `setTrimBounds` (wall-clock-as-UTC ms; start before end, both inside the track's span; nulls reset), `split_at` through `splitTrack` (`alsoCreates` `{'gps_tracks': 1}`), `deleteTrack` with the geometry cache evicted in `afterApply` (`gps_track_map_providers.dart:157-163`). `nav_tracks`: `rename` (blank = null), `setSite`, `setEquipment` (id with its name), `updateCorrection` (scale 0.25 to 4, heading -180 to 180, trust 0 to 1), `setPrimary` (needs a dive), `dive_id` through `link` (manual; becomes primary when the dive has none; inherits site and anchor: derived fields) and `unlink` (promotes a sibling: `touched`), `delete` (promotes a sibling).

- [ ] Step 1: Failing tests: `a GPS track is trimmed, split and deleted`; `a trim outside the track is refused`; `a route is linked, made primary, corrected and unlinked`; `a scale of 5 is refused`; `deleting a primary route promotes its sibling, listed`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for GPS and nav tracks`.

### Task 20: Documents and smart albums

**Files:** Create `families/document_writes.dart`, `families/smart_album_writes.dart`; Test matching tests.

**Interfaces:** `documents`: `DocumentMutations.save` semantics through `DocumentRepository.save` (metadata only: no pages, no bytes), `delete`; tags through the `tag_ids` relation (`replaceTags`); `afterApply` re-arms expiry reminders through a provider-built callback (as `rearmDocuments`). `smart_albums`: `create`, `rename`, `delete`; `filter` as the `MediaLibraryFilter` JSON, non-empty.

Rules: title trim (blank allowed); expiry null for certification cards; phone, emergency phone and `is_primary` only for insurance; `is_primary` clears the other primaries (`touched`); a delete lists its pages and cancels reminders. Album name required and trimmed.

- [ ] Step 1: Failing tests: `a document's details are written and it is deleted with its pages listed`; `is_primary on a non-insurance document is refused`; `making a document primary lists the one it takes over from`; `a smart album is created, renamed and deleted`; `an empty filter is refused`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for documents and smart albums`.

### Task 21: Media

**Files:** Create `families/media_writes.dart`, `families/media_rules.dart`; Test `media_writes_test.dart`.

**Interfaces:** `media` update and delete, never create:
- `manual_elapsed_s` through `setManualElapsedSeconds` (needs a dive; 0 to the dive's profile length, `set_media_time_dialog.dart:63-78`).
- `dive_id` through `reassignMediaToDive` (lists the enrichment rows it drops, `media_repository.dart:549-568`).
- `people` (a whole list of tags, each a buddy or a diver with an optional box and video position) through `MediaPeopleRepository.addTag`, `updateTag`, `removeTag` (a person once per photo, `media_people_repository.dart:92-114`).
- `species_ids` relation through `SpeciesTaggingService` (a new tag on a dive photo adds the dive's sighting if none: `alsoCreates`).
- `color_adjustment` (sliders -1 to 1, strength 0 to 1, white point 0 to 1, `color_adjustment.dart:109-134`) through `setColorAdjustment`.
- `attachment_category` and `attachment_display_size` through `setAttachmentDetails` (site attachments only).
- Delete through `MediaUnlinkService` / `MediaDeletionCoordinator` with the remote delete held (`holdRemoteDelete: true`), never `deleteMedia` alone; `DeleteReach` lists tags, people, species links and the cloud copy.

Rules: every write is refused on the web build when `DeviceCapabilities.mediaAttach` is false (`media_viewer_toolbar.dart:154-198`); caption, favourite, file fields, and create by URL are not writable.

- [ ] Step 1: Failing tests: `a photo is pinned to a moment, moved to another dive and deleted`; `a pin past the dive's end is refused`; `a person is tagged once per photo`; `a species tag on a dive photo lists the sighting it adds`; `a colour slider of 2 is refused`; `a delete holds the cloud delete and lists the links it drops`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent writes for media`.

### Task 22: Site, buddy and dive computer merges

**Files:** Modify `families/site_writes.dart`, `families/buddy_writes.dart`, `families/dive_computer_writes.dart`; Test `merge_writes_test.dart`.

**Interfaces:** the 5b merge machinery (`mergeable`, `mergeReach`, `merge`, `DeleteReach.survivor`, `basis`) as tags use it: a delete naming `merge_into`. Sites through `SiteRepository.mergeSites` (at most one site the owner does not own, and it is the survivor; a duplicate not the owner's to delete is refused, `site_repository_impl.dart:930-992`); buddies through `BuddyMergeRepository.mergeBuddies` (first id survives); computers through `DiveComputerMergeRepository.mergeComputers` (a serial mismatch is a warning in the plan's context, not a block). Each `mergeReach` lists the links it moves, by table, and what it changes on the survivor.

- [ ] Step 1: Failing tests: `two sites merge into one with every link listed`; `a site of another profile can only survive a merge`; `two buddies merge`; `two computers merge with their dives listed`; `a merge reverts through the change log`.
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Implement.
- [ ] Step 4: Run. Expected: PASS.
- [ ] Step 5: Commit `feat(agent-access): agent merges for sites, buddies and dive computers`.

### Task 23: Every other method exempt, and the baseline empty

**Files:** Modify `test/architecture/agent_write_coverage_test.dart`, `test/architecture/agent_write_coverage_baseline.txt`.

Exemptions, each with its reason (grouped `for` entries as 5c and 5d wrote them):
- Inner steps, naming the caller: every `clear*Links`, `restore*`, `undo*`, `relink*`, `repoint*`, `deleteByTripId`, `deleteFor*`, `deleteAllForTrip`, `detachSideTripsForDelete`, `deleteBarePlanDaysOutside`, `unlinkFromDeleted*`, `deleteDiverOwnedRows`, `deleteDiverRows`, `clearDiveLinksToDiverRows`, `retireDiverServiceKinds`, `retireDiverEquipmentLocations`, `writeBuddyRoles`, `deleteBuddyRoles*`, the media people and smart album repoints, `saveCardImages`, `createSectionRow`, the plan mission store, `updateItemEquipment`.
- Imports, devices, derived: profile and tank pressure series, derived metrics, imported metadata, fill-if-empty, source clocks, tank role repair undo, tide records, trip day weather, safety reviews (`saveReview`), rule runs, `createComputer`, `updateComputer`, `updateLast*`, `insertTanks`, GPS track import, nav route import and replace, media enrichment and suggestions, `addBuddyToDive`, legacy buddy conversion, `shareWith`.
- Bulk shortcuts, naming the write they repeat: bulk dive edits (tags, types, courses, equipment, tanks, weights, notes, roles), `bulkDeleteSites`, `bulkDeleteBuddies`, `addSharing`, `hideAll`, `applySlidersToDive`, `setSiteCategory`, `addTags`/`removeTags`, `bulkAddSightings`, `bulkReplaceSightings`, `removeAllExpectedSpeciesForSite`, `setTankRoles`, `assignMissingDiveNumbers` (no single write: a ruling), `setDismissedForDives`.
- Settings and UI state: view configs and column presets, CSV import presets.
- Security: network credentials, manifest subscriptions, watched folders and their scan state, local asset cache, media upload and verification stamps, media repair log.
- Not an agent write by decision: `deleteDiverWithReassignment`, `deleteDiver`, `mergeDivers` and its undo (Eric, 2026-11-04).
- Methods with no caller in the app: each named, "no caller in the app".

- [ ] Step 1: Write the maps; add a test `the baseline is empty` that fails while any line remains, and a test `every covered method is called from its writer` (Review Focus 1: grep the writer file named by the entity for the method name).
- [ ] Step 2: Run. Expected: FAIL until every line is placed.
- [ ] Step 3: Place every remaining line; regenerate the baseline (empty).
- [ ] Step 4: Run `flutter test test/architecture`. Expected: PASS, baseline file empty.
- [ ] Step 5: Commit `test(architecture): every repository write covered or exempt`.

### Task 24: Remove the debug gate, and the docs

**Files:** Modify `lib/features/agent_access/presentation/providers/agent_access_providers.dart` (`agentAccessAvailableProvider` without the debug clause), the Data tools row and the release note behind it, `docs/developer/agent-access.md`, the user docs page for agent access (under `docs/user/`).

- [ ] Step 1: Failing test: `agent access is available on desktop with debug mode off` (and still unavailable where `deviceCapabilities.agentAccess` is false).
- [ ] Step 2: Run. Expected: FAIL.
- [ ] Step 3: Remove the clause; update the docs: the guide's write section lists every family and the exemption groups; the user page drops the debug-mode note.
- [ ] Step 4: Full checks: `dart format .`, `flutter analyze` (whole repo), `flutter test test/features/agent_access test/architecture test/features/equipment test/features/settings test/shared` and every feature test folder a task touched. Expected: all pass.
- [ ] Step 5: Commit `feat(agent-access): ship agent access without debug mode`.
