# Custom certification agencies and levels, plus ACUC and DAN

Issue: #690. Release: v1.8.2.

## Problem

A diver who trained with an agency Submersion does not list has to pick
"Other", and the agency's name is lost. The request (r/submersion) asked for
ACUC, DAN and FFESSM, and for a way to add agencies "like you can with
species".

FFESSM already shipped as a built-in (#1607). What remains:

1. ACUC and DAN as built-in agencies with their own certification ladders.
2. User-defined agencies, and user-defined certifications (levels) that can be
   appended to any agency, built-in or custom.

The issue text proposed moving every built-in agency and level into database
tables. This design keeps built-ins in code instead (see "Approach").

## Decisions

| Topic | Decision |
| --- | --- |
| Approach | Built-ins stay code constants; only custom entries live in tables |
| Entry points | Settings > Manage page and an "Add custom..." item in the edit-page dropdowns |
| Custom agency colour | User picks from a swatch palette; a new agency starts on a colour derived from its id |
| Deleting an entry in use | Refused, with usage counts; nothing is rewritten |
| Custom level grouping | User picks Progression (ranked, reorderable) or Specialty |
| Ownership | Owned per diver, with a share toggle like sites; shared entries appear for every profile, only the owner edits or deletes |
| Built-in ladders | Add-only: users may append levels, never rename, reorder or remove built-ins |
| Imports | An unknown agency string becomes a custom agency; unknown level text keeps today's behaviour |
| Explore | Custom agencies and levels are valid query values |

## Approach

Three were considered:

- **A (chosen). Built-ins in code, custom entries in two tables.**
- B. Everything table-backed: three tables (agencies, levels, an agency/level
  junction) with every built-in seeded.
- C. Free-text companion columns with no catalog.

B was rejected because built-in reference data in a synced table carries a
known failure class. Exporters filter `is_built_in` rows out, so sync adopt
wiped built-in dive types until a `deleteAllRecords` guard and a `beforeOpen`
re-seed were added (#530). Composite-key junctions rebuilt by delete and
reinsert lost membership on sync (#347). B would need both mitigations for
about 140 seeded levels and 200 ladder rows, plus a schema rung for every
future built-in level. Localized built-in names would still be a switch over
ids in code, so the enums would not go away. Under A, built-ins never touch the
database: a future built-in stays a code-only change, and the custom tables
hold only user data, which syncs like any other entity.

C was rejected because it gives no reuse, ladders, colours or manage page.

## Built-ins

### New agencies

`CertificationAgency` (`lib/core/constants/enums.dart`) gains two values:

| Value | displayName | primaryColor | secondaryColor |
| --- | --- | --- | --- |
| `acuc` | ACUC | `0xFF0D3B7A` (navy) | `0xFF2E6BC4` |
| `dan` | DAN | `0xFF9E1B32` (crimson) | `0xFFD23C52` |

Both names are brands and are not translated. Each gets an
`enum_certificationAgency_*` ARB key whose value is the brand name in every
locale, matching the existing agencies.

### New levels

ACUC (American Canadian Underwater Certifications), from ACUC's
start-your-adventure, continue-your-adventure and leadership-levels pages:

| Id | displayName |
| --- | --- |
| `acucScubaDiver` | Scuba Diver |
| (existing) `openWater` | Open Water Diver |
| `acucAdvancedDiver` | Advanced Diver |
| `acucRescueLeader` | Rescue Leader |
| (existing) `masterDiver` | Master Diver |
| `acucUnderwaterGuide` | Underwater Guide |
| `acucTeachingAssistant` | Teaching Assistant |
| `acucOpenWaterInstructor` | Open Water Instructor |
| `acucAdvancedInstructor` | Advanced Instructor |
| `acucInstructorTrainer` | Instructor Trainer |
| `acucInstructorTrainerEvaluator` | Instructor Trainer Evaluator |

`_acucLadder` is the 11 rows above in that order. ACUC uses the shared
`specialties` list.

DAN (Divers Alert Network) issues first-aid and emergency credentials, not
diver grades, so it gets no diving levels:

| Id | displayName | Group |
| --- | --- | --- |
| `danBls` | Basic Life Support: CPR and First Aid | Progression |
| `danEmergencyOxygen` | Emergency Oxygen for Scuba Diving Injuries | Progression |
| `danDfaPro` | Diving First Aid for Professional Divers | Progression |
| `danDemp` | Diving Emergency Management Provider | Progression |
| `danInstructor` | DAN Instructor | Progression |
| `danInstructorTrainer` | DAN Instructor Trainer | Progression |
| `danAdvancedOxygen` | Advanced Oxygen Provider | Specialty |
| `danNeurologicalAssessment` | On-Site Neurological Assessment | Specialty |
| `danMarineLifeInjuries` | First Aid for Hazardous Marine Life Injuries | Specialty |

`_danSpecialties` replaces the shared diving specialties for DAN, the way
`_ffessmSpecialties` does for FFESSM, so DAN never offers "Trimix".

ACUC and DAN level names are proper names and fall back to `displayName` in
`CertificationLevelDisplay.localizedName`, like the BSAC, GUE and FFESSM
ratings. `isInstructorLevel` returns true for the instructor and instructor
trainer values of both agencies.

## Data model

### Tables (schema v267)

Planned as v261; main shipped v261 to v266 while this was open, so the
rung is v267.

Both tables go in `lib/core/database/tables/buddy_tables.dart` beside
`Certifications`, and the rung goes in `lib/core/database/migrations/`, never
in `database.dart`.

`custom_certification_agencies`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `diver_id` | text, FK divers (no ON DELETE action) | Owner |
| `name` | text | Trimmed, non-empty |
| `color_argb` | integer | Primary card colour; the secondary is derived |
| `is_shared` | bool, default false | Visible to every profile when true |
| `created_at`, `updated_at` | integer | Epoch ms |
| `hlc` | text, nullable | HLC clock |

`custom_certification_levels`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `diver_id` | text, FK divers (no ON DELETE action) | Owner |
| `agency_id` | text | A built-in enum name or a custom agency UUID. No FK, because built-ins have no row |
| `name` | text | Trimmed, non-empty |
| `is_progression` | bool | Progression rung or specialty |
| `sort_order` | integer, default 0 | Rank among this agency's custom progression rungs |
| `is_shared` | bool, default false | Used only when `agency_id` is a built-in |
| `created_at`, `updated_at` | integer | Epoch ms |
| `hlc` | text, nullable | HLC clock |

Index: `custom_certification_levels(agency_id)`.

The migration creates both tables and the index. There is no data migration:
existing `certifications.agency`, `certifications.level`,
`certifications.additional_credentials` and `courses.agency` values are
built-in enum names, which stay valid ids. `beforeOpen` re-asserts both tables
(`CREATE TABLE IF NOT EXISTS`, guarded on `sqlite_master`) for databases that
reached v267 by another path, following the existing backstop pattern.

### Visibility and ownership

- A profile sees its own custom agencies plus every shared one.
- A custom level under a custom agency is visible exactly when its agency is.
  Its own `is_shared` is ignored.
- A custom level under a built-in agency is visible to its owner, and to every
  profile when its `is_shared` is true.
- Only the owner may edit, reorder, share or delete. The repository refuses
  writes from another diver, as the site repository does (`_siteOwnership`).
- A new custom agency, and a new custom level under a built-in agency, start
  with `is_shared` set from the existing "Share by default" setting, as new
  sites and trips do.
- Existing references always render for every profile, visible or not,
  through the catalog's id lookup.

### Domain types

Ids become strings. The database columns do not change.

| Field | Before | After |
| --- | --- | --- |
| `Certification.agency` | `CertificationAgency` | `String` |
| `Certification.level` | `CertificationLevel?` | `String?` |
| `CertificationCredential.agency` / `.level` | enums | `String` / `String?` |
| `Course.agency` | `CertificationAgency` | `String` |
| `Buddy.certificationAgency` / `.certificationLevel` | enums | `String?` |

The enums stay as the built-in catalog. `CertificationAgency.fromId(String?)`
and `CertificationLevel.fromId(String?)` return the matching value or null.
Constants such as `CertificationAgency.padi.name` remain the way code names a
built-in id.

New domain entities in `lib/features/certification_agencies/domain/entities/`:
`CustomCertificationAgency` and `CustomCertificationLevel`. Both are Equatable,
carry every column above and have `copyWith`.

### The catalog

`lib/features/certification_agencies/domain/certification_catalog.dart`
defines an immutable `CertificationCatalog`, built from the built-in enums plus
the custom rows the active diver can see. It exposes:

- `List<AgencyEntry> agencies`: built-ins in enum order, `other` last, with
  visible custom agencies between them, alphabetical.
- `AgencyEntry agency(String? id)`: never null. Order: built-in, then any
  custom row (visible or not), then a fallback.
- `LevelEntry level(String id)`: same resolution.
- `List<LevelEntry> ladderFor(String? agencyId)`: the built-in ladder, then the
  agency's custom progression rungs in `sort_order`, then by name.
- `List<LevelEntry> specialtiesFor(String? agencyId)`: built-in specialties not
  on the ladder, then the agency's custom specialties alphabetically.
- `List<LevelEntry> levelsFor(String? agencyId, {String? ensure})`: as today's
  `CertificationLevelCatalog.levelsFor`, so a stored value from another
  agency still renders.

`AgencyEntry` holds `id`, `name`, `primaryColor`, `secondaryColor`,
`isBuiltIn`, `isFallback` and the built-in enum value if any. `LevelEntry`
holds `id`, `name`, `agencyId`, `isProgression`, `isBuiltIn`, `isFallback`,
`isInstructorLevel` and the built-in enum value if any. Display names for
built-ins come from `localizedName(l10n)` through a display extension, and
custom names are returned verbatim.

The fallback replaces every `orElse: CertificationAgency.other` and
`orElse: CertificationLevel.other` parse site, which today silently collapse an
unknown value to "Other" and lose it on the next save:

- An id that looks like a slug (`^[a-z][A-Za-z0-9]*$`), for example a newer
  build's built-in, displays as itself.
- Anything else (a custom UUID whose row has not synced, or was deleted
  elsewhere) displays as "Unknown agency" or "Unknown certification".
- A fallback agency uses the `other` colours.
- Saving writes the stored id back unchanged.

`certificationCatalogProvider` (Riverpod) builds the catalog for the active
diver and rebuilds when either custom table changes. The existing
`CertificationLevelCatalog` keeps the built-in ladders and is what the catalog
reads them from.

### Ranking

`primaryCertification` ranks a certification by its level's index in
`catalog.ladderFor(agency)`. Custom rungs sit after the built-in ladder, so a
built-in rung's index never moves. A specialty, a null level or a fallback
level ranks -1, as today. The tie-breaks (latest `issueDate`, then latest
`updatedAt`) are unchanged. Callers pass the catalog.

## Repository

`lib/features/certification_agencies/data/repositories/custom_certification_repository.dart`:

- `watchVisible(diverId)` and `getAll()` for both tables.
- `createAgency`, `updateAgency`, `setAgencyShared`, `deleteAgency`.
- `createLevel`, `updateLevel`, `reorderProgression(agencyId, ids)`,
  `setLevelShared`, `deleteLevel`.
- `usage(id)`: counts of certifications (by `agency`, `level` and the
  `additional_credentials` JSON), courses and buddy certifications that
  reference the id.

Rules:

- Names are trimmed and required. Agency names are unique case-insensitively
  among the diver's visible agencies, built-in display names included, so a
  second "PADI" cannot be created. Level names are unique case-insensitively
  within an agency's visible levels, built-in included.
- `deleteAgency` and `deleteLevel` refuse while `usage` is non-zero and return
  the counts. Deleting a custom agency also deletes its custom levels, and
  every one of them must be unused too.
- Every write marks the record pending, and every delete writes a tombstone, as
  `certification_repository.dart` does.
- Errors are caught, logged and rethrown as the existing repositories do.

## UI

### Settings > Manage > Certification Agencies

This is a new tile after Dive Roles in the Manage section, with the route
`/certification-agencies`. It is built from `dive_roles_page.dart`, following
the Manage-page convention: a lower-right extended FAB ("Add agency") and
inline edit and delete icons, with no app-bar action and no overflow menu.

- **Your agencies:** the diver's own custom agencies, plus shared agencies from
  other profiles. Those show "Shared by <diver name>" as the subtitle and have
  no edit or delete icons.
- **Built-in agencies:** no edit or delete. Tapping one opens its editor in a
  read-only mode where only levels can be appended.

Each row leads with a small card-gradient swatch.

### Agency editor page

- Name field (disabled for built-ins).
- Colour swatch row, reusing `TagColorPicker` and the `TagColors.predefined`
  palette. The secondary gradient colour is derived by lightening the
  primary. Hidden for built-ins.
- "Share with other divers" switch, shown only when the database has two or
  more divers, as on the site editor. Hidden for built-ins.
- Live mini e-card preview using the chosen name and colours.
- **Progression** section: built-in rungs read-only and dimmed, then custom
  rungs in a `ReorderableListView` with edit and delete icons.
- **Specialties** section: built-in specialties read-only, then custom
  specialties alphabetically with edit and delete icons.
- "Add certification" button opening the level dialog.

### Level dialog

Fields: name, a Progression / Specialty segmented control, and, under a
built-in agency only, a share switch (again shown only with two or more
divers). The same dialog is used from the manage page and from quick-create.

### Delete refusal

Delete is refused with a dialog naming the counts, for example "Used by 3
certifications and 1 course. Change those first." An unused entry deletes after
the usual confirmation.

### Edit-page pickers

These are in `certification_edit_page.dart`, used by the diver's own and by
buddy certifications, and in `course_edit_page.dart`.

- The agency dropdown lists `catalog.agencies`, then an "Add custom agency..."
  action item.
- The certification dropdown keeps its order: Not specified, the Progression
  header and rungs (custom rungs included in place), the Specialties header and
  specialties, any `ensure` value, then "Add custom certification...", then
  Other.
- An "Add custom..." item opens the same dialog. On save the new entry is
  created and selected, and the dropdown remounts on the new value. A new
  agency gets its id-derived default colour, and an agency created this way
  starts with no levels.
- The dropdown value type becomes the id string, wrapped in
  `CertificationOption` as today, so header and action rows keep unique values.
- A stored id that does not resolve renders through its fallback entry and is
  not reset.

### Other readers

Every display reads names and colours from the catalog entry instead of the
enum:

- certification detail and list
- e-card front, wallet card and the card renderer
- PDF templates (`pdf_front_matter.dart`, `pdf_shared_components.dart`, the
  course export)
- buddy list tile, buddy picker and the buddy certification line
- instructor picker (`isInstructorLevel` from the entry)
- certification and course providers' sort by name
- `certificationTitle` and its legacy-name matching
- field extractors (`certification_field.dart`, `buddy_field.dart`,
  `course_field.dart`), which write display names
- the e-card semantics label

## Sync

- Register `customCertificationAgencies` and `customCertificationLevels` in
  `sync_data_serializer.dart` at every per-entity switch site, following the
  `diveRoles` wiring, and in `sync_service.dart`'s entity order, with agencies
  before levels.
- Neither table has built-in rows, so exporters do not filter, and
  `deleteAllRecords` needs no guard. `sync_builtin_reference_data_test.dart`
  discovers `is_built_in` tables and is unaffected.
- A level that arrives before its agency resolves under a fallback agency until
  the agency arrives. No ordering constraint is enforced.
- Diver deletion clears both tables row by row through the `_ownedTables`
  registry (`diver_owned_rows.dart`), levels before agencies, tombstoning each
  row, as it does for `dive_roles`. A schema cascade would delete without
  tombstones. A deleted diver's shared entries go with them, as their shared
  sites do; another profile's references then render through the fallback.

## Import and export

- **UDDF export:** built-in ids keep writing the enum name, so round-trips are
  unchanged. A custom agency or level writes its display name.
- **Agency import** (UDDF, divelogs, universal adapter): a built-in matches
  exactly as today (case-insensitive enum name or display name). Otherwise the
  text matches a visible custom agency by case-insensitive name. Otherwise a
  new custom agency is created for the importing diver, with `is_shared` from
  "Share by default" and an id-derived colour. The original text is never
  replaced by "Other". A blank agency keeps today's default.
- **Level import:** built-ins match as today. Unmatched text also matches a
  visible custom level of the resolved agency by case-insensitive name.
  Otherwise the level stays null and the text stays in the certification name,
  as today. Custom levels are not auto-created, because importers such as
  MacDive send free-form card names as the level.
- **Duplicate check** (`import_duplicate_checker.dart`, key `name|agency`)
  uses the stored id.

## Explore query language

- `certificationQueryEntity` and the course entity keep `agency` and `level`
  as `FieldType.enumName` with the built-in value lists.
- `NameIndexLoader` additionally loads the active diver's visible custom
  agencies and levels (own, plus shared), keyed by query field. The two tables
  join `NameIndexLoader.tables`, so a new entry is queryable without a restart.
- The validator, parser completions, value editor and NL engine accept an enum
  value for these fields that is either a built-in name or a custom id the
  NameIndex holds for that field. Completions and the value editor offer custom
  entries after the built-ins.
- `app_query_labels.dart` labels a custom id with its custom name. Built-ins
  keep `localizedName`.

## Localization

New ARB keys (all locales) for:

- the Manage tile and its subtitle
- page and section titles
- the FAB, the level dialog and the share switch
- the "Add custom agency..." and "Add custom certification..." items
- the delete-refusal message (ICU plurals for certification and course counts)
- "Shared by {name}"
- "Unknown agency" and "Unknown certification"
- name validation errors

Agency names are never translated. ACUC and DAN level names stay untranslated
like the other agency-specific ratings.

## Testing

TDD throughout:

- **Migration:** v267 creates both tables and the index on a v261 database,
  existing certification and course rows are unchanged, and the `beforeOpen`
  backstop creates the tables when missing.
- **Catalog:** built-in resolution, custom resolution, slug fallback, UUID
  fallback, merged ladder order, specialties for DAN and FFESSM, and `ensure`.
- **Ranking:** `primaryCertification` with custom rungs; built-in ranks are
  unchanged by custom additions.
- **Repository:** create, edit and reorder; the visibility matrix (own, shared,
  not shared, level under a built-in vs under a custom agency); ownership
  refusal; uniqueness against built-ins; delete refusal with counts including
  `additional_credentials`; cascade delete of an agency's levels.
- **Parse sites:** an unknown stored agency or level survives load and save
  unchanged, in the certification, course and buddy repositories and in the
  credential JSON.
- **Sync:** round-trip of both entities; a level applied before its agency;
  tombstones.
- **Import:** an unknown agency creates a custom agency; a second import reuses
  it; an existing custom name is matched; level text stays in the name. UDDF
  export writes custom display names.
- **Explore:** a custom agency value validates, completes, labels and filters.
- **Widgets:** manage page, agency editor (built-in read-only mode, reorder,
  share switch visibility), quick-create from both dropdowns, and delete
  refusal.
- The roughly 126 existing test files that reference the enums are updated for
  the String id fields.
- `test/architecture/` passes with the new files under `lib/`.

## Out of scope

- Renaming, reordering or hiding built-in agencies or levels.
- Per-profile hiding of another diver's shared agency (no hides table).
- Per-agency course requirements (#601 owns those).
- Moving built-ins into the database.
