# Equipment catalogue foundation Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans (the maintainer's rule for this repository: implementation is native, in the session, never subagent-driven). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A curated equipment catalogue in its own repository, read by the app to suggest brand and model in the gear editor, offer a model's details for field-by-field review, keep a synced link from an item to its record, and show the manufacturer's links on a linked item's page.

**Architecture:** Part A builds `submersion-app/equipment-catalogue` (Python 3 standard library: validator, libdivecomputer seed script, build script, release workflow). Part B builds the app: a pure parser and index, bundled-plus-fetched delivery, two synced columns on `equipment` written only through a dedicated repository call, edit fields held in the gear sitting until Save, an offer line and review sheet, and a read-only card.

**Tech Stack:** Flutter, Drift, Riverpod, `http`, `shared_preferences`; Python 3.14 standard library and GitHub Actions in the new repository.

**Spec:** `docs/design/specs/2026-11-27-equipment-catalogue-foundation-design.md` (program: `docs/design/specs/2026-11-27-equipment-catalogue-program.md`). Issue #5118.

## Global Constraints

- No em-dashes anywhere (code, comments, docs, commits, PR text). No emojis.
- Nothing written to the repository or GitHub mentions the AI tool.
- Files 200 to 400 lines typical, 800 max. Tables in `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`; nothing added to `database.dart` beyond the version constant and its comment list entry.
- Schema: next free version (388 at time of writing; renumber at merge if main moved). Nullable columns only, so `syncCompatibilityFloor` does not move.
- Every new string in all 11 ARB files (`lib/l10n/arb/app_*.arb`), then `flutter gen-l10n`.
- Every link opens through `parseWebLink`; only `https` URLs are accepted by the validator and by the app parser.
- Web build: no fetch, setting hidden (`kIsWeb`).
- The fetch sends no query parameters and no diver data; failures are logged and invisible.
- Record ids are permanent once published; `<maker>-<model>` slug, `-<type>` suffix on collision.
- Values in records are in storage units (metres, bar, kg); display goes through the attribute catalogue's dimensions and the active diver's units.
- Local test runs: only the test files written or changed, by path. Never a folder, never the suite.
- `dart format .` before every commit.

## Review Focus

1. **A whole-item rebuild dropping the link.** `_with` in `gear_item_edit_fields.dart`, the clone and transfer services and the fold build `EquipmentItem` whole; an edit of any other field must keep `catalogueId` and `catalogueAnswers`. Test in Task B5.
2. **A typed value overwritten by Apply when the diver typed after opening the sheet.** Apply sets a ticked empty-field value only if the field is still empty in the session at Apply time; a differing row ticked replaces the current session value (the diver ticked it while seeing it). Test in Task B7.
3. **A malformed or hostile catalogue file** (huge, wrong types, `javascript:` links, duplicate ids). Parser skips bad records, drops non-https links, keeps the first of duplicate ids. Test in Task B2.
4. **Two devices editing answers.** Row-level last writer wins on `equipment`; an answers JSON from a newer build keeps unknown keys on rewrite. Test in Task B4 (round trip with unknown keys).
5. **Suggestions with many records and long names** (a few thousand records, "Heinrichs Weikamp OSTC 4 hwOS Sport"). Suggestions capped at 8 rows, wrap at phone width. Widget test at 360 px width in Task B6.

---

## Part A: the `submersion-app/equipment-catalogue` repository

Work in a clone outside the app repository: `~/repos/submersion-app/equipment-catalogue`. Layout mirrors `submersion-app/firmware-catalogue` (read its `fwcat/`, `tests/run_tests.py`, `.github/workflows/` and `AGENTS.md` first and copy their conventions). One PR in that repository for Tasks A1 to A4, opened before the app PR; data PR(s) after.

### Task A1: Repository, contract and sample

**Files (new repository):**
- Create: `README.md`, `AGENTS.md`, `LICENSE` (same licence text as `firmware-catalogue`), `.gitignore`
- Create: `schema/format-1.schema.json`, `schema/sample.json`, `schema/attribute-keys.json`
- Create: `tests/run_tests.py`, `tests/test_sample.py`

**Interfaces:**
- Produces: `schema/sample.json`, byte for byte equal to the app fixture `test/fixtures/equipment_catalogue/sample.json` (Task B1); `schema/attribute-keys.json` shape `{"<EquipmentType name>": {"<key>": {"kind": "<AttributeKind name>", "choices": ["..."]}}}` written by the app's `tool/export_equipment_attribute_keys.dart` (Task B1).

- [ ] **Step 1:** Create the public repository: `gh repo create submersion-app/equipment-catalogue --public --description "Curated dive equipment catalogue for Submersion: models, specs and manufacturer links"` and clone it.
- [ ] **Step 2:** Write `schema/format-1.schema.json` for the format in spec section 2: top-level `format` (const 1), `generatedAt` (date-time), `records` (array); record keys `id`, `manufacturer`, `manufacturerAliases`, `model`, `aliases`, `equipmentType`, `attributes` (object), `links` (`product`, `manual`, `support`, each a string), `firmwareId`, `sources` (array of `url`, `publisher` enum `manufacturer|libdivecomputer|thirdParty`, `checked` date, `fields` array). Required: `id`, `manufacturer`, `model`, `equipmentType`, `sources`.
- [ ] **Step 3:** Write `schema/sample.json`: three records (`example-perdix-2` computer with `connectivity: ble`, all three links, `firmwareId`, two sources; `example-puck-lite` computer with no links and one libdivecomputer source; `example-quad-light` light with no attributes) plus one record carrying an unknown key `futureField`. `generatedAt` `2026-11-27T00:00:00Z`.
- [ ] **Step 4:** `tests/test_sample.py::test_sample_hash_pinned` asserts the SHA-256 of `schema/sample.json` equals a constant; the same constant is pinned in the app (Task B1).
- [ ] **Step 5:** README: what the catalogue is, the format, how the app reads it, the sourcing rules (maker's own page first; a page whose terms forbid reuse is never used; values restated, never copied prose; every fact cites a source). AGENTS.md: the same rules plus "ids never change once published".
- [ ] **Step 6:** `python3.14 tests/run_tests.py` passes; commit `feat: format 1 contract and sample`.

### Task A2: Validator

**Files:**
- Create: `ecat/__init__.py`, `ecat/validate.py`, `ecat/schema_check.py` (copy the firmware catalogue's small schema interpreter), `ecat/normalise.py`
- Test: `tests/test_validate.py`, `tests/fixtures/bad/*.json`

**Interfaces:**
- Produces: `python3.14 -m ecat.validate [--firmware <path-or-url>]` exits 0 when `data/*.json` and `schema/sample.json` pass, 1 otherwise, printing one `FAIL <file> <record id>: <reason>` line per problem. `ecat.normalise.key(s: str) -> str` (lowercase, remove spaces and punctuation).

- [ ] **Step 1: Write failing tests**, one per check, each loading a fixture under `tests/fixtures/bad/` and asserting the reason text appears: `test_duplicate_id`, `test_two_records_same_match_key` (same normalised manufacturer or alias, same model or alias, same type), `test_non_https_link`, `test_record_without_source`, `test_unknown_attribute_key_for_type`, `test_choice_value_not_in_choices`, `test_number_attribute_given_text`, `test_manufacturer_source_loses_to_other_publisher_for_same_field`, `test_firmware_id_missing_from_firmware_catalogue` (firmware catalogue passed as a fixture path), `test_strict_mode_unknown_key_in_data` (data strict, sample lenient), plus `test_good_sample_passes`.
- [ ] **Step 2:** Run `python3.14 tests/run_tests.py`; expect the new tests to fail (module missing).
- [ ] **Step 3:** Implement `ecat/validate.py` with those checks; the attribute check reads `schema/attribute-keys.json`; the firmware check fetches `https://github.com/submersion-app/firmware-catalogue/releases/latest/download/firmware-catalogue.json` unless `--firmware` is given, and skips with a `WARN` line (not a failure) when offline.
- [ ] **Step 4:** Tests pass; commit `feat: validator`.

### Task A3: libdivecomputer seed

**Files:**
- Create: `ecat/seed_libdc.py`, `ecat/makers.py` (libdivecomputer vendor spelling to maker spelling and file slug, e.g. `Aqualung` to `Aqua Lung` / `aqua-lung`)
- Test: `tests/test_seed_libdc.py`, `tests/fixtures/descriptor_sample.c` (a cut of `src/descriptor.c` with 6 rows: a BLE row, a USB row, an IrDA row, a SERIAL-only row, a Bluetooth Classic row, and two rows with the same vendor/product but different model numbers)

**Interfaces:**
- Consumes: the fork's `src/descriptor.c` (`packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c` in the app checkout, or `--descriptor <path>`).
- Produces: `python3.14 -m ecat.seed_libdc --descriptor <path>` writes or refreshes records in `data/<maker>.json`. A record it writes has one source `{publisher: libdivecomputer, url: https://github.com/submersion-app/libdivecomputer, checked: <today>, fields: [manufacturer, model, equipmentType, attributes.connectivity]}`.

- [ ] **Step 1: Write failing tests:** `test_one_record_per_vendor_product` (the two same-name rows give one record), `test_connectivity_ble`, `test_connectivity_usb_for_usb_and_usbhid`, `test_connectivity_infrared`, `test_no_connectivity_for_serial_only_and_bluetooth_classic`, `test_id_slug_and_type_suffix_on_collision`, `test_existing_id_never_changes` (a record already in data keeps its id though the slug rule would now give another), `test_researched_fields_untouched` (a field covered by a `manufacturer` source keeps its value and source), `test_vendor_spelling_becomes_alias`.
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement. Parse `{"Vendor", "Product", DC_FAMILY_..., model, DC_TRANSPORT_A | DC_TRANSPORT_B, ...}` rows with a regular expression over the descriptor array.
- [ ] **Step 4:** Tests pass. Run the seed on the fork's real `descriptor.c`; run the validator; commit `feat: libdivecomputer seed` and `data: dive computers from libdivecomputer` separately.

### Task A4: Build, release and CI workflows

**Files:**
- Create: `ecat/build.py`, `.github/workflows/ci.yml`, `.github/workflows/release.yml`
- Test: `tests/test_build.py`

**Interfaces:**
- Produces: `python3.14 -m ecat.build --out build/equipment-catalogue.json` (records from every `data/*.json`, sorted by id, `format: 1`, `generatedAt` now). `release.yml` on push to `main` touching `data/**` publishes it as the asset of release `YYYY.MM.DD` (suffix `.2`, `.3` for a second release the same day) unless the records equal the latest release's. The app fetches `https://github.com/submersion-app/equipment-catalogue/releases/latest/download/equipment-catalogue.json`.

- [ ] **Step 1: Failing tests:** `test_build_merges_and_sorts`, `test_build_drops_nothing_valid`, `test_unchanged_records_detected` (the comparison helper used by the workflow ignores `generatedAt`).
- [ ] **Step 2:** Implement; tests pass.
- [ ] **Step 3:** `ci.yml`: on PR and push, run `tests/run_tests.py` and `python3.14 -m ecat.validate`. `release.yml`: build, compare with the latest release asset, `gh release create`.
- [ ] **Step 4:** Commit `feat: build and release workflows`; push branch; open PR `Equipment catalogue: format 1, validator, seed, release` with body `Refs submersion-app/submersion#5118`; merge when CI is green (maintainer approved creating the repository; ask before merging if CI needs a setting change).

### Task A5: Researched records for the firmware catalogue's models

**Files:**
- Modify: `data/<maker>.json` for Shearwater, Heinrichs Weikamp, Suunto, Garmin, Mares, Ratio, Divesoft, Halcyon

- [ ] **Step 1:** For each model in the firmware catalogue's latest release, read the maker's own product page, manual page and support page; record each URL under `links`, a `manufacturer` source with `checked` today and the `fields` it covers, and `firmwareId` = that model's firmware id. Types follow the maker (Divesoft Liberty `rebreather`; Ratio transmitter `transmitter`; Mares Horizon two records); Garmin Descents are new records with the maker as their only source. A page whose terms forbid reuse is not used.
- [ ] **Step 2:** Validator passes (`--firmware` against the live release); commit `data: manufacturer links for the firmware catalogue's models`; PR in the catalogue repository, merge, confirm the release asset appears.

---

## Part B: the app

### Task B1: Fixtures and the attribute-key contract

**Files:**
- Create: `tool/export_equipment_attribute_keys.dart`
- Create: `test/fixtures/equipment_catalogue/sample.json` (copy of the repository's), `test/fixtures/equipment_catalogue/attribute-keys.json`
- Test: `test/features/equipment/data/catalogue/equipment_catalogue_contract_test.dart`

**Interfaces:**
- Produces: `exportEquipmentAttributeKeys() -> Map<String, Map<String, Map<String, Object>>>` (type name to curated key to `{kind, choices}`), built from `EquipmentAttributeCatalog.attributesFor(type)` for every `EquipmentType`, excluding `AttributeGroup.system`, `purchase` and `appearance` keys (a catalogue never offers those).

- [ ] **Step 1: Failing tests:** `sample fixture matches the pinned hash` (same constant as Task A1 Step 4); `attribute key fixture matches the curated catalogue` (`exportEquipmentAttributeKeys()` deep-equals the decoded fixture; failure message says to run the tool and copy the file into the catalogue repository).
- [ ] **Step 2:** Implement the tool (`dart run tool/export_equipment_attribute_keys.dart > test/fixtures/equipment_catalogue/attribute-keys.json`); tests pass; copy the file into the catalogue repository's `schema/` (Task A1).
- [ ] **Step 3:** Commit `test(equipment): equipment catalogue contract fixtures`.

### Task B2: Record, parser and index (pure)

**Files:**
- Create: `lib/features/equipment/domain/catalogue/equipment_catalogue_record.dart`
- Create: `lib/features/equipment/domain/catalogue/equipment_catalogue.dart` (the index)
- Create: `lib/features/equipment/data/catalogue/equipment_catalogue_parser.dart`
- Test: `test/features/equipment/data/catalogue/equipment_catalogue_parser_test.dart`, `test/features/equipment/domain/catalogue/equipment_catalogue_test.dart`

**Interfaces:**
- Produces:
  - `const int kSupportedEquipmentCatalogueFormat = 1;`
  - `class EquipmentCatalogueSource { String url; CataloguePublisher publisher; DateTime? checked; Set<String> fields; }`, `enum CataloguePublisher { manufacturer, libdivecomputer, thirdParty }`
  - `class EquipmentCatalogueLinks { String? product, manual, support; bool get isEmpty; }`
  - `class EquipmentCatalogueRecord { String id; String manufacturer; List<String> manufacturerAliases; String model; List<String> aliases; EquipmentType type; Map<String, Object> attributes; EquipmentCatalogueLinks links; String? firmwareId; List<EquipmentCatalogueSource> sources; }` with `EquipmentAttribute? attributeFor(String key)` converting a value to the app's attribute (`valueText` for text and choice, `valueNum` for number)
  - `class EquipmentCatalogueFile { int format; DateTime generatedAt; List<EquipmentCatalogueRecord> records; }`
  - `EquipmentCatalogueFile? parseEquipmentCatalogue(String json)`: null for unparseable JSON or an unsupported `format`
  - `String catalogueNameKey(String s)`: lowercase, strip whitespace and punctuation (reuse `normalizeComputerIdentityPart` if it does exactly this)
  - `class EquipmentCatalogue { EquipmentCatalogue(EquipmentCatalogueFile file); static final empty; DateTime? get generatedAt; EquipmentCatalogueRecord? byId(String id); List<String> manufacturers(EquipmentType type); List<EquipmentCatalogueRecord> models(EquipmentType type, String brand); EquipmentCatalogueRecord? resolve(EquipmentType type, String? brand, String? model); }` where `resolve` returns a record only when exactly one matches by normalised name or alias

- [ ] **Step 1: Failing parser tests:** `parses the sample`; `returns null for format 2`; `returns null for broken JSON`; `skips a record missing manufacturer`; `skips a record with an unknown equipmentType`; `drops a non-https link and keeps the record`; `keeps the first of two records with one id`; `ignores unknown keys`; `drops attribute values whose key is not curated for the type`.
- [ ] **Step 2: Failing index tests:** `resolve by exact names`; `resolve by alias and by manufacturer alias, ignoring case and spaces` ("perdix2", "shearwater research"); `resolve ignores a record of another type` (a light "Quad" never resolves for a computer); `resolve returns null when two records match`; `models lists a brand's models for the type only`; `manufacturers lists main names once`.
- [ ] **Step 3:** Implement; tests pass; commit `feat(equipment): equipment catalogue record, parser and index`.

### Task B3: Delivery: bundled, cached, fetched

**Files:**
- Create: `assets/data/equipment_catalogue.json` (the first catalogue release's asset; until A4 has published one, the build output of `ecat.build`)
- Create: `lib/features/equipment/data/catalogue/equipment_catalogue_client.dart`
- Create: `lib/features/equipment/data/catalogue/equipment_catalogue_store.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_catalogue_providers.dart`
- Create: `.github/workflows/equipment-catalogue-release.yml`, `scripts/equipment_catalogue_intake.py` (modelled on `site-catalogue-release.yml` and `scripts/site_catalogue_intake.py`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (a `SettingsKeys.equipmentCatalogueUpdates` key)
- Test: `test/features/equipment/data/catalogue/equipment_catalogue_client_test.dart`, `.../equipment_catalogue_store_test.dart`, `test/features/equipment/presentation/providers/equipment_catalogue_providers_test.dart`

**Interfaces:**
- Produces:
  - `const String kEquipmentCatalogueUrl = 'https://github.com/submersion-app/equipment-catalogue/releases/latest/download/equipment-catalogue.json';`
  - `class EquipmentCatalogueClient { EquipmentCatalogueClient({http.Client? client, Uri? url, Duration timeout = const Duration(seconds: 30)}); Future<String?> fetch(); }`: body on 200 (UTF-8 decoded), null on 404, throws `EquipmentCatalogueFetchException` otherwise
  - `class EquipmentCatalogueStore { EquipmentCatalogueStore(Directory supportDir, SharedPreferences prefs); Future<String?> readCached(); Future<void> writeCached(String json, DateTime fetchedAt); DateTime? get lastFetchedAt; }` (file `equipment_catalogue.json` under `p.join(supportDir.path, 'equipment_catalogue')`)
  - `EquipmentCatalogueFile? chooseEquipmentCatalogue(EquipmentCatalogueFile? bundled, EquipmentCatalogueFile? cached)`: the one with the newer `generatedAt`, either when the other is null
  - `final equipmentCatalogueProvider = FutureProvider<EquipmentCatalogue>` (parses off the UI thread with `compute`; `EquipmentCatalogue.empty` on any failure)
  - `final equipmentCatalogueUpdatesEnabledProvider` (per-device bool, default true, `StateNotifier` seeded from prefs like `DisplayZoomNotifier`)
  - `Future<void> refreshEquipmentCatalogueIfDue(Ref ref, {DateTime? now})`: no-op on web, when disabled, or when `lastFetchedAt` is under 24 hours old; on a good parse with a supported format writes the cache and invalidates `equipmentCatalogueProvider`; any failure is logged only. Called at app start and on resume beside the other startup refreshes (find where the firmware or species pack refresh is wired in `lib/core/bootstrap/`; if none, the app lifecycle observer that drives resume work).

- [ ] **Step 1: Failing tests:** client `returns the body on 200`, `returns null on 404`, `throws on 500`, `throws on timeout`, `sends no query parameters`; store `round-trips a file and its fetch time`; `chooseEquipmentCatalogue` four cases; refresh `does nothing when disabled`, `does nothing within 24 hours`, `keeps the cache when the body is malformed`, `keeps the cache when the format is unsupported`, `writes the cache and invalidates on success`, `does nothing on web` (inject a `isWeb` flag parameter defaulting to `kIsWeb`).
- [ ] **Step 2:** Implement; add the asset under the existing `assets/data/` entry (no pubspec change needed); tests pass.
- [ ] **Step 3:** Intake workflow and script: weekly and by hand, finds a catalogue release newer than `assets/data/equipment_catalogue.version` (create it with the bundled release tag), opens a PR copying the asset, the version file and `schema/sample.json` into `test/fixtures/equipment_catalogue/`. Body says to close and reopen the PR to start CI, as the site intake's does.
- [ ] **Step 4:** Commit `feat(equipment): bundled and fetched equipment catalogue`.

### Task B4: Storage: columns, entity, link write, sync, UDDF

**Files:**
- Modify: `lib/core/database/tables/equipment_tables.dart` (two columns with doc comments, used by the SQL notes generator)
- Create: `lib/core/database/migrations/helpers/equipment_catalogue_migrations.dart` (`part of '../app_database_migrations.dart'`, `_assertEquipmentCatalogueColumns()`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part line), `ladder/rungs_v340_onward.dart` (`if (from < 388)` pair), `before_open_child_columns.dart` (backstop call), `lib/core/database/database.dart` (version 388 and its comment list entry)
- Create: `lib/features/equipment/domain/entities/equipment_catalogue_answers.dart`
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (`catalogueId`, `catalogueAnswers`, in `copyWith`, `props`), `equipment_repository_impl.dart` (row mapper reads both; `createEquipment` writes both; `updateEquipment` writes neither; new `Future<void> setCatalogueLink(String id, {required String? catalogueId, required EquipmentCatalogueAnswers? answers})` that writes both, bumps `updatedAt`, and marks the record pending)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/equipment_fields.dart` (`catalogueId`, `catalogueAnswers`, reusing the existing `settings_conflict_field_catalogueId` / `_catalogueAnswers` strings)
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`, `uddf_import_parsers.dart`, `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`catalogueid`, `catalogueanswers` on an equipment item, as sites do)
- Regenerate: `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v388_equipment_catalogue_test.dart`, `test/core/services/sync/equipment_catalogue_sync_test.dart`, `test/features/equipment/domain/entities/equipment_catalogue_answers_test.dart`, `test/features/equipment/data/repositories/equipment_catalogue_link_test.dart`, `test/core/services/export/uddf_equipment_catalogue_round_trip_test.dart`

**Interfaces:**
- Produces: `class EquipmentCatalogueAnswers { Set<String> notSame; Map<String, Set<String>> declined; Map<String, Object?> unknown; String encode(); static EquipmentCatalogueAnswers decode(String? json); EquipmentCatalogueAnswers withNotSame(String id); EquipmentCatalogueAnswers withDeclined(String id, Set<String> fields); bool get isEmpty; }` (shape of `SiteCatalogueAnswers`; `decode` of null or bad JSON gives empty). `EquipmentItem.catalogueId: String?`, `EquipmentItem.catalogueAnswers: EquipmentCatalogueAnswers` (default empty; stored as null when empty).

- [ ] **Step 1: Failing tests:** migration `adds both columns from v387 and keeps rows`, `backstop adds them when missing`; answers `round trip keeps unknown keys`, `decode of garbage is empty`; repository `createEquipment stores the link`, `updateEquipment leaves the link as stored` (update an item built without the link; the stored link survives), `setCatalogueLink writes both and marks pending`; sync (mirror `site_catalogue_answers_sync_test.dart` for `'equipment'`): written out, written out as none, incoming kept, device-to-device round trip; UDDF backup round trip keeps both.
- [ ] **Step 2:** Implement; `dart run build_runner build --delete-conflicting-outputs` in the background (never `--build-filter`); regenerate SQL notes; tests pass.
- [ ] **Step 3:** Commit `feat(equipment): store an item's equipment catalogue link and answers`.

### Task B5: The offer rule and edit fields (pure)

**Files:**
- Create: `lib/features/equipment/domain/catalogue/equipment_catalogue_offer.dart`
- Modify: `lib/features/equipment/presentation/editing/gear_item_edit_fields.dart` (`_with` carries `catalogueId`, `catalogueAnswers`; two new fields)
- Modify: `lib/features/equipment/data/services/gear_item_edit_save_service.dart` (`alsoWrite` calls `setCatalogueLink` when either changed; `create` passes them through `createEquipment`)
- Test: `test/features/equipment/domain/catalogue/equipment_catalogue_offer_test.dart`, `test/features/equipment/presentation/editing/gear_item_catalogue_fields_test.dart`, `test/features/equipment/data/services/gear_item_catalogue_save_test.dart`

**Interfaces:**
- Produces:
  - `enum CatalogueOfferFieldKind { brand, model, attribute }`
  - `class CatalogueOfferRow { CatalogueOfferFieldKind kind; String? attributeKey; String fieldName /* 'brand', 'model', or the attribute key: stored in answers, never renamed */; Object? itemValue; Object recordValue; bool startTicked /* true when itemValue is empty */; }`
  - `class CatalogueOffer { EquipmentCatalogueRecord record; bool addsLink; List<CatalogueOfferRow> rows; }`
  - `CatalogueOffer offerFor(EquipmentItem working, EquipmentCatalogueRecord record)`: rows for brand and model when the catalogue spelling differs from the item's (trimmed, case-sensitive), and for each record attribute: absent or empty on the item gives a ticked row, a different value gives an unticked row, an equal value gives none; an empty-field row whose field the item's answers decline for this record is left out
  - `bool showOfferLine(EquipmentItem working, CatalogueOffer offer)`: false when `record.id` is in `notSame`; for a linked item, true only when the link is this record and a ticked (empty-field) row remains; for an unlinked item, true
  - `String? catalogueIdAfterRename(EquipmentItem working, EquipmentCatalogue catalogue)`: the working link unless its record is in the catalogue and `catalogue.resolve(type, brand, model)?.id` is not it, then null
  - `gearCatalogueIdField` (`EditField<EquipmentItem, String?>`, id `catalogueId`, card `details`) and `gearCatalogueAnswersField` (`EditField<EquipmentItem, EquipmentCatalogueAnswers>`, id `catalogueAnswers`, card `details`)

- [ ] **Step 1: Failing tests:** offer `empty attribute is ticked`, `differing attribute is unticked`, `equal attribute has no row`, `declined empty field left out`, `brand spelling differs gives an unticked row`, `number attribute compares as stored value`; line `hidden for notSame`, `shown for unlinked even with no rows`, `linked to this record shows only with a ticked row`, `linked to another record never shows this offer` (the resolve already matched a different record); rename `keeps the link on an alias spelling`, `clears it for another model`, `keeps it when the record is absent from the catalogue`; fields `editing the name keeps the link and answers` (Review Focus 1: build via `gearNameField.write`, assert both kept); save `link change calls setCatalogueLink once`, `no link change makes no call`, `create stores the link`.
- [ ] **Step 2:** Implement; Save applies `catalogueIdAfterRename` to the merged item before writing (in the page's save path that calls `GearItemEditSaveService.save`; find it from `gear_item_sitting_host.dart`); tests pass.
- [ ] **Step 3:** Commit `feat(equipment): equipment catalogue offer rule and edit fields`.

### Task B6: Brand and model suggestions

**Files:**
- Create: `lib/features/equipment/presentation/widgets/catalogue_name_field.dart`
- Modify: `lib/features/equipment/presentation/editing/gear_item_details_editor.dart` (the two `TextField`s at the brand/model `Row` become `CatalogueNameField`s; keys `gear-edit-brand` and `gear-edit-model` stay)
- Test: `test/features/equipment/presentation/widgets/catalogue_name_field_test.dart`

**Interfaces:**
- Produces: `class CatalogueNameField extends ConsumerWidget { CatalogueNameField({Key? key, required TextEditingController controller, required String label, required IconData icon, required List<String> Function(String typed) suggestionsFor}); }` using `RawAutocomplete` with at most 8 options, wrapping text; `List<String> brandSuggestions(EquipmentCatalogue c, EquipmentType type, Iterable<String> diverBrands, String typed)` (diver's own brands first, then catalogue manufacturers, prefix then contains matches, case-insensitive, de-duplicated by `catalogueNameKey`) and `List<String> modelSuggestions(EquipmentCatalogue c, EquipmentType type, String brand, String typed)` (empty when brand is blank). The diver's brands come from the existing equipment list provider (distinct non-empty `brand` values).

- [ ] **Step 1: Failing tests:** `brandSuggestions puts the diver's brands first`; `modelSuggestions is empty with no brand`; `modelSuggestions only lists the item type`; widget `picking a suggestion sets exactly the catalogue spelling`; `typing free text is kept`; `at 360 px a long model name wraps without overflow` (Review Focus 5); `no suggestions while the catalogue is loading`.
- [ ] **Step 2:** Implement; tests pass; commit `feat(equipment): suggest brand and model from the equipment catalogue`.

### Task B7: Offer line and review sheet

**Files:**
- Create: `lib/features/equipment/presentation/widgets/gear_catalogue_offer_line.dart`
- Create: `lib/features/equipment/presentation/widgets/gear_catalogue_review_sheet.dart`
- Create: `lib/features/equipment/presentation/editing/gear_item_catalogue_sitting.dart`
- Modify: `gear_item_details_editor.dart` (one line under the brand/model row)
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/widgets/gear_catalogue_offer_line_test.dart`, `.../gear_catalogue_review_sheet_test.dart`, `test/features/equipment/presentation/editing/gear_item_catalogue_sitting_test.dart`

**Interfaces:**
- Consumes: `offerFor`, `showOfferLine` (B5), `equipmentCatalogueProvider` (B3), the session's `valueOf` / `set`.
- Produces:
  - `sealed class GearCatalogueReviewResult`; `GearCatalogueApply(Set<String> tickedFieldNames)`, `GearCatalogueNotThisModel()`; null when dismissed
  - `Future<GearCatalogueReviewResult?> showGearCatalogueReview(BuildContext context, CatalogueOffer offer)`: bottom sheet under 600 px width, dialog above
  - `void holdGearCatalogueReview(EditSession<EquipmentItem> session, CatalogueOffer offer, GearCatalogueReviewResult result)`: Apply sets each ticked row into the session (brand/model through `gearBrandField`/`gearModelField` and the editor's text controllers; attributes through `gearAttributeField(key)` with `record.attributeFor(key)`); a ticked empty-field row is set only if that field is still empty in the session now; a ticked differing row is set; sets `gearCatalogueIdField` to the record id; adds empty-field rows left unticked to `declined` through `gearCatalogueAnswersField`. Not this model: adds the id to `notSame` only.
- Strings (English; translate for the other 10): `equipment_catalogue_offerLine` "Built-in equipment catalogue has details for this model"; `equipment_catalogue_review` "Review"; `equipment_catalogue_sheetSource` "From {publisher}, checked {date}"; `equipment_catalogue_publisher_manufacturer` "the manufacturer"; `equipment_catalogue_publisher_libdivecomputer` "libdivecomputer"; `equipment_catalogue_publisher_thirdParty` "a third party"; `equipment_catalogue_col_field` "Field"; `equipment_catalogue_col_yours` "Yours"; `equipment_catalogue_col_catalogue` "Catalogue"; `equipment_catalogue_none` "None"; `equipment_catalogue_linksNote` "Manufacturer links show on the gear page once linked."; `equipment_catalogue_notThisModel` "Not this model"; `equipment_catalogue_apply` "{count, plural, =0{Link only} =1{Apply 1} other{Apply {count}}}"; `equipment_catalogue_linkOnly` used when no rows exist.

- [ ] **Step 1: Failing tests:** line `shows when the typed name resolves`, `hidden for another type`, `hidden after Not this model`, `hidden while loading`; sheet `empty rows start ticked, differing start unticked`, `Apply count follows ticks`, `values formatted in the diver's units` (a number attribute through `formatAttributeValue`), `phone width is a bottom sheet, desktop a dialog`; sitting `Apply holds values until Save and Cancel discards them`, `a value typed after opening the sheet is not overwritten by an empty-field row` (Review Focus 2), `a ticked differing row replaces`, `unticked empty rows become declined`, `Not this model records notSame and no link`.
- [ ] **Step 2:** Implement; `flutter gen-l10n`; tests pass; commit `feat(equipment): review equipment catalogue details before saving`.

### Task B8: "From the manufacturer" card

**Files:**
- Create: `lib/features/equipment/presentation/widgets/gear_manufacturer_card.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (place after the details card; if #5096 is on main, register it as one of that PR's cards instead)
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/widgets/gear_manufacturer_card_test.dart`

**Interfaces:**
- Produces: `class GearManufacturerCard extends ConsumerWidget { GearManufacturerCard({required EquipmentItem item}); }`; Unlink saves through `GearItemEditSaveService.save` with `apply: (e) => e.copyWith(catalogueId: null)` (add a clear-capable path if `copyWith` cannot null it) and `changedCardIds: {GearItemCardId.details.name}`.
- Strings: `equipment_manufacturer_title` "From the manufacturer"; `equipment_manufacturer_product` "Product page"; `equipment_manufacturer_manual` "Manual"; `equipment_manufacturer_support` "Support"; `equipment_manufacturer_unlink` "Unlink from catalogue".

- [ ] **Step 1: Failing tests:** `shows a row per link present`; `hidden when unlinked`; `hidden when the record has no links`; `hidden when the record is absent`; `a row opens through parseWebLink` (inject the launcher); `Unlink clears the link and keeps the values`; `Unlink lives in the card menu, not ListTile.trailing`.
- [ ] **Step 2:** Implement; tests pass; commit `feat(equipment): show manufacturer links for a linked item`.

### Task B9: Setting, credits and user docs

**Files:**
- Modify: the settings page that holds network-backed downloads (`lib/features/settings/presentation/pages/network_settings_page.dart` unless the firmware switch has landed elsewhere; then beside it)
- Create: `lib/features/equipment/data/catalogue/equipment_catalogue_attribution.dart` (`registerLicense()`, the shape of `SiteCatalogueAttribution`), registered in `lib/core/bootstrap/bootstrap_shared.dart`
- Modify: `docs/user/equipment.md` (a section on the catalogue: suggestions, review, link, card, setting)
- Modify: all 11 ARB files
- Test: `test/features/settings/presentation/pages/equipment_catalogue_setting_test.dart`, `test/features/equipment/data/catalogue/equipment_catalogue_attribution_test.dart`

- [ ] **Step 1: Failing tests:** `switch defaults on and persists per device`; `switch hidden on web` (inject `isWeb`); `licence registered with the repository name and libdivecomputer credit`.
- [ ] **Step 2:** Implement. Strings: `settings_equipmentCatalogue_title` "Download equipment catalogue updates"; `settings_equipmentCatalogue_subtitle` "Checks GitHub at most once a day. Nothing about you or your gear is sent."
- [ ] **Step 3:** Tests pass; commit `feat(settings): switch for equipment catalogue downloads`.

### Task B10: Screenshots, checks and PR

- [ ] **Step 1 (before Task B6):** Before shots by throwaway golden (memory: real Roboto and MaterialIcons fonts loaded in `setUpAll`): the gear editor details card for a new Dive computer item at 400 px and 1280 px, and the gear page of a dive computer, light and dark. Save to the scratchpad as `NN-<screen>-before[-dark][-phone].png`; delete the throwaway test.
- [ ] **Step 2 (after Task B9):** After shots of the same screens, plus suggestions open, the offer line, the review sheet (phone and desktop), the card, and the setting.
- [ ] **Step 3:** `dart format .`, `flutter analyze` (whole repo), the test files this plan created or changed, by path.
- [ ] **Step 4:** Push; open the PR from the template with `Closes #5118`, spec and plan links, screenshots through the project's current secret gist (`pngquant` first), Follow-ups list; `tracker.py pr`; bind; two review rounds; Copilot; Auto-fix.
