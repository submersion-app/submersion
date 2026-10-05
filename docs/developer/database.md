# Database Schema

Submersion uses Drift ORM with SQLite. Its 108 tables are declared in 21
libraries under `lib/core/database/tables/`, one per domain.

## Overview

| Library | Tables | Holds |
| ------- | ------ | ----- |
| `app_tables.dart` | 6 | App-level state: legacy settings, cached map regions, notifications, import presets and view configuration |
| `buddy_tables.dart` | 7 | Buddies, dive roles, certifications and training courses |
| `cylinder_tables.dart` | 5 | Cylinder configurations, tank presets, transmitters and fills |
| `dive_plan_tables.dart` | 4 | Saved dive plans |
| `dive_profile_tables.dart` | 7 | Dive computers, data sources, imported files and profile series |
| `dive_tables.dart` | 6 | Dives and the rows that hang directly off a dive |
| `diver_tables.dart` | 2 | Diver profiles and their settings |
| `equipment_condition_tables.dart` | 3 | Equipment condition engine: observations, findings and reviews |
| `equipment_tables.dart` | 10 | Equipment, equipment sets, sharing and the dive gear junction |
| `marine_life_tables.dart` | 2 | Species and sightings |
| `media_tables.dart` | 12 | Media, enrichment, albums, subscriptions and media stores |
| `pre_dive_tables.dart` | 4 | Pre-dive checklist templates and sessions, with their built-in seeds |
| `quality_tables.dart` | 1 | Findings of the Data Quality Assistant |
| `safety_tables.dart` | 4 | Safety reviews, emergency chambers and incidents |
| `service_tables.dart` | 3 | Service records, kinds and schedules, with their built-in seeds |
| `site_tables.dart` | 8 | Dive sites, their classification, and dive centers |
| `sync_tables.dart` | 5 | Sync bookkeeping |
| `tag_tables.dart` | 4 | Tags and dive types, with the dive type seeds |
| `track_tables.dart` | 3 | GPS surface tracks and measured underwater routes |
| `trip_tables.dart` | 9 | Trips, liveaboards, itineraries, trip cylinders and trip checklists |
| `weight_tables.dart` | 3 | Diver weight entries and weight presets |

The sections below describe the core tables in more detail.

## Drift ORM

### Table Definitions

Tables are defined in per-domain libraries under
`lib/core/database/tables/` (`dive_tables.dart`, `equipment_tables.dart`,
and so on). `lib/core/database/database.dart` imports and exports each of
them and lists every table in `@DriftDatabase(tables: [...])`, so importing
`database.dart` is still all a consumer needs.

```dart
// lib/core/database/tables/dive_tables.dart
class Dives extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  IntColumn get diveNumber => integer().nullable()();
  IntColumn get diveDateTime => integer()();
  // ...

  @override
  Set<Column> get primaryKey => {id};
}
```

To add a table, declare it in the table library for its domain (or a new
library under `tables/`, imported and exported from `database.dart`), then add
it to the `@DriftDatabase` list. Do not declare tables in `database.dart`
itself, and keep each table library under 800 lines:
`test/core/database/database_table_libraries_test.dart` enforces both.

No test imports a table library or a migration file directly, so the
pre-push hook treats a change under `tables/` or `migrations/` as a change
to `database.dart` when it picks the tests to run.

The reason is build memory. During code generation drift_dev resolves the
whole library that declares a column, once per column, and nothing caches the
result. With every table inside `database.dart`, next to the migration ladder,
a cold build peaked at 15 GB on the 16 GB CI runner and was killed whenever
it needed slightly more. Split into small libraries the same build peaks at
3.5 GB and produces identical output (issue #2502).

### Generated Code

Run code generation after schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates `database.g.dart` with:

- Companion classes
- Query builders
- Type converters

## Schema Version

The current version is `AppDatabase.currentSchemaVersion` in
`lib/core/database/database.dart`.

Migrations handle schema evolution. `AppDatabase` declares only the schema
and its version; the migration code lives under
`lib/core/database/migrations/`. Most of it is one library,
`app_database_migrations.dart`, made of extensions on `AppDatabase` spread
over part files. `database.dart` exports it, so its public members are
available wherever `database.dart` is imported:

| Part file | Holds |
| --------- | ----- |
| `migration_strategy.dart` | `onCreate`, and `onUpgrade` calling each ladder file in order |
| `ladder/rungs_v<first>_to_v<last>.dart` | The `if (from < N)` rungs, oldest first |
| `ladder/rungs_v<first>_onward.dart` | The newest rungs; new ones are appended here |
| `helpers/<domain>_migrations.dart` | The `_assert...` and `_backfill...` helpers the rungs call, grouped like the table libraries |
| `before_open.dart` | The backstops that run on every open |

```dart
// lib/core/database/migrations/ladder/rungs_v231_onward.dart
if (from < 240) {
  await _assertProfileEventsDiveIdIndex();
}
if (from < 240) await reportProgress();
```

To add a migration:

1. Raise `AppDatabase.currentSchemaVersion`.
2. Append the version to `AppDatabase.migrationVersions`, the list behind
   the progress bar, with a note on what it does.
3. Append the rung to `ladder/rungs_v<first>_onward.dart`. When that file
   nears 800 lines, close it: rename the file, its extension and its method
   to the range they now cover, as the older files are named, and update its
   `part` directive and its call in `_onUpgrade`. Then start a new onward
   file, with a `part` directive in `app_database_migrations.dart` and a call
   at the end of `_onUpgrade`.
4. Put any helper in the file under `helpers/` for its domain. A helper a
   test must reach gets a public name there, such as
   `DataSourceMigrations.recompressRawDiveDataForTest`; a test that imports
   `database.dart` can then call it as `db.recompressRawDiveDataForTest()`.
   Do not add it to `AppDatabase` itself.
5. If the change must also hold for a database that arrives by restore or
   sync, assert it in `before_open.dart`.

Keep migration code out of `database.dart`: drift_dev resolves that whole
library while it generates code. The same test that guards the table
libraries enforces this, and keeps every file under `tables/` and
`migrations/` under 800 lines.

## Core Tables

### Divers

Multi-account support:

```sql
CREATE TABLE divers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  photo_path TEXT,
  -- Emergency contact
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  emergency_contact_relation TEXT,
  -- Medical
  medical_notes TEXT DEFAULT '',
  blood_type TEXT,
  allergies TEXT,
  medications TEXT,
  medical_clearance_expiry_date INTEGER,
  -- Secondary emergency contact
  emergency_contact2_name TEXT,
  emergency_contact2_phone TEXT,
  emergency_contact2_relation TEXT,
  -- Insurance
  insurance_provider TEXT,
  insurance_policy_number TEXT,
  insurance_expiry_date INTEGER,
  -- Meta
  notes TEXT DEFAULT '',
  is_default INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Dives

Primary dive log:

```sql
CREATE TABLE dives (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  dive_number INTEGER,
  dive_date_time INTEGER NOT NULL,
  entry_time INTEGER,
  exit_time INTEGER,
  duration INTEGER,
  runtime INTEGER,
  max_depth REAL,
  avg_depth REAL,
  water_temp REAL,
  air_temp REAL,
  visibility TEXT,
  -- References
  site_id TEXT REFERENCES dive_sites(id),
  dive_center_id TEXT REFERENCES dive_centers(id),
  trip_id TEXT REFERENCES trips(id),
  computer_id TEXT REFERENCES dive_computers(id),
  course_id TEXT REFERENCES courses(id) ON DELETE SET NULL,
  -- Conditions
  current_direction TEXT,
  current_strength TEXT,
  swell_height REAL,
  entry_method TEXT,
  exit_method TEXT,
  water_type TEXT,
  -- Technical
  altitude REAL,
  surface_pressure REAL,
  surface_interval_seconds INTEGER,
  gradient_factor_low INTEGER,
  gradient_factor_high INTEGER,
  deco_algorithm TEXT,
  deco_conservatism INTEGER,
  dive_mode TEXT DEFAULT 'oc',
  dive_computer_model TEXT,
  dive_computer_serial TEXT,
  dive_computer_firmware TEXT,
  -- O2 toxicity
  cns_start REAL DEFAULT 0,
  cns_end REAL,
  otu REAL,
  -- CCR Setpoints (bar)
  setpoint_low REAL,
  setpoint_high REAL,
  setpoint_deco REAL,
  -- SCR Configuration
  scr_type TEXT,
  scr_injection_rate REAL,
  scr_addition_ratio REAL,
  scr_orifice_size TEXT,
  assumed_vo2 REAL,
  -- Diluent/Supply Gas
  diluent_o2 REAL,
  diluent_he REAL,
  -- Loop FO2 measurements (SCR)
  loop_o2_min REAL,
  loop_o2_max REAL,
  loop_o2_avg REAL,
  -- Shared rebreather fields
  loop_volume REAL,
  scrubber_type TEXT,
  scrubber_duration_minutes INTEGER,
  scrubber_remaining_minutes INTEGER,
  -- Weight
  weight_amount REAL,
  weight_type TEXT,
  -- Flags
  is_favorite INTEGER DEFAULT 0,
  is_planned INTEGER DEFAULT 0,
  -- Wearable integration
  wearable_source TEXT,
  wearable_id TEXT,
  -- Meta
  dive_type TEXT DEFAULT 'recreational',
  buddy TEXT,
  dive_master TEXT,
  rating INTEGER,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveProfiles

Time-series profile data:

```sql
CREATE TABLE dive_profiles (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  computer_id TEXT REFERENCES dive_computers(id),
  is_primary INTEGER DEFAULT 1,
  timestamp INTEGER NOT NULL,
  depth REAL NOT NULL,
  pressure REAL,
  temperature REAL,
  heart_rate INTEGER,
  ascent_rate REAL,
  ceiling REAL,
  ndl INTEGER,
  -- CCR/SCR rebreather data
  setpoint REAL,
  pp_o2 REAL,
  -- Per-sample decompression data
  cns REAL,
  tts INTEGER,
  rbt INTEGER,
  deco_type INTEGER,
  -- Wearable integration
  heart_rate_source TEXT
);

CREATE INDEX idx_profile_dive ON dive_profiles(dive_id, timestamp);
CREATE INDEX idx_dive_profiles_dive_id ON dive_profiles(dive_id);
```

### DiveTanks

Gas configuration:

```sql
CREATE TABLE dive_tanks (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  equipment_id TEXT REFERENCES equipment(id),
  volume REAL,
  working_pressure INTEGER,
  start_pressure INTEGER,
  end_pressure INTEGER,
  o2_percent REAL DEFAULT 21.0,
  he_percent REAL DEFAULT 0.0,
  tank_order INTEGER DEFAULT 0,
  tank_role TEXT DEFAULT 'backGas',
  tank_material TEXT,
  tank_name TEXT,
  preset_name TEXT
);
```

### DiveCustomFields

User-defined key:value fields per dive:

```sql
CREATE TABLE dive_custom_fields (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  field_value TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
```

## Location Tables

### DiveSites

Dive site locations:

```sql
CREATE TABLE dive_sites (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  latitude REAL,
  longitude REAL,
  min_depth REAL,
  max_depth REAL,
  difficulty TEXT,
  country TEXT,
  region TEXT,
  rating REAL,
  notes TEXT DEFAULT '',
  hazards TEXT,
  access_notes TEXT,
  mooring_number TEXT,
  parking_info TEXT,
  altitude REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveCenters

Dive operators/shops:

```sql
CREATE TABLE dive_centers (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  street TEXT,
  city TEXT,
  state_province TEXT,
  postal_code TEXT,
  latitude REAL,
  longitude REAL,
  country TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  affiliations TEXT,
  rating REAL,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Trips

Dive trip grouping:

```sql
CREATE TABLE trips (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER NOT NULL,
  location TEXT,
  resort_name TEXT,
  liveaboard_name TEXT,
  trip_type TEXT DEFAULT 'shore',
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### LiveaboardDetailRecords

Liveaboard-specific details, 1:1 with trips:

```sql
CREATE TABLE liveaboard_detail_records (
  id TEXT PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips(id),
  vessel_name TEXT NOT NULL,
  operator_name TEXT,
  vessel_type TEXT,
  cabin_type TEXT,
  capacity INTEGER,
  embark_port TEXT,
  embark_latitude REAL,
  embark_longitude REAL,
  disembark_port TEXT,
  disembark_latitude REAL,
  disembark_longitude REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Trip Planning Tables

### TripItineraryDays

Itinerary days for trip planning (liveaboard and multi-day trips):

```sql
CREATE TABLE trip_itinerary_days (
  id TEXT PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips(id),
  day_number INTEGER NOT NULL,
  date INTEGER NOT NULL,
  day_type TEXT DEFAULT 'diveDay',
  port_name TEXT,
  latitude REAL,
  longitude REAL,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Equipment Tables

### Equipment

Equipment catalog:

```sql
CREATE TABLE equipment (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  serial_number TEXT,
  size TEXT,
  status TEXT DEFAULT 'active',
  purchase_date INTEGER,
  purchase_price REAL,
  purchase_currency TEXT DEFAULT 'USD',
  last_service_date INTEGER,
  service_interval_days INTEGER,
  notes TEXT DEFAULT '',
  is_active INTEGER DEFAULT 1,
  custom_reminder_enabled INTEGER,
  custom_reminder_days TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveEquipment

Junction table for equipment used per dive (many-to-many):

```sql
CREATE TABLE dive_equipment (
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  equipment_id TEXT REFERENCES equipment(id) ON DELETE CASCADE,
  PRIMARY KEY (dive_id, equipment_id)
);
```

### DiveWeights

Multiple weight entries per dive:

```sql
CREATE TABLE dive_weights (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  weight_type TEXT NOT NULL,
  amount_kg REAL NOT NULL,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL
);
```

### EquipmentSets

Named collections of equipment items:

```sql
CREATE TABLE equipment_sets (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### EquipmentSetItems

Junction table for equipment items in sets:

```sql
CREATE TABLE equipment_set_items (
  set_id TEXT REFERENCES equipment_sets(id) ON DELETE CASCADE,
  equipment_id TEXT REFERENCES equipment(id) ON DELETE CASCADE,
  PRIMARY KEY (set_id, equipment_id)
);
```

### ServiceRecords

Equipment service history:

```sql
CREATE TABLE service_records (
  id TEXT PRIMARY KEY,
  equipment_id TEXT REFERENCES equipment(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL,
  service_date INTEGER NOT NULL,
  provider TEXT,
  cost REAL,
  currency TEXT DEFAULT 'USD',
  next_service_due INTEGER,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### TankPresets

Custom tank presets (user-defined tank configurations):

```sql
CREATE TABLE tank_presets (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  volume_liters REAL NOT NULL,
  working_pressure_bar INTEGER NOT NULL,
  material TEXT NOT NULL,
  description TEXT DEFAULT '',
  sort_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## People Tables

### Buddies

Dive buddy contact list:

```sql
CREATE TABLE buddies (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  certification_level TEXT,
  certification_agency TEXT,
  photo_path TEXT,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveBuddies

Junction table for buddies on each dive (many-to-many with role):

```sql
CREATE TABLE dive_buddies (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  buddy_id TEXT REFERENCES buddies(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'buddy',
  created_at INTEGER NOT NULL
);
```

### Certifications

Diver certifications:

```sql
CREATE TABLE certifications (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  agency TEXT NOT NULL,
  level TEXT,
  card_number TEXT,
  issue_date INTEGER,
  expiry_date INTEGER,
  instructor_name TEXT,
  instructor_number TEXT,
  photo_front_path TEXT,
  photo_back_path TEXT,
  photo_front BLOB,
  photo_back BLOB,
  course_id TEXT REFERENCES courses(id) ON DELETE SET NULL,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Courses

Training courses (e.g., "Advanced Open Water", "Rescue Diver"):

```sql
CREATE TABLE courses (
  id TEXT PRIMARY KEY,
  diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  agency TEXT NOT NULL,
  start_date INTEGER NOT NULL,
  completion_date INTEGER,
  instructor_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
  instructor_name TEXT,
  instructor_number TEXT,
  certification_id TEXT,
  location TEXT,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Organization Tables

### Tags

Tags for organizing dives:

```sql
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  color TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveTags

Junction table for dive tags (many-to-many):

```sql
CREATE TABLE dive_tags (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  tag_id TEXT REFERENCES tags(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL
);
```

### DiveTypes

Custom dive types:

```sql
CREATE TABLE dive_types (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  is_built_in INTEGER DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Profile Tables

### DiveComputers

Dive computer devices:

```sql
CREATE TABLE dive_computers (
  id TEXT PRIMARY KEY,
  diver_id TEXT REFERENCES divers(id),
  name TEXT NOT NULL,
  manufacturer TEXT,
  model TEXT,
  serial_number TEXT,
  firmware_version TEXT,
  connection_type TEXT,
  bluetooth_address TEXT,
  last_dive_fingerprint TEXT,
  last_download_timestamp INTEGER,
  dive_count INTEGER DEFAULT 0,
  is_favorite INTEGER DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DiveProfileEvents

Profile events (markers on dive profile):

```sql
CREATE TABLE dive_profile_events (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  severity TEXT DEFAULT 'info',
  description TEXT,
  depth REAL,
  value REAL,
  tank_id TEXT,
  created_at INTEGER NOT NULL
);
```

### GasSwitches

Gas switches during a dive:

```sql
CREATE TABLE gas_switches (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  tank_id TEXT REFERENCES dive_tanks(id) ON DELETE CASCADE,
  depth REAL,
  created_at INTEGER NOT NULL
);
```

### TankPressureProfiles

Per-tank time-series pressure data for multi-tank dives (AI transmitters):

```sql
CREATE TABLE tank_pressure_profiles (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  tank_id TEXT NOT NULL REFERENCES dive_tanks(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  pressure REAL NOT NULL
);

CREATE INDEX idx_tank_pressure_dive_tank
  ON tank_pressure_profiles(dive_id, tank_id, timestamp);
```

## Marine Life Tables

### Species

Marine life species catalog:

```sql
CREATE TABLE species (
  id TEXT PRIMARY KEY,
  common_name TEXT NOT NULL,
  scientific_name TEXT,
  category TEXT NOT NULL,
  taxonomy_class TEXT,
  description TEXT,
  photo_path TEXT,
  is_built_in INTEGER DEFAULT 0
);
```

### Sightings

Marine life sightings per dive:

```sql
CREATE TABLE sightings (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  species_id TEXT NOT NULL REFERENCES species(id),
  count INTEGER DEFAULT 1,
  notes TEXT DEFAULT ''
);
```

### SiteSpecies

Junction table for expected species at dive sites (manual curation):

```sql
CREATE TABLE site_species (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL REFERENCES dive_sites(id) ON DELETE CASCADE,
  species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL
);
```

## Media Tables

### Media

Photos, videos, and signatures:

```sql
CREATE TABLE media (
  id TEXT PRIMARY KEY,
  dive_id TEXT REFERENCES dives(id) ON DELETE SET NULL,
  site_id TEXT REFERENCES dive_sites(id) ON DELETE SET NULL,
  file_path TEXT NOT NULL,
  file_type TEXT DEFAULT 'photo',
  latitude REAL,
  longitude REAL,
  taken_at INTEGER,
  caption TEXT,
  -- Signature fields
  signer_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
  signer_name TEXT,
  signature_type TEXT,
  image_data BLOB,
  -- Gallery photo fields
  platform_asset_id TEXT,
  original_filename TEXT,
  width INTEGER,
  height INTEGER,
  duration_seconds INTEGER,
  is_favorite INTEGER DEFAULT 0,
  thumbnail_generated_at INTEGER,
  last_verified_at INTEGER,
  is_orphaned INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### MediaEnrichment

Enrichment data calculated from dive profile at photo timestamp:

```sql
CREATE TABLE media_enrichment (
  id TEXT PRIMARY KEY,
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  depth_meters REAL,
  temperature_celsius REAL,
  elapsed_seconds INTEGER,
  match_confidence TEXT DEFAULT 'exact',
  timestamp_offset_seconds INTEGER,
  created_at INTEGER NOT NULL
);
```

### MediaSpecies

Species tags on media (many-to-many with optional spatial annotation):

```sql
CREATE TABLE media_species (
  id TEXT PRIMARY KEY,
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  sighting_id TEXT REFERENCES sightings(id) ON DELETE SET NULL,
  bbox_x REAL,
  bbox_y REAL,
  bbox_width REAL,
  bbox_height REAL,
  notes TEXT,
  created_at INTEGER NOT NULL
);
```

### PendingPhotoSuggestions

Pending photo suggestions for background scan feature:

```sql
CREATE TABLE pending_photo_suggestions (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  platform_asset_id TEXT NOT NULL,
  taken_at INTEGER NOT NULL,
  thumbnail_path TEXT,
  dismissed INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL
);
```

## Tide Tables

### TideRecords

Tide data recorded with a dive for historical reference:

```sql
CREATE TABLE tide_records (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  height_meters REAL NOT NULL,
  tide_state TEXT NOT NULL,
  rate_of_change REAL,
  high_tide_height REAL,
  high_tide_time INTEGER,
  low_tide_height REAL,
  low_tide_time INTEGER,
  created_at INTEGER NOT NULL
);
```

## Settings Tables

### Settings

Application settings key-value store (legacy):

```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at INTEGER NOT NULL
);
```

**Sync:** every key syncs, and each key merges on its own clock, except the
keys in `deviceLocalSettingsKeys` in
`lib/core/services/sync/device_local_fields.dart` (today `active_diver_id`,
`nav_primary_ids`, `nav_rail_ids` and `nav_always_hide_labels`). Those are
filtered on export, skipped on import, kept through a replace-adopt, and never
queued for sync when written. A new key syncs unless you add it there.

### DiverSettings

Per-diver settings with unit preferences, decompression parameters, and UI configuration:

```sql
CREATE TABLE diver_settings (
  id TEXT PRIMARY KEY,
  diver_id TEXT NOT NULL REFERENCES divers(id),
  -- Unit settings
  depth_unit TEXT DEFAULT 'meters',
  temperature_unit TEXT DEFAULT 'celsius',
  pressure_unit TEXT DEFAULT 'bar',
  volume_unit TEXT DEFAULT 'liters',
  weight_unit TEXT DEFAULT 'kilograms',
  altitude_unit TEXT DEFAULT 'meters',
  sac_unit TEXT DEFAULT 'litersPerMin',
  -- Time/Date format
  time_format TEXT DEFAULT 'twelveHour',
  date_format TEXT DEFAULT 'mmmDYYYY',
  -- Theme
  theme_mode TEXT DEFAULT 'system',
  theme_preset TEXT DEFAULT 'submersion',
  -- Locale
  locale TEXT DEFAULT 'system',
  -- Defaults
  default_dive_type TEXT DEFAULT 'recreational',
  default_tank_volume REAL DEFAULT 12.0,
  default_start_pressure INTEGER DEFAULT 200,
  -- Decompression settings
  gf_low INTEGER DEFAULT 30,
  gf_high INTEGER DEFAULT 70,
  pp_o2_max_working REAL DEFAULT 1.4,
  pp_o2_max_deco REAL DEFAULT 1.6,
  cns_warning_threshold INTEGER DEFAULT 80,
  ascent_rate_warning REAL DEFAULT 9.0,
  ascent_rate_critical REAL DEFAULT 12.0,
  last_stop_depth REAL DEFAULT 3.0,
  deco_stop_increment REAL DEFAULT 3.0,
  o2_narcotic INTEGER DEFAULT 1,
  end_limit REAL DEFAULT 30.0,
  use_dive_computer_cns_data INTEGER DEFAULT 0,
  default_ndl_source INTEGER DEFAULT 1,
  default_tts_source INTEGER DEFAULT 1,
  default_cns_source INTEGER DEFAULT 1,
  -- Profile display settings
  show_ceiling_on_profile INTEGER DEFAULT 1,
  show_ascent_rate_colors INTEGER DEFAULT 1,
  show_ndl_on_profile INTEGER DEFAULT 1,
  show_max_depth_marker INTEGER DEFAULT 1,
  show_pressure_threshold_markers INTEGER DEFAULT 0,
  -- Appearance settings
  show_depth_colored_dive_cards INTEGER DEFAULT 0,
  card_color_attribute TEXT DEFAULT 'none',
  card_color_gradient_preset TEXT DEFAULT 'ocean',
  card_color_gradient_start INTEGER,
  card_color_gradient_end INTEGER,
  tissue_color_scheme TEXT DEFAULT 'classic',
  tissue_viz_mode TEXT DEFAULT 'heatMap',
  show_map_background_on_dive_cards INTEGER DEFAULT 0,
  show_map_background_on_site_cards INTEGER DEFAULT 0,
  -- Dive profile chart defaults
  default_right_axis_metric TEXT DEFAULT 'temperature',
  default_show_temperature INTEGER DEFAULT 1,
  default_show_pressure INTEGER DEFAULT 1,
  default_show_heart_rate INTEGER DEFAULT 0,
  default_show_sac INTEGER DEFAULT 0,
  default_show_events INTEGER DEFAULT 1,
  default_show_pp_o2 INTEGER DEFAULT 0,
  default_show_pp_n2 INTEGER DEFAULT 0,
  default_show_pp_he INTEGER DEFAULT 0,
  default_show_gas_density INTEGER DEFAULT 0,
  default_show_gf INTEGER DEFAULT 0,
  default_show_surface_gf INTEGER DEFAULT 0,
  default_show_mean_depth INTEGER DEFAULT 0,
  default_show_tts INTEGER DEFAULT 0,
  default_show_cns INTEGER DEFAULT 0,
  default_show_otu INTEGER DEFAULT 0,
  default_show_gas_switch_markers INTEGER DEFAULT 1,
  -- Notification settings
  notifications_enabled INTEGER DEFAULT 1,
  service_reminder_days TEXT DEFAULT '[7, 14, 30]',
  reminder_time TEXT DEFAULT '09:00',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

**Sync:** the table syncs as a whole row, and the row with the later clock
wins, so a new column syncs unless it is listed in `deviceLocalSyncColumns` in
`lib/core/services/sync/device_local_fields.dart`. Today that lists
`notifications_enabled`, `service_reminder_days`, `reminder_time`,
`trip_service_lead_days` and `theme_mode` (issue #2947). A listed column is
left out of every export, refilled from this device on import (or from the
snapshot a replace-adopt takes before clearing the table), and a save that
changes only listed columns stamps no clock and queues nothing. A per-device
setting with no reason to be per diver can live in SharedPreferences instead
(see `settings_providers.dart`).

When a change moves a setting between synced and device-local, in this table,
the `settings` table, or SharedPreferences, update the
[What Syncs Between Devices](guide/multi-device-sync.md?id=what-syncs-between-devices) section of the user
guide in the same PR.

## Sync Tables

### SyncMetadata

Global sync metadata - tracks sync state for this device:

```sql
CREATE TABLE sync_metadata (
  id TEXT PRIMARY KEY,
  last_sync_timestamp INTEGER,
  device_id TEXT NOT NULL,
  sync_provider TEXT,
  remote_file_id TEXT,
  sync_version INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### SyncRecords

Per-record sync tracking for conflict detection:

```sql
CREATE TABLE sync_records (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  local_updated_at INTEGER NOT NULL,
  synced_at INTEGER,
  sync_status TEXT DEFAULT 'synced',
  conflict_data TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### DeletionLog

Deletion log for tracking deleted records during sync:

```sql
CREATE TABLE deletion_log (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  deleted_at INTEGER NOT NULL
);
```

## Maps Tables

### CachedRegions

Cached map regions for offline use:

```sql
CREATE TABLE cached_regions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  min_lat REAL NOT NULL,
  max_lat REAL NOT NULL,
  min_lng REAL NOT NULL,
  max_lng REAL NOT NULL,
  min_zoom INTEGER NOT NULL,
  max_zoom INTEGER NOT NULL,
  tile_count INTEGER NOT NULL,
  size_bytes INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  last_accessed_at INTEGER NOT NULL
);
```

## Notification Tables

### ScheduledNotifications

Tracks scheduled notifications to enable smart rescheduling:

```sql
CREATE TABLE scheduled_notifications (
  id TEXT PRIMARY KEY,
  equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  scheduled_date INTEGER NOT NULL,
  reminder_days_before INTEGER NOT NULL,
  notification_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

## Relationship Patterns

### One-to-Many

```dart
// Diver has many Dives
TextColumn get diverId => text().nullable().references(Divers, #id)();
```

### Many-to-Many

Junction tables with composite keys:

```dart
// Dives <-> Equipment
class DiveEquipment extends Table {
  TextColumn get diveId =>
    text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
    text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};
}
```

### Junction with Attributes

```dart
// DiveBuddies has role attribute
class DiveBuddies extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
    text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
    text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('buddy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

## Cascade Deletes

Child records auto-delete:

```dart
TextColumn get diveId =>
  text().references(Dives, #id, onDelete: KeyAction.cascade)();
```

Used for:

- DiveProfiles (dive deleted -> profiles deleted)
- DiveTanks
- DiveWeights
- DiveProfileEvents
- GasSwitches
- TankPressureProfiles
- TideRecords
- DiveCustomFields
- Sightings
- DiveTags
- DiveBuddies

## Repository Pattern

### Base Repository

```dart
class DiveRepository {
  final AppDatabase _db = DatabaseService.instance.database;

  Future<List<domain.Dive>> getAllDives({String? diverId}) async {
    final query = _db.select(_db.dives);
    if (diverId != null) {
      query.where((d) => d.diverId.equals(diverId));
    }
    query.orderBy([(d) => OrderingTerm.desc(d.diveDateTime)]);

    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
  }

  Future<domain.Dive> createDive(domain.Dive dive) async {
    final companion = _toCompanion(dive);
    await _db.into(_db.dives).insert(companion);
    return dive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    await (_db.update(_db.dives)
      ..where((d) => d.id.equals(dive.id)))
      .write(_toCompanion(dive));
  }

  Future<void> deleteDive(String id) async {
    await (_db.delete(_db.dives)
      ..where((d) => d.id.equals(id)))
      .go();
  }
}
```

### Domain Mapping

```dart
domain.Dive _mapToDomain(Dive row) {
  return domain.Dive(
    id: row.id,
    diverId: row.diverId,
    diveNumber: row.diveNumber,
    dateTime: DateTime.fromMillisecondsSinceEpoch(row.diveDateTime),
    // ... map all fields
  );
}

DivesCompanion _toCompanion(domain.Dive dive) {
  return DivesCompanion(
    id: Value(dive.id),
    diverId: Value(dive.diverId),
    diveNumber: Value(dive.diveNumber),
    diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
    // ... map all fields
  );
}
```

## Queries

### Select with Joins

```dart
Future<domain.Dive?> getDiveWithDetails(String id) async {
  final query = _db.select(_db.dives).join([
    leftOuterJoin(_db.diveSites,
      _db.diveSites.id.equalsExp(_db.dives.siteId)),
    leftOuterJoin(_db.diveCenters,
      _db.diveCenters.id.equalsExp(_db.dives.diveCenterId)),
  ]);
  query.where(_db.dives.id.equals(id));

  final row = await query.getSingleOrNull();
  if (row == null) return null;

  return _mapWithRelations(row);
}
```

### Aggregations

```dart
Future<DiveStats> getStats(String diverId) async {
  final result = await _db.customSelect('''
    SELECT
      COUNT(*) as dive_count,
      SUM(duration) as total_time,
      MAX(max_depth) as max_depth
    FROM dives
    WHERE diver_id = ?
  ''', variables: [Variable.withString(diverId)]).getSingle();

  return DiveStats(
    diveCount: result.read<int>('dive_count'),
    totalTime: result.read<int>('total_time'),
    maxDepth: result.read<double>('max_depth'),
  );
}
```

## Seeded Data

Built-in dive types seeded on create:

```dart
final builtInTypes = [
  ('recreational', 'Recreational', 0),
  ('technical', 'Technical', 1),
  ('freedive', 'Freedive', 2),
  // ...
];

for (final type in builtInTypes) {
  await customStatement('''
    INSERT OR IGNORE INTO dive_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
    VALUES (?, ?, 1, ?, ?, ?)
  ''');
}
```

## Performance Tips

### Indexes

Indexes exist for common queries:

- `dive_profiles(dive_id, timestamp)` - Profile data by dive
- `dive_profiles(dive_id)` - Profile loading
- `dives(diver_id, dive_date_time DESC)` - Dive list queries
- `dives(diver_id, entry_time DESC)` - Entry time ordering
- `dives(site_id)`, `dives(trip_id)`, `dives(dive_center_id)`, `dives(course_id)` - FK lookups
- `dives(diver_id, is_favorite)` - Favorite filter
- `dive_tanks(dive_id)`, `dive_equipment(dive_id)`, `dive_weights(dive_id)` - Child tables
- `dive_tags(dive_id)`, `dive_tags(tag_id)`, `dive_buddies(dive_id)` - Junction lookups
- `tank_pressure_profiles(dive_id, tank_id, timestamp)` - Pressure data
- `sync_records(entity_type, record_id)` - Sync lookups
- `media(platform_asset_id)` - Gallery photo lookups
- `media_enrichment(media_id)`, `media_enrichment(dive_id)` - Enrichment lookups
- `media_species(media_id)`, `media_species(species_id)` - Species tagging
- `site_species(site_id)` - Site species lookups
- `tide_records(dive_id)` - Tide data
- `courses(diver_id)` - Course lookups
- `scheduled_notifications(equipment_id)` - Notification lookups
- `pending_photo_suggestions(dive_id)` - Photo suggestions
- `dive_custom_fields(dive_id)`, `dive_custom_fields(field_key)` - Custom field lookups

### Batch Operations

```dart
Future<void> bulkInsertProfiles(List<DiveProfile> profiles) async {
  await _db.batch((batch) {
    batch.insertAll(_db.diveProfiles,
      profiles.map(_toCompanion).toList());
  });
}
```

### Lazy Loading

Don't load profiles until needed:

```dart
// In dive list: just dive data
// In dive detail: load profile on demand
```
