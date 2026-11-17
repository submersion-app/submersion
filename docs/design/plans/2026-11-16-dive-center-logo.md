# Dive Center Logo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dive center carries an optional logo, picked like a buddy photo, synced like one, and drawn in place of the store icon wherever a specific center appears.

**Architecture:** A nullable `logo` BLOB column on `dive_centers` (schema v371) holds a 512 px square JPEG from the existing profile photo flow. The `DiveCenter` entity carries it through both repositories and every rebuild-from-scratch writer; the sync serializer moves it as base64 like `buddies.photo`. One `DiveCenterAvatar` widget (logo through `ProfileAvatar`, store icon otherwise) replaces the hand-drawn store icons.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, package:image.

**Spec:** `docs/design/specs/2026-11-16-dive-center-logo-design.md`

## Global Constraints

- Storage is bytes on the row, never a path or a media link.
- Every logo goes through `ImageEncodeSpec.avatar` (512x512 JPEG, quality 85).
- No logo: the store icon exactly as today, never initials.
- Generic "dive center" icons (nav, search labels, import search results, field constants, connections canvas) stay as they are.
- The schema floor (`minimumCompatibleSchemaVersion`) does not move: nullable column, no backfill.
- Every new ARB key is translated in all 11 locales; `flutter gen-l10n` output is committed.
- No em-dashes anywhere; no emojis; `dart format .` before each commit.

## Review Focus

1. Editing a center through the table editor or agent access wipes its logo, because both rebuild a `DiveCenter` from scratch. Expected: logo kept. Tests in Task 3.
2. A peer on an older build sends a center row with no `logo` key. Expected: the local logo survives the merge. Test in Task 4.
3. A transparent PNG picked as a logo. Expected: white behind it, never black. Test in Task 1.
4. A dive list of hundreds of dives at one center. Expected: one shared `Uint8List` per center per batch, so `ProfileAvatar`'s identity-keyed image cache is not defeated. Test in Task 3 (same instance across dives).
5. A closed center with a logo on the map. Expected: still drawn faded through `greyIfClosed`, logo included. Test in Task 7.

---

### Task 1: Encoder flattens transparency onto white

**Files:**
- Modify: `lib/core/services/images/profile_photo_codec.dart` (before `img.encodeJpg`)
- Test: `test/core/services/images/profile_photo_codec_test.dart`

**Interfaces:**
- Produces: no API change; every JPEG the codec writes has transparent source pixels composited onto white.

- [ ] **Step 1: Write the failing test** `'a transparent PNG encodes onto white, not black'`: build a 64x64 RGBA `img.Image` with every pixel `(0, 0, 0, 0)`, `img.encodePng` it, run the codec with `ImageEncodeSpec.avatar` and `declaredName: 'logo.png'`, decode the JPEG and expect the centre pixel's r, g and b each `>= 250`.
- [ ] **Step 2: Run** `flutter test test/core/services/images/profile_photo_codec_test.dart`; expect FAIL (pixel is 0).
- [ ] **Step 3: Implement** in the encode function: when `resized.numChannels == 4`, composite it over a white RGB image of the same size (`img.Image(width, height, numChannels: 3)` filled with `img.ColorRgb8(255, 255, 255)`, then `img.compositeImage(white, resized)`) and encode that. Comment why (JPEG drops alpha; transparent pixels carry rgb 0 and turned black).
- [ ] **Step 4: Run** the codec test file; expect PASS, including existing tests.
- [ ] **Step 5: Commit** `feat(dive-centers): fill transparent picked images with white before JPEG encoding`

### Task 2: Schema v371 `dive_centers.logo`, conflict label

**Files:**
- Modify: `lib/core/database/tables/site_tables.dart` (`DiveCenters`: `BlobColumn get logo => blob().nullable()();` with a doc comment naming the codec, mirroring `Buddies.photo`)
- Create: `lib/core/database/migrations/helpers/dive_center_logo_migrations.dart` (`part of '../app_database_migrations.dart'`; extension `DiveCenterLogoMigrations on AppDatabase` with `Future<void> _assertDiveCenterLogoColumn() => _addColumnIfMissing('dive_centers', 'logo', 'BLOB');`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v371 rung + `reportProgress`, comment as the v370 one)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` or the nearest backstop part file with room (v371 backstop call; NOT `before_open.dart`, which is at its 800-line limit)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 371`, add 371 to `migrationVersions`)
- Modify: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` via `dart run tool/generate_sql_column_notes.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart` (`'logo': ConflictField((l) => l.settings_conflict_field_logo, FieldKind.opaque)`)
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`settings_conflict_field_logo`, beside `settings_conflict_field_photo`'s group), then `flutter gen-l10n`
- Test: `test/core/database/migration_v371_dive_center_logo_test.dart`

**Interfaces:**
- Produces: Drift row class `DiveCenter` gains `Uint8List? logo`; `DiveCentersCompanion` gains `logo`.

- [ ] **Step 1: Write the failing tests** modelled on `migration_v370_buoyancy_default_test.dart`: `'v371 is in the ladder'` (`currentSchemaVersion >= 371`, `migrationVersions` contains 371); `'the new column kept the floor'` (`minimumCompatibleSchemaVersion < 371`); `'upgrading from v370 adds a null logo and keeps the row'` (raw v370 `dive_centers` with one row, open `AppDatabase`, `SELECT logo` reads null, name unchanged).
- [ ] **Step 2: Run** the new test; expect FAIL.
- [ ] **Step 3: Implement** the files above; run `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background), the column notes tool, and `flutter gen-l10n`.
- [ ] **Step 4: Run** the new test, `test/core/database/`, `test/features/agent_access/data/resources/schema_resource_test.dart` and `test/features/settings/presentation/conflicts/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-centers): store a logo on each dive center (schema v371)`

### Task 3: Entity and every writer carry the logo

**Files:**
- Modify: `lib/features/dive_centers/domain/entities/dive_center.dart` (`final Uint8List? logo;`, constructor param, `copyWith({Object? logo = _undefined})` using the file's existing sentinel so null clears; add `logo` to `props` (Equatable compares a `Uint8List` element by element, acceptable at 512 px))
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (create and update companions write `logo: Value(center.logo)`; `_mapRowToDiveCenter` reads `row.logo`; `_mapCustomRowToDiveCenter` reads `row.data['logo'] as Uint8List?`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (both `domain.DiveCenter(` mappers pass `logo: center.logo` / `centerRow.logo`)
- Modify: `lib/features/table_editor/entities/center_table_editor_entity.dart` (`_withValues` passes `logo: current.logo`)
- Modify: `lib/features/agent_access/data/writes/families/center_writes.dart` (`_applied` passes `logo: current.logo`)
- Test: `test/features/dive_centers/data/repositories/dive_center_repository_test.dart` (or the existing repository test file there), `test/features/table_editor/` center entity test, `test/features/agent_access/data/writes/` center writes test, `test/features/dive_log/data/repositories/` list test

**Interfaces:**
- Produces: `DiveCenter.logo` (`Uint8List?`); `DiveCenter.copyWith(logo: null)` clears it.

- [ ] **Step 1: Write the failing tests:**
  - repository: `'a created center keeps its logo'` (create with bytes `[1,2,3]`, `getDiveCenterById` returns equal bytes); `'updating with logo null removes it'`; `'the custom-query list reads the logo'` (the method behind `SELECT * FROM dive_centers`).
  - table editor: `'editing a cell keeps the center logo'`.
  - agent access: `'an agent update keeps the center logo'`.
  - dive repository: `'dives at one center share one logo instance'` (two dives, same center with a logo, `getAllDives` or the batched list method: `identical(a.diveCenter!.logo, b.diveCenter!.logo)`).
  - entity: `'copyWith(logo: null) clears and omitting keeps'`.
- [ ] **Step 2: Run** them; expect FAIL.
- [ ] **Step 3: Implement** the file changes above.
- [ ] **Step 4: Run** the touched test directories; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-centers): carry the logo through the entity and every writer`

### Task 4: Sync moves the logo as base64

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`: base-export table entry `(key: 'diveCenters', ..., blob: true, ...)`; `_exportDiveCenters`, `fetchRecord` arm, batch-fetch arm: `toJson(serializer: _syncBlobSerializer)`; single upsert and batch upsert arms: `DiveCenter.fromJson(data, serializer: _syncBlobSerializer)`
- Test: `test/core/services/sync/sync_blob_base64_test.dart`

- [ ] **Step 1: Write the failing tests** beside the buddy ones: `'a dive center logo is exported as a base64 string'`; `'a dive center logo round-trips through fetchRecord'`; `'a legacy array-encoded center logo still imports'`; `'an older peer's center row without a logo keeps the local logo'` (upsert a center with a logo, then apply `overlayOntoLocal('diveCenters', remoteWithoutLogoKey, await serializer.fetchRecord('diveCenters', id))` through `upsertRecord`, expect the logo unchanged).
- [ ] **Step 2: Run**; expect FAIL on the first three.
- [ ] **Step 3: Implement** the six edits.
- [ ] **Step 4: Run** `test/core/services/sync/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-centers): sync dive center logos as base64`

### Task 5: `DiveCenterAvatar` widget

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/dive_center_avatar.dart`
- Test: `test/features/dive_centers/presentation/widgets/dive_center_avatar_test.dart`

**Interfaces:**
- Produces: `DiveCenterAvatar({Key? key, required Uint8List? logo, double radius = 20, Color? backgroundColor, Color? iconColor, double? iconSize})`. With a logo: `ProfileAvatar(photo: logo, initials: '', radius: radius, backgroundColor: backgroundColor)`. Without: a `CircleAvatar` of the same radius holding `Icon(Icons.store, color: iconColor ?? onPrimaryContainer, size: iconSize ?? radius)` on `backgroundColor ?? primaryContainer`.

- [ ] **Step 1: Write the failing tests** `'shows the store icon with no logo'` (finds `Icons.store`, no `ProfileAvatar`); `'shows the logo through ProfileAvatar'` (a valid tiny JPEG from the codec, finds `ProfileAvatar` with `photo` identical to the input, no store icon).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS. Run `test/architecture/`.
- [ ] **Step 5: Commit** `feat(dive-centers): add a dive center avatar widget`

### Task 6: Pick a logo on the edit page

**Files:**
- Modify: `lib/shared/widgets/profile_photo/profile_photo_source_sheet.dart` (`String? title` param, default `l10n.profilePhoto_sheet_title`)
- Modify: `lib/shared/widgets/profile_photo/profile_photo_picker.dart` (`String? sheetTitle` passed through)
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart` (`Uint8List? _logo` state loaded from the center, tappable 50-radius `DiveCenterAvatar` with the buddy page's camera badge above the Basic Information section, `pickProfilePhoto(context:, hasPhoto: _logo != null, allowContacts: false, sheetTitle: l10n.diveCenters_field_logo)`, sets `_hasChanges`; the saved `DiveCenter(` includes `logo: _logo`). If the page passes 800 lines, move the avatar header into `widgets/dive_center_logo_field.dart`.
- Modify: all 11 ARBs (`diveCenters_field_logo`: "Logo"), `flutter gen-l10n`
- Test: `test/features/dive_centers/presentation/pages/dive_center_edit_page_test.dart` (existing file or new), `test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart`

- [ ] **Step 1: Write the failing tests:** sheet `'uses the given title'`; edit page `'an existing logo is shown and saved unchanged'` and `'remove clears the logo on save'` (drive the sheet's Remove option; saved center has `logo == null`).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the two test files and `test/shared/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-centers): pick a logo on the dive center edit page`

### Task 7: Draw the logo everywhere a center appears

**Files (each store icon for ONE center becomes `DiveCenterAvatar`, keeping its current size and colours):**
- `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` (standard tile), `compact_dive_center_list_tile.dart`, `dense_dive_center_list_tile.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (header, body title icon, location-card markers)
- `lib/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart` (rows for specific centers only; the page-title icon stays)
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart` (`_buildMarker`: logo fills the circle inside the existing rating-coloured border; bottom card leading) and `pages/dive_center_map_page.dart` if it draws its own
- `lib/features/dive_centers/presentation/widgets/dive_center_picker.dart` (row leading; the empty-state icon stays)
- `lib/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart` (`DiveDetailLinkRow` gains `Widget? leading`) and `dive_detail_details_section.dart` (passes a radius-10 `DiveCenterAvatar` only when `logo != null`)
- Tests: the matching widget tests under `test/features/dive_centers/presentation/` and `test/features/dive_log/presentation/widgets/dive_detail/`

- [ ] **Step 1: Write the failing tests:** for the compact tile, the map marker and the picker row, `'shows the center logo when it has one'` (finds `ProfileAvatar` with that `photo`) and the existing store-icon expectations stay green; map: `'a closed center with a logo is still greyed'` (finds the `greyIfClosed` wrapper's `ColorFiltered`); dive detail: `'the dive center row shows its logo'` and `'no logo, no leading avatar'`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the swaps.
- [ ] **Step 4: Run** `test/features/dive_centers/`, `test/features/dive_log/presentation/widgets/dive_detail/`, `test/architecture/`; expect PASS. `flutter analyze` clean, `dart format .`.
- [ ] **Step 5: Commit** `feat(dive-centers): show the logo wherever a dive center appears`
