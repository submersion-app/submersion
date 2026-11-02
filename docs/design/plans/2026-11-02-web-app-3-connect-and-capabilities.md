# Web App Plan 3: Connect Flow, Capabilities, Backends and Media

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In a browser, the first run connects to the user's S3, Dropbox, Google Drive or WebDAV store through the existing setup wizard, syncs both ways, diagnoses a store that blocks browser requests, forgets credentials unless asked to remember them, hides every feature the browser cannot offer, shows media read-only, and can forget the device.

**Architecture:** One capability object (`DeviceCapabilities`) answers every "can this device do X" question; its native file reflects the OS as today's scattered checks do and its web file encodes the spec's table. The connect screen is the wizard's existing cloud-sync path entered directly on the web, with four additions: unavailable tiles for iCloud and Git, a Google web client id field, a "remember on this device" switch, and a cross-origin diagnoser behind "Check connection". Secure storage gets a web backend with a session store and a local store that the switch moves entries between. Media surfaces consult the capability object and hide their write actions. Downloads go through a `FileSaver` facade.

**Tech Stack:** Riverpod providers, the existing `AccountChooser`, `SetUpSyncStep`, `OwnServerForm`, `FallbackSecureStorage`, `google_sign_in` 7.2 (web through Google Identity Services), `package:web` (`localStorage`, `navigator.userAgent`, `navigator.storage`, Blob download), `flutter_map` `NetworkTileProvider`.

**Spec:** `docs/design/specs/2026-11-02-web-app-design.md` (sections "What works, what does not", "Backends in a browser", "The diagnoser", "Connecting", "Credential storage", "Identity in the mesh", "Media", "3. The platform layer").

## Global Constraints

- Everything in Plan 1's Global Constraints.
- UI code asks `ref.watch(deviceCapabilitiesProvider)`, never `kIsWeb` or `HostPlatform.isWeb`, to decide whether a feature appears. `HostPlatform.isWeb` is for platform-layer code only.
- Every hidden feature disappears or shows the one-line "not available in a browser" page. Nothing throws `MissingPluginException` to the user.
- New user-facing strings go into all eleven ARB files under `lib/l10n/arb/` (en plus ar, de, es, fr, he, hu, it, nl, pt, zh) with real translations, inserted next to a key of the same feature group in each file, and `flutter gen-l10n` runs last, after every ARB has the key. Commit the ARBs and the generated `app_localizations_*.dart` together in one `i18n(web): ...` commit per task that adds strings. Verify with `grep -A1 "get <key>" lib/l10n/arb/app_localizations_de.dart`.
- Credentials never reach browser local storage unless `rememberCredentialsProvider` is true.
- Native behaviour does not change: every web branch is additive.

## Review Focus

1. A user turns "remember on this device" off after connecting and the passphrase stays in local storage. Task 3's test asserts `setRemember(false)` moves every key to the session store and local storage holds none.
2. The Google web client id typed with surrounding whitespace or the `.apps.googleusercontent.com` suffix missing fails later with an opaque sign-in error. Task 5 validates the id shape before storing it and the test covers both inputs.
3. A WebDAV server that allows GET but not PROPFIND looks like a CORS block on the first request. Task 6's diagnoser treats an opaque failure on PROPFIND with a successful OPTIONS as "method not allowed by CORS" and prints the `Access-Control-Allow-Methods` line; the test covers it.
4. The browser peer appears in other devices' lists as "Browser" because the user agent was unrecognised. Task 7's test covers Chrome, Edge, Firefox and Safari on Windows, macOS, Linux, iOS and Android user agents, plus the fallback.
5. Forgetting the device while a sync is in flight leaves half a database. Task 8 runs `forget()` under `SyncCoordinator.join` and the cross-tab lock, and the test asserts a running body completes before deletion starts.

---

### Task 1: `DeviceCapabilities`

**Files:**
- Create: `lib/core/platform/device_capabilities.dart` (class, provider and facade export), `device_capabilities_io.dart`, `device_capabilities_web.dart`
- Modify: `lib/features/settings/presentation/providers/storage_providers.dart:13` `StoragePlatformCapabilities` fields read the new object (keep the class for its callers)
- Test: `test/core/platform/device_capabilities_test.dart`

**Interfaces:**
- Produces:
  ```dart
  @immutable
  class DeviceCapabilities {
    const DeviceCapabilities({required this.diveComputerDownload, required this.nfc, required this.nearby, required this.healthImport, required this.devicePhotoLibrary, required this.mediaAttach, required this.biometricLock, required this.databaseEncryption, required this.backgroundTasks, required this.offlineMapTiles, required this.backupRestore, required this.sqliteImport, required this.demoMode, required this.agentAccess, required this.autoUpdate, required this.ocrImport, required this.customDatabaseFolder, required this.revealInFileManager, required this.cloudICloud, required this.cloudGit, required this.cloudGoogleDrive, required this.isBrowser});
    final bool ...;   // one per name above
    static const DeviceCapabilities web = DeviceCapabilities(isBrowser: true, cloudGoogleDrive: true, /* every other field false except mediaAttach: false, backupRestore: false, sqliteImport: false, demoMode: false */);
  }
  DeviceCapabilities currentDeviceCapabilities();        // facade: io computes from HostPlatform and existing checks; web returns DeviceCapabilities.web
  final deviceCapabilitiesProvider = Provider<DeviceCapabilities>((ref) => currentDeviceCapabilities());
  ```
  The io file reproduces today's gates: `diveComputerDownload` true everywhere native, `nfc` on Android and iOS, `nearby` on Android, iOS, macOS and Windows, `healthImport` on iOS and Android, `devicePhotoLibrary` on Android, iOS and macOS, `biometricLock` on Android, iOS, macOS and Windows, `cloudICloud` on Apple platforms, `cloudGoogleDrive` from `GoogleDriveClientConfig.isSupportedOnThisPlatform`, `agentAccess` from `hasDesktopWindow() && debug`, `autoUpdate` from `UpdateChannelConfig.isAutoUpdateEnabled`, `ocrImport` on Android, iOS, macOS and Windows, the rest true.

- [ ] **Step 1: Write the failing test** (`DeviceCapabilities.web` has every spec-table field false and `isBrowser` true; the io value on this VM matches `HostPlatform` and the existing providers it replaces)
- [ ] **Step 2: Implement; make `StoragePlatformCapabilities` derive from it**
- [ ] **Step 3: Run** `flutter test test/core/platform test/features/settings/presentation/providers`, commit `feat(web): DeviceCapabilities object`

---

### Task 2: Hide what the browser cannot do

**Files:**
- Create: `lib/core/router/web_unavailable_routes.dart` (`const webUnavailableRoutePrefixes = {'/dive-computers', '/dives/scan', '/settings/wearable-import', '/settings/nearby', '/settings/offline-maps', '/settings/backup/restore', ...}` and `String? webUnavailableRedirect(DeviceCapabilities caps, GoRouterState state)` returning `/unavailable-in-browser?feature=<id>` for a matching prefix when `caps.isBrowser`), modelled on `demo_sealed_routes.dart`
- Create: `lib/shared/widgets/web_unavailable_page.dart` (`WebUnavailablePage({required String feature})`: the feature's label and the one-line reason from l10n)
- Modify: `lib/core/router/app_router.dart` redirect chain adds `webUnavailableRedirect` after `demoRedirect` (line 273) and registers `/unavailable-in-browser`
- Modify: `lib/shared/widgets/nav/nav_order_provider.dart` `navDestinationsProvider` and `movableNavIdsProvider` drop destinations whose feature is unavailable (`transfer` keeps its import and export sections; nothing else in `kNavDestinations` is hardware-only, so this is a filter hook with a test, not a visible change)
- Modify (each consults `deviceCapabilitiesProvider`): `lib/features/transfer/presentation/widgets/transfer_list_content.dart` (hide `computers` section), `transfer_page.dart` (computers section, Health row at 787-805), `lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart` (download and scan entries), `lib/features/settings/presentation/widgets/settings_list_content.dart:135` and `settings_page.dart:223` (`dataSources` section also needs `healthImport`; `security` section needs `biometricLock || databaseEncryption`), `lib/features/settings/presentation/pages/cloud_sync_page.dart:115` (nearby section), `lib/features/settings/presentation/pages/data_section_content.dart` (offline maps 202-207, backup restore 141-148, demo 233-251, database storage 193-201 when `!customDatabaseFolder` shows the storage row read-only), `lib/features/backup/presentation/pages/backup_settings_page.dart:30` and `backup_actions.dart:50` (restore tile), `lib/features/settings/presentation/widgets/set_up_device/set_up_account_step.dart:92-99` (restore button), `lib/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart` (restore and open-folder cards), `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart:174-184` (demo link), `lib/features/settings/presentation/pages/data_tools_page.dart:56-63` (agent access), `lib/features/settings/presentation/pages/settings_page.dart:2198-2262` (updates card), `lib/features/dashboard/presentation/widgets/gauge_strip.dart:436,454` (restore shortcuts), `lib/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart`, `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart:101` `nfcSupportProvider` (reads `caps.nfc`), `lib/features/gear_passports/presentation/widgets/gear_tag_card.dart`, `lib/features/universal_import/data/models/import_enums.dart:83` `isSupported` (SQLite formats need `caps.sqliteImport`; pass capabilities in from the parser registry)
- Modify: `lib/features/maps/data/services/tile_cache_service.dart`: `initialize` is a no-op on the web; `tileProviderFor`, `getTileProvider`, `browseTileProvider`, `getOfflineTileProvider`, `offlineTileProvider` return a `NetworkTileProvider(httpClient: createPlatformHttpClient())` when `!caps.offlineMapTiles` (return type widens to `TileProvider`); `getTotalCacheSize` returns 0
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_actions.dart:415` and `lib/features/dive_log/presentation/providers/computer_mix_providers.dart` (re-parse through the pigeon host API needs `caps.diveComputerDownload`; otherwise the action is hidden and the provider returns the stored mixes)
- Test: `test/core/router/web_unavailable_routes_test.dart`, `test/shared/widgets/web_unavailable_page_test.dart`, and one widget test per modified surface under its feature's test folder, each pumped twice: with `deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web)` asserting the row or button is absent, and with the io value asserting it is present

- [ ] **Step 1: Write the route and page tests, then the per-surface absent/present tests**
- [ ] **Step 2: Implement, surface by surface, running each feature's tests as you go**
- [ ] **Step 3: Run** `flutter test test/core/router test/shared test/features/transfer test/features/settings test/features/backup test/features/setup_wizard test/features/dive_log test/features/maps test/features/universal_import test/features/buddies test/features/cylinder_passports test/features/gear_passports test/features/dashboard` **and** `test/architecture/`
- [ ] **Step 4: i18n commit for the unavailable-page strings (feature labels and reasons: `web_unavailable_title`, `web_unavailable_reason_hardware`, `web_unavailable_reason_background`, `web_unavailable_reason_files`, `web_unavailable_reason_icloud`, `web_unavailable_reason_git`)**
- [ ] **Step 5: Commit** `feat(web): hide hardware and file-bound features in the browser`

---

### Task 3: Secure storage with a session store and a remembered store

**Files:**
- Create: `lib/core/platform/web/web_secure_storage_core.dart` (pure Dart, VM-testable)
  ```dart
  class WebSecureStorageCore {
    WebSecureStorageCore({required Map<String, String> localStorage, String prefix = 'submersion.secure.'});
    bool get remember;                                     // from localStorage['submersion.rememberCredentials'] == 'true'
    Future<void> setRemember(bool value);                  // moves every entry between the session map and localStorage
    Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key);
    Future<void> clearAll();                                // both stores and the flag
    Set<String> get keys;
  }
  ```
- Create: `lib/core/platform/secure_storage_backend.dart` (facade), `_io.dart` (wraps the `FlutterSecureStorage` instance `FallbackSecureStorage` is given), `_web.dart` (one `WebSecureStorageCore` over `window.localStorage` through `package:web`; the given `FlutterSecureStorage` is ignored)
- Modify: `lib/core/services/secure_storage/fallback_secure_storage.dart` reads, writes and deletes through the backend; `legacyKeychainRequired` returns false on the web
- Create: `lib/core/platform/web/remember_credentials_provider.dart`: `rememberCredentialsProvider` (`NotifierProvider<RememberCredentialsNotifier, bool>`, `set(bool)` calls `setRemember`)
- Test: `test/core/platform/web/web_secure_storage_core_test.dart` (write with remember off lands in the session map only; `setRemember(true)` copies to local storage under the prefix and clears the session map; `setRemember(false)` moves them back and local storage keeps only no prefixed keys; `clearAll` empties both and the flag; `read` after a simulated reload with remember off returns null), existing `test/core/services/secure_storage/`

- [ ] **Step 1: Write the core test, implement the core**
- [ ] **Step 2: Add the backend facade; route `FallbackSecureStorage` through it; run** `flutter test test/core/platform test/core/services`
- [ ] **Step 3: Commit** `feat(web): session-only credentials with a remember-on-this-device store`

---

### Task 4: Web first run and the connect additions in the wizard

**Files:**
- Modify: `lib/features/setup_wizard/presentation/providers/setup_wizard_providers.dart`: when `caps.isBrowser` and `mode == firstRun`, the initial draft has `path = SetupPath.existing` and `source = ExistingDataSource.cloudSync`
- Modify: `lib/features/setup_wizard/domain/setup_wizard_models.dart` `computeSteps`: when the draft is browser-first-run, the list starts at `setUpAccount` (no `welcomeFork`, no `existingChoice`)
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` `_navigationFor`: on the browser, `onNoLibrary` on the account step is a "Continue without a sync store" link that calls `choosePath(SetupPath.fresh)` and goes to `profile`
- Create: `lib/features/settings/presentation/providers/unavailable_account_kinds_provider.dart`: `unavailableAccountKindsProvider` returns `{AccountKindOffer.icloud: l10nKey, AccountKindOffer.git: l10nKey}` when `caps.isBrowser`, else `{}`
- Modify: `lib/features/settings/presentation/widgets/accounts/account_chooser.dart`: after the offerable tiles, render each unavailable offer as a disabled `ListTile` with its reason as subtitle; Google tile subtitle on the browser adds the sign-in note (`settings_setUpDevice_offer_googleDrive_browser`)
- Modify: `lib/features/settings/presentation/widgets/set_up_device/set_up_account_step.dart`: on the browser, a `SwitchListTile` bound to `rememberCredentialsProvider` with title `web_rememberOnThisDevice_title` and subtitle `web_rememberOnThisDevice_subtitle`; the restore button is already hidden by Task 2
- Test: `test/features/setup_wizard/presentation/pages/setup_wizard_page_web_test.dart` (with the web capabilities override: first visible step is the account chooser; the continue-without-sync link exists and leads to the profile step; iCloud and Git tiles are present and disabled with their reasons; the remember switch is present and toggles the provider), `test/features/setup_wizard/domain/setup_wizard_models_test.dart` (browser first-run steps list), existing wizard tests unchanged

- [ ] **Step 1: Write the failing tests**
- [ ] **Step 2: Implement; i18n commit for `web_rememberOnThisDevice_title`, `web_rememberOnThisDevice_subtitle`, `web_continueWithoutSync`, `settings_setUpDevice_offer_googleDrive_browser`, `web_unavailable_offer_icloud`, `web_unavailable_offer_git`**
- [ ] **Step 3: Run** `flutter test test/features/setup_wizard test/features/settings/presentation/widgets`, commit `feat(web): the browser's first run opens on the connect step`

---

### Task 5: Google Drive in the browser

**Files:**
- Create: `lib/core/services/cloud_storage/google_drive/google_web_client_id_store.dart` (`GoogleWebClientIdStore` over `FallbackSecureStorage`, key `google_web_client_id`; `static String? normalize(String raw)` trims and returns null unless it matches `^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$`)
- Modify: `lib/core/services/cloud_storage/google_drive/google_drive_client_config.dart`: `isSupportedOnThisPlatform` on the web is `caps.cloudGoogleDrive`; a new `static Future<String?> webClientId()` reads the store
- Modify: `lib/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart`: on the web, `GoogleSignIn.instance.initialize(clientId: webClientId)` before the first sign-in; token renewal failures that need a user gesture (`GoogleSignInException` with code `uiUnavailable` or `canceled` during a silent renewal) throw `CloudAuthRequired`
- Modify: `lib/features/settings/presentation/widgets/accounts/account_sign_in.dart` `_signInGoogle`: on the web with no stored id, show `GoogleWebClientIdDialog` (new file next to `dropbox_connect_dialog.dart`) with the field, a link to the user guide section, and validation through `normalize`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`: `SyncState` gains `bool needsSignIn`; `_runSyncOnce` maps `CloudAuthRequired` to `needsSignIn = true` and `status = SyncStatus.error` with message `web_signInAgain_message`; the sync status card shows a "Sign in again" action row that calls `authenticateAs(currentAccount)`
- Test: `test/core/services/cloud_storage/google_drive/google_web_client_id_store_test.dart` (normalize accepts a valid id with whitespace, rejects a missing suffix, rejects an empty string), `test/features/settings/presentation/providers/sync_providers_needs_sign_in_test.dart` (a sync that throws `CloudAuthRequired` sets `needsSignIn`; a later success clears it), widget test for the dialog's validation message

- [ ] **Step 1: Write the failing tests, implement**
- [ ] **Step 2: i18n commit for `web_googleClientId_title`, `web_googleClientId_hint`, `web_googleClientId_invalid`, `web_googleClientId_help`, `web_signInAgain_message`, `web_signInAgain_action`**
- [ ] **Step 3: Run** `flutter test test/core/services/cloud_storage test/features/settings`, commit `feat(web): Google Drive with a user-supplied web client id`

---

### Task 6: S3 and WebDAV diagnoser

**Files:**
- Create: `lib/core/platform/web/cors_diagnoser.dart` (pure Dart)
  ```dart
  enum CorsVerdict { blockedByCors, methodBlockedByCors, writeBlockedByCors, forbidden, notFound, tlsOrUnreachable, ok, unknown }
  enum StoreKind { awsS3, cloudflareR2, backblazeB2, minio, genericS3, nextcloud, genericWebDav }
  class CorsDiagnosis { final CorsVerdict verdict; final StoreKind kind; final String origin; String get ruleTemplate; }
  StoreKind detectStoreKind(Uri endpoint, {required bool isWebDav});   // amazonaws.com, r2.cloudflarestorage.com, backblazeb2.com, '/remote.php/dav' path, else generic
  CorsDiagnosis diagnose({required Object error, required Uri endpoint, required String origin, required bool isWebDav, required bool failedOnWrite, bool optionsSucceeded = false});
  ```
  Classification: an `http.ClientException` whose message contains `XMLHttpRequest error` or `Failed to fetch` is opaque; opaque and `failedOnWrite` is `writeBlockedByCors`; opaque and `optionsSucceeded` is `methodBlockedByCors`; opaque otherwise is `blockedByCors` unless the endpoint scheme is `https` with a non-public host, which is `tlsOrUnreachable`; `CloudAccessRefusedException` is `forbidden`; a message containing `NoSuchBucket` or `404` is `notFound`.
- Create: `lib/core/platform/web/cors_rule_templates.dart`: `String corsRuleTemplate(StoreKind kind, {required String origin, required bool writes})` returning the AWS JSON, the R2 dashboard JSON, the B2 `b2 bucket update --cors-rules` JSON, the MinIO `mc admin config set <alias> api cors_allow_origin=<origin>` line, the Nextcloud nginx `add_header` block and the Apache `Header always set` block; every template contains `origin`; `writes` adds PUT and DELETE
- Create: `lib/features/settings/presentation/widgets/accounts/cors_help_sheet.dart` (`showCorsHelpSheet(context, CorsDiagnosis)`: verdict title, one-paragraph explanation, the template in a monospace selectable box, a Copy button)
- Modify: `lib/features/settings/presentation/widgets/accounts/own_server_form.dart` `_check`: on the browser, catch the failure, call `diagnose` with `origin = Uri.base.origin`, and open the sheet instead of the generic error text; WebDAV passes `isWebDav: true` and, when the failure is opaque, first runs an `OPTIONS` through the platform client to fill `optionsSucceeded`
- Modify: `lib/core/services/cloud_storage/s3_storage_provider.dart` `_probe` records which step failed (list, put, get, delete) so `failedOnWrite` is known; surface it on the thrown `CloudStorageException` as a `failedOperation` field
- Test: `test/core/platform/web/cors_diagnoser_test.dart` (one case per verdict, including Review Focus 3), `cors_rule_templates_test.dart` (every kind contains the origin; `writes: false` omits PUT), `test/features/settings/presentation/widgets/accounts/cors_help_sheet_test.dart`

- [ ] **Step 1: Write the failing tests, implement**
- [ ] **Step 2: i18n commit for `web_cors_title_<verdict>` (eight keys), `web_cors_explain_<verdict>`, `web_cors_copyRule`**
- [ ] **Step 3: Run** `flutter test test/core/platform/web test/core/services/cloud_storage test/features/settings`, commit `feat(web): diagnose a store that blocks browser requests and print the rule to add`

---

### Task 7: Browser device name

**Files:**
- Create: `lib/core/platform/web/browser_device_name.dart` (pure): `String browserDeviceName(String userAgent)` producing `<Browser> on <OS>` from `{Edge, Chrome, Firefox, Safari}` and `{Windows, macOS, Linux, iOS, Android, ChromeOS}`, `'Browser'` when neither side is recognised, `'Chrome'` alone when only the browser is
- Modify: `lib/core/services/device_display_name_service.dart` `resolve()`: when `HostPlatform.isWeb`, return `browserDeviceName(HostPlatform.operatingSystemVersion)` (the web `HostPlatform` exposes the user agent there) before trying the channel or the hostname
- Test: `test/core/platform/web/browser_device_name_test.dart` (Review Focus 4's matrix), existing `test/core/services/device_display_name_service_test.dart`

- [ ] **Step 1: Write the failing matrix test, implement, run** `flutter test test/core/platform/web test/core/services`
- [ ] **Step 2: Commit** `feat(web): name the browser peer after the browser and platform`

---

### Task 8: Web rows in Settings and Forget this device

**Files:**
- Create: `lib/core/platform/web/web_forget_device_service.dart` (web only; io stub throws): `Future<void> forget(WidgetRef ref)`: `SyncCoordinator.join` plus `withCrossTabLock('submersion-sync', ...)` around: `syncStateProvider.notifier.disableForDatabaseReset()`, `WebSecureStorageCore.clearAll()`, `SharedPreferences.clear()`, close `DatabaseService.instance` strictly, remove the OPFS entries `drift_db` and `submersion-sync-tmp` through `navigator.storage.getDirectory()`, then `window.location.reload()`
- Create: `lib/features/settings/presentation/widgets/web/web_sync_rows.dart`: `WebSyncRows` widget (browser only) with three rows: storage implementation (`webDatabaseStatusProvider`: `opfsShared`/`opfsLocks` as "Browser file storage", IndexedDB kinds as "Browser database (slower)", `inMemory` as a warning "Nothing is saved after this tab closes"), the remember switch (same provider as Task 4), and "Forget this device" with a confirmation dialog listing what is removed
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` renders `WebSyncRows` when `caps.isBrowser`
- Test: `test/features/settings/presentation/widgets/web/web_sync_rows_test.dart` (three rows present with the web override, absent otherwise; each status wording), `test/core/platform/web/web_forget_device_service_test.dart` (with injected fakes for prefs, storage core, OPFS remover and reload: the order of calls, and Review Focus 5: a body already inside `SyncCoordinator.run` finishes before `forget` deletes)

- [ ] **Step 1: Write the failing tests, implement**
- [ ] **Step 2: i18n commit for `web_storage_title`, `web_storage_opfs`, `web_storage_indexedDb`, `web_storage_memoryWarning`, `web_forgetDevice_title`, `web_forgetDevice_subtitle`, `web_forgetDevice_confirm`, `web_forgetDevice_confirmBody`**
- [ ] **Step 3: Run** `flutter test test/features/settings test/core/platform/web`, commit `feat(web): storage status, remember switch and Forget this device`

---

### Task 9: Media read-only in the browser

**Files:**
- Modify (hide when `!caps.mediaAttach`): `lib/features/media/presentation/widgets/dive_media_section.dart` (add menu 427-465, gallery scan 404, Lightroom scan 416, bulk unlink 163 and 360, replace link 250 and 263), `site_media_section.dart` (add buttons, bulk unlink/setCategory/editDetails 259-275), `species_photos_section.dart` (`onAddPhotos`), `media_selection_bar.dart` (keep `share`; drop `move_to_dive`, `edit_tags`, `unlink`), `media_viewer_toolbar.dart` (keep `info`, `share`, `go_to_dive`; drop `write_metadata`, `species`, `people`, `adjust_color`, `reupload`, `lightroom`), `media_info_panel.dart` (`_SetTimeButton`, `_LocateButton`, `_BackUpButton`, `_CheckNowButton`), `pages/media_section_page.dart` (`sources` and `importMedia` views)
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart` and `platform_gallery_resolver.dart`: on the web return `UnavailableData(UnavailableKind.fromOtherDevice, ...)` without touching the file system
- Test: widget tests per surface with the web override asserting the write actions are absent and `share`/`info` remain; resolver tests on the VM with `HostPlatform.isWeb` driven through the resolvers' injectable platform flag

- [ ] **Step 1: Write the failing tests, implement, run** `flutter test test/features/media`
- [ ] **Step 2: Commit** `feat(web): media is read-only in the browser`

---

### Task 10: Downloads and exports

**Files:**
- Create: `lib/core/platform/file_saver.dart` (facade), `_io.dart` (the existing save-and-share path: write to the temp dir and hand to `share_plus` or the desktop save dialog, whichever the caller used), `_web.dart` (`Blob` plus a temporary anchor `download` through `package:web`)
  ```dart
  abstract final class FileSaver { static Future<void> saveBytes(Uint8List bytes, {required String fileName, required String mimeType}); }
  ```
- Modify: the export providers under `lib/core/services/export/` and `lib/features/*/presentation/providers/export_providers.dart` that write a temp file then share it: on the browser call `FileSaver.saveBytes`; native path unchanged
- Modify: `lib/features/backup/presentation/widgets/backup_actions.dart`: on the browser the backup card offers "Download a backup" which runs `VACUUM INTO` to an OPFS file through the database connection, reads it back through `SyncTempFiles.openRead`, and saves it as `submersion-backup-<date>.db`; the automatic backup rows are hidden (`caps.backgroundTasks`)
- Test: `test/core/platform/file_saver_io_test.dart`, `test/features/backup/presentation/widgets/backup_actions_web_test.dart` (download row present with the web override; the produced bytes start with `SQLite format 3\0` when the connection fake returns a fixture), `test/web/backup/web_backup_download_test.dart` (browser: a real `VACUUM INTO` on the web database yields a file whose header is `SQLite format 3\0` and whose `PRAGMA user_version` read back through a second in-memory `WasmDatabase` equals `currentSchemaVersion`)

- [ ] **Step 1: Write the failing tests, implement**
- [ ] **Step 2: i18n commit for `web_downloadBackup_title`, `web_downloadBackup_subtitle`**
- [ ] **Step 3: Run** `flutter test test/core/platform test/features/backup test/core/services/export` **and** `flutter test --platform chrome test/web/backup`, commit `feat(web): downloads for exports and a backup copy`

---

### Task 11: End-to-end in Chrome against MinIO (local)

A browser test that connects, pulls a seeded library, edits a dive, publishes, and sees the new changeset in the bucket. Plan 4 runs it in CI; here it runs against a local MinIO started by the owner or skipped with a clear reason when `MINIO_ENDPOINT` is unset (the CI job asserts no skips, so it never silently passes there).

**Files:**
- Create: `tool/seed_sync_library.dart` (VM Dart tool: opens a temporary native `AppDatabase`, seeds two divers, five dives with profiles, a site and a buddy, and publishes them with `ChangesetWriter.publish` through `S3StorageProvider` to the endpoint, bucket and prefix given as arguments, under device id `seed-device`)
- Create: `test/web/sync/s3_round_trip_test.dart` (browser, `@TestOn('browser')`): reads `MINIO_ENDPOINT`, `MINIO_BUCKET`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` from `const String.fromEnvironment` (passed with `--dart-define`), connects with `S3Config`, runs `SyncService.performSync` against the web database, asserts five dives, updates one dive's notes, syncs again, lists the prefix and asserts a changeset object for the browser's device id exists, then opens a second web database under another name, syncs, and asserts the edited notes arrived
- Test: this file

- [ ] **Step 1: Write the seed tool and the test**
- [ ] **Step 2: Run locally if MinIO is available:** `dart run tool/seed_sync_library.dart --endpoint http://localhost:9000 ...` then `flutter test --platform chrome test/web/sync/s3_round_trip_test.dart --dart-define=MINIO_ENDPOINT=...`; otherwise confirm the skip reason reads `MINIO_ENDPOINT not set`
- [ ] **Step 3: Commit** `test(web): S3 round trip in a browser against MinIO`

---

## Self-review notes

- Spec coverage: capability object (1), hiding (2), credentials (3), connecting (4, 5, 6), identity name (7), settings rows and forget (8), media (9), downloads (10), bidirectional sync proof (11). Dropbox needs no task: the PKCE flow and `url_launcher` work in the browser as they are; Task 11's pattern is reused for it in Plan 4's smoke if the owner wants.
- Spec correction to record in the PR: the spec says the user can rename the browser device in Settings "as they can any device". No device rename exists in the app today, so the name is derived and not editable. The owner is told in the hand-off.
- Type consistency: `DeviceCapabilities` field names are used verbatim in Tasks 2, 4, 8, 9, 10. `rememberCredentialsProvider` is defined in Task 3 and used in Tasks 4 and 8. `WebSecureStorageCore.clearAll` is called by Task 8.
