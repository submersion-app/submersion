# Changelog

All notable changes to Submersion are documented in this file.


## Unreleased

### Added

- MacDive UDDF imports now capture substantially richer dive data: boat
  name and captain, dive operator, surface conditions, weather (stored
  in the existing weather description field), plus site water type, body
  of water, and difficulty rating.
- **MacDive native XML import.** MacDive's own `.xml` logbook format is now
  a first-class import source. Unlike MacDive UDDF (which doesn't emit tags),
  the native XML export carries dive tags — so users migrating tag metadata
  from MacDive should choose this format. Supports both Imperial and Metric
  unit modes; depths/temperatures/pressures are converted to the canonical
  internal units at the reader boundary.
- **MacDive (XML) source override** in the import wizard's detected-source
  dropdown, alongside the existing MacDive (CSV) option.
- Cross-format import deduplication: stable per-dive UUIDs from MacDive,
  Shearwater Cloud, Subsurface SSRF, and generic UDDF are now preserved on
  the `dive_data_sources` sidecar. Re-importing the same dives in a
  different format no longer creates duplicates.

### Fixed

- MacDive UDDF: equipment / gear now imports correctly. The parser
  previously only scanned Submersion's private equipment extension,
  missing the standard UDDF gear location (`<diver><owner><equipment>`)
  where MacDive and other compliant exporters place their inventory.
- MacDive UDDF: `<equipmentused><link ref>` is now captured from both
  `<informationbeforedive>` and `<informationafterdive>`.
- MacDive UDDF: `<surfaceintervalbeforedive><infinity/></…>` is now
  explicitly handled as "no prior dive" rather than relying on silent
  int-parse failure.

### Known limitations (to be addressed in a follow-up)

- Gas switch markers (`<switchmix ref>`) in MacDive dive profiles are
  parsed but not yet persisted to the profile samples table. A future
  milestone will wire them through, likely via the dive-events table.


## 1.4.6 (2026-04-22)

### Bug Fixes

- log download failures to the file log (#258)
- DB readonly-rollback recovery + cooperative import cancellation (#255)

### Documentation

- implementation plans for MacDive import milestones 1-4
- design spec for robust MacDive import (UDDF, XML, SQLite, photos)

### Chores

- bump version to 1.4.6+92
- changelog + plan update for MacDive UDDF gap-fill milestone

### Other

- ignore sample data
- Revert "chore: changelog + plan update for MacDive UDDF gap-fill milestone"


## 1.4.5 (2026-04-21)

### Features

- customizable bottom nav primary slots on phone (#250)
- optionally share sites and trips across dive profiles (#249)
- add Cmd+Shift+D to open diver switcher
- Slice D - dive-level metadata + provenance fill-out (#247)
- Slice C.2 - extended SSRF profile events (#244)
- Slice C - profile events + source tagging (#243)
- Slice A - setpoint + partial cylinders (#236)
- add region picker page for offline map downloads
- add map style selector (Street, Topo, Satellite) (#233)
- store raw dive data from dive computers (#176) (#230)
- add Overview page in Statistics section (#167) (#229)
- add map style selector (Street, Topo, Satellite)

### Bug Fixes

- show hours underwater on second line in narrow hero bar
- increase test surface size for desktop appearance hub
- add Map Style picker to desktop settings layout
- make v64 migration defensive for missing diver_settings table
- wrap LocationPickerMap test in ProviderScope
- resolve analyze errors in map style feature

### Documentation

- add implementation plan for raw dive data storage (#176)
- add design spec for raw dive data storage (#176)
- add implementation plan for Statistics Overview (#167)
- add design spec for Statistics Overview page (#167)

### CI/CD

- trigger build

### Chores

- bump version to 1.4.5+91

### Other

- i18n: translate 24 missing shared-sites/trips strings across 10 locales
- i18n: translate 35 missing strings across 10 locales
- Revert "Merge main into Jaibar/main to resolve conflicts for PR #193"
- apply dart format to map style files


## 1.4.4 (2026-04-15)

### Features

- highlight last-visited course on phone-mode list return
- highlight last-visited certification on phone-mode list return
- highlight last-visited dive center on phone-mode list return
- highlight last-visited equipment on phone-mode list return
- highlight last-visited buddy on phone-mode list return
- highlight last-visited site on phone-mode list return
- highlight last-visited trip on phone-mode list return
- highlight last-visited dive on phone-mode list return

### Bug Fixes

- compact x-axis years when crowded on dives-per-year (#174)
- move units from ticks to axis labels on Time at Depth chart
- widen and right-align y-axis labels on CategoryBarChart (#175)
- accept TLDs longer than 4 chars in email validation (#208)
- pass raw args to Drift customStatement, unblocks delete/link (#157)
- use runtime (fallback bottom_time) for total dive time
- match other lists' highlight via isSelected (full tint, no left-border)
- route highlight via new isHighlighted tile param to keep checkbox correct
- route highlight through isHighlighted param, add compact test
- scope dive numbering to active diver and refresh after delete

### Refactoring

- drop redundant isSelected arg on DenseBuddyListTile

### Documentation

- implementation plan for phone-mode list highlight
- correct audit findings in highlight spec — 7 tap handlers also need patching
- spec for highlighting last-visited item in phone-mode lists

### Tests

- add compact-mode highlight test; refresh provider doc comment

### Chores

- bump version to 1.4.4+90
- regenerate mocks for diver-scoped numbering signature change

### Other

- normalize tile highlight alpha to 0.5 across all list views


## 1.4.4 (2026-04-14)

### Features

- re-import all dives from dive computer (#206) (#216)
- default detailed-card stat2 to runtime
- pre-migration database backup (#210)
- localize dive computer section
- require explicit selection for import duplicates (#200) (#209)
- show/hide tags toggle on detailed dive cards

### Bug Fixes

- dissolve splash into app UI instead of hard swap
- Mares Puck 4 descriptor match + import-duplicates design spec (#204)
- new dive center and trip now stick when created from dive form (#201)
- per-diver computer records and cascade diver deletion (#199)
- wrap release workflow expression in ${{ }} to avoid YAML tag parse error
- clean stale native asset state before iOS/macOS CI builds
- exclude appcast from beta releases
- skip Claude Code Review on fork PRs

### Documentation

- spec for re-import all dives (#206)
- added plans
- spec for issue #200 - require explicit selection on duplicate imports
- added plan

### CI/CD

- bump softprops/action-gh-release from 2 to 3 (#213)
- bump actions/checkout from 4 to 6 (#212)

### Chores

- bump version to 1.4.4+89
- upgrade 7 major dependencies with API migrations (#194)
- upgrade 66 package dependencies (#192)

### Other

- i18n: translate 71 missing strings across 10 locales


## 1.4.3 (2026-04-09)

### Features

- improve table row selection UX and simplify built-in presets
- replace sine-wave depth model with Perlin noise, micro-events, and workload-driven gas consumption
- add Perlin noise, diver personality, and micro-events for profile realism
- change UDDF generator default sample interval from 10s to 5s
- expand Standard table preset from 6 to 22 columns
- table mode full-width default, details toggle, and entity settings (#184)
- add column configuration and field category l10n strings
- table view with customizable columns and card fields (#56) (#139)

### Bug Fixes

- formatting
- correct FIT import timezone offset for dive times
- simplify dive computer stats to only show dives imported and last download
- handle CertificationLevel enum type in UDDF import display
- use displayName instead of shortLabel for table column headers
- correct Report an Issue URL and open browser on tap (#177)
- handle label overflow caused by new field on dive planner (#181)

### Documentation

- add implementation plan for expanded Standard table preset
- add implementation plan for UDDF generator improvements
- add design spec for expanded Standard table preset
- add design spec for UDDF generator improvements (#186)
- add implementation plan for startup migration progress (#186)
- add design spec for startup migration progress indicator (#186)
- add implementation plan for table mode full-width and details toggle
- add spec for table mode full-width layout and details toggle

### Chores

- bump version to 1.4.3+88
- remove orphaned uddf_adapter_test.mocks.dart
- remove dead UddfAdapter and FitAdapter

### Other

- Add Claude Code GitHub Workflow (#183)
- Handle average depth imports correctly from computers that do not support it (#180)
- Fix/additional uddf ssrf properties (#170)


## 1.4.2 (2026-04-05)

### Bug Fixes

- await dive list instead of reading synchronously (#62)
- remove _showPressure gate that blocked all tank pressure lines
- restore startup check with background guard (#107)
- stop programmatic background check that suppresses manual dialog (#107)
- show MOD and MND for Air gas mix (#138)
- load tank pressure data for single-tank dives in SAC calculation
- apply tank preset name when defaulting imported dives
- inline release notes HTML in appcast.xml to fix empty update dialog
- use runtime instead of bottom time for longest dive record
- add User-Agent to OSM tile requests, correct package name (#134)
- use correct column name in computer stats temperature query

### Chores

- bump version to 1.4.2+87

### Other

- Deprecate legacy pressure field, fix multi-tank import (#115) (#136)


## 1.4.1 (2026-04-03)

### Bug Fixes

- add missing MinimumOSVersion to AppFrameworkInfo.plist

### Chores

- bump version to 1.4.1+86


## 1.4.1 (2026-04-03)

### Features

- drag-and-drop file import with mobile sharing intents (#128)
- redesign homepage and declutter list page toolbars
- add dashboard hero stat translations for all 10 locales
- reorganize hero - icon left, responsive phone/desktop layouts
- rebuild page layout - 4 sections from 7
- restyle quick actions as vertical button stack
- restyle personal records as compact vertical list
- compact alerts banner replacing full card layout
- rewrite hero header with integrated stats and diver name
- add dashboard hero stat label keys
- add Simplified Chinese localization (#113)
- chinese localization plans

### Bug Fixes

- move Equipment view mode to overflow menu, fix iOS overflow icon
- normalize master-detail headers, update import/export text, add translations
- align Kotlin JVM target to each subproject's Java target
- move tabs into master panel in master-detail mode
- fix selection mode including highlighted dive and normalize icon spacing
- prevent non-CSV payload from being cleared during Map Fields animation
- also refresh paginated dive list on tag changes
- also refresh paginated dive list on tag changes
- await parsing in confirmSource so SSRF auto-advances past Map Fields
- invalidate divesProvider on tag changes to refresh dive list and homepage
- remove trophy icon from personal records header
- change hero stat label to 'dives this year'
- show '0' instead of '0m' for zero hours underwater
- allow hero stat labels to wrap naturally
- always show records card with placeholders, reduce recent dives to 3
- prevent stat labels from wrapping mid-word in hero bar
- increase phone hero stat numbers to 22px
- align stat numbers vertically in phone hero bar
- uniform stat font size in phone mode, remove dives-this-month
- push icon to far right edge in desktop layout
- move icon and diver name to right side of hero bar
- increase phone diver name font to 16px
- match phone hero height to desktop with compact fonts
- use 80px icon in both phone and desktop layouts
- restore phone icon to original 80px size
- match desktop activity stat font size to career stats (24px)
- make equipment tabs compact with pill-style indicator
- replace propane tank icon with scuba tank icon (#109) (#124)
- correct Simplified Chinese translation errors
- address PR #114 review feedback (#120)
- eliminate false safety stop markers on shallow dives (#114)
- resolve NDL line zigzag artifacts on multi-surface-interval dives
- tag formatting fix

### Documentation

- add drag-and-drop file import design spec
- add dashboard revamp implementation plan
- add dashboard revamp design spec
- mdi icons
- false-positive safety stop mitigation design

### CI/CD

- bump codecov/codecov-action from 5 to 6 (#119)

### Chores

- bump version to 1.4.1+85
- remove MinimumOSVersion from AppFrameworkInfo.plist
- remove unused activity_status_row, stat_summary_card, quick_stats_row

### Other

- Revert "fix(android): align Kotlin JVM target to each subproject's Java target"
- Rearchitect CSV import with staged pipeline (#116)
- Fix/volume conversion (#126)
- Issue-115 SSRF multi-cylinder dives don't convert over to gas switch … (#122)
- Bugfix/logger test fix (#106)
- add CSV import rearchitect implementation plan
- add CSV import rearchitect design spec
- Issue 36 - JNI interface being obfuscated in android build (#105)


## 1.4.0 (2026-03-29)

### Bug Fixes

- remove build number from macOS CFBundleShortVersionString

### Chores

- bump version to 1.4.0+84


## 1.4.0 (2026-03-29)

### Features

- add dive detail section config translations for 9 locales
- design docs

### Bug Fixes

- appcast version handling
- version display bug in update dialog
- auto_updater_windows threading violation (#83) (#100)
- fix pre-push hook for worktrees

### Documentation

- add implementation plan for auto_updater threading fix (#83)
- add design spec for auto_updater_windows threading fix (#83)
- add Shearwater Cloud database import design spec
- add implementation plan for duration-bottomtime rename and SAC fix
- add debug log viewer implementation plan
- add debug log viewer design spec
- update duration-bottomtime spec with SAC calculation fix
- add import tag selector design spec

### Chores

- bump version to 1.4.0+83

### Other

- Feature/debug log viewer (#98)
- Feature/dive detail section config (#97)
- Feature/duration bottomtime rename sac fix (#95)
- Feature/shearwater cloud import (#96)
- fix/dive-planner-units (#93)
- Feature/import tag selector (#94)
- Issue-71 UDDF handle switchmix switching with out explicit tank reference (#92)
- Issue-87 gas mixes floating point numbers not rounded for display (#91)
- Feature/data import overhaul (#89)
- issue-70 UDDF dual-tank only shows one tank on dive profile (#86)
- Bugix/default local (#88)


## 1.3.7 (2026-03-24)

### Features

- build all platforms on PRs
- add DenseBuddyListTile and integrate view mode for buddies
- add DenseEquipmentListTile and integrate view mode for equipment
- integrate view mode toggle and tile switching for dive centers
- add CompactDiveCenterListTile and DenseDiveCenterListTile widgets
- integrate view mode toggle and tile switching for trips
- add CompactTripListTile and DenseTripListTile widgets
- integrate view mode toggle and tile switching for sites
- add CompactSiteListTile and DenseSiteListTile widgets
- add per-feature list view mode dropdowns to Appearance settings
- add 5 per-feature list view mode settings
- add 5 list view mode columns to DiverSettings (schema v52)

### Bug Fixes

- stabilize list tile and header sizing in selection mode (#73)
- use UTC wall-time for CSV date/time parsing (fixes #60) (#75)
- allow date pickers to select dates before year 2000
- preserve original timestamps in site merge undo
- debounce search inputs and expand dive search to all related fields (#55)
- quote DART_DEFINES in CodeQL workflow and merge C/C++ analysis into Swift job

### Refactoring

- move ListViewModeToggle to shared/widgets, add availableModes
- rename DiveListViewMode to ListViewMode

### Documentation

- add git submodule init step to setup instructions
- add buddy merge implementation plan
- address spec review feedback for buddy merge design
- add buddy merge feature design spec
- add list view modes all features implementation plan
- update spec with rename, selection mode, and gradient notes
- add list view density modes design spec for all features

### CI/CD

- revert fork PR support for Claude code review
- enable Claude code review on fork PRs
- bump github/codeql-action from 3 to 4 (#80)
- replace CodeQL default setup with custom workflow for Swift and Java/Kotlin analysis
- add explicit permissions to workflows to resolve CodeQL alerts
- exclude generated l10n files from code coverage

### Chores

- bump version to 1.3.7+82
- regenerate uddf entity importer test mocks
- update CLAUDE.md
- add --comment flag to Claude code review prompt
- allow gh/git CLI in Claude code review workflow
- enable verbose output for Claude code review workflow
- disable the swift, java, and c++ codeql steps
- add CODEOWNERS for automatic review assignment

### Other

- Feature/cressi leonardo import (#43)
- Fix/macdive uddf import (Fixes #28) (#42)
- Add search to USB Cable tab when adding a USB dive computer manually for import (#68)
- Feature/buddy merge (#66)
- Add reserve pressure user input to dive planner (#67)
- Feature/sites merge (#54)
- format dive center tile files


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
