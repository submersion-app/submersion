# Firmware Tracking and Update Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record the firmware version of electronic gear, keep a history of firmware updates, and tell the diver when the curated firmware catalogue lists a newer release.

**Architecture:** A new `lib/features/firmware/` feature holds the catalogue model, the pure matcher, the fetch client with its file cache, the recorder that writes history, and the providers and widgets for the notices. Equipment gains two curated attributes in a new `AttributeGroup.firmware`, and service records gain a `firmwareUpdate` category and a `firmware_version` column (schema v388). Dive computer downloads feed the recorder; the dashboard, the equipment list, the item page and a system notification read one status provider.

**Tech Stack:** Flutter, Riverpod (project wrapper `core/providers/provider.dart`), Drift, `package:http`, SharedPreferences, flutter_local_notifications through `NotificationService`.

**Spec:** `docs/design/specs/2026-11-27-firmware-tracking-design.md` (issue #5104). Shared format sample: `test/fixtures/firmware_catalogue/sample.json`.

## Global Constraints

- Catalogue URL default: `https://github.com/submersion-app/firmware-catalogue/releases/latest/download/firmware-catalogue.json`, overridable with `--dart-define=FIRMWARE_CATALOGUE_URL=...`.
- Known catalogue `format`: `1`. Any other value: ignored, last good copy kept.
- Fetch at most once per 24 hours, at launch and on resume, only while "Check for firmware updates" is on. No query parameters, no diver data.
- Firmware-capable types: computer, transmitter, rebreather, dpv, light, camera, housing, strobe.
- Attribute keys: `firmware_version` (text), `firmware_page_url` (url).
- New `ServiceCategory.firmwareUpdate`; new nullable `service_records.firmware_version`; schema 387 to 388, floor unchanged.
- An update is claimed only when the installed version is found in the model's release list below a newer release. Release order, never version parsing, decides newer.
- Device-local switches (SharedPreferences): `firmware_checks_enabled` (default true), `firmware_notifications_enabled` (default true). Notified pairs: `firmware_notified_pairs`, string list of `<itemId>|<version>`.
- Checks and notices cover the active diver's fitted items only.
- New strings in all 12 locales (`lib/l10n/arb/app_*.arb`), regenerated with `flutter gen-l10n`.
- No em-dash anywhere; no emojis; files under 800 lines (new code goes in new files; `settings_page.dart`, `equipment_list_content.dart` and `app.dart` get one call each).
- Local test runs: only the test files a task writes or changes, by path. Never a folder.

## Review Focus

1. A catalogue that is malformed, an unknown format, or a 404 (no release yet) keeps the last good copy and shows nothing new. Task 7 pins all three.
2. Brand and model typed differently from the catalogue ("shearwater research", "perdix2") still match, and an item of the wrong type with the same model name ("Perdix 2" as a light) does not. Task 2 pins both.
3. A diver-typed "V95" and a device-reported "95" for one release log nothing and keep "V95". Task 5 pins it.
4. A firmware record never moves the item's last service date or any service clock. Task 4 pins the date; clocks key on service kind, and firmware records carry none (Task 5 asserts `serviceKindId == null`).
5. A notified update is not notified again after a restart, and a later release is. Task 12 pins both, plus the switch being off.

---

### Task 1: Catalogue model and parser

**Files:**
- Create: `lib/features/firmware/domain/firmware_catalogue.dart`
- Test: `test/features/firmware/domain/firmware_catalogue_test.dart`

**Interfaces:**
- Produces:
  - `class FirmwareRelease { String version; List<String> reportedAs; DateTime? date; String? notesUrl; String? instructionsUrl; String? summary; bool safety; }`
  - `class FirmwareModel { String id; String manufacturer; List<String> manufacturerAliases; String model; List<String> aliases; Set<EquipmentType> equipmentTypes; String? firmwarePageUrl; List<FirmwareRelease> releases; }` (releases newest first, as given)
  - `class FirmwareCatalogue { int format; DateTime? generatedAt; List<FirmwareModel> models; static const int knownFormat = 1; static FirmwareCatalogue? parse(String json); }`
  - All Equatable, immutable.

- [ ] **Step 1: Write the failing tests**
  - `parses the shared sample`: reads `test/fixtures/firmware_catalogue/sample.json` (in `setUpAll`), expects 2 models; `example-perdix-2` has `manufacturerAliases == ['Shearwater Research']`, releases `['V95','V94','V92']` in that order, `releases.first.safety == true`, `releases.first.reportedAs == ['95']`, `date == DateTime.utc(2026,10,1)`; `example-dpv` has `equipmentTypes == {EquipmentType.dpv}` and an empty `manufacturerAliases`.
  - `ignores unknown keys`: the sample's `futureField` does not break parsing.
  - `unknown format returns null`: `{"format":2,"models":[]}` gives null.
  - `malformed returns null`: `'not json'`, `'[]'`, a model without `releases`, a release without `version` all give null (the whole file is rejected, never half-read).
  - `unknown equipment type names are dropped`: `"equipmentTypes":["computer","jetpack"]` gives `{computer}`; a model left with no known type is skipped.
  - `non-https links are dropped`: a `notesUrl` of `javascript:alert(1)` parses as null (reuse `parseWebLink` from `equipment_attribute_catalog.dart` for the check).
- [ ] **Step 2: Run** `flutter test test/features/firmware/domain/firmware_catalogue_test.dart`; expect compile failure.
- [ ] **Step 3: Implement** `FirmwareCatalogue.parse` with `jsonDecode` inside try/catch; any type mismatch on a required field returns null.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): firmware catalogue model and parser`

### Task 2: Matching and status

**Files:**
- Create: `lib/features/firmware/domain/firmware_status.dart`
- Test: `test/features/firmware/domain/firmware_status_test.dart`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `String normalizeFirmwareName(String s)`: lowercase, remove everything but letters and digits.
  - `FirmwareModel? matchFirmwareModel(FirmwareCatalogue catalogue, {required EquipmentType type, required String? brand, required String? model})`
  - `int? releaseIndexOf(FirmwareModel model, String version)`: index in `releases` where `version` equals `release.version` or any `reportedAs`, trimmed and case-insensitive; null when absent.
  - `bool sameFirmwareRelease(String a, String b, {FirmwareModel? model})`: equal trimmed case-insensitive, or both found at the same index of `model`.
  - `sealed class FirmwareStatus` with `FirmwareUpToDate(FirmwareModel model)`, `FirmwareUpdateAvailable(FirmwareModel model, List<FirmwareRelease> newer)` (newest first), `FirmwareUnknownVersion(FirmwareModel model)`, `FirmwareNoVersion(FirmwareModel model)`, `FirmwareNotListed()`. `FirmwareRelease get latest` on the model-bearing ones (`model.releases.first`).
  - `FirmwareStatus firmwareStatusFor({required FirmwareCatalogue? catalogue, required EquipmentType type, required String? brand, required String? model, required String? installedVersion})`. Null catalogue gives `FirmwareNotListed`.

- [ ] **Step 1: Write the failing tests** (catalogue = parsed sample)
  - `matches across spelling`: brand `'shearwater research'`, model `'perdix2'`, type computer gives `example-perdix-2`; brand `'Shearwater'`, model `'Perdix 2'` too.
  - `type narrows the match`: same brand and model with type light gives null.
  - `brand must match`: brand `'Suunto'`, model `'Perdix 2'` gives null; brand null gives null.
  - status cases on the Perdix: installed `'V95'` gives `FirmwareUpToDate`; `'92'` gives `FirmwareUpdateAvailable` with `newer` versions `['V95','V94']`; `'V90'` gives `FirmwareUnknownVersion` with `latest.version == 'V95'`; null or `'  '` gives `FirmwareNoVersion`; unmatched item gives `FirmwareNotListed`.
  - `sameFirmwareRelease('V95','95', model: perdix)` true; `('v95','V95')` true without a model; `('V95','V94', model: perdix)` false; `('V95','95')` without a model false.
- [ ] **Step 2: Run** the test; expect failure.
- [ ] **Step 3: Implement** the functions; a release list with duplicate spellings takes the first index.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): match gear to the catalogue and compare versions`

### Task 3: Firmware attributes on equipment

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (keys, new `AttributeGroup.firmware`, `firmware` list, type set, `attributesFor`, `_byKey`, `hasFirmware`)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (getters)
- Modify: `lib/features/equipment/presentation/editing/gear_item_details_editor.dart` (render the group under the serial field)
- Modify: every exhaustive `switch` over `AttributeGroup` that `flutter analyze` reports
- Modify: `lib/l10n/arb/app_*.arb` (`attrLabel_firmware_version`, `attrLabel_firmware_page_url`)
- Test: `test/features/equipment/domain/constants/firmware_attributes_test.dart`

**Interfaces:**
- Produces: `EquipmentAttrKeys.firmwareVersion = 'firmware_version'`, `EquipmentAttrKeys.firmwarePageUrl = 'firmware_page_url'`, `AttributeGroup.firmware`, `EquipmentAttributeCatalog.hasFirmware(EquipmentType) -> bool`, `EquipmentItem.firmwareVersion -> String?`, `EquipmentItem.firmwarePageUrl -> String?`.

- [ ] **Step 1: Write the failing tests**
  - `hasFirmware` is true for exactly the eight constraint types and false for regulator, other, battery.
  - `attributesFor(EquipmentType.dpv)` contains both keys with `group == AttributeGroup.firmware`, kinds text and url; `attributesFor(EquipmentType.fins)` contains neither.
  - `EquipmentItem` with curated `firmware_version` `'V92'` reads `firmwareVersion == 'V92'`; a custom attribute named `firmware_version` reads null.
  - The detail page's spec rows never include the firmware group (assert `attributesFor(t).where((d) => d.group == AttributeGroup.spec)` has no firmware key, for every type).
- [ ] **Step 2: Run** the test; expect failure.
- [ ] **Step 3: Implement.** Add `attributeSection(AttributeGroup.firmware)` after the serial `TextField` in the Details editor, shown only when `hasFirmware(type)`. Labels: English "Firmware version" and "Firmware page"; translate for the other 11 locales. Run `flutter gen-l10n`.
- [ ] **Step 4: Run** the test and `flutter analyze`; expect PASS and no issues.
- [ ] **Step 5: Commit** `feat(equipment): firmware version and firmware page attributes`

### Task 4: Firmware update category and column (schema v388)

**Files:**
- Modify: `lib/core/constants/app_enums.dart` (`firmwareUpdate('Firmware Update')`, placed after `calibration`)
- Modify: `lib/features/equipment/presentation/utils/service_category_label.dart` and the arb files (`equipment_serviceCategory_firmwareUpdate`: "Firmware update")
- Modify: `lib/core/database/tables/service_tables.dart` (`TextColumn get firmwareVersion => text().nullable()();` with a doc comment, v388)
- Create: `lib/core/database/migrations/helpers/firmware_record_migrations.dart` (`_assertFirmwareRecordColumn`, `_addColumnIfMissing('service_records','firmware_version','TEXT')`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part), `ladder/rungs_v340_onward.dart` (`if (from < 388)` assert plus `reportProgress`), the beforeOpen file that backstops equipment child-table columns (`before_open_child_columns.dart`), `lib/core/database/database.dart` (`currentSchemaVersion = 388`, list entry `388` with a comment: additive, floor does not move)
- Modify: `lib/features/equipment/domain/entities/service_record.dart` (`final String? firmwareVersion;`, constructor, `copyWith` that can clear it, props)
- Modify: `lib/features/equipment/data/repositories/service_record_repository.dart` (write and read the column; `_refreshEquipmentLastServiceDate` ignores `firmwareUpdate` records)
- Modify: `lib/features/agent_access/data/writes/families/service_record_writes.dart` (`'firmware_version': FieldCodec.text(maxLength: 60, nullable: true, trim: true)`, mapped both ways)
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` with `dart run tool/generate_sql_column_notes.dart`
- Regenerate: Drift code with `dart run build_runner build --delete-conflicting-outputs` (background, unfiltered)
- Test: `test/features/equipment/data/repositories/service_record_firmware_test.dart`

**Interfaces:**
- Produces: `ServiceCategory.firmwareUpdate`, `ServiceRecord.firmwareVersion`, `ServiceRecordRepository` round-trips it.

- [ ] **Step 1: Write the failing tests** (use `setUpTestDatabase` / `tearDownTestDatabase` from `test/helpers/test_database.dart`, as `service_record_last_service_date_test.dart` does)
  - `round-trips firmware_version`: create a `firmwareUpdate` record with `firmwareVersion: 'V95'`, read it back equal; update it to `'V96'`, read back.
  - `firmware records leave the last service date alone`: annual record 2026-03-01, then firmware record 2026-10-01; item `lastServiceDate` stays 2026-03-01.
  - `an unknown category still reads as other`: insert a row with `service_category = 'futureThing'` via `customStatement`, read gives `ServiceCategory.other` (pins the older-device fallback the spec relies on).
- [ ] **Step 2: Run** the test; expect failure.
- [ ] **Step 3: Implement** the list above. The migration test files that assert the schema version or the rung list (find them with `grep -rln "currentSchemaVersion\|387" test/core/database`) are updated to 388; run only those files.
- [ ] **Step 4: Run** the new test and the updated migration tests; expect PASS. `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(equipment): firmware update service category and version column`

### Task 5: Firmware update recorder

**Files:**
- Create: `lib/features/firmware/data/firmware_update_recorder.dart`
- Create: `lib/features/firmware/presentation/providers/firmware_recorder_provider.dart`
- Test: `test/features/firmware/data/firmware_update_recorder_test.dart`

**Interfaces:**
- Consumes: Tasks 2 to 4; `EquipmentRepository.getEquipmentById`, `EquipmentRepository.saveAttributes`, `ServiceRecordRepository.createRecord`.
- Produces:
  - `enum FirmwareReportOutcome { recordedFirst, unchanged, logged }`
  - `class FirmwareUpdateRecorder { Future<void> logUpdate({required String equipmentId, required String version, required DateTime date, String notes = ''}); Future<FirmwareReportOutcome> recordReported({required String equipmentId, required String reportedVersion, required DateTime at, FirmwareCatalogue? catalogue}); }`
  - `final firmwareUpdateRecorderProvider = Provider<FirmwareUpdateRecorder>`
  - `String firmwareHistoryLabel(AppLocalizations l10n, ServiceRecord r, {FirmwareModel? model, String? previous})`: "Firmware updated to V95", or "Firmware changed to V94" when `model` ranks the new version below `previous`.

- [ ] **Step 1: Write the failing tests** (test database; a DPV item and a computer item)
  - `logUpdate writes the record and the attribute`: one `firmwareUpdate` record, `firmwareVersion 'V95'`, `serviceKindId == null`, date as given; item `firmwareVersion == 'V95'`; other attributes unchanged.
  - `first report sets the version without history`: item with no version, `recordReported('95')` returns `recordedFirst`, attribute `'95'`, zero records.
  - `same release in another spelling logs nothing and keeps the spelling`: item `'V95'`, report `'95'` with the sample catalogue returns `unchanged`, attribute still `'V95'`, zero records.
  - `a new version logs one entry`: item `'V92'`, report `'95'` returns `logged`, attribute `'95'`, one record `firmwareVersion '95'`, `serviceDate == at`.
  - `same text in other case logs nothing` without a catalogue (`'v95'` vs `'V95'`).
  - `label`: older version under the sample model gives the "changed" wording; newer or unrankable gives "updated".
- [ ] **Step 2: Run** the test; expect failure.
- [ ] **Step 3: Implement.** `logUpdate` and the `logged` path run inside `DatabaseService.instance.database.transaction`. Strings `firmware_history_updatedTo` ("Firmware updated to {version}") and `firmware_history_changedTo` ("Firmware changed to {version}") in all locales.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): record firmware updates in service history`

### Task 6: Downloads feed the recorder

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart` (`_persistDeviceInfo`: after `updateComputer`, when `firmwareVersion != null && updated.equipmentId != null`, call `recordReported` through the provider with the cached catalogue; failures logged, never thrown; one call, logic stays in the recorder)
- Test: `test/features/dive_computer/presentation/providers/download_notifier_firmware_test.dart` (copy the harness of `download_notifier_address_rebind_test.dart`)

- [ ] **Step 1: Write the failing tests** with a fake `FirmwareUpdateRecorder` overriding `firmwareUpdateRecorderProvider`:
  - a completed download reporting `'95'` for a computer whose registration has `equipmentId 'eq1'` calls `recordReported(equipmentId: 'eq1', reportedVersion: '95', ...)` once;
  - a report of `''` or null makes no call; a registration without `equipmentId` makes no call;
  - the serial-mismatch early return (existing rule) makes no call;
  - a recorder that throws leaves the download completed and the registration updated.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): log firmware changes reported by a download`

### Task 7: Fetch client, cache and refresh

**Files:**
- Create: `lib/features/firmware/data/firmware_catalogue_client.dart`
- Create: `lib/features/firmware/data/firmware_catalogue_store.dart`
- Create: `lib/features/firmware/presentation/providers/firmware_catalogue_providers.dart`
- Create: `lib/features/firmware/presentation/providers/firmware_settings_providers.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.firmwareChecksEnabled`, `firmwareNotificationsEnabled`, `firmwareNotifiedPairs`)
- Modify: `lib/app.dart` (one `_refreshFirmwareCatalogue()` call in the launch post-frame block and one in the `resumed` branch; unawaited)
- Test: `test/features/firmware/data/firmware_catalogue_client_test.dart`, `test/features/firmware/data/firmware_catalogue_store_test.dart`, `test/features/firmware/presentation/providers/firmware_catalogue_providers_test.dart`

**Interfaces:**
- Produces:
  - `const String kFirmwareCatalogueUrl` (String.fromEnvironment, default above).
  - `sealed class FirmwareFetchResult`: `FirmwareFetched(FirmwareCatalogue catalogue, String raw)`, `FirmwareNotPublished()` (404), `FirmwareFetchFailed(String reason)`.
  - `class FirmwareCatalogueClient { FirmwareCatalogueClient({http.Client? client, Uri? url, Duration timeout = const Duration(seconds: 20)}); Future<FirmwareFetchResult> fetch(); }`
  - `class FirmwareCatalogueStore { FirmwareCatalogueStore(Directory dir); Future<FirmwareCatalogue?> load(); Future<void> save(String raw, DateTime fetchedAt); Future<DateTime?> lastFetchedAt(); }` (files `firmware_catalogue.json` and `firmware_catalogue.fetched` under the app support directory's `firmware/` folder, joined with `p.join`)
  - `firmwareChecksEnabledProvider` and `firmwareNotificationsEnabledProvider`: `StateNotifierProvider<..., bool>`, default true, the `DraftReminderSettingNotifier` pattern.
  - `firmwareCatalogueProvider`: `AsyncNotifierProvider<FirmwareCatalogueNotifier, FirmwareCatalogue?>`, `build()` loads the store; `Future<void> refreshIfDue({DateTime? now})` fetches when checks are on and the last fetch is null or 24 hours old or more, saves on `FirmwareFetched`, updates state; returns quietly otherwise.
  - With checks off the provider's state is null (no notices anywhere).

- [ ] **Step 1: Write the failing tests** (`MockClient` from `package:http/testing.dart`; a temp dir from `Directory.systemTemp.createTemp`, deleted in `addTearDown`)
  - client: 200 with the sample gives `FirmwareFetched`; 404 gives `FirmwareNotPublished`; 500, timeout, `'not json'`, format 2 give `FirmwareFetchFailed`; the request URI has no query string.
  - store: save then load round-trips; load with no file gives null; a corrupt file on disk loads as null.
  - provider: no fetch within 24 hours of the last one; a fetch after 24 hours; a failed or 404 fetch keeps the stored catalogue as state; checks off makes no request and state null; turning checks on again reloads the stored copy.
- [ ] **Step 2: Run** the three files; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): fetch and cache the firmware catalogue daily`

### Task 8: Status providers

**Files:**
- Create: `lib/features/firmware/presentation/providers/firmware_status_providers.dart`
- Test: `test/features/firmware/presentation/providers/firmware_status_providers_test.dart`

**Interfaces:**
- Consumes: `allEquipmentProvider`, `allDiveComputersProvider`, `firmwareCatalogueProvider`, Task 2.
- Produces:
  - `String? installedFirmwareOf(EquipmentItem item, List<DiveComputer> registrations)`: the item's attribute, else the newest-downloaded registration's `firmwareVersion` (read-through; nothing stored).
  - `final firmwareStatusesProvider = FutureProvider<Map<String, FirmwareStatus>>`: every fitted item (`isFitted`) of a firmware-capable type; brand and model fall back to the newest registration's manufacturer and model when the item has none.
  - `final firmwareStatusProvider = Provider.family<FirmwareStatus?, String>` (select from the map; null while loading).
  - `typedef FirmwareUpdateEntry = ({EquipmentItem item, FirmwareUpdateAvailable status});`
  - `final firmwareUpdatesProvider = FutureProvider<List<FirmwareUpdateEntry>>`: the `FirmwareUpdateAvailable` ones, safety first, then by item name.

- [ ] **Step 1: Write the failing tests** (provider overrides with fixed lists and the sample catalogue):
  - an item without a version but with a registration reporting `'92'` reads `FirmwareUpdateAvailable` (read-through);
  - a retired item is absent; a fins item is absent;
  - a gear twin with no brand of its own matches through its registration's manufacturer;
  - `firmwareUpdatesProvider` orders a safety update before a non-safety one;
  - a null catalogue gives every item `FirmwareNotListed` and an empty update list.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): firmware status for the active diver's gear`

### Task 9: Firmware card and Log firmware update sheet

**Files:**
- Create: `lib/features/firmware/presentation/widgets/firmware_card.dart`
- Create: `lib/features/firmware/presentation/widgets/log_firmware_update_sheet.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (card after the Dive computer section, only when `hasFirmware(type)`)
- Modify: arb files
- Test: `test/features/firmware/presentation/widgets/firmware_card_test.dart`, `test/features/firmware/presentation/widgets/log_firmware_update_sheet_test.dart`

**Interfaces:**
- Produces: `FirmwareCard({required EquipmentItem item})`, `Future<void> showLogFirmwareUpdateSheet(BuildContext context, {required EquipmentItem item, String? suggestedVersion})`.

Card content by status: installed version row ("Not recorded" when none); `UpdateAvailable`: headline "Update available: {latest}", up to 3 newer releases (version, date in the diver's date format, summary, a "Safety" chip when `safety`), "Show all {n}" when more, links "Release notes", "How to update", "Firmware page" (model's, else the item's `firmware_page_url`) opened through `parseWebLink` and the app's link launcher; `UpToDate`: "Up to date"; `UnknownVersion`: "Not in the firmware list. Latest: {version}"; `NoVersion`: "Latest: {version}. Record yours to compare."; `NotListed`: version and the item's own page link only. Always a "Log firmware update" button. With checks off: version, page link and the button only.

Sheet: version field (prefilled with `suggestedVersion`, required, trimmed, max 60), date (today, date picker), notes; Save calls `logUpdate`.

- [ ] **Step 1: Write the failing widget tests** (pump with provider overrides, English locale pinned)
  - each of the five statuses shows its text; the Safety chip shows only for `safety`; 5 newer releases show 3 and "Show all 5";
  - a long model and version (60 chars) at 360 px width lays out without overflow;
  - the sheet refuses an empty version with an inline error and saves `'V95'` through a fake recorder.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): firmware card and log firmware update`

### Task 10: List badge and history row

**Files:**
- Create: `lib/features/firmware/presentation/widgets/firmware_update_badge.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile` second line: finding, then clock, then firmware badge, then status, then place)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` (same order)
- Modify: `lib/features/equipment/presentation/widgets/service_history_section.dart` (a `firmwareUpdate` record's title is `firmwareHistoryLabel`)
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart` (a required version field while the category is `firmwareUpdate`; saving a firmware record whose date is the newest firmware record's sets the item's attribute)
- Test: `test/features/firmware/presentation/widgets/firmware_update_badge_test.dart`, plus the existing tests of the two tiles, the history section and the dialog extended with one case each

- [ ] **Step 1: Write the failing tests**: tile with an update shows the badge text "Update"; a tile with an overdue clock shows the clock, not the badge; history row reads "Firmware updated to V95"; dialog shows the version field only for the firmware category and blocks Save without it.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(equipment): firmware update badge and history entries`

### Task 11: Dashboard rows

**Files:**
- Create: `lib/features/firmware/presentation/widgets/home_firmware_rows.dart`
- Modify: `lib/features/dashboard/presentation/panels/gear_service_panel.dart`
- Test: `test/features/dashboard/presentation/panels/gear_service_panel_firmware_test.dart`

Rows after the service bars, sharing the panel's cap (`max`, 3 on phone, 5 wider): bars first, firmware rows fill what is left, then "{n} more firmware updates" when any are cut. A row: item name, "Firmware {version}" on the right, chip icon `Icons.system_update_alt`. Tapping a row opens `/equipment/<id>`. With no bars and no gear the empty text is unchanged; with no bars but updates, the rows show instead of the empty text.

- [ ] **Step 1: Write the failing tests**: phone width with 2 bars and 3 updates shows 2 bars, 1 row and "2 more firmware updates"; no bars plus 1 update shows the row and not the empty text; no updates leaves the panel exactly as before (same widget count as a pump without the firmware provider).
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dashboard): firmware updates in the gear service panel`

### Task 12: System notification

**Files:**
- Modify: `lib/core/services/notification_service.dart` (`Future<void> showFirmwareUpdate({required String equipmentId, required String title, required String body})`, mobile only, channel `firmware_updates` "Firmware Updates", id `_stableNotificationId('firmware:$equipmentId')`, payload the equipment id, which `notificationPayloadRoute` already opens)
- Create: `lib/features/firmware/presentation/providers/firmware_notification_providers.dart`
- Modify: `lib/app.dart` (one `listenManual` on the sync provider next to the other lifetime listeners)
- Test: `test/features/firmware/presentation/providers/firmware_notification_providers_test.dart`

**Interfaces:**
- Produces: `List<FirmwareUpdateEntry> firmwareUpdatesToNotify(List<FirmwareUpdateEntry> updates, Set<String> notifiedPairs)` (pure); `firmwareNotificationSyncProvider` (FutureProvider<void>) that shows one notification per new pair, then appends the pairs to `firmware_notified_pairs`.

Text: title "Firmware update for {item}", body "{latest} is available. Tap for release notes." (safety: "{latest} is a safety update. Tap for release notes.").

- [ ] **Step 1: Write the failing tests** with a fake notifier function injected through a provider:
  - first run notifies `eq1|V95` and stores it; a second run (fresh container, same prefs) notifies nothing;
  - a catalogue with V96 above V95 notifies `eq1|V96`;
  - notifications switch off: nothing shown, nothing stored; checks off: nothing shown.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(firmware): notify once per new firmware release`

### Task 13: Settings switches

**Files:**
- Create: `lib/features/firmware/presentation/widgets/firmware_settings_switches.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (one `const FirmwareSettingsSwitches()` after `DraftReminderSwitch`)
- Test: `test/features/firmware/presentation/widgets/firmware_settings_switches_test.dart`

Two `SwitchListTile`s in Cards like the draft reminder: "Check for firmware updates" (subtitle "Reads the public firmware list once a day. Nothing about you is sent.") and "Firmware update notifications", which is hidden while checks are off rather than shown disabled.

- [ ] **Step 1: Write the failing test**: both default on; turning checks off hides the second and stores false; values survive a rebuild from the same prefs.
- [ ] **Step 2: Run**; expect failure. **Step 3: Implement.** **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(settings): firmware check and notification switches`

### Task 14: Finish

- [ ] `dart format .`, `flutter analyze` clean, every test file touched above run by path.
- [ ] After screenshots (throwaway goldens, uncommitted) of: a Dive Computer item page with an update and with up to date, the equipment list with a badge, the dashboard panel, the service history with a firmware row, the service dialog with the version field, the Settings switches; light and dark for the card and badge; phone and desktop width for the item page and dashboard.
- [ ] Delete the throwaway golden folder before pushing.
