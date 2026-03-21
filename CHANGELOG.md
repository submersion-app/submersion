# Changelog

All notable changes to Submersion are documented in this file.


## 1.3.6 (2026-03-21)

### Features

- add dive list view mode dropdown to Appearance settings
- integrate view mode toggle and tile switching in dive list
- add DiveListViewModeToggle segmented button
- add DenseDiveListTile widget
- add CompactDiveListTile widget
- wire DiveListViewMode through settings layer
- add dive_list_view_mode column to DiverSettings (schema v51)
- add DiveListViewMode enum

### Bug Fixes

- formatting
- replace SegmentedButton with PopupMenuButton for view mode toggle
- add dive list view mode dropdown to desktop settings page
- normalize wall-clock-as-UTC and local times in media matching
- open schema version check in read-write mode to allow WAL recovery

### Documentation

- add compact dive list view implementation plan
- add compact dive list view design spec
- add multi-computer dive consolidation implementation plan
- address spec review feedback for multi-computer consolidation
- add multi-computer dive consolidation design spec

### Chores

- bump version to 1.3.6+81
- update changelog

### Other

- Fix/air consumption unit conversion (#52)
- Feature/site picker search (Issue #49) (#51)


## 1.3.5 (2026-03-19)

### Features

- add dive number field to dive edit form
- add dive number field translations
- auto-assign dive numbers during dive computer import
- add diveNumber parameter to importProfile()
- add translations for default tank preset keys in all locales
- add default preset indicator and import toggle to Tank Presets page
- add localization keys for default tank preset feature
- apply default tank preset fallback in entity importer and providers
- apply default tank preset in DiveEditPage
- add import tank defaults utility for per-field fallback
- add DefaultTankPresetResolver utility
- persist defaultTankPreset and applyDefaultTankToImports in repository and sync
- add defaultTankPreset and applyDefaultTankToImports to AppSettings
- add defaultTankPreset and applyDefaultTankToImports columns to DiverSettings

### Bug Fixes

- pre-populate dive number field with next sequential number
- use wall-clock-as-UTC convention for Subsurface XML import times
- Fix dive list sorting.
- invalidate stale caches for import stats, buddy unlink, and buddy delete.
- prevent unnecessary recalculation and fix right axis "None" selection
- clarify default tank UI with description text and better toggle label
- move setDefaultTankPreset inside context.mounted guard
- preserve existing startPressure in backfill, set _tanksDirty on load
- add missing endPressure: 50 in _addTank()
- create backup directory before copying in DatabaseService.backup()

### Documentation

- add implementation plan for dive number auto-assign and edit
- address spec review feedback for dive number design
- add design spec for dive number auto-assignment and manual editing
- add implementation plan for default tank preset feature
- add design spec for default tank preset feature

### Chores

- bump version to 1.3.5+80
- bump version to 1.3.4+79
- regenerate l10n files after description key addition
- update pubspec.lock after dependency resolution on new environment


## 1.3.3 (2026-03-18)

### Features

- add schema version-mismatch guard to prevent older app from opening newer database
- add Fix Dive Times settings page for bulk-fix tool
- add DiveTimeMigrationService for bulk-fix offset logic
- add importVersion column and wall-clock-as-UTC migration (schema v49)
- construct wall-clock-as-UTC DateTime from raw components in mapper
- pass raw datetime components instead of UTC epoch
- add nativeGetDiveTimezone JNI binding
- pass raw datetime components instead of UTC epoch
- replace dateTimeEpoch with raw component fields in Pigeon API

### Bug Fixes

- pass raw datetime components instead of epoch in dive converters
- use UTC bounds for all dive date range queries
- use DateTime.utc for manual dive entry (wall-clock-as-UTC)

### Documentation

- add dive time timezone fix implementation plan
- add dive_import_providers to files changed table
- address spec review findings for dive time timezone fix
- add dive time timezone fix design spec

### Chores

- bump version to 1.3.3+78
- formatting
- formatting


## 1.3.2 (2026-03-16)

### Chores

- bump version to 1.3.2+77
- disable cloud sync UI options until bugs are addressed


## 1.3.2 (2026-03-15)

### Features

- wire SubsurfaceXmlParser and add integration test with real export
- add trip and tag parsing with deduplication
- add site parsing with GPS, geo taxonomy, and UUID whitespace trimming
- add cylinder/tank, weight, and profile sample parsing
- add dive metadata parsing (buddy, notes, visibility, current, salinity)
- scaffold SubsurfaceXmlParser with value helpers and minimal dive parsing

### Bug Fixes

- show imported buddies in review step and fix profile temperature
- import buddies as proper entities and fill sparse profile data
- import Subsurface buddies and divemasters as proper Buddy entities
- import Subsurface buddies and divemasters as proper Buddy entities
- interpolate sparse pressure data in Subsurface XML profile samples
- auto-select newly created dive site when returning to dive edit page

### Documentation

- add Subsurface XML import implementation plan
- fix spec review issues in Subsurface XML import design
- add Subsurface XML import design spec

### Tests

- add edge case and error handling tests

### Chores

- bump version to 1.3.2+76
- update README.md


## 1.3.1 (2026-03-14)

### Bug Fixes

- prevent black screen on startup from failed database migration

### Chores

- bump version to 1.3.1+75


## 1.3.0 (2026-03-14)

### Features

- migrate all display widgets to resolved asset providers
- add unavailable photo placeholder widget and l10n key
- add resolved asset providers for cross-device photo display
- add AssetResolutionService with tiered matching and cache
- initialize local cache database at app startup
- add LocalAssetCacheRepository with CRUD and backoff logic
- add LocalCacheDatabaseService singleton for local cache lifecycle
- add local cache Drift database for cross-device asset resolution
- weather documentation
- add weather localization strings
- add weather fields to universal import mapping
- add weather fields to UDDF export
- add weather fields to sync serializer
- add weather columns to Excel export
- add weather columns to CSV export
- auto-fetch weather on new dive creation
- replace Conditions with Environment section on dive detail page
- replace Conditions with Environment section on dive edit page
- add wind speed formatting to UnitFormatter
- add weather Riverpod providers
- add WeatherRepository for fetch + persist orchestration
- add WeatherService HTTP client for Open-Meteo API
- add WeatherMapper for Open-Meteo API response mapping
- map weather fields in DiveRepository
- add weather columns to dives table (migration v48)
- create WeatherData value object
- add weather fields to Dive entity
- add CloudCover, Precipitation, WeatherSource enums
- handle zero-dive incremental download with up-to-date message
- add incremental download toggle and completion messages to download page
- wire fingerprint logic into DownloadNotifier for incremental download
- pass fingerprint to libdc_download_run
- pass fingerprint to libdc_download_run
- pass fingerprint through JNI to libdc_download_run
- pass fingerprint to libdc_download_run for incremental download
- add fingerprint parameter to DiveComputerService.startDownload
- add fingerprint parameter to Pigeon startDownload API
- add lastDiveFingerprint schema column and repository support
- add lastDiveFingerprint field to DiveComputer entity
- add selectNewestFingerprint utility for incremental download

### Bug Fixes

- verify cached asset IDs are still loadable before returning
- update Submersion preset column count test to 21
- wire up l10n keys for weather UI and fix _hasEnvironmentData
- invalidate stale provider cache so incremental download uses stored fingerprint
- replace hardcoded strings with l10n keys for incremental download UI

### Tests

- add escalating backoff coverage for local asset cache
- add integration tests for fingerprint persistence in DownloadNotifier

### Chores

- bump version to 1.3.0+74
- localization update
- format code and fix lint warnings for weather feature
- documentation update
- formatting
- translations
- fix mock override and format generated code for incremental download


## 1.2.25 (2026-03-12)

### Features

- add PIN code auth and access code support
- wire PIN code callback and submitPinCode in HostApiImpl
- handle PIN code and access code ioctls in JNI layer
- add PIN code and access code support to BleIoHandler/BleIoStream
- wire PIN code callback and submitPinCode in HostApiImpl
- add PIN code and access code ioctl handlers to BleIoStream
- wire PIN code dialog into download UI pages
- create PIN code dialog widget for BLE authentication
- add pinRequired phase, submitPinCode, remove setDialogContext
- add PinCodeRequestEvent and submitPinCode to DiveComputerService
- add PIN code Pigeon API (submitPinCode + onPinCodeRequired)

### Bug Fixes

- resolve location failure after fresh permission grant

### Chores

- bump version to 1.2.25+73
- add ble pin code plan


## 1.2.24 (2026-03-11)

### Bug Fixes

- retry location capture when first attempt fails on cold start

### Chores

- bump version to 1.2.24+72


## 1.2.24 (2026-03-11)

### Bug Fixes

- decouple store uploads from GitHub release and notify on upload failures

### Chores

- bump version to 1.2.24+71
- added translations


## 1.2.23 (2026-03-10)

### Bug Fixes

- declare location data collection in privacy manifests and improve macOS purpose string
- refactor github release workflow to require all builds to succeed before uploading to any app store.
- replace flutter-action internal actions/cache@v4 with explicit actions/cache@v5

### Chores

- bump version to 1.2.23+70


## 1.2.23 (2026-03-10)

### Bug Fixes

- failing test due to label change
- release.sh use project directory for generating the changelog.
- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+69
- bump version to 1.2.23+68
- bump version to 1.2.23+67
- add code optimization plan


## 1.2.23 (2026-03-10)

### Bug Fixes

- release.sh use project directory for generating the changelog.
- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+68
- bump version to 1.2.23+67
- add code optimization plan


## 1.2.23 (2026-03-10)

### Bug Fixes

- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+67
- add code optimization plan

## 1.1.2 (2026-02-16)

### Chores

- bump version to 1.1.2+39

### Other

- Fix: appcast feed URL pointed to incorrect repo
- generate favicon without rounded corners or alpha

## 1.1.1 (2026-02-16)

### Features

- add unified release script
- add changelog generation from conventional commits

### Bug Fixes

- skip Claude code review for Dependabot PRs
- disable Codecov fail_ci_if_error until repo is configured
- allow Dependabot bot in Claude code review workflow
- add Codecov token and graceful fallback
- include build-ios in appcast job dependencies
- match analyze strictness between CI and release preflight

### Documentation

- add PR template with test plan checklist
- add CI/CD pipeline overhaul implementation plan
- add CI/CD pipeline overhaul design

### CI/CD

- bump actions/download-artifact from 4 to 7 (#17)
- bump actions/checkout from 4 to 6 (#19)
- bump actions/setup-java from 4 to 5 (#20)
- bump actions/upload-artifact from 4 to 6 (#15)
- bump actions/setup-python from 5 to 6 (#18)
- bump codecov/codecov-action from 4 to 5 (#16)
- add integration tests on macOS for pull requests
- enforce coverage threshold via Codecov
- add weekly performance benchmark workflow
- add Dependabot for GitHub Actions, pub, and Bundler
- use changelog for release notes and add post-release validation
- add retry logic for notarization and Fastlane uploads
- pin Flutter version via shared config file

### Chores

- bump version to 1.1.1+38

### Other

- Updates section in Settings/About should not show on iOS or Android

Format follows [Keep a Changelog](https://keepachangelog.com/).
