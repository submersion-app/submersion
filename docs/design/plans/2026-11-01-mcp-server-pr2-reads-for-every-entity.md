# MCP Server PR 2: Reads for Every Entity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every editable record in the logbook is readable through the agent tools: `get_records` for every entity, `list_records` for every non-root entity, summaries for every query root, and `serviceDue` queries that answer for any diver profile.

**Architecture:** One record catalogue with an entry per entity: table, visibility rule, optional parent column, loader, document mapper, child blocks and summary keys. A tool asks SQL which ids the diver may see, loads those through the repositories, and maps them to metric JSON. `serviceDue` evaluates the named diver's clocks in memory and feeds them to the compiled query through a CTE that shadows the cache table, so a read tool never writes the cache.

**Tech Stack:** Dart, Flutter, Drift, `mcp_dart` (only inside `mcp_server_builder.dart`).

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`. PR 1 plan, whose Roadmap this implements: `docs/design/plans/2026-11-01-mcp-server-pr1-server-core.md`.

## Decisions taken with Eric on 2026-11-01

- `serviceDue` and `nextServiceDue` work for any `diver_id`, evaluated fresh for that diver, without touching the cache.
- Documents carry everything but bytes: email, phone, card numbers, reference numbers, medical notes and insurance are included.
- The catalogue is everything a diver can edit, not only the spec's checklist.
- Diver profiles and diver settings are readable records. `list_divers` stays a short whitelist.

## Global Constraints

- Tool responses: metric values with the unit in the key (`max_depth_m`, `water_temp_c`, `start_pressure_bar`, `weight_kg`), never bare numbers.
- Bytes never appear in a document: not photos, card images, signatures, document pages or track blobs. Media stays links.
- No key from `changeLogCredentialColumns` or `deviceLocalSyncColumns` appears in a document.
- Read the database through a getter at call time; never hold an `AppDatabase`. The server factory runs per request on the 2026 protocol, so nothing there touches the database.
- Every tool emitting times states the date rule (below). `mcp_dart` drops `structuredContent` from error results, so errors stay readable as text.
- Reads do not write. No tool in this PR opens a transaction or writes a table.
- The debug-mode gate on `agentAccessAvailableProvider` stays.
- No new table, column or migration. No user-facing strings, so no ARB changes.
- Files 200 to 400 lines, 800 max; `dart format .` before each commit; TDD; no emojis; no em-dashes.
- Run `flutter test test/architecture test/shared` after adding any `lib/` file.
- PR body says `Refs #4071`, never `Closes`. No attribution of any tool anywhere. The PR touches `lib/features/agent_access/presentation/providers/`, so tick "No visible UI change" and say why.

### The date rule

`document_dates.dart` holds the only three formatters, and each key's suffix says which one it used. The tool descriptions state this rule.

| Key | Meaning | Formatter |
| --- | --- | --- |
| `date_time` and `*_time` | The local wall clock of the dive or event with a nominal `Z`; do not shift it | `wallClock(dt)`: `dt.toIso8601String()` |
| `*_date` | A calendar date, `2025-03-14` | `calendarDate(dt)`: `y-m-d` from the value as held, never via `toUtc()`, so a local midnight cannot slip a day |
| `*_at` | A true instant in UTC | `instant(dt)`: `dt.toUtc().toIso8601String()` |

`created_at` and `updated_at` are left out of every document: they are bookkeeping, and PR 4 reads its own version markers.

## Review Focus

1. Diver B has hidden a site diver A shared; `get_records` as B lists that id under `missing`, and `list_records` for its features returns nothing (Task 4 test `a hidden site hides its children`).
2. Equipment shared with diver B: B reads its service records through the parent rule even though B owns no row (Task 5 test `a share holder reads service records`).
3. A local-midnight `issue_date` read under `TZ=Australia/Sydney` must print the same calendar day, and CI runs in that zone (Task 1 test `calendar dates never slip a day`).
4. `serviceDue` for a diver with no gear must answer "nothing due", not fail on an empty CTE (Task 10 test `no gear means nothing is due`).
5. A signature media row and a buddy with a stored photo carry bytes; a generic scan of every document must find none (Task 11 test `no document in the catalogue carries bytes`).

---

## File Structure

Create under `lib/features/agent_access/data/`:

- `records/record_scope.dart`: `RecordScope` and its builders.
- `records/record_entity.dart`: `RecordEntity<T>`, `RecordEntry`, `RecordLoad`, `BlockLoader<T>`.
- `records/record_reader.dart`: `RecordReader.visibleIds`, `RecordReader.page`, `RecordPage`.
- `records/record_repositories.dart`: `RecordRepositories`, a plain bundle of lazily built repositories.
- `records/record_catalog.dart`: `RecordCatalog`, the merged list and lookups.
- `records/families/`: `dive_records.dart`, `site_records.dart`, `gear_records.dart`, `trip_records.dart`, `training_records.dart`, `catalog_records.dart`, `logbook_records.dart`, `profile_records.dart`, each returning `List<RecordEntry>`.
- `documents/document_dates.dart`: the three formatters.
- `documents/`: `site_documents.dart`, `gear_documents.dart`, `trip_documents.dart`, `training_documents.dart`, `catalog_documents.dart`, `logbook_documents.dart`, `plan_documents.dart`, `track_documents.dart`, `profile_documents.dart`.
- `tools/list_records_tool.dart`.
- `service_status_overlay.dart`: the named diver's verdicts as a `QueryCte`.

Modify:

- `lib/features/agent_access/data/tools/get_records_tool.dart`: catalogue driven, `fields`.
- `lib/features/agent_access/data/tools/query_tool.dart`: summaries and `serviceDue`.
- `lib/features/agent_access/data/tools/agent_tool_registry.dart`, `presentation/providers/agent_access_providers.dart`: wiring.
- `lib/features/agent_access/data/documents/dive_document.dart`: the full dive, blocks moved to loaders.
- `lib/features/query/data/query_id_set_runner.dart`: optional CTE on `ids`.
- `lib/features/equipment/data/services/loaded_service_clocks.dart`, `lib/features/notifications/data/services/notification_scheduler.dart`: extract the batch evaluation.
- `docs/developer/agent-access.md`, `docs/design/specs/2026-11-01-mcp-server-design.md`.

Tests mirror these paths under `test/features/agent_access/data/`.

## Catalogue

Scope names are the builders in Task 1. `via(x)` means through the parent column, against the parent's own rule. Every entry's rule copies its repository's list method, and the family tests pin that parity, so a difference is a failing test rather than a judgement call.

| Family | Entity (table if different) | Scope | Parent column | Blocks |
| --- | --- | --- | --- | --- |
| Dive | `dives` | root | | `tanks buddies tags types weights sightings media profile gear custom_fields gas_switches events data_sources scenarios` |
| Dive | `dive_tanks`, `dive_weights`, `sightings`, `dive_custom_fields`, `gas_switches`, `dive_events` (`dive_profile_events`), `dive_scenarios` | `via(dives)` | `dive_id` | |
| Dive | `media` | `mediaScope`: `dive_id IS NULL` or a visible dive, as `MediaLibraryRepository._diverScope` | `dive_id` | |
| Site | `sites` | root | | `features types tags species media shares` |
| Site | `site_features` | `via(sites)` | `site_id` | |
| Site | `site_types` | `ownedOrBuiltIn` | | |
| Site | `centers` | root | | `gear_notes` |
| Site | `center_gear_notes` (`dive_center_gear_notes`) | `via(centers)` | `dive_center_id` | |
| Gear | `equipment` | root | | `service_records service_schedules components shares tags media location_moves observations fills transmitters` |
| Gear | `equipment_location_moves`, `equipment_observations`, `service_records`, `service_schedules`, `equipment_shares` | `via(equipment)` | `equipment_id` | |
| Gear | `equipment_components` | `via(equipment)` | `parent_equipment_id` | |
| Gear | `cylinder_fills` | `fillScope`: as `CylinderFillRepository.getAllVisibleTo` | `equipment_id` | |
| Gear | `equipment_sets`, `transmitters`, `cylinder_configs` | `owned` | | sets: `items geofences`; configs: `items` |
| Gear | `equipment_locations` | `ownedOrNull` | | |
| Gear | `service_kinds` | `ownedNullOrBuiltIn` | | |
| Trip | `trips` | root | | `itinerary liveaboard cylinders checklist dive_ids side_trips shares` |
| Trip | `itinerary_days` (`trip_itinerary_days`), `liveaboard_details` (`liveaboard_detail_records`), `trip_cylinders`, `trip_checklist_sections`, `trip_checklist_items` | `via(trips)` | `trip_id` | |
| Trip | `trip_cylinder_events` | `via(trip_cylinders)` | `trip_cylinder_id` | |
| Training | `buddies` | root | | `certifications` |
| Training | `certifications` | root | | `currency_prefs currency_events` |
| Training | `currency_prefs` (`certification_currency_prefs`), `currency_events` (`certification_currency_events`) | `via(certifications)` | `certification_id` | |
| Training | `currency_rules` (`certification_currency_rules`) | `ownedNullOrBuiltIn` | | |
| Training | `custom_agencies` (`custom_certification_agencies`), `custom_levels` (`custom_certification_levels`) | `ownedOrShared` | levels: `agency_id` | |
| Training | `courses` | root | | `requirements dive_ids` |
| Training | `course_requirements` | `via(courses)` | `course_id` | |
| Training | `species` | root (`everyone`) | | |
| Catalogs | `tags`, `tank_presets`, `weight_presets` | `owned` | | presets: `entries` |
| Catalogs | `dive_types`, `dive_roles`, `pre_dive_templates` | `ownedOrBuiltIn` | | templates: `items` |
| Catalogs | `checklist_templates` | `ownedOrNull` | | `items` |
| Logbook | `pre_dive_sessions`, `incidents`, `emergency_chambers`, `saved_queries` | `ownedOrNull` | | sessions: `items` |
| Logbook | `documents` | `owned` | | `pages` (metadata only) |
| Logbook | `rules`, `connection_maps`, `dive_computers`, `weight_entries` (`diver_weight_entries`) | `owned` | | |
| Logbook | `nav_tracks` | `navTrackScope`: as `NavTrackRepository._visibleToSql` | | |
| Logbook | `dive_plans`, `gps_tracks`, `smart_albums` (`media_smart_albums`), `csv_presets` | `everyone` | | |
| Profiles | `divers` | `everyone` | | |
| Profiles | `diver_settings` | `owned` | | |

Link tables are blocks on their parent: `dive_buddies`, `dive_buddy_roles`, `dive_tags`, `dive_dive_types`, `dive_diver_roles`, `dive_courses`, `dive_equipment`, `site_tags`, `site_site_types`, `site_species`, `equipment_tags`, `trip_equipment`, `site_shares`, `trip_shares`, `media_tags`, `media_species`, `media_people`, `document_tags`.

Children folded into their parent: template sections and items, weight preset entries, cylinder config items, dive plan tanks, segments, equipment and mission rows, set items and geofences, equipment attributes, session sections and items, document pages.

Left out on purpose: `settings` (device key-value store), `view_configs`, `field_presets`, `site_hides`, `trip_hides`, `library_site_notes`, `insight_observation_dismissals`, `imported_files`, `media_stores`, `media_subscriptions`, and every table `changeLogTables` classes as excluded or delete-copy-only. Task 11's guard makes that list explicit.

---

### Task 1: The record core

**Files:**

- Create: `records/record_scope.dart`, `records/record_entity.dart`, `records/record_reader.dart`, `documents/document_dates.dart`
- Test: `test/features/agent_access/data/records/record_scope_test.dart`, `record_reader_test.dart`, `test/features/agent_access/data/documents/document_dates_test.dart`

**Interfaces:**

- Produces:

```dart
/// A WHERE fragment over [alias] that limits a table to what [diverId] may
/// see. Null means no limit.
typedef RecordScope = QueryScope? Function(String diverId, String alias);

RecordScope everyone();
RecordScope owned({String column = 'diver_id'});
RecordScope ownedOrNull();
RecordScope ownedOrBuiltIn();
RecordScope ownedNullOrBuiltIn();
RecordScope ownedOrShared();
RecordScope rootScope(QuerySubject subject); // delegates to rootScopeFor
RecordScope viaParent(String parentTable, String column, RecordScope parent);

class RecordLoad {
  const RecordLoad({required this.include, required this.diverId,
      this.profileOffset = 0, this.profileLimit = kProfileDefaultLimit});
  final Set<String> include;
  final String diverId;
  final int profileOffset;
  final int profileLimit;
}

typedef BlockLoader<T> = Future<Object?> Function(T record, RecordLoad load);

/// The face tools use. Calls through this never touch a typed field, so a
/// list of mixed entities stays free of covariance failures.
abstract interface class RecordEntry {
  String get name;
  String get table;
  RecordScope get scope;
  String? get parentColumn;
  String get orderBy;           // SQL over r0, default 'r0.id'
  Set<String> get blocks;
  Future<Map<String, Map<String, Object?>>> read(List<String> ids, RecordLoad load);
  Future<List<Map<String, Object?>>> summaries(List<String> ids, RecordLoad load);
}

class RecordEntity<T> implements RecordEntry { ... }

class RecordPage { List<String> ids; int total; }

class RecordReader {
  const RecordReader(this.db);
  Future<List<String>> visibleIds(RecordEntry e, List<String> ids, String diverId);
  Future<RecordPage> page(RecordEntry e, String diverId,
      {String? parentId, required int limit, required int offset});
}

String wallClock(DateTime value);
String? wallClockOrNull(DateTime? value);
String? calendarDate(DateTime? value);
String? instant(DateTime? value);
```

`RecordEntity` takes `load: Future<Map<String, T>> Function(List<String>, RecordLoad)`, `document: Map<String, Object?> Function(T)`, `summaryKeys: List<String>`, `blocks: Map<String, BlockLoader<T>>`, and an optional `summarize` that replaces the projection (dives use it). `read` runs `load`, then `document`, then each requested block, and writes the block's result under its name. `summaries` projects `summaryKeys` plus `id` from `document` and preserves the order of `ids`. Helpers in the same file: `loadEach<T>(ids, Future<T?> Function(String))` and `byId<T>(list, String Function(T))`, plus `loadChildren<T>` that groups a child's ids by parent column and calls a batch-by-parent loader.

- [ ] **Step 1: Write the failing tests**

`record_scope_test`: each builder against a real `setUpTestDatabase()` with rows owned by A, by B and null, asserting the id set. Named cases: `viaParent nests two levels` (trip cylinder event through cylinder through trip, shared trip visible to B), `viaParent keeps parameters in order`, `everyone returns null`.

`record_reader_test`: `visibleIds keeps only what the diver may see`, `visibleIds preserves the order asked for`, `page counts everything and returns one window`, `page filters by parent id`, `page refuses a parent id on an entity without a parent column` (`invalid_argument`).

`document_dates_test`: `calendar dates never slip a day` with `DateTime(2024, 3, 1)`, asserting `'2024-03-01'` and the same under `DateTime.utc(2024, 3, 1)`; `instant is always UTC`: `instant(DateTime.fromMillisecondsSinceEpoch(0))` is `'1970-01-01T00:00:00.000Z'`; `wall clock keeps the value as held`: `wallClock(DateTime.utc(2024, 5, 1, 10))` is `'2024-05-01T10:00:00.000Z'`.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/agent_access/data/records test/features/agent_access/data/documents/document_dates_test.dart`
Expected: FAIL, the libraries do not exist.

- [ ] **Step 3: Implement**

`viaParent` aliases the inner query `${alias}p`, so nesting cannot collide. `visibleIds` chunks with `seriesIdChunks`, runs `SELECT r0.id FROM <table> r0 WHERE r0.id IN (...) AND <scope>`, and returns the asked order. `page` runs a `COUNT(*)` and a `SELECT ... ORDER BY <orderBy> LIMIT ? OFFSET ?` with the same WHERE.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): add the record scope, reader and date formatters`

### Task 2: The catalogue-driven tools

**Files:**

- Create: `records/record_repositories.dart`, `records/record_catalog.dart`, `records/families/dive_records.dart`, `tools/list_records_tool.dart`
- Modify: `tools/get_records_tool.dart`, `tools/agent_tool_registry.dart`, `presentation/providers/agent_access_providers.dart`, `documents/dive_document.dart`
- Test: `test/features/agent_access/data/tools/get_records_tool_test.dart`, `list_records_tool_test.dart`, `agent_tool_registry_test.dart`, `server/agent_access_server_e2e_test.dart`

**Interfaces:**

- Consumes: Task 1.
- Produces:

```dart
class RecordRepositories { late final sites = SiteRepository(); ... }

class RecordCatalog {
  RecordCatalog(RecordRepositories r);
  List<RecordEntry> get all;
  List<RecordEntry> get nonRoots;
  RecordEntry named(String name);  // invalid_argument with the valid names
}

const kListRecordsDefaultLimit = 100;
const kListRecordsMaxLimit = 500;
```

`AgentToolRegistry.standard` drops the individual repositories for `RecordRepositories`; `_buildServer` constructs one. Repositories read `DatabaseService.instance.database` through a getter, so a bundle built per request pins nothing.

`get_records` input gains `fields` (array of strings). Its `entity` enum is every catalogue name, and `include` is validated per entity: a name the entity lacks is `invalid_argument` listing that entity's blocks. `list_records` input: `entity` (enum of `nonRoots`), `diver_id`, `parent_id`, `limit`, `offset`. Output: `entity`, `diver_id`, `total`, `records` (summaries), `offset`, `limit`, `has_more`.

- [ ] **Step 1: Write the failing tests**

`get_records_tool_test`, existing cases keep passing, plus: `fields narrows a document and always keeps the id`, `an unknown field is refused with the valid names`, `include names only that entity's blocks`, `profile paging still works`. `list_records_tool_test`: `lists one profile's records`, `pages with has_more`, `parent_id narrows to one parent`, `parent_id on an entity without a parent is refused`, `an unknown diver is refused`, `a root entity is refused and names query`. `agent_tool_registry_test`: `standard registers list_records`. E2E: `list_records over loopback`.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement** the bundle, the catalogue with `dives` and `dive_tanks` only, the tools, and the wiring. `diveDocument` loses its `buddies`, `sightings`, `media` and `typeNames` parameters; those become block loaders in `dive_records.dart`, and `dive_document_test` moves with them.

- [ ] **Step 4: Run them plus `test/architecture test/shared`, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): drive get_records from a catalogue and add list_records`

### Task 3: The dive family

**Files:** Modify `documents/dive_document.dart`, `records/families/dive_records.dart`. Test: `documents/dive_document_test.dart`, `records/dive_records_test.dart`.

**Interfaces:** Consumes Tasks 1 and 2. Produces `diveEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `the document carries every diver-entered field` (entry and exit locations, visibility range, boat, conditions, rebreather block, weather, custom weighting feedback, excluded-from-gas-stats, courses, roles, each key unit-named); `gas_switches are sorted by time`; each child entity readable by id across profiles (`a tank of another diver's dive is missing`), `media scope matches the library rule`, `a signature row emits no image data`.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement** the remaining dive fields and blocks and the seven child entities. `gear` emits each `GearLink`'s equipment id plus its via ids. Child loaders use `loadChildren` over the batch methods (`getGasSwitchesForDives`, `getEventsForDives`, `getFieldsForDiveIds`, `getSightingsForDives`) and `getScenario`.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read the whole dive and its children`

### Task 4: Sites and centers

**Files:** Create `documents/site_documents.dart`, `records/families/site_records.dart`. Test: `records/site_records_test.dart`.

**Interfaces:** Produces `siteEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `a hidden site hides its children` (Review Focus 1), `a shared site reads for every profile`, `a shared library site reads for a member only`, `site_features list by parent`, `center gear notes follow their center`, and one `scope matches getAllSites` parity case per entity with a repository list.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** Site keys: `min_depth_m`, `max_depth_m`, `latitude`, `longitude`, `entry_methods`, `exit_methods`, `is_shared`, `shared_library_id`. Feature: `depth_m`, `bearing_deg`. Center: `fill_opens_at_min`, `fill_closes_at_min` (minutes after midnight), `lead_adjustment_kg`, `volume_l`.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read sites, centers and their children`

### Task 5: Gear

**Files:** Create `documents/gear_documents.dart`, `records/families/gear_records.dart`. Test: `records/gear_records_test.dart`.

**Interfaces:** Produces `gearEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `a share holder reads service records` (Review Focus 2), `equipment owned by another diver and not shared is missing`, `purchase and service dates are calendar dates`, `attributes are in the document`, `cost keeps its currency` (`cost` with `currency`, the one bare number that is money), `fills follow visible cylinders`, and parity cases for sets, locations, kinds, transmitters, configs and fills.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** `EquipmentAttribute` emits `key`, `is_custom`, `value_text`, `value_num`; the num is unitless by the attribute's own key. `ServiceSchedule` emits `interval_days`, `interval_dives`, `interval_hours` and `exposure_intervals` keyed by `ExposureUnit.name`.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read equipment and its service history`

### Task 6: Trips

**Files:** Create `documents/trip_documents.dart`, `records/families/trip_records.dart`. Test: `records/trip_records_test.dart`.

**Interfaces:** Produces `tripEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `a shared trip reads for a share row holder`, `a hidden trip hides its children`, `cylinder events read through a shared trip` (two-level parent), `start and end are calendar dates`, `return_flight_time keeps its wall clock`, `dive_ids lists only what the diver sees`, parity for `getAllTrips`.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** Event keys: `pressure_bar`, `o2_fraction`, `he_fraction`, `analyzed_o2_fraction`, `analyzed_he_fraction` (percent in storage, divided by 100 like tanks).

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read trips and their children`

### Task 7: People and training

**Files:** Create `documents/training_documents.dart`, `records/families/training_records.dart`. Test: `records/training_records_test.dart`.

**Interfaces:** Produces `trainingEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `a buddy document carries contact details and no photo bytes`, `a buddy's certifications arrive as a block`, `a certification's card images never appear`, `a card number is present`, `requirements follow their course`, `built-in currency rules read for every profile`, `a shared custom agency reads for every profile`, `species read for every profile`, parity for buddies, certifications, courses and rules.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** `custom_agencies` emits `color_argb`; `additional_credentials` keeps agency and level ids verbatim.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read buddies, certifications, courses and species`

### Task 8: Catalogs and templates

**Files:** Create `documents/catalog_documents.dart`, `records/families/catalog_records.dart`. Test: `records/catalog_records_test.dart`.

**Interfaces:** Produces `catalogEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `built-in dive types read for every profile`, `a custom dive type reads only for its owner`, `checklist items come with their template`, `pre-dive item values keep value_label and value_unit`, `tank presets are stored rows only` (a built-in constant is not listed), `weight preset entries carry amount_kg`, parity for each entity.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** Pre-dive item numbers stay `value_min`, `value_max`, `value_number` beside `value_unit`, because the unit is stored with them.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read tags, types, presets and templates`

### Task 9: The rest of the logbook

**Files:** Create `documents/logbook_documents.dart`, `documents/plan_documents.dart`, `documents/track_documents.dart`, `records/families/logbook_records.dart`. Test: `records/logbook_records_test.dart`.

**Interfaces:** Produces `logbookEntries(RecordRepositories r)`.

- [ ] **Step 1: Write the failing tests**: `a document lists page metadata and no bytes`, `a dive computer leaves out its Bluetooth address and fingerprint`, `a plan carries tanks and segments`, `a rule carries its query and actions as JSON`, `a track document reports points without a blob`, `nav track points are paged` through `profile_offset` and `profile_limit` when `points` is included, `incidents read for owner and ownerless`, `an emergency chamber reads`, parity for each entity with a list.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** `DivePlan` carries no diver id, and `getAllPlanSummaries` is unfiltered, so `dive_plans` uses `everyone`. Rules load through `getById(id, names: ...)`, whose names come from `NameIndexLoader` for `load.diverId`.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): read documents, plans, rules, tracks and the rest`

### Task 10: Query summaries and `serviceDue`

**Files:**

- Create: `service_status_overlay.dart`
- Modify: `tools/query_tool.dart`, `lib/features/query/data/query_id_set_runner.dart`, `lib/features/equipment/data/services/loaded_service_clocks.dart`, `lib/features/notifications/data/services/notification_scheduler.dart`, `tools/agent_tool_registry.dart`
- Test: `tools/query_tool_test.dart`, `test/features/agent_access/data/service_status_overlay_test.dart`, `test/features/query/data/query_id_set_runner_test.dart`, the existing notification scheduler test

**Interfaces:**

- Consumes: `RecordCatalog`, `exposureThresholdsFromSettings`, `evaluateLoadedServiceClocks`.
- Produces:

```dart
// loaded_service_clocks.dart, extracted from NotificationScheduler._evaluateClocks
Future<Map<String, List<ServiceClockStatus>>> evaluateServiceClocksForItems(
  List<EquipmentItem> items, {
  required Map<String, ServiceKind> kindsById,
  required AppSettings settings,
  required ServiceScheduleRepository schedules,
  required ServiceRecordRepository records,
  required EquipmentRepository equipment,
  required DateTime now,
});

// query_id_set_runner.dart
typedef QueryCte = ({String sql, List<Object> params});
Future<Set<String>> ids(CompiledQuery compiled, {QueryScope? scope, QueryCte? cte});

// service_status_overlay.dart
Future<QueryCte> serviceStatusOverlay({
  required String diverId,
  required AppSettings settings,
  required RecordRepositories repositories,
  required DateTime now,
});
```

The overlay is one bound JSON string, the same verdict the cache writer picks (first status, `ok` when none):

```sql
WITH equipment_service_status(equipment_id, severity, due_date) AS (
  SELECT json_extract(value, '$[0]'), json_extract(value, '$[1]'),
         json_extract(value, '$[2]')
  FROM json_each(?))
```

- [ ] **Step 1: Write the failing tests**

`query_tool_test`, replacing `refuses serviceDue`: `serviceDue answers for the active diver`, `serviceDue answers for a named non-active diver` (B has an overdue regulator, the active diver is A, whose cache row says ok), `nextServiceDue bounds by the named diver's date`, `no gear means nothing is due` (Review Focus 4), `a serviceDue query writes nothing` (select from `equipment_service_status` before and after, and count table update notifications), `the cache table is left as it was`. Also `summaries for sites`, one case per root, `a summary is a projection of the document`, `summaries keep id order`, `dive summaries are unchanged`.

`query_id_set_runner_test`: `a CTE shadows the table it names`.

Scheduler: the existing reminder tests stay green unchanged.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement.** The `QueryTool` branch is:

```dart
final cte = compiled.tablesTouched.contains(serviceStatusTable)
    ? await serviceStatusOverlay(...)
    : null;
```

`DiverContext` already carries the named diver's settings, so the window and thresholds are that diver's. `activeEquipment` comes from `getActiveEquipment(diverId: id)`, matching the cache's "retired and sold read as ok". `awaitServiceStatusIfRead` is not used: it can only answer for the active diver.

- [ ] **Step 4: Run them, expect PASS**

- [ ] **Step 5: Commit**: `feat(agent-access): add root summaries and answer serviceDue for any diver`

### Task 11: Profiles, guards and documentation

**Files:**

- Create: `documents/profile_documents.dart`, `records/families/profile_records.dart`, `test/features/agent_access/data/records/record_catalog_guard_test.dart`
- Modify: `docs/developer/agent-access.md`, `docs/design/specs/2026-11-01-mcp-server-design.md`, `lib/features/agent_access/data/resources/query_language_resource.dart`

**Interfaces:**

- Produces `profileEntries(RecordRepositories r)`. The link, folded and unexposed table lists live in the guard test.

`divers` maps the domain `Diver` with a whitelist that omits `photo`.

`diver_settings` is the one mapper over a Drift row, and the deliberate exception to the spec's rule: 217 columns with no domain shape of their own, most of them view preferences, would drift the moment a setting is added. `settingsDocument(DiverSetting row)` takes `row.toJson()`, drops `deviceLocalSyncColumns['diverSettings']` plus `id`, `createdAt`, `updatedAt` and `hlc`, converts keys to snake_case, and renames dimensioned keys from `kSettingUnitKeys` (`default_tank_volume` to `default_tank_volume_l`, `default_start_pressure` to `default_start_pressure_bar`, `planner_descent_rate` to `planner_descent_rate_m_min`).

- [ ] **Step 1: Write the failing tests**

`record_catalog_guard_test`:

- `every tracked table is covered, linked, folded or unexposed`: each `changeLogTables` key classed `tracked` appears in a catalogue `table`, or in exactly one of the three lists, so a new table forces a decision.
- `no document carries a credential or device-local key`: seed one row per entity, walk every document recursively, and assert no key equals a `changeLogCredentialColumns` value or the snake_case of a `deviceLocalSyncColumns` value.
- `no document in the catalogue carries bytes` (Review Focus 5): the same walk rejects any `Uint8List` or `List<int>`.
- `every real settings column is unit-named or declared unitless`: every `REAL` column of `diver_settings` is a key of `kSettingUnitKeys` or of `kUnitlessSettings`.
- `every entity's parent column exists on its table`, using `PRAGMA table_info`.
- `every entity's table exists`.
- `a repeat read writes nothing`: read every entity and count zero table-update notifications.

`profile_records_test`: `a diver record carries medical notes and insurance`, `a diver record carries no photo bytes`, `list_divers stays a whitelist`, `diver settings read as that profile`, `another diver's settings are missing`.

- [ ] **Step 2: Run them, expect FAIL**

- [ ] **Step 3: Implement** the two entries, the three lists, and the docs. `agent-access.md` gains the new file map, the date rule, how to add an entity, and the `serviceDue` overlay, and its roadmap drops this PR. The spec's decision record gains the four decisions at the top of this plan, and the spec's `query` section stops naming the cache wait. The query-language resource says the date rule.

- [ ] **Step 4: Run the whole feature plus guards**

Run: `flutter test test/features/agent_access test/features/query test/features/notifications test/architecture test/shared`
Expected: PASS

- [ ] **Step 5: Commit**: `feat(agent-access): read profiles and settings, and guard the catalogue`

## Self-review notes

- Spec coverage: `get_records` `entity`, `ids`, `fields`, `include`, `diver_id`, samples paged (Tasks 2, 3); `list_records` (Task 2); `query` summaries and `serviceDue` (Task 10); credential and device-local test (Task 11); units (every task); `submersion://units/{diver_id}` as a template stays deferred, since `submersion://units` already serves every profile.
- Changes from the spec: `awaitServiceStatusIfRead` is replaced by the overlay, because it answers only for the active diver. `diver_settings` maps a Drift row, for the reason in Task 11.
- Types used across tasks: `RecordScope`, `RecordEntry`, `RecordEntity<T>`, `RecordLoad`, `RecordReader`, `RecordPage`, `RecordRepositories`, `RecordCatalog`, `QueryCte`, `evaluateServiceClocksForItems`, `serviceStatusOverlay`.
